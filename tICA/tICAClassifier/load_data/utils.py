import json

import pandas as pd
import numpy as np
import os
import re

# Get the absolute path of the directory containing this module
MODULE_DIR = os.path.dirname(os.path.abspath(__file__))

CATEGORY_MAPPING={
    ('signal',
        'specialsignal',
        'mixed',
        'subcortical',
        'notsure'): 1,
    ('spatiallyspecificnoise',
        'signal or spatiallyspecificnoise'): 0,
    ('globalnoise', 'vasculardelay'): 2,
    ('singlesubjectglobalnoise',
        'singlesubjectspatiallyspecificnoise'): 3,
    ('weaknoise'): 4,
    ('weaksignal',
     'signal or weaksignal'): 5,
    ('singlesubjectsignal',
        'singlesubjectspecialsignal',
        'singlesubjectsignal or singlesubjectspecialsignal',
        'singlesubjectsignal or singlesubjectglobalnoise',
        'singlesubjectspecialsignal or singlesubjectglobalnoise',
        'singlesubjectglobalnoise or singlesubjectspecialsignal'): 6,
    ('weaksubcortical'): 7
}

LABEL_MAPPING={
    (1,5,6,7): 1,
    (0,2,3,4): 0
}

LABEL_MAPPING_WEAK_ALL_SIGNAL={
    (1,4,5,6,7): 1,
    (0,2,3): 0
}

# Open the JSON file
with open(os.path.join(MODULE_DIR, 'keep_features.json'), 'r') as f:
    KEEP_FEATURE_COLUMNS = json.load(f)
    
def category2label(category, weak_all_signal=False):
    if weak_all_signal:
        label_mapping_to_use=LABEL_MAPPING_WEAK_ALL_SIGNAL
    else:
        label_mapping_to_use=LABEL_MAPPING
    category_info=dict()
    category_info['category']=category
    label_raw_list=[]
    label_list=[]
    single_list=[]
    for idx,cat in enumerate(category):
        # flag to check if a category can be found in the mapping dict
        valid_cat=False
        cat=cat.lower()
        if 'single' in cat:
            single_subj=1
        else:
            single_subj=0
        single_list.append(single_subj)
        
        for keywords, label in CATEGORY_MAPPING.items():
            if cat in keywords:
                label_raw_list.append(label)
                valid_cat=True
                break
        
        if not valid_cat:
            print(f"No.{idx} category: {cat} cannot be found in mapping dict")
            
    category_info['single']=single_list
    assert len(category)==len(label_raw_list)
    category_info['label_raw']=label_raw_list
    
    for lab in label_raw_list:
        for keywords, label in label_mapping_to_use.items():
            if lab in keywords:
                label_list.append(label)
                break
            
    assert len(category)==len(label_list)
    category_info['label']=label_list
    return category_info
    
