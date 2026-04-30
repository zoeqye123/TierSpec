//
//  AISprintAssignerTests.swift
//  TierSpecTests
//
//  Created by Sisyphus on 2026/4/30.
//

import Testing
import Foundation
@testable import TierSpec

@MainActor
struct AISprintAssignerTests {
    
    private func createTestSprint(
        name: String,
        capacityPoints: Int,
        committedPoints: Int = 0,
        status: SprintStatus = .planning
    ) -> Sprint {
        let sprint = Sprint(
            name: name,
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .weekOfYear, value: 2, to: Date())!,
            capacityPoints: capacityPoints,
            status: status
        )
        sprint.committedPoints = committedPoints
        return sprint
    }
    
    private func createTestStory(
        title: String,
        priority: Int,
        storyPoints: Int? = nil
    ) -> TierItem {
        return TierItem(
            type: .user_story,
            title: title,
            priority: priority,
            storyPoints: storyPoints
        )
    }
    
    @Test func suggestsAssignmentBasedOnPriority() async throws {
        let assigner = AISprintAssigner()
        
        let highPriorityStory = createTestStory(title: "High Priority", priority: 80, storyPoints: 3)
        let lowPriorityStory = createTestStory(title: "Low Priority", priority: 20, storyPoints: 2)
        
        let sprint = createTestSprint(name: "Sprint 1", capacityPoints: 10)
        
        let suggestions = assigner.suggestAssignments(
            unassignedStories: [lowPriorityStory, highPriorityStory],
            sprints: [sprint]
        )
        
        #expect(suggestions.count == 2)
        #expect(suggestions[0].story.id == highPriorityStory.id)
        #expect(suggestions[1].story.id == lowPriorityStory.id)
    }
    
    @Test func respectsSprintCapacity() async throws {
        let assigner = AISprintAssigner()
        
        let story1 = createTestStory(title: "Story 1", priority: 50, storyPoints: 5)
        let story2 = createTestStory(title: "Story 2", priority: 40, storyPoints: 4)
        let story3 = createTestStory(title: "Story 3", priority: 30, storyPoints: 3)
        
        let sprint = createTestSprint(name: "Sprint 1", capacityPoints: 10)
        
        let suggestions = assigner.suggestAssignments(
            unassignedStories: [story1, story2, story3],
            sprints: [sprint]
        )
        
        #expect(suggestions.count == 2)
        #expect(suggestions.contains { $0.story.id == story1.id })
        #expect(suggestions.contains { $0.story.id == story2.id })
        #expect(!suggestions.contains { $0.story.id == story3.id })
    }
    
    @Test func prefersActiveSprints() async throws {
        let assigner = AISprintAssigner()
        
        let story = createTestStory(title: "Story", priority: 50, storyPoints: 3)
        
        let planningSprint = createTestSprint(name: "Planning Sprint", capacityPoints: 10, status: .planning)
        let activeSprint = createTestSprint(name: "Active Sprint", capacityPoints: 10, status: .active)
        
        let suggestions = assigner.suggestAssignments(
            unassignedStories: [story],
            sprints: [planningSprint, activeSprint]
        )
        
        #expect(suggestions.count == 1)
        #expect(suggestions[0].suggestedSprint.id == activeSprint.id)
    }
    
    @Test func fallsBackToPlanningSprintWhenActiveFull() async throws {
        let assigner = AISprintAssigner()
        
        let story = createTestStory(title: "Story", priority: 50, storyPoints: 5)
        
        let activeSprint = createTestSprint(name: "Active Sprint", capacityPoints: 10, committedPoints: 8, status: .active)
        let planningSprint = createTestSprint(name: "Planning Sprint", capacityPoints: 10, status: .planning)
        
        let suggestions = assigner.suggestAssignments(
            unassignedStories: [story],
            sprints: [activeSprint, planningSprint]
        )
        
        #expect(suggestions.count == 1)
        #expect(suggestions[0].suggestedSprint.id == planningSprint.id)
    }
    
    @Test func returnsEmptyWhenNoSprintHasCapacity() async throws {
        let assigner = AISprintAssigner()
        
        let story = createTestStory(title: "Story", priority: 50, storyPoints: 5)
        
        let sprint1 = createTestSprint(name: "Sprint 1", capacityPoints: 10, committedPoints: 8)
        let sprint2 = createTestSprint(name: "Sprint 2", capacityPoints: 10, committedPoints: 7)
        
        let suggestions = assigner.suggestAssignments(
            unassignedStories: [story],
            sprints: [sprint1, sprint2]
        )
        
        #expect(suggestions.isEmpty)
    }
    
    @Test func ignoresCompletedAndCancelledSprints() async throws {
        let assigner = AISprintAssigner()
        
        let story = createTestStory(title: "Story", priority: 50, storyPoints: 3)
        
        let completedSprint = createTestSprint(name: "Completed Sprint", capacityPoints: 10, status: .completed)
        let cancelledSprint = createTestSprint(name: "Cancelled Sprint", capacityPoints: 10, status: .cancelled)
        let activeSprint = createTestSprint(name: "Active Sprint", capacityPoints: 10, status: .active)
        
        let suggestions = assigner.suggestAssignments(
            unassignedStories: [story],
            sprints: [completedSprint, cancelledSprint, activeSprint]
        )
        
        #expect(suggestions.count == 1)
        #expect(suggestions[0].suggestedSprint.id == activeSprint.id)
    }
    
    @Test func generatesReasonWithPriorityText() async throws {
        let assigner = AISprintAssigner()
        
        let highPriorityStory = createTestStory(title: "High", priority: 80, storyPoints: 3)
        let mediumPriorityStory = createTestStory(title: "Medium", priority: 50, storyPoints: 2)
        let lowPriorityStory = createTestStory(title: "Low", priority: 10, storyPoints: 1)
        
        let sprint = createTestSprint(name: "Sprint 1", capacityPoints: 10)
        
        let suggestions = assigner.suggestAssignments(
            unassignedStories: [highPriorityStory, mediumPriorityStory, lowPriorityStory],
            sprints: [sprint]
        )
        
        #expect(suggestions.count == 3)
        #expect(suggestions[0].reason.contains("High priority"))
        #expect(suggestions[1].reason.contains("Medium priority"))
        #expect(suggestions[2].reason.contains("Low priority"))
    }
    
    @Test func generatesReasonWithSprintInfo() async throws {
        let assigner = AISprintAssigner()
        
        let story = createTestStory(title: "Story", priority: 50, storyPoints: 3)
        let activeSprint = createTestSprint(name: "Sprint Alpha", capacityPoints: 10, status: .active)
        
        let suggestions = assigner.suggestAssignments(
            unassignedStories: [story],
            sprints: [activeSprint]
        )
        
        #expect(suggestions.count == 1)
        #expect(suggestions[0].reason.contains("active sprint"))
        #expect(suggestions[0].reason.contains("Sprint Alpha"))
        #expect(suggestions[0].reason.contains("3 points"))
    }
    
    @Test func defaultsToOneStoryPointWhenNotEstimated() async throws {
        let assigner = AISprintAssigner()
        
        let storyWithoutPoints = createTestStory(title: "Unestimated", priority: 50, storyPoints: nil)
        
        let sprint = createTestSprint(name: "Sprint 1", capacityPoints: 1)
        
        let suggestions = assigner.suggestAssignments(
            unassignedStories: [storyWithoutPoints],
            sprints: [sprint]
        )
        
        #expect(suggestions.count == 1)
        #expect(suggestions[0].reason.contains("1 points"))
    }
    
    @Test func assignsToMultipleSprints() async throws {
        let assigner = AISprintAssigner()
        
        let story1 = createTestStory(title: "Story 1", priority: 80, storyPoints: 5)
        let story2 = createTestStory(title: "Story 2", priority: 60, storyPoints: 5)
        
        let sprint1 = createTestSprint(name: "Sprint 1", capacityPoints: 5)
        let sprint2 = createTestSprint(name: "Sprint 2", capacityPoints: 5)
        
        let suggestions = assigner.suggestAssignments(
            unassignedStories: [story1, story2],
            sprints: [sprint1, sprint2]
        )
        
        #expect(suggestions.count == 2)
        #expect(suggestions[0].suggestedSprint.id == sprint1.id)
        #expect(suggestions[1].suggestedSprint.id == sprint2.id)
    }
    
    @Test func updatesCapacityAfterEachAssignment() async throws {
        let assigner = AISprintAssigner()
        
        let story1 = createTestStory(title: "Story 1", priority: 80, storyPoints: 3)
        let story2 = createTestStory(title: "Story 2", priority: 60, storyPoints: 3)
        let story3 = createTestStory(title: "Story 3", priority: 40, storyPoints: 5)
        
        let sprint = createTestSprint(name: "Sprint 1", capacityPoints: 10)
        
        let suggestions = assigner.suggestAssignments(
            unassignedStories: [story1, story2, story3],
            sprints: [sprint]
        )
        
        #expect(suggestions.count == 2)
        #expect(suggestions[0].story.id == story1.id)
        #expect(suggestions[1].story.id == story2.id)
    }
}
