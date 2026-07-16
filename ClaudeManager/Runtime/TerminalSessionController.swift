import AppKit
import Foundation
import SwiftTerm

enum TerminalRuntimeState: Equatable {
    case notStarted
    case running
    case exited(code: Int32)
    case failed(message: String)

    var displayName: String {
        switch self {
        case .notStarted:
            return "Not Started"
        case .running:
            return "Running"
        case .exited:
            return "Exited"
        case .failed:
            return "Failed"
        }
    }
}

enum TerminalLaunchBehavior {
    case shell
    case claude(startupCommand: String)
}

@MainActor
final class TerminalSessionController: NSObject, ObservableObject {
    @Published private(set) var state: TerminalRuntimeState = .notStarted
    @Published private(set) var currentDirectory: String?

    let terminalView: LocalProcessTerminalView

    private let shellPath: String
    private let workingDirectory: String
    private let launchBehavior: TerminalLaunchBehavior
    private let startupDelayNanoseconds: UInt64 = 150_000_000
    private var hasStarted = false
    private var pendingStartupTask: Task<Void, Never>?

    init(workingDirectory: String, launchBehavior: TerminalLaunchBehavior) {
        self.workingDirectory = workingDirectory
        self.launchBehavior = launchBehavior
        self.shellPath = TerminalEnvironment.shellExecutablePath()
        self.terminalView = LocalProcessTerminalView(frame: .zero)
        super.init()

        terminalView.processDelegate = self
        terminalView.configureNativeColors()
        terminalView.nativeBackgroundColor = NSColor.textBackgroundColor
        terminalView.nativeForegroundColor = NSColor.textColor
    }

    func startIfNeeded() {
        guard !hasStarted else { return }

        hasStarted = true
        currentDirectory = workingDirectory

        let environment = TerminalEnvironment.resolvedEnvironment()
        terminalView.startProcess(
            executable: shellPath,
            args: ["-l"],
            environment: environment.map { "\($0.key)=\($0.value)" },
            execName: nil,
            currentDirectory: workingDirectory
        )

        state = terminalView.process.running ? .running : .failed(message: "Unable to start shell process.")

        guard terminalView.process.running else { return }

        switch launchBehavior {
        case .shell:
            return
        case .claude(let startupCommand):
            pendingStartupTask = Task { @MainActor [weak self] in
                guard let self else { return }
                try? await Task.sleep(nanoseconds: startupDelayNanoseconds)
                send(text: startupCommand)
            }
        }
    }

    func terminate() {
        pendingStartupTask?.cancel()
        pendingStartupTask = nil

        if terminalView.process.running {
            terminalView.terminate()
        }
    }

    func send(text: String) {
        let bytes = Array(text.utf8)
        terminalView.send(source: terminalView, data: bytes[...])
    }
}

extension TerminalSessionController: LocalProcessTerminalViewDelegate {
    nonisolated func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

    nonisolated func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}

    nonisolated func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            currentDirectory = directory ?? workingDirectory
        }
    }

    nonisolated func processTerminated(source: TerminalView, exitCode: Int32?) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            pendingStartupTask?.cancel()
            pendingStartupTask = nil

            if let exitCode {
                state = .exited(code: exitCode)
            } else {
                state = .failed(message: "The terminal process ended unexpectedly.")
            }
        }
    }
}
