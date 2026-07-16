import Foundation

struct WorkspaceUIState: Codable, Hashable {
    var selection: SidebarSelection?
    var expandedRepositoryIDs: Set<UUID>
    var expandedWorkstreamIDs: Set<UUID>

    static let empty = WorkspaceUIState(
        selection: nil,
        expandedRepositoryIDs: [],
        expandedWorkstreamIDs: []
    )

    private enum CodingKeys: String, CodingKey {
        case selection
        case expandedRepositoryIDs
        case expandedWorkstreamIDs
        case expandedProjectIDs
    }

    init(
        selection: SidebarSelection?,
        expandedRepositoryIDs: Set<UUID>,
        expandedWorkstreamIDs: Set<UUID>
    ) {
        self.selection = selection
        self.expandedRepositoryIDs = expandedRepositoryIDs
        self.expandedWorkstreamIDs = expandedWorkstreamIDs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        selection = try container.decodeIfPresent(SidebarSelection.self, forKey: .selection)
        expandedRepositoryIDs = try container.decodeIfPresent(Set<UUID>.self, forKey: .expandedRepositoryIDs) ?? []
        expandedWorkstreamIDs = try container.decodeIfPresent(Set<UUID>.self, forKey: .expandedWorkstreamIDs)
            ?? container.decodeIfPresent(Set<UUID>.self, forKey: .expandedProjectIDs)
            ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(selection, forKey: .selection)
        try container.encode(expandedRepositoryIDs, forKey: .expandedRepositoryIDs)
        try container.encode(expandedWorkstreamIDs, forKey: .expandedWorkstreamIDs)
    }
}

struct WorkspaceSnapshot: Codable, Hashable {
    var repositories: [Repository]
    var workstreams: [Workstream]
    var sessions: [WorkspaceSession]
    var uiState: WorkspaceUIState

    static let empty = WorkspaceSnapshot(
        repositories: [],
        workstreams: [],
        sessions: [],
        uiState: .empty
    )

    private enum CodingKeys: String, CodingKey {
        case repositories
        case workstreams
        case projects
        case sessions
        case uiState
    }

    init(
        repositories: [Repository],
        workstreams: [Workstream],
        sessions: [WorkspaceSession],
        uiState: WorkspaceUIState
    ) {
        self.repositories = repositories
        self.workstreams = workstreams
        self.sessions = sessions
        self.uiState = uiState
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        repositories = try container.decodeIfPresent([Repository].self, forKey: .repositories) ?? []
        workstreams = try container.decodeIfPresent([Workstream].self, forKey: .workstreams)
            ?? container.decodeIfPresent([Workstream].self, forKey: .projects)
            ?? []
        sessions = try container.decodeIfPresent([WorkspaceSession].self, forKey: .sessions) ?? []
        uiState = try container.decodeIfPresent(WorkspaceUIState.self, forKey: .uiState) ?? .empty
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(repositories, forKey: .repositories)
        try container.encode(workstreams, forKey: .workstreams)
        try container.encode(sessions, forKey: .sessions)
        try container.encode(uiState, forKey: .uiState)
    }
}
