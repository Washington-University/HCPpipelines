#!/usr/bin/env python3
"""
Download pre-trained tICA classifier models from Hugging Face
"""
import os
import sys

def download_models():
    try:
        from huggingface_hub import snapshot_download
    except ImportError:
        sys.exit(1)
    
    #Note_AY: classifier is too big(around 39 GB) to directly push to github
    #curretnly using AY's own Hugging face
    #so we might need to create our lab's own hugging face account 
    #then update the repo id 
    repo_id = "YOUR_LAB_ORG/tICA-classifier"
    local_dir = "./models"
    
    print("Downloading tICA Classifier Models")
    try:
        snapshot_download(
            repo_id=repo_id,
            local_dir=local_dir,
            repo_type="model",
            resume_download=True
        )
        print(f"Location: {os.path.abspath(local_dir)}")
    except Exception as e:
        print(f"\nError: {e}")
        sys.exit(1)

if __name__ == "__main__":
    download_models()
