#!/bin/bash
#~ND~FORMAT~MARKDOWN~
#~ND~START~
#
# # makeSubjectTaskSummary.sh
#
# ## Copyright (C) 2021 The Human Connectome Project
#
# * Washington University in St. Louis
#
# ## Author(s)
#
# * Greg Burgess, Washington University in St. Louis
#
# ## Product
#
# [Human Connectome Project][HCP] (HCP) Pipelines
#
# ## License
#
# See the [LICENSE](https://github.com/Washington-University/Pipelines/blob/master/LICENCE.md) file
#
# ## Description
#
# This script will create subject-level summary directory containing images required for
# group-level analyses. Script reads arguments set in TaskfMRIAnalysis.sh to determine
# which analyses were run (grayordinates, parcellated, volume) and at which "level"
# (Level1 vs. Level2). Script creates symlinks to Level2 outputs (if they exist) or
# outputs from single Level1. Unlike film / flameo, this script will use identical naming
# convention for Level1 and Level2 outputs. This allows group-level analyses to include
# subjects whether their outputs included one run or multiple runs.
#
#
# <!-- References -->
# [HCP]: http://www.humanconnectome.org
# [FSL]: http://fsl.fmrib.ox.ac.uk
#
#~ND~END~

set -eu

# ------------------------------------------------------------------------------
#  Check that HCPPIPEDIR is defined and Load Function Libraries
# ------------------------------------------------------------------------------

pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
    pipedirguessed=1
    export HCPPIPEDIR="$(dirname -- "$0")/.."
fi

source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/debug.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/fsl_version.shlib"	# Function for getting FSL version


# --------------------------------------------------------------------------------
#  Usage Description Function
# --------------------------------------------------------------------------------

#this function gets called by opts_ParseArguments when --help is specified
function usage()
{
    #header text
    echo "
$log_ToolName: Run TaskfMRIAnalysis pipeline for a subject. Pipeline will run Level1 (scan-level) analyses, and Level2 (single subject-level) analysis as specified.

Usage: $log_ToolName arguments...
[ ] = optional; < > = user supplied value
"
    #automatic argument descriptions
    opts_ShowArguments
    
    #do not use exit, the parsing code takes care of it
}

# ------------------------------------------------------------------------------
#  Parse Command Line Options
# ------------------------------------------------------------------------------

