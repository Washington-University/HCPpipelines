import argparse
import json

import numpy as np
import pandas as pd


class OnnxClassifier(object):
    def __init__(self, model_name=None):
        self.model = None
        self.ensemble = False
        if model_name is not None:
            if "ensemble" in model_name.lower():
                self.load_model_ensemble(model_name)
            else:
                self.load_model(model_name)

    def load_model(self, model_name):
        """
        loads an onnx model from file
        model_name: path to the model file
        """
        self.model = ort.InferenceSession(model_name)
        self.ensemble = False

    def load_model_ensemble(self, model_name):
        """
        loads many onnx model from files and ensemble them
        model_name: prefix for model file, the full model name should be f"{model_name}_{idx}.onnx"
        """
        models = []
        model_name = model_name.replace(".onnx", "")
        for i in range(1, 1000):
            if os.path.exists(f"{model_name}_{i}.onnx"):
                models.append(ort.InferenceSession(f"{model_name}_{i}.onnx"))
            else:
                break
            if i == 999:
                raise RuntimeError("increase the number of ensemble models to continue")
        self.model = models
        self.ensemble = True

    def predict_proba(self, x):
        """
        predicts the probability of each class
        x: a np.array with shape (batch, features)
        return: a np.array with shape (batch, class prob)
        """
        x = x.astype(np.float32)
        if self.ensemble:
            results = []
            for m in self.model:
                input_name = m.get_inputs()[0].name
                r = m.run(None, {input_name: x})[1]
                r = [np.array([v for _, v in sorted(d.items())]) for d in r]
                r = np.stack(r)
                results.append(r)
            results = np.array(results)
            res = results.mean(axis=0)
        else:
            input_name = self.model.get_inputs()[0].name
            result_dict = self.model.run(None, {input_name: x})[1]
            res = [np.array([v for _, v in sorted(d.items())]) for d in result_dict]
            res = np.stack(res)
        return res


def preprocess_feature(df_feature, keep_feature_columns):
    cols_mapping = {col: col.replace(" ", "") for col in df_feature.columns}
    df_feature = df_feature.rename(columns=cols_mapping)
    df_feature = df_feature.loc[:, keep_feature_columns]
    assert df_feature[df_feature.isna().any(axis=1)].shape[0] == 0, \
        "input feature table has NaN values which is not supported!"
    return df_feature


def main(args):
    with open(args.keep_features_json) as f:
        keep_features_config = json.load(f)
    keep_feature_columns = [col for group in keep_features_config.values() for col in group]

    with open(f"{args.model_folder}/base_learner_order.txt") as f:
        base_learner_order = [line.strip() for line in f if line.strip()]

    base_learners = {
        name: OnnxClassifier(f"{args.model_folder}/{name.replace(' ', '_')}.onnx")
        for name in base_learner_order
    }
    stacking_model = OnnxClassifier(f"{args.model_folder}/{args.stacking_model_name.replace(' ', '_')}.onnx")

    df = pd.read_csv(args.input_csv)
    df_processed = preprocess_feature(df, keep_feature_columns=keep_feature_columns)
    row_names = df_processed["Row"]
    X = df_processed.drop(columns=["Row"]).to_numpy(dtype=np.float32)

    base_proba = np.stack(
        [base_learners[name].predict_proba(X)[:, 1] for name in base_learner_order],
        axis=1,
    ).astype(np.float32)

    predict_proba = stacking_model.predict_proba(base_proba)[:, 1]
    prediction = predict_proba >= args.threshold

    noise_index = np.where(~prediction)[0] + 1  # 1-indexed, matches CleanData's --manual-components-to-remove format
    with open(args.output_noise_file, "w") as f:
        f.write(" ".join(str(idx) for idx in noise_index))

    result = pd.DataFrame({
        "Row": row_names,
        "noise_probability": 1 - predict_proba,
        "prediction": ["signal" if p else "noise" for p in prediction],
    })
    if args.output_proba_csv:
        result.to_csv(args.output_proba_csv, index=False)
    print(result)
    print(f"noise components: {noise_index.tolist()}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="tICA component classifier inference (ONNX).")
    parser.add_argument("--input_csv", type=str, required=True, help="path to the ComputeTICAFeatures features.csv")
    parser.add_argument("--keep_features_json", type=str, required=True, help="path to keep_features_v1.json")
    parser.add_argument("--model_folder", type=str, required=True, help="folder containing the converted .onnx models")
    parser.add_argument("--stacking_model_name", type=str, default="linearSVM", help="name of the stacking layer model")
    parser.add_argument("--threshold", type=float, default=0.5, help="decision threshold for signal vs noise")
    parser.add_argument("--output_noise_file", type=str, required=True, help="output Noise.txt path")
    parser.add_argument("--output_proba_csv", type=str, default=None, help="optional: save per-component probabilities to csv")

    args = parser.parse_args()
    main(args)
