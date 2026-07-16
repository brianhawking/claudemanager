import Foundation
import SwiftUI

enum SidebarSelection: Hashable, Codable {
    case repository(UUID)
    case workstream(UUID)
    case session(UUID)

    private enum CodingKeys: String, CodingKey {
        case type
        case id
    }

    private enum SelectionType: String, Codable {
        case repository
        case workstream
        case project
        case session
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(SelectionType.self, forKey: .type)
        let id = try container.decode(UUID.self, forKey: .id)

        switch type {
        case .repository:
            self = .repository(id)
        case .workstream, .project:
            self = .workstream(id)
        case .session:
            self = .session(id)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .repository(let id):
            try container.encode(SelectionType.repository, forKey: .type)
            try container.encode(id, forKey: .id)
        case .workstream(let id):
            try container.encode(SelectionType.workstream, forKey: .type)
            try container.encode(id, forKey: .id)
        case .session(let id):
            try container.encode(SelectionType.session, forKey: .type)
            try container.encode(id, forKey: .id)
        }
    }
}

struct SessionDetailContext {
    let repository: Repository
    let workstream: Workstream
    let session: WorkspaceSession
}

@MainActor
final class WorkspaceViewModel: ObservableObject {
    @Published var selection: SidebarSelection? {
        didSet { persistUIState() }
    }
    @Published var expandedRepositoryIDs: Set<UUID> {
        didSet { persistUIState() }
    }
    @Published var expandedWorkstreamIDs: Set<UUID> {
        didSet { persistUIState() }
    }

    private let store: WorkspaceStore

    init(store: WorkspaceStore) {
        self.store = store
        self.selection = store.snapshot.uiState.selection
        self.expandedRepositoryIDs = store.snapshot.uiState.expandedRepositoryIDs
        self.expandedWorkstreamIDs = store.snapshot.uiState.expandedWorkstreamIDs
        sanitizePersistedUIState()
    }

    var repositories: [Repository] {
        store.snapshot.repositories
    }

    var loadErrorDescription: String? {
        store.loadErrorDescription
    }

    func workstreams(in repository: Repository) -> [Workstream] {
        store.snapshot.workstreams.filter { $0.repositoryId == repository.id }
    }

    func sessions(in workstream: Workstream) -> [WorkspaceSession] {
        store.snapshot.sessions.filter { $0.workstreamId == workstream.id }
    }

    func repository(id: UUID) -> Repository? {
        store.snapshot.repositories.first { $0.id == id }
    }

    func workstream(id: UUID) -> Workstream? {
        store.snapshot.workstreams.first { $0.id == id }
    }

    func session(id: UUID) -> WorkspaceSession? {
        store.snapshot.sessions.first { $0.id == id }
    }

    var selectedRepository: Repository? {
        switch selection {
        case .repository(let id):
            return repository(id: id)
        case .workstream(let id):
            guard let workstream = workstream(id: id) else { return nil }
            return repository(id: workstream.repositoryId)
        case .session(let id):
            guard
                let session = session(id: id),
                let workstream = workstream(id: session.workstreamId)
            else { return nil }
            return repository(id: workstream.repositoryId)
        case .none:
            return nil
        }
    }

    var selectedWorkstream: Workstream? {
        switch selection {
        case .workstream(let id):
            return workstream(id: id)
        case .session(let id):
            guard let session = session(id: id) else { return nil }
            return workstream(id: session.workstreamId)
        default:
            return nil
        }
    }

    var selectedSession: WorkspaceSession? {
        guard case .session(let id) = selection else { return nil }
        return session(id: id)
    }

    var selectedSessionDetail: SessionDetailContext? {
        guard
            let session = selectedSession,
            let workstream = workstream(id: session.workstreamId),
            let repository = repository(id: workstream.repositoryId)
        else { return nil }

        return SessionDetailContext(repository: repository, workstream: workstream, session: session)
    }

    var orderedSessions: [WorkspaceSession] {
        repositories.flatMap { repository in
            workstreams(in: repository).flatMap { workstream in
                sessions(in: workstream)
            }
        }
    }

    var canAddWorkstream: Bool {
        selectedRepository != nil
    }

    var canAddSession: Bool {
        selectedWorkstream != nil
    }

    var canRenameSelection: Bool {
        selection != nil
    }

    var canDeleteSelection: Bool {
        selection != nil
    }

    func addOrSelectRepository(folderURL: URL) {
        let standardizedPath = folderURL.standardizedFileURL.path

        if let existingRepository = store.snapshot.repositories.first(where: {
            URL(fileURLWithPath: $0.folderPath).standardizedFileURL.path == standardizedPath
        }) {
            expandedRepositoryIDs.insert(existingRepository.id)
            selection = .repository(existingRepository.id)
            return
        }

        let repository = Repository(
            name: folderURL.lastPathComponent,
            folderPath: standardizedPath,
            lastOpenedAt: .now
        )

        store.update { snapshot in
            snapshot.repositories.append(repository)
        }

        expandedRepositoryIDs.insert(repository.id)
        selection = .repository(repository.id)
    }

