import Foundation

public enum ExportMode: String, CaseIterable, Identifiable, Sendable {
    case conversation = "Conversation"
    case activity = "Conversation + Activity"
    case archive = "Raw Archival Transcript"

    public var id: String { rawValue }

    public var description: String {
        switch self {
        case .conversation:
            return "User and assistant messages only."
        case .activity:
            return "Messages plus collapsible tool calls, commands, patches, and outputs."
        case .archive:
            return "Every JSONL record, preserved in order inside Markdown."
        }
    }
}

public struct SessionSummary: Identifiable, Hashable, Sendable {
    public let id: String
    public let url: URL
    public let title: String
    public let timestamp: Date?
    public let cwd: String?
    public let source: String?
    public let cliVersion: String?
    public let modelProvider: String?
    public let size: Int64
    public let isArchived: Bool

    public init(id: String, url: URL, title: String, timestamp: Date?, cwd: String?, source: String?, cliVersion: String?, modelProvider: String?, size: Int64, isArchived: Bool) {
        self.id = id
        self.url = url
        self.title = title
        self.timestamp = timestamp
        self.cwd = cwd
        self.source = source
        self.cliVersion = cliVersion
        self.modelProvider = modelProvider
        self.size = size
        self.isArchived = isArchived
    }

    public var projectName: String {
        guard let cwd, !cwd.isEmpty else { return title }
        let name = URL(fileURLWithPath: cwd).standardizedFileURL.lastPathComponent
        return name.isEmpty ? title : name
    }
}

public struct PreviewResult: Sendable {
    public let markdown: String
    public let blocks: [TranscriptBlock]
    public let truncated: Bool
    public let recordCount: Int

    public init(markdown: String, blocks: [TranscriptBlock] = [], truncated: Bool, recordCount: Int) {
        self.markdown = markdown
        self.blocks = blocks
        self.truncated = truncated
        self.recordCount = recordCount
    }
}

public enum TranscriptBlockKind: String, Hashable, Sendable {
    case user
    case assistant
    case toolCall
    case toolOutput
    case command
    case activity
    case notice
    case raw
}

public struct TranscriptBlock: Identifiable, Hashable, Sendable {
    public let id: Int
    public let kind: TranscriptBlockKind
    public let title: String
    public let content: String
    public let detail: String?

    public init(id: Int, kind: TranscriptBlockKind, title: String, content: String, detail: String? = nil) {
        self.id = id
        self.kind = kind
        self.title = title
        self.content = content
        self.detail = detail
    }
}

public enum TranscriptError: LocalizedError {
    case unreadableSession(URL)
    case invalidDestination(URL)

    public var errorDescription: String? {
        switch self {
        case .unreadableSession(let url): return "Could not read session: \(url.path)"
        case .invalidDestination(let url): return "Could not write export: \(url.path)"
        }
    }
}
