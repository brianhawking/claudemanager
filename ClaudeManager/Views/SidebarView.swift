import SwiftUI

struct SidebarView: View {
    @ObservedObject var viewModel: WorkspaceViewModel
    @ObservedObject var runtimeStore: SessionRuntimeStore
    let onAddRepository: () -> Void
    let onAddWorkstream: (Repository) -> Void
    let onAddSession: (Workstream) -> Void
    let onEditWorkstreamMemory: (Workstream) -> Void
    let onRename: (SidebarSelection) -> Void
    let onDelete: (SidebarSelection) -> Void
    let onOpenSession: (WorkspaceSession) -> Void
    let onFocusSessionTerminal: (WorkspaceSession, SessionTerminalTab) -> Void
    let onCloseSession: (WorkspaceSession) -> Void
    let onRevealInFinder: (Repository) -> Void
    let onCopyPath: (Repository) -> Void

    var body: some View {
        List(selection: $viewModel.selection) {
            ForEach(viewModel.repositories) { repository in
                RepositorySidebarRow(
                    repository: repository,
                    workstreams: viewModel.workstreams(in: repository),
                    viewModel: viewModel,
                    runtimeStore: runtimeStore,
                    onAddWorkstream: onAddWorkstream,
                    onAddSession: onAddSession,
                    onEditWorkstreamMemory: onEditWorkstreamMemory,
                    onRename: onRename,
                    onDelete: onDelete,
                    onOpenSession: onOpenSession,
                    onFocusSessionTerminal: onFocusSessionTerminal,
                    onCloseSession: onCloseSession,
                    onRevealInFinder: onRevealInFinder,
                    onCopyPath: onCopyPath
                )
            }
        }
        .listStyle(.sidebar)
        .overlay(alignment: .center) {
            if viewModel.repositories.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "folder")
                        .font(.system(size: 44))
                        .foregroundStyle(.secondary)

                    Text("No Repositories")
                        .font(.title)
                        .fontWeight(.semibold)

                    Text("Add a repository to start organizing workstreams and sessions.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button("Add Repository", action: onAddRepository)
                        .buttonStyle(.borderedProminent)
                }
                .padding(24)
            }
        }
    }
}

private struct RepositorySidebarRow: View {
    let repository: Repository
    let workstreams: [Workstream]
    @ObservedObject var viewModel: WorkspaceViewModel
    @ObservedObject var runtimeStore: SessionRuntimeStore
    let onAddWorkstream: (Repository) -> Void
    let onAddSession: (Workstream) -> Void
    let onEditWorkstreamMemory: (Workstream) -> Void
    let onRename: (SidebarSelection) -> Void
    let onDelete: (SidebarSelection) -> Void
    let onOpenSession: (WorkspaceSession) -> Void
    let onFocusSessionTerminal: (WorkspaceSession, SessionTerminalTab) -> Void
    let onCloseSession: (WorkspaceSession) -> Void
    let onRevealInFinder: (Repository) -> Void
    let onCopyPath: (Repository) -> Void

    private var isExpanded: Bool {
        viewModel.expandedRepositoryIDs.contains(repository.id)
    }

    var body: some View {
        DisclosureGroup(
            isExpanded: Binding(
                get: { isExpanded },
                set: { _ in viewModel.toggleRepositoryExpansion(repository.id) }
            )
        ) {
            ForEach(workstreams) { workstream in
                WorkstreamSidebarRow(
                    workstream: workstream,
                    sessions: viewModel.sessions(in: workstream),
                    viewModel: viewModel,
                    runtimeStore: runtimeStore,
                    onAddSession: onAddSession,
                    onEditWorkstreamMemory: onEditWorkstreamMemory,
                    onRename: onRename,
                    onDelete: onDelete,
                    onOpenSession: onOpenSession,
                    onFocusSessionTerminal: onFocusSessionTerminal,
                    onCloseSession: onCloseSession
                )
                .padding(.leading, 12)
            }
        } label: {
            Label(repository.name, systemImage: "folder")
                .contentShape(Rectangle())
                .onTapGesture {
                    viewModel.selectRepository(id: repository.id)
                }
                .onTapGesture(count: 2) {
                    viewModel.toggleRepositoryExpansion(repository.id)
                }
                .contextMenu {
                    Button("New Workstream…") {
                        onAddWorkstream(repository)
                    }
                    Button("Rename…") {
                        onRename(.repository(repository.id))
                    }
                    Button("Reveal in Finder") {
                        onRevealInFinder(repository)
                    }
                    Button("Copy Path") {
                        onCopyPath(repository)
                    }
                    Divider()
                    Button("Delete…", role: .destructive) {
                        onDelete(.repository(repository.id))
                    }
                }
        }
    }
}

