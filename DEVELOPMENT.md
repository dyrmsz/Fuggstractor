# Fuggstractor Development Guide

This guide explains the project structure, architecture, and how to work with both Swift and Python components.

## Table of Contents
1. [Project Overview](#project-overview)
2. [Architecture](#architecture)
3. [Development Setup](#development-setup)
4. [Swift Development](#swift-development)
5. [Python Development](#python-development)
6. [Testing](#testing)
7. [Building and Running](#building-and-running)
8. [Contributing](#contributing)

## Project Overview

**Fuggstractor** is a native macOS application that automatically identifies and extracts body parts from images of "fugglers" using instance segmentation machine learning models.

### Key Features
- **Annotation Tool**: Built-in UI to label body parts in images
- **ML Pipeline**: Full machine learning workflow from data collection to model training
- **Image Processing**: Segmentation, background removal, and transparent PNG export
- **User-Friendly**: Native SwiftUI interface with drag-and-drop support

### Technology Stack
- **macOS UI**: Swift + SwiftUI
- **ML Framework**: Core ML (inference) + Detectron2 (training)
- **Image Processing**: Core Image, Accelerate framework
- **Data Format**: COCO JSON annotations
- **Python Tools**: PyTorch, Detectron2, OpenCV

## Architecture

### Overall Structure

```
┌─────────────────────────────────────────────────────────┐
│           macOS Application (Swift/SwiftUI)             │
│                                                         │
│  ┌──────────────┐           ┌──────────────┐           │
│  │ Annotation   │           │  Processing  │           │
│  │ Tool         │           │  Mode        │           │
│  └──────────────┘           └──────────────┘           │
│         │                           │                   │
└─────────────────────────────────────────────────────────┘
         │                           │
         v                           v
    ┌─────────────────────────────────────────────────┐
    │     Image Processing Engines (Swift)             │
    │                                                 │
    │  ├─ SegmentationEngine (Core ML inference)      │
    │  ├─ BackgroundRemovalEngine (mask processing)   │
    │  └─ PNGExporter (transparent PNG output)        │
    └─────────────────────────────────────────────────┘
                        │
                        v
    ┌─────────────────────────────────────────────────┐
    │        Core ML Model                             │
    │  (Trained with Detectron2, converted)           │
    └─────────────────────────────────────────────────┘
                        │
                        v
    ┌─────────────────────────────────────────────────┐
    │        Python ML Pipeline                        │
    │                                                 │
    │  ├─ data_collector.py (web scraping)            │
    │  ├─ prepare_dataset.py (train/val splits)       │
    │  ├─ train.py (Detectron2 training)              │
    │  └─ convert_to_coreml.py (model conversion)     │
    └─────────────────────────────────────────────────┘
```

### Module Breakdown

#### Swift/macOS Components

**FuggstractorApp.swift**
- Entry point for the macOS application
- Global app state management
- Window configuration

**MainView.swift**
- Tab-based navigation between Annotation and Processing modes
- Settings panel
- Export directory configuration

**AnnotationView.swift**
- Interactive canvas for drawing annotations
- Body part selection
- Annotation list management
- COCO JSON export

**ProcessingView.swift**
- Drag-and-drop image upload
- Processing progress tracking
- Results display
- Export management

**ViewModels/**
- `ProcessingViewModel.swift`: Image processing workflow logic
- `AnnotationViewModel.swift`: Annotation tool state management

**Models/**
- `SegmentationEngine.swift`: Core ML model inference
- `BackgroundRemovalEngine.swift`: Mask application and edge processing
- `PNGExporter.swift`: PNG export with transparency

#### Python Components

**data_collector.py**
- Web scraping for fuggler images
- Image quality filtering
- Deduplication

**prepare_dataset.py**
- Merge annotations from multiple sources
- Create train/validation splits
- Generate COCO dataset format

**train.py**
- Detectron2 Mask R-CNN training
- Checkpoint management
- Evaluation metrics

**convert_to_coreml.py**
- PyTorch to ONNX conversion
- ONNX to Core ML conversion
- Model quantization

## Development Setup

### Prerequisites
- macOS 12.0+
- Xcode 14.0+
- Swift 5.7+
- Python 3.8+
- Git

### macOS Setup

1. **Clone repository**
   ```bash
   git clone <repository-url>
   cd Fuggstractor
   ```

2. **Open in Xcode**
   ```bash
   open Package.swift
   ```

3. **Build and run**
   ```bash
   swift build
   swift run
   ```

### Python Setup

See [PYTHON_GUIDE.md](PYTHON_GUIDE.md) for complete Python environment setup.

Quick setup:
```bash
python3 -m venv venv
source venv/bin/activate
pip install -r Sources/Python/requirements.txt
```

## Swift Development

### Code Organization

Swift code is organized by functionality:
- **Views**: UI components (AnnotationView, ProcessingView, MainView)
- **ViewModels**: Business logic (ProcessingViewModel, AnnotationViewModel)
- **Models**: Data structures and engines (SegmentationEngine, BackgroundRemovalEngine, PNGExporter)

### Adding New Features

1. **Create a new view** (if UI is needed):
   ```swift
   struct MyNewView: View {
       @EnvironmentObject var appState: AppState
       @StateObject private var viewModel = MyViewModel()
       
       var body: some View {
           // UI code
       }
   }
   ```

2. **Create a view model** (for state management):
   ```swift
   class MyViewModel: ObservableObject {
       @Published var someProperty = ""
       
       func someFunction() {
           // Logic
       }
   }
   ```

3. **Update MainView** to include the new feature:
   ```swift
   // Add to tab bar or content area
   ```

### Key Swift Patterns

**ObservableObject Pattern**
- Use `@Published` for state changes
- Use `@StateObject` to own view models
- Use `@EnvironmentObject` to share state

**Error Handling**
```swift
do {
    try segmentationEngine.segment(image: testImage)
} catch {
    errorMessage = error.localizedDescription
}
```

**Async/Await**
```swift
async {
    let result = await processImage()
}
```

## Python Development

### Code Organization

Python scripts are organized by phase:
1. **Data Collection**: `data_collector.py`
2. **Dataset Preparation**: `prepare_dataset.py`
3. **Model Training**: `train.py`
4. **Model Conversion**: `convert_to_coreml.py`

### Adding New Python Features

1. **Add dependencies** to `requirements.txt`
2. **Create new script** following existing pattern
3. **Add CLI arguments** with `argparse`
4. **Include logging** for debugging

### Python Best Practices

**Logging**
```python
import logging
logger = logging.getLogger(__name__)
logger.info("Processing complete")
```

**Type Hints**
```python
def process_image(image_path: str) -> Dict[str, Any]:
    return {}
```

**Error Handling**
```python
try:
    result = process_data()
except ValueError as e:
    logger.error(f"Processing failed: {e}")
    raise
```

## Testing

### Swift Tests

Located in `tests/ImageProcessingTests.swift`

Run tests:
```bash
swift test
```

Test structure:
```swift
class SomeEngineTests: XCTestCase {
    func testFeature() {
        // Arrange
        let engine = SomeEngine()
        
        // Act
        let result = engine.doSomething()
        
        // Assert
        XCTAssertEqual(result, expectedValue)
    }
}
```

### Python Tests

No tests yet - would follow pytest pattern:
```python
# tests/test_data_collector.py
def test_image_filtering():
    collector = ImageCollector()
    assert collector.is_valid_image(test_image)
```

To add: `pytest` to requirements.txt

## Building and Running

### macOS App

**Development Build**
```bash
swift build
```

**Run**
```bash
swift run Fuggstractor
```

**Release Build**
```bash
swift build -c release
```

### Python Scripts

**Data Collection**
```bash
source venv/bin/activate
python Sources/Python/data_collector.py --output data/raw --count 100
```

**Training**
```bash
python Sources/Python/train.py --data-dir data/processed --output-dir models
```

## Workflows

### Complete Development Workflow

1. **Collect Data**
   ```bash
   python data_collector.py --urls images.txt --output data/raw
   ```

2. **Annotate** (in macOS app)
   - Run app
   - Switch to Annotation tab
   - Load images and draw body parts
   - Export annotations

3. **Prepare Dataset**
   ```bash
   python prepare_dataset.py --annotation-dir data/processed --image-dir data/raw
   ```

4. **Train Model**
   ```bash
   python train.py --data-dir data/processed --output-dir models
   ```

5. **Convert Model**
   ```bash
   python convert_to_coreml.py --config Sources/Python/config.yaml --weights models/model_final.pth
   ```

6. **Update App**
   - Copy .mlmodel file to Xcode project
   - Update SegmentationEngine.swift to load new model
   - Rebuild and test

7. **Run Tests**
   ```bash
   swift test
   ```

## Debugging

### Swift Debugging

1. Use Xcode debugger:
   - Set breakpoints
   - Use `po` command to print objects
   - View state in Variables panel

2. Add logging:
   ```swift
   os_log("Debug message: %{public}@", log: OSLog.default, type: .debug, someValue)
   ```

### Python Debugging

1. Add print statements or use logging
2. Use Python debugger:
   ```bash
   python -m pdb script.py
   ```

3. Check logs:
   ```bash
   tail -f training.log
   tail -f data_collection.log
   ```

## Performance Considerations

### Swift Optimization
- Use Core Image for GPU-accelerated image processing
- Batch process images when possible
- Use `DispatchQueue` for background processing
- Profile with Instruments

### Python Optimization
- Use GPU for training: `export CUDA_VISIBLE_DEVICES=0`
- Increase batch size for faster training (if GPU memory allows)
- Use data augmentation for better model generalization
- Monitor memory usage with `nvidia-smi` (for CUDA)

## Common Issues and Solutions

### Swift Issues

**Swift package resolution fails**
```bash
rm -rf .build
swift build
```

**UI not responding**
- Check for blocking operations on main thread
- Use async/await or DispatchQueue for background work

### Python Issues

**Detectron2 installation fails**
```bash
pip install 'detectron2 @ git+https://github.com/facebookresearch/detectron2.git'
```

**Out of memory during training**
- Reduce batch_size
- Reduce MAX_SIZE_TRAIN in config
- Use fewer data loader workers

## Contributing

### Code Style

**Swift**
- Follow Apple Swift style guidelines
- Use 4-space indentation
- Use meaningful variable names

**Python**
- Follow PEP 8
- Use 4-space indentation
- Add docstrings to functions

### Commit Messages

Format: `[Category] Brief description`

Examples:
- `[UI] Add image preview to annotation tool`
- `[ML] Fix model training convergence issue`
- `[Docs] Update Python guide with new examples`

### Pull Request Process

1. Create feature branch: `git checkout -b feature/description`
2. Make changes
3. Test thoroughly
4. Commit with clear messages
5. Push and create PR

## References

- [Swift Documentation](https://docs.swift.org)
- [SwiftUI Tutorial](https://developer.apple.com/tutorials/swiftui)
- [Detectron2 Docs](https://detectron2.readthedocs.io)
- [Core ML Guide](https://developer.apple.com/documentation/coreml)
- [COCO Dataset Format](https://cocodataset.org)

## Getting Help

- Check existing issues on GitHub
- Refer to PYTHON_GUIDE.md for ML workflow questions
- Check training.log and data_collection.log for errors
- Use Xcode debugging tools for Swift issues
