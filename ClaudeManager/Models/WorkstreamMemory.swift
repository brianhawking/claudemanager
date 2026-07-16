import Foundation

struct WorkstreamMemory: Codable, Hashable {
    var objective: String
    var currentState: String
    var decisions: [String]
    var openWork: [String]
    var risksAndUnknowns: [String]
    var updatedAt: Date
    var sourceSessionId: UUID?
    var revision: Int

    static func migrated(from legacyContext: String, updatedAt: Date, sourceSessionId: UUID? = nil) -> WorkstreamMemory? {
        let trimmed = legacyContext.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        return WorkstreamMemory(
            objective: "",
            currentState: trimmed,
            decisions: [],
            openWork: [],
            risksAndUnknowns: [],
            updatedAt: updatedAt,
            sourceSessionId: sourceSessionId,
            revision: 1
        )
    }

    var hasContent: Bool {
        !objective.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !currentState.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !decisions.isEmpty ||
        !openWork.isEmpty ||
        !risksAndUnknowns.isEmpty
    }
}

struct WorkstreamMemoryRevision: Codable, Hashable, Identifiable {
    let id: UUID
    var memory: WorkstreamMemory
    var timestamp: Date
    var sourceSessionId: UUID?
    var revision: Int

    init(id: UUID = UUID(), memory: WorkstreamMemory) {
        self.id = id
        self.memory = memory
        self.timestamp = memory.updatedAt
        self.sourceSessionId = memory.sourceSessionId
        self.revision = memory.revision
    }
}
