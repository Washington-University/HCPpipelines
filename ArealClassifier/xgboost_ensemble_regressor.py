import numpy as np
import copy
import joblib
import os

from sklearn.base import BaseEstimator, RegressorMixin
from sklearn.utils.validation import check_X_y, check_array, check_is_fitted
from sklearn.utils.multiclass import unique_labels

from xgboost import XGBRegressor 

class XGBoostEnsembleRegressor(BaseEstimator, RegressorMixin):
    def __init__(self, random_state=12345, num_models=100):
        self.models = []
        np.random.seed(random_state)
        min_value=0
        max_value=1000000
        self.random_integers = np.random.randint(min_value, max_value + 1, size=(num_models, ))
        self.num_models=num_models
        self.random_state=random_state
        self.params={'n_estimators': 200,
                'max_depth': 4,
                'learning_rate': 0.3,
                'subsample': 0.5,
                'random_state': random_state}
        
        for random_integer in self.random_integers:
            self.params['random_state']=random_integer
            self.models.append(XGBRegressor(**self.params))

        self.is_fitted_ = False
    
    def fit(self, X, y):
        ratio=0.7
        y_low_indices = np.where(y < 0.5)[0]
        y_high_indices = np.where(y >= 0.5)[0]
        for model in self.models:
            
            y_low_random_indices = np.random.choice(y_low_indices, size=int(ratio*len(y_high_indices)), replace=False)
            y_high_random_indices = np.random.choice(y_high_indices, size=int(ratio*len(y_high_indices)), replace=False)
            
            # y_0_random_indices=y_0_indices
            # y_1_random_indices=y_1_indices
            
            # Combine the indices of y=0 and sampled y=1
            balanced_indices = np.concatenate((y_low_random_indices, y_high_random_indices))
            print(f"balanced_indices: {balanced_indices.shape}")
            # Create the balanced feature matrix and label vector
            balanced_X = X.iloc[balanced_indices]
            balanced_y = y[balanced_indices]
            
            model.fit(balanced_X, balanced_y)

        self.is_fitted_ = True
        # Return the classifier
        return self
    
    def predict(self, X):

        # Check is fit had been called
        assert self.is_fitted_ is True, 'model is not fitted'

        # Input validation
        X = check_array(X)

        y_hat = np.zeros((X.shape[0],))
        for model in self.models:
            model.set_params(n_jobs=2)
            y_hat += model.predict(X)
        y_hat = y_hat / len(self.models)
        
        return y_hat
    
    def save(self, save_path):
        # Check is fit had been called
        assert self.is_fitted_ is True, 'model is not fitted'
        
        for i,model in enumerate(self.models):
            model.save_model(save_path+f'/xgb_regressor_{i}.json')
        print("model is saved!")
        # Return the classifier
        return self
    
    def load(self, model_path):
        for i,model in enumerate(self.models):
            model.load_model(model_path+f'/xgb_regressor_{i}.json')
        self.is_fitted_ = True
        # print("model is loaded!")
        # Return the classifier
        return self
    
# directly run is not supported because of the relative module path
if __name__=='__main__':
    from sklearn.datasets import load_breast_cancer
    data = load_breast_cancer()
    mdl=XGBoostEnsembleRegressor(random_state=12345)
    mdl.fit(data.data, data.target)
    pred_0=mdl.predict(data.data)
    
    mdl=XGBoostEnsembleRegressor(random_state=12345)
    mdl.fit(data.data, data.target)
    pred_1=mdl.predict(data.data)
    
    mdl=XGBoostEnsembleRegressor(random_state=0)
    mdl.fit(data.data, data.target)
    pred_2=mdl.predict(data.data)
    
    save_path = '/media/myelin/alex/tICA/tICAClassify/results/test_regressor'
    mdl.save(save_path)
    
    mdl=XGBoostEnsembleRegressor(random_state=67890)
    mdl.load(save_path)
    pred_3=mdl.predict(data.data)
    
    # reproducibility check
    assert np.array_equal(pred_0, pred_1)
    # reproducibility check
    assert not np.array_equal(pred_0, pred_2)
    # load and save model check
    assert np.array_equal(pred_2, pred_3)
