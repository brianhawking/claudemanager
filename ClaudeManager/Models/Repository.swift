import Foundation

struct Repository: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var folderPath: String
    let createdAt: Date
    var lastOpenedAt: Date?

    init(
        id: UUID = UUID(),
        name: String,
        folderPath: String,
        createdAt: Date = .now,
        lastOpenedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.folderPath = folderPath
        self.createdAt = createdAt
        self.lastOpenedAt = lastOpenedAt
    }
}
