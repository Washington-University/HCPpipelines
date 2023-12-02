StudyFolder="${1}"
Subject="${2}"
fMRIName="${3}"
CorticalLUT="${4}"
SubCorticalLUT="${5}"
Caret7_Command="${6}"
LowResMesh="${7}"
RegNames="${8}"
SmoothingFWHM="${9}"
FinalfMRIResolution="${10}"
BrainOrdinatesResolution="${11}"
Inputs="${12}" 
Outputs="${13}"
Names="${14}"
Flag="${15}" #FALSE=Don't fix zeros, TRUE=Fix zeros
DeleteIntermediates="${16}" #TRUE/FALSE
VolExT="${17}"
WorkingDir="${18}"

Sigma=`echo "$SmoothingFWHM / ( 2 * ( sqrt ( 2 * l ( 2 ) ) ) )" | bc -l`

RegNames=`echo ${RegNames} | sed 's/@/ /g'`

Inputs=`echo ${Inputs} | sed 's/@/ /g'`
Outputs=`echo ${Outputs} | sed 's/@/ /g'`
Names=`echo ${Names} | sed 's/@/ /g'`


AtlasFolder="${StudyFolder}/${Subject}/MNINonLinear"
AtlasAtlasResultsFolder="${AtlasFolder}/Results/${fMRIName}"
NativeFolder="${AtlasFolder}/Native"
DownsampleFolder="${AtlasFolder}/fsaverage_LR${LowResMesh}k"
ROIFolder="${AtlasFolder}/ROIs"

if [ ${WorkingDir} = "NONE" ] ; then
  WorkingDir="${AtlasAtlasResultsFolder}"
fi

  i=1
  for File in ${Names} ; do
    Input=`echo ${Inputs} | cut -d " " -f ${i}`
    Output=`echo ${Outputs} | cut -d " " -f ${i}`
    cp ${Input} ${WorkingDir}/${fMRIName}_${File}.${VolExT}

    roiVolume="${AtlasAtlasResultsFolder}/RibbonVolumeToSurfaceMapping/goodvoxels.nii.gz"
    if [ ! ${Flag} = "FALSE" ] ; then
      ResampleFlag="-fix-zeros"
      VolROI="-volume-roi $roiVolume"
    else
      ResampleFlag=""
      VolROI=""
    fi
        
    unset POSIXLY_CORRECT
    if [ 1 -eq `echo "$BrainOrdinatesResolution == $FinalfMRIResolution" | bc -l` ] ; then
	    #If using the same fMRI and grayordinates space resolution, use the simple algorithm to project bias field into subcortical CIFTI space like fMRI
	    volumeIn="${WorkingDir}/${fMRIName}_${File}.${VolExT}"
	    currentParcel="${ROIFolder}/ROIs.${BrainOrdinatesResolution}.nii.gz"
	    newParcel="${ROIFolder}/Atlas_ROIs.${BrainOrdinatesResolution}.nii.gz"
	    kernel="${Sigma}"
	    volumeOut="${WorkingDir}/${File}_AtlasSubcortical.${VolExT}"
	    $Caret7_Command -volume-parcel-resampling $volumeIn $currentParcel $newParcel $kernel $volumeOut ${ResampleFlag}
    else
	    #If using different fMRI and grayordinates space resolutions, use the generic algorithm to project bias field into subcortical CIFTI space like fMRI
	    volumeIn="${WorkingDir}/${fMRIName}_${File}.${VolExT}"
	    currentParcel="${ROIFolder}/ROIs.${FinalfMRIResolution}.nii.gz"
	    newParcel="${ROIFolder}/Atlas_ROIs.${BrainOrdinatesResolution}.nii.gz"
	    kernel="${Sigma}"
	    volumeOut="${WorkingDir}/${File}_AtlasSubcortical.${VolExT}"
	    $Caret7_Command -volume-parcel-resampling-generic $volumeIn $currentParcel $newParcel $kernel $volumeOut ${ResampleFlag}
    fi 
     

