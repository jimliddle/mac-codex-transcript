import Foundation

public struct TranscriptExporter: Sendable {
    public init() {}

    public func preview(session: SessionSummary, mode: ExportMode, maxRecords: Int = 800, maxCharacters: Int = 350_000) throws -> PreviewResult {
        var output = header(for: session, mode: mode)
        var blocks: [TranscriptBlock] = []
        let reader = try LineReader(url: session.url)
        var count = 0
        var truncated = false
        var messageSignatures = Set<String>()

        while let data = try reader.nextLine() {
            guard !data.isEmpty else { continue }
            count += 1
            if count > maxRecords || output.count > maxCharacters {
                truncated = true
                break
            }
            if let record = render(data: data, mode: mode, messageSignatures: &messageSignatures), !record.markdown.isEmpty {
                output += record.markdown
                blocks.append(record.block(id: blocks.count))
            }
        }
        if truncated {
            output += "\n---\n\n> Preview truncated for performance. Export writes the complete selected transcript.\n"
            blocks.append(TranscriptBlock(
                id: blocks.count,
                kind: .notice,
                title: "Preview truncated",
                content: "Export Markdown writes the complete selected transcript."
            ))
        }
        return PreviewResult(markdown: output, blocks: blocks, truncated: truncated, recordCount: count)
    }

    public func export(session: SessionSummary, mode: ExportMode, to destination: URL) throws {
        _ = FileManager.default.createFile(atPath: destination.path, contents: nil)
        guard let handle = try? FileHandle(forWritingTo: destination) else { throw TranscriptError.invalidDestination(destination) }
        defer { try? handle.close() }
        try write(header(for: session, mode: mode), to: handle)

        let reader = try LineReader(url: session.url)
        var messageSignatures = Set<String>()
        while let data = try reader.nextLine() {
            guard !data.isEmpty else { continue }
            if let record = render(data: data, mode: mode, messageSignatures: &messageSignatures), !record.markdown.isEmpty {
                try write(record.markdown, to: handle)
            }
        }
    }

    private func write(_ string: String, to handle: FileHandle) throws {
        if let data = string.data(using: .utf8) { try handle.write(contentsOf: data) }
    }

    private func header(for session: SessionSummary, mode: ExportMode) -> String {
        var details = [
            "- **Export:** \(mode.rawValue)",
            "- **Session ID:** \(inlineCode(session.id))",
            "- **Source file:** \(inlineCode(session.url.path))"
        ]
        if let timestamp = session.timestamp { details.append("- **Date:** \(ISO8601DateFormatter().string(from: timestamp))") }
        if let cwd = session.cwd { details.append("- **Working directory:** \(inlineCode(cwd))") }
        if let source = session.source { details.append("- **Source:** \(markdownEscapedInline(source))") }
        if let cli = session.cliVersion { details.append("- **Codex CLI:** \(markdownEscapedInline(cli))") }
        if let provider = session.modelProvider { details.append("- **Model provider:** \(markdownEscapedInline(provider))") }
        if session.isArchived { details.append("- **Status:** Archived") }

        var output = "# \(markdownEscapedInline(session.projectName))\n\n"
        if session.projectName != session.title {
            output += "> \(markdownEscapedInline(session.title))\n\n"
        }
        output += "<details>\n<summary>Session details</summary>\n\n"
        output += details.joined(separator: "\n")
        output += "\n\n</details>\n\n---\n\n"
        return output
    }

    private func render(data: Data, mode: ExportMode, messageSignatures: inout Set<String>) -> RenderedRecord? {
        if mode == .archive {
            let raw = String(data: data, encoding: .utf8) ?? "<non-UTF8 JSONL record>"
            guard let obj = jsonObject(from: data) else {
                return RenderedRecord(
                    markdown: "## Unparseable record\n\n\(markdownFence(for: raw, language: "json"))\n\n",
                    kind: .raw,
                    title: "Unparseable record",
                    content: raw
                )
            }
            let outerType = string(obj["type"]) ?? "unknown"
            let timestamp = string(obj["timestamp"]).map { " — `\($0)`" } ?? ""
            return RenderedRecord(
                markdown: "## Record: `\(outerType)`\(timestamp)\n\n\(markdownFence(for: raw, language: "json"))\n\n",
                kind: .raw,
                title: outerType,
                content: raw,
                detail: string(obj["timestamp"])
            )
        }

        guard let obj = jsonObject(from: data) else { return nil }
        let outerType = string(obj["type"]) ?? ""
        let payload = dictionary(obj["payload"]) ?? [:]

        switch outerType {
        case "response_item":
            return renderResponseItem(payload, mode: mode, signatures: &messageSignatures)
        case "event_msg":
            return renderEvent(payload, mode: mode, signatures: &messageSignatures)
        case "compacted":
            guard mode == .activity else { return nil }
            return RenderedRecord(
                markdown: "> **Context compacted:** Codex compacted the active context at this point in the session.\n\n",
                kind: .notice,
                title: "Context compacted",
                content: "Codex compacted the active context at this point in the session."
            )
        default:
            return nil
        }
    }

