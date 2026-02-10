#!/usr/bin/env python3
"""
classify_tica.py

Classifies tICA components as signal or noise using pre-trained XGBoost ensemble models.
Called by ClassifyTICA.sh.

Usage:
    python3 classify_tica.py <tica_folder> <model_dir> <threshold>

Outputs (written to tica_folder/):
    Signal.txt                           
    Noise.txt                            
    tICA_classification_probabilities.csv
"""

import sys
import os
import json
import numpy as np
import pandas as pd

sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'tICAClassifier'))
from hierarchical_classifier.xgboost_ensemble_classifier import XGBoostEnsembleClassifier
from load_data.utils import preprocess_feature


def classify(tica_folder, model_dir, threshold=0.5):
    features_path = os.path.join(tica_folder, 'features.csv')
    first_clf_dir = os.path.join(model_dir, '1st_clf')

    # load keep_features_v1.json for preprocessing
    keep_features_path = os.path.join(
        os.path.dirname(__file__), 'tICAClassifier', 'load_data', 'keep_features_v1.json'
    )
    with open(keep_features_path, 'r') as f:
        KEEP_FEATURE_COLUMNS = json.load(f)
    keep_cols = [col for group in KEEP_FEATURE_COLUMNS.values() for col in group]

    # load and preprocess features (same as training)
    df_raw  = pd.read_csv(features_path)
    df_proc = preprocess_feature(df_raw, keep_feature_columns=keep_cols, abs_feature=False)
    df_proc = df_proc.drop(columns=['Row'])

    n_components = len(df_proc)

    roi_dirs = sorted([
        d for d in os.listdir(first_clf_dir)
        if os.path.isdir(os.path.join(first_clf_dir, d))
    ])

    probabilities = np.zeros(n_components)

    for comp_idx in range(n_components):
        comp_features = df_proc.iloc[[comp_idx]]
        roi_probas    = []

        for roi_dir in roi_dirs:
            roi_path = os.path.join(first_clf_dir, roi_dir)
            clf = XGBoostEnsembleClassifier(num_models=100)
            try:
                clf.load(roi_path)
                proba = clf.predict_proba(comp_features.values)
                roi_probas.append(proba[0, 1])
            except Exception:
                continue

        probabilities[comp_idx] = float(np.mean(roi_probas)) if roi_probas else 0.0

    predictions  = (probabilities >= threshold).astype(int)
    signal_comps = [str(i + 1) for i, p in enumerate(predictions) if p == 1]
    noise_comps  = [str(i + 1) for i, p in enumerate(predictions) if p == 0]

    with open(os.path.join(tica_folder, 'Signal.txt'), 'w') as f:
        f.write(' '.join(signal_comps) + '\n')

    with open(os.path.join(tica_folder, 'Noise.txt'), 'w') as f:
        f.write(' '.join(noise_comps) + '\n')

    proba_df = pd.DataFrame({
        'component':          range(1, n_components + 1),
        'signal_probability': probabilities,
        'prediction':         ['signal' if p == 1 else 'noise' for p in predictions]
    })
    proba_df.to_csv(os.path.join(tica_folder, 'tICA_classification_probabilities.csv'), index=False)

    print(f"Signal components ({len(signal_comps)}): {' '.join(signal_comps)}")
    print(f"Noise  components ({len(noise_comps)}): {' '.join(noise_comps)}")


if __name__ == '__main__':
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)

    classify(
        tica_folder=sys.argv[1],
        model_dir=sys.argv[2],
        threshold=float(sys.argv[3]) if len(sys.argv) > 3 else 0.5
    )