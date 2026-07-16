import Foundation

enum SessionStatus: String, Codable, CaseIterable, Hashable {
    case idle
    case active
    case paused
    case archived

    var displayName: String {
        rawValue.capitalized
    }
}

struct WorkspaceSession: Identifiable, Codable, Hashable {
    let id: UUID
    let workstreamId: UUID
    var name: String
    var status: SessionStatus
    let createdAt: Date
    var lastOpenedAt: Date?

    // Reserved for later phases.
    var claudeSessionIdentifier: String?
    var gitBranch: String?
    var embeddedClaudeTerminalIdentifier: String?
    var embeddedShellTerminalIdentifier: String?
    var radioStationIdentifier: String?

    init(
        id: UUID = UUID(),
        workstreamId: UUID,
        name: String,
        status: SessionStatus = .idle,
        createdAt: Date = .now,
        lastOpenedAt: Date? = nil,
        claudeSessionIdentifier: String? = nil,
        gitBranch: String? = nil,
        embeddedClaudeTerminalIdentifier: String? = nil,
        embeddedShellTerminalIdentifier: String? = nil,
        radioStationIdentifier: String? = nil
    ) {
        self.id = id
        self.workstreamId = workstreamId
        self.name = name
        self.status = status
        self.createdAt = createdAt
        self.lastOpenedAt = lastOpenedAt
        self.claudeSessionIdentifier = claudeSessionIdentifier
        self.gitBranch = gitBranch
        self.embeddedClaudeTerminalIdentifier = embeddedClaudeTerminalIdentifier
        self.embeddedShellTerminalIdentifier = embeddedShellTerminalIdentifier
        self.radioStationIdentifier = radioStationIdentifier
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case workstreamId
        case projectId
        case name
        case status
        case createdAt
        case lastOpenedAt
        case claudeSessionIdentifier
        case gitBranch
        case embeddedClaudeTerminalIdentifier
        case embeddedShellTerminalIdentifier
        case radioStationIdentifier
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        workstreamId = try container.decodeIfPresent(UUID.self, forKey: .workstreamId)
            ?? container.decode(UUID.self, forKey: .projectId)
        name = try container.decode(String.self, forKey: .name)
        status = try container.decode(SessionStatus.self, forKey: .status)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        lastOpenedAt = try container.decodeIfPresent(Date.self, forKey: .lastOpenedAt)
        claudeSessionIdentifier = try container.decodeIfPresent(String.self, forKey: .claudeSessionIdentifier)
        gitBranch = try container.decodeIfPresent(String.self, forKey: .gitBranch)
        embeddedClaudeTerminalIdentifier = try container.decodeIfPresent(String.self, forKey: .embeddedClaudeTerminalIdentifier)
        embeddedShellTerminalIdentifier = try container.decodeIfPresent(String.self, forKey: .embeddedShellTerminalIdentifier)
        radioStationIdentifier = try container.decodeIfPresent(String.self, forKey: .radioStationIdentifier)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(workstreamId, forKey: .workstreamId)
        try container.encode(name, forKey: .name)
        try container.encode(status, forKey: .status)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(lastOpenedAt, forKey: .lastOpenedAt)
        try container.encodeIfPresent(claudeSessionIdentifier, forKey: .claudeSessionIdentifier)
        try container.encodeIfPresent(gitBranch, forKey: .gitBranch)
        try container.encodeIfPresent(embeddedClaudeTerminalIdentifier, forKey: .embeddedClaudeTerminalIdentifier)
        try container.encodeIfPresent(embeddedShellTerminalIdentifier, forKey: .embeddedShellTerminalIdentifier)
        try container.encodeIfPresent(radioStationIdentifier, forKey: .radioStationIdentifier)
    }
}