def ss_volume_distortion_list():
    volume_distortion_list=['S1200_MSMAll7T87T_rfMRI_REST_7T_d108_59',
                            'S1200_MSMAll7T87T_rfMRI_REST_7T_d108_86',
                            'S1200_MSMAll7T87T_rfMRI_REST_7T_d108_95',
                            'S1200_MSMAll7T87T_rfMRI_REST_7T_d108_99',
                            'S1200_MSMAll7T87T_tfMRI_MOVIE_7T_d113_88',
                            'S1200_MSMAll7T87T_tfMRI_MOVIE_7T_d113_89',
                            'S1200_MSMAll7T87T_tfMRI_MOVIE_7T_d113_93',
                            'S1200_MSMAll7T87T_tfMRI_MOVIE_7T_d113_96',
                            'S1200_MSMAll7T87T_tfMRI_MOVIE_7T_d113_99',
                            'S1200_MSMAll7T87T_tfMRI_MOVIE_7T_d113_101',
                            'S1200_MSMAll7T87T_tfMRI_MOVIE_7T_d113_102',
                            'S1200_MSMAll7T87T_tfMRI_MOVIE_7T_d113_104',
                            'S1200_MSMAll7T87T_tfMRI_MOVIE_7T_d113_105',
                            'S1200_MSMAll7T87T_tfMRI_MOVIE_7T_d113_106',
                            'S1200_MSMAll7T87T_tfMRI_MOVIE_7T_d113_107',
                            'S1200_MSMAll7T87T_tfMRI_MOVIE_7T_d113_112',
                            'S1200_MSMAll7T87T_tfMRI_RET_7T_d75_44',
                            'S1200_MSMAll7T87T_tfMRI_RET_7T_d75_47',
                            'S1200_MSMAll7T87T_tfMRI_RET_7T_d75_59',
                            'S1200_MSMAll7T87T_tfMRI_RET_7T_d75_64',
                            'S1200_MSMAll7T87T_tfMRI_RET_7T_d75_66',
                            'S1200_MSMAll7T87T_tfMRI_RET_7T_d75_68',
                            'S1200_MSMAll7T87T_tfMRI_RET_7T_d75_74',
                            'S1200_MSMAll7T87V_rfMRI_REST_7T_d108_57',
                            'S1200_MSMAll7T87V_rfMRI_REST_7T_d108_69',
                            'S1200_MSMAll7T87V_rfMRI_REST_7T_d108_74',
                            'S1200_MSMAll7T87V_rfMRI_REST_7T_d108_89',
                            'S1200_MSMAll7T87V_rfMRI_REST_7T_d108_105',
                            'S1200_MSMAll7T87V_rfMRI_REST_7T_d108_106',
                            'S1200_MSMAll7T87V_rfMRI_REST_7T_d108_107',
                            'S1200_MSMAll7T87V_tfMRI_MOVIE_7T_d100_73',
                            'S1200_MSMAll7T87V_tfMRI_MOVIE_7T_d100_90',
                            'S1200_MSMAll7T87V_tfMRI_MOVIE_7T_d100_93',
                            'S1200_MSMAll7T87V_tfMRI_MOVIE_7T_d100_95',
                            'S1200_MSMAll7T87V_tfMRI_MOVIE_7T_d100_97',#new added 2
                            'S1200_MSMAll7T87V_tfMRI_MOVIE_7T_d100_99',
                            'S1200_MSMAll7T87V_tfMRI_RET_7T_d73_64',
                            'S1200_MSMAll7T87V_tfMRI_RET_7T_d73_67',
                            'S1200_MSMAll7T87V_tfMRI_RET_7T_d73_72',]
    return np.asarray(volume_distortion_list)

def preprocess_label_file(file_path):
    label=[]
    with open(file_path, "r") as f:
        for line in f:
            processed_line = line.strip()  # Remove leading/trailing whitespace
            tmp_=processed_line.split(';')[0]
            substring = re.match(r"[^ ?]+", tmp_).group()
            label.append(substring)
    return label
    
# def preprocess_feature(df_feature, keep_feature_columns, abs_feature=False):
#     cols = df_feature.columns.to_list()
#     cols_mapping={}
#     # features may contain space in column names
#     for col in cols:
#         cols_mapping[col]=col.replace(" ", "")
#     df_feature=df_feature.rename(columns=cols_mapping)
#     # Get a list of column names to keep
#     cols_to_keep = [col for col in keep_feature_columns]

#     # instead of using loc should use reindex
#     #df_feature = df_feature.reindex(columns=cols_to_keep)
#     df_feature = df_feature.loc[:, cols_to_keep]
    
#     if abs_feature:
#         df_feature=add_abs_features(df_feature)
        
#     # Check for NaN values
#     assert df_feature[df_feature.isna().any(axis=1)].shape[0]==0, 'input df has NaN values which is not supported!'
    
