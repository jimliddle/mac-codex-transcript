#if os(macOS)
import AppKit
import CodexTranscriptCore
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                sidebarHeader
                Divider()
                List(selection: $model.selected) {
                    ForEach(model.filteredSessionGroups) { project in
                        Section {
                            ForEach(project.sessions) { session in
                                SessionRow(session: session)
                                    .tag(session)
                            }
                        } header: {
                            HStack {
                                Label(project.name, systemImage: "folder.fill")
                                Spacer()
                                Text("\(project.sessions.count)")
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
                .searchable(text: $model.searchText, placement: .sidebar, prompt: "Search transcripts")
                .onChange(of: model.selected) { _, _ in model.updatePreview() }

                Divider()
                sidebarFooter
            }
            .navigationSplitViewColumnWidth(min: 270, ideal: 330, max: 430)
        } detail: {
            VStack(spacing: 0) {
                toolbar
                Divider()
                if let session = model.selected {
                    SessionHeader(session: session)
                    Divider()
                    transcript
                } else {
                    ContentUnavailableView(
                        "Choose a transcript",
                        systemImage: "text.bubble",
                        description: Text("Select a Codex session from the sidebar to read it.")
                    )
                }
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .alert("Codex Transcript", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "Unknown error")
        }
    }

    private var sidebarHeader: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 1) {
                Text("Codex Transcript")
                    .font(.headline)
                Text("Local session browser")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var sidebarFooter: some View {
        HStack(spacing: 8) {
            if model.isLoading {
                ProgressView().controlSize(.small)
            } else {
                Image(systemName: "checkmark.circle")
                    .foregroundStyle(.secondary)
            }
            Text("\(model.filteredSessionGroups.count) projects · \(model.filteredSessions.count) threads")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Codex Home…") { model.chooseCodexHome() }
                .buttonStyle(.link)
        }
        .padding(10)
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Picker("View", selection: $model.mode) {
                ForEach(ExportMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .frame(width: 230)
            .onChange(of: model.mode) { _, _ in model.updatePreview() }

            Text(model.mode.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 12)

            Button { model.revealSelected() } label: {
                Label("Reveal", systemImage: "folder")
            }
            .help("Reveal the source JSONL in Finder")
            .disabled(model.selected == nil)

            Button { model.copyPreview() } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            .help("Copy the Markdown export")
            .disabled(model.selected == nil)

            Button { model.exportSelected() } label: {
                Label("Export…", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.selected == nil)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.bar)
    }

    @ViewBuilder
    private var transcript: some View {
        if model.previewBlocks.isEmpty {
            VStack(spacing: 12) {
                if model.preview == "Loading preview…" {
                    ProgressView()
                    Text("Formatting transcript…")
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 34))
                        .foregroundStyle(.secondary)
                    Text(model.preview)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(model.previewBlocks) { block in
                        TranscriptBlockView(block: block)
                    }
                }
                .frame(maxWidth: 920)
                .padding(.horizontal, 24)
                .padding(.vertical, 22)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.visible)
        }
    }
}

private struct TranscriptBlockView: View {
    let block: TranscriptBlock

    var body: some View {
        if block.kind == .user || block.kind == .assistant {
            messageCard
        } else {
            activityCard
        }
    }

    private var messageCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: block.kind == .user ? "person.fill" : "sparkles")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(tint.gradient, in: Circle())

            VStack(alignment: .leading, spacing: 9) {
                Text(block.title.uppercased())
                    .font(.caption.weight(.bold))
                    .tracking(0.7)
                    .foregroundStyle(tint)

                Text(formattedMessage)
                    .font(.system(size: 14.5))
                    .lineSpacing(3)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.075), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(tint.opacity(0.22), lineWidth: 1)
        }
    }

    private var activityCard: some View {
        DisclosureGroup {
            Text(block.content)
                .font(.system(size: 12.5, design: .monospaced))
                .lineSpacing(2)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 10)
        } label: {
            HStack(spacing: 9) {
                Image(systemName: activityIcon)
                    .foregroundStyle(tint)
                    .frame(width: 18)
                Text(block.title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if let detail = block.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(13)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }

    private var formattedMessage: AttributedString {
        (try? AttributedString(
            markdown: block.content,
            options: .init(interpretedSyntax: .full)
        )) ?? AttributedString(block.content)
    }

    private var tint: Color {
        switch block.kind {
        case .user: return Color(nsColor: .systemOrange)
        case .assistant: return Color(nsColor: .systemIndigo)
        case .command: return Color(nsColor: .systemGreen)
        case .toolCall: return Color(nsColor: .systemPurple)
        case .toolOutput: return Color(nsColor: .systemBlue)
        case .notice: return Color(nsColor: .systemYellow)
        case .activity, .raw: return Color(nsColor: .secondaryLabelColor)
        }
    }

    private var activityIcon: String {
        switch block.kind {
        case .command: return "terminal"
        case .toolCall: return "wrench.and.screwdriver"
        case .toolOutput: return "arrow.turn.down.right"
        case .notice: return "info.circle"
        case .raw: return "curlybraces"
        default: return "gearshape"
        }
    }
}

private struct SessionRow: View {
    let session: SessionSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(session.title)
                    .font(.body.weight(.medium))
                    .lineLimit(2)
                Spacer(minLength: 2)
                if session.isArchived {
                    Image(systemName: "archivebox.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .help("Archived")
                }
            }
            HStack(spacing: 6) {
                if let date = session.timestamp {
                    Text(date.formatted(date: .abbreviated, time: .shortened))
                }
                Text("•")
                Text(ByteCountFormatter.string(fromByteCount: session.size, countStyle: .file))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 5)
    }
}

private struct SessionHeader: View {
    let session: SessionSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top) {
                Text(session.projectName)
                    .font(.title2.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                if session.isArchived {
                    Label("Archived", systemImage: "archivebox")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.quaternary, in: Capsule())
                }
            }

            if session.projectName != session.title {
                Text(session.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 14) {
                if let date = session.timestamp {
                    MetadataLabel(icon: "calendar", text: date.formatted(date: .abbreviated, time: .shortened))
                }
                if let cwd = session.cwd {
                    MetadataLabel(icon: "folder", text: (cwd as NSString).abbreviatingWithTildeInPath)
                }
                MetadataLabel(icon: "doc", text: ByteCountFormatter.string(fromByteCount: session.size, countStyle: .file))
            }
            .lineLimit(1)

            Text(session.id)
                .font(.caption2.monospaced())
                .foregroundStyle(.tertiary)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.55))
    }
}

private struct MetadataLabel: View {
    let icon: String
    let text: String

    var body: some View {
        Label(text, systemImage: icon)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
#endif
