# Fuggstractor

A native macOS application for automated identification and extraction of body parts from fuggler images using instance segmentation machine learning models.

## Quick Start

```bash
# Setup macOS app
swift build
swift run Fuggstractor

# Setup Python environment
python3 -m venv venv
source venv/bin/activate
pip install -r Sources/Python/requirements.txt
```

For detailed setup instructions, see [DEVELOPMENT.md](DEVELOPMENT.md).

## Features

- **Automated Body Part Extraction**: Identifies and extracts 9 distinct body parts (eye, ear, teeth, arm, body, head, leg, accessory, underpants)
- **Instance Segmentation**: Distinguishes multiple instances of the same body part (e.g., left and right eyes/arms)
- **Transparent PNG Export**: Saves individual body parts with transparent backgrounds for compositing
- **Built-in Annotation Tool**: Label fuggler images with interactive drawing canvas to create training data
- **Full ML Pipeline**: From data collection → annotation → training → Core ML conversion
- **Batch Processing**: Process multiple images efficiently with progress tracking
- **COCO Dataset Support**: Fully compatible with COCO JSON annotation format

## Project Structure

```
Fuggstractor/
├── Sources/
│   ├── macOS-App/                    # Swift/SwiftUI macOS application
│   │   ├── FuggstractorApp.swift     # App entry point and state
│   │   ├── MainView.swift            # Tab navigation
│   │   ├── AnnotationView.swift      # Annotation tool UI
│   │   ├── ProcessingView.swift      # Image processing UI
│   │   ├── Models/                   # Image processing engines
│   │   │   ├── SegmentationEngine.swift
│   │   │   ├── BackgroundRemovalEngine.swift
│   │   │   └── PNGExporter.swift
│   │   └── ViewModels/               # MVVM view models
│   │       ├── ProcessingViewModel.swift
│   │       └── AnnotationViewModel.swift
│   └── Python/                       # Python ML pipeline
│       ├── data_collector.py         # Web scraping for images
│       ├── prepare_dataset.py        # Dataset organization
│       ├── train.py                  # Model training with Detectron2
│       ├── convert_to_coreml.py      # PyTorch → Core ML conversion
│       ├── config.yaml               # Training configuration
│       └── requirements.txt          # Python dependencies
├── data/                             # Dataset directory
│   ├── raw/                          # Raw collected images
│   └── processed/                    # Annotated training data
├── models/                           # Trained models
├── tests/                            # Swift unit tests
├── DEVELOPMENT.md                    # Development guide
├── PYTHON_GUIDE.md                   # Python tools documentation
└── README.md
```

## Architecture

The application consists of two main components:

### 1. macOS Application (Swift/SwiftUI)
- **UI Framework**: SwiftUI with native macOS integration
- **Processing**: Image segmentation, background removal, PNG export
- **ML Framework**: Core ML for model inference
- **Two Modes**:
  - **Annotation Mode**: Interactive tool for labeling body parts (creates training data)
  - **Processing Mode**: Automatic extraction of body parts from images

### 2. Python ML Pipeline
- **Data Collection**: Web scraping with quality filtering
- **Data Preparation**: COCO dataset creation with train/val splits
- **Model Training**: Detectron2 Mask R-CNN instance segmentation
- **Model Conversion**: PyTorch → ONNX → Core ML conversion

### Workflow

```
1. Data Collection          2. Annotation              3. Dataset Prep
   (web scraping) ──────→   (interactive tool)  ──→   (train/val split)
                                                              │
                                                              v
                                                    4. Model Training
                                                    (Detectron2)
                                                              │
                                                              v
                                                    5. Model Conversion
                                                    (PyTorch → Core ML)
                                                              │
                                                              v
                                                    6. macOS App
                                                    (image processing)
```

## Requirements

### macOS Requirements
- **OS**: macOS 12.0 or later
- **IDE**: Xcode 14.0 or later
- **Language**: Swift 5.7 or later
- **RAM**: 8GB minimum (16GB recommended)
- **Disk**: 10GB for data and models

### Python Requirements
- **Python**: 3.8 or later
- **PyTorch**: 2.0+
- **Detectron2**: Latest version
- **CUDA** (optional): For GPU acceleration during training

See [PYTHON_GUIDE.md](PYTHON_GUIDE.md) for detailed Python setup.

## Installation & Setup

### macOS Application

1. **Clone repository**
   ```bash
   git clone <repository-url>
   cd Fuggstractor
   ```

2. **Build**
   ```bash
   swift build
   ```

3. **Run**
   ```bash
   swift run Fuggstractor
   ```

4. **Or open in Xcode**
   ```bash
   open Package.swift
   ```

### Python Environment

1. **Create virtual environment**
   ```bash
   python3 -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

2. **Install dependencies**
   ```bash
   pip install -r Sources/Python/requirements.txt
   ```

## Usage Guide

### Complete Workflow

**Step 1: Collect Data**
```bash
python Sources/Python/data_collector.py \
    --urls image_urls.txt \
    --output data/raw \
    --count 100
```

**Step 2: Annotate Images**
1. Launch Fuggstractor app
2. Switch to "Annotator" tab
3. Load images and draw rectangles around body parts
4. Export annotations (saved as COCO JSON)

**Step 3: Prepare Dataset**
```bash
python Sources/Python/prepare_dataset.py \
    --annotation-dir data/processed \
    --image-dir data/raw \
    --output-dir data/processed
```

**Step 4: Train Model**
```bash
python Sources/Python/train.py \
    --data-dir data/processed \
    --output-dir models \
    --batch-size 4 \
    --epochs 50
