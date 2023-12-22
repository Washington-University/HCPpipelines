import numpy as np
import copy
import joblib
import os

from sklearn.base import BaseEstimator, ClassifierMixin
from sklearn.utils.validation import check_X_y, check_array, check_is_fitted
from sklearn.utils.multiclass import unique_labels

from xgboost import XGBClassifier 

class XGBoostEnsembleClassifier(BaseEstimator, ClassifierMixin):
    def __init__(self, threshold=0.5, random_state=12345, num_models=100, ratio=0.7, n_jobs=7, replace=False, focus_on_signal=False):
        self.threshold = threshold
        self.models = []
        np.random.seed(random_state)
        min_value=0
        max_value=1000000
        self.random_integers = np.random.randint(min_value, max_value + 1, size=(num_models, ))
        
        self.ratio=ratio
        self.replace=replace
        self.focus_on_signal=focus_on_signal
        
        self.params={'n_estimators': 200,
                'max_depth': 4,
                'learning_rate': 0.3,
                'subsample': 0.5,
                'n_jobs': n_jobs,
                'random_state': random_state}
        for random_integer in self.random_integers:
            self.params['random_state']=random_integer
            self.models.append(XGBClassifier(**self.params))

        self.is_fitted_ = False
        
    def fit(self, X, y):
        assert np.unique(y).shape[0]==2, 'must be a binary label y'
        # Check that X and y have correct shape
        X, y = check_X_y(X, y)
        # Store the classes seen during fit
        self.classes_ = unique_labels(y)
        # Find indices of samples with y=0 and y=1
        y_0_indices = np.where(y == 0)[0]
        y_1_indices = np.where(y == 1)[0]
        ratio=self.ratio
        for model in self.models:
            if self.focus_on_signal:
                y_0_random_indices = np.random.choice(y_0_indices, size=int(ratio*len(y_1_indices)), replace=self.replace)
                y_1_random_indices = np.random.choice(y_1_indices, size=int(ratio*len(y_1_indices)), replace=self.replace)
            else:
                y_0_random_indices = np.random.choice(y_0_indices, size=int(ratio*len(y_0_indices)), replace=self.replace)
                y_1_random_indices = np.random.choice(y_1_indices, size=int(ratio*len(y_0_indices)), replace=self.replace)
                
            # Combine the indices of y=0 and sampled y=1
            balanced_indices = np.concatenate((y_0_random_indices, y_1_random_indices))

            # Create the balanced feature matrix and label vector
            balanced_X = X[balanced_indices]
            balanced_y = y[balanced_indices]

            model.fit(balanced_X, balanced_y)

        self.is_fitted_ = True
        # Return the classifier
        return self
    
    def predict_proba(self, X):

        # Check is fit had been called
        assert self.is_fitted_ is True, 'model is not fitted'

        # Input validation
        X = check_array(X)
        
        y_hat = np.zeros((X.shape[0], 2))
        for model in self.models:
            y_hat[:,0] += model.predict_proba(X)[:,0]
            y_hat[:,1] += model.predict_proba(X)[:,1]
        y_hat = y_hat / len(self.models)
        
        return y_hat
    
    def predict(self, X):

        # Check is fit had been called
        assert self.is_fitted_ is True, 'model is not fitted'

        # Input validation
        X = check_array(X)
        
        predictions_proba=self.predict_proba(X)
        
        return predictions_proba[:,1]>=self.threshold
    
    def save(self, save_path):
        # Check is fit had been called
        assert self.is_fitted_ is True, 'model is not fitted'
        
        for i,model in enumerate(self.models):
            model.save_model(save_path+f'/xgb_classifier_{i}.json')
        print("model is saved!")
        # Return the classifier
        return self
    
    def load(self, model_path):
        for i,model in enumerate(self.models):
            model.load_model(model_path+f'/xgb_classifier_{i}.json')
        self.is_fitted_ = True
        print("model is loaded!")
        # Return the classifier
        return self