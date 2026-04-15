import SwiftUI
import Foundation

// MARK: - Processing State

enum ProcessingState {
    case pending
    case processing
    case completed
    case failed
}

struct ProcessingStatus: Identifiable {
    let id = UUID()
    let fileName: String
    var state: ProcessingState
    var message: String?
    var extractedParts: [String] = []
}

// MARK: - Processing View Model

class ProcessingViewModel: NSObject, ObservableObject {
    @Published var selectedImages: [URL] = []
    @Published var processingStatus: [ProcessingStatus] = []
    @Published var isProcessing = false
    @Published var processedCount = 0
    @Published var extractedPartsCount = 0
    @Published var errorMessage: String?
    @Published var estimatedTimeRemaining: String?
    @Published var hasSummary = false

    private var processingTask: Task<Void, Never>?
    private let processingQueue = DispatchQueue(label: "com.fuggstractor.processing", qos: .userInitiated)

    func addImages(_ urls: [URL]) {
        let imageURLs = urls.filter { url in
            ["jpg", "jpeg", "png", "gif", "webp"].contains(url.pathExtension.lowercased())
        }

        if imageURLs.isEmpty {
            errorMessage = "No valid image files selected"
            return
        }

        selectedImages.append(contentsOf: imageURLs)
        initializeProcessingStatus()
        startProcessing()
    }

    private func initializeProcessingStatus() {
        processingStatus = selectedImages.map { url in
            ProcessingStatus(
                fileName: url.lastPathComponent,
                state: .pending
            )
        }
    }

    func startProcessing() {
        guard !selectedImages.isEmpty else { return }

        isProcessing = true
        processedCount = 0
        extractedPartsCount = 0

        processingTask = Task {
            for (index, imageURL) in selectedImages.enumerated() {
                guard !Task.isCancelled else { break }

                await processImage(at: index, url: imageURL)
            }

            // Update UI on main thread
            await MainActor.run {
                isProcessing = false
                hasSummary = true
            }
        }
    }

    private func processImage(at index: Int, url: URL) async {
        await MainActor.run {
            processingStatus[index].state = .processing
            processingStatus[index].message = "Processing..."
        }

        do {
            // TODO: Integrate with actual segmentation engine
            // For now, simulate processing

            // Simulate processing delay
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

            // Simulate extracted parts
            let parts = ["eye_left", "eye_right", "head", "body", "arms_left", "arms_right", "legs_left", "legs_right"]

            await MainActor.run {
                processingStatus[index].state = .completed
                processingStatus[index].message = "\(parts.count) parts extracted"
                processingStatus[index].extractedParts = parts
                processedCount += 1
                extractedPartsCount += parts.count
                estimatedTimeRemaining = calculateETA()
            }

            // TODO: Save extracted parts as PNG files to export directory

        } catch {
            await MainActor.run {
                processingStatus[index].state = .failed
                processingStatus[index].message = error.localizedDescription
                errorMessage = "Failed to process: \(url.lastPathComponent)"
            }
        }
    }

    func cancelProcessing() {
        processingTask?.cancel()
        isProcessing = false
        errorMessage = "Processing cancelled"
    }

    func reset() {
        selectedImages = []
        processingStatus = []
        isProcessing = false
        processedCount = 0
        extractedPartsCount = 0
        errorMessage = nil
        estimatedTimeRemaining = nil
        hasSummary = false
    }

    func copySummaryToClipboard() {
        let summary = """
        Fuggstractor Processing Summary
        ================================
        Images Processed: \(processedCount)
        Total Body Parts Extracted: \(extractedPartsCount)
        Status: \(isProcessing ? "Processing" : "Complete")

        Details:
        \(processingStatus.map { "\($0.fileName): \($0.state)" }.joined(separator: "\n"))
        """

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(summary, forType: .string)
    }

    private func calculateETA() -> String? {
        guard processedCount > 0, processedCount < selectedImages.count else { return nil }

        let remainingImages = selectedImages.count - processedCount
        let averageTimePerImage = 2.0 // seconds (from our simulation)
        let totalSeconds = Int(Double(remainingImages) * averageTimePerImage)

        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60

        if minutes > 0 {
            return "~\(minutes)m \(seconds)s remaining"
        } else {
            return "~\(seconds)s remaining"
        }
    }
}
