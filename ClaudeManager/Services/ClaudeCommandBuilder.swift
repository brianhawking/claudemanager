import Foundation

enum ClaudeCommandBuilder {
    static func startupCommand(
        sessionIdentifier: String,
        sessionName: String,
        workstreamName: String,
        memory: WorkstreamMemory?
    ) -> String {
        var parts = [
            "claude",
            "--session-id",
            shellQuoted(sessionIdentifier),
            "-n",
            shellQuoted(sessionName)
        ]

        if let memory, memory.hasContent {
            let prompt = HandoffPromptBuilder.startupPrompt(
                workstreamName: workstreamName,
                sessionName: sessionName,
                memory: memory
            )
            parts.append(shellQuoted(prompt))
        }

        return parts.joined(separator: " ") + "\r"
    }

    private static func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\"'\"'"))'"
    }
}
