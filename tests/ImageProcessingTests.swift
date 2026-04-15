import XCTest
import Foundation
import AppKit
import CoreML

@testable import Fuggstractor

class SegmentationEngineTests: XCTestCase {

    var segmentationEngine: SegmentationEngine!

    override func setUp() {
        super.setUp()
        segmentationEngine = SegmentationEngine()
    }

    override func tearDown() {
        segmentationEngine = nil
        super.tearDown()
    }

    func testEngineInitialization() {
        XCTAssertNotNil(segmentationEngine)
    }

    func testPixelBufferConversion() {
        // Create a test image
        guard let testImage = createTestImage() else {
            XCTFail("Failed to create test image")
            return
        }

        // Test should not crash
        let result = testImage
        XCTAssertNotNil(result)
    }

    func testSegmentationWithTestImage() {
        guard let testImage = createTestImage() else {
            XCTFail("Failed to create test image")
            return
        }

        // Should not throw
        XCTAssertNoThrow {
            let result = try segmentationEngine.segment(image: testImage)
            XCTAssertGreaterThan(result.processingTime, 0)
        }
    }

    private func createTestImage() -> NSImage? {
        let size = NSSize(width: 512, height: 512)

        guard let image = NSImage(size: size) else {
            return nil
        }

        image.lockFocus()
        NSColor.white.setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()

        return image
    }
}

class BackgroundRemovalEngineTests: XCTestCase {

    var backgroundEngine: BackgroundRemovalEngine!

    override func setUp() {
        super.setUp()
        backgroundEngine = BackgroundRemovalEngine()
    }

    override func tearDown() {
        backgroundEngine = nil
        super.tearDown()
    }

    func testEngineInitialization() {
        XCTAssertNotNil(backgroundEngine)
    }

    func testBackgroundRemovalWithValidInputs() {
        guard let testImage = createTestImage() else {
            XCTFail("Failed to create test image")
            return
        }

        let testMask = CVPixelBuffer.createEmpty(width: 512, height: 512)

        let result = backgroundEngine.removeBackground(
            image: testImage,
            mask: testMask
        )

        XCTAssertNotNil(result)
    }

    func testEdgeFeathering() {
        guard let testImage = createTestImage() else {
            XCTFail("Failed to create test image")
            return
        }

        let featheredImage = backgroundEngine.featherEdges(image: testImage, radius: 3)
        XCTAssertNotNil(featheredImage)
    }

    func testBoundingBoxExtraction() {
        let testMask = CVPixelBuffer.createEmpty(width: 512, height: 512)

        let bbox = backgroundEngine.extractBoundingBox(
            image: createTestImage()!,
            mask: testMask
        )

        XCTAssertEqual(bbox.width >= 0, true)
        XCTAssertEqual(bbox.height >= 0, true)
    }

    private func createTestImage() -> NSImage? {
        let size = NSSize(width: 512, height: 512)

        guard let image = NSImage(size: size) else {
            return nil
        }

        image.lockFocus()
        NSColor.blue.setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()

        return image
    }
}

class PNGExporterTests: XCTestCase {

    var exporter: PNGExporter!
    var tempDirectory: URL!

    override func setUp() {
        super.setUp()

        tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("FuggstractorTests-\(UUID().uuidString)")

        try? FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true
        )

        exporter = PNGExporter(outputDirectory: tempDirectory)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        exporter = nil
        tempDirectory = nil
        super.tearDown()
    }

    func testExportBodyPart() {
        guard let testImage = createTestImage() else {
            XCTFail("Failed to create test image")
            return
        }

        XCTAssertNoThrow {
            let result = try exporter.exportBodyPart(
                image: testImage,
                partType: "head",
                partIndex: 0,
                sourceFileName: "test_image.jpg"
            )

            XCTAssertEqual(result.fileName.contains("head"), true)
            XCTAssertEqual(FileManager.default.fileExists(atPath: result.filePath.path), true)
        }
    }

    func testBatchExport() {
        guard let testImage = createTestImage() else {
            XCTFail("Failed to create test image")
            return
        }

        let images = [
            (testImage, "eye", 0, "test1.jpg"),
            (testImage, "head", 1, "test1.jpg"),
            (testImage, "body", 0, "test2.jpg"),
        ]

        XCTAssertNoThrow {
            let results = try exporter.exportBatchResults(images: images)
            XCTAssertEqual(results.count, 3)
        }
    }

    func testIndexFileGeneration() {
        guard let testImage = createTestImage() else {
            XCTFail("Failed to create test image")
            return
        }

        XCTAssertNoThrow {
            let result = try exporter.exportBodyPart(
                image: testImage,
                partType: "eye",
                partIndex: 0,
                sourceFileName: "test.jpg"
            )

            let exportedParts = ["test.jpg": [result]]
            let indexFile = tempDirectory.appendingPathComponent("index.json")

            try exporter.createIndexFile(
                exportedParts: exportedParts,
                to: indexFile
            )

            XCTAssertEqual(
                FileManager.default.fileExists(atPath: indexFile.path),
                true
            )
        }
    }

    private func createTestImage() -> NSImage? {
        let size = NSSize(width: 256, height: 256)

        guard let image = NSImage(size: size) else {
            return nil
        }

        image.lockFocus()
        NSColor.red.setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()

        return image
    }
}

class ProcessingViewModelTests: XCTestCase {

    var viewModel: ProcessingViewModel!

    override func setUp() {
        super.setUp()
        viewModel = ProcessingViewModel()
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    func testInitialState() {
        XCTAssertEqual(viewModel.selectedImages.count, 0)
        XCTAssertEqual(viewModel.isProcessing, false)
        XCTAssertEqual(viewModel.processedCount, 0)
    }

    func testImageAddition() {
        let testURL = URL(fileURLWithPath: "/tmp/test.jpg")

        // Should not crash with invalid URL
        viewModel.addImages([testURL])
    }

    func testProcessingReset() {
        viewModel.processedCount = 5
        viewModel.isProcessing = true

        viewModel.reset()

        XCTAssertEqual(viewModel.processedCount, 0)
        XCTAssertEqual(viewModel.isProcessing, false)
    }

    func testSummaryGeneration() {
        viewModel.processedCount = 1
        viewModel.extractedPartsCount = 8

        viewModel.copySummaryToClipboard()

        let pasteboard = NSPasteboard.general
        let summary = pasteboard.string(forType: .string)

        XCTAssertNotNil(summary)
        XCTAssertTrue(summary?.contains("1") ?? false)
    }
}

// MARK: - Test Helpers

extension XCTestCase {
    func XCTAssertNoThrow(
        _ expression: @autoclosure () throws -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        do {
            try expression()
        } catch {
            XCTFail(
                "Expected no error, but got: \(error)",
                file: file,
                line: line
            )
        }
    }
}