```

**Step 5: Convert to Core ML**
```bash
python Sources/Python/convert_to_coreml.py \
    --config Sources/Python/config.yaml \
    --weights models/model_final.pth \
    --output models/fuggler-segmenter.mlmodel
```

**Step 6: Use in App**
1. Copy `.mlmodel` file to project
2. Update `SegmentationEngine.swift` to load new model
3. Rebuild and use "Processor" mode to extract body parts

### Quick Processing

Once a trained model is integrated:
1. Launch Fuggstractor
2. Switch to "Processor" tab
3. Drag-and-drop images or click "Browse Files"
4. Wait for processing to complete
5. Click "Open Export Folder" to view results

## Model Architecture

- **Type**: Instance Segmentation
- **Backbone**: ResNet-50
- **Model**: Mask R-CNN (via Detectron2)
- **Classes**: 9 body part types
- **Inference**: Core ML on macOS
- **Training**: PyTorch with Detectron2

## Body Parts Extracted

The application segments and extracts the following 9 body part categories:

1. **Eye** - Eyes (distinguishes left/right)
2. **Ear** - Ears (distinguishes left/right)
3. **Teeth** - Mouth/dental features
4. **Arm** - Arms (distinguishes left/right and multiple)
5. **Body** - Main torso/body
6. **Head** - Head/face
7. **Leg** - Legs (distinguishes left/right)
8. **Accessory** - Clothing/attachments
9. **Underpants** - Lower garments

Each body part is saved as an individual PNG with transparent background.

## Documentation

- **[DEVELOPMENT.md](DEVELOPMENT.md)**: Complete development guide with architecture details, setup instructions, and contributing guidelines
- **[PYTHON_GUIDE.md](PYTHON_GUIDE.md)**: Detailed Python tools documentation with workflow examples and troubleshooting

## Troubleshooting

### Swift Build Issues
```bash
# Clean and rebuild
rm -rf .build
swift build
```

### Python/Detectron2 Issues
```bash
# Reinstall Detectron2
pip install --force-reinstall 'detectron2 @ git+https://github.com/facebookresearch/detectron2.git'

# Check PyTorch installation
python -c "import torch; print(torch.__version__)"
```

### GPU Not Being Used
```bash
# Verify CUDA availability
python -c "import torch; print(torch.cuda.is_available())"

# Set GPU device
export CUDA_VISIBLE_DEVICES=0
python Sources/Python/train.py --data-dir data/processed
```

### Out of Memory Errors
```bash
# Reduce batch size and number of workers
python Sources/Python/train.py \
    --data-dir data/processed \
    --batch-size 2 \
    --num-workers 0
```

See [PYTHON_GUIDE.md](PYTHON_GUIDE.md#troubleshooting) for more troubleshooting tips.

## Testing

### Run Swift Tests
```bash
swift test
```

### Test Coverage
Tests are provided for:
- Segmentation engine (Core ML inference)
- Background removal engine (mask processing)
- PNG exporter (transparency handling)
- View models (state management)

## Performance

### Training Performance
- **GPU**: 10-100x faster than CPU
- **Batch Size**: Larger batches train faster (if GPU memory allows)
- **Data Augmentation**: Improves model quality but increases training time

### Inference Performance
- **macOS M1/M2**: ~500ms per image
- **macOS Intel**: ~2-5 seconds per image
- **Core ML optimizations**: Quantization reduces model size by 4x

### Memory Requirements
- **Data Collection**: Minimal (depends on image count)
- **Training**: 8-16GB RAM (with GPU) or 16GB+ (CPU only)
- **Inference**: <500MB (with Core ML)

## Contributing

We welcome contributions! Please:

1. **Fork the repository**
2. **Create feature branch**: `git checkout -b feature/description`
3. **Make changes** with clear, focused commits
4. **Add tests** for new functionality
5. **Update documentation** as needed
6. **Push and create Pull Request**

### Code Style Guidelines

**Swift**:
- Follow Apple Swift style guide
- Use 4-space indentation
- Use meaningful variable names
- Add comments for complex logic

**Python**:
- Follow PEP 8
- Use 4-space indentation
- Add docstrings to functions/classes
- Use type hints where possible

### Commit Message Format
```
[Category] Brief description

Longer explanation if needed

- Bullet points for multiple changes
```

Examples:
- `[UI] Add dark mode support`
- `[ML] Improve model training stability`
- `[Docs] Update getting started guide`

## License

MIT License - See LICENSE file for details

## Citation

If you use Fuggstractor in academic work, please cite:

```bibtex
@software{fuggstractor2024,
  title={Fuggstractor: Automated Body Part Extraction from Fuggler Images},
  author={Your Name},
  year={2024},
  url={https://github.com/dyrmsz/Fuggstractor}
}
```

## Support & Contact

- **Issues**: Create an issue in the GitHub repository
- **Discussions**: Use GitHub Discussions for questions
- **Documentation**: See [DEVELOPMENT.md](DEVELOPMENT.md) and [PYTHON_GUIDE.md](PYTHON_GUIDE.md)

## Acknowledgments

- Built with [Detectron2](https://github.com/facebookresearch/detectron2)
- macOS UI with [SwiftUI](https://developer.apple.com/xcode/swiftui/)
- Machine learning with [PyTorch](https://pytorch.org/)
- Image processing with [Core Image](https://developer.apple.com/coreimage/) and [Accelerate](https://developer.apple.com/accelerate/)

---

**Status**: Active Development

**Latest Release**: v1.0.0-alpha (in progress)

**Contributors**: Welcome!
