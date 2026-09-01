#if os(macOS)
import AppKit
import CodexTranscriptCore
import Foundation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class AppModel: ObservableObject {
    @Published var codexHome: URL
    @Published var sessions: [SessionSummary] = []
    @Published var selected: SessionSummary?
    @Published var mode: ExportMode = .conversation
    @Published var preview = "Select a session to preview its Markdown export."
    @Published var previewBlocks: [TranscriptBlock] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText = ""

    private let scanner = SessionScanner()
    private let exporter = TranscriptExporter()
    private var previewTask: Task<Void, Never>?

    init() {
        if let saved = UserDefaults.standard.string(forKey: "CodexHome") {
            codexHome = URL(fileURLWithPath: saved)
        } else {
            codexHome = SessionScanner.defaultCodexHome()
        }
    }

    var filteredSessions: [SessionSummary] {
        guard !searchText.isEmpty else { return sessions }
        let query = searchText.lowercased()
        return sessions.filter {
            $0.title.lowercased().contains(query) ||
            ($0.cwd?.lowercased().contains(query) ?? false) ||
            $0.id.lowercased().contains(query)
        }
    }

    func refresh() {
        isLoading = true
        errorMessage = nil
        let home = codexHome
        Task.detached { [scanner] in
            scanner.scan(codexHome: home)
        }.mapToMain { [weak self] result in
            guard let self else { return }
            self.sessions = result
            if self.selected == nil { self.selected = result.first }
            self.isLoading = false
            self.updatePreview()
        }
    }

    func chooseCodexHome() {
        let panel = NSOpenPanel()
        panel.title = "Choose Codex Home"
        panel.message = "Choose the folder that contains Codex sessions (normally ~/.codex)."
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = codexHome
        if panel.runModal() == .OK, let url = panel.url {
            codexHome = url
            UserDefaults.standard.set(url.path, forKey: "CodexHome")
            selected = nil
            refresh()
        }
    }

    func updatePreview() {
        previewTask?.cancel()
        guard let session = selected else {
            preview = "Select a session to preview its Markdown export."
            previewBlocks = []
            return
        }
        let selectedMode = mode
        preview = "Loading preview…"
        previewBlocks = []
        previewTask = Task {
            do {
                let result = try await Task.detached { [exporter] in
                    try exporter.preview(session: session, mode: selectedMode)
                }.value
                guard !Task.isCancelled else { return }
                preview = result.markdown
                previewBlocks = result.blocks
            } catch {
                guard !Task.isCancelled else { return }
                preview = "Preview failed: \(error.localizedDescription)"
                previewBlocks = []
            }
        }
    }

    func exportSelected() {
        guard let session = selected else { return }
        let panel = NSSavePanel()
        panel.title = "Export Codex Transcript"
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        panel.allowsOtherFileTypes = false
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = defaultExportFilename(for: session)
        if panel.runModal() == .OK, let url = panel.url {
            let destination = url.pathExtension.lowercased() == "md" ? url : url.appendingPathExtension("md")
            do {
                try exporter.export(session: session, mode: mode, to: destination)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func revealSelected() {
        guard let selected else { return }
        NSWorkspace.shared.activateFileViewerSelecting([selected.url])
    }

    func copyPreview() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(preview, forType: .string)
    }

    private func safeFilename(_ value: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        let name = String(value.components(separatedBy: forbidden).joined(separator: "-").prefix(90))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Codex Transcript" : name
    }

    private func defaultExportFilename(for session: SessionSummary) -> String {
        let project = String(safeFilename(session.projectName).prefix(58))
        let threadIdentifier: String
        if let timestamp = session.timestamp {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd HHmmss"
            threadIdentifier = formatter.string(from: timestamp)
        } else {
            threadIdentifier = String(session.id.suffix(10))
        }
        return safeFilename("\(project) - \(threadIdentifier)") + ".md"
    }
}

private extension Task where Success == Never, Failure == Never {
    static func detachedMap<T: Sendable>(_ operation: @escaping @Sendable () -> T) -> Task<T, Never> {
        Task<T, Never>.detached(operation: operation)
    }
}

private extension Task where Failure == Never {
    func mapToMain(_ completion: @escaping @MainActor (Success) -> Void) {
        Task<Void, Never> { @MainActor in completion(await self.value) }
    }
}
#endif
