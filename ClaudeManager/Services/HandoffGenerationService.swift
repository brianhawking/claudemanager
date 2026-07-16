import Foundation

struct HandoffGenerationRequest {
    let repositoryPath: String
    let workstreamName: String
    let sessionName: String
    let claudeSessionIdentifier: String?
    let existingMemory: WorkstreamMemory?
}

struct HandoffGenerationResponse: Codable {
    let objective: String
    let currentState: String
    let decisions: [String]
    let openWork: [String]
    let risksAndUnknowns: [String]
}

private struct ClaudeStructuredOutputEnvelope: Codable {
    let structuredOutput: HandoffGenerationResponse?

    private enum CodingKeys: String, CodingKey {
        case structuredOutput = "structured_output"
    }
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
        let prompt = HandoffPromptBuilder.handoffPrompt(
            workstreamName: request.workstreamName,
            sessionName: request.sessionName,
            existingMemory: request.existingMemory
        )

        if let sessionIdentifier = request.claudeSessionIdentifier, !sessionIdentifier.isEmpty {
            do {
                return try runClaude(
                    repositoryPath: request.repositoryPath,
                    arguments: [
                        "claude",
                        "-p",
                        "--output-format", "json",
                        "--resume", sessionIdentifier,
                        "--json-schema", HandoffPromptBuilder.outputSchema(),
                        prompt
                    ]
                )
            } catch let error as HandoffGenerationError {
                if case .processFailed(let message) = error,
                   message.localizedCaseInsensitiveContains("No conversation found with session ID") {
                    return try runClaude(
                        repositoryPath: request.repositoryPath,
                        arguments: [
                            "claude",
                            "-c",
                            "-p",
                            "--output-format", "json",
                            "--json-schema", HandoffPromptBuilder.outputSchema(),
                            prompt
                        ]
                    )
                }

                throw error
            }
        }

        return try runClaude(
            repositoryPath: request.repositoryPath,
            arguments: [
                "claude",
                "-c",
                "-p",
                "--output-format", "json",
                "--json-schema", HandoffPromptBuilder.outputSchema(),
                prompt
            ]
        )
    }

    private func runClaude(repositoryPath: String, arguments: [String]) throws -> HandoffGenerationResponse {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.currentDirectoryURL = URL(fileURLWithPath: repositoryPath)
        process.environment = TerminalEnvironment.resolvedEnvironment()
        process.arguments = arguments
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

        return try decodeResponse(from: stdout)
    }

    private func decodeResponse(from stdout: Data) throws -> HandoffGenerationResponse {
        let decoder = JSONDecoder()

        if let envelope = try? decoder.decode(ClaudeStructuredOutputEnvelope.self, from: stdout),
           let structuredOutput = envelope.structuredOutput {
            return structuredOutput
        }

        if let directResponse = try? decoder.decode(HandoffGenerationResponse.self, from: stdout) {
            return directResponse
        }

        let raw = String(decoding: stdout, as: UTF8.self)
        NSLog("Invalid Workstream Memory JSON response: %@", raw)
        throw HandoffGenerationError.invalidResponse
    }
}
