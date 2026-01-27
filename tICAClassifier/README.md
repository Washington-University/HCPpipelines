# tICA Hierarchical Classifier
Pre-trained tICA hierarchical classifier.

## Contributors
**Alex Yang** : Original classifier architecture and implementation
**Yubo Wang** : tICA version adaptation and training
**Andrea Yang** : GitHub integration and documentation

## Classifier Download

### 1. Clone the repository
```bash
git clone https://github.com/Washington-University/HCPpipelines.git
cd HCPpipelines/tICAClassifier
```

### 2. Install dependencies
```bash
pip install -r requirements.txt
```

### 3. Download pre-trained models
```bash
python download_models.py
```

This will download model files from Hugging Face.

### 4. Use the classifier
```python
from hierarchical_classifier.hierarchical_classifier import HCClassifier
import pickle

with open('models/your_model.pkl', 'rb') as f:
    classifier = pickle.load(f)

predictions = classifier.predict(X_new)
```

##  Model Information
**Architecture**: Two-level hierarchical XGBoost ensemble
**ROI Classifiers**: 372 brain regions
**Base Learners**: 100 XGBoost models per ROI
**Model Size**: ~39GB
**Training Date**: 2024-01-25

## Repository Structure
```
tICAClassifier/
├── hierarchical_classifier/    # Core classifier implementation
├── load_data/                  # Data loading utilities
│   └── config.py               # Path configuration system
├── metrics/                    # Evaluation metrics
├── download_models.py          # Download models from Hugging Face
├── requirements.txt            # Python dependencies
└── README.md                   
```

## Configuration

The classifier uses relative paths by default. 
```bash
export MODEL_DIR=/path/to/models
export DATA_DIR=/path/to/data
python your_script.py
```

## Citation
If you use this work, please cite:
Yang, C., Coalson, T. S., Smith, S. M., Elam, J. S., Van Essen, D. C., & Glasser, M. F. (2024). Automating the Human Connectome Project's Temporal ICA Pipeline. bioRxiv : the preprint server for biology, 2024.01.15.574667. https://doi.org/10.1101/2024.01.15.574667

##  Contact
For questions:
