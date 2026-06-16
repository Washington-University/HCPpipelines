import argparse
import re
from glob import glob
import os

import torch
import torch.nn as nn
import numpy as np
import nibabel as nb
from tqdm import tqdm
from xgboost_ensemble_classifier import XGBoostEnsembleClassifier
from xgboost_ensemble_regressor import XGBoostEnsembleRegressor

    
def main(args):
    # print("InputDense:", args.input_dense)
    # print("ModelName:", args.model)
    # print("TrainedFolder:", args.trained_folder)
    # print("AreaNamesFile:", args.area_names_file)
    # print("InputFeatureTypes:", args.input_feature_types)
    # print("OutputFolder:", args.output_folder)
    # print("Device:", args.device)
    # print("HCPPIPEDIR", args.hcp_pipe_dir)
    # print("Hem", args.hemisphere)

    test_data=args.input_dense
    model_folder=args.trained_folder
    model_name=args.model
    area_name_file=args.area_names_file
    feature_type_file=args.input_feature_types
    save_path=args.output_folder
    hcp_pipe_dir=args.hcp_pipe_dir
    hem = args.hemisphere
    
    # area name
    with open(area_name_file, 'r') as file:
        lines = file.readlines()
    area_names = [line.strip() for line in lines]

    # gifti data
    gifti_list = nb.load(test_data).darrays
    gifti_numpy_concat = np.concatenate([gifti_numpy.data[..., np.newaxis] for gifti_numpy in gifti_list], axis=1) # num_vertices X feature_dim
    
    ROI_data = nb.load(f"{hcp_pipe_dir}/ArealClassifier/data/HCP_MMP_ROIs/{area_names[0][0].upper()}.atlasroi.32k_fs_LR.shape.gii").darrays[0].data.astype(int)
    ROI_indices = np.where(ROI_data==1)[0]
    
    FeatureCategories=np.loadtxt(feature_type_file).astype(int)
    
    # logan's normalization
    if model_name.lower() in ['xgboost', 'xgboost_2nd_prob']: # raw matlab normalization
        # dense data
        input_numpy = np.expand_dims(gifti_numpy_concat, axis=0)   
        # normalize data
        mean_features=input_numpy.mean(1) # 1 X feat_dim
        std_features_raw = input_numpy.std(1) # 1 X feat_dim
        std_features = np.zeros_like(std_features_raw)

        for f in range(1, np.amax(FeatureCategories)+1):
            mask = np.where(FeatureCategories == f)[0] # indices
            std_features[:, mask] = np.median(std_features_raw[:, mask])
        normdata = (input_numpy - mean_features) / std_features # (1, 32492, feat_dim)
    else:
        raise ValueError(f"model_name: {model_name} is not supported!")

    c=0
    # loop over all the area names
    for i, area_name in tqdm(enumerate(area_names), total=len(area_names)):
        hemisphere=area_name.split('_')[0]
        if hem != "B":
            if hem != hemisphere:
                continue
        ROI="_".join(area_name.split('_')[1:])
        
        # dil ROI mask gifti
        dil_gifti_mask = nb.load(f"{hcp_pipe_dir}/ArealClassifier/data/HCP_MMP_ROIs/{hemisphere.upper()}.{ROI}.dil.label.gii").darrays[0].data
        dil_gifti_mask = torch.BoolTensor(dil_gifti_mask)
        
        if ROI == 'V1_ROI':
            in_channels = FeatureCategories.shape[0]-6 # 6 visuotopic maps
        else:
            in_channels = FeatureCategories.shape[0]
        # print(i+1, area_name)
        
        # inference
        probability_map = np.zeros((normdata.shape[1]))
        if model_name.lower()=='xgboost':
            mdl=XGBoostEnsembleClassifier(threshold=0.5, random_state=12345, num_models=100)
            mdl.load(model_folder+f"/{area_name}")
            estimate_probability = mdl.predict_proba(normdata[0,dil_gifti_mask,:in_channels])[:,1]
        elif model_name.lower()=='xgboost_2nd_prob':
            mdl=XGBoostEnsembleRegressor(random_state=12345, num_models=100)
            mdl.load(model_folder+f"/{area_name}")
            estimate_probability = np.clip(mdl.predict(normdata[0,dil_gifti_mask,:in_channels]), 0, 1)
        else:
            raise ValueError(f"model_name: {model_name.lower()} is not supported!")
            
        probability_map[dil_gifti_mask.numpy()] = estimate_probability
        
        # save gifti
        placeholder_probability_map = nb.load(f'{hcp_pipe_dir}/ArealClassifier/data/Q1-Q6_RelatedParcellation210.{hemisphere}.midthickness_MSMAll_2_d41_WRN_DeDrift_va.32k_fs_LR.shape.gii') ### gifti file
        placeholder_probability_map.darrays[0].data = probability_map[...,np.newaxis]
        nb.save(placeholder_probability_map,f'{save_path}/{i+1}_{hemisphere}_{ROI}_final_area.shape.gii')

        c+=1

    # print(f"{c}/{len(area_names)} is finished!")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Areal classifier 2.0.")

    parser.add_argument("--input_dense", type=str, help="Test data file path")
    parser.add_argument("--model", type=str, help="the model to use MLP/XGBOOST")
    parser.add_argument("--trained_folder", type=str, help="Trained folder path")
    parser.add_argument("--input_dil_rois", type=str, help="Dilated ROI file path")
    parser.add_argument("--area_names_file", type=str, help="Area names file path")
    parser.add_argument("--input_feature_types", type=str, help="Feature types file path")
    parser.add_argument("--output_folder", type=str, help="Save path")
    parser.add_argument("--hcp_pipe_dir", type=str, help="HCPPIPEDIR path")
    parser.add_argument("--device", type=str, default="cpu", help="Device (default: cpu)")
    parser.add_argument("--hemisphere", type=str, default="B", help="hemisphere to use")

    args = parser.parse_args()
    main(args)
