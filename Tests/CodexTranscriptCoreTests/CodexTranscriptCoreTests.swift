import XCTest
@testable import CodexTranscriptCore

final class CodexTranscriptCoreTests: XCTestCase {
    private var fixture: URL {
        Bundle.module.url(forResource: "sample", withExtension: "jsonl", subdirectory: "Fixtures")!
    }

    func testScannerExtractsMetadataAndTitle() throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let dir = temp.appendingPathComponent("sessions/2026/08/18", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let destination = dir.appendingPathComponent("rollout-sample.jsonl")
        try FileManager.default.copyItem(at: fixture, to: destination)

        let sessions = SessionScanner().scan(codexHome: temp)
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions[0].id, "019-test-session")
        XCTAssertEqual(sessions[0].title, "Find the failing test.")
        XCTAssertEqual(sessions[0].projectName, "Project")
        XCTAssertEqual(sessions[0].cwd, "/Users/example/Project")
    }

    func testConversationDeduplicatesEventAndResponseUserMessage() throws {
        let summary = SessionSummary(id: "019-test-session", url: fixture, title: "Test", timestamp: nil, cwd: nil, source: nil, cliVersion: nil, modelProvider: nil, size: 0, isArchived: false)
        let preview = try TranscriptExporter().preview(session: summary, mode: .conversation)
        XCTAssertEqual(preview.markdown.components(separatedBy: "Find the failing test.").count - 1, 1)
        XCTAssertTrue(preview.markdown.contains("## 🔵 Codex"))
        XCTAssertFalse(preview.markdown.contains("Tool call"))
        XCTAssertEqual(preview.blocks.filter { $0.kind == .user }.count, 1)
        XCTAssertEqual(preview.blocks.filter { $0.kind == .assistant }.count, 1)
    }

    func testActivityIncludesToolCallAndOutput() throws {
        let summary = SessionSummary(id: "019-test-session", url: fixture, title: "Test", timestamp: nil, cwd: nil, source: nil, cliVersion: nil, modelProvider: nil, size: 0, isArchived: false)
        let preview = try TranscriptExporter().preview(session: summary, mode: .activity)
        XCTAssertTrue(preview.markdown.contains("<summary>Tool call — exec_command</summary>"))
        XCTAssertTrue(preview.markdown.contains("Test Suite 'All tests' passed."))
        XCTAssertTrue(preview.markdown.contains("<details>"))
        XCTAssertTrue(preview.blocks.contains { $0.kind == .toolCall && $0.title == "exec_command" })
        XCTAssertTrue(preview.blocks.contains { $0.kind == .toolOutput })
    }

    func testArchivePreservesEveryRecord() throws {
        let summary = SessionSummary(id: "019-test-session", url: fixture, title: "Test", timestamp: nil, cwd: nil, source: nil, cliVersion: nil, modelProvider: nil, size: 0, isArchived: false)
        let preview = try TranscriptExporter().preview(session: summary, mode: .archive)
        XCTAssertEqual(preview.markdown.components(separatedBy: "## Record:").count - 1, 6)
        XCTAssertTrue(preview.markdown.contains("session_meta"))
        XCTAssertTrue(preview.markdown.contains("function_call_output"))
        XCTAssertEqual(preview.blocks.count, 6)
        XCTAssertTrue(preview.blocks.allSatisfy { $0.kind == .raw })
    }
}
