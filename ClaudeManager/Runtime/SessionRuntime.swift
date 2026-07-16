import Foundation
import Combine

@MainActor
final class SessionRuntime: ObservableObject {
    let sessionID: UUID
    let claudeTerminal: TerminalSessionController
    let shellTerminal: TerminalSessionController
    private var cancellables: Set<AnyCancellable> = []

    init(sessionID: UUID, workingDirectory: String, claudeStartupCommand: String) {
        self.sessionID = sessionID
        self.claudeTerminal = TerminalSessionController(
            workingDirectory: workingDirectory,
            launchBehavior: .claude(startupCommand: claudeStartupCommand)
        )
        self.shellTerminal = TerminalSessionController(
            workingDirectory: workingDirectory,
            launchBehavior: .shell
        )

        claudeTerminal.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        shellTerminal.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    func startIfNeeded() {
        claudeTerminal.startIfNeeded()
        shellTerminal.startIfNeeded()
    }

    var isRunning: Bool {
        claudeTerminal.state == .running || shellTerminal.state == .running
    }

    var aggregateState: TerminalRuntimeState {
        let states = [claudeTerminal.state, shellTerminal.state]

        if states.contains(.running) {
            return .running
        }

        if let failedState = states.first(where: {
            if case .failed = $0 { return true }
            return false
        }) {
            return failedState
        }

        if let exitedState = states.first(where: {
            if case .exited = $0 { return true }
            return false
        }) {
            return exitedState
        }

        return .notStarted
    }

    func terminate() {
        claudeTerminal.terminate()
        shellTerminal.terminate()
    }
}
