import SwiftUI
import Foundation

// MARK: - Annotation Model

struct Annotation: Identifiable, Codable {
    let id = UUID()
    let rect: CGRect
    let partType: String

    var bodyPartType: BodyPartType {
        BodyPartType(rawValue: partType) ?? .body
    }

    enum CodingKeys: String, CodingKey {
        case rect, partType
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(
            [rect.origin.x, rect.origin.y, rect.width, rect.height],
            forKey: .rect
        )
        try container.encode(partType, forKey: .partType)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rectArray = try container.decode([CGFloat].self, forKey: .rect)
        self.rect = CGRect(
            x: rectArray[0],
            y: rectArray[1],
            width: rectArray[2],
            height: rectArray[3]
        )
        self.partType = try container.decode(String.self, forKey: .partType)
    }

    init(rect: CGRect, partType: BodyPartType) {
        self.rect = rect
        self.partType = partType.rawValue
    }
}

// MARK: - COCO Annotation Format

struct COCOAnnotation: Codable {
    struct Image: Codable {
        let id: Int
        let file_name: String
        let height: Int
        let width: Int
    }

    struct Annotation: Codable {
        let id: Int
        let image_id: Int
        let category_id: Int
        let bbox: [CGFloat] // [x, y, width, height]
        let area: CGFloat
        let iscrowd: Int
    }

    struct Category: Codable {
        let id: Int
        let name: String
        let supercategory: String
    }

    let images: [Image]
    let annotations: [Annotation]
    let categories: [Category]
}

// MARK: - Annotation View Model

class AnnotationViewModel: NSObject, ObservableObject {
    @Published var currentImage: NSImage?
    @Published var currentImageURL: URL?
    @Published var annotations: [Annotation] = []
    @Published var isProcessing = false
    @Published var errorMessage: String?

    private let fileManager = FileManager.default

    func loadImage() {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["public.image"]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            if let image = NSImage(contentsOf: url) {
                currentImage = image
                currentImageURL = url
                annotations = []
            } else {
                errorMessage = "Failed to load image"
            }
        }
    }

    func addAnnotation(rect: CGRect, partType: BodyPartType) {
        let annotation = Annotation(rect: rect, partType: partType)
        annotations.append(annotation)
    }

    func removeAnnotation(at index: Int) {
        guard index < annotations.count else { return }
        annotations.remove(at: index)
    }

    func undoLastAnnotation() {
        guard !annotations.isEmpty else { return }
        annotations.removeLast()
    }

    func clearAnnotations() {
        annotations = []
    }

    func exportAnnotations() {
        guard let imageURL = currentImageURL, !annotations.isEmpty else {
            errorMessage = "No image or annotations to export"
            return
        }

        let panel = NSSavePanel()
        panel.allowedFileTypes = ["json"]
        panel.nameFieldStringValue = imageURL.deletingPathExtension().lastPathComponent + "_annotations"

        if panel.runModal() == .OK, let url = panel.url {
            do {
                try saveAnnotationsToJSON(url)
                errorMessage = nil
            } catch {
                errorMessage = "Failed to export annotations: \(error.localizedDescription)"
            }
        }
    }

    private func saveAnnotationsToJSON(_ url: URL) throws {
        guard let imageURL = currentImageURL, let image = currentImage else {
            throw NSError(domain: "AnnotationViewModel", code: -1, userInfo: nil)
        }

        // Create COCO format annotations
        let imageId = 1
        let cocoImage = COCOAnnotation.Image(
            id: imageId,
            file_name: imageURL.lastPathComponent,
            height: Int(image.size.height),
            width: Int(image.size.width)
        )

        var cocoAnnotations: [COCOAnnotation.Annotation] = []
        for (idx, annotation) in annotations.enumerated() {
            let area = annotation.rect.width * annotation.rect.height
            let cocoAnnotation = COCOAnnotation.Annotation(
                id: idx,
                image_id: imageId,
                category_id: getCategoryId(for: annotation.bodyPartType),
                bbox: [
                    annotation.rect.origin.x,
                    annotation.rect.origin.y,
                    annotation.rect.width,
                    annotation.rect.height
                ],
                area: area,
                iscrowd: 0
            )
            cocoAnnotations.append(cocoAnnotation)
        }

        // Create categories
        let categories: [COCOAnnotation.Category] = [
            .init(id: 1, name: "eye", supercategory: "part"),
            .init(id: 2, name: "ear", supercategory: "part"),
            .init(id: 3, name: "teeth", supercategory: "part"),
            .init(id: 4, name: "arm", supercategory: "part"),
            .init(id: 5, name: "body", supercategory: "part"),
            .init(id: 6, name: "head", supercategory: "part"),
            .init(id: 7, name: "leg", supercategory: "part"),
            .init(id: 8, name: "accessory", supercategory: "part"),
            .init(id: 9, name: "underpants", supercategory: "part"),
        ]

        let cocoData = COCOAnnotation(
            images: [cocoImage],
            annotations: cocoAnnotations,
            categories: categories
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let jsonData = try encoder.encode(cocoData)

        try jsonData.write(to: url)
    }

    private func getCategoryId(for partType: BodyPartType) -> Int {
        switch partType {
        case .eye: return 1
        case .ear: return 2
        case .teeth: return 3
        case .arm: return 4
        case .body: return 5
        case .head: return 6
        case .leg: return 7
        case .accessory: return 8
        case .underpants: return 9
        }
    }
}
