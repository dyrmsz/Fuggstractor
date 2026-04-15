#!/usr/bin/env python3
"""
Fuggler Instance Segmentation Model Training

Trains an instance segmentation model using Detectron2 (Mask R-CNN)
for identifying and extracting body parts from fuggler images.
"""

import os
import sys
import argparse
import logging
from pathlib import Path
from typing import Dict, List
import json
from datetime import datetime

import torch
import numpy as np
from detectron2.config import get_cfg
from detectron2.engine import DefaultTrainer, default_argument_parser, launch
from detectron2.data import MetadataCatalog, DatasetCatalog
from detectron2.data.datasets import register_coco_instances
from detectron2.evaluation import COCOEvaluator, inference_on_dataset
from detectron2.data import build_detection_test_loader


# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('training.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)


class FugglerTrainer:
    """Trains Mask R-CNN model for fuggler body part segmentation."""

    # Body part categories
    CATEGORIES = [
        {"id": 1, "name": "eye"},
        {"id": 2, "name": "ear"},
        {"id": 3, "name": "teeth"},
        {"id": 4, "name": "arm"},
        {"id": 5, "name": "body"},
        {"id": 6, "name": "head"},
        {"id": 7, "name": "leg"},
        {"id": 8, "name": "accessory"},
        {"id": 9, "name": "underpants"},
    ]

    def __init__(
        self,
        config_file: str = None,
        data_dir: str = "data/processed",
        output_dir: str = "models",
        num_workers: int = 4,
        batch_size: int = 4,
        learning_rate: float = 1e-3,
        num_epochs: int = 100,
    ):
        """
        Initialize the trainer.

        Args:
            config_file: Path to custom config file
            data_dir: Directory containing annotated images and annotations
            output_dir: Directory to save trained models
            num_workers: Number of data loading workers
            batch_size: Batch size for training
            learning_rate: Learning rate
            num_epochs: Number of training epochs
        """
        self.data_dir = Path(data_dir)
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)
        self.num_workers = num_workers
        self.batch_size = batch_size
        self.learning_rate = learning_rate
        self.num_epochs = num_epochs
        self.config_file = config_file

        logger.info("Trainer initialized")
        logger.info(f"Data directory: {self.data_dir}")
        logger.info(f"Output directory: {self.output_dir}")

    def register_datasets(self):
        """Register training and validation datasets."""
        logger.info("Registering datasets...")

        train_annotation_file = self.data_dir / "train_annotations.json"
        train_image_dir = self.data_dir / "train"

        val_annotation_file = self.data_dir / "val_annotations.json"
        val_image_dir = self.data_dir / "val"

        # Check if annotation files exist
        if not train_annotation_file.exists():
            logger.warning(f"Training annotations not found: {train_annotation_file}")
            return False

        try:
            register_coco_instances(
                "fuggler_train",
                {},
                str(train_annotation_file),
                str(train_image_dir)
            )

            if val_annotation_file.exists():
                register_coco_instances(
                    "fuggler_val",
                    {},
                    str(val_annotation_file),
                    str(val_image_dir)
                )
            else:
                logger.warning(f"Validation annotations not found: {val_annotation_file}")

            logger.info("Datasets registered successfully")
            return True

        except Exception as e:
            logger.error(f"Failed to register datasets: {e}")
            return False

    def setup_config(self) -> get_cfg:
        """Set up Detectron2 configuration."""
        cfg = get_cfg()

        if self.config_file:
            cfg.merge_from_file(self.config_file)
        else:
            # Use default Mask R-CNN configuration
            cfg.merge_from_list([
                "MODEL.BACKBONE.NAME", "build_resnet_backbone",
                "MODEL.RESNETS.DEPTH", 50,
                "MODEL.RESNETS.NUM_GROUPS", 1,
                "MODEL.RESNETS.WIDTH_PER_GROUP", 64,
                "MODEL.RESNETS.STRIDE_IN_1X1", False,
                "MODEL.RPN.IN_FEATURES", ["res2", "res3", "res4", "res5"],
                "MODEL.ANCHOR_GENERATOR.SIZES", [[32], [64], [128], [256], [512]],
                "MODEL.ANCHOR_GENERATOR.ASPECT_RATIOS", [[0.5, 1.0, 2.0]],
            ])

        # Update with training parameters
        cfg.DATASETS.TRAIN = ("fuggler_train",)
        cfg.DATASETS.TEST = ()
        cfg.MODEL.DEVICE = "cuda" if torch.cuda.is_available() else "cpu"
        cfg.DATALOADER.NUM_WORKERS = self.num_workers
        cfg.SOLVER.IMS_PER_BATCH = self.batch_size
        cfg.SOLVER.BASE_LR = self.learning_rate
        cfg.SOLVER.MAX_ITER = self.num_epochs
        cfg.SOLVER.STEPS = (int(self.num_epochs * 0.8),)
        cfg.SOLVER.GAMMA = 0.1
        cfg.MODEL.ROI_HEADS.BATCH_SIZE_PER_IMAGE = 512
        cfg.MODEL.ROI_HEADS.NUM_CLASSES = len(self.CATEGORIES)
        cfg.MODEL.MASK_ON = True
        cfg.OUTPUT_DIR = str(self.output_dir)

        logger.info(f"Using device: {cfg.MODEL.DEVICE}")
        return cfg

    def train(self):
        """Train the model."""
        logger.info("Starting model training...")

        # Register datasets
        if not self.register_datasets():
            logger.error("Failed to register datasets")
            return False

        # Setup configuration
        cfg = self.setup_config()

        # Create trainer
        try:
            trainer = DefaultTrainer(cfg)
            trainer.resume_or_load(resume=False)
            trainer.train()

            logger.info("Training completed successfully")
            return True

        except Exception as e:
            logger.error(f"Training failed: {e}")
            return False

    def evaluate(self):
        """Evaluate the trained model."""
        logger.info("Evaluating model...")

        cfg = self.setup_config()

        # Register validation dataset
        if not (self.data_dir / "val_annotations.json").exists():
            logger.warning("Validation dataset not found")
            return

        try:
            from detectron2.modeling import build_model
            model = build_model(cfg)

            evaluator = COCOEvaluator("fuggler_val", output_dir=str(self.output_dir))
            val_loader = build_detection_test_loader(cfg, "fuggler_val")
            inference_on_dataset(model, val_loader, evaluator)

            logger.info("Evaluation completed")

        except Exception as e:
            logger.error(f"Evaluation failed: {e}")

    def save_metadata(self):
        """Save training metadata."""
        metadata = {
            "timestamp": datetime.now().isoformat(),
            "categories": self.CATEGORIES,
            "num_epochs": self.num_epochs,
            "batch_size": self.batch_size,
            "learning_rate": self.learning_rate,
            "device": "cuda" if torch.cuda.is_available() else "cpu",
        }

        metadata_file = self.output_dir / "training_metadata.json"
        with open(metadata_file, 'w') as f:
            json.dump(metadata, f, indent=2)

        logger.info(f"Metadata saved: {metadata_file}")


