#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Tue Aug 20 11:10:05 2024

@author: brainmappers
"""

def metric_regression(subjects_dir,subject,hemi,surface,mesh,rois,weights):

    import nibabel as nib
    import numpy as np
    import os
    from concurrent.futures import ProcessPoolExecutor
    import multiprocessing
    import psutil
        
    d = {} # read all the curvature values and save them in a dictionary
    curvs = ['H', 'k1', 'k2', 'K', 'SI', 'C']

    for curv in curvs:
        d[str(curv)+'_img']= os.path.join(subjects_dir, subject,'MNINonLinear','Native','CorrThick','{sub}.{h}.{s}.{c}.smooth.shape.gii'.format(sub=subject,h=hemi,s=surface,c=curv))
        d[str(curv)+'_img'] = nib.load(d[str(curv)+'_img'])
        d[str(curv)] = d[str(curv)+'_img'].agg_data()
        
    t_img = os.path.join(subjects_dir, subject,'MNINonLinear','Native','CorrThick','{sub}.{h}.thickness.{m}.resample.shape.gii'.format(sub=subject,h=hemi,m=mesh))
    t_img = nib.load(t_img)
    t = t_img.agg_data()
    
    d['t'] = t # Add thickness to dictionary
    
    #merge curvatures 
    curv=np.zeros([163842, 5])
    
    for i in range(len(curvs)-1):
        curv[:,i]=nib.load(os.path.join(subjects_dir, subject, 'MNINonLinear','Native', 'CorrThick','{sub}.{h}.{s}.{c}.smooth.shape.gii'.format(sub=subject,h=hemi,s=surface,c=curvs[i+1]))).agg_data()
    
    for i in range(len(t)):
        if t[i] == 0:
            curv[i,:]=0
        
    # Save merged curv in gifti 
    curv = np.float32(curv) #gifti supports float32 only
    data = nib.gifti.gifti.GiftiImage()
    data.add_gifti_data_array(nib.gifti.gifti.GiftiDataArray(curv))
    curv_name = '{sub}.{h}.{s}.curvs.shape.gii'.format(sub=subject,h=hemi,s=surface)
    curv_name = os.path.join(subjects_dir, subject, 'MNINonLinear','Native','CorrThick',curv_name)
    nib.save(data, curv_name)
    
    for i in range(len(d['t'])):
        if d['t'][i] == 0:
            d['H'][i] = 0
            d['K'][i] = 0
            d['C'][i] = 0
            d['SI'][i] = 0
            d['k1'][i] = 0
            d['k2'][i] = 0
    
    # Demean curvature data - calculate the means first
    mean_H = np.mean(d['H'][d['H'] != 0])
    mean_K = np.mean(d['K'][d['K'] != 0])
    mean_C = np.mean(d['C'][d['C'] != 0])
    mean_SI = np.mean(d['SI'][d['SI'] != 0])
    mean_k1 = np.mean(d['k1'][d['k1'] != 0])
    mean_k2 = np.mean(d['k2'][d['k2'] != 0])
    
    for i in range(len(d['t'])):
        if d['t'][i] != 0:
            d['H'][i] = d['H'][i] - mean_H
            d['K'][i] = d['K'][i] - mean_K
            d['C'][i] = d['C'][i] - mean_C
            d['SI'][i] = d['SI'][i] - mean_SI
            d['k1'][i] = d['k1'][i] - mean_k1
            d['k2'][i] = d['k2'][i] - mean_k2
            
    #add squared curvatures to the dictionary
    d['H2'] = d['H']*d['H']
    d['K2'] = d['K']*d['K']
    d['C2'] = d['C']*d['C']
    d['SI2'] = d['SI']*d['SI']
    d['k12'] = d['k1']*d['k1']
    d['k22'] = d['k2']*d['k2']
    
    mean_H2 = np.mean(d['H2'][d['H2'] != 0])
    mean_K2 = np.mean(d['K2'][d['K2'] != 0])
    mean_C2 = np.mean(d['C2'][d['C2'] != 0])
    mean_SI2 = np.mean(d['SI2'][d['SI2'] != 0])
    mean_k12 = np.mean(d['k12'][d['k12'] != 0])
    mean_k22 = np.mean(d['k22'][d['k22'] != 0])
    
    #demean squared curvatures
    for i in range(len(d['t'])):
        if d['t'][i] != 0:
            d['H2'][i] = d['H2'][i] - mean_H2
            d['K2'][i] = d['K2'][i] - mean_K2
            d['C2'][i] = d['C2'][i] - mean_C2
            d['SI2'][i] = d['SI2'][i] - mean_SI2
            d['k12'][i] = d['k12'][i] - mean_k12
            d['k22'][i] = d['k22'][i] - mean_k22
            
    ###############################################################################   
    # parallelize roi regression
    max_workers = psutil.cpu_count(logical=False)
    with ProcessPoolExecutor(max_workers=max_workers,mp_context=multiprocessing.get_context("fork")) as executor:
        results = list(executor.map(process_roi, [(j, rois[j], weights[j], d) for j in range(len(rois)) if d['t'][j] != 0], chunksize=10000))
    
    coeff, coeff_norm, t_corr = zip(*results)  # Unzip results into separate lists
    t_corr = np.array(t_corr)
    coeff = np.array(coeff)
    coeff_norm = np.array(coeff_norm)
    
    row_to_be_added = np.array([0,0,0,0,0,0,0,0,0,0,0])
    
    for i in range(len(d['t'])):
        if d['t'][i] == 0:
            coeff = np.insert(coeff, i, row_to_be_added, axis=0)
            
    intercept = np.array(coeff[:, -1])
    coeff = np.delete(coeff, np.s_[-1:], axis=1)
    
    row_to_be_added = np.array([0,0,0,0,0,0,0,0,0,0])
    
    for i in range(len(d['t'])):
        if d['t'][i] == 0:
            coeff_norm = np.insert(coeff_norm, i, row_to_be_added, axis=0)
        
    for i in range(len(d['t'])):
        if d['t'][i] == 0:
            t_corr = np.insert(t_corr,i,0)
            
    for j in range(len(t_corr)):
        if t_corr[j]<0:
            t_corr[j]=0
      
    # Save t_corr in gifti
    t_corr = np.float32(t_corr) #gifti supports float32 only
    data = nib.gifti.gifti.GiftiImage()
    data.add_gifti_data_array(nib.gifti.gifti.GiftiDataArray(t_corr))
    Tcorr_name = os.path.join(subjects_dir,subject,'MNINonLinear','Native','CorrThick','{sub}.{h}.{s}.corrthickness.shape.gii'.format(sub=subject,h=hemi,s=surface,m=mesh))
    nib.save(data, Tcorr_name)
    
    # Save regression coeffs in gifti 
    coeff = np.float32(coeff) #gifti supports float32 only
    data = nib.gifti.gifti.GiftiImage()
    data.add_gifti_data_array(nib.gifti.gifti.GiftiDataArray(coeff))
    coeff_name = '{sub}.{h}.{s}.coeffs.shape.gii'.format(sub=subject,h=hemi,s=surface)
    coeff_name = os.path.join(subjects_dir, subject,'MNINonLinear','Native', 'CorrThick',coeff_name)
    nib.save(data, coeff_name)
    
    # Save normalized regression coeffs in gifti 
    coeff_norm = np.float32(coeff_norm) #gifti supports float32 only
    data = nib.gifti.gifti.GiftiImage()
    data.add_gifti_data_array(nib.gifti.gifti.GiftiDataArray(coeff_norm))
    coeff_name = '{sub}.{h}.{s}.normcoeffs.shape.gii'.format(sub=subject,h=hemi,s=surface)
    coeff_name = os.path.join(subjects_dir, subject,'MNINonLinear','Native', 'CorrThick',coeff_name)
    nib.save(data, coeff_name)
    
    # Save intercept in gifti 
    intercept = np.float32(intercept) #gifti supports float32 only
    data = nib.gifti.gifti.GiftiImage()
    data.add_gifti_data_array(nib.gifti.gifti.GiftiDataArray(intercept))
    intercept_name = '{sub}.{h}.{s}.intercept.shape.gii'.format(sub=subject,h=hemi,s=surface)
    intercept_name = os.path.join(subjects_dir, subject,'MNINonLinear','Native', 'CorrThick',intercept_name)
    nib.save(data, intercept_name)
    
    return

def process_roi(args):
    
    import numpy as np
    import scipy.stats as stats
    import os
    
    j=args[0]
    region=args[1]
    weight=args[2]
    d=args[3]
    
    H = np.zeros(len(region))
    K = np.zeros(len(region))
    C = np.zeros(len(region))
    SI = np.zeros(len(region))
    k1 = np.zeros(len(region))
    k2 = np.zeros(len(region))
    t = np.zeros(len(region))
    H2 = np.zeros(len(region))
    K2 = np.zeros(len(region))
    C2 = np.zeros(len(region))
    SI2 = np.zeros(len(region))
    k12 = np.zeros(len(region))
    k22 = np.zeros(len(region))

    t_m = []
    idx = []
    curv_matrix = []
    curv_matrix_nonzero = []
    t_nonzero = []

    for i in range(len(region)):
        H[i] = d['H'][region[i]]
        K[i] = d['K'][region[i]]
        C[i] = d['C'][region[i]]
        SI[i] = d['SI'][region[i]]
        k1[i] = d['k1'][region[i]]
        k2[i] = d['k2'][region[i]]
        t[i] = d['t'][region[i]]
        H2[i] = d['H2'][region[i]]
        K2[i] = d['K2'][region[i]]
        C2[i] = d['C2'][region[i]]
        SI2[i] = d['SI2'][region[i]]
        k12[i] = d['k12'][region[i]]
        k22[i] = d['k22'][region[i]]

    curv_matrix = np.array([k1, k12, k2, k22, K, K2, SI, SI2, C, C2], dtype=float)
    for i in range(len(curv_matrix)):
        curv_matrix[i] = curv_matrix[i] * np.sqrt(weight)

    idx = np.argwhere(np.all(curv_matrix[..., :] == 0, axis=0))
    curv_matrix_nonzero = np.delete(curv_matrix, idx, axis=1)
    t_w = t * np.sqrt(weight)
    ones = np.ones(len(t_w)) * np.sqrt(weight)

    for i in range(len(t_w)):
        if t_w[i] == 0:
            ones[i] = 0

    t_nonzero = t_w[t_w != 0]
    ones = ones[ones != 0]
    curv_matrix_nonzero = np.vstack((curv_matrix_nonzero, ones))
    with threadpool_limits(limits=1, user_api='blas'):
        coeff = np.matmul(np.linalg.inv(np.matmul(curv_matrix_nonzero, np.transpose(curv_matrix_nonzero))), np.matmul(curv_matrix_nonzero, t_nonzero))
    curv_matrix = np.array([k1, k12, k2, k22, K, K2, SI, SI2, C, C2], dtype=float)
    coeff_norm = coeff[0:(len(coeff) - 1)] * stats.median_abs_deviation(curv_matrix, axis=1)
    with threadpool_limits(limits=1, user_api='blas'):
        t_m = t - np.matmul(coeff[0:len(coeff) - 1], curv_matrix)
    index = np.where(region == j)
    t_corr = float(t_m[index])
    
    return coeff, coeff_norm, t_corr
