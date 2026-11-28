#!/bin/bash
#set -xv
set -e
# Authors: Matthew Glasser, Michael Harms, Sachin Dixit, Oren Poliva

usage() {
    {
        echo "Usage: $0 --path=<> --subjectlist=<> --groupfolder=<> --lvl3fsf=<> --lvl2task=<> --lvl2fsf=<> --prefixanalysisname=<> --finalsmoothingFWHM=<> --temporalfilter=<> --regname=<> --parcellation=<> --vba=<> --contrastlist=<> "
        echo
	echo "--path=<StudyFolder>"
	echo
	echo "--excluded-subjectlist=<ExcludedSubjectList>"
	echo "     Optional excluded subject IDs, separated by @. Default=NONE"
	echo
	echo "--level2-feat-name=<LevelTwoFeatName>"
	echo "     Optional Level2 FEAT directory name for reporting"
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
	echo "--lvl3fsf-mode=<CUSTOM, GROUP_MEAN>"
	echo "     GROUP_MEAN (default) requires a single-group mean FSF template and sizes"
	echo "     CUSTOM uses the design supplied via --lvl3fsf."
	echo "     the design to the number of subjects in --subjectlist."
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
	echo "--hippocampal-output=<YES, NO>"
	echo "      Also run hippocampal analysis. Default=NO"
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

source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@"         # Debugging functions; also sources log.shlib

level2_cifti_extension() {
    local analysis="$1"
    local copedir="$2"
    local extension
    local -a extensions

    case "$analysis" in
        GrayordinatesStats) extensions=(nii dtseries.nii) ;;
        HippocampusStats)   extensions=(dtseries.nii) ;;
        ParcellatedStats)   extensions=(nii) ;;
    esac

    for extension in "${extensions[@]}"; do
        if [[ -f "${copedir}/mask.${extension}" &&
              -f "${copedir}/cope1.${extension}" &&
              -f "${copedir}/varcope1.${extension}" &&
              -f "${copedir}/tdof_t1.${extension}" ]]; then
            printf '%s\n' "$extension"
            return 0
        fi
    done

  log_Err_Abort "No complete Level 2 CIFTI set in $copedir (checked suffixes: ${extensions[*]})"
}

# Relabel dentate as cortex for FSL, or restore the dentate labels.
# Rebuild as scalar CIFTI; each input map remains a separate output map.
relabel_hippocampal_cifti() {
    local input="$1"
    local output="$2"
    local direction="$3"
    local left_structure right_structure
    local output_left output_right
    local temp_dir

    case "$direction" in
        to-fsl)
            left_structure="HIPPOCAMPUS_DENTATE_LEFT"
            right_structure="HIPPOCAMPUS_DENTATE_RIGHT"
            output_left="CORTEX_LEFT"
            output_right="CORTEX_RIGHT"
            ;;
        from-fsl)
            left_structure="CORTEX_LEFT"
            right_structure="CORTEX_RIGHT"
            output_left="HIPPOCAMPUS_DENTATE_LEFT"
            output_right="HIPPOCAMPUS_DENTATE_RIGHT"
            ;;
        *)
            log_Err_Abort "Invalid relabel direction: $direction"
            ;;
    esac

    temp_dir=$(mktemp -d "$(dirname -- "$output")/relabel.XXXXXX")

    ${CARET7DIR}/wb_command -cifti-separate "$input" COLUMN \
        -metric HIPPOCAMPUS_LEFT "$temp_dir/L.hipp.func.gii" \
            -roi "$temp_dir/L.hipp.roi.func.gii" \
        -metric HIPPOCAMPUS_RIGHT "$temp_dir/R.hipp.func.gii" \
            -roi "$temp_dir/R.hipp.roi.func.gii" \
        -metric "$left_structure" "$temp_dir/L.dentate.func.gii" \
            -roi "$temp_dir/L.dentate.roi.func.gii" \
        -metric "$right_structure" "$temp_dir/R.dentate.func.gii" \
            -roi "$temp_dir/R.dentate.roi.func.gii"

    ${CARET7DIR}/wb_command -cifti-create-dense-scalar "$output" \
        -metric HIPPOCAMPUS_LEFT "$temp_dir/L.hipp.func.gii" \
            -roi "$temp_dir/L.hipp.roi.func.gii" \
        -metric HIPPOCAMPUS_RIGHT "$temp_dir/R.hipp.func.gii" \
            -roi "$temp_dir/R.hipp.roi.func.gii" \
        -metric "$output_left" "$temp_dir/L.dentate.func.gii" \
            -roi "$temp_dir/L.dentate.roi.func.gii" \
        -metric "$output_right" "$temp_dir/R.dentate.func.gii" \
            -roi "$temp_dir/R.dentate.roi.func.gii"
    rm -r "$temp_dir"
}

