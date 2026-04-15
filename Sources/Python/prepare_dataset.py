#!/usr/bin/env python3
"""
Dataset Preparation Script

Organizes annotated images and creates train/validation splits
in COCO format for model training.
"""

import os
import sys
import argparse
import json
import logging
from pathlib import Path
from typing import List, Dict, Tuple
import shutil
from datetime import datetime
import random


# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('dataset_preparation.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)


class DatasetPreparer:
    """Prepares annotated images for model training."""

    def __init__(
        self,
        annotation_dir: str,
        image_dir: str,
        output_dir: str,
        train_split: float = 0.8,
        val_split: float = 0.2,
        seed: int = 42
    ):
        """
        Initialize dataset preparer.

        Args:
            annotation_dir: Directory containing annotation JSON files
            image_dir: Directory containing images
            output_dir: Output directory for processed dataset
            train_split: Fraction for training set
            val_split: Fraction for validation set
            seed: Random seed for reproducibility
        """
        self.annotation_dir = Path(annotation_dir)
        self.image_dir = Path(image_dir)
        self.output_dir = Path(output_dir)
        self.train_split = train_split
        self.val_split = val_split
        self.seed = seed

        random.seed(seed)
        np.random.seed(seed)

        # Create output directories
        self.output_dir.mkdir(parents=True, exist_ok=True)
        (self.output_dir / "train").mkdir(exist_ok=True)
        (self.output_dir / "val").mkdir(exist_ok=True)

        self.stats = {
            'total_images': 0,
            'train_images': 0,
            'val_images': 0,
            'total_annotations': 0,
            'train_annotations': 0,
            'val_annotations': 0,
        }

    def load_annotations(self, annotation_file: Path) -> Dict:
        """Load COCO format annotations."""
        try:
            with open(annotation_file, 'r') as f:
                return json.load(f)
        except Exception as e:
            logger.error(f"Failed to load annotations from {annotation_file}: {e}")
            return None

    def collect_all_annotations(self) -> List[Tuple[Dict, Path]]:
        """Collect all annotation files."""
        annotations = []

        for annotation_file in self.annotation_dir.glob("**/*_annotations.json"):
            coco_data = self.load_annotations(annotation_file)
            if coco_data:
                annotations.append((coco_data, annotation_file))
                logger.info(f"Loaded annotations: {annotation_file}")

        logger.info(f"Total annotation files: {len(annotations)}")
        return annotations

    def merge_annotations(self, all_annotations: List[Tuple[Dict, Path]]) -> Dict:
        """Merge multiple annotation files into single COCO dataset."""
        merged = {
            "images": [],
            "annotations": [],
            "categories": []
        }

        # Collect categories
        category_map = {}  # Maps old_id to new_id
        categories_by_name = {}

        for coco_data, _ in all_annotations:
            for category in coco_data.get("categories", []):
                cat_name = category.get("name")
                if cat_name not in categories_by_name:
                    new_id = len(merged["categories"]) + 1
                    categories_by_name[cat_name] = new_id
                    merged["categories"].append({
                        "id": new_id,
                        "name": cat_name,
                        "supercategory": category.get("supercategory", "part")
                    })

        # Merge images and annotations
        image_id_map = {}  # Maps (file, old_id) to new_id
        next_image_id = 1
        next_annotation_id = 1

        for coco_data, _ in all_annotations:
            # Create mapping for this dataset
            local_id_map = {}
            for old_image in coco_data.get("images", []):
                old_id = old_image["id"]
                local_id_map[old_id] = next_image_id

                # Add image with new ID
                new_image = old_image.copy()
                new_image["id"] = next_image_id
                merged["images"].append(new_image)

                next_image_id += 1

            # Add annotations with remapped IDs
            for old_annotation in coco_data.get("annotations", []):
                old_image_id = old_annotation.get("image_id")
                if old_image_id in local_id_map:
                    new_annotation = old_annotation.copy()
                    new_annotation["id"] = next_annotation_id
                    new_annotation["image_id"] = local_id_map[old_image_id]

                    # Remap category ID
                    old_cat_id = new_annotation.get("category_id")
                    if old_cat_id and old_cat_id <= len(coco_data.get("categories", [])):
                        old_cat_name = coco_data["categories"][old_cat_id - 1].get("name")
                        new_annotation["category_id"] = categories_by_name.get(old_cat_name, 1)

                    merged["annotations"].append(new_annotation)
                    next_annotation_id += 1

        self.stats['total_images'] = len(merged["images"])
        self.stats['total_annotations'] = len(merged["annotations"])

        logger.info(f"Merged images: {self.stats['total_images']}")
        logger.info(f"Merged annotations: {self.stats['total_annotations']}")

        return merged

    def split_dataset(self, coco_data: Dict) -> Tuple[Dict, Dict]:
        """Split merged dataset into train/val sets."""
        # Get image IDs and shuffle
        image_ids = [img["id"] for img in coco_data["images"]]
        random.shuffle(image_ids)

        # Split based on ratio
        split_idx = int(len(image_ids) * self.train_split)
        train_ids = set(image_ids[:split_idx])
        val_ids = set(image_ids[split_idx:])

        # Create train and val datasets
        train_data = {
            "images": [img for img in coco_data["images"] if img["id"] in train_ids],
            "annotations": [
                ann for ann in coco_data["annotations"]
                if ann.get("image_id") in train_ids
            ],
            "categories": coco_data["categories"]
        }

        val_data = {
            "images": [img for img in coco_data["images"] if img["id"] in val_ids],
            "annotations": [
                ann for ann in coco_data["annotations"]
                if ann.get("image_id") in val_ids
            ],
            "categories": coco_data["categories"]
        }

        self.stats['train_images'] = len(train_data["images"])
        self.stats['val_images'] = len(val_data["images"])
        self.stats['train_annotations'] = len(train_data["annotations"])
        self.stats['val_annotations'] = len(val_data["annotations"])

        logger.info(f"Train split: {self.stats['train_images']} images, "
                   f"{self.stats['train_annotations']} annotations")
        logger.info(f"Val split: {self.stats['val_images']} images, "
                   f"{self.stats['val_annotations']} annotations")

        return train_data, val_data

    def copy_images(self, coco_data: Dict, split_name: str):
        """Copy images to split directory."""
        split_dir = self.output_dir / split_name

        for image_info in coco_data.get("images", []):
            src_path = self.image_dir / image_info["file_name"]
            if src_path.exists():
                dst_path = split_dir / image_info["file_name"]
                shutil.copy2(src_path, dst_path)
            else:
                logger.warning(f"Image not found: {src_path}")

    def save_coco_annotations(self, coco_data: Dict, output_file: Path):
        """Save COCO format annotations."""
        with open(output_file, 'w') as f:
            json.dump(coco_data, f, indent=2)

        logger.info(f"Annotations saved: {output_file}")

    def prepare(self) -> bool:
        """Prepare dataset for training."""
        logger.info("Starting dataset preparation...")

        try:
            # Collect all annotations
            all_annotations = self.collect_all_annotations()
            if not all_annotations:
                logger.warning("No annotations found")
                # Can continue with empty datasets for testing

            # Merge annotations
            if all_annotations:
                merged_coco = self.merge_annotations(all_annotations)
            else:
                merged_coco = {
                    "images": [],
                    "annotations": [],
                    "categories": [
                        {"id": i+1, "name": name}
                        for i, name in enumerate([
                            "eye", "ear", "teeth", "arm", "body",
                            "head", "leg", "accessory", "underpants"
                        ])
                    ]
                }

            # Split dataset
            train_coco, val_coco = self.split_dataset(merged_coco)

            # Copy images
            if all_annotations:
                self.copy_images(train_coco, "train")
                self.copy_images(val_coco, "val")

            # Save annotations
            self.save_coco_annotations(
                train_coco,
                self.output_dir / "train_annotations.json"
            )
            self.save_coco_annotations(
                val_coco,
                self.output_dir / "val_annotations.json"
            )

            # Save metadata
            self.save_metadata()

            logger.info("Dataset preparation completed successfully")
            return True

        except Exception as e:
            logger.error(f"Dataset preparation failed: {e}")
            return False

    def save_metadata(self):
        """Save dataset metadata."""
        metadata = {
            "timestamp": datetime.now().isoformat(),
            "train_split": self.train_split,
            "val_split": self.val_split,
            "seed": self.seed,
            "statistics": self.stats,
            "categories": [
                "eye", "ear", "teeth", "arm", "body",
                "head", "leg", "accessory", "underpants"
            ]
        }

        with open(self.output_dir / "dataset_metadata.json", 'w') as f:
            json.dump(metadata, f, indent=2)

        logger.info("Metadata saved")

    def print_statistics(self):
        """Print dataset statistics."""
        logger.info("\n" + "="*60)
        logger.info("Dataset Preparation Statistics")
        logger.info("="*60)
        logger.info(f"Total images: {self.stats['total_images']}")
        logger.info(f"Train images: {self.stats['train_images']}")
        logger.info(f"Val images: {self.stats['val_images']}")
        logger.info(f"Total annotations: {self.stats['total_annotations']}")
        logger.info(f"Train annotations: {self.stats['train_annotations']}")
        logger.info(f"Val annotations: {self.stats['val_annotations']}")
        logger.info("="*60)


def main():
    parser = argparse.ArgumentParser(
        description='Prepare dataset for model training'
    )
    parser.add_argument(
        '--annotation-dir', '-a',
        type=str,
        default='data/processed',
        help='Directory containing annotation files'
    )
    parser.add_argument(
        '--image-dir', '-i',
        type=str,
        default='data/raw',
        help='Directory containing images'
    )
    parser.add_argument(
        '--output-dir', '-o',
        type=str,
        default='data/processed',
        help='Output directory for prepared dataset'
    )
    parser.add_argument(
        '--train-split',
        type=float,
        default=0.8,
        help='Fraction of data for training'
    )
    parser.add_argument(
        '--seed',
        type=int,
        default=42,
        help='Random seed'
    )

    args = parser.parse_args()

    # Add numpy import
    global np
    import numpy as np

    # Create preparer
    preparer = DatasetPreparer(
        annotation_dir=args.annotation_dir,
        image_dir=args.image_dir,
        output_dir=args.output_dir,
        train_split=args.train_split,
        seed=args.seed
    )

    # Prepare dataset
    if preparer.prepare():
        preparer.print_statistics()
        return 0
    else:
        return 1


if __name__ == '__main__':
    sys.exit(main())