    private func renderResponseItem(_ payload: JSONObject, mode: ExportMode, signatures: inout Set<String>) -> RenderedRecord? {
        let type = string(payload["type"]) ?? ""
        switch type {
        case "message":
            let role = string(payload["role"]) ?? "unknown"
            let text = extractMessageText(payload)
            guard !text.isEmpty, role == "user" || role == "assistant" else { return nil }
            return renderMessage(role: role, text: text, signatures: &signatures)
        case "function_call":
            guard mode == .activity else { return nil }
            let name = string(payload["name"]) ?? "function"
            let callID = string(payload["call_id"])
            let args = parsePossiblyJSONString(payload["arguments"])
            var body = ""
            if let callID { body += "**Call ID:** \(inlineCode(callID))\n\n" }
            if !args.isEmpty { body += markdownFence(for: args, language: "json") }
            let result = collapsibleDetails(summary: "Tool call — \(name)", body: body.isEmpty ? "No arguments" : body)
            return RenderedRecord(markdown: result, kind: .toolCall, title: name, content: args.isEmpty ? "No arguments" : args, detail: callID)
        case "function_call_output", "custom_tool_call_output", "local_shell_call_output", "shell_call_output", "computer_call_output":
            guard mode == .activity else { return nil }
            let callID = string(payload["call_id"])
            let output = string(payload["output"]) ?? string(payload["content"]) ?? prettyJSON(payload)
            var body = ""
            if let callID { body += "**Call ID:** \(inlineCode(callID))\n\n" }
            body += markdownFence(for: output)
            let result = collapsibleDetails(summary: "Tool output", body: body)
            return RenderedRecord(markdown: result, kind: .toolOutput, title: "Tool output", content: output, detail: callID)
        case "local_shell_call", "shell_call":
            guard mode == .activity else { return nil }
            let command = string(payload["command"]) ?? string(payload["input"]) ?? prettyJSON(payload)
            return RenderedRecord(
                markdown: collapsibleDetails(summary: "Shell command", body: markdownFence(for: command, language: "bash")),
                kind: .command,
                title: "Shell command",
                content: command
            )
        case "custom_tool_call", "mcp_call", "web_search_call", "file_search_call", "tool_search_call", "computer_call", "apply_patch_call":
            guard mode == .activity else { return nil }
            return RenderedRecord(
                markdown: collapsibleDetails(summary: "Activity — \(activityTitle(type))", body: markdownFence(for: prettyJSON(payload), language: "json")),
                kind: .activity,
                title: activityTitle(type),
                content: prettyJSON(payload),
                detail: type
            )
        default:
            return nil
        }
    }

    private func renderEvent(_ payload: JSONObject, mode: ExportMode, signatures: inout Set<String>) -> RenderedRecord? {
        let type = string(payload["type"]) ?? ""
        switch type {
        case "user_message":
            let text = string(payload["message"]) ?? ""
            return text.isEmpty ? nil : renderMessage(role: "user", text: text, signatures: &signatures)
        case "agent_message":
            let text = string(payload["message"]) ?? ""
            return text.isEmpty ? nil : renderMessage(role: "assistant", text: text, signatures: &signatures)
        case "exec_command_end":
            guard mode == .activity else { return nil }
            let command: String
            if let parts = payload["command"] as? [String] { command = parts.joined(separator: " ") }
            else { command = string(payload["command"]) ?? "" }
            let cwd = string(payload["cwd"])
            let exitCode = string(payload["exit_code"])
            var body = ""
            if !command.isEmpty { body += markdownFence(for: command, language: "bash") + "\n\n" }
            if let cwd { body += "- **Working directory:** \(inlineCode(cwd))\n" }
            if let exitCode { body += "- **Exit code:** \(inlineCode(exitCode))\n" }
            let result = collapsibleDetails(summary: "Command completed", body: body)
            var content = command
            if let cwd { content += "\n\nWorking directory: \(cwd)" }
            return RenderedRecord(markdown: result, kind: .command, title: "Command completed", content: content, detail: exitCode.map { "Exit \($0)" })
        case "patch_apply_begin", "patch_apply_end", "mcp_tool_call_begin", "mcp_tool_call_end":
            guard mode == .activity else { return nil }
            return RenderedRecord(
                markdown: collapsibleDetails(summary: "Activity — \(activityTitle(type))", body: markdownFence(for: prettyJSON(payload), language: "json")),
                kind: .activity,
                title: activityTitle(type),
                content: prettyJSON(payload),
                detail: type
            )
        default:
            return nil
        }
    }

    private func renderMessage(role: String, text: String, signatures: inout Set<String>) -> RenderedRecord? {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let signature = role + "\u{1F}" + normalized
        guard !signatures.contains(signature) else { return nil }
        signatures.insert(signature)
        let heading = role == "user" ? "🟠 You" : "🔵 Codex"
        return RenderedRecord(
            markdown: "## \(heading)\n\n\(normalized)\n\n---\n\n",
            kind: role == "user" ? .user : .assistant,
            title: role == "user" ? "You" : "Codex",
            content: normalized
        )
    }

    private func activityTitle(_ type: String) -> String {
        type.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private func collapsibleDetails(summary: String, body: String) -> String {
        "<details>\n<summary>\(htmlEscaped(summary))</summary>\n\n\(body)\n\n</details>\n\n"
    }

    private func inlineCode(_ value: String) -> String {
        var ticks = "`"
        while value.contains(ticks) { ticks += "`" }
        return "\(ticks)\(value)\(ticks)"
    }

    private func markdownEscapedInline(_ value: String) -> String {
        var escaped = value.replacingOccurrences(of: "\\", with: "\\\\")
        for character in ["`", "*", "_", "{", "}", "[", "]", "<", ">", "#"] {
            escaped = escaped.replacingOccurrences(of: character, with: "\\\(character)")
        }
        return escaped.replacingOccurrences(of: "\n", with: " ")
    }

    private func htmlEscaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}

private struct RenderedRecord {
    let markdown: String
    let kind: TranscriptBlockKind
    let title: String
    let content: String
    var detail: String?

    func block(id: Int) -> TranscriptBlock {
        TranscriptBlock(id: id, kind: kind, title: title, content: content, detail: detail)
    }
}
