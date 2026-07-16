import Foundation

enum SessionTerminalTab: String, CaseIterable, Identifiable {
    case claude
    case shell

    var id: String { rawValue }

    var title: String {
        switch self {
        case .claude:
            return "Claude"
        case .shell:
            return "Terminal"
        }
    }
}

enum EditorRequest: Identifiable, Equatable {
    case addWorkstream(UUID)
    case addSession(UUID)

    var id: String {
        switch self {
        case .addWorkstream(let repositoryID):
            return "addWorkstream-\(repositoryID.uuidString)"
        case .addSession(let workstreamID):
            return "addSession-\(workstreamID.uuidString)"
        }
    }
}

struct WorkstreamMemoryRequest: Identifiable, Equatable {
    let workstreamID: UUID
    var id: UUID { workstreamID }
}

struct WorkstreamMemoryNotice: Identifiable, Equatable {
    let workstreamID: UUID
    let addedItems: [String]

    var id: UUID { workstreamID }
}

@MainActor
final class WorkspacePresentationState: ObservableObject {
    @Published var quickOpenPresented = false
    @Published var editorRequest: EditorRequest?
    @Published var workstreamMemoryRequest: WorkstreamMemoryRequest?
    @Published var workstreamMemoryNotice: WorkstreamMemoryNotice?

    private var terminalTabs: [UUID: SessionTerminalTab] = [:]

    func terminalTab(for sessionID: UUID) -> SessionTerminalTab {
        terminalTabs[sessionID] ?? .claude
    }

    func focus(tab: SessionTerminalTab, for sessionID: UUID) {
        terminalTabs[sessionID] = tab
    }

    func resetTerminalTab(for sessionID: UUID) {
        terminalTabs.removeValue(forKey: sessionID)
    }
}
