# Codex Transcript for macOS

A private, local-only macOS app for browsing Codex CLI session history and exporting readable Markdown transcripts.

Codex Transcript turns the raw JSONL files under `~/.codex` into a browsable conversation view. It groups threads by project, distinguishes user and model messages visually, wraps long content, and keeps technical activity out of the way until it is needed.

## Features

- Groups conversation threads by project folder.
- Shows the original request, date, size, and session metadata for each thread.
- Uses distinct, readable styling for user and Codex messages.
- Formats Markdown and wraps long messages to the window width.
- Presents commands, tool calls, outputs, and raw records as expandable sections.
- Searches session titles, project paths, and session IDs.
- Scans active and archived Codex sessions.
- Streams full exports so large transcripts do not need to fit in memory.
- Works entirely on-device with no network code.
- Never modifies Codex session files.

## Requirements

- macOS 14 Sonoma or newer
- Apple Silicon for the prebuilt release
- Codex CLI session history under `$CODEX_HOME/sessions` or `~/.codex/sessions`

## Install

1. Download the latest DMG from [Releases](https://github.com/jimliddle/mac-codex-transcript/releases).
2. Open the DMG.
3. Drag **Codex Transcript** into **Applications**.

The downloadable app is ad-hoc signed rather than notarized with an Apple Developer ID. If macOS blocks the first launch, Control-click the app in Finder, choose **Open**, and confirm.

## Export modes

- **Conversation** — user and assistant messages only. This is the clean, readable default.
- **Conversation + Activity** — messages plus commands, tool calls, patches, and outputs. Technical sections are collapsible in compatible Markdown viewers.
- **Raw Archival Transcript** — every JSONL record in original order, embedded verbatim in Markdown for maximum fidelity.

Export filenames start with the project name and include the thread timestamp, for example `MyProject - 2026-09-01 170412.md`.

## Build from source

1. Install Xcode 16 or newer.
2. Clone this repository.
3. Open `Package.swift` in Xcode.
4. Select the **CodexTranscript** scheme and **My Mac** destination.
5. Build and run.

The app targets macOS 14. The reusable parsing and export code lives in `CodexTranscriptCore`; the SwiftUI application lives in `CodexTranscriptApp`.

Core tests can also be run from the repository root:

```bash
swift test
```

## Custom Codex home

Use **Codex Home…** in the sidebar footer if your sessions are stored somewhere other than `~/.codex`. The selected location is stored in the app's local preferences.

## Privacy

Codex Transcript contains no networking code. Session files are opened read-only, and the app writes only to a destination you explicitly select when exporting Markdown.

## License

Codex Transcript is available under the [MIT License](LICENSE).
