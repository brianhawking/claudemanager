//
//  ClaudeManagerTests.swift
//  ClaudeManagerTests
//
//  Created by Brian Veitch on 7/15/26.
//

import XCTest
@testable import ClaudeManager

final class ClaudeManagerTests: XCTestCase {
    @MainActor
    func testWorkspaceHierarchyLifecycle() throws {
        let persistence = InMemoryWorkspacePersistence()
        let store = WorkspaceStore(persistence: persistence)
        let viewModel = WorkspaceViewModel(store: store)

        viewModel.createRepository(name: "ClaudeManager", folderPath: "/tmp/claude-manager")
        let repository = try XCTUnwrap(viewModel.repositories.first)

        viewModel.createWorkstream(repositoryID: repository.id, name: "Phase 1", description: "Persistence shell")
        let workstream = try XCTUnwrap(viewModel.workstreams(in: repository).first)

        viewModel.createSession(workstreamID: workstream.id, name: "Session 1")
        let session = try XCTUnwrap(viewModel.sessions(in: workstream).first)

        let memory = WorkstreamMemory(
            objective: "Phase 1 persistence",
            currentState: "Shared context goes here",
            decisions: [],
            openWork: [],
            risksAndUnknowns: [],
            updatedAt: .now,
            sourceSessionId: session.id,
            revision: 1
        )
        viewModel.updateWorkstreamMemory(workstreamID: workstream.id, memory: memory)

        XCTAssertEqual(viewModel.repositories.count, 1)
        XCTAssertEqual(viewModel.workstreams(in: repository).count, 1)
        XCTAssertEqual(viewModel.sessions(in: workstream).count, 1)
        XCTAssertEqual(viewModel.workstream(id: workstream.id)?.memory?.currentState, "Shared context goes here")

        viewModel.selectSession(id: session.id)
        XCTAssertEqual(viewModel.selectedSessionDetail?.session.id, session.id)

        viewModel.deleteRepository(id: repository.id)

        XCTAssertTrue(viewModel.repositories.isEmpty)
        XCTAssertNil(viewModel.workstream(id: workstream.id))
        XCTAssertNil(viewModel.session(id: session.id))
        XCTAssertEqual(persistence.savedSnapshots.last?.repositories.count, 0)
    }

    @MainActor
    func testAddingDuplicateRepositorySelectsExisting() throws {
        let persistence = InMemoryWorkspacePersistence()
        let store = WorkspaceStore(persistence: persistence)
        let viewModel = WorkspaceViewModel(store: store)

        let folderURL = URL(fileURLWithPath: "/tmp/claude-manager")
        viewModel.addOrSelectRepository(folderURL: folderURL)
        viewModel.addOrSelectRepository(folderURL: folderURL)

        XCTAssertEqual(viewModel.repositories.count, 1)
        XCTAssertEqual(viewModel.selection, .repository(try XCTUnwrap(viewModel.repositories.first?.id)))
    }

    @MainActor
    func testExpandedStateAndSelectionPersist() throws {
        let persistence = InMemoryWorkspacePersistence()
        let store = WorkspaceStore(persistence: persistence)
        let viewModel = WorkspaceViewModel(store: store)

        let folderURL = URL(fileURLWithPath: "/tmp/workspace")
        viewModel.addOrSelectRepository(folderURL: folderURL)
        let repository = try XCTUnwrap(viewModel.repositories.first)
        viewModel.createWorkstream(repositoryID: repository.id, name: "Phase 1", description: nil)
        let workstream = try XCTUnwrap(viewModel.workstreams(in: repository).first)
        viewModel.createSession(workstreamID: workstream.id, name: "Session 1")
        let session = try XCTUnwrap(viewModel.sessions(in: workstream).first)

        viewModel.selectSession(id: session.id)

        let reloadedStore = WorkspaceStore(persistence: persistence)
        let reloadedViewModel = WorkspaceViewModel(store: reloadedStore)

        XCTAssertEqual(reloadedViewModel.selection, .session(session.id))
        XCTAssertTrue(reloadedViewModel.expandedRepositoryIDs.contains(repository.id))
        XCTAssertTrue(reloadedViewModel.expandedWorkstreamIDs.contains(workstream.id))
    }

    @MainActor
    func testBlankSessionNameGeneratesFallback() throws {
        let persistence = InMemoryWorkspacePersistence()
        let store = WorkspaceStore(persistence: persistence)
        let viewModel = WorkspaceViewModel(store: store)

        viewModel.createRepository(name: "Repo", folderPath: "/tmp/repo")
        let repository = try XCTUnwrap(viewModel.repositories.first)
        viewModel.createWorkstream(repositoryID: repository.id, name: "Workstream", description: nil)
        let workstream = try XCTUnwrap(viewModel.workstreams(in: repository).first)

        viewModel.createSession(workstreamID: workstream.id, name: "   ")

        let session = try XCTUnwrap(viewModel.sessions(in: workstream).first)
        XCTAssertTrue(session.name.hasPrefix("Session — "))
    }

