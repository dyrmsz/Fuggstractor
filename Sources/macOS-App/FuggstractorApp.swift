import SwiftUI

@main
struct FuggstractorApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(appState)
                .frame(minWidth: 1000, minHeight: 700)
        }
        .windowStyle(.hiddenTitleBar)
    }
}

// MARK: - App State

class AppState: ObservableObject {
    enum Mode {
        case processing
        case annotation
    }

    @Published var currentMode: Mode = .processing
    @Published var exportDirectory: URL = FileManager.default.urls(
        for: .documentDirectory,
        in: .userDomainMask
    )[0]

    init() {
        // Set up default export directory
        let fuggstractorDir = exportDirectory.appendingPathComponent("Fuggstractor-Exports")
        if !FileManager.default.fileExists(atPath: fuggstractorDir.path) {
            try? FileManager.default.createDirectory(
                at: fuggstractorDir,
                withIntermediateDirectories: true
            )
        }
        self.exportDirectory = fuggstractorDir
    }
}
