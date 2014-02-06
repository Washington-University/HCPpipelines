#!/bin/bash
#set -x

# Authors: Michael Harms, Matthew Glasser, Sachin Dixit

usage() {
    {
        echo "Usage: $0 --path=<> --subjectlist=<> --resultsfolder=<> --analysisname=<> --lvl3fsf=<> --lvl2task=<> --lvl2fsf=<> --finalsmoothingFWHM=<> --temporalfilter=<> --regname=<> --analysistype=<> --contrastlist=<>"
        echo
	echo "--path=<StudyFolder>"
	echo
	echo "--subjectlist=<SubjectList>"
	echo "     List of subject IDs, separated by @ symbol (without spaces)"
	echo
	echo "--resultsfolder=<ResultsFolder>"
	echo "     Directory name for outputs of this script"
	echo
	echo "--analysisname=<AnalysisName>"
	echo "     Used as an initial prefix in some file naming"
	echo
	echo "--lvl3fsf=<LevelThreeFsf>"
	echo "     Specification of EVs, Contrasts, and F-tests, in FSL's fsf format"
	echo "     Does not need to specify any inputs files."
	echo "     However, the order of rows in the design matrix are assumed to "
	echo "     match the order of subjects in SubjectList."
	echo "     Can be created using FSL's Glm GUI"
	echo
	echo "--lvl2task=<LevelTwofMRIName>"
	echo "--lvl2fsf=<LevelTwofsfName>"
	echo "--finalsmoothingFWHM=<FinalSmoothingFWHM>"
	echo "--temporalfilter=<TemporalFilter>"
	echo "--regname=<RegName>"
	echo "      Together, these define aspects of the Level1/2 analysis,"
	echo "      and the location of the Level2 input directories for each subject"
	echo "      e.g., \${LevelTwofMRIName}/\${LevelTwofsfName}_hp\${TemporalFilter}_s\${FinalSmoothingFWHM}_level2_\${RegName}.feat"
	echo 
	echo "--analysistype=<GRAYORD,VOLUME, or BOTH>"
	echo
	echo "--contrastlist=<ContrastList>"
	echo "      Use ALL to automatically create Level3 results for each of the Level2 contrasts"
	echo "      Otherwise, use a list of numbers, separated by @ symbol (without spaces)"
	echo "      to process just those specific Level2 contrasts"
	echo "      e.g., --contrastlist=1@6@8"
	echo "      would process just contrasts 1, 6, and 8 from Level2"
	echo

     } >&2
    exit 7
} 

# function for parsing options
getopt1() {
    sopt="$1"
    shift 1
    for fn in $@ ; do
	if [ `echo $fn | grep -- "^${sopt}=" | wc -w` -gt 0 ] ; then
	    echo $fn | sed "s/^${sopt}=//"
	    return 0
	fi
    done
}

defaultopt() {
    echo $1
}

