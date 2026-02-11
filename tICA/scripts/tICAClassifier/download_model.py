#!/usr/bin/env python3
"""
download_model.py

Download the pre-trained tICA HCClassifier model from BALSA.

Usage:
    python3 download_model.py [output_path]

Arguments:
    output_path : Optional path to save the model (default: tICAClassifier.joblib)
"""

import os
import sys
import urllib.request
from pathlib import Path

# BALSA URL  UPDATED after model upload
MODEL_URL = ""
#Output Path for the downloaded model
DEFAULT_OUTPUT = "tICAClassifier.joblib"


def download_model(output_path=DEFAULT_OUTPUT):
    """
    Download the pre-trained tICA classifier model from BALSA.
    
    Args:
        output_path: Path where the model will be saved
    """
    if os.path.exists(output_path):
        response = input(f"File {output_path} already exists. Overwrite? (y/n): ")
        if response.lower() != 'y':
            print("Download cancelled.")
            return
    

    try:
        def report_progress(block_num, block_size, total_size):
            downloaded = block_num * block_size
            percent = min(100, (downloaded / total_size) * 100)
            mb_downloaded = downloaded / (1024 * 1024)
            mb_total = total_size / (1024 * 1024)
            print(f"\rProgress: {percent:.1f}% ({mb_downloaded:.1f} MB / {mb_total:.1f} MB)", end='')
        
        urllib.request.urlretrieve(MODEL_URL, output_path, reporthook=report_progress)
        print()  
        
        if os.path.exists(output_path):
            file_size = os.path.getsize(output_path) / (1024 * 1024)
            print("You can now use this model with:")
            print(f"  tICAPipeline.sh --model-path={os.path.abspath(output_path)} ...")
        else:
            print(" \nError: Download failed ")
            sys.exit(1)
            
    except urllib.error.URLError as e:
        print(f"\n Error downloading model: {e}")
        print("\nPlease check:")
        print("  1. Your internet connection")
        print("  2. The BALSA URL is correct")
        print("  3. You have write permissions in the target directory")
        sys.exit(1)
    except KeyboardInterrupt:
        print("\n Download interrupted by user")
        if os.path.exists(output_path):
            os.remove(output_path)
            print(f"  Partial file removed: {output_path}")
        sys.exit(1)


if __name__ == "__main__":
    # Parse command line arguments
    if len(sys.argv) > 1:
        if sys.argv[1] in ['-h', '--help']:
            print(__doc__)
            sys.exit(0)
        output_path = sys.argv[1]
    else:
        output_path = DEFAULT_OUTPUT
    
    # Create parent directory if needed
    parent_dir = os.path.dirname(output_path)
    if parent_dir and not os.path.exists(parent_dir):
        os.makedirs(parent_dir)
    
    download_model(output_path)