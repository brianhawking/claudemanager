import Foundation

enum TerminalEnvironment {
    private static let fallbackPath = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
    private static var cachedLoginPath: String?

    static func shellExecutablePath() -> String {
        let shell = ProcessInfo.processInfo.environment["SHELL"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let shell, !shell.isEmpty {
            return shell
        }
        return "/bin/zsh"
    }

    static func resolvedEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let shellPath = shellExecutablePath()

        environment["SHELL"] = shellPath
        environment["TERM"] = environment["TERM"] ?? "xterm-256color"
        environment["COLORTERM"] = environment["COLORTERM"] ?? "truecolor"
        environment["TERM_PROGRAM"] = "ClaudeManager"

        if let loginPath = loginShellPath(shellPath: shellPath), !loginPath.isEmpty {
            environment["PATH"] = loginPath
        } else if environment["PATH"]?.isEmpty != false {
            environment["PATH"] = fallbackPath
        }

        return environment
    }

    private static func loginShellPath(shellPath: String) -> String? {
        if let cachedLoginPath {
            return cachedLoginPath
        }

        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: shellPath)
        process.arguments = ["-l", "-c", "printf %s \"$PATH\""]
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard process.terminationStatus == 0 else {
            return nil
        }

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let path = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)

        guard !path.isEmpty else {
            return nil
        }

        cachedLoginPath = path
        return path
    }
}
