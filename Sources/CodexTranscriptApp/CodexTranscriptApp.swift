#if os(macOS)
import CodexTranscriptCore
import SwiftUI

@main
struct CodexTranscriptApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("Codex Transcript") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 980, minHeight: 640)
                .task { model.refresh() }
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Export Transcript…") { model.exportSelected() }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                    .disabled(model.selected == nil)
                Button("Refresh Sessions") { model.refresh() }
                    .keyboardShortcut("r", modifiers: .command)
            }
        }
    }
}
#endif
