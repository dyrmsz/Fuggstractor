# Fuggstractor Python Tools Guide

This guide explains how to use the Python tools for data collection, annotation processing, model training, and conversion.

## Setup

### 1. Create Virtual Environment
```bash
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

### 2. Install Dependencies
```bash
pip install -r Sources/Python/requirements.txt
```

### 3. Verify Installation
```bash
python -c "import detectron2; print('Detectron2 installed successfully')"
```

## Workflow

### Phase 1: Data Collection

Collect fuggler images from the internet to build a training dataset.

```bash
python Sources/Python/data_collector.py \
    --output data/raw \
    --count 500
```

**Options:**
- `--output`: Output directory for collected images
- `--count`: Target number of images to collect
- `--urls`: File containing image URLs (one per line)
- `--timeout`: Request timeout in seconds

**Note:** The data collector includes web scraping capabilities. You can:
1. Provide a file with direct image URLs:
   ```bash
   # Create urls.txt with one URL per line
   echo "https://example.com/image1.jpg" >> urls.txt
   python Sources/Python/data_collector.py --urls urls.txt --output data/raw
   ```

2. Use the Fuggstractor app's annotation tool to manually curate images

### Phase 2: Annotation (Manual)

Use the macOS app to annotate images:

1. Launch Fuggstractor app
2. Go to "Annotator" tab
3. Click "Load Image" to select an image
4. Select body parts from dropdown
5. Draw rectangles around each body part on the canvas
6. Click "Export Annotations" to save in COCO JSON format

**Output:** `image_annotations.json` (COCO format)

### Phase 3: Dataset Preparation

Organize annotated images and create train/validation splits:

```bash
python Sources/Python/prepare_dataset.py \
    --annotation-dir data/processed \
    --image-dir data/raw \
    --output-dir data/processed \
    --train-split 0.8
```

**What it does:**
1. Collects all annotation files
2. Merges annotations into single COCO dataset
3. Creates train/validation splits (80/20 by default)
4. Copies images to train/val directories
5. Generates metadata and statistics

**Output structure:**
```
data/processed/
├── train/
│   ├── image1.jpg
│   ├── image2.jpg
│   └── ...
├── val/
│   ├── image3.jpg
│   ├── image4.jpg
│   └── ...
├── train_annotations.json
├── val_annotations.json
└── dataset_metadata.json
```

### Phase 4: Model Training

Train the instance segmentation model using Detectron2:

```bash
python Sources/Python/train.py \
    --data-dir data/processed \
    --output-dir models \
    --batch-size 4 \
    --learning-rate 0.001 \
    --epochs 100
```

**Options:**
- `--data-dir`: Directory with train/val splits
- `--output-dir`: Directory to save trained models
- `--batch-size`: Batch size (adjust based on GPU memory)
- `--learning-rate`: Learning rate
- `--epochs`: Number of training epochs
- `--num-workers`: Data loading workers
- `--config`: Custom Detectron2 config file
- `--evaluate`: Run evaluation after training

**GPU Usage:**
```bash
# Use GPU if available
export CUDA_VISIBLE_DEVICES=0
python Sources/Python/train.py --data-dir data/processed
```

**Training will:**
1. Register datasets with Detectron2
2. Load pre-trained Mask R-CNN backbone
3. Fine-tune on fuggler images
4. Save checkpoints every epoch
5. Generate training logs and metrics

**Output:**
- `models/model_final.pth` - Final trained weights
- `models/last_checkpoint` - Checkpoint file
- `models/training_metadata.json` - Training parameters
- `training.log` - Detailed logs

### Phase 5: Model Conversion to Core ML

Convert the trained PyTorch model to Core ML format for the macOS app:

```bash
python Sources/Python/convert_to_coreml.py \
    --config path/to/config.yaml \
    --weights models/model_final.pth \
    --output models/fuggler-segmenter.mlmodel \
    --quantize \
    --package
```

**Options:**
- `--config`: Detectron2 config file (required)
- `--weights`: Trained model weights (required)
- `--output`: Output Core ML model path
- `--quantize`: Quantize model for faster inference (optional)
- `--package`: Create model package with metadata (optional)

**Process:**
1. Load trained Detectron2 model
2. Export to ONNX format (intermediate)
3. Convert ONNX to Core ML
4. Optionally quantize for 8-bit inference
5. Create model package with metadata

**Output:**
- `models/fuggler-segmenter.mlmodel` - Core ML model for macOS
- `models/fuggler-segmenter/` - Model package with metadata

### Phase 6: Integration with macOS App

1. Copy the generated `.mlmodel` file to the Xcode project:
   ```bash
   cp models/fuggler-segmenter.mlmodel Fuggstractor.xcodeproj/
   ```

2. Update `SegmentationEngine.swift` to load the correct model file

3. Build and run the app:
   ```bash
   swift build
   swift run
   ```

## Complete Workflow Example

```bash
# Setup
python3 -m venv venv
source venv/bin/activate
pip install -r Sources/Python/requirements.txt

# Data collection
python Sources/Python/data_collector.py \
    --urls fuggler_urls.txt \
    --output data/raw \
    --count 100

# Annotation (done in macOS app)
# ... use Fuggstractor app to annotate images ...

# Dataset preparation
python Sources/Python/prepare_dataset.py \
    --annotation-dir data/processed \
    --image-dir data/raw \
    --output-dir data/processed

# Training
python Sources/Python/train.py \
    --data-dir data/processed \
    --output-dir models \
    --batch-size 4 \
    --epochs 50

# Convert to Core ML
python Sources/Python/convert_to_coreml.py \
    --config path/to/config.yaml \
    --weights models/model_final.pth \
    --output models/fuggler-segmenter.mlmodel
```

## Troubleshooting

### Detectron2 Installation Issues
```bash
# If detectron2 fails to install, try:
pip install torch torchvision
pip install 'git+https://github.com/facebookresearch/detectron2.git'
```

### CUDA/GPU Issues
```bash
# Check GPU availability
python -c "import torch; print(torch.cuda.is_available())"

# If CUDA not available, training will use CPU (slower)
```

### Memory Issues
```bash
# Reduce batch size and number of workers
python Sources/Python/train.py \
    --data-dir data/processed \
    --batch-size 2 \
    --num-workers 0
```

### Dataset Issues
```bash
# Check dataset structure
python Sources/Python/prepare_dataset.py \
    --annotation-dir data/processed \
    --image-dir data/raw \
    --output-dir data/processed
```

## Performance Tips

1. **GPU Acceleration**: Train on GPU for 10-100x speedup
   ```bash
   export CUDA_VISIBLE_DEVICES=0
   ```

2. **Data Augmentation**: More images = better model
   - Collect 500+ images for production quality
   - Annotate 200-300 images minimum

3. **Batch Size**: Larger batches = faster training (if GPU memory allows)
   - Start with batch_size=4, increase to 8-16 if GPU has memory

4. **Learning Rate**: Adjust based on training stability
   - Start with 0.001, adjust if loss doesn't decrease

5. **Epochs**: Train until validation metrics plateau
   - 50-100 epochs typically sufficient
   - Monitor training.log for convergence

## References

- [Detectron2 Documentation](https://detectron2.readthedocs.io/)
- [COCO Dataset Format](https://cocodataset.org/#format-results)
- [Core ML Model Format](https://developer.apple.com/documentation/coreml)
- [PyTorch Documentation](https://pytorch.org/docs/stable/index.html)
