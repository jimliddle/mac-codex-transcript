import Foundation

public struct SessionScanner: Sendable {
    public init() {}

    public static func defaultCodexHome() -> URL {
        if let configured = ProcessInfo.processInfo.environment["CODEX_HOME"], !configured.isEmpty {
            return URL(fileURLWithPath: configured).standardizedFileURL
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex", isDirectory: true)
    }

    public func scan(codexHome: URL) -> [SessionSummary] {
        let roots: [(URL, Bool)] = [
            (codexHome.appendingPathComponent("sessions", isDirectory: true), false),
            (codexHome.appendingPathComponent("archived_sessions", isDirectory: true), true)
        ]
        var found: [SessionSummary] = []
        for (root, archived) in roots {
            guard let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }

            for case let url as URL in enumerator where url.pathExtension.lowercased() == "jsonl" && url.lastPathComponent.hasPrefix("rollout-") {
                if let summary = summarize(url: url, archived: archived) { found.append(summary) }
            }
        }
        return found.sorted {
            let a = $0.timestamp ?? (try? $0.url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let b = $1.timestamp ?? (try? $1.url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return a > b
        }
    }

    private func summarize(url: URL, archived: Bool) -> SessionSummary? {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        let size = Int64(values?.fileSize ?? 0)
        var id = url.deletingPathExtension().lastPathComponent
        var timestamp: Date?
        var cwd: String?
        var source: String?
        var cliVersion: String?
        var modelProvider: String?
        var firstUserMessage: String?

        guard let reader = try? LineReader(url: url) else { return nil }
        var bytesInspected = 0
        while bytesInspected < 2_000_000 {
            guard let data = try? reader.nextLine() else { break }
            bytesInspected += data.count
            guard !data.isEmpty, let obj = jsonObject(from: data) else { continue }
            let outerType = string(obj["type"]) ?? ""
            let payload = dictionary(obj["payload"]) ?? [:]
            if outerType == "session_meta" {
                id = string(payload["id"]) ?? string(payload["session_id"]) ?? id
                timestamp = parseDate(string(payload["timestamp"]) ?? string(obj["timestamp"]))
                cwd = string(payload["cwd"])
                source = string(payload["source"])
                cliVersion = string(payload["cli_version"])
                modelProvider = string(payload["model_provider"])
            } else if outerType == "event_msg", string(payload["type"]) == "user_message" {
                firstUserMessage = string(payload["message"])
                break
            } else if outerType == "response_item", string(payload["type"]) == "message", string(payload["role"]) == "user" {
                firstUserMessage = extractMessageText(payload)
                break
            }
        }

        let title = makeTitle(firstUserMessage) ?? url.deletingPathExtension().lastPathComponent
        return SessionSummary(id: id, url: url, title: title, timestamp: timestamp, cwd: cwd, source: source, cliVersion: cliVersion, modelProvider: modelProvider, size: size, isArchived: archived)
    }

    private func makeTitle(_ message: String?) -> String? {
        guard let message else { return nil }
        let normalized = message.replacingOccurrences(of: "\n", with: " ").split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        guard !normalized.isEmpty else { return nil }
        if normalized.count <= 72 { return normalized }
        let end = normalized.index(normalized.startIndex, offsetBy: 69)
        return String(normalized[..<end]) + "…"
    }
}
