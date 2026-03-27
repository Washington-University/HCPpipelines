from sklearn.preprocessing import StandardScaler
from sklearn.pipeline import make_pipeline
from sklearn.svm import NuSVC, SVC
from sklearn.tree import DecisionTreeClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.neural_network import MLPClassifier
from sklearn.neighbors import KNeighborsClassifier
from sklearn.ensemble import RandomForestClassifier, ExtraTreesClassifier, BaggingClassifier
from xgboost import XGBClassifier 

base_learners={            
    'RandomForest': make_pipeline(RandomForestClassifier(class_weight='balanced',random_state=0)),
    'Xgboost': make_pipeline(XGBClassifier(class_weight='balanced', random_state=0, verbosity=0)),
    #'BaggingTree': make_pipeline(BaggingClassifier(DecisionTreeClassifier(class_weight='balanced'),random_state=0)),
    'MLPOneLayer': make_pipeline(StandardScaler(), MLPClassifier([20,], max_iter=2000, random_state=0)),
    'ExtraTree': make_pipeline(ExtraTreesClassifier(class_weight='balanced', random_state=0)),
    'WeightedKNN': make_pipeline(StandardScaler(), KNeighborsClassifier(n_neighbors=3, weights='distance')),
    }

base_learners={            
    #'RandomForest': make_pipeline(RandomForestClassifier(class_weight='balanced',random_state=0)),
    #'Xgboost': make_pipeline(XGBClassifier(class_weight='balanced', random_state=0, verbosity=0)),
    #'BaggingTree': make_pipeline(BaggingClassifier(DecisionTreeClassifier(class_weight='balanced'),random_state=0)),
    'MLPOneLayer': make_pipeline(StandardScaler(), MLPClassifier([20,], max_iter=2000, random_state=0)),
    'ExtraTree': make_pipeline(ExtraTreesClassifier(class_weight='balanced', random_state=0)),
    #'WeightedKNN': make_pipeline(StandardScaler(), KNeighborsClassifier(n_neighbors=3, weights='distance')),
    'MLPTwoLayer': make_pipeline(StandardScaler(), MLPClassifier([5,5], max_iter=2000, random_state=0)),
    'Xgboost': make_pipeline(XGBClassifier(class_weight='balanced', random_state=0, verbosity=0, n_estimators=200, max_depth=4, learning_rate=0.3, subsample=0.5)),
    'logistic regression': make_pipeline(StandardScaler(), LogisticRegression(class_weight='balanced',max_iter=3000, random_state=0)),
    }


stacking_learner={            
    #'logistic regression': make_pipeline(StandardScaler(), LogisticRegression(class_weight='balanced',max_iter=3000, random_state=0)),
    'linearSVM': make_pipeline(StandardScaler(), SVC(kernel='linear', class_weight='balanced', gamma='auto', probability=True, random_state=0)),
    }

base_learner_candidates={
    'Xgboost_v2': make_pipeline(XGBClassifier(class_weight='balanced', random_state=0, verbosity=0, n_estimators=200, max_depth=4, learning_rate=0.3, subsample=0.5)),
    'logistic regression v2': make_pipeline(StandardScaler(), LogisticRegression(class_weight='balanced',max_iter=3000, random_state=0, solver='sag')),
    'DecisionTree': make_pipeline(DecisionTreeClassifier(class_weight='balanced',random_state=0)),
    #'linearSVM': make_pipeline(StandardScaler(), SVC(kernel='linear', class_weight='balanced', gamma='auto', probability=True, random_state=0)),
    #'quadraticSVM': make_pipeline(StandardScaler(), SVC(kernel='poly', degree=2, class_weight='balanced',gamma='auto', probability=True, random_state=0)),
    #'cubicSVM': make_pipeline(StandardScaler(), SVC(kernel='poly', degree=3, gamma='auto', probability=True, random_state=0)),
    #'rbfSVM': make_pipeline(StandardScaler(), SVC(kernel='rbf', gamma='auto', class_weight='balanced',probability=True, random_state=0)),
    'logistic regression': make_pipeline(StandardScaler(), LogisticRegression(class_weight='balanced',max_iter=3000, random_state=0)),
    'RandomForest': make_pipeline(RandomForestClassifier(class_weight='balanced',random_state=0)),
    'MLPOneLayer': make_pipeline(StandardScaler(), MLPClassifier([20,], max_iter=2000, random_state=0)),
    'MLPTwoLayer': make_pipeline(StandardScaler(), MLPClassifier([5,5], max_iter=2000, random_state=0)),
    'KNN': make_pipeline(StandardScaler(), KNeighborsClassifier(n_neighbors=3, weights='uniform')),
    'WeightedKNN': make_pipeline(StandardScaler(), KNeighborsClassifier(n_neighbors=3, weights='distance')),
    'ExtraTree': make_pipeline(ExtraTreesClassifier(class_weight='balanced', random_state=0)),
    'BaggingTree': make_pipeline(BaggingClassifier(DecisionTreeClassifier(class_weight='balanced'),random_state=0)),
    'Xgboost': make_pipeline(XGBClassifier(class_weight='balanced', random_state=0, verbosity=0)),
}