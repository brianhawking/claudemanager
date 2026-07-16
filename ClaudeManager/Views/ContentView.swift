import AppKit
import SwiftUI

private enum EditorSheet: Identifiable {
    case renameRepository(Repository)
    case addWorkstream(Repository)
    case renameWorkstream(Workstream)
    case addSession(Workstream)
    case renameSession(WorkspaceSession)

    var id: String {
        switch self {
        case .renameRepository(let repository):
            return "renameRepository-\(repository.id.uuidString)"
        case .addWorkstream(let repository):
            return "addWorkstream-\(repository.id.uuidString)"
        case .renameWorkstream(let workstream):
            return "renameWorkstream-\(workstream.id.uuidString)"
        case .addSession(let workstream):
            return "addSession-\(workstream.id.uuidString)"
        case .renameSession(let session):
            return "renameSession-\(session.id.uuidString)"
        }
    }
}

private enum DeleteTarget: Identifiable {
    case repository(Repository)
    case workstream(Workstream)
    case session(WorkspaceSession)

    var id: String {
        switch self {
        case .repository(let repository):
            return "repository-\(repository.id.uuidString)"
        case .workstream(let workstream):
            return "workstream-\(workstream.id.uuidString)"
        case .session(let session):
            return "session-\(session.id.uuidString)"
        }
    }

    var title: String {
        switch self {
        case .repository(let repository):
            return "Delete “\(repository.name)”?"
        case .workstream(let workstream):
            return "Delete “\(workstream.name)”?"
        case .session(let session):
            return "Delete “\(session.name)”?"
        }
    }

    var message: String {
        switch self {
        case .repository:
            return "This will also delete all workstreams and sessions inside the repository."
        case .workstream:
            return "This will also delete all sessions inside the workstream."
        case .session:
            return "This action cannot be undone."
        }
    }
}

struct ContentView: View {
    @ObservedObject var viewModel: WorkspaceViewModel
    @ObservedObject var runtimeStore: SessionRuntimeStore
    @ObservedObject var uiState: WorkspacePresentationState
    @State private var editorSheet: EditorSheet?
    @State private var deleteTarget: DeleteTarget?
    @State private var handoffErrorMessage: String?
    @State private var pendingCloseAfterHandoffSessionID: UUID?

    private let handoffGenerationService = HandoffGenerationService()

    var body: some View {
        NavigationSplitView {
            SidebarView(
                viewModel: viewModel,
                runtimeStore: runtimeStore,
                onAddRepository: addRepositoryFromOpenPanel,
                onAddWorkstream: { repository in
                    editorSheet = .addWorkstream(repository)
                },
                onAddSession: { workstream in
                    editorSheet = .addSession(workstream)
                },
                onEditWorkstreamMemory: openWorkstreamMemoryFromSidebar,
                onRename: handleRenameRequest,
                onDelete: handleDeleteRequest,
                onOpenSession: openSessionFromSidebar,
                onFocusSessionTerminal: focusSessionTerminal,
                onCloseSession: closeSessionFromSidebar,
                onRevealInFinder: revealRepositoryInFinder,
                onCopyPath: copyRepositoryPath
            )
        } detail: {
            DetailView(
                viewModel: viewModel,
                runtimeStore: runtimeStore,
                uiState: uiState,
                onAddWorkstream: {
                    if let repository = viewModel.selectedRepository {
                        editorSheet = .addWorkstream(repository)
                    }
                },
                onAddSession: {
                    if let workstream = viewModel.selectedWorkstream {
                        editorSheet = .addSession(workstream)
                    }
                },
                onStartSession: startSession,
                onStartSessionWithoutMemory: startSessionWithoutMemory,
                onCloseSession: closeSession,
                onEditSharedContext: showWorkstreamMemoryForSession,
                onGenerateHandoff: generateHandoff,
                onGenerateHandoffAndClose: generateHandoffAndClose
            )
        }
        .overlay {
            if uiState.quickOpenPresented {
                QuickOpenPaletteView(
                    viewModel: viewModel,
                    runtimeStore: runtimeStore,
                    onSelectResult: handleQuickOpenSelection,
                    onDismiss: {
                        uiState.quickOpenPresented = false
                    }
                )
            }
        }
        .navigationTitle("Claude Workspace Manager")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    addRepositoryFromOpenPanel()
                } label: {
                    Label("Add Repository", systemImage: "folder.badge.plus")
                }

