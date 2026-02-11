#!/usr/bin/env python3
"""
ClassifyTICA.py

Classifies tICA components as signal or noise using pre-trained HCClassifier.
Called by ClassifyTICA.sh.

Usage:
    python3 ClassifyTICA.py <tica_folder> <model_path> <threshold>

Arguments:
    tica_folder : path to tICA_d{dim}/ folder containing features.csv
    model_path  : path to tICAClassifier.joblib model file
    threshold   : signal classification threshold (default 0.5)

Outputs (written to tica_folder/):
    Noise.txt                        
    tICA_classification_results.csv  
"""

import sys
import os
import json
import numpy as np
import pandas as pd

# Add tICAClassifier to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'tICAClassifier'))
from hierarchical_classifier.hierarchical_classifier import HCClassifier
from load_data.utils import preprocess_feature


def classify(tica_folder, model_path, threshold=0.5):
    """
    Classify tICA components and save results.
    
    Args:
        tica_folder: Path to tICA_d{dim}/ directory
        model_path: Path to tICAClassifier.joblib file
        threshold: Classification threshold for signal vs noise
    """
    features_path = os.path.join(tica_folder, 'features.csv')
    
    if not os.path.isfile(features_path):
        raise FileNotFoundError(
            f"Features file not found: {features_path}\n"
            f"Make sure ComputeTICAFeatures has been run first"
        )
    
    if not os.path.isfile(model_path):
        raise FileNotFoundError(f"Model file not found: {model_path}")
    
    # Load keep_features configuration
    keep_features_path = os.path.join(
        os.path.dirname(__file__), 'tICAClassifier', 'load_data', 'keep_features_v1.json'
    )
    with open(keep_features_path, 'r') as f:
        KEEP_FEATURE_COLUMNS = json.load(f)
    keep_cols = [col for group in KEEP_FEATURE_COLUMNS.values() for col in group]
    
    # Load and preprocess features
    print(f"Loading features from: {features_path}")
    df_raw = pd.read_csv(features_path)
    n_components = len(df_raw)
    print(f"Number of components: {n_components}")
    
    df_processed = preprocess_feature(df_raw, keep_feature_columns=keep_cols, abs_feature=False)
    df_features = df_processed.drop(columns=['Row'])
    
    # Load model
    print(f"Loading model from: {model_path}")
    hc = HCClassifier()
    hc.load(model_path)
    
    # Run classification
    print(f"Running classification (threshold={threshold})...")
    probabilities = hc.predict_proba(df_features.values)[:, 1]  # signal probability
    predictions = (probabilities >= threshold).astype(int)  
    
    # Get noise component indices (1-indexed)
    noise_indices = np.where(predictions == 0)[0] + 1
    signal_indices = np.where(predictions == 1)[0] + 1
    
    print(f"Signal components: {len(signal_indices)}")
    print(f"Noise components: {len(noise_indices)}")
    
    # Save Noise.txt
    noise_file = os.path.join(tica_folder, 'Noise.txt')
    with open(noise_file, 'w') as f:
        f.write(' '.join(map(str, noise_indices)) + '\n')
    print(f"Saved: {noise_file}")
    
    # Create results CSV
    results_data = {
        'Index': range(1, n_components + 1),
        'single_subject': df_raw['outlier_stat_1'].apply(lambda x: round(x, 2)),
        'single_subject_global_components': df_raw['outlier_stat_2'].apply(lambda x: round(x, 2)),
        'Signal_Probability': [round(p, 4) for p in probabilities],
        'Signal_or_Noise': ['Noise' if p == 0 else 'Signal' for p in predictions],
        'Notes': ['' for _ in range(n_components)]
    }
    
    results_df = pd.DataFrame(results_data)
    
    # Save results CSV
    csv_file = os.path.join(tica_folder, 'tICA_classification_results.csv')
    results_df.to_csv(csv_file, index=False)
    print(f"Saved: {csv_file}")
    
    print("\nClassification complete!")


if __name__ == '__main__':
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    
    tica_folder = sys.argv[1]
    model_path = sys.argv[2]
    threshold = float(sys.argv[3]) if len(sys.argv) > 3 else 0.5
    
    try:
        classify(tica_folder, model_path, threshold)
    except Exception as e:
        print(f"\nError: {e}", file=sys.stderr)
        sys.exit(1)