    @MainActor
    func testLegacyProjectPersistenceDecodesAsWorkstream() throws {
        let persistence = LegacyWorkspacePersistence()
        let store = WorkspaceStore(persistence: persistence)
        let viewModel = WorkspaceViewModel(store: store)

        XCTAssertEqual(viewModel.repositories.count, 1)
        let workstream = try XCTUnwrap(viewModel.workstreams(in: try XCTUnwrap(viewModel.repositories.first)).first)
        XCTAssertEqual(viewModel.workstreams(in: try XCTUnwrap(viewModel.repositories.first)).count, 1)
        XCTAssertEqual(viewModel.selection, .workstream(UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!))
        XCTAssertEqual(workstream.memory?.currentState, "Legacy context")
        XCTAssertEqual(workstream.memoryHistory.count, 1)
    }

    @MainActor
    func testSessionRuntimeStoreReturnsSameRuntime() throws {
        let detail = SessionDetailContext(
            repository: Repository(name: "Repo", folderPath: "/tmp"),
            workstream: Workstream(repositoryId: UUID(), name: "Workstream"),
            session: WorkspaceSession(workstreamId: UUID(), name: "Session")
        )
        let runtimeStore = SessionRuntimeStore()

        let firstRuntime = runtimeStore.runtime(for: detail)
        let secondRuntime = runtimeStore.runtime(for: detail)

        XCTAssertTrue(firstRuntime === secondRuntime)
    }

    @MainActor
    func testTerminalSessionControllerStartsShellProcess() throws {
        let controller = TerminalSessionController(
            workingDirectory: "/tmp",
            launchBehavior: .shell
        )

        controller.startIfNeeded()

        XCTAssertEqual(controller.state, .running)
        XCTAssertTrue(controller.terminalView.process.running)

        controller.terminate()
    }

    @MainActor
    func testSessionRuntimeStoreCloseAndRestartCreatesFreshRuntime() throws {
        let detail = SessionDetailContext(
            repository: Repository(name: "Repo", folderPath: "/tmp"),
            workstream: Workstream(repositoryId: UUID(), name: "Workstream"),
            session: WorkspaceSession(workstreamId: UUID(), name: "Session")
        )
        let runtimeStore = SessionRuntimeStore()

        let firstRuntime = runtimeStore.startSession(for: detail, claudeStartupCommand: "claude\n")
        XCTAssertEqual(runtimeStore.sessionState(for: detail.session.id), .running)

        runtimeStore.closeSession(detail.session.id)
        XCTAssertEqual(runtimeStore.sessionState(for: detail.session.id), .notStarted)

        let secondRuntime = runtimeStore.startSession(for: detail, claudeStartupCommand: "claude\n")
        XCTAssertFalse(firstRuntime === secondRuntime)
    }
}

private final class InMemoryWorkspacePersistence: WorkspacePersisting {
    var snapshot: WorkspaceSnapshot = .empty
    var savedSnapshots: [WorkspaceSnapshot] = []

    func load() throws -> WorkspaceSnapshot {
        snapshot
    }

    func save(_ snapshot: WorkspaceSnapshot) throws {
        self.snapshot = snapshot
        savedSnapshots.append(snapshot)
    }
}

private struct LegacyWorkspacePersistence: WorkspacePersisting {
    func load() throws -> WorkspaceSnapshot {
        let json = """
        {
          "repositories": [
            {
              "id": "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA",
              "name": "Breadcrumbs",
              "folderPath": "/tmp/breadcrumbs",
              "createdAt": "2026-07-15T12:00:00Z",
              "lastOpenedAt": null
            }
          ],
          "projects": [
            {
              "id": "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB",
              "repositoryId": "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA",
              "name": "Demo UI",
              "description": "Legacy project",
              "sharedContext": "Legacy context",
              "createdAt": "2026-07-15T12:00:00Z",
              "lastOpenedAt": null
            }
          ],
          "sessions": [
            {
              "id": "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC",
              "projectId": "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB",
              "name": "Initial Layout",
              "status": "idle",
              "createdAt": "2026-07-15T12:00:00Z",
              "lastOpenedAt": null
            }
          ],
          "uiState": {
            "selection": {
              "type": "project",
              "id": "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB"
            },
            "expandedRepositoryIDs": ["AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"],
            "expandedProjectIDs": ["BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB"]
          }
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(WorkspaceSnapshot.self, from: Data(json.utf8))
    }

    func save(_ snapshot: WorkspaceSnapshot) throws {}
}