#     return df_feature
def preprocess_feature(df_feature, keep_feature_columns, abs_feature=False):
    cols = df_feature.columns.to_list()
    cols_mapping={}
    # features may contain space in column names
    for col in cols:
        cols_mapping[col]=col.replace(" ", "")
    df_feature=df_feature.rename(columns=cols_mapping)
    # Get a list of column names to keep
    cols_to_keep = [col for col in keep_feature_columns]

    # instead of using loc should use reindex
    #df_feature = df_feature.reindex(columns=cols_to_keep)
    df_feature = df_feature.loc[:, cols_to_keep]
    
    if abs_feature:
        df_feature=add_abs_features(df_feature)
        
    # Check for NaN values
    assert df_feature[df_feature.isna().any(axis=1)].shape[0]==0, 'input df has NaN values which is not supported!'
    
    return df_feature

def add_abs_features(df_feature):
    with open('./load_data/features_abs.json','r') as config_file:
        features_abs = json.load(config_file)
    
    features_to_process_=list(features_abs.values())
    features_to_process = [item for sublist in features_to_process_ for item in sublist]

    # Loop through the features and add new columns with absolute values
    for feature in features_to_process:
        new_column_name = f"{feature}_abs"  # New column name
        df_feature[new_column_name] = df_feature[feature].abs()  # Add new column with absolute values
    return df_feature

# the raw settings of filtering df
def preprocess_data(data_feature):
    """
    preprocess the dataframe of feature table.

    Args:
        data_feature (df): the input feature table
    
    Returns:
        df: the preprocessed feature table
    """
    drop_feature_list=[]
    step=4
    for i in range(8):
        name='brain_region_stat_'
        data_feature = data_feature.drop(columns='{}{}'.format(name, i*step+4))
        
        drop_feature_list.append('{}{}'.format(name, i*step+4))
        
        name='brain_region_stat_groupnorm_'
        data_feature = data_feature.drop(columns='{}{}'.format(name, i*step+4))
        
        drop_feature_list.append('{}{}'.format(name, i*step+4))
        
        #data_feature['{}{}'.format(name, i*step+4)] = data_feature['{}{}'.format(name, i*step+4)].abs()
        name='brain_region_stat_Zss_'
        data_feature = data_feature.drop(columns='{}{}'.format(name, i*step+4))
        
        drop_feature_list.append('{}{}'.format(name, i*step+4))
        
    # drop sum(m*S)/sum(m)
    step=4
    for i in range(4):
        name='boundary_stat_'
        data_feature = data_feature.drop(columns='{}{}'.format(name, i*step+4))
        drop_feature_list.append('{}{}'.format(name, i*step+4))
        
        #data_feature['{}{}'.format(name, i*step+4)] = data_feature['{}{}'.format(name, i*step+4)].abs()
        name='boundary_stat_groupnorm_'
        data_feature = data_feature.drop(columns='{}{}'.format(name, i*step+4))
        drop_feature_list.append('{}{}'.format(name, i*step+4))
        
        name='boundary_stat_Zss_'
        data_feature = data_feature.drop(columns='{}{}'.format(name, i*step+4))
        drop_feature_list.append('{}{}'.format(name, i*step+4))
        

#     # drop kurtosis
#     step=5
#     for i in range(4):
#         if i > 1:
#             name='subcortical_stat_'
#         else:
#             name='subcortical_stat_ '
#         data_feature = data_feature.drop(columns='{}{}'.format(name, i*step+3))

#     # drop kurtosis
#     step=5
#     for i in range(4):
#         if i > 1:
#             name='boundary_stat_'
#         else:
#             name='boundary_stat_ '
#         data_feature = data_feature.drop(columns='{}{}'.format(name, i*step+3))