                Button {
                    if let repository = viewModel.selectedRepository {
                        editorSheet = .addWorkstream(repository)
                    }
                } label: {
                    Label("Add Workstream", systemImage: "square.stack.badge.plus")
                }
                .disabled(!viewModel.canAddWorkstream)

                Button {
                    if let workstream = viewModel.selectedWorkstream {
                        editorSheet = .addSession(workstream)
                    }
                } label: {
                    Label("Add Session", systemImage: "plus.bubble")
                }
                .disabled(!viewModel.canAddSession)

                Divider()

                Button {
                    triggerRenameForSelection()
                } label: {
                    Label("Rename", systemImage: "pencil")
                }
                .disabled(!viewModel.canRenameSelection)

                Button(role: .destructive) {
                    triggerDeleteForSelection()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .disabled(!viewModel.canDeleteSelection)
            }
        }
        .sheet(item: $editorSheet) { sheet in
            switch sheet {
            case .renameRepository(let repository):
                RenameRepositorySheet(
                    title: "Rename Repository",
                    submitTitle: "Save",
                    initialName: repository.name
                ) { name in
                    viewModel.renameRepository(id: repository.id, name: name)
                }
            case .addWorkstream(let repository):
                WorkstreamEditorSheet(
                    title: "Add Workstream",
                    submitTitle: "Create",
                    repositoryName: repository.name,
                    initialName: "",
                    initialDescription: ""
                ) { name, description in
                    viewModel.createWorkstream(repositoryID: repository.id, name: name, description: description)
                }
            case .renameWorkstream(let workstream):
                WorkstreamEditorSheet(
                    title: "Rename Workstream",
                    submitTitle: "Save",
                    repositoryName: viewModel.repository(id: workstream.repositoryId)?.name ?? "Repository",
                    initialName: workstream.name,
                    initialDescription: workstream.description ?? ""
                ) { name, description in
                    viewModel.renameWorkstream(id: workstream.id, name: name, description: description)
                }
            case .addSession(let workstream):
                SessionEditorSheet(
                    title: "Add Session",
                    submitTitle: "Create",
                    workstreamName: workstream.name,
                    initialName: ""
                ) { name in
                    viewModel.createSession(workstreamID: workstream.id, name: name)
                }
            case .renameSession(let session):
                SessionEditorSheet(
                    title: "Rename Session",
                    submitTitle: "Save",
                    workstreamName: viewModel.workstream(id: session.workstreamId)?.name ?? "Workstream",
                    initialName: session.name
                ) { name in
                    viewModel.renameSession(id: session.id, name: name)
                }
            }
        }
        .sheet(item: $uiState.workstreamMemoryRequest) { request in
            if
                let workstream = viewModel.workstream(id: request.workstreamID),
                let repository = viewModel.repository(id: workstream.repositoryId)
            {
                WorkstreamMemorySheet(
                    repository: repository,
                    workstream: workstream,
                    session: viewModel.selectedSession?.workstreamId == workstream.id ? viewModel.selectedSession : nil,
                    sourceSessionName: { sessionID in
                        viewModel.session(id: sessionID)?.name
                    },
                    onMemoryChange: { updatedMemory in
                        viewModel.manuallyCorrectWorkstreamMemory(workstreamID: workstream.id, memory: updatedMemory)
                    },
                    onUndo: {
                        viewModel.undoLastWorkstreamMemoryUpdate(workstreamID: workstream.id)
                    }
                )
            }
        }
        .alert("Workstream Memory Update Failed", isPresented: Binding(
            get: { handoffErrorMessage != nil },
            set: { isPresented in
                if !isPresented { handoffErrorMessage = nil }
            }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(handoffErrorMessage ?? "")
        }
        .alert(item: $uiState.workstreamMemoryNotice) { notice in
            Alert(
                title: Text("Workstream Memory updated"),
                message: Text(noticeMessage(notice)),
                primaryButton: .default(Text("View")) {
                    uiState.workstreamMemoryRequest = WorkstreamMemoryRequest(workstreamID: notice.workstreamID)
                },
                secondaryButton: .default(Text("Undo")) {
                    viewModel.undoLastWorkstreamMemoryUpdate(workstreamID: notice.workstreamID)
                }
            )
        }
        .alert(
            deleteTarget?.title ?? "Delete",
            isPresented: Binding(
                get: { deleteTarget != nil },
                set: { isPresented in
                    if !isPresented {
                        deleteTarget = nil
                    }
                }
            ),
            presenting: deleteTarget
        ) { target in
            Button("Delete", role: .destructive) {
                performDelete(target)
            }
            Button("Cancel", role: .cancel) {
                deleteTarget = nil
            }
        } message: { target in
            Text(target.message)
        }
        .onChange(of: uiState.editorRequest) { _, request in
            guard let request else { return }
            handleEditorRequest(request)
            uiState.editorRequest = nil
        }
    }

    private func triggerRenameForSelection() {
        switch viewModel.selection {
        case .repository(let id):
            if let repository = viewModel.repository(id: id) {
                editorSheet = .renameRepository(repository)
            }
        case .workstream(let id):
            if let workstream = viewModel.workstream(id: id) {
                editorSheet = .renameWorkstream(workstream)
            }
        case .session(let id):
            if let session = viewModel.session(id: id) {
                editorSheet = .renameSession(session)
            }
        case .none:
            break
        }
    }

    private func triggerDeleteForSelection() {
        switch viewModel.selection {
        case .repository(let id):
            if let repository = viewModel.repository(id: id) {
                deleteTarget = .repository(repository)
            }
        case .workstream(let id):
            if let workstream = viewModel.workstream(id: id) {
                deleteTarget = .workstream(workstream)
            }
        case .session(let id):
            if let session = viewModel.session(id: id) {
                deleteTarget = .session(session)
            }
        case .none:
            break
        }
    }

    private func handleRenameRequest(_ selection: SidebarSelection) {
        viewModel.revealSelection(selection)
        triggerRenameForSelection()
    }

    private func handleDeleteRequest(_ selection: SidebarSelection) {
        viewModel.revealSelection(selection)
        triggerDeleteForSelection()
    }

    private func performDelete(_ target: DeleteTarget) {
        switch target {
        case .repository(let repository):
            let sessionIDs = viewModel.workstreams(in: repository)
                .flatMap { viewModel.sessions(in: $0).map(\.id) }
            runtimeStore.removeRuntimes(for: sessionIDs)
            viewModel.deleteRepository(id: repository.id)
        case .workstream(let workstream):
            runtimeStore.removeRuntimes(for: viewModel.sessions(in: workstream).map(\.id))
            viewModel.deleteWorkstream(id: workstream.id)
        case .session(let session):
            runtimeStore.removeRuntime(for: session.id)
            viewModel.deleteSession(id: session.id)
        }

        deleteTarget = nil
    }

    private func startSession(_ detail: SessionDetailContext) {
        let sessionIdentifier = UUID().uuidString
        viewModel.setClaudeSessionIdentifier(sessionIdentifier, for: detail.session.id)

        let startupCommand = ClaudeCommandBuilder.startupCommand(
            sessionIdentifier: sessionIdentifier,
            sessionName: detail.session.name,
            workstreamName: detail.workstream.name,
            memory: detail.workstream.memory
        )

        _ = runtimeStore.startSession(for: detail, claudeStartupCommand: startupCommand)
        uiState.focus(tab: .claude, for: detail.session.id)
        viewModel.selectSession(id: detail.session.id)
    }

    private func startSessionWithoutMemory(_ detail: SessionDetailContext) {
        let sessionIdentifier = UUID().uuidString
        viewModel.setClaudeSessionIdentifier(sessionIdentifier, for: detail.session.id)

        let startupCommand = ClaudeCommandBuilder.startupCommand(
            sessionIdentifier: sessionIdentifier,
            sessionName: detail.session.name,
            workstreamName: detail.workstream.name,
            memory: nil
        )

        _ = runtimeStore.startSession(for: detail, claudeStartupCommand: startupCommand)
        uiState.focus(tab: .claude, for: detail.session.id)
        viewModel.selectSession(id: detail.session.id)
    }

    private func closeSession(_ detail: SessionDetailContext) {
        runtimeStore.closeSession(detail.session.id)
        uiState.resetTerminalTab(for: detail.session.id)
    }

    private func openSessionFromSidebar(_ session: WorkspaceSession) {
        guard let detail = detailContext(for: session) else { return }
        if runtimeStore.sessionState(for: session.id) != .running {
            startSession(detail)
        } else {
            uiState.focus(tab: .claude, for: session.id)
            viewModel.selectSession(id: session.id)
        }
    }

    private func focusSessionTerminal(_ session: WorkspaceSession, tab: SessionTerminalTab) {
        uiState.focus(tab: tab, for: session.id)
        viewModel.selectSession(id: session.id)
    }

    private func closeSessionFromSidebar(_ session: WorkspaceSession) {
        runtimeStore.closeSession(session.id)
        uiState.resetTerminalTab(for: session.id)
        viewModel.selectSession(id: session.id)
    }

    private func showWorkstreamMemoryForSession(_ workstream: Workstream) {
        uiState.workstreamMemoryRequest = WorkstreamMemoryRequest(workstreamID: workstream.id)
    }

    private func openWorkstreamMemoryFromSidebar(_ workstream: Workstream) {
        viewModel.selectWorkstream(id: workstream.id)
        uiState.workstreamMemoryRequest = WorkstreamMemoryRequest(workstreamID: workstream.id)
    }

    private func revealRepositoryInFinder(_ repository: Repository) {
        viewModel.selectRepository(id: repository.id)
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: repository.folderPath)])
    }

    private func copyRepositoryPath(_ repository: Repository) {
        viewModel.selectRepository(id: repository.id)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(repository.folderPath, forType: .string)
    }

    private func handleEditorRequest(_ request: EditorRequest) {
        switch request {
        case .addWorkstream(let repositoryID):
            if let repository = viewModel.repository(id: repositoryID) {
                editorSheet = .addWorkstream(repository)
            }
        case .addSession(let workstreamID):
            if let workstream = viewModel.workstream(id: workstreamID) {
                editorSheet = .addSession(workstream)
            }
        }
    }

    private func handleQuickOpenSelection(_ result: QuickOpenResult) {
        switch result.selection {
        case .repository, .workstream:
            viewModel.revealSelection(result.selection)
            uiState.quickOpenPresented = false
        case .session(let sessionID):
            let runtimeState = runtimeStore.sessionState(for: sessionID)

            if runtimeState == .running {
                viewModel.revealSelection(result.selection)
                uiState.quickOpenPresented = false
            } else if viewModel.selection == result.selection {
                if let session = viewModel.session(id: sessionID), let detail = detailContext(for: session) {
                    startSession(detail)
                }
                uiState.quickOpenPresented = false
            } else {
                viewModel.revealSelection(result.selection)
            }
        }
    }

    private func detailContext(for session: WorkspaceSession) -> SessionDetailContext? {
        guard
            let workstream = viewModel.workstream(id: session.workstreamId),
            let repository = viewModel.repository(id: workstream.repositoryId)
        else { return nil }

        return SessionDetailContext(repository: repository, workstream: workstream, session: session)
    }

    private func generateHandoff(_ detail: SessionDetailContext) {
        Task {
            await runHandoffGeneration(for: detail, closeAfter: false)
        }
    }

    private func generateHandoffAndClose(_ detail: SessionDetailContext) {
        Task {
            await runHandoffGeneration(for: detail, closeAfter: true)
        }
    }

    @MainActor
    private func runHandoffGeneration(for detail: SessionDetailContext, closeAfter: Bool) async {
        guard let sessionIdentifier = detail.session.claudeSessionIdentifier, !sessionIdentifier.isEmpty else {
            handoffErrorMessage = "This session does not have an active Claude session identifier yet."
            return
        }

        do {
            let response = try await handoffGenerationService.generateHandoff(
                request: HandoffGenerationRequest(
                    repositoryPath: detail.repository.folderPath,
                    workstreamName: detail.workstream.name,
                    sessionName: detail.session.name,
                    claudeSessionIdentifier: sessionIdentifier,
                    existingMemory: detail.workstream.memory
                )
            )

            let nextRevision = (detail.workstream.memory?.revision ?? 0) + 1
            let updatedMemory = WorkstreamMemory(
                objective: response.objective,
                currentState: response.currentState,
                decisions: response.decisions,
                openWork: response.openWork,
                risksAndUnknowns: response.risksAndUnknowns,
                updatedAt: .now,
                sourceSessionId: detail.session.id,
                revision: nextRevision
            )

            let changes = summarizeChanges(from: detail.workstream.memory, to: updatedMemory)
            viewModel.updateWorkstreamMemory(workstreamID: detail.workstream.id, memory: updatedMemory)
            uiState.workstreamMemoryNotice = WorkstreamMemoryNotice(
                workstreamID: detail.workstream.id,
                addedItems: changes
            )

            if closeAfter {
                closeSession(detail)
            }
        } catch {
            handoffErrorMessage = error.localizedDescription
        }
    }

    private func summarizeChanges(from oldMemory: WorkstreamMemory?, to newMemory: WorkstreamMemory) -> [String] {
        var changes: [String] = []

        if oldMemory?.objective != newMemory.objective, !newMemory.objective.isEmpty {
            changes.append("Objective updated")
        }
        if oldMemory?.currentState != newMemory.currentState, !newMemory.currentState.isEmpty {
            changes.append("Current state refreshed")
        }

        let decisionAdds = Set(newMemory.decisions).subtracting(oldMemory?.decisions ?? [])
        changes.append(contentsOf: decisionAdds.prefix(2).map { "Decision: \($0)" })

        let openWorkAdds = Set(newMemory.openWork).subtracting(oldMemory?.openWork ?? [])
        changes.append(contentsOf: openWorkAdds.prefix(2).map { "Open work: \($0)" })

        let riskAdds = Set(newMemory.risksAndUnknowns).subtracting(oldMemory?.risksAndUnknowns ?? [])
        changes.append(contentsOf: riskAdds.prefix(2).map { "Risk: \($0)" })

        if changes.isEmpty {
            changes.append("Workstream Memory revised")
        }

        return Array(changes.prefix(3))
    }

    private func noticeMessage(_ notice: WorkstreamMemoryNotice) -> String {
        notice.addedItems.map { "• \($0)" }.joined(separator: "\n")
    }
    
    private func addRepositoryFromOpenPanel() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false

        guard panel.runModal() == .OK, let folderURL = panel.url else {
            return
        }

        viewModel.addOrSelectRepository(folderURL: folderURL)
    }
}