# Just give usage if no arguments specified
if [ $# -eq 0 ] ; then usage; exit 0; fi

StudyFolder=`getopt1 "--path" $@`  
SubjectList=`getopt1 "--subjectlist" $@`  
ResultsFolder=`getopt1 "--resultsfolder" $@`  
AnalysisName=`getopt1 "--analysisname" $@`      # Used as initial prefix in some file naming.
LevelThreeFsf=`getopt1 "--lvl3fsf" $@`   # Needs to specify the EVs, Contrasts, and F-tests.  Does NOT need to specify any inputs.
                                         # However, order of inputs (rows) MUST correspond to order used in $SubjectList. 
                                         # Can be created using "Glm" GUI.
LevelTwofMRIName=`getopt1 "--lvl2task" $@`
LevelTwofsfName=`getopt1 "--lvl2fsf" $@`  
FinalSmoothingFWHM=`getopt1 "--finalsmoothingFWHM" $@`  
TemporalFilter=`getopt1 "--temporalfilter" $@`
AnalysisType=`getopt1 "--analysistype" $@`
RegName=`getopt1 "--regname" $@`
ContrastListIn=`getopt1 "--contrastlist" $@`


### M.P.Harms changes, Oct-Dec 2013  ###
# Eliminate copying of Lev2 data -- use sym links for Volume analysis, and just convert CIFTI directly for Grayordinates.
# For Grayordinates, convert (CIFTI->NIFTI) only the specific lower-level files that are necessary for 'flameo'.
# Added "--fc" option to 'flameo' to compute F-tests.
# Extended code to allow processing of only specific Lev2 copes (via ContrastListIn argument).
# Allowed for a Volume only analysis.
# Consolidated common code outside of 'for' loops.
# Added check to confirm that Lev2 contrasts are the same across subjects.
# Added variables to permit deletion of non-essential files.
# Extended code that generates files for viewing to flexibly handle copes, zstats, and zfstats, 
#   and to handle more than 1 contrast in the Level3 analysis.
# Changed directory structure to be a bit more "Feat-like" [i.e., added 'stats' directory to store direct output 
#   of 'flameo', thereby creating a directory level (copeX.feat) for future post-flameo processing, such as FDR, 
#   randomise, or cluster-corrected statistical images].
# Split Grayordinate and Volume analyses into separate output gfeat directories for better segregation and flexibility.
#   (Allows one to run a Volume analysis after a Grayordinate analysis, without disturbing the latter).
# Various changes to help with readability (e.g., extract file names into variables).

# To do (?):
# 1) Add capability to go back and add certain contrasts while integrating into the already existing data
# 2) Rework .dtseries.nii, .dscalar.nii conversions if workbench develops easier approaches
# 3) Add creation of a Lev3Contrasts.txt file (describing the Lev3 contrasts).


##Naming Conventions
CommonAtlasFolder="${ResultsFolder}/MNINonLinear"
CommonResultsFolder="${CommonAtlasFolder}/Results"

##Set up some things
# Note that all lists should be space separated lists. NOT defined as arrays.
SubjectList=`echo $SubjectList | sed 's/@/ /g'`
NumSubjects=`echo ${SubjectList} | wc -w`

SmoothingString="_s${FinalSmoothingFWHM}"
TemporalFilterString="_hp""$TemporalFilter"
if [ ! "${RegName}" = "NONE" ] ; then 
  RegString="_${RegName}"
else
  RegString=""
fi

##Hidden options not available via command line arguments
DeleteIntermediates="YES"       #Set to "NO" to preserve intermediate (CIFTI/NIFTI conversion) files (for debugging)
DeleteMergedFlameoInputs="YES"  #Set to "NO" to preserve the merged Lev2 file files (for debugging)
DeleteSingleContrastDscalars="YES"  #Set to "YES" to delete the single contrast dscalar files, 
                                    # leaving only the aggregated composite containing all contrasts.
DscalarMeasureList="cope zstat zfstat"  #List of measures for which to aggregate across contrasts
                                        # for convenient viewing in Workbench.
                                        #Result will be one dscalar file for each measure, containing
                                        # as its COL dimension the Lev2 contrasts specified in ContrastListIn.
                                        #Can set to empty to avoid aggregation across contrasts.

StartTime=`date`
echo $StartTime

LevelTwoFEATDirSTRING=""
for Subject in $SubjectList ; do 
  AtlasFolder="${StudyFolder}/${Subject}/MNINonLinear"
  ResultsFolder="${AtlasFolder}/Results"
  LevelTwoFEATDir="${ResultsFolder}/${LevelTwofMRIName}/${LevelTwofsfName}${TemporalFilterString}${SmoothingString}_level2${RegString}.feat"
  if [ -d ${LevelTwoFEATDir} ] ; then
    LevelTwoFEATDirSTRING="${LevelTwoFEATDirSTRING} ${LevelTwoFEATDir}"
  else
    echo "ERROR: ${LevelTwoFEATDir} does not exist for ${Subject}"
    exit -1
  fi
done

FirstFolder=`echo $LevelTwoFEATDirSTRING | cut -d " " -f 1`
ContrastNames=`cat ${FirstFolder}/Contrasts.txt`

#Set up ContrastList
if [ "${ContrastListIn}" = "ALL" ] ; then
    NumContrasts=`echo ${ContrastNames} | wc -w`
    j=1
    while [ $j -le ${NumContrasts} ] ; do
	ContrastList="${ContrastList} $j"
	j=$(($j+1))
    done
else
    ContrastList=`echo $ContrastListIn | sed 's/@/ /g'`
fi

LevelThreeFEATDirGray="${CommonResultsFolder}/${LevelTwofMRIName}/${LevelTwofsfName}${TemporalFilterString}${SmoothingString}_level3${RegString}.gfeat"
LevelThreeFEATDirVol="${CommonResultsFolder}/${LevelTwofMRIName}/${LevelTwofsfName}${TemporalFilterString}${SmoothingString}_level3vol${RegString}.gfeat"

DIR=`pwd`

#Loop over Grayordinates and Standard Volume (if requested) Level 2 Analyses
if [ "${AnalysisType}" = "BOTH" ] ; then
  Analyses="GrayordinatesStats StandardVolumeStats"
elif [ "${AnalysisType}" = "VOLUME" ] ; then
  Analyses="StandardVolumeStats"
else
  Analyses="GrayordinatesStats"  # Default to Grayordinate analysis only
fi

for Analysis in ${Analyses} ; do

  #Set LevelThreeFEATDir according to Analysis type
  if [ "$Analysis" = "GrayordinatesStats" ] ; then
    LevelThreeFEATDir=${LevelThreeFEATDirGray}
  elif [ "$Analysis" = "StandardVolumeStats" ] ; then
    LevelThreeFEATDir=${LevelThreeFEATDirVol}
  else
    echo "ERROR: $Analysis not a valid analysis mode"
    exit -1
  fi

  echo -e "\n----- ANALYSIS = $Analysis -----"
  if [ -d ${LevelThreeFEATDir} ] ; then
    rm -r ${LevelThreeFEATDir}
  fi
  
  #Define directory where the copeX.feat directories (corresponding to each Lev2 contrast) will go
  # Since we've split Grayordinate and Volume analyses into separate root gfeat directories (above), 
  # we will just use LevelThreeFEATDir itself. (This yields a directory structure closer to FEAT output).
  LevelThreeFEATDirCopes=${LevelThreeFEATDir}
  # If Grayordinate and Volume analyses are to be part of the same LevelThreeFEATDir (previous implementation)
  # then can easily revert to that by using the following definition instead:
  ##LevelThreeFEATDirCopes=${LevelThreeFEATDir}/${Analysis}
  # (Note that if you use the above line, must make a similar change in the section "Generate Files for 
  # Workbench viewing" as well).
  
  mkdir -p ${LevelThreeFEATDirCopes}
  
  #Make design files
  cat ${LevelThreeFsf} > ${LevelThreeFEATDir}/design.fsf
  cd ${LevelThreeFEATDir}
  feat_model ${LevelThreeFEATDir}/design
  cd $DIR
  
  ##  --- BEGIN PREP SECTION --- ##
  # Prepare convenient directory structure for merging lower level inputs
  # And convert CIFTI to NIFTI if Grayordinates analysis
  for i in ${ContrastList} ; do
    Contrast=`echo $ContrastNames | cut -d " " -f $i`
    echo "COPE $i, $Contrast, Preparing inputs, `date`"
    j=1
    for Subject in ${SubjectList} ; do
      if (( $j % 20 == 0 )) ; then
	echo "  Subject $j/$NumSubjects"
      fi
      LevelTwoFEATDir=`echo ${LevelTwoFEATDirSTRING} | cut -d " " -f $j`

      #Confirm that all the Lev2 inputs have the same contrasts, otherwise we have a problem
      diff ${FirstFolder}/Contrasts.txt ${LevelTwoFEATDir}/Contrasts.txt > /dev/null
      if [ $? -ne 0 ] ; then
	echo "ERROR: Contrasts.txt in ${LevelTwoFEATDir} doesn't match that in ${FirstFolder}"
	exit -1
      fi

      ## Subsection specific to Grayordinates analysis
      if [ "$Analysis" = "GrayordinatesStats" ] ; then
	mkdir -p ${LevelThreeFEATDirCopes}/${i}/${j}
	## Need to convert 4 files back to NIFTI for use in FLAMEO
        for File in {mask,cope1,varcope1,tdof_t1} ; do
	  cifti_in=${LevelTwoFEATDir}/${Analysis}/cope${i}.feat/${File}.dtseries.nii
	 
	  cifti_out=${LevelThreeFEATDirCopes}/${i}/${j}/${File}.nii.gz
	  if [ ! -e ${cifti_in} ] ; then
	      echo "ERROR: ${cifti_in} does not exist"
	      exit -1
	  fi
          ${CARET7DIR}/wb_command -cifti-convert -to-nifti ${cifti_in} ${cifti_out}
	done

      ## Subsection specific to Volume analysis
      elif [ "$Analysis" = "StandardVolumeStats" ] ; then
	mkdir -p ${LevelThreeFEATDirCopes}/${i}
	## For StandardVolumeStats, just create symbolic links to original copeX.feat directories
	copedir=${LevelTwoFEATDir}/${Analysis}/cope${i}.feat
	if [ ! -e ${copedir} ] ; then
	    echo "ERROR: ${copedir} does not exist"
	    exit -1
	fi
        ln -s ${copedir} ${LevelThreeFEATDirCopes}/${i}/${j}

      else
	echo "ERROR: $Analysis not a valid analysis mode"
	exit -1
      fi ##End of specific gray and vol subsections

      j=$(($j+1))
    done  # Subject loop
  done  # ContrastList loop
  ##  --- END PREP SECTION --- ##


  ##  --- BEGIN FLAMEO SECTION --- ##
  # Merge copes, varcopes, masks, and tdof_t1s, and run 3rd level analysis
  # Because of how we prep'ed above, same code applies here for both Grayordinate and Volume analyses
  echo -e "\nMerging inputs and running FLAMEO"
  ExtraArgs=""
  if [ -e ${LevelThreeFEATDir}/design.fts ] ; then
      ExtraArgs="$ExtraArgs --fc=${LevelThreeFEATDir}/design.fts"
  fi
  for i in ${ContrastList} ; do
    MASKMERGE=""
    COPEMERGE=""
    VARCOPEMERGE=""
    DOFMERGE=""
    j=1
    while [ $j -le ${NumSubjects} ] ; do
      MASKMERGE="${MASKMERGE} ${LevelThreeFEATDirCopes}/${i}/${j}/mask.nii.gz"
      COPEMERGE="${COPEMERGE} ${LevelThreeFEATDirCopes}/${i}/${j}/cope1.nii.gz"
      VARCOPEMERGE="${VARCOPEMERGE} ${LevelThreeFEATDirCopes}/${i}/${j}/varcope1.nii.gz"
      DOFMERGE="${DOFMERGE} ${LevelThreeFEATDirCopes}/${i}/${j}/tdof_t1.nii.gz"
      j=$(($j+1))
    done
    copedir="${LevelThreeFEATDirCopes}/cope${i}.feat"
    mkdir -p ${copedir}
    cd ${copedir}
    suffix="_lev2data"  #Suffix to distinguish the merged lev2 files
    mergedcope=cope${i}${suffix}
    mergedvarcope=varcope${i}${suffix}
    mergedtdof=tdof_t1_${i}${suffix}
    fslmerge -t mask${i} $MASKMERGE
    fslmaths mask${i} -Tmin mask${i}
    fslmerge -t $mergedcope $COPEMERGE
    fslmaths $mergedcope -mas mask${i} $mergedcope
    fslmerge -t $mergedvarcope $VARCOPEMERGE
    fslmaths $mergedvarcope -mas mask${i} $mergedvarcope
    fslmerge -t $mergedtdof $DOFMERGE
    fslmaths $mergedtdof -mas mask${i}.nii.gz $mergedtdof
    flameo --cope=$mergedcope --vc=$mergedvarcope --dvc=$mergedtdof --mask=mask${i} --ld=stats --dm=${LevelThreeFEATDir}/design.mat --cs=${LevelThreeFEATDir}/design.grp --tc=${LevelThreeFEATDir}/design.con ${ExtraArgs} --runmode=flame1 --outputdof

    # Cleanup
    if [ "${DeleteMergedFlameoInputs}" = "YES" ] ; then
      rm -r mask${i}.nii.gz ${mergedcope}.nii.gz ${mergedvarcope}.nii.gz ${mergedtdof}.nii.gz
    fi
    if [ "${DeleteIntermediates}" = "YES" ] ; then
      rm -r ${LevelThreeFEATDirCopes}/${i}
    fi

    cd $DIR
  done
  echo -e "\nDone FLAMEO\n"
  ##  --- END FLAMEO SECTION --- ##

  ##  --- BEGIN POST-FLAMEO CONVERSIONS --- ##
  # Convert NIFTI file back to CIFTI; only relevant for Grayordinate analysis
  if [ "$Analysis" = "GrayordinatesStats" ] ; then
    cd ${LevelThreeFEATDirCopes}
    Files=`ls | grep .nii.gz | cut -d "." -f 1`
    cd $DIR
    for File in $Files ; do
      nifti_in=${LevelThreeFEATDirCopes}/${File}.nii.gz
      cifti_template=${LevelTwoFEATDir}/${Analysis}/cope1.feat/pe1.dtseries.nii
      cifti_out=${LevelThreeFEATDirCopes}/${File}.dtseries.nii
      ${CARET7DIR}/wb_command -cifti-convert -from-nifti ${nifti_in} ${cifti_template} ${cifti_out} -reset-timepoints 1 1 
      if [ "${DeleteIntermediates}" = "YES" ] ; then
	rm ${LevelThreeFEATDirCopes}/${File}.nii.gz
      fi
    done
    for i in ${ContrastList} ; do
      echo "COPE $i, Converting NIFTI->CIFTI, `date`"
      cd ${LevelThreeFEATDirCopes}/cope${i}.feat/stats
      Files=`ls | grep .nii.gz | cut -d "." -f 1`
      cd $DIR
      for File in $Files ; do
	nifti_in=${LevelThreeFEATDirCopes}/cope${i}.feat/stats/${File}.nii.gz
	cifti_template=${LevelTwoFEATDir}/${Analysis}/cope${i}.feat/pe1.dtseries.nii
	cifti_out=${LevelThreeFEATDirCopes}/cope${i}.feat/stats/${File}.dtseries.nii
        ${CARET7DIR}/wb_command -cifti-convert -from-nifti ${nifti_in} ${cifti_template} ${cifti_out} -reset-timepoints 1 1 
	if [ "${DeleteIntermediates}" = "YES" ] ; then
          rm ${LevelThreeFEATDirCopes}/cope${i}.feat/stats/${File}.nii.gz
	fi
      done
    done        
  fi ##END of NIFTI->CIFTI conversion for Grayordinates analysis
  ##  --- END POST-FLAMEO CONVERSIONS --- ##

done  # for Analysis in ${Analyses} ; do


### --- Generate Files for Workbench viewing --- ###
echo -e "\n----- Generating files for viewing -----"
for Analysis in ${Analyses} ; do

  #Set LevelThreeFEATDir according to Analysis type
  if [ "$Analysis" = "GrayordinatesStats" ] ; then
    LevelThreeFEATDir=${LevelThreeFEATDirGray}
  elif [ "$Analysis" = "StandardVolumeStats" ] ; then
    LevelThreeFEATDir=${LevelThreeFEATDirVol}
  else
    echo "ERROR: $Analysis not a valid analysis mode"
    exit -1
  fi

  # See comment above regarding LevelThreeFEATDirCopes
  LevelThreeFEATDirCopes=${LevelThreeFEATDir}

  for MeasureType in ${DscalarMeasureList} ; do
  # Create a list of all possible unique files for each measure (i.e., zstat1, zstat2, ..., zstatN if MeasureType="zstat")
    cd ${LevelThreeFEATDirCopes}
    StatPrefixes=`ls -1 cope*.feat/stats/${MeasureType}* 2> /dev/null`
    if [ ${#StatPrefixes} -gt 0 ] ; then
      StatPrefixes=`echo $StatPrefixes | xargs -n 1 basename | cut -d "." -f 1 | sort -u`
    fi

    cd $DIR

    for statistic in ${StatPrefixes} ; do

      MergeSTRING=""
      if [ -e ${LevelThreeFEATDir}/Contrasts.txt ] ; then
	rm ${LevelThreeFEATDir}/Contrasts.txt
	rm -f ${LevelThreeFEATDir}/Contrasttemp.txt
      fi

      for i in ${ContrastList} ; do
	Contrast=`echo $ContrastNames | cut -d " " -f $i`
	echo "COPE $i, $Contrast, $statistic, $Analysis"
	prefix="${AnalysisName}_${LevelTwofsfName}_level3_${statistic}_${Contrast}${TemporalFilterString}${SmoothingString}${RegString}"
	echo ${prefix} >> ${LevelThreeFEATDir}/Contrasttemp.txt
      	echo ${Contrast} >> ${LevelThreeFEATDir}/Contrasts.txt

        ## Subsection specific to Grayordinates analysis
	if [ "$Analysis" = "GrayordinatesStats" ] ; then
	  input=${LevelThreeFEATDirCopes}/cope${i}.feat/stats/${statistic}.dtseries.nii
	  if [ ! -e ${input} ] ; then
	    echo "ERROR: ${input} does not exist"
	    exit -1
	  fi
	  output=${LevelThreeFEATDir}/${prefix}.dscalar.nii
	  ${CARET7DIR}/wb_command -cifti-convert-to-scalar ${input} ROW ${output} -name-file ${LevelThreeFEATDir}/Contrasttemp.txt
	  MergeSTRING=`echo "${MergeSTRING} -cifti ${output}"`

        ## Subsection specific to Volume analysis
	elif [ "$Analysis" = "StandardVolumeStats" ] ; then
	  label_list=${LevelThreeFEATDir}/wbtemp.txt
	  echo "OTHER" >> ${label_list}
	  echo "1 255 255 255 255" >> ${label_list}
	  volume_to_label=${LevelThreeFEATDirCopes}/cope${i}.feat/stats/mask.nii.gz
	  labeled_volume=${LevelThreeFEATDirCopes}/cope${i}.feat/stats/masktmp.nii.gz
	  ${CARET7DIR}/wb_command -volume-label-import ${volume_to_label} ${label_list} ${labeled_volume} -discard-others -unlabeled-value 0
	  rm ${label_list}
	  prefix=${AnalysisName}_${LevelTwofsfName}_level3vol_${statistic}_${Contrast}${TemporalFilterString}${SmoothingString}${RegString}
	  input=${LevelThreeFEATDirCopes}/cope${i}.feat/stats/${statistic}.nii.gz
	  if [ ! -e ${input} ] ; then
	    echo "ERROR: ${input} does not exist"
	    exit -1
	  fi
	  outputdtseries=${LevelThreeFEATDir}/${prefix}.dtseries.nii
	  outputdscalar=${LevelThreeFEATDir}/${prefix}.dscalar.nii
	  ${CARET7DIR}/wb_command -cifti-create-dense-timeseries ${outputdtseries} -volume ${input} ${labeled_volume} -timestep 1 -timestart 1
	  ${CARET7DIR}/wb_command -cifti-convert-to-scalar ${outputdtseries} ROW ${outputdscalar} -name-file ${LevelThreeFEATDir}/Contrasttemp.txt
	  rm ${outputdtseries} ${labeled_volume}
	  MergeSTRING=`echo "${MergeSTRING} -cifti ${outputdscalar}"`

	else
	  echo "ERROR: $Analysis not a valid analysis mode"
	  exit -1
	fi
      
	rm ${LevelThreeFEATDir}/Contrasttemp.txt
      done  # contrast loop

      # Merge across contrasts for a given statistic
      if [ "$Analysis" = "GrayordinatesStats" ] ; then
	cifti_merge_out=${LevelThreeFEATDir}/${AnalysisName}_${LevelTwofsfName}_level3_${statistic}${TemporalFilterString}${SmoothingString}${RegString}.dscalar.nii
      elif [ "$Analysis" = "StandardVolumeStats" ] ; then
	  cifti_merge_out=${LevelThreeFEATDir}/${AnalysisName}_${LevelTwofsfName}_level3vol_${statistic}${TemporalFilterString}${SmoothingString}.dscalar.nii
      fi
      ${CARET7DIR}/wb_command -cifti-merge ${cifti_merge_out} ${MergeSTRING}
      if [ "${DeleteSingleContrastDscalars}" = "YES" ] ; then
	  FilesToDelete=`echo ${MergeSTRING} | sed 's/-cifti//g'`
	  rm ${FilesToDelete}
      fi

    done  # statistic loop
  done  # MeasureType loop
done  # Analysis loop

FinishTime=`date`
echo "Start time: ${StartTime}"
echo "Finish time: ${FinishTime}"
exit






