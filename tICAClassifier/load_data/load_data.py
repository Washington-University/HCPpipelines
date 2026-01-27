import pandas as pd
import json
import pickle
import numpy as np
import os
import copy

from .utils import category2label, preprocess_feature, preprocess_label_file
#from utils import category2label, preprocess_feature, preprocess_label_file

# global
CONFIG_JSON_SAVE_PATH='./prepare_data'
AUG_CONFIG_SAVE_PATH='./data_aug'
AUG_CONFIG_SAVE_PATH='./data_aug_rnd'

# aug config pkl is generated in ./data_aug
# including group info and aug info

# Step1: load group features based on config json
def load_data(config_file_path=f"{CONFIG_JSON_SAVE_PATH}/S1200_MSMAll3T535T_rfMRI_REST.json",
              group_feature_path=None,
              group_label_path=None,
              aug_config_file_name="april30_chosen50_rnd100_20230430-172640",
              keyword="april30_chosen50_rnd100",
              aug_range=range(100),
              weak_all_signal=False,
              abs_feature=False,
              keep_feature_columns=None,
              extra_feature=None,
              aug_config_path="./data_aug"
              ):
    with open(config_file_path,'r') as config_file:
        config = json.load(config_file)
    

    # HCA, HCD change to mnt folder
    if "HCA" in config['StudyFolder']:
        config['StudyFolder']="/mnt/NRG_overlay/NRG/intradb/archive/CinaB/CCF_HCA_STG"
    elif "HCD" in config['StudyFolder']:
        config['StudyFolder']="/mnt/NRG_overlay/NRG/intradb/archive/CinaB/CCF_HCD_STG"

    # if override the path in config json
    if group_feature_path is None:
        feature_base_name='features.csv'
        feature_path=f"{config['StudyFolder']}/{config['GroupAverageName']}/MNINonLinear/Results/{config['OutputfMRIName']}/tICA_d{config['sICADim']}/{feature_base_name}"
    else:
        feature_path=f"{config['StudyFolder']}/{config['GroupAverageName']}/MNINonLinear/Results/{config['OutputfMRIName']}/tICA_d{config['sICADim']}/{group_feature_path}"
    df_group_feature=pd.read_csv(feature_path)
    
    # if override the path in config json
    if group_label_path is None:
        category_ = config['category']
    else:
        category_ = preprocess_label_file(group_label_path)
    category_info=category2label(category_, weak_all_signal=weak_all_signal)
    label=category_info['label']

    # sanity check the size of feature and label
    assert len(label)==df_group_feature.shape[0], f"group feature size {df_group_feature.shape[0]} and label length {len(label)} don't match"
    
    df_group_feature_preprocessed = preprocess_feature(df_group_feature, keep_feature_columns, abs_feature)
    
    keep_feature_columns_ = copy.deepcopy(keep_feature_columns)
    # add extra group features
    if extra_feature is not None:
        assert extra_feature.shape[0]==df_group_feature_preprocessed.shape[0], f"shape not match extra_feature: {extra_feature.shape[0]} df_group_feature_preprocessed: {df_group_feature_preprocessed.shape[0]}"
        for idx in range(extra_feature.shape[1]):
            df_group_feature_preprocessed[f"extra_feature_{idx}"]=extra_feature[:,idx]
            keep_feature_columns_.append(f"extra_feature_{idx}")
            
    # Step2: load augmented features based on aug config pkl
    if len(aug_range)==0: # no aug
        df_aug_preprocessed=None
        df_aug_label=None
        result={
        "group": {"features": df_group_feature_preprocessed,
                  "label": np.array(label)},
        "aug": {"features": None,
                  "label": None}
        }
    else:
        aug_config_file_path=f"{aug_config_path}/{config['GroupAverageName']}/{config['OutputfMRIName']}/tICA_d{config['sICADim']}/{aug_config_file_name}.pkl"

        with open(aug_config_file_path,'rb') as aug_config_file:
            aug_config = pickle.load(aug_config_file)

        aug_keys_=list(aug_config.keys())
        aug_keys=[key for key in aug_keys_ if keyword in key]

        df_aug_list=[]
        label_aug_list=[]
        # # no augmentation
        # if aug_range is None:
        #     return {
        #             "group": {"features": df_group_feature_preprocessed,
        #                     "label": df_group_label},
        #             "aug": {"features": None,
        #                     "label": None}
        #             }
        aug_feature_names=['brain_region_stat_', 'brain_region_stat_groupnorm_', 'vessal_stat_', 'vessal_stat_groupnorm_', 'kspace_mask_stat_', 'kspace_mask_stat_groupnorm_',
                        'parcel_features_', 'parcel_features_groupnorm_', 'boundary_stat_', 'boundary_stat_groupnorm_', 'vas_stat_', 'vas_stat_groupnorm_',
                        'spectrum_stat', 'spectrum_stat_groupscale', 'spectrum_stat_groupnorm', 'global_idx_old', 'global_idx', 'global_idx_groupnorm','vas_correlation_atlas_']
        for i in aug_range:
            aug_feature_file_name=f"features_{config['GroupAverageName']}_{config['OutputfMRIName']}_{config['sICADim']}_{aug_keys[0]}.csv"
            aug_feature_path=f"{aug_config_path}/{config['GroupAverageName']}/{config['OutputfMRIName']}/tICA_d{config['sICADim']}/feature_csv/{aug_feature_file_name}"
            df_aug_single = pd.read_csv(aug_feature_path)
            # override the non-aug features with group df
            # then only change group df is sufficient when features need to be re-consider
            for column in keep_feature_columns_:
                if not any(substring in column for substring in aug_feature_names):
                    df_aug_single[column]=df_group_feature_preprocessed[column]
            df_aug_list.append(df_aug_single)
            label_aug_list+=label
            
        df_aug=pd.concat(df_aug_list, axis=0, ignore_index=True)
    
        df_aug_preprocessed = preprocess_feature(df_aug, keep_feature_columns_, abs_feature)
        df_group_label, df_aug_label = np.array(label), np.array(label_aug_list)
        result={
            "group": {"features": df_group_feature_preprocessed,
                    "label": df_group_label},
            "aug": {"features": df_aug_preprocessed,
                    "label": df_aug_label}
        }
    return result
    
