#!/bin/bash
#set -xv
set -e
# Authors: Matthew Glasser, Michael Harms, Sachin Dixit

usage() {
    {
        echo "Usage: $0 --path=<> --subjectlist=<> --groupfolder=<> --lvl3fsf=<> --lvl2task=<> --lvl2fsf=<> --prefixanalysisname=<> --finalsmoothingFWHM=<> --temporalfilter=<> --regname=<> --parcellation=<> --vba=<> --contrastlist=<> "
        echo
	echo "--path=<StudyFolder>"
	echo
	echo "--subjectlist=<SubjectList>"
	echo "     List of subject IDs, separated by @ symbol (without spaces)"
	echo
	echo "--groupfolder=<GroupFolder>"
	echo "     Group ID folder name"
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
	echo "--prefixanalysisname=<PrefixAnalysisName>"
	echo "     Prefix for output folder name, turn off with NONE"
	echo "--finalsmoothingFWHM=<FinalSmoothingFWHM>"
	echo "--temporalfilter=<TemporalFilter>"
	echo "--regname=<RegName>"
	echo "--parcellation=<Parcellation>"
	echo "      Together, these define aspects of the Level1/2 analysis,"
	echo "      and the location of the Level2 input directories for each subject"
	echo "      e.g., \${LevelTwofMRIName}/\${LevelTwofsfName}_hp\${TemporalFilter}_s\${FinalSmoothingFWHM}_level2_\${RegName}_\${Parcellation}.feat"
	echo "      Set --regname=NONE and/or --parcellation=NONE to turn off"
	echo 
	echo "--vba=<YES, NO>"
	echo
	echo "--contrastlist=<ContrastList>"
	echo "      Use ALL to automatically create Level3 results for each of the Level2 contrasts"
	echo "      Otherwise, use a list of numbers, separated by @ symbol (without spaces)"
	echo "      to process just those specific Level2 contrasts"
	echo "      e.g., --contrastlist=1@6@8"
	echo "      would process just contrasts 1, 6, and 8 from Level2"
	echo "--procstring=<ProcSTRING>"
	echo "      e.g. like _hp2000_clean for ICA+FIX, not required for greyordinates as this can be in RegName, but required for volume"
	echo "      append _lp<lpfilter> if --lowpassfilter was used in prior scripts"

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
GroupFolder=`getopt1 "--groupfolder" $@`  
LevelThreeFsf=`getopt1 "--lvl3fsf" $@`   # Needs to specify the EVs, Contrasts, and F-tests.  Does NOT need to specify any inputs.
                                         # However, order of inputs (rows) MUST correspond to order used in $SubjectList. 
                                         # Can be created using "Glm" GUI.
LevelTwofMRIName=`getopt1 "--lvl2task" $@`
LevelTwofsfName=`getopt1 "--lvl2fsf" $@`  
PrefixAnalysisName=`getopt1 "--prefixanalysisname" $@`  
FinalSmoothingFWHM=`getopt1 "--finalsmoothingFWHM" $@`  
TemporalFilter=`getopt1 "--temporalfilter" $@`
VolumeBasedProcessing=`getopt1 "--vba" $@`
RegName=`getopt1 "--regname" $@`
ContrastListIn=`getopt1 "--contrastlist" $@`
Parcellation=`getopt1 "--parcellation" $@`
ProcSTRING=`getopt1 "--procstring" $@`

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

### Matt Glasser changs, April 2015 ###
#Merge in changes for 1) MSMAll registration (or other non-default surface registration), 2) Allow processing of parcellated data, 3) Saving out beta maps as CIFTI
#Revert some file naming and directory organization changes above that weren't agreed upon
#Revert abilty to do only volume-based analyses--this is a CIFTI script that has the option of running a volume-based analysis

# To do (?):
# 1) Add capability to go back and add certain contrasts while integrating into the already existing data
# 2) Rework .dtseries.nii, .dscalar.nii conversions if workbench develops easier approaches
# 3) Add creation of a Lev3Contrasts.txt file (describing the Lev3 contrasts).

##Naming Conventions
CommonAtlasFolder="${GroupFolder}/MNINonLinear"
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

if [ ! ${ProcSTRING} = "NONE" ] ; then
  ProcSTRING="_${ProcSTRING}"
else
  ProcSTRING=""
fi

if [ ! "${PrefixAnalysisName}" = "NONE" ] ; then 
  PrefixAnalysisString="${PrefixAnalysisName}_"
else
  PrefixAnalysisString=""
fi

if [ ! ${Parcellation} = "NONE" ] ; then
  ParcellationString="_${Parcellation}"
  Extension="ptseries.nii"
  ScalarExtension="pscalar.nii"
else
  ParcellationString=""
  Extension="dtseries.nii"
  ScalarExtension="dscalar.nii"
fi

##Hidden options not available via command line arguments
DeleteIntermediates="YES"       #Set to "NO" to preserve intermediate (CIFTI/NIFTI conversion) files (for debugging)
DeleteMergedFlameoInputs="YES"  #Set to "NO" to preserve the merged Lev2 file files (for debugging)
DeleteSingleContrastDscalars="YES"  #Set to "YES" to delete the single contrast dscalar files, 
                                    # leaving only the aggregated composite containing all contrasts.
DscalarMeasureList="cope zstat varcope zfstat"  #List of measures for which to aggregate across contrasts
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
  LevelTwoFEATDir="${ResultsFolder}/${LevelTwofMRIName}/${LevelTwofsfName}${TemporalFilterString}${SmoothingString}_level2${RegString}${ProcSTRING}${ParcellationString}.feat"
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

LevelThreeFEATDir="${CommonResultsFolder}/${LevelTwofMRIName}/${PrefixAnalysisString}${LevelTwofsfName}${TemporalFilterString}${SmoothingString}_level3${RegString}${ProcSTRING}${ParcellationString}.gfeat"

#I think this should be kept
if [ -e ${LevelThreeFEATDir} ] ; then
  if [[ $VolumeBasedProcessing = "YES" && $FinalSmoothingFWHM = "0" ]] ; then
    echo "Skipping FEAT Directory Clean up"
  else
    rm -r ${LevelThreeFEATDir}
    mkdir ${LevelThreeFEATDir}
  fi
else
  mkdir -p ${LevelThreeFEATDir}
fi

#Make design files
cat ${LevelThreeFsf} > ${LevelThreeFEATDir}/design.fsf
DIR=`pwd`
cd ${LevelThreeFEATDir}
feat_model design
cd $DIR

#Loop over Grayordinates and Standard Volume (if requested) Level 2 Analyses
if [ ${VolumeBasedProcessing} = "YES" ] ; then
  Analyses="GrayordinatesStats StandardVolumeStats"
elif [ -z ${ParcellationString} ] ; then
  Analyses="GrayordinatesStats"
else
  Analyses="ParcellatedStats"
fi

if [[ $VolumeBasedProcessing = "YES" && $FinalSmoothingFWHM = "0" ]] ; then
  echo "Cannot smooth CIFTI 0mm FWHM because already smoothed ${OriginalSmoothingFWHM}mm FWHM, Skipping"
  Analyses="StandardVolumeStats"
fi

for Analysis in ${Analyses} ; do
  echo -e "\n----- ANALYSIS = $Analysis -----"
  mkdir -p ${LevelThreeFEATDir}/${Analysis}
  
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
      if [[ "$Analysis" = "GrayordinatesStats" || "$Analysis" = "ParcellatedStats" ]] ; then
	      mkdir -p ${LevelThreeFEATDir}/${Analysis}/${i}/${j}
	      ## Need to convert 4 files back to NIFTI for use in FLAMEO
        for File in {mask,cope1,varcope1,tdof_t1} ; do
	        cifti_in=${LevelTwoFEATDir}/${Analysis}/cope${i}.feat/${File}.${Extension}
	        cifti_out=${LevelThreeFEATDir}/${Analysis}/${i}/${j}/${File}.nii.gz
	        if [ ! -e ${cifti_in} ] ; then
	          echo "ERROR: ${cifti_in} does not exist"
	          exit -1
	        fi
          ${CARET7DIR}/wb_command -cifti-convert -to-nifti ${cifti_in} ${cifti_out}
	      done

      ## Subsection specific to Volume analysis
      elif [ "$Analysis" = "StandardVolumeStats" ] ; then
	      mkdir -p ${LevelThreeFEATDir}/${Analysis}/${i}
	      ## For StandardVolumeStats, just create symbolic links to original copeX.feat directories
	      copedir=${LevelTwoFEATDir}/${Analysis}/cope${i}.feat
	      if [ ! -e ${copedir} ] ; then
	        echo "ERROR: ${copedir} does not exist"
	        exit -1
	      fi
        ln -s ${copedir} ${LevelThreeFEATDir}/${Analysis}/${i}/${j}
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
      MASKMERGE="${MASKMERGE} ${LevelThreeFEATDir}/${Analysis}/${i}/${j}/mask.nii.gz"
      COPEMERGE="${COPEMERGE} ${LevelThreeFEATDir}/${Analysis}/${i}/${j}/cope1.nii.gz"
      VARCOPEMERGE="${VARCOPEMERGE} ${LevelThreeFEATDir}/${Analysis}/${i}/${j}/varcope1.nii.gz"
      DOFMERGE="${DOFMERGE} ${LevelThreeFEATDir}/${Analysis}/${i}/${j}/tdof_t1.nii.gz"
      j=$(($j+1))
    done
    suffix="_lev2data"  #Suffix to distinguish the merged lev2 files
    mergedcope=${LevelThreeFEATDir}/${Analysis}/cope${i}${suffix}
    mergedvarcope=${LevelThreeFEATDir}/${Analysis}/varcope${i}${suffix}
    mergedtdof=${LevelThreeFEATDir}/${Analysis}/tdof_t1_${i}${suffix}
    mask=${LevelThreeFEATDir}/${Analysis}/mask${i}${suffix}
    fslmerge -t ${mask} $MASKMERGE
    fslmaths ${mask} -Tmin ${mask}
    fslmerge -t ${mergedcope} $COPEMERGE
    fslmaths ${mergedcope} -mas ${mask} ${mergedcope}
    fslmerge -t ${mergedvarcope} $VARCOPEMERGE
    fslmaths ${mergedvarcope} -mas ${mask} ${mergedvarcope}
    fslmerge -t ${mergedtdof} $DOFMERGE
    fslmaths ${mergedtdof} -mas ${mask} ${mergedtdof}

    if [ -e ${LevelThreeFEATDir}/${Analysis}/cope${i}.feat ] ; then
      rm -r ${LevelThreeFEATDir}/${Analysis}/cope${i}.feat
    fi

    flameo --cope=${mergedcope} --vc=${mergedvarcope} --dvc=${mergedtdof} --mask=${mask} --ld=${LevelThreeFEATDir}/${Analysis}/cope${i}.feat --dm=${LevelThreeFEATDir}/design.mat --cs=${LevelThreeFEATDir}/design.grp --tc=${LevelThreeFEATDir}/design.con ${ExtraArgs} --runmode=flame1 --outputdof

    # Cleanup
    if [ "${DeleteMergedFlameoInputs}" = "YES" ] ; then
      rm -r ${mask}.nii.gz ${mergedcope}.nii.gz ${mergedvarcope}.nii.gz ${mergedtdof}.nii.gz
    fi
    if [ "${DeleteIntermediates}" = "YES" ] ; then
      rm -r ${LevelThreeFEATDir}/${Analysis}/${i}
    fi
  done
  echo -e "\nDone FLAMEO\n"
  ##  --- END FLAMEO SECTION --- ##

  ##  --- BEGIN POST-FLAMEO CONVERSIONS --- ##
  # Convert NIFTI file back to CIFTI; only relevant for Grayordinate analysis
  if [[ "$Analysis" = "GrayordinatesStats" || "$Analysis" = "ParcellatedStats" ]] ; then
    cd ${LevelThreeFEATDir}/${Analysis}
    Files=`ls | grep .nii.gz | cut -d "." -f 1`
    cd $DIR
    for File in $Files ; do
      nifti_in=${LevelThreeFEATDir}/${Analysis}/${File}.nii.gz
      cifti_template=${LevelTwoFEATDir}/${Analysis}/cope1.feat/pe1.${Extension}
      cifti_out=${LevelThreeFEATDir}/${Analysis}/${File}.${Extension}
      ${CARET7DIR}/wb_command -cifti-convert -from-nifti ${nifti_in} ${cifti_template} ${cifti_out} -reset-timepoints 1 1 
      if [ "${DeleteIntermediates}" = "YES" ] ; then
	      rm ${LevelThreeFEATDir}/${Analysis}/${File}.nii.gz
      fi
    done
    for i in ${ContrastList} ; do
      echo "COPE $i, Converting NIFTI->CIFTI, `date`"
      cd ${LevelThreeFEATDir}/${Analysis}/cope${i}.feat
      Files=`ls | grep .nii.gz | cut -d "." -f 1`
      cd $DIR
      for File in $Files ; do
	      nifti_in=${LevelThreeFEATDir}/${Analysis}/cope${i}.feat/${File}.nii.gz
	      cifti_template=${LevelTwoFEATDir}/${Analysis}/cope${i}.feat/pe1.${Extension}
	      cifti_out=${LevelThreeFEATDir}/${Analysis}/cope${i}.feat/${File}.${Extension}
        ${CARET7DIR}/wb_command -cifti-convert -from-nifti ${nifti_in} ${cifti_template} ${cifti_out} -reset-timepoints 1 1 
	      if [ "${DeleteIntermediates}" = "YES" ] ; then
          rm ${LevelThreeFEATDir}/${Analysis}/cope${i}.feat/${File}.nii.gz
	      fi
      done
    done        
  fi ##END of NIFTI->CIFTI conversion for Grayordinates analysis
  ##  --- END POST-FLAMEO CONVERSIONS --- ##

done  # for Analysis in ${Analyses} ; do

### --- Generate Files for Workbench viewing --- ###
echo -e "\n----- Generating files for viewing -----"
for Analysis in ${Analyses} ; do

  for MeasureType in ${DscalarMeasureList} ; do
  # Create a list of all possible unique files for each measure (i.e., zstat1, zstat2, ..., zstatN if MeasureType="zstat")
    cd ${LevelThreeFEATDir}/${Analysis}
    StatPrefixes=`ls -1 cope*.feat/${MeasureType}* 2> /dev/null`
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
	      prefix="${PrefixAnalysisString}${LevelTwofsfName}_level3_${statistic}_${Contrast}${TemporalFilterString}${SmoothingString}${RegString}${ProcSTRING}${ParcellationString}"
	      echo ${prefix} >> ${LevelThreeFEATDir}/Contrasttemp.txt
      	echo ${Contrast} >> ${LevelThreeFEATDir}/Contrasts.txt

        ## Subsection specific to Grayordinates analysis
        if [[ "$Analysis" = "GrayordinatesStats" || "$Analysis" = "ParcellatedStats" ]] ; then
	        input=${LevelThreeFEATDir}/${Analysis}/cope${i}.feat/${statistic}.${Extension}
	        if [ ! -e ${input} ] ; then
	        echo "ERROR: ${input} does not exist" 1>&2
	        exit -1
	        fi
	        output=${LevelThreeFEATDir}/${prefix}.${ScalarExtension}
	        ${CARET7DIR}/wb_command -cifti-convert-to-scalar ${input} ROW ${output} -name-file ${LevelThreeFEATDir}/Contrasttemp.txt
	        MergeSTRING=`echo "${MergeSTRING} -cifti ${output}"`

        ## Subsection specific to Volume analysis
	      elif [ "$Analysis" = "StandardVolumeStats" ] ; then
	        label_list=${LevelThreeFEATDir}/wbtemp.txt
	        echo "OTHER" >> ${label_list}
	        echo "1 255 255 255 255" >> ${label_list}
	        volume_to_label=${LevelThreeFEATDir}/${Analysis}/cope${i}.feat/mask.nii.gz
	        labeled_volume=${LevelThreeFEATDir}/${Analysis}/cope${i}.feat/masktmp.nii.gz
	        ${CARET7DIR}/wb_command -volume-label-import ${volume_to_label} ${label_list} ${labeled_volume} -discard-others -unlabeled-value 0
	        rm ${label_list}
	        prefix=${PrefixAnalysisString}${LevelTwofsfName}_level3vol_${statistic}_${Contrast}${TemporalFilterString}${SmoothingString}${ProcSTRING}
	        input=${LevelThreeFEATDir}/${Analysis}/cope${i}.feat/${statistic}.nii.gz
	        if [ ! -e ${input} ] ; then
	          echo "ERROR: ${input} does not exist" 1>&2
	          exit -1
	        fi
	        outputseries=${LevelThreeFEATDir}/${prefix}.${Extension}
	        outputscalar=${LevelThreeFEATDir}/${prefix}.${ScalarExtension}
	        ${CARET7DIR}/wb_command -cifti-create-dense-timeseries ${outputseries} -volume ${input} ${labeled_volume} -timestep 1 -timestart 1
	        ${CARET7DIR}/wb_command -cifti-convert-to-scalar ${outputseries} ROW ${outputscalar} -name-file ${LevelThreeFEATDir}/Contrasttemp.txt
	        rm ${outputseries} ${labeled_volume}
	        MergeSTRING=`echo "${MergeSTRING} -cifti ${outputscalar}"`

	        else
	          echo "ERROR: $Analysis not a valid analysis mode" 1>&2
	          exit -1
	      fi
      
	      rm ${LevelThreeFEATDir}/Contrasttemp.txt
      done  # contrast loop

      # Merge across contrasts for a given statistic
      if [[ "$Analysis" = "GrayordinatesStats" || "$Analysis" = "ParcellatedStats" ]] ; then
	      cifti_merge_out=${LevelThreeFEATDir}/${PrefixAnalysisString}${LevelTwofsfName}_level3_${statistic}${TemporalFilterString}${SmoothingString}${RegString}${ProcSTRING}${ParcellationString}.${ScalarExtension}
      elif [ "$Analysis" = "StandardVolumeStats" ] ; then
	      cifti_merge_out=${LevelThreeFEATDir}/${PrefixAnalysisString}${LevelTwofsfName}_level3vol_${statistic}${TemporalFilterString}${SmoothingString}${ProcSTRING}.${ScalarExtension}
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

