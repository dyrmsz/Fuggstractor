import SwiftUI

struct MainView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: String = "process"

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            HStack(spacing: 0) {
                TabButton(
                    title: "Processor",
                    icon: "wand.and.stars",
                    isSelected: selectedTab == "process"
                ) {
                    selectedTab = "process"
                    appState.currentMode = .processing
                }
                .frame(height: 50)

                TabButton(
                    title: "Annotator",
                    icon: "paintbrush",
                    isSelected: selectedTab == "annotate"
                ) {
                    selectedTab = "annotate"
                    appState.currentMode = .annotation
                }
                .frame(height: 50)

                Spacer()

                SettingsButton()
                    .frame(height: 50)
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .borderBottom()

            // Main content
            Group {
                if selectedTab == "process" {
                    ProcessingView()
                } else {
                    AnnotationView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - Tab Button

struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundColor(isSelected ? .white : .secondary)
            .background(isSelected ? Color.accentColor : Color.clear)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Settings Button

struct SettingsButton: View {
    @State private var isShowingSettings = false

    var body: some View {
        Button(action: { isShowingSettings.toggle() }) {
            Image(systemName: "gear")
                .font(.system(size: 16))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(PlainButtonStyle())
        .help("Settings")
        .popover(isPresented: $isShowingSettings) {
            SettingsView()
                .padding()
                .frame(width: 400)
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedDirectory: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.system(size: 18, weight: .bold))

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Export Directory")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)

                HStack {
                    Text(appState.exportDirectory.lastPathComponent)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .font(.system(size: 12, design: .monospaced))

                    Spacer()

                    Button("Change...") {
                        let panel = NSOpenPanel()
                        panel.canChooseDirectories = true
                        panel.canChooseFiles = false
                        panel.allowsMultipleSelection = false

                        if panel.runModal() == .OK, let url = panel.url {
                            appState.exportDirectory = url
                        }
                    }
                    .font(.system(size: 12))
                }
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(4)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Information")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Version")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text("1.0.0")
                            .font(.system(size: 12, weight: .semibold))
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Python Backend")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text("TBD")
                            .font(.system(size: 12, weight: .semibold))
                    }
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Preview

#Preview {
    MainView()
        .environmentObject(AppState())
}
