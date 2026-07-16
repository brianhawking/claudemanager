import SwiftUI

struct DetailView: View {
    @ObservedObject var viewModel: WorkspaceViewModel
    @ObservedObject var runtimeStore: SessionRuntimeStore
    @ObservedObject var uiState: WorkspacePresentationState
    let onAddWorkstream: () -> Void
    let onAddSession: () -> Void
    let onStartSession: (SessionDetailContext) -> Void
    let onStartSessionWithoutMemory: (SessionDetailContext) -> Void
    let onCloseSession: (SessionDetailContext) -> Void
    let onEditWorkstreamMemory: (Workstream) -> Void
    let onGenerateHandoff: (SessionDetailContext) -> Void
    let onGenerateHandoffAndClose: (SessionDetailContext) -> Void

    var body: some View {
        if let detail = viewModel.selectedSessionDetail {
            SessionDetailView(
                detail: detail,
                activeRuntime: runtimeStore.runtimeIfPresent(for: detail.session.id),
                sessionState: runtimeStore.sessionState(for: detail.session.id),
                uiState: uiState,
                onStartSession: { onStartSession(detail) },
                onStartSessionWithoutMemory: { onStartSessionWithoutMemory(detail) },
                onCloseSession: { onCloseSession(detail) },
                onEditWorkstreamMemory: { onEditWorkstreamMemory(detail.workstream) },
                onGenerateHandoff: { onGenerateHandoff(detail) },
                onGenerateHandoffAndClose: { onGenerateHandoffAndClose(detail) }
            )
        } else if let repository = viewModel.selectedRepository, viewModel.selectedWorkstream == nil {
            RepositoryEmptyStateView(
                repository: repository,
                hasWorkstreams: !viewModel.workstreams(in: repository).isEmpty,
                onAddWorkstream: onAddWorkstream
            )
        } else if let workstream = viewModel.selectedWorkstream {
            WorkstreamEmptyStateView(
                workstream: workstream,
                hasSessions: !viewModel.sessions(in: workstream).isEmpty,
                onAddSession: onAddSession
            )
        } else {
            EmptyDetailView(loadErrorDescription: viewModel.loadErrorDescription)
        }
    }
}

private struct SessionDetailView: View {
    let detail: SessionDetailContext
    let activeRuntime: SessionRuntime?
    let sessionState: TerminalRuntimeState
    @ObservedObject var uiState: WorkspacePresentationState
    let onStartSession: () -> Void
    let onStartSessionWithoutMemory: () -> Void
    let onCloseSession: () -> Void
    let onEditWorkstreamMemory: () -> Void
    let onGenerateHandoff: () -> Void
    let onGenerateHandoffAndClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if isRunning, let activeRuntime {
                Picker("Session Terminal", selection: selectedTabBinding) {
                    ForEach(SessionTerminalTab.allCases) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 260)

                activeTerminalView(runtime: activeRuntime)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.secondary.opacity(0.12))
                    }
            } else {
                StoppedSessionView(
                    state: sessionState,
                    hasMemory: detail.workstream.memory?.hasContent == true,
                    onStartSession: onStartSession,
                    onStartWithoutMemory: onStartSessionWithoutMemory
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(detail.session.name)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                Text("\(detail.workstream.name) • \(detail.repository.name)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(detail.repository.folderPath)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(detail.repository.folderPath)

                runtimeStatusView
            }

            Spacer()

            HStack(spacing: 8) {
                if isRunning {
                    Button("Generate Handoff", action: onGenerateHandoff)
                        .controlSize(.small)

                    Button("Generate Handoff & Close", action: onGenerateHandoffAndClose)
                        .controlSize(.small)

                    Button("Close Session", action: onCloseSession)
                        .controlSize(.small)
                } else {
                    Button("Start Session", action: onStartSession)
                        .controlSize(.small)
                }

                Button("Memory", action: onEditWorkstreamMemory)
                    .controlSize(.small)
            }
        }
    }

    @ViewBuilder
    private func activeTerminalView(runtime: SessionRuntime) -> some View {
        switch uiState.terminalTab(for: detail.session.id) {
        case .claude:
            EmbeddedTerminalView(controller: runtime.claudeTerminal)
        case .shell:
            EmbeddedTerminalView(controller: runtime.shellTerminal)
        }
    }

    private var selectedTabBinding: Binding<SessionTerminalTab> {
        Binding(
            get: { uiState.terminalTab(for: detail.session.id) },
            set: { uiState.focus(tab: $0, for: detail.session.id) }
        )
    }

    private var isRunning: Bool {
        sessionState == .running
    }

    private var runtimeStatusView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                statusDot(for: claudeState)
                Text("Claude \(claudeState.displayName)")
                Text("·")
                    .foregroundStyle(.tertiary)
                statusDot(for: shellState)
                Text("Terminal \(shellState.displayName)")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if didIncludeMemoryOnStart {
                Label("Workstream Memory included", systemImage: "brain.head.profile")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else if detail.workstream.memory?.hasContent == true, !isRunning {
                Label("This session can start with Workstream Memory", systemImage: "brain.head.profile")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var didIncludeMemoryOnStart: Bool {
        isRunning && detail.workstream.memory?.hasContent == true && detail.session.claudeSessionIdentifier != nil
    }

    private var claudeState: TerminalRuntimeState {
        activeRuntime?.claudeTerminal.state ?? sessionState
    }

    private var shellState: TerminalRuntimeState {
        activeRuntime?.shellTerminal.state ?? sessionState
    }

    private func statusDot(for state: TerminalRuntimeState) -> some View {
        Circle()
            .fill(statusColor(for: state))
            .frame(width: 7, height: 7)
    }

    private func statusColor(for state: TerminalRuntimeState) -> Color {
        switch state {
        case .notStarted:
            return .secondary
        case .running:
            return .green
        case .exited:
            return .orange
        case .failed:
            return .red
        }
    }
}

private struct StoppedSessionView: View {
    let state: TerminalRuntimeState
    let hasMemory: Bool
    let onStartSession: () -> Void
    let onStartWithoutMemory: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label(state.title, systemImage: state.symbolName)
        } description: {
            Text(state.message)
        } actions: {
            Button("Start Session", action: onStartSession)
                .buttonStyle(.borderedProminent)

            if hasMemory {
                Button("Start Without Memory", action: onStartWithoutMemory)
            }
        }
    }
}