#arguments to opts_Add*: switch, variable to set, name for inside of <> in help text, description, [default value if AddOptional], [compatibility flag, ...]
#help info for option gets printed like "--foo=<$3> - $4"
opts_AddMandatory '--study-folder' 'Path' '/path/to/study/folder' "directory containing imaging data for all subjects"
opts_AddMandatory '--subject' 'Subject' 'SubjectID' ""
opts_AddMandatory '--lvl1tasks' 'LevelOnefMRINames' 'ScanName1@ScanName2' "List of task fMRI scan names, which are the prefixes of the time series filename for the TaskName task. Multiple task fMRI scan names should be provided as a single string separated by '@' character." #Assumes these subdirectories are located in the SubjectID/MNINonLinear/Results directory. Also assumes that timeseries image filename begins with this string.
opts_AddOptional '--lvl1fsfs' 'LevelOnefsfNames' 'DesignName1@DesignName2' "List of design names, which are the prefixes of the fsf filenames for each scan run. Should contain same number of design files as time series images in --lvl1tasks option. (N-th design will be used for N-th time series image.) Separate multiple design names by '@' character. If no value is passed to --lvl1fsfs, the value will be set to the same list passed to --lvl1tasks."
opts_AddOptional '--lvl2task' 'LevelTwofMRIName' 'tfMRI_TaskName' "Name of Level2 subdirectory in which all Level2 feat directories are written for TaskName. Default is 'NONE', which means that no Level2 analysis will run." 'NONE'
opts_AddOptional '--lvl2fsf' 'LevelTwofsfName' 'DesignName_TaskName' "Prefix of design.fsf filename for the Level2 analysis for TaskName. If no value is passed to --lvl2fsf, the value will be set to the same list passed to --lvl2task."
opts_AddOptional '--summaryname' 'SummaryName' 'tfMRI_TaskName/DesignName_TaskName' "Name used for single-subject summary directory. Mandatory when running Level1 analysis only. Default when running Level2 analysis is derived from --lvl2task and --lvl2fsf options \"tfMRI_TaskName/DesignName_TaskName\"" 'NONE'
opts_AddOptional '--confound' 'Confound' 'filename' "Confound matrix text filename (e.g., output of fsl_motion_outliers). Assumes file is located in <SubjectID>/MNINonLinear/Results/<ScanName>. Default='NONE'" 'NONE'
opts_AddOptional '--origsmoothingFWHM' 'OriginalSmoothingFWHM' 'number' "Value (in mm FWHM) of smoothing applied during surface registration in fMRISurface pipeline. Default=2, which is appropriate for HCP minimal preprocessing pipeline outputs" '2'
opts_AddOptional '--finalsmoothingFWHM' 'FinalSmoothingFWHM' 'number' "Value (in mm FWHM) of total desired smoothing, reached by calculating the additional smoothing required and applying that additional amount to data previously smoothed in fMRISurface. Default=2, which is no additional smoothing above HCP minimal preprocessing pipelines outputs." '2'
opts_AddOptional '--highpassfilter' 'TemporalFilter' 'integer' "Apply *additional* highpass filter (in seconds) to time series and task design. This is above and beyond temporal filter applied during preprocessing. To apply no additional filtering, set to 'NONE'. Default=200" '200'
opts_AddOptional '--lowpassfilter' 'TemporalSmoothing' 'integer' "Apply *additional* lowpass filter (in seconds) to time series and task design. This is above and beyond temporal filter applied during preprocessing. Low pass filter is generally not advised for Task fMRI analyses. Default=NONE" 'NONE'
opts_AddOptional '--procstring' 'ProcSTRING' 'string' "String value in filename of time series image, specifying the additional processing that was previously applied (e.g., FIX-cleaned data with 'hp2000_clean' in filename). Default=NONE" 'NONE'
opts_AddOptional '--lowresmesh' 'LowResMesh' 'integer' "Value (in mm) that matches surface resolution for fMRI data. Default=32, which is appropriate for HCP minimal preprocessing pipeline outputs" '32'
opts_AddOptional '--grayordinatesres' 'GrayordinatesResolution' 'number' "Value (in mm) that matches value in 'Atlas_ROIs' filename; Default='2', which is appropriate for HCP minimal preprocessing pipeline outputs" '2'
opts_AddOptional '--regname' 'RegName' 'RegName' "Name of surface registration technique. Default=NONE, which will use the default (MSMSulc) surface registration." 'NONE'
opts_AddOptional '--vba' 'VolumeBasedProcessing' 'YES/NO' "Default=NO. CAUTION: Only use YES if you want unconstrained volumetric blurring of your data, otherwise set to NO for faster, less biased, and more senstive processing (grayordinates results do not use unconstrained volumetric blurring and are always produced)" 'NO'
opts_AddOptional '--parcellation' 'Parcellation' 'ParcellationName' "Name of parcellation scheme to conduct parcellated analysis. Default=NONE, which will perform dense analysis instead. Non-greyordinates parcellations are not supported because they are not valid for cerebral cortex.  Parcellation supersedes smoothing (i.e. no smoothing is done)" 'NONE'
opts_AddOptional '--parcellationfile' 'ParcellationFile' '/path/to/dlabel' "Absolute path to the parcellation dlabel file. Default=NONE" 'NONE'

opts_ParseArguments "$@"

# if LevelOnefsfNames is blank, set equal to LevelOnefMRINames
[ -z "$LevelOnefsfNames" ] && LevelOnefsfNames=${LevelOnefMRINames}
# if LevelTwofsfName is blank, set equal to LevelTwofMRIName
[ -z "$LevelTwofsfName" ] && LevelTwofsfName=${LevelTwofMRIName}

#display the parsed/default values
opts_ShowValues


# ------------------------------------------------------------------------------
#  Verify required environment variables are set and log value
# ------------------------------------------------------------------------------

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

log_Msg "Platform Information Follows: "
uname -a

${HCPPIPEDIR}/show_version

log_Check_Env_Var HCPPIPEDIR
log_Check_Env_Var FSLDIR
log_Check_Env_Var CARET7DIR

