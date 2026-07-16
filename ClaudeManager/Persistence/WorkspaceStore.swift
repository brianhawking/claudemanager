import Foundation

protocol WorkspacePersisting {
    func load() throws -> WorkspaceSnapshot
    func save(_ snapshot: WorkspaceSnapshot) throws
}

struct JSONWorkspacePersistence: WorkspacePersisting {
    private let fileManager: FileManager
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager

        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directoryURL = appSupportURL.appendingPathComponent("ClaudeManager", isDirectory: true)
        self.fileURL = directoryURL.appendingPathComponent("workspace.json")

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func load() throws -> WorkspaceSnapshot {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return .empty
        }

        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(WorkspaceSnapshot.self, from: data)
    }

    func save(_ snapshot: WorkspaceSnapshot) throws {
        let directoryURL = fileURL.deletingLastPathComponent()

        if !fileManager.fileExists(atPath: directoryURL.path) {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }

        let data = try encoder.encode(snapshot)
        try data.write(to: fileURL, options: .atomic)
    }
}

@MainActor
final class WorkspaceStore: ObservableObject {
    @Published private(set) var snapshot: WorkspaceSnapshot = .empty
    @Published private(set) var loadErrorDescription: String?

    private let persistence: WorkspacePersisting

    init(persistence: WorkspacePersisting = JSONWorkspacePersistence()) {
        self.persistence = persistence
        load()
    }

    func update(_ mutation: (inout WorkspaceSnapshot) -> Void) {
        var updated = snapshot
        mutation(&updated)
        persist(updated)
    }

    private func load() {
        do {
            snapshot = try persistence.load()
            loadErrorDescription = nil
        } catch {
            snapshot = .empty
            loadErrorDescription = error.localizedDescription
        }
    }

    private func persist(_ updatedSnapshot: WorkspaceSnapshot) {
        do {
            try persistence.save(updatedSnapshot)
            snapshot = updatedSnapshot
            loadErrorDescription = nil
        } catch {
            loadErrorDescription = error.localizedDescription
        }
    }
}