#     # drop kurtosis
#     step=3
#     for i in range(9):
#         if i > 2:
#             name='vas_stat_'
#         else:
#             name='vas_stat_ '
#         data_feature = data_feature.drop(columns='{}{}'.format(name, i*step+3))

    #data_feature=data_feature.drop(columns=['sum_outlier_ss_tcs_stat', 'CE_ss_tcs_stat'])

    for i in range(1,6):
        name='kspace_mask_stat_groupnorm_'
        data_feature = data_feature.drop(columns='{}{}'.format(name, i))
        drop_feature_list.append('{}{}'.format(name, i))
        
        name='kspace_mask_stat_Zss_'
        data_feature = data_feature.drop(columns='{}{}'.format(name, i))
        drop_feature_list.append('{}{}'.format(name, i))
        
    # for i in range(12):
    #     if i > 8:
    #         name='gp_black_index_'
    #     else:
    #         name='gp_black_index_ '
    #     data_feature = data_feature.drop(columns='{}{}'.format(name, i+1))
    #data_feature=data_feature.drop(columns=['spectrum_stat_groupnorm', 'spectrum_stat_groupscale'])

    # include thesis proposal
    data_feature=data_feature.drop(columns=['global_idx'])

    data_feature=data_feature.drop(columns=['DVARS_measure', 'variability'])

    data_feature=data_feature.drop(columns=['spectrum_stat', 'spectrum_stat_groupnorm'])
    
    data_feature=data_feature.drop(columns=['gp_outlier_stat_1','gp_outlier_stat_2'])
    # end include thesis proposal
    data_feature=data_feature.drop(columns=['global_idx_old'])
    
    drop_feature_list.append('global_idx')
    drop_feature_list.append('DVARS_measure')
    drop_feature_list.append('variability')
    drop_feature_list.append('spectrum_stat')
    drop_feature_list.append('spectrum_stat_groupnorm')
    drop_feature_list.append('gp_outlier_stat_1')
    drop_feature_list.append('gp_outlier_stat_2')
    drop_feature_list.append('global_idx_old')
    
    #data_feature['vas_average_atlas']=(data_feature['vas_correlation_atlas_1']+data_feature['vas_correlation_atlas_2'])/2
    #data_feature=data_feature.drop(columns=['vas_correlation_atlas_1','vas_correlation_atlas_2'])
    # ss_tcs_related_features=['sum_outlier_stat', 'CE_ss_tcs_stat', 'gp_xcorr_stat_all']
    #ss_tcs_related_features=['sum_outlier_stat', 'CE_ss_tcs_stat', 'gp_xcorr_stat_all']+[feature for feature in feature_cols if 'ss_tcs_stat_all' in feature]

    # data_feature=data_feature.drop(columns=[feature for feature in feature_cols if 'gp_stat_' in feature])

