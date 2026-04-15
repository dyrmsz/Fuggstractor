# Fuggstractor

A native macOS application for automated identification and extraction of body parts from fuggler images using instance segmentation ML models.

## Features

- **Automated Body Part Extraction**: Identifies and extracts 11 body parts (eye, ear, teeth, arms, body, head, legs, accessory, underpants)
- **Instance Segmentation**: Distinguishes multiple instances of the same body part (e.g., left and right eyes)
- **Transparent PNG Export**: Saves individual body parts with transparent backgrounds
- **Built-in Annotation Tool**: Label fuggler images to improve model accuracy
- **Batch Processing**: Process multiple images efficiently

## Project Structure

```
Fuggstractor/
├── Sources/
│   ├── macOS-App/           # Swift/SwiftUI application
│   │   ├── Models/          # Core ML and image processing
│   │   └── ViewModels/      # MVVM view models
│   └── Python/              # Python scripts for data and ML
├── data/                    # Dataset directory
│   ├── raw/                 # Raw collected fuggler images
│   └── processed/           # Annotated images
├── models/                  # Trained Core ML models
├── tests/                   # Unit and integration tests
└── README.md
```

## Architecture

### Phase 1: Data Collection
Scrape fuggler images from the internet to build a training dataset.

### Phase 2: Annotation Tool
Built-in SwiftUI tool for labeling body parts in images (COCO JSON format).

### Phase 3: Model Training
Train instance segmentation model using PyTorch/Detectron2 and convert to Core ML.

### Phase 4: Image Processing
Core engines for segmentation, background removal, and PNG export with transparency.

### Phase 5: Main Application
Native macOS app UI for image upload, processing, and batch export.

### Phase 6: Testing & Optimization
Quality assurance, performance tuning, and optimization.

## Requirements

### macOS
- macOS 12.0 or later
- Xcode 14.0 or later
- Swift 5.7 or later

### Python
- Python 3.8+
- PyTorch 2.0+
- Detectron2 or YOLOv5
- See `requirements.txt` for full dependencies

## Installation & Setup

### macOS App
```bash
cd Fuggstractor
swift build
swift run
```

### Python Environment
```bash
pip install -r Sources/Python/requirements.txt
```

## Usage

### Collecting Training Data
```bash
python Sources/Python/data_collector.py --output data/raw --count 500
```

### Annotating Images
Launch the Fuggstractor app → Annotation Mode → Select images and draw body parts

### Training the Model
```bash
python Sources/Python/train.py --data data/processed --output models/
```

### Processing Images
Launch the Fuggstractor app → Processing Mode → Drag-and-drop images → Export PNGs

## Model Details

- **Architecture**: Instance Segmentation (Mask R-CNN / YOLOv5-seg)
- **Classes**: 11 body part types
- **Framework**: Core ML (for inference)
- **Training**: PyTorch with Detectron2

## Body Parts Extracted

1. Eye (instance: left, right)
2. Ear (instance: left, right)
3. Teeth
4. Arms (instance: left, right, etc.)
5. Body
6. Head
7. Legs (instance: left, right)
8. Accessory
9. Underpants

## License

MIT License - See LICENSE file for details

## Contributing

Contributions are welcome! Please ensure all changes maintain code quality and pass tests.

## Support

For issues or feature requests, please create an issue in the repository.
