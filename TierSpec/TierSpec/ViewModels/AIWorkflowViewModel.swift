import Foundation
import Observation

@MainActor
@Observable
class AIWorkflowViewModel {
    let mcpClient: MCPToolClient
    private let configManager: ConfigManager

    var isProcessing = false
    var currentSuggestions: [HierarchySuggestion] = []
    var complexityEstimates: [UUID: ComplexityEstimateDTO] = [:]
    var dependencyDetections: [UUID: DependencyDetectionDTO] = [:]
    var error: String?
    var inputText = ""

    init(
        mcpClient: MCPToolClient,
        configManager: ConfigManager = ConfigManager()
    ) {
        self.mcpClient = mcpClient
        self.configManager = configManager
    }

    func parseRequirement() async {
        let trimmedInput = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else { return }

        isProcessing = true
        error = nil
        complexityEstimates = [:]
        dependencyDetections = [:]

        defer { isProcessing = false }

        do {
            let apiKey = await configManager.getApiKey()
            let parsed = try await mcpClient.parseRequirement(requirement: trimmedInput, apiKey: apiKey)

            guard let hierarchy = HierarchySuggestionDTO(from: parsed) else {
                throw NSError(domain: "AIWorkflowViewModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid requirement parsing response"])
            }

            let rootSuggestion = mapHierarchySuggestion(from: hierarchy)
            currentSuggestions = [rootSuggestion]

            let existingStories = try await fetchExistingUserStoryIDs()
            let stories = collectSuggestions(ofType: .userStory, from: currentSuggestions)

            for story in stories {
                await estimateComplexity(for: story, apiKey: apiKey)
                await detectDependencies(for: story, existingStoryIds: existingStories, apiKey: apiKey)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func acceptSuggestion(_ suggestion: HierarchySuggestion) async {
        isProcessing = true
        error = nil
        defer { isProcessing = false }

        do {
            try await createSuggestionTree(suggestion, parentId: nil)
            rejectSuggestion(suggestion)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func acceptAllSuggestions() async {
        guard !currentSuggestions.isEmpty else { return }

        isProcessing = true
        error = nil
        defer { isProcessing = false }

        do {
            for suggestion in currentSuggestions {
                try await createSuggestionTree(suggestion, parentId: nil)
            }
            clearSuggestions()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func rejectSuggestion(_ suggestion: HierarchySuggestion) {
        currentSuggestions = currentSuggestions.compactMap { removeSuggestion(withId: suggestion.id, from: $0) }
        complexityEstimates.removeValue(forKey: suggestion.id)
        dependencyDetections.removeValue(forKey: suggestion.id)
    }

    func clearSuggestions() {
        currentSuggestions = []
        complexityEstimates = [:]
        dependencyDetections = [:]
        error = nil
    }

    private func mapHierarchySuggestion(from dto: HierarchySuggestionDTO) -> HierarchySuggestion {
        let capability = dto.capability
        let featureChildren = capability.features.map { feature in
            HierarchySuggestion(
                title: feature.title,
                description: feature.description,
                itemType: .feature,
                confidence: dto.confidence,
                reasoning: dto.reasoning,
                children: feature.userStories.map { story in
                    HierarchySuggestion(
                        title: story.title,
                        description: story.description,
                        itemType: .userStory,
                        confidence: dto.confidence,
                        reasoning: dto.reasoning,
                        children: story.testCases.map {
                            HierarchySuggestion(
                                title: $0.title,
                                description: $0.description,
                                itemType: .testCase,
                                confidence: dto.confidence,
                                reasoning: dto.reasoning
                            )
                        }
                    )
                }
            )
        }

        return HierarchySuggestion(
            title: capability.title,
            description: capability.description,
            itemType: .capability,
            confidence: dto.confidence,
            reasoning: dto.reasoning,
            children: featureChildren
        )
    }

    private func estimateComplexity(for suggestion: HierarchySuggestion, apiKey: String?) async {
        do {
            let result = try await mcpClient.estimateComplexity(
                storyDescription: suggestion.description ?? suggestion.title,
                apiKey: apiKey
            )

            guard let storyPoints = result["storyPoints"] as? Int,
                  let complexity = result["complexity"] as? String,
                  let reasoning = result["reasoning"] as? String,
                  let confidence = result["confidence"] as? Double else {
                return
            }

            complexityEstimates[suggestion.id] = ComplexityEstimateDTO(
                storyPoints: storyPoints,
                complexity: complexity,
                reasoning: reasoning,
                confidence: confidence
            )
        } catch {
            // Non-fatal; parsing suggestions should still be usable.
        }
    }

    private func detectDependencies(
        for suggestion: HierarchySuggestion,
        existingStoryIds: [String],
        apiKey: String?
    ) async {
        do {
            let result = try await mcpClient.detectDependencies(
                storyDescription: suggestion.description ?? suggestion.title,
                existingStoryIds: existingStoryIds,
                apiKey: apiKey
            )

            guard let dependencyDicts = result["dependencies"] as? [[String: Any]],
                  let reasoning = result["reasoning"] as? String,
                  let confidence = result["confidence"] as? Double else {
                return
            }

            let dependencies = dependencyDicts.compactMap { dict -> DependencySuggestionDTO? in
                guard let storyId = dict["storyId"] as? String,
                      let storyTitle = dict["storyTitle"] as? String,
                      let dependencyType = dict["dependencyType"] as? String,
                      let dependencyReasoning = dict["reasoning"] as? String else {
                    return nil
                }

                return DependencySuggestionDTO(
                    storyId: storyId,
                    storyTitle: storyTitle,
                    dependencyType: dependencyType,
                    reasoning: dependencyReasoning
                )
            }

            dependencyDetections[suggestion.id] = DependencyDetectionDTO(
                dependencies: dependencies,
                reasoning: reasoning,
                confidence: confidence
            )
        } catch {
            // Non-fatal; parsing suggestions should still be usable.
        }
    }

    private func fetchExistingUserStoryIDs() async throws -> [String] {
        let response = try await mcpClient.listItems(type: ItemTypeDTO.userStory.rawValue)
        let itemDicts = response["items"] as? [[String: Any]] ?? []

        return itemDicts.compactMap { dict in
            if let id = dict["id"] as? String {
                return id
            }
            if let id = dict["id"] as? UUID {
                return id.uuidString
            }
            return nil
        }
    }

    private func collectSuggestions(ofType type: ItemTypeDTO, from roots: [HierarchySuggestion]) -> [HierarchySuggestion] {
        var result: [HierarchySuggestion] = []

        func walk(_ node: HierarchySuggestion) {
            if node.itemType == type {
                result.append(node)
            }
            node.children.forEach(walk)
        }

        roots.forEach(walk)
        return result
    }

    private func createSuggestionTree(_ suggestion: HierarchySuggestion, parentId: String?) async throws {
        let created = try await mcpClient.createItem(
            type: suggestion.itemType.rawValue,
            title: suggestion.title,
            description: suggestion.description,
            parentId: parentId,
            priority: 0
        )

        let createdId = (created["id"] as? String) ?? (created["item"] as? [String: Any])?["id"] as? String

        for child in suggestion.children {
            try await createSuggestionTree(child, parentId: createdId)
        }
    }

    private func removeSuggestion(withId id: UUID, from node: HierarchySuggestion) -> HierarchySuggestion? {
        guard node.id != id else { return nil }

        var updated = node
        updated.children = node.children.compactMap { removeSuggestion(withId: id, from: $0) }
        return updated
    }
}

struct HierarchySuggestion: Identifiable {
    let id: UUID
    let title: String
    let description: String?
    let itemType: ItemTypeDTO
    let confidence: Double
    let reasoning: String
    var children: [HierarchySuggestion] = []

    init(
        id: UUID = UUID(),
        title: String,
        description: String? = nil,
        itemType: ItemTypeDTO,
        confidence: Double,
        reasoning: String,
        children: [HierarchySuggestion] = []
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.itemType = itemType
        self.confidence = confidence
        self.reasoning = reasoning
        self.children = children
    }
}