#     data_feature=data_feature.drop(columns=[feature for feature in feature_cols if 'gp_black_index' in feature])
#     for feature in ss_tcs_related_features:
#         if feature=='gp_xcorr_stat_all':
#             data_feature[feature]=(1-data_feature[feature])*data_feature['gp_stat_1']
#         else:
#             data_feature[feature]=data_feature[feature]*data_feature['gp_stat_1']
    # # include thesis proposal
    # data_feature=data_feature.drop(columns=[tmp for tmp in data_feature.columns if ('boundary_stat_' in tmp) and ('groupnorm' not in tmp)])
    # data_feature=data_feature.drop(columns=[tmp for tmp in data_feature.columns if ('brain_region_stat_' in tmp) and ('groupnorm' not in tmp)])
    # data_feature=data_feature.drop(columns=[tmp for tmp in data_feature.columns if ('vas_stat_' in tmp) and ('groupnorm' not in tmp)])
    # # end include thesis proposal
    # data_feature=data_feature.drop(columns=[tmp for tmp in data_feature.columns if ('parcel_features_' in tmp) and ('groupnorm' not in tmp)])
    
    drop_feature_list+=[tmp for tmp in data_feature.columns if ('boundary_stat_' in tmp) and ('groupnorm' not in tmp and 'Zss' not in tmp)]
    drop_feature_list+=[tmp for tmp in data_feature.columns if ('brain_region_stat_' in tmp) and ('groupnorm' not in tmp and 'Zss' not in tmp)]
    drop_feature_list+=[tmp for tmp in data_feature.columns if ('vas_stat_' in tmp) and ('groupnorm' not in tmp and 'Zss' not in tmp)]
    drop_feature_list+=[tmp for tmp in data_feature.columns if ('parcel_features_' in tmp) and ('groupnorm' not in tmp and 'Zss' not in tmp)]
    drop_feature_list+=[tmp for tmp in data_feature.columns if ('kspace_mask_stat_' in tmp) and ('groupnorm' not in tmp and 'Zss' not in tmp)]
    drop_feature_list+=[tmp for tmp in data_feature.columns if ('gp_coeff_var' in tmp) and ('gp_coeff_var_1' not in tmp)]

    
    # include Mar26 best
      # include thesis proposal
    data_feature=data_feature.drop(columns=[tmp for tmp in data_feature.columns if ('boundary_stat_' in tmp) and ('groupnorm' not in tmp and 'Zss' not in tmp)])
    data_feature=data_feature.drop(columns=[tmp for tmp in data_feature.columns if ('brain_region_stat_' in tmp) and ('groupnorm' not in tmp and 'Zss' not in tmp)])
    data_feature=data_feature.drop(columns=[tmp for tmp in data_feature.columns if ('vas_stat_' in tmp) and ('groupnorm' not in tmp and 'Zss' not in tmp)])
    # end include thesis proposal
    data_feature=data_feature.drop(columns=[tmp for tmp in data_feature.columns if ('parcel_features_' in tmp) and ('groupnorm' not in tmp and 'Zss' not in tmp)])
    data_feature=data_feature.drop(columns=[tmp for tmp in data_feature.columns if ('kspace_mask_stat_' in tmp) and ('groupnorm' not in tmp and 'Zss' not in tmp)])
    #end Mar26 best
    
    #  # include thesis proposal
    # data_feature=data_feature.drop(columns=[tmp for tmp in data_feature.columns if ('boundary_stat_groupnorm' in tmp)])
    # data_feature=data_feature.drop(columns=[tmp for tmp in data_feature.columns if ('brain_region_stat_groupnorm' in tmp)])
    # data_feature=data_feature.drop(columns=[tmp for tmp in data_feature.columns if ('vas_stat_groupnorm' in tmp)])
    # # end include thesis proposal
    # data_feature=data_feature.drop(columns=[tmp for tmp in data_feature.columns if ('parcel_features_groupnorm' in tmp)])
    # data_feature=data_feature.drop(columns=[tmp for tmp in data_feature.columns if ('kspace_mask_stat_groupnorm' in tmp)])
    
    # data_feature=data_feature.drop(columns=[tmp for tmp in data_feature.columns if ('boundary_stat_' in tmp) and ('groupnorm' in tmp)])
    # data_feature=data_feature.drop(columns=[tmp for tmp in data_feature.columns if ('brain_region_stat_' in tmp) and ('groupnorm' in tmp)])
    # data_feature=data_feature.drop(columns=[tmp for tmp in data_feature.columns if ('vas_stat_' in tmp) and ('groupnorm' in tmp)])
    # include thesis proposal
    #data_feature=data_feature.drop(columns=[tmp for tmp in data_feature.columns if ('boundary_stat_' in tmp)])
    # end include thesis proposal
    #data_feature=data_feature.drop(columns=[tmp for tmp in data_feature.columns if ('vas_stat_' in tmp)])
    # include thesis proposal
    data_feature=data_feature.drop(columns=[tmp for tmp in data_feature.columns if ('gp_coeff_var' in tmp) and ('gp_coeff_var_1' not in tmp)])
    # end include thesis proposal
    
    # vessel after proposal
    #data_feature=data_feature.drop(columns=[tmp for tmp in data_feature.columns if 'vessal_stat' in tmp])
    # kspace after proposal
    #data_feature=data_feature.drop(columns=[tmp for tmp in data_feature.columns if 'kspace_stat' in tmp])
    # after drop
    return data_feature, drop_feature_list

