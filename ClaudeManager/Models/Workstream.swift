import Foundation

struct Workstream: Identifiable, Codable, Hashable {
    let id: UUID
    let repositoryId: UUID
    var name: String
    var description: String?
    var memory: WorkstreamMemory?
    var memoryHistory: [WorkstreamMemoryRevision]
    let createdAt: Date
    var lastOpenedAt: Date?

    init(
        id: UUID = UUID(),
        repositoryId: UUID,
        name: String,
        description: String? = nil,
        memory: WorkstreamMemory? = nil,
        memoryHistory: [WorkstreamMemoryRevision] = [],
        createdAt: Date = .now,
        lastOpenedAt: Date? = nil
    ) {
        self.id = id
        self.repositoryId = repositoryId
        self.name = name
        self.description = description
        self.memory = memory
        self.memoryHistory = memoryHistory
        self.createdAt = createdAt
        self.lastOpenedAt = lastOpenedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case repositoryId
        case name
        case description
        case memory
        case memoryHistory
        case sharedContext
        case createdAt
        case lastOpenedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        repositoryId = try container.decode(UUID.self, forKey: .repositoryId)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        lastOpenedAt = try container.decodeIfPresent(Date.self, forKey: .lastOpenedAt)

        let decodedMemory = try container.decodeIfPresent(WorkstreamMemory.self, forKey: .memory)
        let decodedHistory = try container.decodeIfPresent([WorkstreamMemoryRevision].self, forKey: .memoryHistory) ?? []
        let legacySharedContext = try container.decodeIfPresent(String.self, forKey: .sharedContext) ?? ""

        if let decodedMemory {
            memory = decodedMemory
            if decodedHistory.isEmpty {
                memoryHistory = [WorkstreamMemoryRevision(memory: decodedMemory)]
            } else {
                memoryHistory = decodedHistory
            }
        } else if let migratedMemory = WorkstreamMemory.migrated(
            from: legacySharedContext,
            updatedAt: lastOpenedAt ?? createdAt
        ) {
            memory = migratedMemory
            memoryHistory = [WorkstreamMemoryRevision(memory: migratedMemory)]
        } else {
            memory = nil
            memoryHistory = decodedHistory
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(repositoryId, forKey: .repositoryId)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(memory, forKey: .memory)
        try container.encode(memoryHistory, forKey: .memoryHistory)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(lastOpenedAt, forKey: .lastOpenedAt)
    }
}