private struct RenameRepositorySheet: View {
    let title: String
    let submitTitle: String
    let initialName: String
    let onSubmit: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String

    init(
        title: String,
        submitTitle: String,
        initialName: String,
        onSubmit: @escaping (String) -> Void
    ) {
        self.title = title
        self.submitTitle = submitTitle
        self.initialName = initialName
        self.onSubmit = onSubmit
        _name = State(initialValue: initialName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)

            TextField("Repository Name", text: $name)

            HStack {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }

                Button(submitTitle) {
                    onSubmit(name.trimmingCharacters(in: .whitespacesAndNewlines))
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 420)
    }
}

private struct WorkstreamEditorSheet: View {
    let title: String
    let submitTitle: String
    let repositoryName: String
    let initialName: String
    let initialDescription: String
    let onSubmit: (String, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var description: String

    init(
        title: String,
        submitTitle: String,
        repositoryName: String,
        initialName: String,
        initialDescription: String,
        onSubmit: @escaping (String, String?) -> Void
    ) {
        self.title = title
        self.submitTitle = submitTitle
        self.repositoryName = repositoryName
        self.initialName = initialName
        self.initialDescription = initialDescription
        self.onSubmit = onSubmit
        _name = State(initialValue: initialName)
        _description = State(initialValue: initialDescription)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)

            LabeledContent("Repository", value: repositoryName)
            TextField("Workstream Name", text: $name)

            TextField("Description (Optional)", text: $description, axis: .vertical)
                .lineLimit(3...5)

            HStack {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }

                Button(submitTitle) {
                    let normalizedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
                    onSubmit(
                        name.trimmingCharacters(in: .whitespacesAndNewlines),
                        normalizedDescription.isEmpty ? nil : normalizedDescription
                    )
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 480)
    }
}

private struct SessionEditorSheet: View {
    let title: String
    let submitTitle: String
    let workstreamName: String
    let initialName: String
    let onSubmit: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String

    init(
        title: String,
        submitTitle: String,
        workstreamName: String,
        initialName: String,
        onSubmit: @escaping (String) -> Void
    ) {
        self.title = title
        self.submitTitle = submitTitle
        self.workstreamName = workstreamName
        self.initialName = initialName
        self.onSubmit = onSubmit
        _name = State(initialValue: initialName)
    }

    private var isCreatingNewSession: Bool {
        initialName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)

            LabeledContent("Workstream", value: workstreamName)
            TextField("Session Name", text: $name)

            if isCreatingNewSession {
                Text("Leave blank to use a timestamped session name.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }

                Button(submitTitle) {
                    onSubmit(name.trimmingCharacters(in: .whitespacesAndNewlines))
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isCreatingNewSession && name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 420)
    }
}

#Preview {
    ContentView(viewModel: .preview, runtimeStore: SessionRuntimeStore(), uiState: WorkspacePresentationState())
}
