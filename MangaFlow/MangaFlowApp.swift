import SwiftUI

@main
struct ImageViewerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onDisappear {
                    // Clean up temporary files when closing the app
                    FileManagerHelper.cleanupTemporaryFiles()
                }
        }
        .windowStyle(.hiddenTitleBar) // For a more modern look
        .commands {
            // Add custom menu commands here if needed
            CommandGroup(replacing: .newItem) {
                Button("Open Images") {
                    NotificationCenter.default.post(name: .openFilePicker, object: nil)
                }
                .keyboardShortcut("o", modifiers: .command)
            }
        }
    }
}

// Notification names for app-wide communication
extension Notification.Name {
    static let openFilePicker = Notification.Name("openFilePicker")
}