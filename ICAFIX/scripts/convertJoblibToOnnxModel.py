import argparse
import joblib
from collections import defaultdict

import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from xgboost_ensemble_classifier import XGBoostEnsembleClassifier
from xgboost import XGBClassifier 
from sklearn.neural_network import MLPClassifier
from sklearn.preprocessing import StandardScaler
from sklearn.pipeline import make_pipeline
from sklearn.neighbors import KNeighborsClassifier

from skl2onnx.common.data_types import FloatTensorType
from onnxmltools.convert.common.data_types import FloatTensorType as ml_tools_FloatTensorType
from skl2onnx import convert_sklearn, to_onnx, update_registered_converter
from skl2onnx.common.shape_calculator import (
    calculate_linear_classifier_output_shapes,
    calculate_linear_regressor_output_shapes,
)
from skl2onnx.convert import may_switch_bases_classes_order
from onnxmltools.convert.xgboost.operator_converters.XGBoost import convert_xgboost
from onnxmltools.convert import convert_xgboost as convert_xgboost_booster
import onnxruntime as ort

from OnnxClassifierInterface import OnnxClassifier

np.random.seed(42)

# available models
models = [
    'RandomForest',
    'MLP',
    'Xgboost',
    'WeightedKNN',
    'XgboostEnsemble',
]

update_registered_converter(
    XGBClassifier,
    "XGBoostXGBClassifier",
    calculate_linear_classifier_output_shapes,
    convert_xgboost,
    options={"nocl": [True, False], "zipmap": [True, False, "columns"]},
)

update_registered_converter(
    XGBoostEnsembleClassifier,
    "XGBoostXGBoostEnsembleClassifier",
    calculate_linear_classifier_output_shapes,
    convert_xgboost,
    options={"nocl": [True, False], "zipmap": [True, False, "columns"]},
)

def main(args):

    # model_names = "RandomForest@MLP@Xgboost@XgboostEnsemble".split("@")
    model_names=args.model.split("@")
    trained_folder=args.trained_folder
    
    models_to_use={}
    models_to_use2={}
    for model_name in model_names:
        if model_name not in models:
            raise ValueError(f"{model_name} is not supported!")
        models_to_use[model_name]=joblib.load(f'{trained_folder}/{model_name}.joblib')
    print("model loaded successfully")

    for model_name in model_names:
        in_dim = models_to_use[model_name].n_features_in_
        rndin = np.random.randn(2, in_dim).astype(np.float32)
        predictions = models_to_use[model_name].predict_proba(rndin)
        print(predictions)

        if "xgboost" not in model_name.lower():
            initial_type = [('float_input', FloatTensorType([None, in_dim]))]
            onx = convert_sklearn(models_to_use[model_name], initial_types=initial_type,)
            with open(f"{trained_folder}/{model_name}.onnx", "wb") as f:
                f.write(onx.SerializeToString())

        elif "ensemble" not in model_name.lower():
            with may_switch_bases_classes_order(XGBClassifier):
                onx = convert_sklearn(
                    models_to_use[model_name],
                    "pipeline_xgboost",
                    initial_types=[("input", FloatTensorType([None, in_dim]))],
                    target_opset={"": 12, "ai.onnx.ml": 2},
                )
            with open(f"{trained_folder}/{model_name}.onnx", "wb") as f:
                f.write(onx.SerializeToString())
        else:
            for idx, mode_ens in enumerate(models_to_use[model_name].named_steps["xgboostensembleclassifier"].models):
                with may_switch_bases_classes_order(XGBClassifier):
                    onx = convert_sklearn(
                        mode_ens,
                        "pipeline_xgboost",
                        initial_types=[("input", FloatTensorType([None, in_dim]))],
                        target_opset={"": 12, "ai.onnx.ml": 2},
                    )
                with open(f"{trained_folder}/{model_name}_{idx}.onnx", "wb") as f:
                    f.write(onx.SerializeToString())

        
        models_to_use2[model_name]=OnnxClassifier(f'{trained_folder}/{model_name}.onnx')

        results = models_to_use2[model_name].predict_proba(rndin)
        print(results)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Reclean classifier inference stage only.")
    parser.add_argument("--model", type=str, help="the models to use for inference e.g., 'RandomForest@Xgboost'")
    parser.add_argument("--trained_folder", type=str, help="Trained folder path")
    main(parser.parse_args())
    