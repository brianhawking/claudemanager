import SwiftUI

struct WorkspaceCommands: Commands {
    @ObservedObject var viewModel: WorkspaceViewModel
    @ObservedObject var runtimeStore: SessionRuntimeStore
    @ObservedObject var uiState: WorkspacePresentationState

    var body: some Commands {
        CommandMenu("Workspace") {
            Button("New Session") {
                if let workstreamID = viewModel.selectedWorkstream?.id {
                    uiState.editorRequest = .addSession(workstreamID)
                }
            }
            .keyboardShortcut("n", modifiers: .command)
            .disabled(viewModel.selectedWorkstream == nil)

            Button("New Workstream") {
                if let repositoryID = viewModel.selectedRepository?.id {
                    uiState.editorRequest = .addWorkstream(repositoryID)
                }
            }
            .keyboardShortcut("N", modifiers: [.command, .shift])
            .disabled(viewModel.selectedRepository == nil)

            Divider()

            Button("Quick Open") {
                uiState.quickOpenPresented = true
            }
            .keyboardShortcut("p", modifiers: .command)

            Divider()

            Button("Show Claude") {
                if let sessionID = viewModel.selectedSession?.id {
                    uiState.focus(tab: .claude, for: sessionID)
                }
            }
            .keyboardShortcut("1", modifiers: .command)
            .disabled(viewModel.selectedSession == nil)

            Button("Show Terminal") {
                if let sessionID = viewModel.selectedSession?.id {
                    uiState.focus(tab: .shell, for: sessionID)
                }
            }
            .keyboardShortcut("2", modifiers: .command)
            .disabled(viewModel.selectedSession == nil)

            Divider()

            Button("Previous Session") {
                viewModel.selectAdjacentSession(offset: -1)
            }
            .keyboardShortcut("[", modifiers: [.command, .shift])
            .disabled(viewModel.orderedSessions.isEmpty)

            Button("Next Session") {
                viewModel.selectAdjacentSession(offset: 1)
            }
            .keyboardShortcut("]", modifiers: [.command, .shift])
            .disabled(viewModel.orderedSessions.isEmpty)

            Divider()

            Button("Show Workstream Memory") {
                if let workstreamID = viewModel.selectedWorkstream?.id {
                    uiState.workstreamMemoryRequest = WorkstreamMemoryRequest(workstreamID: workstreamID)
                }
            }
            .disabled(viewModel.selectedWorkstream == nil)
        }
    }
}