    func createRepository(name: String, folderPath: String) {
        let repository = Repository(name: name, folderPath: folderPath)
        store.update { snapshot in
            snapshot.repositories.append(repository)
        }
        expandedRepositoryIDs.insert(repository.id)
        selection = .repository(repository.id)
    }

    func renameRepository(id: UUID, name: String) {
        store.update { snapshot in
            guard let index = snapshot.repositories.firstIndex(where: { $0.id == id }) else { return }
            snapshot.repositories[index].name = name
        }
    }

    func deleteRepository(id: UUID) {
        let workstreamIDs = store.snapshot.workstreams
            .filter { $0.repositoryId == id }
            .map(\.id)

        store.update { snapshot in
            snapshot.sessions.removeAll { workstreamIDs.contains($0.workstreamId) }
            snapshot.workstreams.removeAll { $0.repositoryId == id }
            snapshot.repositories.removeAll { $0.id == id }
        }

        expandedRepositoryIDs.remove(id)
        expandedWorkstreamIDs.subtract(workstreamIDs)
        clearSelectionIfNeeded(forDeletedRepository: id, workstreamIDs: Set(workstreamIDs), sessionIDs: [])
    }

    func createWorkstream(repositoryID: UUID, name: String, description: String?) {
        let workstream = Workstream(repositoryId: repositoryID, name: name, description: description)
        store.update { snapshot in
            snapshot.workstreams.append(workstream)
        }
        expandedRepositoryIDs.insert(repositoryID)
        expandedWorkstreamIDs.insert(workstream.id)
        selection = .workstream(workstream.id)
    }

    func renameWorkstream(id: UUID, name: String, description: String?) {
        store.update { snapshot in
            guard let index = snapshot.workstreams.firstIndex(where: { $0.id == id }) else { return }
            snapshot.workstreams[index].name = name
            snapshot.workstreams[index].description = normalizeOptional(description)
        }
    }

    func deleteWorkstream(id: UUID) {
        let sessionIDs = store.snapshot.sessions
            .filter { $0.workstreamId == id }
            .map(\.id)

        store.update { snapshot in
            snapshot.sessions.removeAll { $0.workstreamId == id }
            snapshot.workstreams.removeAll { $0.id == id }
        }

        expandedWorkstreamIDs.remove(id)
        clearSelectionIfNeeded(forDeletedWorkstream: id, sessionIDs: Set(sessionIDs))
    }

    func createSession(workstreamID: UUID, name: String) {
        let sessionName = normalizedSessionName(from: name)
        let session = WorkspaceSession(workstreamId: workstreamID, name: sessionName)
        store.update { snapshot in
            snapshot.sessions.append(session)
        }
        expandedWorkstreamIDs.insert(workstreamID)
        selection = .session(session.id)
    }

    func renameSession(id: UUID, name: String) {
        store.update { snapshot in
            guard let index = snapshot.sessions.firstIndex(where: { $0.id == id }) else { return }
            snapshot.sessions[index].name = name
        }
    }

    func deleteSession(id: UUID) {
        store.update { snapshot in
            snapshot.sessions.removeAll { $0.id == id }
        }

        if selection == .session(id) {
            selection = nil
        }
    }

    func updateWorkstreamMemory(workstreamID: UUID, memory: WorkstreamMemory) {
        store.update { snapshot in
            guard let index = snapshot.workstreams.firstIndex(where: { $0.id == workstreamID }) else { return }
            guard snapshot.workstreams[index].memory != memory else { return }
            let revision = WorkstreamMemoryRevision(memory: memory)
            snapshot.workstreams[index].memory = memory
            snapshot.workstreams[index].memoryHistory.append(revision)
            if snapshot.workstreams[index].memoryHistory.count > 10 {
                snapshot.workstreams[index].memoryHistory.removeFirst(snapshot.workstreams[index].memoryHistory.count - 10)
            }
        }
    }

    func manuallyCorrectWorkstreamMemory(workstreamID: UUID, memory: WorkstreamMemory) {
        let currentRevision = workstream(id: workstreamID)?.memory?.revision ?? 0
        var corrected = memory
        corrected.updatedAt = .now
        corrected.revision = max(currentRevision + 1, corrected.revision)
        updateWorkstreamMemory(workstreamID: workstreamID, memory: corrected)
    }

    func undoLastWorkstreamMemoryUpdate(workstreamID: UUID) {
        store.update { snapshot in
            guard let index = snapshot.workstreams.firstIndex(where: { $0.id == workstreamID }) else { return }
            guard snapshot.workstreams[index].memoryHistory.count >= 2 else { return }

            snapshot.workstreams[index].memoryHistory.removeLast()
            snapshot.workstreams[index].memory = snapshot.workstreams[index].memoryHistory.last?.memory
        }
    }

    func setClaudeSessionIdentifier(_ identifier: String?, for sessionID: UUID) {
        store.update { snapshot in
            guard let index = snapshot.sessions.firstIndex(where: { $0.id == sessionID }) else { return }
            snapshot.sessions[index].claudeSessionIdentifier = identifier
        }
    }

