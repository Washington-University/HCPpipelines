#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Thu Sep  5 14:07:38 2024

This script was originally developed as part of Nagehan Demirci's Ph.D. thesis under the copyright CC-BY-NC-SA-4.0 at the University of Notre Dame in the CoMMaND lab under the supervision of Maria Holland. If you use this script in your work, please give proper attribution and citation:
 
Demirci, N., & Holland, M. A. (2022). Cortical thickness systematically varies with curvature and depth in healthy human brains. Human Brain Mapping, 43(6), 2064–2084. https://doi.org/10.1002/hbm.25776

Author(s): 
Nagehan Demirci, Department of Radiology, Washington University in St. Louis
Maria Holland, Department of Aerospace and Mechanical Engineering, University of Notre Dame

"""
import numpy as np
import os
import nibabel as nib
import math

def Gaussian_curvature(x,y,z,subjects_dir,subject,hemi,surface):

    input_ndl = '{sub}.{h}.{s}.neighbor.asc'.format(sub=subject,h=hemi,s=surface) #Read the neighbor .asc file
    ndl_file = os.path.join(subjects_dir, subject, 'MNINonLinear','Native', 'CorrThick', input_ndl)
    ndl = np.loadtxt(ndl_file)
    nb = np.zeros(len(x)) # max number of neighbor for each vertex
    for i in range(len(x)):
        for j in range(3, len(ndl[0])):
            if ndl[i, 2] == ndl[i, j]:
                nb[i] = j
                break
    max_nb = int(max(nb))
    
    skip_vertex = np.array([]) # Check for bad vertices due to bad connectivity of the mesh at that vertex
    for i in range(len(ndl)):
        le = int(nb[i]-2)
        if ndl[i, le+1] != ndl[i, 1] or nb[i] <= 3:
            skip_vertex = np.append(skip_vertex, i) 
    
    dist_from_vertex = np.zeros((len(x), max_nb)) # Euclidean distance of each neighbor from the main vertex
    for i in range(len(ndl)): 
        nd = ndl[i]
        le = int(nb[i]-2)
        dist_from_vertex[i,0] = i
        for j in range(1, le+1):
            index = int(nd[j])
            dist_from_vertex[i,j] = np.sqrt((x[i] - x[index])**2 + (y[i] - y[index])**2 + (z[i] - z[index])**2)
        dist_from_vertex[i,j+1] = dist_from_vertex[i,1]
    
    ############## Sum of internal angles #################
    theta = np.zeros((len(x), max_nb)) # Internal angles for each triangle connecting at a specific vertex
    param = np.zeros((len(x), max_nb)) # Semi-parameter of each triangle
    parea = np.zeros((len(x), max_nb)) # Area of each triangle, patch area
        
    for h in range(len(x)): 
        if h in skip_vertex: 
            continue
        nd = ndl[h]
        le = int(nb[h]-2)
        for j in range(1,le+1):
            k = dist_from_vertex[h, j]
            l = dist_from_vertex[h, j + 1]
            ind1 = int(nd[j])
            ind2 = int(nd[j + 1])
            m = np.sqrt((x[ind1] - x[ind2])**2 + (y[ind1] - y[ind2])**2 + (z[ind1] - z[ind2])**2)
            theta[h,j-1] = np.arccos((k**2 + l**2 - m**2)/(2*k*l))
            param[h,j-1] = (k + l + m)/2
            parea[h,j-1] = np.sqrt(param[h,j-1]*(param[h,j-1]-l)*(param[h,j-1]-k)*(param[h,j-1]-m))
    
    theta_sum = np.zeros(len(x)) # Sum of internal angles of each triangle meeting at each vertex
    K_gb = np.zeros(len(x)) # Sum of angle excess or defect
    a_sum = np.zeros(len(x)) #Sum of area of triangles meeting at each vertex
    
    for i in range(len(x)):
        theta_sum[i] = sum(theta[i,:])
        a_sum[i] = sum(parea[i,:])
        K_gb[i] = 2*np.pi - theta_sum[i]
        
    # Check if there are any zero areas due to mesh and/or connectivity and set a low but not zero value
    for i in range(len(a_sum)):
        if a_sum[i] == 0:
            a_sum[i] = 0.001
    K = K_gb/(a_sum/3) # This is the final Gaussian curvature
    for i in range(len(K)):
        if K[i] > 1000: # a very large number due to bad vertices with bad connectivity
            K[i] = 0
     
    # Save gifti
    K = np.float32(K) #gifti supports float32 only
    data = nib.gifti.gifti.GiftiImage()
    data.add_gifti_data_array(nib.gifti.gifti.GiftiDataArray(K))
    K_name = '{sub}.{h}.{s}.K.shape.gii'.format(sub=subject,h=hemi,s=surface)
    K_name = os.path.join(subjects_dir, subject, 'MNINonLinear','Native', 'CorrThick', K_name)
    nib.save(data, K_name)
    
    a_sum = np.float32(a_sum) #gifti supports float32 only
    data = nib.gifti.gifti.GiftiImage()
    data.add_gifti_data_array(nib.gifti.gifti.GiftiDataArray(a_sum))
    a_name = '{sub}.{h}.{s}.area.shape.gii'.format(sub=subject,h=hemi,s=surface)
    a_name = os.path.join(subjects_dir, subject, 'MNINonLinear','Native', 'CorrThick', a_name)
    nib.save(data, a_name)
    
    return 

def mean_curvature(x,y,z,subjects_dir,subject,hemi,surface):
    
    input_ndl = '{sub}.{h}.{s}.neighbor.asc'.format(sub=subject,h=hemi,s=surface) #Read the neighbor .asc file
    ndl_file = os.path.join(subjects_dir, subject, 'MNINonLinear','Native', 'CorrThick', input_ndl)
    ndl = np.loadtxt(ndl_file)
    nb = np.zeros(len(ndl)) # max number of neighbor for each vertex
    for i in range(len(ndl)):
        for j in range(3,len(ndl[0])):
            if ndl[i, 2] == ndl[i, j]:
                nb[i] = j
                break
    max_nb = int(max(nb))
    
    skip_vertex = np.array([]) # Check for bad vertices due to bad connectivity of the mesh at that vertex
    for i in range(len(ndl)):
        le = int(nb[i]-2)
        if ndl[i, le+1] != ndl[i, 1] or nb[i] <= 3:
            skip_vertex = np.append(skip_vertex, i) 
    ###################################################################
    h_tri = np.zeros((len(x), max_nb))
    for h in range(len(x)):
        if h in skip_vertex: # skip the bad vertices with bad connectivity
            continue
        le = int(nb[h] + 1)
        k = np.array(ndl[h, :le])
        j=1
        for i in k:
            if j==le-2:
                break
            p2 = np.array([x[int(h)], y[int(h)], z[int(h)]]) #Vertex in consideration
            ind1 = int(k[j])
            ind2 = int(k[j+1])
            ind3 = int(k[j+2])
            p1 = np.array([x[ind1], y[ind1], z[ind1]])
            p3 = np.array([x[ind2], y[ind2], z[ind2]])
            p4 = np.array([x[ind3], y[ind3], z[ind3]])
            q1 = np.subtract(p2,p1)
            q2 = np.subtract(p3,p2)
            q3 = np.subtract(p4,p3)
            q1_x_q2 = np.cross(q1,q2)
            q2_x_q3 = np.cross(q2,q3)
            n1 = q1_x_q2/np.sqrt(np.dot(q1_x_q2,q1_x_q2))
            n2 = q2_x_q3/np.sqrt(np.dot(q2_x_q3,q2_x_q3))
            n2 = -n2
            u1 = n2
            u3 = q2/(np.sqrt(np.dot(q2,q2)))
            u2 = np.cross(u3,u1)
            cost = np.dot(n1, u1)
            sint = np.dot(n1, u2)
            theta = -math.atan2(sint,cost)
            edge = np.sqrt((x[int(h)] - x[ind2])**2 + (y[int(h)] - y[ind2])**2 + (z[int(h)] - z[ind2])**2)
            h_tri[h, j] = theta*edge
            j = j + 1
    H_sum = np.zeros(len(x))
    for i in range(len(x)):
        H_sum[i] = sum(h_tri[i,:])   

    # read the area file
    a_name = '{sub}.{h}.{s}.area.shape.gii'.format(sub=subject,h=hemi,s=surface)
    a_name = os.path.join(subjects_dir, subject, 'MNINonLinear','Native', 'CorrThick', a_name)
    a_sum = nib.load(a_name)
    a_sum = a_sum.agg_data()
    H = H_sum/4/(a_sum/3) # This is the final mean curvature
    
    # Save gifti
    H = np.float32(H) #gifti supports float32 only
    data = nib.gifti.gifti.GiftiImage()
    data.add_gifti_data_array(nib.gifti.gifti.GiftiDataArray(H))
    H_name = '{sub}.{h}.{s}.H.shape.gii'.format(sub=subject,h=hemi,s=surface)
    H_name = os.path.join(subjects_dir, subject, 'MNINonLinear','Native', 'CorrThick', H_name)
    nib.save(data, H_name)
    
    return 

def k1_k2_SI(x,y,z,subjects_dir,subject,hemi,surface):
        
    # read H and K 
    H_name = '{sub}.{h}.{s}.H.shape.gii'.format(sub=subject,h=hemi,s=surface)
    H_name = os.path.join(subjects_dir, subject, 'MNINonLinear','Native', 'CorrThick', H_name)
    H = nib.load(H_name)
    h = H.agg_data()

    K_name = '{sub}.{h}.{s}.K.shape.gii'.format(sub=subject,h=hemi,s=surface)
    K_name = os.path.join(subjects_dir, subject, 'MNINonLinear','Native', 'CorrThick', K_name)
    K = nib.load(K_name)
    k = K.agg_data()
              
    k1 = np.zeros(len(h))
    k2 = np.zeros(len(h))
    SI = np.zeros(len(h))
    C = np.zeros(len(h))
              
    for i in range(len(h)):
        sqrt_term = h[i] ** 2 - k[i] # calculate principal curvatures       
        if sqrt_term < 0:
            sqrt_term = 0
        try: 
            k1[i] = h[i] + np.sqrt(sqrt_term)
            k2[i] = h[i] - np.sqrt(sqrt_term)
        except Warning: 
            print('Warning: calculating principal curvatures from', i, h[i], k[i])
            
        C[i]= np.sqrt((k1[i]*k1[i] + k2[i]*k2[i])/2) # calculate curvedness 
        
        denom_term = k2[i] - k1[i] # calculate shape index
        if denom_term == 0: 
            SI[i] = 0
        else: 
            try: 
                SI[i] = 2 * np.arctan((k2[i] + k1[i])/denom_term)/np.pi  
            except Warning: 
                print ('Warning: calculating shape index from principal curvatures', k1[i], k2[i])
                
    # Save k1 in gifti 
    k1 = np.float32(k1) #gifti supports float32 only
    data = nib.gifti.gifti.GiftiImage()
    data.add_gifti_data_array(nib.gifti.gifti.GiftiDataArray(k1))
    k1_name = '{sub}.{h}.{s}.k1.shape.gii'.format(sub=subject,h=hemi,s=surface)
    k1_name = os.path.join(subjects_dir, subject, 'MNINonLinear','Native', 'CorrThick', k1_name)
    nib.save(data, k1_name)
    
    # Save k2 in gifti 
    k2 = np.float32(k2) #gifti supports float32 only
    data = nib.gifti.gifti.GiftiImage()
    data.add_gifti_data_array(nib.gifti.gifti.GiftiDataArray(k2))
    k2_name = '{sub}.{h}.{s}.k2.shape.gii'.format(sub=subject,h=hemi,s=surface)
    k2_name = os.path.join(subjects_dir, subject, 'MNINonLinear','Native', 'CorrThick', k2_name)
    nib.save(data, k2_name)
    
    # Save SI in gifti 
    SI = np.float32(SI) #gifti supports float32 only
    data = nib.gifti.gifti.GiftiImage()
    data.add_gifti_data_array(nib.gifti.gifti.GiftiDataArray(SI))
    SI_name = '{sub}.{h}.{s}.SI.shape.gii'.format(sub=subject,h=hemi,s=surface)
    SI_name = os.path.join(subjects_dir, subject, 'MNINonLinear','Native', 'CorrThick', SI_name)
    nib.save(data, SI_name)
    
    # Save C in gifti 
    C = np.float32(C) #gifti supports float32 only
    data = nib.gifti.gifti.GiftiImage()
    data.add_gifti_data_array(nib.gifti.gifti.GiftiDataArray(C))
    C_name = '{sub}.{h}.{s}.C.shape.gii'.format(sub=subject,h=hemi,s=surface)
    C_name = os.path.join(subjects_dir, subject, 'MNINonLinear','Native', 'CorrThick', C_name)
    nib.save(data, C_name)
    
    return 

       