import SwiftUI

struct AnnotationView: View {
    @StateObject private var viewModel = AnnotationViewModel()
    @State private var selectedBodyPart: BodyPartType = .head

    var body: some View {
        VStack(spacing: 0) {
            // Top toolbar
            HStack(spacing: 12) {
                Button(action: { viewModel.loadImage() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "folder.badge.plus")
                        Text("Load Image")
                    }
                }
                .disabled(viewModel.isProcessing)

                Divider()
                    .frame(height: 20)

                // Body part selector
                Text("Select Part:")
                    .font(.system(size: 12))

                Picker("Body Part", selection: $selectedBodyPart) {
                    ForEach(BodyPartType.allCases, id: \.self) { part in
                        HStack {
                            Circle()
                                .fill(part.color)
                                .frame(width: 12, height: 12)
                            Text(part.displayName)
                        }
                        .tag(part)
                    }
                }
                .frame(width: 150)

                Divider()
                    .frame(height: 20)

                Button(action: { viewModel.undoLastAnnotation() }) {
                    Image(systemName: "arrow.uturn.backward")
                }
                .disabled(viewModel.annotations.isEmpty)

                Button(action: { viewModel.clearAnnotations() }) {
                    Image(systemName: "trash")
                }
                .disabled(viewModel.annotations.isEmpty)

                Spacer()

                Button("Export Annotations") {
                    viewModel.exportAnnotations()
                }
                .disabled(viewModel.annotations.isEmpty || viewModel.currentImage == nil)
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))
            .borderBottom()

            // Main content
            HStack(spacing: 16) {
                // Canvas area
                if let image = viewModel.currentImage {
                    AnnotationCanvasView(
                        image: image,
                        annotations: viewModel.annotations,
                        selectedPart: selectedBodyPart,
                        onAnnotation: { rect in
                            viewModel.addAnnotation(
                                rect: rect,
                                partType: selectedBodyPart
                            )
                        }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack {
                        Image(systemName: "photo")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)

                        Text("No image loaded")
                            .foregroundColor(.secondary)

                        Button("Load an image to begin annotating") {
                            viewModel.loadImage()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(nsColor: .controlBackgroundColor))
                }

                // Right sidebar
                VStack(spacing: 12) {
                    Text("Annotations")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(viewModel.annotations.indices, id: \.self) { idx in
                                let annotation = viewModel.annotations[idx]
                                AnnotationItemView(
                                    annotation: annotation,
                                    onDelete: {
                                        viewModel.removeAnnotation(at: idx)
                                    }
                                )
                            }
                        }
                    }

                    Spacer()

                    VStack(spacing: 8) {
                        Text("\(viewModel.annotations.count) annotations")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .frame(width: 200)
                .padding(12)
                .background(Color(nsColor: .controlBackgroundColor))
            }
            .padding(12)
        }
    }
}

// MARK: - Body Part Type

enum BodyPartType: String, CaseIterable {
    case eye = "eye"
    case ear = "ear"
    case teeth = "teeth"
    case arm = "arm"
    case body = "body"
    case head = "head"
    case leg = "leg"
    case accessory = "accessory"
    case underpants = "underpants"

    var displayName: String {
        switch self {
        case .eye: return "Eye"
        case .ear: return "Ear"
        case .teeth: return "Teeth"
        case .arm: return "Arm"
        case .body: return "Body"
        case .head: return "Head"
        case .leg: return "Leg"
        case .accessory: return "Accessory"
        case .underpants: return "Underpants"
        }
    }

    var color: Color {
        switch self {
        case .eye: return .blue
        case .ear: return .purple
        case .teeth: return .white
        case .arm: return .orange
        case .body: return .red
        case .head: return .yellow
        case .leg: return .green
        case .accessory: return .pink
        case .underpants: return .cyan
        }
    }
}

// MARK: - Annotation Canvas View

struct AnnotationCanvasView: View {
    let image: NSImage
    let annotations: [Annotation]
    let selectedPart: BodyPartType
    var onAnnotation: (CGRect) -> Void

    @State private var startPoint: CGPoint?
    @State private var currentPoint: CGPoint?
    @State private var scale: CGFloat = 1.0

    var body: some View {
        ZStack {
            // Image
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)

            // Annotation overlays
            Canvas { context, _ in
                for annotation in annotations {
                    let path = Path(roundedRect: annotation.rect, cornerRadius: 2)
                    let partType = BodyPartType(rawValue: annotation.partType) ?? .body
                    context.stroke(
                        path,
                        with: .color(partType.color),
                        lineWidth: 2
                    )
                }

                // Current drawing
                if let start = startPoint, let current = currentPoint {
                    let rect = CGRect(
                        x: min(start.x, current.x),
                        y: min(start.y, current.y),
                        width: abs(current.x - start.x),
                        height: abs(current.y - start.y)
                    )
                    let path = Path(roundedRect: rect, cornerRadius: 2)
                    context.stroke(
                        path,
                        with: .color(selectedPart.color),
                        lineWidth: 2
                    )
                    context.fill(
                        path,
                        with: .color(selectedPart.color.opacity(0.1))
                    )
                }
            }

            // Zoom controls
            VStack {
                HStack {
                    Button(action: { scale *= 1.2 }) {
                        Image(systemName: "plus.magnifyingglass")
                    }
                    Button(action: { scale /= 1.2 }) {
                        Image(systemName: "minus.magnifyingglass")
                    }
                    Button(action: { scale = 1.0 }) {
                        Text("Reset")
                            .font(.system(size: 11))
                    }
                    Spacer()
                }
                .padding(8)
                .background(Color.black.opacity(0.5))
                .foregroundColor(.white)

                Spacer()
            }
            .padding(8)
        }
        .gesture(
            DragGesture(minimumDistance: 5)
                .onChanged { gesture in
                    if startPoint == nil {
                        startPoint = gesture.startLocation
                    }
                    currentPoint = gesture.location
                }
                .onEnded { gesture in
                    let rect = CGRect(
                        x: min(gesture.startLocation.x, gesture.location.x),
                        y: min(gesture.startLocation.y, gesture.location.y),
                        width: abs(gesture.location.x - gesture.startLocation.x),
                        height: abs(gesture.location.y - gesture.startLocation.y)
                    )
                    onAnnotation(rect)
                    startPoint = nil
                    currentPoint = nil
                }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(6)
    }
}

// MARK: - Annotation Item View

struct AnnotationItemView: View {
    let annotation: Annotation
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(annotation.bodyPartType.color)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                Text(annotation.bodyPartType.displayName)
                    .font(.system(size: 11, weight: .semibold))

                Text("(\(Int(annotation.rect.width))×\(Int(annotation.rect.height)))")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(8)
        .background(Color.white.opacity(0.5))
        .cornerRadius(4)
    }
}

// MARK: - Preview

#Preview {
    AnnotationView()
}
