import SwiftUI

struct ProcessingView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = ProcessingViewModel()
    @State private var isDropTargeted = false

    var body: some View {
        ZStack {
            VStack {
                if viewModel.selectedImages.isEmpty && !viewModel.isProcessing {
                    // Drop target area
                    DropAreaView(isTargeted: $isDropTargeted) { urls in
                        viewModel.addImages(urls)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.isProcessing {
                    // Processing progress view
                    ProcessingProgressView(viewModel: viewModel)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Results view
                    ResultsView(viewModel: viewModel)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding(20)

            // Error toast
            if let error = viewModel.errorMessage {
                VStack {
                    HStack {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.red)
                        Text(error)
                        Spacer()
                        Button(action: { viewModel.errorMessage = nil }) {
                            Image(systemName: "xmark")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(12)
                    .background(Color(nsColor: .systemRed).opacity(0.1))
                    .cornerRadius(6)
                    .padding(20)

                    Spacer()
                }
            }
        }
    }
}

// MARK: - Drop Area View

struct DropAreaView: View {
    @Binding var isTargeted: Bool
    var onDrop: ([URL]) -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.down.doc")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                Text("Drop images here")
                    .font(.system(size: 18, weight: .semibold))

                Text("or click to browse for fuggler images")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            Button("Browse Files") {
                let panel = NSOpenPanel()
                panel.allowedFileTypes = ["public.image"]
                panel.allowsMultipleSelection = true
                panel.canChooseDirectories = false

                if panel.runModal() == .OK {
                    onDrop(panel.urls)
                }
            }
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(isTargeted ? Color.accentColor.opacity(0.1) : Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
                .foregroundColor(isTargeted ? .accentColor : .secondary)
        )
        .cornerRadius(12)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            for provider in providers {
                provider.loadFileRepresentation(forTypeIdentifier: "public.file-url") { url, _ in
                    if let url = url as? URL {
                        DispatchQueue.main.async {
                            onDrop([url])
                        }
                    }
                }
            }
            return true
        }
    }
}

// MARK: - Processing Progress View

struct ProcessingProgressView: View {
    @ObservedObject var viewModel: ProcessingViewModel

    var body: some View {
        VStack(spacing: 24) {
            Text("Processing Images")
                .font(.system(size: 18, weight: .semibold))

            VStack(spacing: 16) {
                ForEach(viewModel.processingStatus.indices, id: \.self) { idx in
                    let status = viewModel.processingStatus[idx]
                    ProcessingItemView(status: status)
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)

            // Overall progress
            VStack(spacing: 8) {
                ProgressView(value: Double(viewModel.processedCount), total: Double(viewModel.selectedImages.count))
                    .tint(.accentColor)

                HStack {
                    Text("\(viewModel.processedCount) / \(viewModel.selectedImages.count) images")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                    if let eta = viewModel.estimatedTimeRemaining {
                        Text(eta)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            Button("Cancel") {
                viewModel.cancelProcessing()
            }
            .controlSize(.large)
        }
    }
}

// MARK: - Processing Item View

struct ProcessingItemView: View {
    let status: ProcessingStatus

    var body: some View {
        HStack(spacing: 12) {
            switch status.state {
            case .pending:
                Image(systemName: "circle")
                    .foregroundColor(.secondary)
            case .processing:
                ProgressView()
                    .scaleEffect(0.8, anchor: .center)
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .failed:
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(status.fileName)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)

                if let message = status.message {
                    Text(message)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(4)
    }
}

// MARK: - Results View

struct ResultsView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: ProcessingViewModel

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Processing Complete")
                    .font(.system(size: 18, weight: .semibold))

                Spacer()

                Button("New Batch") {
                    viewModel.reset()
                }
                .controlSize(.small)
            }

            // Summary stats
            HStack(spacing: 16) {
                StatCard(title: "Images Processed", value: "\(viewModel.processedCount)")
                StatCard(title: "Body Parts Extracted", value: "\(viewModel.extractedPartsCount)")
                StatCard(title: "Export Location", value: "Saved")
            }

            // Results table
            Table(viewModel.processingStatus) {
                TableColumn("Image") { status in
                    Text(status.fileName)
                        .font(.system(size: 12, design: .monospaced))
                        .lineLimit(1)
                }
                TableColumn("Status") { status in
                    HStack(spacing: 6) {
                        Image(systemName: statusIcon(status.state))
                            .foregroundColor(statusColor(status.state))
                        Text(statusText(status.state))
                    }
                    .font(.system(size: 11))
                }
            }
            .frame(maxHeight: .infinity)

            // Action buttons
            HStack(spacing: 12) {
                Button("Open Export Folder") {
                    NSWorkspace.shared.open(appState.exportDirectory)
                }

                Spacer()

                Button("Copy Summary") {
                    viewModel.copySummaryToClipboard()
                }
                .disabled(!viewModel.hasSummary)
            }
            .controlSize(.large)
        }
    }

    private func statusIcon(_ state: ProcessingState) -> String {
        switch state {
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        default: return "circle"
        }
    }

    private func statusColor(_ state: ProcessingState) -> Color {
        switch state {
        case .completed: return .green
        case .failed: return .red
        default: return .gray
        }
    }

    private func statusText(_ state: ProcessingState) -> String {
        switch state {
        case .completed: return "Completed"
        case .failed: return "Failed"
        case .processing: return "Processing"
        case .pending: return "Pending"
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 16, weight: .semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(6)
    }
}

// MARK: - View Extensions

extension View {
    func borderBottom() -> some View {
        self.overlay(
            VStack {
                Spacer()
                Divider()
            }
        )
    }
}

// MARK: - Preview

#Preview {
    ProcessingView()
        .environmentObject(AppState())
}
