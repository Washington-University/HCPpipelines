import numpy as np
import copy
import joblib
import os

from sklearn.base import BaseEstimator, ClassifierMixin
from sklearn.utils.validation import check_X_y, check_array, check_is_fitted
from sklearn.utils.multiclass import unique_labels

from .learners import base_learners, stacking_learner

class HCClassifier(BaseEstimator, ClassifierMixin):
    def __init__(self, threshold=0.5, random_state=12345, learners=None):
        self.threshold = threshold
        if learners is None:
            self.base_learners=copy.deepcopy(base_learners) # dict, use base_learners
            self.raw_learners=copy.deepcopy(base_learners) # untrained models
        else:
            self.base_learners=copy.deepcopy(learners) # dict, use input learners
            self.raw_learners=copy.deepcopy(learners) # untrained models
        self.reset_base_learners(random_state)
        self.stacking_layer=copy.deepcopy(stacking_learner)
        self.reset_stacking_learner(random_state) # dict
                
    def reset_base_learners(self, random_state):
        learners=copy.deepcopy(self.raw_learners)
        for model_name, model in learners.items():
            pipeline_keys_list=list(model.named_steps.keys())
            model_key_list=[key for key in pipeline_keys_list if key!='standardscaler']
            assert len(model_key_list)==1, f'{model_name} base learner has more than one model, check the base_leaners dict'
            model.named_steps[model_key_list[0]].random_state = random_state
            self.base_learners[model_name]=model
    
    def reset_stacking_learner(self, random_state):
        learner=copy.deepcopy(stacking_learner)
        assert len(list(learner.keys()))==1, 'only one stacking layer is acceptable'
        model_name=list(learner.keys())[0]
        model=learner[model_name]
        pipeline_keys_list=list(model.named_steps.keys())
        model_key_list=[key for key in pipeline_keys_list if key!='standardscaler']
        assert len(model_key_list)==1, f'{model_name} stacking learner has more than one model, check the stacking_learner dict'
        model.named_steps[model_key_list[0]].random_state = random_state
        self.stacking_layer[model_name]=model
    
    def fit(self, X, y):
        assert np.unique(y).shape[0]==2, 'must be a binary label y'
        # Check that X and y have correct shape
        X, y = check_X_y(X, y)
        # Store the classes seen during fit
        self.classes_ = unique_labels(y)
        
        for model_name, model in self.base_learners.items():
            model.fit(X, y)
            self.base_learners[model_name]=model
        
        # form the probability array for stacking layer
        proba=[self.base_learners[model_name].predict_proba(X)[:,1] for model_name in list(self.base_learners.keys())]
        proba=np.array(proba).T
        
        for model_name, model in self.stacking_layer.items():
            model.fit(proba, y)
            self.stacking_layer[model_name]=model
    
        # Return the classifier
        return self
    
    def predict_proba(self, X):

        # Check is fit had been called
        check_is_fitted(self)

        # Input validation
        X = check_array(X)
        
        proba=[self.base_learners[model_name].predict_proba(X)[:,1] for model_name in list(self.base_learners.keys())]
        proba=np.array(proba).T
        
        for model_name, model in self.stacking_layer.items():
            predictions_proba=model.predict_proba(proba)
        
        return predictions_proba
    
    def predict(self, X):

        # Check is fit had been called
        check_is_fitted(self)

        # Input validation
        X = check_array(X)
        
        predictions_proba=self.predict_proba(X)
        
        return predictions_proba[:,1]>=self.threshold
    
    def base_learner_predict_proba(self, X, model_name):
        # Check is fit had been called
        check_is_fitted(self)

        # Input validation
        X = check_array(X)
        predictions_proba=self.base_learners[model_name].predict_proba(X)
        return predictions_proba
    
    def base_learner_predict(self, X, model_name):
        # Check is fit had been called
        check_is_fitted(self)

        # Input validation
        X = check_array(X)
        
        predictions_proba=self.base_learner_predict_proba(X, model_name)
        return predictions_proba[:,1]>=self.threshold
    
    def save(self, save_path):
        check_is_fitted(self)
        joblib.dump({
            "base_learners": self.base_learners,
            "stacking_layer": self.stacking_layer,
            "classes_": self.classes_  # ← 只加这一行
        }, save_path)
        print("model is saved!")
        return self
    
    def load(self, model_path):
        trained_model_dict = joblib.load(model_path)
        self.base_learners = copy.deepcopy(trained_model_dict["base_learners"])
        self.stacking_layer = copy.deepcopy(trained_model_dict["stacking_layer"])
        self.classes_ = trained_model_dict.get("classes_", np.array([0, 1]))  # ← 只加这一行
        print("model is loaded!")
        return self

# directly run is not supported because of the relative module path
if __name__=='__main__':
    from sklearn.datasets import load_breast_cancer
    data = load_breast_cancer()
    hc=HCClassifier(random_state=12345)
    hc.fit(data.data, data.target)
    pred_0=hc.predict(data.data)
    pred_0_1=hc.base_learner_predict_proba(data.data, 'MLPOneLayer')
    
    hc=HCClassifier(random_state=12345)
    hc.fit(data.data, data.target)
    pred_1=hc.predict(data.data)
    pred_1_1=hc.base_learner_predict_proba(data.data, 'MLPOneLayer')
    
    hc=HCClassifier(random_state=0)
    hc.fit(data.data, data.target)
    pred_2=hc.predict(data.data)
    pred_2_1=hc.base_learner_predict_proba(data.data, 'MLPOneLayer')
    
    save_path = './results/test/hc_test.joblib'
    hc.save(save_path)
    
    hc=HCClassifier(random_state=67890)
    hc.load(save_path)
    hc.fit(data.data, data.target)
    pred_3=hc.predict(data.data)
    pred_3_1=hc.base_learner_predict_proba(data.data, 'MLPOneLayer')
    
    # reproducibility check
    assert np.array_equal(pred_0_1, pred_1_1)
    # reproducibility check
    assert not np.array_equal(pred_0_1, pred_2_1)
    # load and save model check
    assert np.array_equal(pred_2_1, pred_3_1)