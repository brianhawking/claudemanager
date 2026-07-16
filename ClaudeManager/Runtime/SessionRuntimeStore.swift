import Foundation
import Combine

@MainActor
final class SessionRuntimeStore: ObservableObject {
    private var runtimes: [UUID: SessionRuntime] = [:]
    private var cancellables: [UUID: AnyCancellable] = [:]

    func runtimeIfPresent(for sessionID: UUID) -> SessionRuntime? {
        runtimes[sessionID]
    }

    func sessionState(for sessionID: UUID) -> TerminalRuntimeState {
        runtimes[sessionID]?.aggregateState ?? .notStarted
    }

    func startSession(for detail: SessionDetailContext, claudeStartupCommand: String) -> SessionRuntime {
        if let existing = runtimes[detail.session.id], existing.isRunning {
            return existing
        }

        if let existing = runtimes.removeValue(forKey: detail.session.id) {
            existing.terminate()
        }

        let runtime = SessionRuntime(
            sessionID: detail.session.id,
            workingDirectory: detail.repository.folderPath,
            claudeStartupCommand: claudeStartupCommand
        )
        runtimes[detail.session.id] = runtime
        bind(runtime, for: detail.session.id)
        runtime.startIfNeeded()
        objectWillChange.send()
        return runtime
    }

    func runtime(for detail: SessionDetailContext) -> SessionRuntime {
        if let existing = runtimes[detail.session.id] {
            return existing
        }

        let runtime = SessionRuntime(
            sessionID: detail.session.id,
            workingDirectory: detail.repository.folderPath,
            claudeStartupCommand: "claude\n"
        )
        runtimes[detail.session.id] = runtime
        bind(runtime, for: detail.session.id)
        return runtime
    }

    func closeSession(_ sessionID: UUID) {
        removeRuntime(for: sessionID)
    }

    func removeRuntime(for sessionID: UUID) {
        guard let runtime = runtimes.removeValue(forKey: sessionID) else { return }
        cancellables[sessionID] = nil
        runtime.terminate()
        objectWillChange.send()
    }

    func removeRuntimes(for sessionIDs: some Sequence<UUID>) {
        for sessionID in sessionIDs {
            removeRuntime(for: sessionID)
        }
    }

    func terminateAll() {
        for runtime in runtimes.values {
            runtime.terminate()
        }
        runtimes.removeAll()
        cancellables.removeAll()
    }

    private func bind(_ runtime: SessionRuntime, for sessionID: UUID) {
        cancellables[sessionID] = runtime.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
    }
}