HCPPIPEDIR_tfMRIAnalysis=${HCPPIPEDIR}/TaskfMRIAnalysis/scripts


##### SET_NAME_STRINGS: smoothing and filtering string variables used for file naming #####
SmoothingString="_s${FinalSmoothingFWHM}"

# Record prior preprocessing in filenames
if [ "${ProcSTRING}" != "NONE" ] ; then
	ProcSTRING="_${ProcSTRING}"
else
	ProcSTRING=""
fi

# Record additional highpass filter in filenames
if [ "${TemporalFilter}" != "NONE" ]; then
	TemporalFilterString="_hp""$TemporalFilter"
else
	TemporalFilterString="_hp0"
fi

# Record additional lowpass filter in filenames
if [ "${TemporalSmoothing}" != "NONE" ]; then
	LowPassSTRING="_lp""$TemporalSmoothing"
else
	LowPassSTRING=""
fi

# Set variables used for different registration procedures
if [ "${RegName}" != "NONE" ] ; then
	RegString="_${RegName}"
else
	RegString=""
fi

log_Msg "MAIN: SET_NAME_STRINGS: SmoothingString: ${SmoothingString}"
log_Msg "MAIN: SET_NAME_STRINGS: TemporalFilterString: ${TemporalFilterString}"
log_Msg "MAIN: SET_NAME_STRINGS: RegString: ${RegString}"


# Determine locations of necessary directories (using expected naming convention)
ResultsFolder="${Path}/${Subject}/MNINonLinear/Results"

# Determine which analyses need to be packaged into summary directory
# initialize list variables
Analyses=""; ExtensionList=""; ScalarExtensionList="";

# Determine whether to run Parcellated, and set strings used for filenaming
if [ "${Parcellation}" != "NONE" ] ; then
	# Run Parcellated Analyses
	ParcellationString="_${Parcellation}"
  ExtensionList="${ExtensionList}ptseries.nii "
	ScalarExtensionList="${ScalarExtensionList}pscalar.nii "
	Analyses+="ParcellatedStats "; # space character at end to separate multiple analyses
fi

# Determine whether to run Dense, and set strings used for filenaming
if [ "${Parcellation}" = "NONE" ]; then
	# Run Dense Analyses
	ParcellationString=""
	ExtensionList="${ExtensionList}dtseries.nii "
	ScalarExtensionList="${ScalarExtensionList}dscalar.nii "
	Analyses+="GrayordinatesStats "; # space character at end to separate multiple analyses
fi

# Determine whether to run Volume, and set strings used for filenaming
if [ "$VolumeBasedProcessing" = "YES" ] ; then
        if [ ${FinalSmoothingFWHM} -eq 0 ] ; then
	ExtensionList="nii.gz "
	ScalarExtensionList="volume.dscalar.nii "
	Analyses="StandardVolumeStats "; # space character at end to separate multiple analyses	
        else
	ExtensionList="${ExtensionList}nii.gz "
	ScalarExtensionList="${ScalarExtensionList}volume.dscalar.nii "
	Analyses+="StandardVolumeStats "; # space character at end to separate multiple analyses	
        fi
fi

if [[ "${SummaryName}" = "NONE" || "${SummaryName}" = "" ]]; then
	if [ "${LevelTwofMRIName}" = "NONE" ]; then
	    log_Err_Abort "Cannot determine summaryname. You must provide name for single-subject summary directory (--summaryname) if Level2 analysis is not being run."
	else
		SummaryName="${LevelTwofMRIName}/${LevelTwofsfName}";
	fi
   # Determine location where SummaryDirectory should be created
  SummaryDirectory="${ResultsFolder}/${SummaryName}${TemporalFilterString}${SmoothingString}${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}_subjectSummary.feat"
else
   # Determine location where SummaryDirectory should be created
  SummaryDirectory="${ResultsFolder}/${SummaryName}/${SummaryName}${TemporalFilterString}${SmoothingString}${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}_subjectSummary.feat"
fi

# Check if summary directory already exists, and remove old summary directory
if [ -d "$SummaryDirectory" ]; then
  echo "Removing previous summary directory from ${SummaryDirectory}..."
  rm -r "$SummaryDirectory"
