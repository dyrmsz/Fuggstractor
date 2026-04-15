#!/usr/bin/env python3
"""
Fuggler Image Data Collector

Scrapes fuggler images from the internet to build a training dataset.
Implements image quality filtering and deduplication.
"""

import os
import sys
import argparse
import logging
from pathlib import Path
from typing import List, Tuple
import hashlib
from datetime import datetime
import time

import requests
from bs4 import BeautifulSoup
from PIL import Image
from io import BytesIO
import json
from urllib.parse import urljoin, urlparse
from tqdm import tqdm


# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('data_collection.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)


class FugglerImageCollector:
    """Collects fuggler images from various internet sources."""

    # Search terms and sources for fuggler images
    SEARCH_TERMS = [
        'fuggler doll',
        'fuggler toy',
        'fuggler figure',
        'ugly doll',
        'creepy doll',
    ]

    # Image hosting sites to scrape
    SOURCES = {
        'google_images': 'https://www.google.com/search?q=fuggler&tbm=isch',
        'pinterest': 'https://www.pinterest.com/search/pins/?q=fuggler',
        'duckduckgo': 'https://duckduckgo.com/?q=fuggler&t=h_&iax=images&ia=images',
    }

    # Image quality thresholds
    MIN_WIDTH = 128
    MIN_HEIGHT = 128
    MAX_WIDTH = 4096
    MAX_HEIGHT = 4096
    MIN_FILE_SIZE = 1024  # 1KB minimum
    MAX_FILE_SIZE = 10 * 1024 * 1024  # 10MB maximum

    def __init__(self, output_dir: str, timeout: int = 10):
        """
        Initialize the image collector.

        Args:
            output_dir: Directory to save collected images
            timeout: Request timeout in seconds
        """
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)
        self.timeout = timeout
        self.session = self._setup_session()
        self.downloaded_hashes = self._load_hash_registry()
        self.stats = {
            'attempted': 0,
            'successful': 0,
            'failed': 0,
            'duplicates': 0,
            'quality_rejected': 0,
        }

    def _setup_session(self) -> requests.Session:
        """Set up HTTP session with appropriate headers."""
        session = requests.Session()
        session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
                         'AppleWebKit/537.36 (KHTML, like Gecko) '
                         'Chrome/120.0.0.0 Safari/537.36'
        })
        return session

    def _load_hash_registry(self) -> set:
        """Load previously downloaded image hashes to avoid duplicates."""
        hash_file = self.output_dir / '.hashes.json'
        if hash_file.exists():
            try:
                with open(hash_file, 'r') as f:
                    data = json.load(f)
                    logger.info(f"Loaded {len(data)} known image hashes")
                    return set(data.get('hashes', []))
            except Exception as e:
                logger.warning(f"Could not load hash registry: {e}")
        return set()

    def _save_hash_registry(self):
        """Save downloaded image hashes to prevent future duplicates."""
        hash_file = self.output_dir / '.hashes.json'
        try:
            with open(hash_file, 'w') as f:
                json.dump({'hashes': list(self.downloaded_hashes)}, f)
        except Exception as e:
            logger.warning(f"Could not save hash registry: {e}")

    def _is_valid_image(self, img: Image.Image) -> bool:
        """Check if image meets quality requirements."""
        width, height = img.size

        if width < self.MIN_WIDTH or height < self.MIN_HEIGHT:
            logger.debug(f"Image too small: {width}x{height}")
            return False

        if width > self.MAX_WIDTH or height > self.MAX_HEIGHT:
            logger.debug(f"Image too large: {width}x{height}")
            return False

        # Reject images that are too wide or too tall (landscape/portrait extreme)
        aspect_ratio = width / height
        if aspect_ratio < 0.5 or aspect_ratio > 2.0:
            logger.debug(f"Invalid aspect ratio: {aspect_ratio}")
            return False

        return True

    def _get_image_hash(self, image_data: bytes) -> str:
        """Generate SHA256 hash of image data."""
        return hashlib.sha256(image_data).hexdigest()

    def _download_image(self, url: str) -> Tuple[bool, Image.Image | None, str]:
        """
        Download and validate a single image.

        Returns:
            Tuple of (success, image, error_message)
        """
        try:
            self.stats['attempted'] += 1

            response = self.session.get(url, timeout=self.timeout, stream=True)
            response.raise_for_status()

            # Check content length
            content_length = len(response.content)
            if content_length < self.MIN_FILE_SIZE or content_length > self.MAX_FILE_SIZE:
                self.stats['quality_rejected'] += 1
                return False, None, f"Invalid file size: {content_length} bytes"

            # Check for duplicates
            img_hash = self._get_image_hash(response.content)
            if img_hash in self.downloaded_hashes:
                self.stats['duplicates'] += 1
                return False, None, "Duplicate image"

            # Try to open and validate image
            img = Image.open(BytesIO(response.content))
            img.load()  # Force load to check validity

            # Convert to RGB if necessary
            if img.mode != 'RGB':
                img = img.convert('RGB')

            # Validate image quality
            if not self._is_valid_image(img):
                self.stats['quality_rejected'] += 1
                return False, None, "Failed quality checks"

            self.downloaded_hashes.add(img_hash)
            self.stats['successful'] += 1
            return True, img, ""

        except requests.RequestException as e:
            self.stats['failed'] += 1
            return False, None, f"Request error: {str(e)}"
        except Exception as e:
            self.stats['failed'] += 1
            return False, None, f"Processing error: {str(e)}"

    def _save_image(self, img: Image.Image, idx: int) -> bool:
        """Save image to output directory with sequential naming."""
        try:
            filename = self.output_dir / f"fuggler_{idx:06d}.jpg"
            img.save(filename, quality=95, optimize=True)
            logger.debug(f"Saved: {filename}")
            return True
        except Exception as e:
            logger.error(f"Failed to save image {idx}: {e}")
            return False

    def collect_from_google_images(self, search_term: str, count: int = 10) -> int:
        """
        Collect images from Google Images search.

        Note: This is a simplified implementation. In production, you might want
        to use Selenium or other tools to handle JavaScript-rendered content.
        """
        logger.info(f"Collecting from Google Images: '{search_term}'")

        # Note: Direct scraping Google Images is limited due to JavaScript rendering
        # This is a placeholder for manual curation or using Google Cloud Vision API
        logger.warning("Google Images requires Selenium/headless browser. "
                      "Consider using google-images-download or similar tool.")
        return 0

    def collect_from_urls(self, urls: List[str]) -> int:
        """Download images from a list of direct URLs."""
        logger.info(f"Downloading {len(urls)} images from provided URLs")

        idx = len(list(self.output_dir.glob('fuggler_*.jpg')))
        successful = 0

        for url in tqdm(urls, desc="Downloading images"):
            success, img, error = self._download_image(url)

            if success:
                if self._save_image(img, idx):
                    successful += 1
                    idx += 1
            else:
                logger.debug(f"Failed to download {url}: {error}")

            # Rate limiting
            time.sleep(0.1)

        return successful

    def collect_sample_dataset(self, count: int = 100) -> int:
        """
        Create a sample dataset by searching multiple sources.

        This is a simplified implementation that demonstrates the collection pipeline.
        For production, integrate with APIs like:
        - Google Custom Search API
        - Bing Image Search API
        - Various public image datasets
        """
        logger.info(f"Starting sample data collection for {count} images")

        # Sample URLs (these would normally come from search results)
        # In practice, you would scrape or use APIs to get these URLs
        sample_urls = [
            # Placeholder URLs - replace with actual fuggler image URLs
            # Example structure:
            # 'https://example.com/fuggler1.jpg',
            # 'https://example.com/fuggler2.jpg',
        ]

        if sample_urls:
            return self.collect_from_urls(sample_urls[:count])
        else:
            logger.warning("No sample URLs configured. "
                          "Please provide image URLs manually or configure API keys.")
            return 0

    def print_statistics(self):
        """Print collection statistics."""
        total_files = len(list(self.output_dir.glob('fuggler_*.jpg')))

        logger.info("\n" + "="*60)
        logger.info("Data Collection Statistics")
        logger.info("="*60)
        logger.info(f"Attempted downloads: {self.stats['attempted']}")
        logger.info(f"Successful downloads: {self.stats['successful']}")
        logger.info(f"Failed downloads: {self.stats['failed']}")
        logger.info(f"Duplicates detected: {self.stats['duplicates']}")
        logger.info(f"Quality rejected: {self.stats['quality_rejected']}")
        logger.info(f"Total images in dataset: {total_files}")
        logger.info(f"Output directory: {self.output_dir}")
        logger.info("="*60)


def main():
    parser = argparse.ArgumentParser(
        description='Collect fuggler images for training dataset'
    )
    parser.add_argument(
        '--output', '-o',
        type=str,
        default='data/raw',
        help='Output directory for collected images'
    )
    parser.add_argument(
        '--count', '-c',
        type=int,
        default=100,
        help='Target number of images to collect'
    )
    parser.add_argument(
        '--urls',
        type=str,
        help='File containing list of image URLs (one per line)'
    )
    parser.add_argument(
        '--timeout',
        type=int,
        default=10,
        help='Request timeout in seconds'
    )

    args = parser.parse_args()

    # Create collector
    collector = FugglerImageCollector(args.output, timeout=args.timeout)

    # Collect images
    if args.urls:
        # Load URLs from file
        with open(args.urls, 'r') as f:
            urls = [line.strip() for line in f if line.strip()]
        collected = collector.collect_from_urls(urls[:args.count])
    else:
        # Use sample collection (requires configuration)
        collected = collector.collect_sample_dataset(args.count)

    # Save hash registry
    collector._save_hash_registry()

    # Print statistics
    collector.print_statistics()

    return 0 if collected > 0 else 1


if __name__ == '__main__':
    sys.exit(main())