StudyFolder=`getopt1 "--path" $@`  
SubjectList=`getopt1 "--subjectlist" $@`
ExcludedSubjectList=`getopt1 "--excluded-subjectlist" $@`
ExcludedSubjectList=${ExcludedSubjectList:-NONE}
LevelTwoFeatName=`getopt1 "--level2-feat-name" $@`
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
HippocampalOutput=`getopt1 "--hippocampal-output" $@`
LevelThreeFsfMode=`getopt1 "--lvl3fsf-mode" $@`
LevelThreeFsfMode=${LevelThreeFsfMode:-GROUP_MEAN}

if [[ ! -f "$LevelThreeFsf" || ! -r "$LevelThreeFsf" ]]; then
    log_Err_Abort "Level 3 FSF must be a readable file: $LevelThreeFsf"
fi

case "$LevelThreeFsfMode" in
    CUSTOM|GROUP_MEAN) ;;
    *) log_Err_Abort "--lvl3fsf-mode must be CUSTOM or GROUP_MEAN" ;;
esac

HippocampalOutput=${HippocampalOutput:-NO}
case "$HippocampalOutput" in
    YES|NO) ;;
    *)
        log_Err_Abort "--hippocampal-output must be YES or NO"
        ;;
esac

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

# CIFTI analyses use native FLAMEO --CIFTI processing; no CIFTI-to-NIFTI conversion.
# To do (?):
# 1) Add capability to go back and add certain contrasts while integrating into the already existing data
# 2) Rework .dtseries.nii, .dscalar.nii conversions if workbench develops easier approaches
# 3) Add creation of a Lev3Contrasts.txt file (describing the Lev3 contrasts).

##Naming Conventions
CommonAtlasFolder="${GroupFolder}/MNINonLinear"
CommonResultsFolder="${CommonAtlasFolder}/Results"

# Note that all lists should be space separated lists. NOT defined as arrays.
IFS=@ read -r -a IncludedSubjects <<< "$SubjectList"

ExcludedSubjects=()
if [[ "$ExcludedSubjectList" != "NONE" ]]; then
    IFS=@ read -r -a ExcludedSubjects <<< "$ExcludedSubjectList"
fi

# Report subject selection to stdout.
echo "===== Subject selection ====="
echo "Task: ${LevelTwofMRIName}"
echo "Level2 FEAT directory name: ${LevelTwoFeatName:-Not supplied}"
echo "Excluded subjects (${#ExcludedSubjects[@]}): ${ExcludedSubjects[*]:-None}"
echo "Included subjects (${#IncludedSubjects[@]}), in analysis order: ${IncludedSubjects[*]}"
echo "============================="