fi

# Create new summary directory
echo "Creating new summary directory at ${SummaryDirectory}..."
mkdir -pv "$SummaryDirectory"

# Loop over analyses requested (runDense or runParcellation) && (runVolume)
log_Msg "Loop over analyses requested: ${Analyses}"
analysisCounter=1;
for Analysis in ${Analyses} ; do
	log_Msg "Make Summary for Analysis: ${Analysis}"
	Extension=`echo $ExtensionList | cut -d' ' -f $analysisCounter`;
	ScalarExtension=`echo $ScalarExtensionList | cut -d' ' -f $analysisCounter`;
	log_Msg "Using ${Extension} and ${ScalarExtension}"
	mkdir -pv "${SummaryDirectory}/${Analysis}"
	analysisCounter=$(($analysisCounter+1))

	# Check if Level2 analysis was requested
	if [ "$LevelTwofMRIName" != "NONE" ]; then
		echo "Using Level2"
		# Check if Level2 outputs are present, else throw error
		LevelTwoFEATDir="${ResultsFolder}/${LevelTwofMRIName}/${LevelTwofsfName}${TemporalFilterString}${SmoothingString}_level2${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}.feat"
		
		## Check for Contrasts.txt file in feat directory
		if [ ! -e "${LevelTwoFEATDir}/Contrasts.txt" ]; then
			# file is missing, write cope number and contrast name to log
			echo "ERROR: Cannot find Contrasts list at ${LevelTwoFEATDir}/Contrasts.txt. Verify that Level1 and Level2 analyses completed correctly." >> ${SummaryDirectory}/TaskfMRIAnalysisSummary.txt
			log_Err_Abort "ERROR: Cannot find Contrasts list at ${LevelTwoFEATDir}/Contrasts.txt. Verify that Level1 and Level2 analyses completed correctly."
		else
			ln -svf ${LevelTwoFEATDir}/Contrasts.txt ${SummaryDirectory}/Contrasts.txt
		fi
		
		copeCounter=1;
		cat ${LevelTwoFEATDir}/Contrasts.txt | while read Contrast ; do
			# Check if necessary files exist in cope${i}.feat directory (cope1 should be mean of two runs)
			if [ -e "${LevelTwoFEATDir}/${Analysis}/cope${copeCounter}.feat/cope1.${Extension}" ]; then
				echo "${Analysis}: cope${copeCounter} ($Contrast) exists" >> ${SummaryDirectory}/TaskfMRIAnalysisSummary.txt
			fi
			for File in mask cope1 varcope1 tdof_t1 ; do
				cifti_in=${LevelTwoFEATDir}/${Analysis}/cope${copeCounter}.feat/${File}.${Extension}
				if [ -e "$cifti_in" ]; then
					outdir=${SummaryDirectory}/${Analysis}/cope${copeCounter}.feat
					if [ ! -d "$outdir" ]; then
						mkdir -pv "$outdir";
					fi
					cifti_out=${SummaryDirectory}/${Analysis}/cope${copeCounter}.feat/${File}.${Extension}
					# create symlink to summary directory
					ln -svf $cifti_in $cifti_out
				else
					# file is missing, write cope number and contrast name to log
					shortName=$( echo $cifti_in | sed -e "s|${ResultsFolder}/||" );
					echo "${Analysis}: NOTE cope${copeCounter} ($Contrast) is missing file $shortName" >> ${SummaryDirectory}/TaskfMRIAnalysisSummary.txt
				fi
			done
			copeCounter=$(($copeCounter+1))
		done

	else	# If Level2 not requested, determine location of Level1
		echo "Using Level1"
		# Cut first value from list (ensure single value is clean)
		LevelOnefMRIName=$( echo $LevelOnefMRINames | cut -d'@' -f1 )
		LevelOnefsfName=$( echo $LevelOnefsfNames | cut -d'@' -f1 )

		# Determine which Level1 analysis was requested
		LevelOneFEATDir="${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefsfName}${TemporalFilterString}${SmoothingString}_level1${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}.feat"

		# Check if Level1 outputs are present, else throw error
		if [ ! -e "${LevelOneFEATDir}/design.con" ]; then
			# file is missing, write cope number and contrast name to log
			echo "ERROR: Cannot find Contrasts list at ${LevelOneFEATDir}/design.con. Verify that Level1 analysis completed correctly." >> ${SummaryDirectory}/TaskfMRIAnalysisSummary.txt
			log_Err_Abort "ERROR: Cannot find Contrasts list at ${LevelOneFEATDir}/design.con. Verify that Level1 analysis completed correctly."
		fi

		# Create mask and tdof files in tmp directory, to copy them into place as needed
		tmpdir=${SummaryDirectory}/${Analysis}/tmp
		mkdir -pv "$tmpdir"
		# Symlink Level1 dof and create tdof_t1 image file and mask file
		dof=`cat ${LevelOneFEATDir}/${Analysis}/dof`;
		if [[ "$Analysis" = "GrayordinatesStats" || "$Analysis" = "ParcellatedStats" ]] ; then
			${CARET7DIR}/wb_command -cifti-convert -to-nifti ${LevelOneFEATDir}/${Analysis}/res4d.${Extension} $tmpdir/res4d.nii.gz
		else
			ln -svf ${LevelOneFEATDir}/${Analysis}/res4d.nii.gz $tmpdir/res4d.nii.gz
		fi
		fslmaths $tmpdir/res4d.nii.gz -Tstd -bin $tmpdir/mask.nii.gz;
		fslmaths $tmpdir/mask.nii.gz -mul $dof $tmpdir/tdof_t1.nii.gz;
		
		if [[ "$Analysis" = "GrayordinatesStats" || "$Analysis" = "ParcellatedStats" ]] ; then
			for nifti_in in $tmpdir/{mask,tdof_t1}.nii.gz; do
				cifti_template=$( ls ${LevelOneFEATDir}/${Analysis}/pe*.${Extension} | head -1 )
				cifti_out=$( echo $nifti_in | sed -e "s|nii.gz|${Extension}|" )
				${CARET7DIR}/wb_command -cifti-convert -from-nifti ${nifti_in} ${cifti_template} ${cifti_out} -reset-timepoints 1 1 
			done
		fi
		# Make Contrasts.txt file in feat directory
		ContrastNames=`cat ${LevelOneFEATDir}/design.con | grep "ContrastName" | cut -f 2`
		NumContrasts=`cat ${LevelOneFEATDir}/design.con | grep "ContrastName" | wc -l`


	  ### Generate Files for Viewing
	  log_Msg "Generate Files for Viewing"
	  # Initialize strings used for fslmerge command
	  zMergeSTRING=""
	  bMergeSTRING=""
	  vMergeSTRING=""
	  touch ${SummaryDirectory}/Contrasttemp.txt
  	[ "${Analysis}" = "StandardVolumeStats" ] && touch ${SummaryDirectory}/wbtemp.txt


		copeCounter=1;
		while [ "$copeCounter" -le "${NumContrasts}" ] ; do
			Contrast=`echo $ContrastNames | cut -d " " -f $copeCounter`
			# Contrasts.txt is used to store the contrast names for this analysis
			# Avoid writing if contrasts have already been written
			lenContrastTextFile=$(cat ${SummaryDirectory}/Contrasts.txt 2>/dev/null | wc -l)
			if [ "$lenContrastTextFile" -lt "$NumContrasts" ]; then
				echo ${Contrast} >> ${SummaryDirectory}/Contrasts.txt
			fi
	
			# Check if necessary files exist in analysis directory
			# if files are missing, write cope number and contrast name to log
			for File in cope varcope zstat ; do
				cifti_in=${LevelOneFEATDir}/${Analysis}/${File}${copeCounter}.${Extension}
				shortName=$( echo $cifti_in | sed -e "s|${ResultsFolder}/||" );
				if [ -e "$cifti_in" ]; then
					outdir=${SummaryDirectory}/${Analysis}/cope${copeCounter}.feat
					if [ ! -d "$outdir" ]; then
						mkdir -pv "$outdir";
					fi
					cifti_out=${SummaryDirectory}/${Analysis}/cope${copeCounter}.feat/${File}1.${Extension}
					# create symlink to summary directory
					ln -svf $cifti_in $cifti_out
					echo "${Analysis}: NOTE ${File}${copeCounter} ($Contrast) copied from Level1 $shortName" >> ${SummaryDirectory}/TaskfMRIAnalysisSummary.txt
				else
					# file is missing, write cope number and contrast name to log
					echo "${Analysis}: NOTE ${File}${copeCounter} ($Contrast) Level1 is missing file $shortName" >> ${SummaryDirectory}/TaskfMRIAnalysisSummary.txt
				fi
			done
			cp -v $tmpdir/mask.${Extension} ${SummaryDirectory}/${Analysis}/cope${copeCounter}.feat/
			cp -v $tmpdir/tdof_t1.${Extension} ${SummaryDirectory}/${Analysis}/cope${copeCounter}.feat/


  		# Contrasttemp.txt is a temporary file used to name the maps in the CIFTI scalar file			
		  echo "${Subject}_${SummaryName}_level2_${Contrast}${TemporalFilterString}${SmoothingString}${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}" >> ${SummaryDirectory}/Contrasttemp.txt

		  if [ "${Analysis}" = "StandardVolumeStats" ] ; then

			  ### Make temporary dtseries files to convert into scalar files
			  # Converting volume to dense timeseries requires a volume label file
			  echo "OTHER" >> ${SummaryDirectory}/wbtemp.txt
			  echo "1 255 255 255 255" >> ${SummaryDirectory}/wbtemp.txt
			  ${CARET7DIR}/wb_command -volume-label-import ${SummaryDirectory}/${Analysis}/cope${copeCounter}.feat/mask.nii.gz ${SummaryDirectory}/wbtemp.txt ${SummaryDirectory}/${Analysis}/cope${copeCounter}.feat/mask.nii.gz -discard-others -unlabeled-value 0
			  rm ${SummaryDirectory}/wbtemp.txt

			  # Convert temporary volume CIFTI timeseries files
			  ${CARET7DIR}/wb_command -cifti-create-dense-timeseries ${SummaryDirectory}/${Subject}_${SummaryName}_level2_zstat_${Contrast}${TemporalFilterString}${SmoothingString}${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}.volume.dtseries.nii -volume ${SummaryDirectory}/StandardVolumeStats/cope${copeCounter}.feat/zstat1.nii.gz ${SummaryDirectory}/${Analysis}/cope${copeCounter}.feat/mask.nii.gz -timestep 1 -timestart 1
			  ${CARET7DIR}/wb_command -cifti-create-dense-timeseries ${SummaryDirectory}/${Subject}_${SummaryName}_level2_cope_${Contrast}${TemporalFilterString}${SmoothingString}${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}.volume.dtseries.nii -volume ${SummaryDirectory}/StandardVolumeStats/cope${copeCounter}.feat/cope1.nii.gz ${SummaryDirectory}/${Analysis}/cope${copeCounter}.feat/mask.nii.gz -timestep 1 -timestart 1
			  ${CARET7DIR}/wb_command -cifti-create-dense-timeseries ${SummaryDirectory}/${Subject}_${SummaryName}_level2_varcope_${Contrast}${TemporalFilterString}${SmoothingString}${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}.volume.dtseries.nii -volume ${SummaryDirectory}/StandardVolumeStats/cope${copeCounter}.feat/varcope1.nii.gz ${SummaryDirectory}/${Analysis}/cope${copeCounter}.feat/mask.nii.gz -timestep 1 -timestart 1

			  # Convert volume CIFTI timeseries files to scalar files
			  ${CARET7DIR}/wb_command -cifti-convert-to-scalar ${SummaryDirectory}/${Subject}_${SummaryName}_level2_zstat_${Contrast}${TemporalFilterString}${SmoothingString}${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}.volume.dtseries.nii ROW ${SummaryDirectory}/${Subject}_${SummaryName}_level2_zstat_${Contrast}${TemporalFilterString}${SmoothingString}${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}.${ScalarExtension} -name-file ${SummaryDirectory}/Contrasttemp.txt
			  ${CARET7DIR}/wb_command -cifti-convert-to-scalar ${SummaryDirectory}/${Subject}_${SummaryName}_level2_cope_${Contrast}${TemporalFilterString}${SmoothingString}${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}.volume.dtseries.nii ROW ${SummaryDirectory}/${Subject}_${SummaryName}_level2_cope_${Contrast}${TemporalFilterString}${SmoothingString}${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}.${ScalarExtension} -name-file ${SummaryDirectory}/Contrasttemp.txt
			  ${CARET7DIR}/wb_command -cifti-convert-to-scalar ${SummaryDirectory}/${Subject}_${SummaryName}_level2_varcope_${Contrast}${TemporalFilterString}${SmoothingString}${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}.volume.dtseries.nii ROW ${SummaryDirectory}/${Subject}_${SummaryName}_level2_varcope_${Contrast}${TemporalFilterString}${SmoothingString}${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}.${ScalarExtension} -name-file ${SummaryDirectory}/Contrasttemp.txt

			  # Delete the temporary volume CIFTI timeseries files
			  rm ${SummaryDirectory}/${Subject}_${SummaryName}_level2_{cope,varcope,zstat}_${Contrast}${TemporalFilterString}${SmoothingString}${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}.volume.dtseries.nii
		  else
			  ### Convert CIFTI dense or parcellated timeseries to scalar files
			  ${CARET7DIR}/wb_command -cifti-convert-to-scalar ${SummaryDirectory}/${Analysis}/cope${copeCounter}.feat/zstat1.${Extension} ROW ${SummaryDirectory}/${Subject}_${SummaryName}_level2_zstat_${Contrast}${TemporalFilterString}${SmoothingString}${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}.${ScalarExtension} -name-file ${SummaryDirectory}/Contrasttemp.txt
			  ${CARET7DIR}/wb_command -cifti-convert-to-scalar ${SummaryDirectory}/${Analysis}/cope${copeCounter}.feat/cope1.${Extension} ROW ${SummaryDirectory}/${Subject}_${SummaryName}_level2_cope_${Contrast}${TemporalFilterString}${SmoothingString}${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}.${ScalarExtension} -name-file ${SummaryDirectory}/Contrasttemp.txt
			  ${CARET7DIR}/wb_command -cifti-convert-to-scalar ${SummaryDirectory}/${Analysis}/cope${copeCounter}.feat/varcope1.${Extension} ROW ${SummaryDirectory}/${Subject}_${SummaryName}_level2_varcope_${Contrast}${TemporalFilterString}${SmoothingString}${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}.${ScalarExtension} -name-file ${SummaryDirectory}/Contrasttemp.txt
		  fi

		  # These merge strings are used below to combine the multiple scalar files into a single file for visualization
		  zMergeSTRING="${zMergeSTRING}-cifti ${SummaryDirectory}/${Subject}_${SummaryName}_level2_zstat_${Contrast}${TemporalFilterString}${SmoothingString}${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}.${ScalarExtension} "
		  bMergeSTRING="${bMergeSTRING}-cifti ${SummaryDirectory}/${Subject}_${SummaryName}_level2_cope_${Contrast}${TemporalFilterString}${SmoothingString}${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}.${ScalarExtension} "
		  vMergeSTRING="${vMergeSTRING}-cifti ${SummaryDirectory}/${Subject}_${SummaryName}_level2_varcope_${Contrast}${TemporalFilterString}${SmoothingString}${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}.${ScalarExtension} "

		  # Remove Contrasttemp.txt file
		  rm ${SummaryDirectory}/Contrasttemp.txt

			
			copeCounter=$(($copeCounter+1))
		done
		
		
	  # Perform the merge into viewable scalar files
	  ${CARET7DIR}/wb_command -cifti-merge ${SummaryDirectory}/${Subject}_${SummaryName}_level2_zstat${TemporalFilterString}${SmoothingString}${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}.${ScalarExtension} ${zMergeSTRING}
	  ${CARET7DIR}/wb_command -cifti-merge ${SummaryDirectory}/${Subject}_${SummaryName}_level2_cope${TemporalFilterString}${SmoothingString}${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}.${ScalarExtension} ${bMergeSTRING}
	  ${CARET7DIR}/wb_command -cifti-merge ${SummaryDirectory}/${Subject}_${SummaryName}_level2_varcope${TemporalFilterString}${SmoothingString}${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}.${ScalarExtension} ${vMergeSTRING}

		
		rm -r $tmpdir
	fi
done
