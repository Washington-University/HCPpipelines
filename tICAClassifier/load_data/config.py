"""
Configuration for data paths and model directories.
"""
import os
from pathlib import Path

# Base directory
BASE_DIR = Path(__file__).parent.parent

# Data directories (can be overridden by environment variables)
CONFIG_JSON_SAVE_PATH = os.getenv('PREPARE_DATA_PATH', str(BASE_DIR / 'prepare_data'))
LABEL_SAVE_PATH = os.getenv('LABEL_PATH', str(BASE_DIR / 'datasets_category'))
KEEP_FEATURES_PATH = os.getenv('KEEP_FEATURES_PATH', str(BASE_DIR / 'load_data' / 'keep_features_v1.json'))

# Model directory
MODEL_DIR = os.getenv('MODEL_DIR', str(BASE_DIR / 'models'))
DATA_DIR = os.getenv('DATA_DIR', str(BASE_DIR / 'data'))