struct WorkstreamMemorySheet: View {
    let repository: Repository
    let workstream: Workstream
    let session: WorkspaceSession?
    let sourceSessionName: (UUID) -> String?
    let onMemoryChange: (WorkstreamMemory) -> Void
    let onUndo: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draftMemory: WorkstreamMemory
    @State private var isEditing = false

    init(
        repository: Repository,
        workstream: Workstream,
        session: WorkspaceSession?,
        sourceSessionName: @escaping (UUID) -> String?,
        onMemoryChange: @escaping (WorkstreamMemory) -> Void,
        onUndo: @escaping () -> Void
    ) {
        self.repository = repository
        self.workstream = workstream
        self.session = session
        self.sourceSessionName = sourceSessionName
        self.onMemoryChange = onMemoryChange
        self.onUndo = onUndo
        _draftMemory = State(initialValue: workstream.memory ?? WorkstreamMemory(
            objective: "",
            currentState: "",
            decisions: [],
            openWork: [],
            risksAndUnknowns: [],
            updatedAt: workstream.lastOpenedAt ?? workstream.createdAt,
            sourceSessionId: session?.id,
            revision: workstream.memory?.revision ?? 0
        ))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Workstream Memory")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Spacer()

                    if isEditing {
                        Button("Cancel") {
                            draftMemory = persistedMemory
                            isEditing = false
                        }

                        Button("Save Correction") {
                            saveCorrection()
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button("Edit") {
                            draftMemory = persistedMemory
                            isEditing = true
                        }
                    }

                    if workstream.memoryHistory.count >= 2 {
                        Button("Undo", action: onUndo)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(workstream.name)
                        .font(.headline)

                    Text(repository.name)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let description = workstream.description, !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                metadataSection
                memorySection(title: "Objective", text: $draftMemory.objective)
                memorySection(title: "Current State", text: $draftMemory.currentState)
                bulletSection(title: "Decisions", items: Binding(
                    get: { draftMemory.decisions.joined(separator: "\n") },
                    set: { draftMemory.decisions = normalizeLines($0) }
                ))
                bulletSection(title: "Open Work", items: Binding(
                    get: { draftMemory.openWork.joined(separator: "\n") },
                    set: { draftMemory.openWork = normalizeLines($0) }
                ))
                bulletSection(title: "Risks and Unknowns", items: Binding(
                    get: { draftMemory.risksAndUnknowns.joined(separator: "\n") },
                    set: { draftMemory.risksAndUnknowns = normalizeLines($0) }
                ))

                if !workstream.memoryHistory.isEmpty {
                    historySection
                }

                HStack {
                    Spacer()

                    Button("Done") {
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(24)
        }
        .frame(width: 620, height: 720)
    }

    private var persistedMemory: WorkstreamMemory {
        workstream.memory ?? WorkstreamMemory(
            objective: "",
            currentState: "",
            decisions: [],
            openWork: [],
            risksAndUnknowns: [],
            updatedAt: workstream.lastOpenedAt ?? workstream.createdAt,
            sourceSessionId: session?.id,
            revision: 0
        )
    }

    private func saveCorrection() {
        guard draftMemory != persistedMemory else {
            isEditing = false
            return
        }

        var corrected = draftMemory
        corrected.sourceSessionId = corrected.sourceSessionId ?? session?.id
        onMemoryChange(corrected)
        isEditing = false
    }

    private var metadataSection: some View {
        Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 8) {
            GridRow {
                metadataLabel("Updated")
                Text(persistedMemory.updatedAt.formatted(date: .abbreviated, time: .shortened))
            }

            GridRow {
                metadataLabel("Revision")
                Text("\(persistedMemory.revision)")
            }

            GridRow {
                metadataLabel("Created")
                Text(workstream.createdAt.formatted(date: .abbreviated, time: .shortened))
            }

            if let lastOpenedAt = workstream.lastOpenedAt {
                GridRow {
                    metadataLabel("Last Opened")
                    Text(lastOpenedAt.formatted(date: .abbreviated, time: .shortened))
                }
            }

            if let sourceSessionId = persistedMemory.sourceSessionId {
                GridRow {
                    metadataLabel("Source Session")
                    Text(sourceSessionName(sourceSessionId) ?? sourceSessionId.uuidString)
                }
            } else if let session {
                GridRow {
                    metadataLabel("Source Session")
                    Text(session.name)
                }
            }

            GridRow {
                metadataLabel("Folder")
                Text(repository.folderPath)
                    .textSelection(.enabled)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }

    @ViewBuilder
    private func memorySection(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)

            if isEditing {
                TextEditor(text: text)
                    .font(.body)
                    .frame(minHeight: 72)
                    .padding(8)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                Text(text.wrappedValue.isEmpty ? "—" : text.wrappedValue)
                    .foregroundStyle(text.wrappedValue.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func bulletSection(title: String, items: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)

            if isEditing {
                TextEditor(text: items)
                    .font(.body)
                    .frame(minHeight: 72)
                    .padding(8)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                let values = normalizeLines(items.wrappedValue)
                if values.isEmpty {
                    Text("—")
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(values, id: \.self) { item in
                            Text("• \(item)")
                        }
                    }
                }
            }
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Revision History")
                .font(.headline)

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(workstream.memoryHistory.reversed())) { revision in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text("Revision \(revision.revision)")
                                Spacer()
                                Text(revision.timestamp.formatted(date: .abbreviated, time: .shortened))
                                    .foregroundStyle(.secondary)
                            }
                            .font(.caption)

                            if let sourceSessionId = revision.sourceSessionId {
                                Text(sourceSessionName(sourceSessionId) ?? sourceSessionId.uuidString)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: 140)
        }
    }

    private func normalizeLines(_ value: String) -> [String] {
        value
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func metadataLabel(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(width: 100, alignment: .leading)
    }
}

private extension TerminalRuntimeState {
    var title: String {
        switch self {
        case .notStarted:
            return "Session Not Started"
        case .running:
            return "Session Running"
        case .exited:
            return "Session Exited"
        case .failed:
            return "Session Failed"
        }
    }

    var message: String {
        switch self {
        case .notStarted:
            return "Start this workspace session when you’re ready to launch Claude and its paired shell."
        case .running:
            return "The session is already running."
        case .exited:
            return "This session is no longer running. Start it again to create a fresh Claude and shell runtime."
        case .failed:
            return "The previous runtime failed. Start the session again to create a fresh runtime."
        }
    }

    var symbolName: String {
        switch self {
        case .notStarted:
            return "play.slash"
        case .running:
            return "play.circle"
        case .exited:
            return "stop.circle"
        case .failed:
            return "exclamationmark.triangle"
        }
    }
}

private struct RepositoryEmptyStateView: View {
    let repository: Repository
    let hasWorkstreams: Bool
    let onAddWorkstream: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label(repository.name, systemImage: "folder")
        } description: {
            Text(hasWorkstreams ? "Select a session from the sidebar." : "This repository does not have any workstreams yet.")
        } actions: {
            if !hasWorkstreams {
                Button("Add Workstream", action: onAddWorkstream)
            }
        }
    }
}

private struct WorkstreamEmptyStateView: View {
    let workstream: Workstream
    let hasSessions: Bool
    let onAddSession: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label(workstream.name, systemImage: "target")
        } description: {
            Text(hasSessions ? "Select a session from the sidebar." : "This workstream does not have any sessions yet.")
        } actions: {
            if !hasSessions {
                Button("Add Session", action: onAddSession)
            }
        }
    }
}

private struct EmptyDetailView: View {
    let loadErrorDescription: String?

    var body: some View {
        ContentUnavailableView {
            Label("Select a Session", systemImage: "sidebar.right")
        } description: {
            if let loadErrorDescription {
                Text("The workspace loaded with an error: \(loadErrorDescription)")
            } else {
                Text("Choose a session from the sidebar to view its workspace and Workstream Memory.")
            }
        }
    }
}