def create_jsons(drop_feature_list, df_group_feature_preprocessed):
    # save drop_features and keep_features as json files
    from itertools import groupby

    # Define a function to extract the feature name from a string
    def get_feature_name(s):
        return s.rsplit('_', 1)[0]

    # Use groupby to group the strings by feature name
    drop_features = {}
    for feature_name, group in groupby(drop_feature_list, key=get_feature_name):
        drop_features[feature_name] = list(group)
    with open('./load_data/drop_features.json', 'w') as f:
        json.dump(drop_features, f, indent=4, separators=(',', ': '))
        
    keep_features = {}
    for feature_name, group in groupby(list(df_group_feature_preprocessed.columns), key=get_feature_name):
        keep_features[feature_name] = list(group)
    with open('./load_data/keep_features.json', 'w') as f:
        json.dump(keep_features, f, indent=4, separators=(',', ': '))
        
if __name__=='__main__':
    # test category2label
    import json
    CONFIG_JSON_SAVE_PATH='./prepare_data'
    
    config_name_list=['S1200_MSMAll3T535T_rfMRI_REST.json',
                      'S1200_MSMAll3T535T_tfMRI_Concat.json',
                      'S1200_MSMAll7T87T_rfMRI_REST_7T.json',
                      'S1200_MSMAll7T87T_tfMRI_MOVIE_7T.json',
                      'S1200_MSMAll7T87T_tfMRI_RET_7T.json',
                      'AABC_Version2_Prelim_Data_Visits_617T_fMRI_CONCAT_ALL_clean.json',
                      'HCD628_Winter2021_314T_fMRI_CONCAT_ALL_clean.json',
                      'HCD628_Winter2021_160independent_fMRI_CONCAT_ALL_clean.json',
                      'HCD628_Winter2021_100independent_fMRI_CONCAT_ALL_clean.json',
                      'HCD628_Winter2021_60independent_fMRI_CONCAT_ALL_clean.json',
                      'S1200_MSMAll3T535V_rfMRI_REST.json',
                      'S1200_MSMAll3T535V_tfMRI_Concat.json',
                      'S1200_MSMAll7T87V_rfMRI_REST_7T.json',
                      'S1200_MSMAll7T87V_tfMRI_MOVIE_7T.json',
                      'S1200_MSMAll7T87V_tfMRI_RET_7T.json',
                      'AABC_Version2_Prelim_Data_Visits_617V_fMRI_CONCAT_ALL_clean.json',
                      'HCD628_Winter2021_314V_fMRI_CONCAT_ALL_clean.json',
                      ]
    for config_name in config_name_list:
        config_file_path=f'{CONFIG_JSON_SAVE_PATH}/{config_name}'
        with open(config_file_path,'r') as config_file:
            config = json.load(config_file)
        try:
            config_info=category2label(config['category'])
        except:
            print(config_name)
            
    # test preprocess features
    # Step1: load group features based on config json
    config_file_path=f'{CONFIG_JSON_SAVE_PATH}/S1200_MSMAll3T535T_rfMRI_REST.json'
    with open(config_file_path,'r') as config_file:
        config = json.load(config_file)
        
    feature_base_name='features.csv'
    feature_path=f"{config['StudyFolder']}/{config['GroupAverageName']}/MNINonLinear/Results/{config['OutputfMRIName']}/tICA_d{config['sICADim']}/{feature_base_name}"
    df_group_feature=pd.read_csv(feature_path)
    
    df_group_feature_preprocessed, drop_feature_list=preprocess_data(df_group_feature)
    df_group_feature_preprocessed_final=preprocess_feature(df_group_feature)
    
    # create jsons
    # create_jsons(drop_feature_list, df_group_feature_preprocessed)
    
    # compare the raw setting and current setting to keep and drop features
    # Sort the columns in both dataframes alphabetically
    df_group_feature_preprocessed = df_group_feature_preprocessed.reindex(sorted(df_group_feature_preprocessed.columns), axis=1)
    df_group_feature_preprocessed_final = df_group_feature_preprocessed_final.reindex(sorted(df_group_feature_preprocessed_final.columns), axis=1)
    
    # Compare the two dataframes
    if df_group_feature_preprocessed.equals(df_group_feature_preprocessed_final):
        print("The dataframes are equal!")
    else:
        print("The dataframes are not equal.")
    
