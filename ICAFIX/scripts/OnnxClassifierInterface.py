import onnxruntime as ort
import os
import numpy as np

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
        self.model = ort.InferenceSession(model_name)
        self.ensemble = False

    def load_model_ensemble(self, model_name):
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