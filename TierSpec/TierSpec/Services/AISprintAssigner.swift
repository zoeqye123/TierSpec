//
//  AISprintAssigner.swift
//  TierSpec
//
//  Created by Sisyphus on 2026/4/30.
//

import Foundation

/// Represents a sprint assignment suggestion for an unassigned user story
struct SprintAssignmentSuggestion: Identifiable {
    let id = UUID()
    let story: TierItem
    let suggestedSprint: Sprint
    let reason: String
}

/// AI-powered service that suggests sprint assignments for unassigned user stories
@Observable
class AISprintAssigner {
    
    /// Suggests sprint assignments for unassigned user stories
    /// - Parameters:
    ///   - unassignedStories: User stories without a sprint assignment
    ///   - sprints: Available sprints to consider for assignment
    /// - Returns: Array of suggestions, one per story that can be assigned
    func suggestAssignments(
        unassignedStories: [TierItem],
        sprints: [Sprint]
    ) -> [SprintAssignmentSuggestion] {
        var suggestions: [SprintAssignmentSuggestion] = []
        
        let assignableSprints = sprints.filter { sprint in
            sprint.status == .planning || sprint.status == .active
        }
        
        let sortedStories = unassignedStories.sorted { $0.priority > $1.priority }
        
        var sprintCapacity: [UUID: Int] = [:]
        for sprint in assignableSprints {
            sprintCapacity[sprint.id] = sprint.capacityPoints - sprint.committedPoints
        }
        
        for story in sortedStories {
            let storyPoints = story.storyPoints ?? 1
            
            if let bestSprint = findBestSprint(
                for: story,
                storyPoints: storyPoints,
                sprints: assignableSprints,
                sprintCapacity: sprintCapacity
            ) {
                let reason = generateReason(
                    for: story,
                    sprint: bestSprint,
                    storyPoints: storyPoints
                )
                
                suggestions.append(SprintAssignmentSuggestion(
                    story: story,
                    suggestedSprint: bestSprint,
                    reason: reason
                ))
                
                sprintCapacity[bestSprint.id] = (sprintCapacity[bestSprint.id] ?? 0) - storyPoints
            }
        }
        
        return suggestions
    }
    
    // MARK: - Private Helpers
    
    private func findBestSprint(
        for story: TierItem,
        storyPoints: Int,
        sprints: [Sprint],
        sprintCapacity: [UUID: Int]
    ) -> Sprint? {
        let activeSprints = sprints.filter { $0.status == .active }
        let planningSprints = sprints.filter { $0.status == .planning }
        
        if let sprint = findSprintWithCapacity(
            storyPoints: storyPoints,
            sprints: activeSprints,
            sprintCapacity: sprintCapacity
        ) {
            return sprint
        }
        
        if let sprint = findSprintWithCapacity(
            storyPoints: storyPoints,
            sprints: planningSprints,
            sprintCapacity: sprintCapacity
        ) {
            return sprint
        }
        
        return nil
    }
    
    private func findSprintWithCapacity(
        storyPoints: Int,
        sprints: [Sprint],
        sprintCapacity: [UUID: Int]
    ) -> Sprint? {
        return sprints.first { sprint in
            let remaining = sprintCapacity[sprint.id] ?? 0
            return remaining >= storyPoints
        }
    }
    
    private func generateReason(
        for story: TierItem,
        sprint: Sprint,
        storyPoints: Int
    ) -> String {
        let priorityText = story.priority >= 70 ? "High priority" :
                          story.priority >= 30 ? "Medium priority" : "Low priority"
        
        let sprintStatusText = sprint.status == .active ? "active sprint" : "planning sprint"
        
        let remainingCapacity = sprint.capacityPoints - sprint.committedPoints
        let capacityAfter = remainingCapacity - storyPoints
        
        return "\(priorityText) story assigned to \(sprintStatusText) '\(sprint.name)'. " +
               "Uses \(storyPoints) points, leaving \(capacityAfter) points capacity."
    }
}