    func selectSession(id: UUID) {
        revealSession(id: id)
        touchSessionHierarchy(sessionID: id)
    }

    func selectRepository(id: UUID) {
        revealRepository(id: id)
    }

    func selectWorkstream(id: UUID) {
        revealWorkstream(id: id)
    }

    func revealSelection(_ selection: SidebarSelection) {
        switch selection {
        case .repository(let id):
            revealRepository(id: id)
        case .workstream(let id):
            revealWorkstream(id: id)
        case .session(let id):
            revealSession(id: id)
        }
    }

    func selectAdjacentSession(offset: Int) {
        guard !orderedSessions.isEmpty else { return }

        let currentID = selectedSession?.id
        let currentIndex = orderedSessions.firstIndex { $0.id == currentID } ?? 0
        let nextIndex = min(max(currentIndex + offset, 0), orderedSessions.count - 1)
        selectSession(id: orderedSessions[nextIndex].id)
    }

    func toggleRepositoryExpansion(_ repositoryID: UUID) {
        if expandedRepositoryIDs.contains(repositoryID) {
            expandedRepositoryIDs.remove(repositoryID)
        } else {
            expandedRepositoryIDs.insert(repositoryID)
        }
    }

    func toggleWorkstreamExpansion(_ workstreamID: UUID) {
        if expandedWorkstreamIDs.contains(workstreamID) {
            expandedWorkstreamIDs.remove(workstreamID)
        } else {
            expandedWorkstreamIDs.insert(workstreamID)
        }
    }

    private func touchSessionHierarchy(sessionID: UUID) {
        let now = Date()

        store.update { snapshot in
            guard
                let sessionIndex = snapshot.sessions.firstIndex(where: { $0.id == sessionID })
            else { return }

            snapshot.sessions[sessionIndex].lastOpenedAt = now
            let workstreamID = snapshot.sessions[sessionIndex].workstreamId

            guard let workstreamIndex = snapshot.workstreams.firstIndex(where: { $0.id == workstreamID }) else { return }
            snapshot.workstreams[workstreamIndex].lastOpenedAt = now
            let repositoryID = snapshot.workstreams[workstreamIndex].repositoryId

            guard let repositoryIndex = snapshot.repositories.firstIndex(where: { $0.id == repositoryID }) else { return }
            snapshot.repositories[repositoryIndex].lastOpenedAt = now
        }
    }

    private func revealRepository(id: UUID) {
        expandedRepositoryIDs.insert(id)
        selection = .repository(id)
    }

    private func revealWorkstream(id: UUID) {
        guard let workstream = workstream(id: id) else { return }
        expandedRepositoryIDs.insert(workstream.repositoryId)
        expandedWorkstreamIDs.insert(workstream.id)
        selection = .workstream(id)
    }

    private func revealSession(id: UUID) {
        guard
            let session = session(id: id),
            let workstream = workstream(id: session.workstreamId)
        else { return }

        expandedRepositoryIDs.insert(workstream.repositoryId)
        expandedWorkstreamIDs.insert(workstream.id)
        selection = .session(id)
    }

    private func clearSelectionIfNeeded(
        forDeletedRepository repositoryID: UUID,
        workstreamIDs: Set<UUID>,
        sessionIDs: Set<UUID>
    ) {
        switch selection {
        case .repository(let selectedID) where selectedID == repositoryID:
            selection = nil
        case .workstream(let selectedID) where workstreamIDs.contains(selectedID):
            selection = nil
        case .session(let selectedID) where sessionIDs.contains(selectedID):
            selection = nil
        default:
            break
        }
    }

    private func clearSelectionIfNeeded(forDeletedWorkstream workstreamID: UUID, sessionIDs: Set<UUID>) {
        switch selection {
        case .workstream(let selectedID) where selectedID == workstreamID:
            selection = nil
        case .session(let selectedID) where sessionIDs.contains(selectedID):
            selection = nil
        default:
            break
        }
    }

    private func normalizeOptional(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private func normalizedSessionName(from value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "Session — \(Date.now.formatted(date: .abbreviated, time: .shortened))"
        }
        return trimmed
    }

    private func persistUIState() {
        store.update { snapshot in
            snapshot.uiState = WorkspaceUIState(
                selection: selection,
                expandedRepositoryIDs: expandedRepositoryIDs,
                expandedWorkstreamIDs: expandedWorkstreamIDs
            )
        }
    }

    private func sanitizePersistedUIState() {
        let repositoryIDs = Set(store.snapshot.repositories.map(\.id))
        let workstreamIDs = Set(store.snapshot.workstreams.map(\.id))
        let sessionIDs = Set(store.snapshot.sessions.map(\.id))

        expandedRepositoryIDs = expandedRepositoryIDs.intersection(repositoryIDs)
        expandedWorkstreamIDs = expandedWorkstreamIDs.intersection(workstreamIDs)

        switch selection {
        case .repository(let id) where !repositoryIDs.contains(id):
            selection = nil
        case .workstream(let id) where !workstreamIDs.contains(id):
            selection = nil
        case .session(let id) where !sessionIDs.contains(id):
            selection = nil
        default:
            break
        }
    }
}
