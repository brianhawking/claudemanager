import Foundation

struct HandoffGenerationRequest {
    let repositoryPath: String
    let workstreamName: String
    let sessionName: String
    let claudeSessionIdentifier: String
    let existingMemory: WorkstreamMemory?
}

struct HandoffGenerationResponse: Codable {
    let objective: String
    let currentState: String
    let decisions: [String]
    let openWork: [String]
    let risksAndUnknowns: [String]
}

enum HandoffGenerationError: LocalizedError {
    case missingClaudeCommand
    case processFailed(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .missingClaudeCommand:
            return "Claude could not be found for handoff generation."
        case .processFailed(let message):
            return message
        case .invalidResponse:
            return "Claude returned invalid structured output for Workstream Memory."
        }
    }
}

struct HandoffGenerationService {
    func generateHandoff(request: HandoffGenerationRequest) async throws -> HandoffGenerationResponse {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.currentDirectoryURL = URL(fileURLWithPath: request.repositoryPath)
        process.environment = TerminalEnvironment.resolvedEnvironment()
        process.arguments = [
            "claude",
            "-p",
            "--resume", request.claudeSessionIdentifier,
            "--json-schema", HandoffPromptBuilder.outputSchema(),
            HandoffPromptBuilder.handoffPrompt(
                workstreamName: request.workstreamName,
                sessionName: request.sessionName,
                existingMemory: request.existingMemory
            )
        ]
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw HandoffGenerationError.missingClaudeCommand
        }

        let stdout = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let stderr = errorPipe.fileHandleForReading.readDataToEndOfFile()

        guard process.terminationStatus == 0 else {
            let message = String(decoding: stderr, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            throw HandoffGenerationError.processFailed(message.isEmpty ? "Claude handoff generation failed." : message)
        }

        let decoder = JSONDecoder()
        guard let response = try? decoder.decode(HandoffGenerationResponse.self, from: stdout) else {
            let raw = String(decoding: stdout, as: UTF8.self)
            NSLog("Invalid Workstream Memory JSON response: %@", raw)
            throw HandoffGenerationError.invalidResponse
        }

        return response
    }
}