# directly run is not supported because of the relative module path
if __name__=='__main__':
    # result = load_data(config_file_path=f"{CONFIG_JSON_SAVE_PATH}/S1200_MSMAll3T535T_rfMRI_REST.json",
    #             aug_config_file_name="april30_chosen50_rnd100_20230430-172640",
    #             keyword="april30_chosen50_rnd100",
    #             aug_range=range(100))
    
    # result = load_data(config_file_path=f"{CONFIG_JSON_SAVE_PATH}/AABC_Version2_Prelim_Data_Visits_617T_fMRI_CONCAT_ALL_clean.json",
    #             aug_config_file_name="april30_chosen50_rnd100_20230501-111656",
    #             keyword="april30_chosen50_rnd100",
    #             aug_range=range(100))
    
    result = load_data(config_file_path=f"{CONFIG_JSON_SAVE_PATH}/S1200_MSMAll3T535T_rfMRI_REST.json",
                       group_feature_path="features_20230814_154437.csv",
                       group_label_path="./datasets_category/S1200_MSMAll3T535T_REST84.txt",
                aug_config_file_name="april30_chosen50_rnd100_20230430-172640",
                keyword="april30_chosen50_rnd100",
                aug_range=range(100))
    
    with open('./train_group_aug.json','r') as config_file:
        config = json.load(config_file)
    
    result={}
    for key, val in config.items():
        try:
            result[key] = load_data(config_file_path=f"{CONFIG_JSON_SAVE_PATH}/{key}.json",
                    aug_config_file_name=val["aug_config_name"],
                    keyword=val["aug_keyword"],
                    aug_range=range(100))
        except:
            print(f"{key} has issues loading")