def main():
    parser = argparse.ArgumentParser(
        description='Train Mask R-CNN model for fuggler body part segmentation'
    )
    parser.add_argument(
        '--data-dir', '-d',
        type=str,
        default='data/processed',
        help='Directory containing annotated images'
    )
    parser.add_argument(
        '--output-dir', '-o',
        type=str,
        default='models',
        help='Output directory for trained models'
    )
    parser.add_argument(
        '--config',
        type=str,
        help='Path to custom Detectron2 config file'
    )
    parser.add_argument(
        '--batch-size', '-b',
        type=int,
        default=4,
        help='Batch size for training'
    )
    parser.add_argument(
        '--learning-rate', '-lr',
        type=float,
        default=1e-3,
        help='Learning rate'
    )
    parser.add_argument(
        '--epochs', '-e',
        type=int,
        default=100,
        help='Number of training epochs'
    )
    parser.add_argument(
        '--num-workers', '-w',
        type=int,
        default=4,
        help='Number of data loading workers'
    )
    parser.add_argument(
        '--evaluate',
        action='store_true',
        help='Run evaluation after training'
    )

    args = parser.parse_args()

    # Create trainer
    trainer = FugglerTrainer(
        config_file=args.config,
        data_dir=args.data_dir,
        output_dir=args.output_dir,
        num_workers=args.num_workers,
        batch_size=args.batch_size,
        learning_rate=args.learning_rate,
        num_epochs=args.epochs,
    )

    # Train
    success = trainer.train()

    # Evaluate if requested
    if success and args.evaluate:
        trainer.evaluate()

    # Save metadata
    trainer.save_metadata()

    return 0 if success else 1


if __name__ == '__main__':
    sys.exit(main())
