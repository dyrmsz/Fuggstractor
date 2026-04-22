import Foundation
import Accelerate
import AppKit
import CoreVideo

// MARK: - Background Removal Engine

class BackgroundRemovalEngine {

    func removeBackground(
        image: NSImage,
        mask: CVPixelBuffer,
        applyAntialiasing: Bool = true
    ) -> NSImage? {
        // Convert image to CG image for processing
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        // Get dimensions
        let width = cgImage.width
        let height = cgImage.height

        // Create image with alpha channel
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        // Draw original image
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Apply mask to create transparency
        guard let rawData = context.data else {
            return nil
        }

        applyMaskToAlpha(
            rawData: rawData,
            width: width,
            height: height,
            mask: mask
        )

        // Create new image with transparency
        guard let newCGImage = context.makeImage() else {
            return nil
        }

        return NSImage(cgImage: newCGImage, size: NSZeroSize)
    }

    private func applyMaskToAlpha(
        rawData: UnsafeMutableRawPointer,
        width: Int,
        height: Int,
        mask: CVPixelBuffer
    ) {
        CVPixelBufferLockBaseAddress(mask, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(mask, .readOnly) }

        guard let maskData = CVPixelBufferGetBaseAddress(mask) else {
            return
        }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(mask)
        let maskPtr = maskData.assumingMemoryBound(to: UInt8.self)
        let imgPtr = rawData.assumingMemoryBound(to: UInt8.self)

        // Apply mask: where mask is 0, set alpha to 0
        for y in 0 ..< height {
            for x in 0 ..< width {
                let maskIdx = y * bytesPerRow + x
                let imgIdx = (y * width + x) * 4

                if maskPtr[maskIdx] == 0 {
                    imgPtr[imgIdx + 3] = 0  // Set alpha to transparent
                }
            }
        }
    }

    func featherEdges(image: NSImage, radius: Int = 3) -> NSImage? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let width = cgImage.width
        let height = cgImage.height

        // Create context
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var imageBuffer = vImage_Buffer()
        guard let contextData = context.data else {
            return nil
        }
        imageBuffer.data = contextData
        imageBuffer.height = vImage_Pixel_Count(height)
        imageBuffer.width = vImage_Pixel_Count(width)
        imageBuffer.rowBytes = width * 4

        // Apply Gaussian blur to alpha channel for feathering
        var buffer = imageBuffer
        let kernel = createGaussianKernel(radius: radius)

        // Apply blur (simplified - in production use vImageMatrixMultiply_ARGB8888)
        // For now, just return the image as-is
        // TODO: Implement proper feathering with vImage

        guard let newCGImage = context.makeImage() else {
            return nil
        }

        return NSImage(cgImage: newCGImage, size: NSZeroSize)
    }

    private func createGaussianKernel(radius: Int) -> [[Float]] {
        var kernel = Array(repeating: Array(repeating: Float(0), count: radius * 2 + 1), count: radius * 2 + 1)
        let sigma = Float(radius) / 3.0
        let piSigmaSq = Float.pi * sigma * sigma
        let twoSigmaSq = 2 * sigma * sigma

        var sum: Float = 0
        for y in -radius ... radius {
            for x in -radius ... radius {
                let value = exp(-Float(x * x + y * y) / twoSigmaSq) / piSigmaSq
                kernel[y + radius][x + radius] = value
                sum += value
            }
        }

        // Normalize
        for y in 0 ..< kernel.count {
            for x in 0 ..< kernel[y].count {
                kernel[y][x] /= sum
            }
        }

        return kernel
    }

    func extractBoundingBox(image: NSImage, mask: CVPixelBuffer) -> CGRect {
        CVPixelBufferLockBaseAddress(mask, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(mask, .readOnly) }

        guard let maskData = CVPixelBufferGetBaseAddress(mask) else {
            return CGRect.zero
        }

        let width = CVPixelBufferGetWidth(mask)
        let height = CVPixelBufferGetHeight(mask)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(mask)
        let maskPtr = maskData.assumingMemoryBound(to: UInt8.self)

        var minX = width
        var maxX = 0
        var minY = height
        var maxY = 0

        // Find bounds of non-zero pixels
        for y in 0 ..< height {
            for x in 0 ..< width {
                let idx = y * bytesPerRow + x
                if maskPtr[idx] > 0 {
                    minX = min(minX, x)
                    maxX = max(maxX, x)
                    minY = min(minY, y)
                    maxY = max(maxY, y)
                }
            }
        }

        if minX == width || minY == height {
            return CGRect.zero
        }

        return CGRect(
            x: minX,
            y: minY,
            width: maxX - minX,
            height: maxY - minY
        )
    }
}

