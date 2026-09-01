# Build notes

## Targets

- `CodexTranscriptCore` — session discovery, JSONL parsing, preview generation, and streaming Markdown export.
- `CodexTranscriptApp` — the macOS SwiftUI application.
- `CodexTranscriptCoreTests` — scanner and exporter fixture tests.

The package requires macOS 14 or later. Open `Package.swift` in Xcode and select the **CodexTranscript** scheme with **My Mac** as the destination to build the GUI application.

## Packaging

The Swift Package release product is the executable placed inside the application bundle. `Packaging/Info.plist` contains the bundle metadata, and `Assets/AppIcon.icns` is the application icon.

Release DMGs and `.app` bundles belong under `dist/`, which is intentionally excluded from Git. Publish finished DMGs as GitHub Release assets rather than committing them to the repository.

## Design guarantees

- No writes to Codex session files.
- No network code.
- Sidebar scanning reads only the beginning of each rollout for metadata and title.
- Preview parsing is capped for responsiveness.
- Full exports stream source JSONL line by line.
- Raw archival mode embeds every source JSONL record verbatim and in order.
