import Foundation

enum HandoffPromptBuilder {
    static func handoffPrompt(
        workstreamName: String,
        sessionName: String,
        existingMemory: WorkstreamMemory?
    ) -> String {
        """
        You are generating Workstream Memory for a future Claude Code session.

        Workstream name: \(workstreamName)
        Source session name: \(sessionName)

        Existing Workstream Memory:
        \(existingMemory.map(memoryJSON) ?? "null")

        Update the Workstream Memory using only durable information that will help a future session continue the work.

        Requirements:
        - Preserve still-valid existing memory
        - Update stale information
        - Record completed work in Current State or Decisions
        - Record important technical decisions and reasoning
        - Record remaining work
        - Record unresolved risks or unknowns
        - Avoid conversational detail
        - Avoid copying large code blocks
        - Avoid claiming work is complete unless supported by the session
        - Return only valid JSON matching the requested structure

        Return JSON with this shape:
        {
          "objective": "string",
          "currentState": "string",
          "decisions": ["string"],
          "openWork": ["string"],
          "risksAndUnknowns": ["string"]
        }
        """
    }

    static func startupPrompt(
        workstreamName: String,
        sessionName: String,
        memory: WorkstreamMemory
    ) -> String {
        """
        Starting a new Claude Code session for workstream "\(workstreamName)".

        This Workstream Memory is a prior handoff and may need verification.
        Please inspect the repository before assuming every detail is current.

        Session name: \(sessionName)

        Workstream Memory:
        \(memoryJSON(memory))
        """
    }

    static func outputSchema() -> String {
        """
        {
          "type": "object",
          "properties": {
            "objective": { "type": "string" },
            "currentState": { "type": "string" },
            "decisions": {
              "type": "array",
              "items": { "type": "string" }
            },
            "openWork": {
              "type": "array",
              "items": { "type": "string" }
            },
            "risksAndUnknowns": {
              "type": "array",
              "items": { "type": "string" }
            }
          },
          "required": ["objective", "currentState", "decisions", "openWork", "risksAndUnknowns"],
          "additionalProperties": false
        }
        """
    }

    private static func memoryJSON(_ memory: WorkstreamMemory) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = (try? encoder.encode(memory)) ?? Data("null".utf8)
        return String(decoding: data, as: UTF8.self)
    }
}