##generate subject-roi space fMRI cifti for subcortical
#if [[ `echo "$BrainOrdinatesResolution == $FinalfMRIResolution" | bc -l | cut -f1 -d.` == "1" ]]
#then
#    log_Msg "Creating subject-roi subcortical cifti at same resolution as output"
#    $Caret7_Command -cifti-create-dense-timeseries ${WorkingDir}/${fMRIName}_temp_subject.dtseries.nii -volume ${WorkingDir}/${fMRIName}_${File}.${VolExT} "$ROIFolder"/ROIs."$BrainOrdinatesResolution".nii.gz
#else
#    log_Msg "Creating subject-roi subcortical cifti at differing fMRI resolution"
#    $Caret7_Command -volume-affine-resample "$ROIFolder"/ROIs."$BrainOrdinatesResolution".nii.gz $FSLDIR/etc/flirtsch/ident.mat ${WorkingDir}/${fMRIName}_${File}.${VolExT} ENCLOSING_VOXEL ${WorkingDir}/ROIs."$FinalfMRIResolution".nii.gz
#    $Caret7_Command -cifti-create-dense-timeseries ${WorkingDir}/${fMRIName}_temp_subject.dtseries.nii -volume ${WorkingDir}/${fMRIName}_${File}.${VolExT} ${WorkingDir}/ROIs."$FinalfMRIResolution".nii.gz
#    rm -f ${WorkingDir}/ROIs."$FinalfMRIResolution".nii.gz
#fi

#log_Msg "Dilating out zeros"
##dilate out any exact zeros in the input data, for instance if the brain mask is wrong. Note that the CIFTI space cannot contain zeros to produce a valid CIFTI file (dilation also occurs below).
#$Caret7_Command -cifti-dilate ${WorkingDir}/${fMRIName}_temp_subject.dtseries.nii COLUMN 0 30 ${WorkingDir}/${fMRIName}_temp_subject_dilate.dtseries.nii
#rm -f ${WorkingDir}/${fMRIName}_temp_subject.dtseries.nii

#log_Msg "Generate atlas subcortical template cifti"
#$Caret7_Command -cifti-create-label ${WorkingDir}/${fMRIName}_temp_template.dlabel.nii -volume "$ROIFolder"/Atlas_ROIs."$BrainOrdinatesResolution".nii.gz "$ROIFolder"/Atlas_ROIs."$BrainOrdinatesResolution".nii.gz

##As of wb_command 1.4.0 and later, volume predilate is much less important for reducing edge ringing, and could be reduced
#if [[ `echo "${Sigma} > 0" | bc -l | cut -f1 -d.` == "1" ]]
#then
#    log_Msg "Smoothing and resampling"
#    #this is the whole timeseries, so don't overwrite, in order to allow on-disk writing, then delete temporary
#    $Caret7_Command -cifti-smoothing ${WorkingDir}/${fMRIName}_temp_subject_dilate.dtseries.nii 0 ${Sigma} COLUMN ${WorkingDir}/${fMRIName}_temp_subject_smooth.dtseries.nii -fix-zeros-volume
#    #resample, delete temporary
#    $Caret7_Command -cifti-resample ${WorkingDir}/${fMRIName}_temp_subject_smooth.dtseries.nii COLUMN ${WorkingDir}/${fMRIName}_temp_template.dlabel.nii COLUMN ADAP_BARY_AREA CUBIC ${WorkingDir}/${fMRIName}_temp_atlas.dtseries.nii -volume-predilate 10
#    rm -f ${WorkingDir}/${fMRIName}_temp_subject_smooth.dtseries.nii
#else
#    log_Msg "Resampling"
#    $Caret7_Command -cifti-resample ${WorkingDir}/${fMRIName}_temp_subject_dilate.dtseries.nii COLUMN ${WorkingDir}/${fMRIName}_temp_template.dlabel.nii COLUMN ADAP_BARY_AREA CUBIC ${WorkingDir}/${fMRIName}_temp_atlas.dtseries.nii -volume-predilate 10
#fi

##delete common temporaries
#rm -f ${WorkingDir}/${fMRIName}_temp_subject_dilate.dtseries.nii
#rm -f ${WorkingDir}/${fMRIName}_temp_template.dlabel.nii

##the standard space output cifti must not contain zeros (or correlation, ICA, variance normalization, etc will break), so dilate in case freesurfer was unable to segment something (may only be applicable for bad quality structurals)
##NOTE: wb_command v1.4.0 and later should only output exact 0s past the edge of predilate, so this works as desired
##earlier verions of wb_command may produce undesired results in the subjects that need this dilation
#$Caret7_Command -cifti-dilate ${WorkingDir}/${fMRIName}_temp_atlas.dtseries.nii COLUMN 0 30 ${WorkingDir}/${fMRIName}_temp_atlas_dilate.dtseries.nii
#rm -f ${WorkingDir}/${fMRIName}_temp_atlas.dtseries.nii

