//
//  ClaudeManagerApp.swift
//  ClaudeManager
//
//  Created by Brian Veitch on 7/15/26.
//

import SwiftUI

@main
struct ClaudeManagerApp: App {
    @StateObject private var store = WorkspaceStore()
    @StateObject private var viewModel: WorkspaceViewModel
    @StateObject private var runtimeStore = SessionRuntimeStore()
    @StateObject private var uiState = WorkspacePresentationState()

    init() {
        let store = WorkspaceStore()
        _store = StateObject(wrappedValue: store)
        _viewModel = StateObject(wrappedValue: WorkspaceViewModel(store: store))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel, runtimeStore: runtimeStore, uiState: uiState)
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    runtimeStore.terminateAll()
                }
        }
        .commands {
            WorkspaceCommands(viewModel: viewModel, runtimeStore: runtimeStore, uiState: uiState)
        }
    }
}

#if DEBUG
extension WorkspaceViewModel {
    static var preview: WorkspaceViewModel {
        WorkspaceViewModel(store: WorkspaceStore(persistence: PreviewWorkspacePersistence()))
    }
}

private struct PreviewWorkspacePersistence: WorkspacePersisting {
    func load() throws -> WorkspaceSnapshot {
        let repoOne = Repository(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            name: "Breadcrumbs",
            folderPath: "/Users/brianveitch/Projects/Breadcrumbs",
            createdAt: .now.addingTimeInterval(-10_000),
            lastOpenedAt: .now.addingTimeInterval(-600)
        )
        let repoTwo = Repository(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            name: "Flight Simulator",
            folderPath: "/Users/brianveitch/Projects/FlightSimulator",
            createdAt: .now.addingTimeInterval(-20_000),
            lastOpenedAt: .now.addingTimeInterval(-1_200)
        )

        let workstreamOne = Workstream(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            repositoryId: repoOne.id,
            name: "Demo UI",
            description: "Finder-style workspace navigation",
            memory: WorkstreamMemory(
                objective: "Validate the workspace manager information architecture.",
                currentState: "Terminal runtime and selection flow are working in preview data.",
                decisions: ["Keep the app terminal-first."],
                openWork: ["Refine memory handoff flow."],
                risksAndUnknowns: ["Need reliable structured handoff generation."],
                updatedAt: .now.addingTimeInterval(-500),
                sourceSessionId: nil,
                revision: 1
            ),
            memoryHistory: [],
            createdAt: .now.addingTimeInterval(-8_000),
            lastOpenedAt: .now.addingTimeInterval(-500)
        )
        let workstreamTwo = Workstream(
            id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
            repositoryId: repoOne.id,
            name: "Journal Refactor",
            description: "Refine content structure",
            memory: WorkstreamMemory(
                objective: "Refine content structure.",
                currentState: "Workstream memory is intended to preserve useful continuity.",
                decisions: ["Use workstream-level memory instead of session-only notes."],
                openWork: ["Test handoff generation."],
                risksAndUnknowns: [],
                updatedAt: .now.addingTimeInterval(-400),
                sourceSessionId: nil,
                revision: 1
            ),
            memoryHistory: [],
            createdAt: .now.addingTimeInterval(-7_000),
            lastOpenedAt: .now.addingTimeInterval(-400)
        )
        let workstreamThree = Workstream(
            id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
            repositoryId: repoTwo.id,
            name: "Timeline Engine",
            description: "Scenario tooling",
            memory: WorkstreamMemory(
                objective: "Validate hierarchy indentation and detail layout.",
                currentState: "Preview data supports session detail layout checks.",
                decisions: [],
                openWork: [],
                risksAndUnknowns: [],
                updatedAt: .now.addingTimeInterval(-300),
                sourceSessionId: nil,
                revision: 1
            ),
            memoryHistory: [],
            createdAt: .now.addingTimeInterval(-6_000),
            lastOpenedAt: .now.addingTimeInterval(-300)
        )

        let sessionOne = WorkspaceSession(
            id: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!,
            workstreamId: workstreamOne.id,
            name: "Initial Layout",
            createdAt: .now.addingTimeInterval(-5_000),
            lastOpenedAt: .now.addingTimeInterval(-250)
        )
        let sessionTwo = WorkspaceSession(
            id: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!,
            workstreamId: workstreamOne.id,
            name: "Continue Navigation",
            createdAt: .now.addingTimeInterval(-4_000),
            lastOpenedAt: .now.addingTimeInterval(-200)
        )
        let sessionThree = WorkspaceSession(
            id: UUID(uuidString: "88888888-8888-8888-8888-888888888888")!,
            workstreamId: workstreamTwo.id,
            name: "First Pass",
            createdAt: .now.addingTimeInterval(-3_000),
            lastOpenedAt: .now.addingTimeInterval(-150)
        )
        let sessionFour = WorkspaceSession(
            id: UUID(uuidString: "99999999-9999-9999-9999-999999999999")!,
            workstreamId: workstreamThree.id,
            name: "Scenario Work",
            createdAt: .now.addingTimeInterval(-2_000),
            lastOpenedAt: .now.addingTimeInterval(-100)
        )

        return WorkspaceSnapshot(
            repositories: [repoOne, repoTwo],
            workstreams: [workstreamOne, workstreamTwo, workstreamThree],
            sessions: [sessionOne, sessionTwo, sessionThree, sessionFour],
            uiState: WorkspaceUIState(
                selection: .session(sessionOne.id),
                expandedRepositoryIDs: [repoOne.id, repoTwo.id],
                expandedWorkstreamIDs: [workstreamOne.id, workstreamTwo.id, workstreamThree.id]
            )
        )
    }

    func save(_ snapshot: WorkspaceSnapshot) throws {}
}
#endif