SubjectList="${IncludedSubjects[*]}"
NumSubjects=${#IncludedSubjects[@]}

if [[ "$LevelThreeFsfMode" == "GROUP_MEAN" ]]; then
    awk '
        $1 == "set" {
            if ($2 == "fmri(evs_orig)") orig = $3
            if ($2 == "fmri(evs_real)") real = $3
            if ($2 == "fmri(evs_vox)") vox = $3
            if ($2 == "fmri(confoundevs)" && $3 != 0) invalid = 1

            if ($2 ~ /^fmri\(evg[0-9]+\.[0-9]+\)$/ &&
                ($2 !~ /\.1\)$/ || $3 != 1)) invalid = 1

            if ($2 ~ /^fmri\(groupmem\.[0-9]+\)$/ &&
                $3 != 1) invalid = 1

            if ($2 ~ /^(feat_files|highres_files|confoundev_files)\(/)
                invalid = 1
        }
        END {
            exit !(orig == 1 && real == 1 && vox == 0 && !invalid)
        }
    ' "$LevelThreeFsf" ||
        log_Err_Abort "GROUP_MEAN requires a single-group mean FSF template: $LevelThreeFsf"
fi

SmoothingString="_s${FinalSmoothingFWHM}"
if [[ "$TemporalFilter" == "NONE" ]]; then
    TemporalFilterString="_hp0"
else
    TemporalFilterString="_hp${TemporalFilter}"
fi

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
    log_Err_Abort "ERROR: ${LevelTwoFEATDir} does not exist for ${Subject}"
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

if [[ "$LevelThreeFsfMode" == "GROUP_MEAN" ]]; then
    # Generate one EV row and one group-membership row per included subject.
    awk -v n="$NumSubjects" '
        $1 == "set" && ($2 == "fmri(npts)" || $2 == "fmri(multiple)") {
            print $1, $2, n
            if ($2 == "fmri(npts)") found_npts = 1
            if ($2 == "fmri(multiple)") found_multiple = 1
            next
        }

        /^# Higher-level EV value for EV 1 and input [0-9]+[[:space:]]*$/ ||
        ($1 == "set" && $2 ~ /^fmri\(evg[0-9]+\.1\)$/) {
            if (!wrote_ev) {
                for (i = 1; i <= n; i++) {
                    printf "# Higher-level EV value for EV 1 and input %d\n", i
                    printf "set fmri(evg%d.1) 1\n\n", i
                }
                wrote_ev = 1
            }
            skip_blank = 1
            next
        }

        /^# Group membership for input [0-9]+[[:space:]]*$/ ||
        ($1 == "set" && $2 ~ /^fmri\(groupmem\.[0-9]+\)$/) {
            if (!wrote_groups) {
                for (i = 1; i <= n; i++) {
                    printf "# Group membership for input %d\n", i
                    printf "set fmri(groupmem.%d) 1\n\n", i
                }
                wrote_groups = 1
            }
            skip_blank = 1
            next
        }

        skip_blank && NF == 0 { next }

        {
            skip_blank = 0
            print
        }

        END {
            if (!(found_npts && found_multiple && wrote_ev && wrote_groups))
                exit 1
        }
    ' "$LevelThreeFsf" > "${LevelThreeFEATDir}/design.fsf" ||
        log_Err_Abort "Could not generate a group-mean FSF from: $LevelThreeFsf"
else
    # Preserve the caller's custom statistical design.
    cp -- "$LevelThreeFsf" "${LevelThreeFEATDir}/design.fsf"
fi

sed -i -e "s|^set fmri(outputdir) .*|set fmri(outputdir) \"${LevelThreeFEATDir}\"|" "${LevelThreeFEATDir}/design.fsf"

# Build the design files from the updated FSF.
DIR=$(pwd)
cd "${LevelThreeFEATDir}"
feat_model design
cd "$DIR"

# Compare subject count based on number of feat directories vs. number of rows in design matrix.
DesignSubjects=$(awk '$1 == "/NumPoints" { print $2 }' "${LevelThreeFEATDir}/design.mat")
if [[ "$DesignSubjects" != "$NumSubjects" ]]; then
    log_Err_Abort "Level 3 design has ${DesignSubjects:-unknown} rows, but --subjectlist contains $NumSubjects subjects"
fi

# Record the subject order used for the Level 3 inputs.
printf '%s\n' "${IncludedSubjects[@]}" > "${LevelThreeFEATDir}/Subjects.txt"

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

if [[ "${HippocampalOutput}" == "YES" ]]; then
  Analyses="${Analyses} HippocampusStats"
fi

for Analysis in ${Analyses} ; do
  echo -e "\n----- ANALYSIS = $Analysis -----"
  mkdir -p ${LevelThreeFEATDir}/${Analysis}
  
  ##  --- BEGIN PREP SECTION --- ##
  # Prepare convenient directory structure for merging lower level inputs
  # Check CIFTI inputs or link volume inputs
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
      if ! diff ${FirstFolder}/Contrasts.txt ${LevelTwoFEATDir}/Contrasts.txt > /dev/null ; then
	      log_Err_Abort "Contrasts.txt in ${LevelTwoFEATDir} doesn't match that in ${FirstFolder}"
      fi

      ## Subsection specific to CIFTI analysis
      if [[ "$Analysis" = "GrayordinatesStats" || "$Analysis" = "ParcellatedStats" || "$Analysis" = "HippocampusStats" ]] ; then
        copedir="${LevelTwoFEATDir}/${Analysis}/cope${i}.feat"
        InputExtension=$(level2_cifti_extension "$Analysis" "$copedir")

      ## Subsection specific to Volume analysis
      elif [ "$Analysis" = "StandardVolumeStats" ] ; then
	      mkdir -p ${LevelThreeFEATDir}/${Analysis}/${i}
	      ## For StandardVolumeStats, just create symbolic links to original copeX.feat directories
	      copedir=${LevelTwoFEATDir}/${Analysis}/cope${i}.feat
	      if [ ! -e ${copedir} ] ; then
	        log_Err_Abort "ERROR: ${copedir} does not exist"
	      fi
        #symlinks review: absolute link, needs attention.
        ln -s ${copedir} ${LevelThreeFEATDir}/${Analysis}/${i}/${j}
      else
	      log_Err_Abort "ERROR: $Analysis not a valid analysis mode"
      fi ##End of specific gray and vol subsections

      j=$(($j+1))
    done  # Subject loop
  done  # ContrastList loop
  ##  --- END PREP SECTION --- ##

  ##  --- BEGIN FLAMEO SECTION --- ##
  # Merge copes, varcopes, masks, and tdof_t1s, and run 3rd level analysis
  # Use CIFTI merging for surface analyses and NIFTI merging for volume analysis
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
      if [ "$Analysis" = "StandardVolumeStats" ] ; then
        MASKMERGE="${MASKMERGE} ${LevelThreeFEATDir}/${Analysis}/${i}/${j}/mask.nii.gz"
        COPEMERGE="${COPEMERGE} ${LevelThreeFEATDir}/${Analysis}/${i}/${j}/cope1.nii.gz"
        VARCOPEMERGE="${VARCOPEMERGE} ${LevelThreeFEATDir}/${Analysis}/${i}/${j}/varcope1.nii.gz"
        DOFMERGE="${DOFMERGE} ${LevelThreeFEATDir}/${Analysis}/${i}/${j}/tdof_t1.nii.gz"
      else
        LevelTwoFEATDir=`echo ${LevelTwoFEATDirSTRING} | cut -d " " -f $j`
        copedir="${LevelTwoFEATDir}/${Analysis}/cope${i}.feat"
        InputExtension=$(level2_cifti_extension "$Analysis" "$copedir")
        MASKMERGE="${MASKMERGE} -cifti ${copedir}/mask.${InputExtension}"
        COPEMERGE="${COPEMERGE} -cifti ${copedir}/cope1.${InputExtension}"
        VARCOPEMERGE="${VARCOPEMERGE} -cifti ${copedir}/varcope1.${InputExtension}"
        DOFMERGE="${DOFMERGE} -cifti ${copedir}/tdof_t1.${InputExtension}"
      fi
      j=$(($j+1))
    done
    suffix="_lev2data"  #Suffix to distinguish the merged lev2 files
    mergedcope=${LevelThreeFEATDir}/${Analysis}/cope${i}${suffix}
    mergedvarcope=${LevelThreeFEATDir}/${Analysis}/varcope${i}${suffix}
    mergedtdof=${LevelThreeFEATDir}/${Analysis}/tdof_t1_${i}${suffix}
    mask=${LevelThreeFEATDir}/${Analysis}/mask${i}${suffix}
    if [ "$Analysis" = "StandardVolumeStats" ] ; then
      fslmerge -t ${mask} $MASKMERGE
      fslmaths ${mask} -Tmin ${mask}
      fslmerge -t ${mergedcope} $COPEMERGE
      fslmaths ${mergedcope} -mas ${mask} ${mergedcope}
      fslmerge -t ${mergedvarcope} $VARCOPEMERGE
      fslmaths ${mergedvarcope} -mas ${mask} ${mergedvarcope}
      fslmerge -t ${mergedtdof} $DOFMERGE
      fslmaths ${mergedtdof} -mas ${mask} ${mergedtdof}

      InputSuffix=".nii.gz"
      CiftiArgs=""
    else
      mkdir -p ${LevelThreeFEATDir}/${Analysis}/${i}
      InputSuffix=".nii"
      CiftiArgs="--CIFTI"
      ${CARET7DIR}/wb_command -cifti-merge ${mask}_subjects.nii ${MASKMERGE}
      ${CARET7DIR}/wb_command -cifti-reduce ${mask}_subjects.nii MIN ${mask}_min.nii
      ${CARET7DIR}/wb_command -cifti-math "x > 0" ${mask}.nii -var x ${mask}_min.nii
      ${CARET7DIR}/wb_command -cifti-merge ${mergedcope}_subjects.nii ${COPEMERGE}
      ${CARET7DIR}/wb_command -cifti-merge ${mergedvarcope}_subjects.nii ${VARCOPEMERGE}
      ${CARET7DIR}/wb_command -cifti-merge ${mergedtdof}_subjects.nii ${DOFMERGE}
      for File in ${mergedcope} ${mergedvarcope} ${mergedtdof} ; do
        ${CARET7DIR}/wb_command -cifti-math "x * mask" ${File}.nii -var x ${File}_subjects.nii -var mask ${mask}.nii -select 1 1 -repeat
      done

      # Current FSL workaround: temporarily represent dentate as cortex.
      if [ "$Analysis" = "HippocampusStats" ] ; then
        for File in ${mask} ${mergedcope} ${mergedvarcope} ${mergedtdof} ; do
          relabel_hippocampal_cifti ${File}.nii ${File}.fsl.dscalar.nii to-fsl
        done
        InputSuffix=".fsl.dscalar.nii"
      fi
    fi

    if [ -e ${LevelThreeFEATDir}/${Analysis}/cope${i}.feat ] ; then
      rm -r ${LevelThreeFEATDir}/${Analysis}/cope${i}.feat
    fi

    flameo --cope=${mergedcope}${InputSuffix} --vc=${mergedvarcope}${InputSuffix} --dvc=${mergedtdof}${InputSuffix} --mask=${mask}${InputSuffix} --ld=${LevelThreeFEATDir}/${Analysis}/cope${i}.feat --dm=${LevelThreeFEATDir}/design.mat --cs=${LevelThreeFEATDir}/design.grp --tc=${LevelThreeFEATDir}/design.con ${ExtraArgs} --runmode=flame1 --outputdof ${CiftiArgs}

    # Restore correct dentate labels in hippocampal outputs.
    if [ "$Analysis" = "HippocampusStats" ] ; then
      for input in ${LevelThreeFEATDir}/${Analysis}/cope${i}.feat/*.nii ; do
        [ -f "$input" ] || continue
        File=`basename "$input" .nii`
        relabel_hippocampal_cifti "$input" "${LevelThreeFEATDir}/${Analysis}/cope${i}.feat/${File}.dscalar.nii" from-fsl
        if [ "${DeleteIntermediates}" = "YES" ] ; then
          rm "$input"
        fi
      done
    fi

    # Cleanup
    if [ "${DeleteMergedFlameoInputs}" = "YES" ] ; then
      if [ "$Analysis" = "StandardVolumeStats" ] ; then
        rm ${mask}.nii.gz ${mergedcope}.nii.gz ${mergedvarcope}.nii.gz ${mergedtdof}.nii.gz
      else
        for File in ${mask} ${mergedcope} ${mergedvarcope} ${mergedtdof} ; do
          rm -f ${File}.nii ${File}_subjects.nii ${File}.fsl.dscalar.nii
        done
        rm -f ${mask}_min.nii
      fi
    fi
    if [ "${DeleteIntermediates}" = "YES" ] ; then
      rm -r ${LevelThreeFEATDir}/${Analysis}/${i}
    fi
  done
  echo -e "\nDone FLAMEO\n"
  ##  --- END FLAMEO SECTION --- ##

done  # for Analysis in ${Analyses} ; do

### --- Generate Files for Workbench viewing --- ###
echo -e "\n----- Generating files for viewing -----"
for Analysis in ${Analyses} ; do
  StructureString=""
  if [ "$Analysis" = "HippocampusStats" ] ; then
      StructureString="_Hipp"
  fi
  case "$Analysis" in
      ParcellatedStats)
          StatInputExtension="nii"
          ScalarExtension="pscalar.nii"
          ;;
      HippocampusStats)
          StatInputExtension="dscalar.nii"
          ScalarExtension="dscalar.nii"
          ;;
      *)
          StatInputExtension="nii"
          Extension="dtseries.nii"
          ScalarExtension="dscalar.nii"
          ;;
  esac
  for MeasureType in ${DscalarMeasureList} ; do
  # Create a list of all possible unique files for each measure (i.e., zstat1, zstat2, ..., zstatN if MeasureType="zstat")
    cd ${LevelThreeFEATDir}/${Analysis}
    StatPrefixes=`ls -1 cope*.feat/${MeasureType}* 2> /dev/null || true`
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
        prefix="${PrefixAnalysisString}${LevelTwofsfName}_level3${StructureString}_${statistic}_${Contrast}${TemporalFilterString}${SmoothingString}${RegString}${ProcSTRING}${ParcellationString}"
        echo ${prefix} >> ${LevelThreeFEATDir}/Contrasttemp.txt
      	echo ${Contrast} >> ${LevelThreeFEATDir}/Contrasts.txt

        ## Subsection specific to Grayordinates analysis
        if [[ "$Analysis" = "GrayordinatesStats" || "$Analysis" = "ParcellatedStats" || "$Analysis" = "HippocampusStats" ]] ; then
	        input=${LevelThreeFEATDir}/${Analysis}/cope${i}.feat/${statistic}.${StatInputExtension}
	        if [ ! -e ${input} ] ; then
            log_Err_Abort "ERROR: ${input} does not exist"
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
	          log_Err_Abort "ERROR: ${input} does not exist"
	        fi
	        outputseries=${LevelThreeFEATDir}/${prefix}.${Extension}
	        outputscalar=${LevelThreeFEATDir}/${prefix}.${ScalarExtension}
	        ${CARET7DIR}/wb_command -cifti-create-dense-timeseries ${outputseries} -volume ${input} ${labeled_volume} -timestep 1 -timestart 1
	        ${CARET7DIR}/wb_command -cifti-convert-to-scalar ${outputseries} ROW ${outputscalar} -name-file ${LevelThreeFEATDir}/Contrasttemp.txt
	        rm ${outputseries} ${labeled_volume}
	        MergeSTRING=`echo "${MergeSTRING} -cifti ${outputscalar}"`

	        else
	          log_Err_Abort "ERROR: $Analysis not a valid analysis mode" 1>&2
	      fi
      
	      rm ${LevelThreeFEATDir}/Contrasttemp.txt
      done  # contrast loop

      # Merge across contrasts for a given statistic
      if [[ "$Analysis" = "GrayordinatesStats" || "$Analysis" = "ParcellatedStats" || "$Analysis" = "HippocampusStats" ]] ; then
        cifti_merge_out=${LevelThreeFEATDir}/${PrefixAnalysisString}${LevelTwofsfName}_level3${StructureString}_${statistic}${TemporalFilterString}${SmoothingString}${RegString}${ProcSTRING}${ParcellationString}.${ScalarExtension}
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