##write output volume, delete temporary
##NOTE: $VolumefMRI contains a path in it, it is not a file in the current directory
#$Caret7_Command -cifti-separate ${WorkingDir}/${fMRIName}_temp_atlas_dilate.dtseries.nii COLUMN -volume-all ${WorkingDir}/${File}_AtlasSubcortical.${VolExT}
#rm -f ${WorkingDir}/${fMRIName}_temp_atlas_dilate.dtseries.nii
#     
     
        
    for Hemisphere in L R ; do
	    #Map bias field volume to surface using the same approach as when fMRI data are projected to the surface
	    volume="${WorkingDir}/${fMRIName}_${File}.${VolExT}"
	    surface="${NativeFolder}/${Subject}.${Hemisphere}.midthickness.native.surf.gii"
	    metricOut="${WorkingDir}/${File}.${Hemisphere}.native.func.gii"
	    ribbonInner="${NativeFolder}/${Subject}.${Hemisphere}.white.native.surf.gii"
	    ribbonOutter="${NativeFolder}/${Subject}.${Hemisphere}.pial.native.surf.gii"
	    $Caret7_Command -volume-to-surface-mapping $volume $surface $metricOut -ribbon-constrained $ribbonInner $ribbonOutter ${VolROI}

      if [ ! ${Flag} = "FALSE" ] ; then
         #Fill in any small holes with dilation again as is done with fMRI
	       metric="${WorkingDir}/${File}.${Hemisphere}.native.func.gii"
	       surface="${NativeFolder}/${Subject}.${Hemisphere}.midthickness.native.surf.gii"
	       distance="30"
	       metricOut="${WorkingDir}/${File}.${Hemisphere}.native.func.gii"
	       $Caret7_Command -metric-dilate $metric $surface $distance $metricOut -nearest
      fi
      
      #Mask out the medial wall of dilated file
	    metric="${WorkingDir}/${File}.${Hemisphere}.native.func.gii"
	    mask="${NativeFolder}/${Subject}.${Hemisphere}.roi.native.shape.gii"
	    metricOut="${WorkingDir}/${File}.${Hemisphere}.native.func.gii"
	    $Caret7_Command -metric-mask $metric $mask $metricOut
	    for RegName in ${RegNames} ; do
  	    if [ ! ${RegName} = "NONE" ] ; then
          RegString="_${RegName}"
        else
          RegString=""
          RegName="MSMSulc"
        fi
	
	      #Resample the surface data from the native mesh to the standard mesh
	      metricIn="${WorkingDir}/${File}.${Hemisphere}.native.func.gii"
	      currentSphere="${NativeFolder}/${Subject}.${Hemisphere}.sphere.${RegName}.native.surf.gii"
	      newSphere="${DownsampleFolder}/${Subject}.${Hemisphere}.sphere.${LowResMesh}k_fs_LR.surf.gii"
	      method="ADAP_BARY_AREA"
	      metricOut="${WorkingDir}/${File}${RegString}.${Hemisphere}.${LowResMesh}k_fs_LR.func.gii"
	      currentArea="${NativeFolder}/${Subject}.${Hemisphere}.midthickness.native.surf.gii"
	      newArea="${DownsampleFolder}/${Subject}.${Hemisphere}.midthickness.${LowResMesh}k_fs_LR.surf.gii"
	      roiMetric="${NativeFolder}/${Subject}.${Hemisphere}.roi.native.shape.gii"
	      $Caret7_Command -metric-resample $metricIn $currentSphere $newSphere $method $metricOut -area-surfs $currentArea $newArea -current-roi $roiMetric

        if [ ! ${Flag} = "FALSE" ] ; then
          #Fill in any small holes with dilation again as is done with fMRI
	        metric="${WorkingDir}/${File}${RegString}.${Hemisphere}.${LowResMesh}k_fs_LR.func.gii"
	        surface="${DownsampleFolder}/${Subject}.${Hemisphere}.midthickness.${LowResMesh}k_fs_LR.surf.gii"
	        distance="30"
	        metricOut="${WorkingDir}/${File}${RegString}.${Hemisphere}.${LowResMesh}k_fs_LR.func.gii"
	        $Caret7_Command -metric-dilate $metric $surface $distance $metricOut -nearest
        fi
	
	      #Make sure the medial wall is zeros
	      metric="${WorkingDir}/${File}${RegString}.${Hemisphere}.${LowResMesh}k_fs_LR.func.gii"
	      mask="${DownsampleFolder}/${Subject}.${Hemisphere}.atlasroi.${LowResMesh}k_fs_LR.shape.gii"
	      metricOut="${WorkingDir}/${File}${RegString}.${Hemisphere}.${LowResMesh}k_fs_LR.func.gii"
	      $Caret7_Command -metric-mask $metric $mask $metricOut
	
	      #Smooth the surface bias field the same as the fMRI
	      surface="${DownsampleFolder}/${Subject}.${Hemisphere}.midthickness.${LowResMesh}k_fs_LR.surf.gii"
	      metricIn="${WorkingDir}/${File}${RegString}.${Hemisphere}.${LowResMesh}k_fs_LR.func.gii"
	      smoothingKernel="${Sigma}"
	      metricOut="${WorkingDir}/${File}${RegString}.${Hemisphere}.${LowResMesh}k_fs_LR.func.gii"
	      roiMetric="${DownsampleFolder}/${Subject}.${Hemisphere}.atlasroi.${LowResMesh}k_fs_LR.shape.gii"
	      $Caret7_Command -metric-smoothing $surface $metricIn $smoothingKernel $metricOut -roi $roiMetric
      done
    done
      
	  for RegName in ${RegNames} ; do
  	  if [ ! ${RegName} = "NONE" ] ; then
        RegString="_${RegName}"
      else
        RegString=""
        RegName="MSMSulc"
      fi
      #Create CIFTI file of bias field as was done with fMRI
      ciftiOut="${WorkingDir}/${fMRIName}_Atlas${RegString}_${File}.dscalar.nii"
      volumeData="${WorkingDir}/${File}_AtlasSubcortical.${VolExT}"
      labelVolume="${ROIFolder}/Atlas_ROIs.${BrainOrdinatesResolution}.nii.gz"
      lMetric="${WorkingDir}/${File}${RegString}.L.${LowResMesh}k_fs_LR.func.gii"
      lRoiMetric="${DownsampleFolder}/${Subject}.L.atlasroi.${LowResMesh}k_fs_LR.shape.gii"
      rMetric="${WorkingDir}/${File}${RegString}.R.${LowResMesh}k_fs_LR.func.gii"
      rRoiMetric="${DownsampleFolder}/${Subject}.R.atlasroi.${LowResMesh}k_fs_LR.shape.gii"
      $Caret7_Command -cifti-create-dense-scalar $ciftiOut -volume $volumeData $labelVolume -left-metric $lMetric -roi-left $lRoiMetric -right-metric $rMetric -roi-right $rRoiMetric

      #Set Palette in CIFTI dscalar
      #ciftiIn="${WorkingDir}/${fMRIName}_Atlas${RegString}_${File}.dscalar.nii"
      #mode="MODE_AUTO_SCALE_PERCENTAGE"
      #ciftiOut="${WorkingDir}/${fMRIName}_Atlas${RegString}_${File}.dscalar.nii"
      #$Caret7_Command -cifti-palette $ciftiIn $mode $ciftiOut -pos-percent 4 96 -neg-percent 4 96 -interpolate true -disp-pos true -disp-neg true -disp-zero true -palette-name videen_style
      
      if [ ! ${ResampleFlag} = "" ] ; then
        $Caret7_Command -cifti-dilate ${WorkingDir}/${fMRIName}_Atlas${RegString}_${File}.dscalar.nii COLUMN 10 10 ${WorkingDir}/${fMRIName}_Atlas${RegString}_${File}.dscalar.nii -left-surface ${DownsampleFolder}/${Subject}.L.midthickness.${LowResMesh}k_fs_LR.surf.gii -right-surface ${DownsampleFolder}/${Subject}.R.midthickness.${LowResMesh}k_fs_LR.surf.gii -merged-volume -nearest 
      fi
      
      rm ${lMetric} ${rMetric} 
    done
    rm ${volumeData} ${WorkingDir}/${fMRIName}_${File}.${VolExT}

    mv $ciftiOut ${Output}

    if [ ${DeleteIntermediates} = "TRUE" ] ; then
      rm ${WorkingDir}/${File}.L.native.func.gii ${WorkingDir}/${File}.R.native.func.gii
    fi
    i=$((${i}+1))
  done


