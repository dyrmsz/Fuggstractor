import Foundation
import AppKit

// MARK: - PNG Export Result

struct PNGExportResult {
    let fileName: String
    let filePath: URL
    let size: CGSize
    let hasTransparency: Bool
}

// MARK: - PNG Exporter

class PNGExporter {
    let outputDirectory: URL

    init(outputDirectory: URL) {
        self.outputDirectory = outputDirectory
    }

    func exportBodyPart(
        image: NSImage,
        partType: String,
        partIndex: Int,
        sourceFileName: String
    ) throws -> PNGExportResult {
        // Create subdirectory for this image's exports
        let sourceBaseName = URL(fileURLWithPath: sourceFileName).deletingPathExtension().lastPathComponent
        let imageExportDir = outputDirectory.appendingPathComponent(sourceBaseName)

        try FileManager.default.createDirectory(at: imageExportDir, withIntermediateDirectories: true)

        // Generate filename
        let fileName = generateFileName(
            partType: partType,
            partIndex: partIndex,
            baseName: sourceBaseName
        )

        let filePath = imageExportDir.appendingPathComponent(fileName)

        // Save as PNG with transparency
        try savePNG(image: image, to: filePath)

        return PNGExportResult(
            fileName: fileName,
            filePath: filePath,
            size: image.size,
            hasTransparency: imageHasTransparency(image)
        )
    }

    func exportBatchResults(
        images: [(NSImage, String, Int, String)],  // (image, partType, partIndex, sourceFile)
        summaryFile: URL? = nil
    ) throws -> [PNGExportResult] {
        var results: [PNGExportResult] = []

        for (image, partType, partIndex, sourceFile) in images {
            let result = try exportBodyPart(
                image: image,
                partType: partType,
                partIndex: partIndex,
                sourceFileName: sourceFile
            )
            results.append(result)
        }

        // Write summary if requested
        if let summaryFile = summaryFile {
            try writeSummaryFile(results: results, to: summaryFile)
        }

        return results
    }

    private func savePNG(image: NSImage, to url: URL) throws {
        guard let tiffData = image.tiffRepresentation else {
            throw ExportError.imageConversionFailed
        }

        guard let bitmapImage = NSBitmapImageRep(data: tiffData) else {
            throw ExportError.imageConversionFailed
        }

        guard let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            throw ExportError.pngEncodingFailed
        }

        try pngData.write(to: url)
    }

    private func generateFileName(
        partType: String,
        partIndex: Int,
        baseName: String
    ) -> String {
        return "\(baseName)_\(partType)_\(partIndex).png"
    }

    private func imageHasTransparency(_ image: NSImage) -> Bool {
        guard let tiffData = image.tiffRepresentation else {
            return false
        }

        guard let bitmapImage = NSBitmapImageRep(data: tiffData) else {
            return false
        }

        // Check if image has alpha channel
        return bitmapImage.hasAlpha
    }

    private func writeSummaryFile(results: [PNGExportResult], to url: URL) throws {
        var summary = "Fuggstractor Export Summary\n"
        summary += "============================\n"
        summary += "Exported: \(ISO8601DateFormatter().string(from: Date()))\n"
        summary += "Total files: \(results.count)\n\n"

        summary += "Files:\n"
        for result in results {
            summary += "- \(result.fileName) (\(Int(result.size.width))×\(Int(result.size.height)))\n"
        }

        try summary.write(to: url, atomically: true, encoding: .utf8)
    }

    func createIndexFile(
        exportedParts: [String: [PNGExportResult]],  // [sourceFile: [results]]
        to url: URL
    ) throws {
        var index: [[String: Any]] = []

        for (sourceFile, results) in exportedParts {
            for result in results {
                index.append([
                    "source": sourceFile,
                    "file": result.fileName,
                    "path": result.filePath.relativePath,
                    "size": [
                        "width": result.size.width,
                        "height": result.size.height
                    ],
                    "hasTransparency": result.hasTransparency
                ])
            }
        }

        let jsonData = try JSONSerialization.data(
            withJSONObject: index,
            options: [.prettyPrinted, .sortedKeys]
        )

        try jsonData.write(to: url)
    }
}

// MARK: - Export Error

enum ExportError: Error, LocalizedError {
    case imageConversionFailed
    case pngEncodingFailed
    case directoryCreationFailed
    case fileSaveFailed(String)

    var errorDescription: String? {
        switch self {
        case .imageConversionFailed:
            return "Failed to convert image format"
        case .pngEncodingFailed:
            return "Failed to encode PNG"
        case .directoryCreationFailed:
            return "Failed to create output directory"
        case .fileSaveFailed(let reason):
            return "Failed to save file: \(reason)"
        }
    }
}
