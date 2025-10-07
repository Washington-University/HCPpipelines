#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Mon Sep  2 16:31:37 2024

@author: brainmappers
"""

import os
import nibabel as nib
import math
import numpy as np

def wb_metric_resample_to_164k(subjects_dir,subject,hemi,surface,mesh):

    input_file = os.path.join(subjects_dir, subject,'MNINonLinear','Native','{sub}.{h}.thickness.native.shape.gii'.format(sub=subject,h=hemi))
    input_sphere = os.path.join(subjects_dir, subject,'MNINonLinear','Native','{sub}.{h}.sphere.native.surf.gii'.format(sub=subject,h=hemi))
    output_sphere = os.path.join(subjects_dir, subject,'MNINonLinear','{sub}.{h}.sphere.164k_fs_LR.surf.gii'.format(sub=subject,h=hemi))
    output_file = os.path.join(subjects_dir, subject, 'MNINonLinear','Native', 'CorrThick', '{sub}.{h}.thickness.{m}.resample.shape.gii'.format(sub=subject,h=hemi,m=mesh))
    input_surf = os.path.join(subjects_dir, subject,'T1w','Native','{sub}.{h}.{s}.native.surf.gii'.format(sub=subject,s=surface,h=hemi))
    output_surf = os.path.join(subjects_dir, subject,'MNINonLinear','{sub}.{h}.{s}.164k_fs_LR.surf.gii'.format(sub=subject,s=surface,h=hemi))
    roi_file = os.path.join(subjects_dir, subject,'MNINonLinear','Native','{sub}.{h}.roi.native.shape.gii'.format(sub=subject,h=hemi))
    command = "wb_command -metric-resample {i} {ins} {os} ADAP_BARY_AREA {o} -area-surfs {insurf} {outsurf} -current-roi {roi}".format(i=input_file,ins=input_sphere,os=output_sphere,
                                           o=output_file,insurf=input_surf,outsurf=output_surf,roi=roi_file)
    os.system(command)
        
def wb_surf_resample_to_164k(subjects_dir,subject,hemi,surface,mesh):
    
    input_file = os.path.join(subjects_dir, subject,'T1w','Native','{sub}.{h}.{s}.native.surf.gii'.format(sub=subject,s=surface,h=hemi))
    input_sphere = os.path.join(subjects_dir, subject,'MNINonLinear','Native','{sub}.{h}.sphere.native.surf.gii'.format(sub=subject,h=hemi))
    output_sphere = os.path.join(subjects_dir, subject,'MNINonLinear','{sub}.{h}.sphere.164k_fs_LR.surf.gii'.format(sub=subject,h=hemi))
    output_file = os.path.join(subjects_dir, subject, 'MNINonLinear','Native', 'CorrThick', '{sub}.{h}.{s}.{m}.resample.surf.gii'.format(sub=subject,h=hemi,s=surface,m=mesh))
    command = "wb_command -surface-resample {i} {ins} {os} BARYCENTRIC {o}".format(i=input_file,ins=input_sphere,os=output_sphere,
                                           o=output_file)
    os.system(command)   
    
def wb_taubin(subjects_dir,subject,hemi,surface,mesh,iteration):

    output_file = os.path.join(subjects_dir, subject, 'MNINonLinear','Native', 'CorrThick', '{sub}.{h}.{s}.{m}.func.gii'.format(sub=subject,h=hemi,s=surface,m=mesh))
    surf_file = os.path.join(subjects_dir, subject, 'MNINonLinear','Native', 'CorrThick', '{sub}.{h}.{s}.{m}.resample.surf.gii'.format(sub=subject,h=hemi,s=surface,m=mesh))
    command = "wb_command -surface-coordinates-to-metric {s} {o}".format(s=surf_file, o=output_file)
    os.system(command) 
    
    output_file1 = os.path.join(subjects_dir, subject, 'MNINonLinear','Native', 'CorrThick', '{sub}.{h}.{s}.it.{m}.func.gii'.format(sub=subject,h=hemi,s=surface,m=mesh))
    command = "wb_command -metric-smoothing {s} {o} {it} {o1} -fwhm".format(s=surf_file,o=output_file,it=iteration, o1=output_file1)
    os.system(command) 
    
    output_file2 = os.path.join(subjects_dir, subject, 'MNINonLinear','Native', 'CorrThick', '{sub}.{h}.{s}.it.it.{m}.func.gii'.format(sub=subject,h=hemi,s=surface,m=mesh))
    command = "wb_command -metric-smoothing {s} {o1} {it} {o2} -fwhm".format(s=surf_file,o1=output_file1,it=iteration,o2=output_file2)
    os.system(command) 
    
    output_file3 = os.path.join(subjects_dir, subject, 'MNINonLinear','Native', 'CorrThick', '{sub}.{h}.{s}.smooth.{m}.func.gii'.format(sub=subject,h=hemi,s=surface,m=mesh))
    command = "wb_command -metric-math 'first + (first - second)' {o3} -var first {o1} -var second {o2}".format(s=surf_file,o2=output_file2,it=iteration,o3=output_file3,o1=output_file1)
    os.system(command) 
    
    output_file4 = os.path.join(subjects_dir, subject, 'MNINonLinear','Native', 'CorrThick', '{sub}.{h}.{s}.{m}.resample.smooth.surf.gii'.format(sub=subject,h=hemi,s=surface,m=mesh))
    command = "wb_command -surface-set-coordinates {s} {o3} {o4}".format(s=surf_file,o3=output_file3,o4=output_file4)
    os.system(command) 
    
    surf_img = nib.load(output_file4)
    
    coords = surf_img.agg_data('NIFTI_INTENT_POINTSET')
    triangles = surf_img.agg_data('NIFTI_INTENT_TRIANGLE')
    x=coords[:,0]    
    y=coords[:,1]   
    z=coords[:,2]   
    a=triangles[:,0]
    b=triangles[:,1]
    c=triangles[:,2]
    
    os.remove(output_file3)
    os.remove(output_file2)
    os.remove(output_file1)
    os.remove(output_file)
    
    return  x,y,z,a,b,c

def wb_smooth(subjects_dir,subject,hemi,surface,mesh,smooth):

    curvs = ['H', 'K', 'k1', 'k2', 'C', 'SI']

    for curv in curvs:
        output_file = os.path.join(subjects_dir, subject, 'MNINonLinear','Native', 'CorrThick', '{sub}.{h}.{s}.{c}.smooth.shape.gii'.format(sub=subject,h=hemi,s=surface,c=curv))
        surf_file = os.path.join(subjects_dir, subject, 'MNINonLinear','Native', 'CorrThick', '{sub}.{h}.{s}.{m}.resample.smooth.surf.gii'.format(sub=subject,h=hemi,s=surface,m=mesh))
        input_file = os.path.join(subjects_dir, subject, 'MNINonLinear','Native', 'CorrThick', '{sub}.{h}.{s}.{c}.shape.gii'.format(sub=subject,h=hemi,s=surface,c=curv))
        command = "wb_command -metric-smoothing {s} {i} {sm} {o} -fwhm".format(s=surf_file, i=input_file, o=output_file, sm=smooth)
        os.system(command) 
        
    return 

def wb_rois(subjects_dir,subject,hemi,surface,mesh,number):
    
    surf_data = nib.load(os.path.join(subjects_dir, subject,'MNINonLinear','Native', 'CorrThick','{sub}.{h}.{s}.{m}.resample.smooth.surf.gii'.format(sub=subject,h=hemi,s=surface,m=mesh))).agg_data()
    indices = np.arange(len(surf_data[0]))
    
    vert_list_name = '{sub}.{h}.{s}.vert.{m}.asc'.format(sub=subject,h=hemi,s=surface,m=mesh)
    vert_list = os.path.join(subjects_dir, subject, 'MNINonLinear','Native', 'CorrThick', vert_list_name)
    np.savetxt(vert_list, indices, fmt='%00d', delimiter=' '' ') 
    
    #take "number" as HWHM, convert via FWHM
    sigma = number / math.sqrt(2 * math.log(2))
    limit = sigma * 3
    output_file = os.path.join(subjects_dir, subject,'MNINonLinear','Native','CorrThick','{sub}.{h}.{s}.roi.{m}.csv'.format(sub=subject,h=hemi,s=surface,n=number,m=mesh))
    surf_file = os.path.join(subjects_dir, subject,'MNINonLinear','Native','CorrThick','{sub}.{h}.{s}.{m}.resample.smooth.surf.gii'.format(sub=subject,h=hemi,s=surface,m=mesh))
    vert_file = os.path.join(subjects_dir,subject, 'MNINonLinear','Native','CorrThick','{sub}.{h}.{s}.vert.{m}.asc'.format(sub=subject,h=hemi,s=surface,m=mesh))
#    command = "wb_command -surface-geodesic-rois {s} {n} {v} {o}".format(s=surf_file, v=vert_file, o=output_file, n=number)
#    command = "wb_command  -surface-geodesic-rois {s} {n} {v} {o} -gaussian {sig}".format(s=surf_file,v=vert_file,o=output_file,n=limit,sig=sigma)
    command = "wb_command -surface-geodesic-distance-sparse-text {s} {n} {o}".format(s=surf_file,v=vert_file,o=output_file,n=limit,sig=sigma)
    os.system(command)
    
    return

def wb_metric_resample_to_native(subjects_dir,subject,hemi,surface):
    
    input_names = ['curvs', 'intercept', 'coeffs', 'normcoeffs', 'corrthickness']
    
    output_names = ['MRcorrThickness_curvs','MRcorrThickness_intercept','MRcorrThickness_coeffs','MRcorrThickness_normcoeffs', 'MRcorrThickness']
    
    for i in range(len(input_names)):
    
        # resample everything back to native space
        input_file = os.path.join(subjects_dir, subject, 'MNINonLinear','Native', 'CorrThick','{sub}.{h}.{s}.{inp}.shape.gii'.format(sub=subject,h=hemi,s=surface,inp=input_names[i]))
        input_sphere = os.path.join(subjects_dir, subject,'MNINonLinear','{sub}.{h}.sphere.164k_fs_LR.surf.gii'.format(sub=subject,h=hemi))
        output_sphere = os.path.join(subjects_dir, subject,'MNINonLinear','Native','{sub}.{h}.sphere.native.surf.gii'.format(sub=subject,h=hemi))
        output_file = os.path.join(subjects_dir, subject,'MNINonLinear','Native','{sub}.{h}.{out}.native.shape.gii'.format(sub=subject,h=hemi,s=surface,out=output_names[i]))
        input_surf = os.path.join(subjects_dir, subject,'MNINonLinear','{sub}.{h}.{s}.164k_fs_LR.surf.gii'.format(sub=subject,s=surface,h=hemi))
        output_surf = os.path.join(subjects_dir, subject,'T1w','Native','{sub}.{h}.{s}.native.surf.gii'.format(sub=subject,s=surface,h=hemi))
        command = "wb_command -metric-resample {i} {ins} {os} ADAP_BARY_AREA {o} -area-surfs {insurf} {outsurf}".format(i=input_file,ins=input_sphere,os=output_sphere,
                                               o=output_file,insurf=input_surf,outsurf=output_surf)
        os.system(command)  

def wb_set_map_names(subjects_dir,subject,hemi): 
    
    input_file = '{sub}.{h}.MRcorrThickness_curvs.native.shape.gii'.format(sub=subject,h=hemi)
    input_file = os.path.join(subjects_dir, subject, 'MNINonLinear','Native', input_file)
    command = "wb_command -set-map-names {i} -map 1 MaxPrincipalCurv -map 2 MinPrincipalCurv -map 3 GaussianCurv -map 4 ShapeIndex -map 5 Curvedness".format(i=input_file)
    os.system(command)
    
    input_file = '{sub}.{h}.MRcorrThickness_coeffs.native.shape.gii'.format(sub=subject,h=hemi)
    input_file = os.path.join(subjects_dir, subject, 'MNINonLinear','Native', input_file)
    command = "wb_command -set-map-names {i} -map 1 MaxPrincipalCurv -map 2 MaxPrincipalCurv^2 -map 3 MinPrincipalCurv -map 4 MinPrincipalCurv^2 -map 5 GaussianCurv -map 6 GaussianCurv^2 -map 7 ShapeIndex -map 8 ShapeIndex^2 -map 9 Curvedness -map 10 Curvedness^2".format(i=input_file)
    os.system(command)
    
    input_file = '{sub}.{h}.MRcorrThickness_normcoeffs.native.shape.gii'.format(sub=subject,h=hemi)
    input_file = os.path.join(subjects_dir, subject, 'MNINonLinear','Native', input_file)
    command = "wb_command -set-map-names {i} -map 1 NormMaxPrincipalCurv -map 2 NormMaxPrincipalCurv^2 -map 3 NormMinPrincipalCurv -map 4 NormMinPrincipalCurv^2 -map 5 NormGaussianCurv -map 6 NormGaussianCurv^2 -map 7 NormShapeIndex -map 8 NormShapeIndex^2 -map 9 NormCurvedness -map 10 NormCurvedness^2".format(i=input_file)
    os.system(command)
    
    input_file = '{sub}.{h}.MRcorrThickness_intercept.native.shape.gii'.format(sub=subject,h=hemi)
    input_file = os.path.join(subjects_dir, subject, 'MNINonLinear','Native', input_file)
    command = "wb_command -set-map-names {i} -map 1 {sub}_MRcorrThickness_intercept".format(i=input_file,sub=subject)
    os.system(command)
    
    input_file = '{sub}.{h}.MRcorrThickness.native.shape.gii'.format(sub=subject,h=hemi)
    input_file = os.path.join(subjects_dir, subject, 'MNINonLinear','Native', input_file)
    command = "wb_command -set-map-names {i} -map 1 {sub}_MRcorrThickness".format(i=input_file,sub=subject)
    os.system(command)

def wb_structure(subjects_dir,subject,hemi,surface,structure):
    
    curvs = ['H', 'K', 'k1', 'k2', 'C', 'SI']

    for curv in curvs:
        input_file = os.path.join(subjects_dir, subject, 'MNINonLinear','Native', 'CorrThick','{sub}.{h}.{s}.{c}.smooth.shape.gii'.format(sub=subject,h=hemi,s=surface,c=curv))
        command = "wb_command -set-structure {i} {s}".format(s=structure, i=input_file)
        os.system(command) 
        input_file = os.path.join(subjects_dir, subject, 'MNINonLinear','Native', 'CorrThick','{sub}.{h}.{s}.{c}.shape.gii'.format(sub=subject,h=hemi,s=surface,c=curv))
        command = "wb_command -set-structure {i} {s}".format(s=structure, i=input_file)
        os.system(command)
        
    names = ['MRcorrThickness_curvs','MRcorrThickness_intercept','MRcorrThickness_coeffs','MRcorrThickness_normcoeffs', 'MRcorrThickness']
    
    for name in names:
        input_file = os.path.join(subjects_dir, subject, 'MNINonLinear','Native','{sub}.{h}.{inp}.native.shape.gii'.format(sub=subject,h=hemi,s=surface,inp=name))
        command = "wb_command -set-structure {i} {s}".format(s=structure, i=input_file)
        os.system(command)
    
    return