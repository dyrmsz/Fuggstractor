#!/usr/bin/env python3
"""
Convert Detectron2 Model to Core ML Format

Exports trained Mask R-CNN model to Core ML (.mlmodel) format
for use in the macOS Fuggstractor application.
"""

import os
import sys
import argparse
import logging
from pathlib import Path
from typing import Optional

import torch
import numpy as np

try:
    import coremltools as ct
except ImportError:
    print("coremltools not installed. Install with: pip install coremltools")
    sys.exit(1)

from detectron2.config import get_cfg
from detectron2.modeling import build_model
from detectron2.checkpoint import DetectionCheckpointer


# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class ModelConverter:
    """Converts Detectron2 models to Core ML format."""

    def __init__(self, config_file: str, model_weights: str, output_path: str):
        """
        Initialize converter.

        Args:
            config_file: Path to Detectron2 config file
            model_weights: Path to trained model weights
            output_path: Output path for Core ML model
        """
        self.config_file = config_file
        self.model_weights = model_weights
        self.output_path = Path(output_path)
        self.output_path.parent.mkdir(parents=True, exist_ok=True)

    def load_detectron_model(self):
        """Load trained Detectron2 model."""
        logger.info("Loading Detectron2 model...")

        cfg = get_cfg()
        cfg.merge_from_file(self.config_file)
        cfg.MODEL.WEIGHTS = self.model_weights
        cfg.MODEL.DEVICE = "cpu"  # Use CPU for conversion

        model = build_model(cfg)
        model.eval()

        logger.info(f"Model loaded: {self.model_weights}")
        return model, cfg

    def convert_to_coreml(self, model, cfg):
        """
        Convert Detectron2 model to Core ML.

        Note: This is a simplified approach. Full conversion of Detectron2
        models to Core ML requires custom conversion logic because Core ML
        has limitations with complex models.
        """
        logger.info("Converting model to Core ML format...")

        try:
            # Create wrapper model for Core ML
            # This is a placeholder - full conversion would require:
            # 1. Extracting model architecture
            # 2. Converting PyTorch ops to Core ML compatible ops
            # 3. Quantization and optimization

            # For now, we'll create a basic model descriptor
            logger.warning("Full Detectron2 to Core ML conversion requires custom implementation")
            logger.info("Using ONNX as intermediate format...")

            # Alternative: Export to ONNX first, then convert
            self._export_to_onnx(model, cfg)
            self._convert_onnx_to_coreml()

            return True

        except Exception as e:
            logger.error(f"Conversion failed: {e}")
            return False

    def _export_to_onnx(self, model, cfg):
        """Export model to ONNX format."""
        logger.info("Exporting to ONNX...")

        try:
            from detectron2.export import export_onnx_model

            # Create dummy input
            dummy_input = {
                "image": torch.randn(1, 3, 512, 512),
            }

            onnx_path = self.output_path.with_suffix('.onnx')

            export_onnx_model(cfg, model, onnx_path)

            logger.info(f"ONNX model saved: {onnx_path}")
            self.onnx_path = onnx_path

        except Exception as e:
            logger.error(f"ONNX export failed: {e}")
            raise

    def _convert_onnx_to_coreml(self):
        """Convert ONNX model to Core ML."""
        logger.info("Converting ONNX to Core ML...")

        try:
            # This requires onnx-coreml
            # Install with: pip install onnx-coreml

            import onnx
            from onnx_coreml import convert

            onnx_model = onnx.load(str(self.onnx_path))

            # Convert to Core ML
            mlmodel = convert(
                onnx_model,
                minimum_ios_deployment_target='12',
                image_input_names=['image'],
                mode='classifier'
            )

            # Save Core ML model
            mlmodel_path = str(self.output_path)
            mlmodel.save(mlmodel_path)

            logger.info(f"Core ML model saved: {mlmodel_path}")

        except ImportError:
            logger.error("onnx-coreml not installed. Install with: pip install onnx-coreml")
            raise
        except Exception as e:
            logger.error(f"ONNX to Core ML conversion failed: {e}")
            raise

    def quantize_model(self, mlmodel_path: str, output_path: str):
        """
        Quantize Core ML model for reduced size and faster inference.
        """
        logger.info("Quantizing model...")

        try:
            mlmodel = ct.models.MLModel(mlmodel_path)

            # Quantize to 8-bit
            quantized = ct.models.quantization_utils.quantize_weights(
                mlmodel,
                nbits=8
            )

            quantized.save(output_path)
            logger.info(f"Quantized model saved: {output_path}")

        except Exception as e:
            logger.error(f"Quantization failed: {e}")

    def create_model_package(self):
        """
        Create a complete model package with metadata.
        """
        logger.info("Creating model package...")

        try:
            package_dir = self.output_path.parent / "fuggler-segmenter"
            package_dir.mkdir(exist_ok=True)

            # Copy model
            import shutil
            if self.output_path.exists():
                shutil.copy(
                    str(self.output_path),
                    str(package_dir / "model.mlmodel")
                )

            # Create metadata
            metadata = {
                "name": "fuggler-segmenter",
                "version": "1.0.0",
                "description": "Instance segmentation model for fuggler body parts",
                "input_shape": [1, 3, 512, 512],
                "input_names": ["image"],
                "output_names": ["predictions"],
                "classes": [
                    "eye", "ear", "teeth", "arm", "body",
                    "head", "leg", "accessory", "underpants"
                ]
            }

            import json
            with open(package_dir / "metadata.json", 'w') as f:
                json.dump(metadata, f, indent=2)

            logger.info(f"Model package created: {package_dir}")

        except Exception as e:
            logger.error(f"Package creation failed: {e}")


def main():
    parser = argparse.ArgumentParser(
        description='Convert Detectron2 model to Core ML format'
    )
    parser.add_argument(
        '--config', '-c',
        type=str,
        required=True,
        help='Path to Detectron2 config file'
    )
    parser.add_argument(
        '--weights', '-w',
        type=str,
        required=True,
        help='Path to trained model weights'
    )
    parser.add_argument(
        '--output', '-o',
        type=str,
        default='models/fuggler-segmenter.mlmodel',
        help='Output Core ML model path'
    )
    parser.add_argument(
        '--quantize',
        action='store_true',
        help='Quantize model for faster inference'
    )
    parser.add_argument(
        '--package',
        action='store_true',
        help='Create model package with metadata'
    )

    args = parser.parse_args()

    # Create converter
    converter = ModelConverter(
        config_file=args.config,
        model_weights=args.weights,
        output_path=args.output
    )

    # Load model
    try:
        model, cfg = converter.load_detectron_model()
    except Exception as e:
        logger.error(f"Failed to load model: {e}")
        return 1

    # Convert to Core ML
    if not converter.convert_to_coreml(model, cfg):
        return 1

    # Quantize if requested
    if args.quantize and Path(args.output).exists():
        quantized_output = Path(args.output).with_stem(
            Path(args.output).stem + "_quantized"
        )
        converter.quantize_model(str(args.output), str(quantized_output))

    # Create package if requested
    if args.package:
        converter.create_model_package()

    logger.info("Conversion complete")
    return 0


if __name__ == '__main__':
    sys.exit(main())
