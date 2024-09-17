#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Tue Aug 20 14:44:13 2024

@author: brainmappers
"""
import sys

subjects_dir=str(sys.argv[1])
subject=str(sys.argv[2])
structure=str(sys.argv[3])
hemi=str(sys.argv[4])
surface=str(sys.argv[5])
number=float(sys.argv[6])
iteration=str(sys.argv[7])
smooth=str(sys.argv[8])

import neighbor_info
import curvature
import metric_regression
import roi
import wb

################################################################################
mesh='164k'
wb.wb_metric_resample_to_164k(subjects_dir,subject,hemi,surface,mesh) 
wb.wb_surf_resample_to_164k(subjects_dir,subject,hemi,surface,mesh) 
x,y,z,a,b,c = wb.wb_taubin(subjects_dir,subject,hemi,surface,mesh,iteration)
neighbor_info.neighbor_info(a,b,c,x,y,z,subjects_dir,subject,hemi,surface,mesh)
curvature.Gaussian_curvature(x,y,z,subjects_dir,subject,hemi,surface)
curvature.mean_curvature(x,y,z,subjects_dir,subject,hemi,surface)
curvature.k1_k2_SI(x,y,z,subjects_dir,subject,hemi,surface)
wb.wb_smooth(subjects_dir,subject,hemi,surface,mesh,smooth)
wb.wb_rois(subjects_dir,subject,hemi,surface,mesh,number)
rois,weights=roi.roi(subjects_dir,subject,hemi,surface,mesh,number)
metric_regression.metric_regression(subjects_dir,subject,hemi,surface,mesh,rois,weights) 
wb.wb_metric_resample_to_native(subjects_dir,subject,hemi,surface,mesh) 
wb.wb_structure(subjects_dir,subject,hemi,surface,mesh,structure)
wb.wb_set_map_names(subjects_dir,subject,hemi,surface,mesh)


