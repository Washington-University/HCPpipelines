#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Sun Apr 28 17:45:23 2024

@author: brainmappers
"""

def roi(subjects_dir,subject,hemi,surface,mesh,number):
    
    import os
    import numpy as np
    import math
    
    if mesh=='164k':
        m=163842
        
    #read csv file and save as lists in a list array (weights and rois-vertices)
    rois=[None]*m
    weights=[None]*m
    i=0
    roi_file = os.path.join(subjects_dir, subject, 'MNINonLinear','Native', 'CorrThick', '{sub}.{h}.{s}.roi.{m}.csv'.format(sub=subject,h=hemi,s=surface,m=mesh))
    sigma = number / math.sqrt(2 * math.log(2))
    
    with open(roi_file) as f:
        for line in f:
            l = line.split(',')
            roi = np.array([int(ele) for ele in l[::2]], dtype=np.int32)
            distance = np.array([float(ele) for ele in l[1::2]], dtype=np.float32)
            roi, distance = zip(*sorted(zip(roi, distance)))
            roi=np.array(roi)
            distance=np.array(distance)
            weight = np.exp(-0.5*((distance)/sigma)**2)
            weight = weight/np.sum(weight)
            rois[i]=roi
            weights[i]=weight
            i=i+1
            
    os.remove(roi_file)
                
    return rois, weights

