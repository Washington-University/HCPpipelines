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

# available models
models = [
    'RandomForest',
    'MLP',
    'Xgboost',
    'WeightedKNN',
    'XgboostEnsemble',
]

def main(args):
    
    # general inputs
    # output
    reclassify_as_signal_file=args.reclassify_as_signal_file
    reclassify_as_noise_file=args.reclassify_as_noise_file

    # decision threshold for every rclean model
    threshold = 0.5
    
    feature_file_path=args.input_csv
    
    not_use_fix=args.not_use_fix
        
    trained_folder=args.trained_folder
    output_folder=args.output_folder
    
    model_names=args.model.split("@")
    voting_threshold=int(args.voting_threshold)
    
    assert voting_threshold<=len(model_names), "the voting threshold must be smaller than or equal to the number of models to use"
    
    models_to_use={}
    for model_name in model_names:
        if model_name not in models:
            raise ValueError(f"{model_name} is not supported!")
        models_to_use[model_name]=joblib.load(f'{trained_folder}/{model_name}.joblib')

    # load csv and remove the Row column
    df_feature=pd.read_csv(feature_file_path)
    df_feature.index=df_feature['Row']
    df_feature=df_feature.drop(columns=['Row'])
    
    predictions_dict={}
    for model_name in model_names:
        predictions = models_to_use[model_name].predict_proba(df_feature.values)
        predictions_dict[model_name]=predictions[:,1] # signal prediction
    
    # save predictions
    df_prediction=pd.DataFrame.from_dict(predictions_dict)
    df_prediction.index=df_feature.index    
    
    df_predict_class = df_prediction.applymap(lambda x: 1 if x >= threshold else 0)

    if not_use_fix is False: # if using FIX result
        fix_prob_file_path=args.input_fix_prob_csv
        fix_prob_threshold=int(args.fix_prob_threshold)/100
        df_fix_prob=pd.read_csv(fix_prob_file_path)
        df_fix_prob.index=df_fix_prob['Row']
        df_fix_prob=df_fix_prob.drop(columns=['Row'])
        df_fix_class = df_fix_prob.applymap(lambda x: 1 if x >= fix_prob_threshold else 0)

    reclassify_dict={}
    for column in df_predict_class.columns:
        predict_=df_predict_class[column].to_numpy()
        # if using FIX result
        if not_use_fix is False:
            baseline_pred=df_fix_class['Var1'].to_numpy()
            reclassifyToSignal=np.intersect1d(np.where(baseline_pred==0)[0], np.where(predict_==1)[0])
            reclassifyToNoise=np.intersect1d(np.where(baseline_pred==1)[0], np.where(predict_==0)[0])
        # if not using FIX, just inference by models
        else:
            reclassifyToSignal=np.where(predict_==1)[0]
            reclassifyToNoise=np.where(predict_==0)[0]
        reclassify_dict[column]={
                "ReclassifyToSignal": reclassifyToSignal.tolist(),
                "ReclassifyToNoise": reclassifyToNoise.tolist(),
        }

    all_reclassify_to_signal=[]
    all_reclassify_to_noise=[]
    for model_name in reclassify_dict:
        all_reclassify_to_signal.extend(reclassify_dict[model_name]["ReclassifyToSignal"])
        all_reclassify_to_noise.extend(reclassify_dict[model_name]["ReclassifyToNoise"])
    
    # counts
    # at least certain number of models among all the models give a prediction different from FIX (voting)
    cnt = voting_threshold
    reclassify_to_signal_count = defaultdict(int)
    reclassify_to_noise_count = defaultdict(int)

    # fount occurrences of each element in the list
    for num in all_reclassify_to_signal:
        reclassify_to_signal_count[num] += 1

    for num in all_reclassify_to_noise:
        reclassify_to_noise_count[num] += 1
        
    # find elements that are duplicated more than certain times
    all_reclassify_to_signal_final = [num for num, count in reclassify_to_signal_count.items() if count >= cnt]
    all_reclassify_to_noise_final = [num for num, count in reclassify_to_noise_count.items() if count >= cnt]

    with open(reclassify_as_signal_file, "w") as text_file:
        text_file.write(" ".join([f"{idx+1}" for idx in sorted(all_reclassify_to_signal_final)])) # plus 1 for indexing from 1 instead of 0
        
    with open(reclassify_as_noise_file, "w") as text_file:
        text_file.write(" ".join([f"{idx+1}" for idx in sorted(all_reclassify_to_noise_final)]))
    
    if not_use_fix is False: # if using FIX result
        df_prediction["FIX"]=df_fix_prob['Var1']
        df_prediction.to_csv(f"{output_folder}/rclean_fix_prediction_proba.csv")
    else:
        df_prediction.to_csv(f"{output_folder}/rclean_prediction_proba.csv")
    
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Reclean classifier inference stage only.")

    parser.add_argument("--input_csv", type=str, help="the reclean feature csv file path")
    parser.add_argument("--input_fix_prob_csv", type=str, help="the FIX probability csv file path")
    parser.add_argument("--fix_prob_threshold", type=str, help="the threshold for FIX, e.g., 10")
    parser.add_argument('--not_use_fix', action='store_true', help='enable to not use fix')
    parser.add_argument("--trained_folder", type=str, help="Trained folder path")
    parser.add_argument("--model", type=str, help="the models to use for inference e.g., 'RandomForest@Xgboost'")
    parser.add_argument("--output_folder", type=str, help="Save path for prediction")
    parser.add_argument("--voting_threshold", type=str, help="a number smaller or equal to the number of models")
    parser.add_argument("--reclassify_as_signal_file", type=str, help="output txt file from reclassification for signal")
    parser.add_argument("--reclassify_as_noise_file", type=str, help="output txt file from reclassification for noise")

    args = parser.parse_args()
    main(args)