private struct WorkstreamSidebarRow: View {
    let workstream: Workstream
    let sessions: [WorkspaceSession]
    @ObservedObject var viewModel: WorkspaceViewModel
    @ObservedObject var runtimeStore: SessionRuntimeStore
    let onAddSession: (Workstream) -> Void
    let onEditWorkstreamMemory: (Workstream) -> Void
    let onRename: (SidebarSelection) -> Void
    let onDelete: (SidebarSelection) -> Void
    let onOpenSession: (WorkspaceSession) -> Void
    let onFocusSessionTerminal: (WorkspaceSession, SessionTerminalTab) -> Void
    let onCloseSession: (WorkspaceSession) -> Void

    private var isExpanded: Bool {
        viewModel.expandedWorkstreamIDs.contains(workstream.id)
    }

    var body: some View {
        DisclosureGroup(
            isExpanded: Binding(
                get: { isExpanded },
                set: { _ in viewModel.toggleWorkstreamExpansion(workstream.id) }
            )
        ) {
            if sessions.isEmpty {
                Button {
                    onAddSession(workstream)
                } label: {
                    Label("Add Session", systemImage: "plus")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.leading, 8)
            } else {
                ForEach(sessions) { session in
                    SessionSidebarRow(
                        session: session,
                        isSelected: viewModel.selection == .session(session.id),
                        isRunning: runtimeStore.sessionState(for: session.id) == .running,
                        onSelect: {
                            viewModel.selectSession(id: session.id)
                        },
                        onOpen: {
                            onOpenSession(session)
                        },
                        onFocusClaude: {
                            onFocusSessionTerminal(session, .claude)
                        },
                        onFocusTerminal: {
                            onFocusSessionTerminal(session, .shell)
                        },
                        onRename: {
                            onRename(.session(session.id))
                        },
                        onClose: {
                            onCloseSession(session)
                        },
                        onDelete: {
                            onDelete(.session(session.id))
                        }
                    )
                }
            }
        } label: {
            Label(workstream.name, systemImage: "target")
                .fontWeight(.medium)
                .contentShape(Rectangle())
                .onTapGesture {
                    viewModel.selectWorkstream(id: workstream.id)
                }
                .onTapGesture(count: 2) {
                    viewModel.toggleWorkstreamExpansion(workstream.id)
                }
                .contextMenu {
                    Button("New Session…") {
                        onAddSession(workstream)
                    }
                    Button("Rename…") {
                        onRename(.workstream(workstream.id))
                    }
                    Button("Show Workstream Memory…") {
                        onEditWorkstreamMemory(workstream)
                    }
                    Divider()
                    Button("Delete…", role: .destructive) {
                        onDelete(.workstream(workstream.id))
                    }
                }
        }
    }
}

private struct SessionSidebarRow: View {
    let session: WorkspaceSession
    let isSelected: Bool
    let isRunning: Bool
    let onSelect: () -> Void
    let onOpen: () -> Void
    let onFocusClaude: () -> Void
    let onFocusTerminal: () -> Void
    let onRename: () -> Void
    let onClose: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onSelect) {
            Label(session.name, systemImage: "terminal")
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(isSelected ? Color.accentColor.opacity(0.15) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .simultaneousGesture(TapGesture(count: 2).onEnded(onOpen))
        .contextMenu {
            Button(isRunning ? "Open" : "Start Session") {
                onOpen()
            }
            Button("Focus Claude") {
                onFocusClaude()
            }
            Button("Focus Terminal") {
                onFocusTerminal()
            }
            if isRunning {
                Divider()
                Button("Close Session") {
                    onClose()
                }
            }
            Divider()
            Button("Rename…") {
                onRename()
            }
            Divider()
            Button("Delete…", role: .destructive) {
                onDelete()
            }
        }
    }
}
