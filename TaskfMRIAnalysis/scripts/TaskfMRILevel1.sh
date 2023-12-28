#!/bin/bash

# Requirements for this script
#  installed versions of: FSL, Connectome Workbench (wb_command)
#  environment: HCPPIPEDIR, FSLDIR, CARET7DIR 

# --------------------------------------------------------------------------------
#  Usage Description Function
# --------------------------------------------------------------------------------

script_name=$(basename "${0}")

show_usage() {
	cat <<EOF

${script_name}: Sub-script of TaskfMRIAnalysis.sh

EOF
}

# Allow script to return a Usage statement, before any other output or checking
if [ "$#" = "0" ]; then
    show_usage
    exit 1
fi

# ------------------------------------------------------------------------------
#  Check that HCPPIPEDIR is defined and Load Function Libraries
# ------------------------------------------------------------------------------

if [ -z "${HCPPIPEDIR}" ]; then
  echo "${script_name}: ABORTING: HCPPIPEDIR environment variable must be set"
  exit 1
fi

source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@"         # Debugging functions; also sources log.shlib
source ${HCPPIPEDIR}/global/scripts/opts.shlib                 # Command line option functions
source ${HCPPIPEDIR}/global/scripts/fsl_version.shlib          # Function for getting FSL version

opts_ShowVersionIfRequested $@

if opts_CheckForHelpRequest $@; then
	show_usage
	exit 0
fi

# ------------------------------------------------------------------------------
#  Verify required environment variables are set and log value
# ------------------------------------------------------------------------------

log_Check_Env_Var HCPPIPEDIR
log_Check_Env_Var FSLDIR
log_Check_Env_Var CARET7DIR

# ------------------------------------------------------------------------------
#  Support Functions
# ------------------------------------------------------------------------------

show_tool_versions()
{
	# Show HCP pipelines version
	log_Msg "TOOL_VERSIONS: Showing HCP Pipelines version"
	"${HCPPIPEDIR}"/show_version --short

	# Show wb_command version
	log_Msg "TOOL_VERSIONS: Showing Connectome Workbench (wb_command) version"
	${CARET7DIR}/wb_command -version

	# Show fsl version
	fsl_version_get fsl_ver
}

# Log versions of tools used by this script
show_tool_versions


########################################## READ_ARGS ##################################

# Set variables from positional arguments to command line
Subject="$1"
ResultsFolder="$2"
ROIsFolder="$3"
DownSampleFolder="$4"
LevelOnefMRIName="$5"
LevelOnefsfName="$6"
LowResMesh="$7"
GrayordinatesResolution="$8"
OriginalSmoothingFWHM="$9"
Confound="${10}"
FinalSmoothingFWHM="${11}"
TemporalFilter="${12}"
VolumeBasedProcessing="${13}"
RegName="${14}"
Parcellation="${15}"
ParcellationFile="${16}"
ProcSTRING="${17}"
TemporalSmoothing="${18}"

log_Msg "READ_ARGS: ${script_name} arguments: $@"

# Log variables parsed from command line arguments
log_Msg "READ_ARGS: Subject: ${Subject}"
log_Msg "READ_ARGS: ResultsFolder: ${ResultsFolder}"
log_Msg "READ_ARGS: ROIsFolder: ${ROIsFolder}"
log_Msg "READ_ARGS: DownSampleFolder: ${DownSampleFolder}"
log_Msg "READ_ARGS: LevelOnefMRIName: ${LevelOnefMRIName}"
log_Msg "READ_ARGS: LevelOnefsfName: ${LevelOnefsfName}"
log_Msg "READ_ARGS: LowResMesh: ${LowResMesh}"
log_Msg "READ_ARGS: GrayordinatesResolution: ${GrayordinatesResolution}"
log_Msg "READ_ARGS: OriginalSmoothingFWHM: ${OriginalSmoothingFWHM}"
log_Msg "READ_ARGS: Confound: ${Confound}"
log_Msg "READ_ARGS: FinalSmoothingFWHM: ${FinalSmoothingFWHM}"
log_Msg "READ_ARGS: TemporalFilter: ${TemporalFilter}"
log_Msg "READ_ARGS: VolumeBasedProcessing: ${VolumeBasedProcessing}"
log_Msg "READ_ARGS: RegName: ${RegName}"
log_Msg "READ_ARGS: Parcellation: ${Parcellation}"
log_Msg "READ_ARGS: ParcellationFile: ${ParcellationFile}" 
log_Msg "READ_ARGS: ProcSTRING: ${ProcSTRING}" 
log_Msg "READ_ARGS: TemporalSmoothing: ${TemporalSmoothing}"


########################################## MAIN ##################################

##### DETERMINE ANALYSES TO RUN (DENSE, PARCELLATED, VOLUME) #####

# initialize run variables
runParcellated=false; runVolume=false; runDense=false;

# Determine whether to run Parcellated, and set strings used for filenaming
if [ "${Parcellation}" != "NONE" ] ; then
	# Run Parcellated Analyses
	runParcellated=true;
	ParcellationString="_${Parcellation}"
	Extension="ptseries.nii"
	log_Msg "MAIN: DETERMINE_ANALYSES: Parcellated Analysis requested"
fi

# Determine whether to run Dense, and set strings used for filenaming
if [ "${Parcellation}" = "NONE" ]; then
	# Run Dense Analyses
	runDense=true;
	ParcellationString=""
	Extension="dtseries.nii"
	log_Msg "MAIN: DETERMINE_ANALYSES: Dense Analysis requested"
fi

# Determine whether to run Volume, and set strings used for filenaming
if [ "$VolumeBasedProcessing" = "YES" ] ; then
	runVolume=true;
	log_Msg "MAIN: DETERMINE_ANALYSES: Volume Analysis requested"
        if [ ${FinalSmoothingFWHM} -eq 0 ] ; then
	      runDense=false;
	      log_Msg "MAIN: DETERMINE_ANALYSES: Requested Zero Final Smoothing, Running Unsmoothed Volume Analysis Only"
	fi
fi


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
	TemporalFilter="-1" # negative values turn filter off in fslmaths
fi

# Record additional lowpass filter in filenames
if [ "${TemporalSmoothing}" != "NONE" ]; then
	LowPassSTRING="_lp""$TemporalSmoothing"
else
	LowPassSTRING=""
	LowPassFilter="-1" # negative values turn filter off in fslmaths
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
log_Msg "MAIN: SET_NAME_STRINGS: ParcellationString: ${ParcellationString}"
log_Msg "MAIN: SET_NAME_STRINGS: Extension: ${Extension}"

##### CHECK_FILES: Check that necessary inputs exist before trying to use them #####
# Assemble list of input filenames that need to be checked
Filenames="";

# Need fsf files in scan-level directories
Filenames="$Filenames ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefsfName}_hp200_s4_level1.fsf"

if [[ -e "${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefsfName}_hp200_s4_level1.fsf" ]]; then
	# Need EVs referenced in fsf file
	while read line; do
		Filenames="$Filenames ${ResultsFolder}/${LevelOnefMRIName}/${line}"
	done <<< "$(grep -e 'set fmri(custom' ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefsfName}_hp200_s4_level1.fsf | \
	sed -e 's|../||' | cut -d'"' -f2)"
fi

# Need appropriate timeseries files
if $runParcellated; then
  if [ ! ${ParcellationFile} = "NONE" ] ; then
	  Filenames="$Filenames ${ParcellationFile}"
	  Filenames="$Filenames ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas${RegString}${ProcSTRING}.dtseries.nii"
  else
    if [ ! -e ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas${RegString}${ProcSTRING}${ParcellationString}.ptseries.nii ] ; then
      log_Err "Searching for ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas${RegString}${ProcSTRING}${ParcellationString}.ptseries.nii"
      log_Err_Abort "MAIN: Pipeline was told to expect that matching parcellated timeseries was already generated (--parcellation!=NONE and --parcellationfile=NONE) but it was not found"
    fi
    Filenames="$Filenames ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas${RegString}${ProcSTRING}${ParcellationString}.ptseries.nii"
  fi
fi
if $runDense ; then
	Filenames="$Filenames ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas${RegString}${ProcSTRING}.dtseries.nii"
fi
if $runVolume ; then
	Filenames="$Filenames ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}${ProcSTRING}.nii.gz"
fi

# Need midthickness GIFTI surfaces
Filenames="$Filenames ${DownSampleFolder}/${Subject}.L.midthickness${RegString}.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.R.midthickness${RegString}.${LowResMesh}k_fs_LR.surf.gii"

# Need Atlas_ROIs volume file
Filenames="$Filenames $ROIsFolder/Atlas_ROIs.${GrayordinatesResolution}.nii.gz"

# Need atlasroi GIFTI shape files
Filenames="$Filenames ${DownSampleFolder}/${Subject}.L.atlasroi.${LowResMesh}k_fs_LR.shape.gii ${DownSampleFolder}/${Subject}.R.atlasroi.${LowResMesh}k_fs_LR.shape.gii"

# Now check each file in list
missingFiles="";
for Filename in $Filenames; do
	# if file does not exist, save $Filename for use by errMsg
	if [[ ! -e "$Filename" ]]; then
		missingFiles+="${Filename} "
	fi
done

# if missing files, then throw an error and abort
if [[ -n "${missingFiles}" ]]; then
    errMsg="Missing necessary input files: ${missingFiles}"
	log_Err_Abort $errMsg
fi

# if no missing files, then carry on
log_Msg "CHECK INPUTS: Necessary input files exist"



##### IMAGE_INFO: DETERMINE TR AND SCAN LENGTH #####
# Extract TR information from input time series files

if $runParcellated; then
  if [ ! ${ParcellationFile} = "NONE" ] ; then
	  File="${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas${RegString}${ProcSTRING}.dtseries.nii"
  else
    File="${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas${RegString}${ProcSTRING}${ParcellationString}.ptseries.nii"
  fi
fi
if $runDense ; then
	File="${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas${RegString}${ProcSTRING}.dtseries.nii"
fi
if $runVolume ; then
	File="${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}${ProcSTRING}.nii.gz"
fi

TR_vol=`${CARET7DIR}/wb_command -file-information ${File} -no-map-info -only-step-interval`
log_Msg "MAIN: IMAGE_INFO: TR_vol: ${TR_vol}"

# Extract number of time points in CIFTI time series file
npts=`${CARET7DIR}/wb_command -file-information ${File} -no-map-info -only-number-of-maps`
log_Msg "MAIN: IMAGE_INFO: npts: ${npts}"


##### MAKE_DESIGNS: MAKE DESIGN FILES #####

# Create output .feat directory ($FEATDir) for this analysis
FEATDir="${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefsfName}${TemporalFilterString}${SmoothingString}_level1${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}.feat"
log_Msg "MAIN: MAKE_DESIGNS: FEATDir: ${FEATDir}"
if [[ -e "${FEATDir}" ]] ; then
	rm -r ${FEATDir}
	mkdir ${FEATDir}
else
	mkdir -p ${FEATDir}
fi

### Edit fsf file to record the parameters used in this analysis
# Copy template fsf file into $FEATDir
log_Msg "MAIN: MAKE_DESIGNS: Copying fsf file to .feat directory"
cp ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefsfName}_hp200_s4_level1.fsf ${FEATDir}/design.fsf

# Change the highpass filter string to the desired highpass filter
log_Msg "MAIN: MAKE_DESIGNS: Change design.fsf: Set highpass filter string to the desired highpass filter to ${TemporalFilter}"
sed -i -e "s|set fmri(paradigm_hp) 200|set fmri(paradigm_hp) ${TemporalFilter}|g" ${FEATDir}/design.fsf
if [ ${TemporalFilter} -eq -1 ] ; then
  sed -i -e "s|set fmri(temphp_yn) 1|set fmri(temphp_yn) 0|g" ${FEATDir}/design.fsf
  sed -i -e "s|^\(set fmri(tempfilt_yn[0-9])\) 1|\1 0|g" ${FEATDir}/design.fsf  
fi

# Change smoothing to be equal to additional smoothing in FSF file
log_Msg "MAIN: MAKE_DESIGNS: Change design.fsf: Set smoothing to be equal to final smoothing to ${FinalSmoothingFWHM}"
sed -i -e "s|set fmri(smooth) 4|set fmri(smooth) ${FinalSmoothingFWHM}|g" ${FEATDir}/design.fsf

# Change output directory name to match total smoothing and highpass
log_Msg "MAIN: MAKE_DESIGNS: Change design.fsf: Change string in output directory name to ${TemporalFilterString}${SmoothingString}_level1${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}"
sed -i -e "s|_hp200_s4|${TemporalFilterString}${SmoothingString}_level1${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}|g" ${FEATDir}/design.fsf

# find current value for npts in template.fsf
fsfnpts=`grep "set fmri(npts)" ${FEATDir}/design.fsf | cut -d " " -f 3 | sed 's|"||g'`;

# Ensure number of time points in fsf matches time series image
if [ "$fsfnpts" -eq "$npts" ] ; then
	log_Msg "MAIN: MAKE_DESIGNS: Change design.fsf: Scan length matches number of timepoints in template.fsf: ${fsfnpts}"
else
	log_Msg "MAIN: MAKE_DESIGNS: Change design.fsf: Warning! Scan length does not match template.fsf!"
	log_Msg "MAIN: MAKE_DESIGNS: Change design.fsf: Warning! Changing Number of Timepoints in fsf (""${fsfnpts}"") to match time series image (""${npts}"")"
	sed -i -e  "s|set fmri(npts) \"\?${fsfnpts}\"\?|set fmri(npts) ${npts}|g" ${FEATDir}/design.fsf
fi

# Use grep to find lines in fsf that list EV text files. Those lines look like this:
# set fmri(custom1) "../EVs/guess.txt"
# set fmri(custom2) "../EVs/miss.txt"
grep -e 'fmri(custom' < ${FEATDir}/design.fsf | while read line; do
	# Figure out which EV number this is (sed to remove characters before and after EV number)
	custom=`echo $line | sed -e 's|.*custom||' -e 's|).*||' `;
	# get path to EV from text between double-quotes
	ev=`echo $line | cut -d\" -f2`;
	# Find length (number of lines) for EV, assuming path to EVs is relative to $FEATDir
	count=`awk '{ if ($3 != 0) print $0 }' ${FEATDir}/$ev |wc -l`;

	if [ $count -eq 0 ]; # if EV is empty
	then
		# Change the EV shape to Empty EV shape
		# set fmri(shape2) 3  # custom 3-column
		# set fmri(shape2) 10 # empty EV
		sed -i -e "s|fmri(shape${custom}).*|fmri(shape${custom}) 10|" ${FEATDir}/design.fsf
		log_Msg "EMPTY custom${custom} $ev $count in fsf";
	else
		log_Msg "FULL  custom${custom} $ev $count in fsf";
	fi;
done

### Use fsf to create additional design files used by film_gls
log_Msg "MAIN: MAKE_DESIGNS: Create design files, model confounds if desired"
# Determine if there is a confound matrix text file (e.g., output of fsl_motion_outliers)
confound_matrix="";
if [ "$Confound" != "NONE" ] ; then
	confound_matrix=$( ls -d ${ResultsFolder}/${LevelOnefMRIName}/${Confound} 2>/dev/null )
fi

# Run feat_model inside $FEATDir
cd $FEATDir # so feat_model can interpret relative paths in fsf file
feat_model design ${confound_matrix}; # $confound_matrix string is blank if file is missing
cd $OLDPWD	# OLDPWD is shell variable previous working directory

# Set variables for additional design files
DesignMatrix=${FEATDir}/design.mat
DesignContrasts=${FEATDir}/design.con
DesignfContrasts=${FEATDir}/design.fts

# An F-test may not always be requested as part of the design.fsf
ExtraArgs=""
if [ -e "${DesignfContrasts}" ] ; then
	ExtraArgs="$ExtraArgs --fcon=${DesignfContrasts}"
fi


##### SMOOTH_OR_PARCELLATE: APPLY SPATIAL SMOOTHING (or parcellation) #####

### Parcellate data if a Parcellation was provided
# Parcellation may be better than adding spatial smoothing to dense time series.
# Parcellation increases sensitivity and statistical power, but avoids blurring signal 
# across region boundaries into adjacent, non-activated regions.
log_Msg "MAIN: SMOOTH_OR_PARCELLATE: PARCELLATE: Parcellate data if a Parcellation was provided"
if $runParcellated; then
	if [ ! ${ParcellationFile} = "NONE" ] ; then
	  log_Msg "MAIN: SMOOTH_OR_PARCELLATE: PARCELLATE: Parcellating data"
	  log_Msg "MAIN: SMOOTH_OR_PARCELLATE: PARCELLATE: Notice: currently parcellated time series has $SmoothingString in file name, but no additional smoothing was applied!"
	  # SmoothingString in parcellated filename allows subsequent commands to work for either dtseries or ptseries
	  ${CARET7DIR}/wb_command -cifti-parcellate ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas${RegString}${ProcSTRING}.dtseries.nii ${ParcellationFile} COLUMN ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas${SmoothingString}${RegString}${ProcSTRING}${ParcellationString}.${Extension}
  else
    log_Msg "MAIN: SMOOTH_OR_PARCELLATE: PARCELLATE: Matching parcellated timeseries file already exists and will be used"
    log_Msg "MAIN: SMOOTH_OR_PARCELLATE: PARCELLATE: Notice: currently parcellated time series has $SmoothingString in file name, but no additional smoothing was applied!"
    cp ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas${RegString}${ProcSTRING}${ParcellationString}.${Extension} ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas${SmoothingString}${RegString}${ProcSTRING}${ParcellationString}.${Extension}
  fi
fi

### Apply spatial smoothing to CIFTI dense analysis
if $runDense ; then
	if [ "$FinalSmoothingFWHM" -gt "$OriginalSmoothingFWHM" ] ; then
		# Some smoothing was already conducted in fMRISurface Pipeline. To reach the desired
		# total level of smoothing, the additional spatial smoothing added here must be reduced
		# by the original smoothing applied earlier
		AdditionalSmoothingFWHM=`echo "sqrt(( $FinalSmoothingFWHM ^ 2 ) - ( $OriginalSmoothingFWHM ^ 2 ))" | bc -l`
		AdditionalSigma=`echo "$AdditionalSmoothingFWHM / (2 * sqrt(2 * l(2)))" | bc -l`
		log_Msg "MAIN: SMOOTH_OR_PARCELLATE: SMOOTH_CIFTI: AdditionalSmoothingFWHM: ${AdditionalSmoothingFWHM}"
		log_Msg "MAIN: SMOOTH_OR_PARCELLATE: SMOOTH_CIFTI: AdditionalSigma: ${AdditionalSigma}"
		log_Msg "MAIN: SMOOTH_OR_PARCELLATE: SMOOTH_CIFTI: Applying additional surface smoothing to CIFTI Dense data"
		${CARET7DIR}/wb_command -cifti-smoothing ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas${RegString}${ProcSTRING}.dtseries.nii ${AdditionalSigma} ${AdditionalSigma} COLUMN ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas${SmoothingString}${RegString}${ProcSTRING}.dtseries.nii -left-surface ${DownSampleFolder}/${Subject}.L.midthickness${RegString}.${LowResMesh}k_fs_LR.surf.gii -right-surface ${DownSampleFolder}/${Subject}.R.midthickness${RegString}.${LowResMesh}k_fs_LR.surf.gii
	else
		if [ "$FinalSmoothingFWHM" -eq "$OriginalSmoothingFWHM" ]; then
			log_Msg "MAIN: SMOOTH_OR_PARCELLATE: SMOOTH_CIFTI: No additional surface smoothing requested for CIFTI Dense data"
		else
			log_Msg "MAIN: SMOOTH_OR_PARCELLATE: SMOOTH_CIFTI: WARNING: For CIFTI Dense data, the surface smoothing requested \($FinalSmoothingFWHM\) is LESS than the surface smoothing already applied \(${OriginalSmoothingFWHM}\)."
			log_Msg "MAIN: SMOOTH_OR_PARCELLATE: SMOOTH_CIFTI: Continuing analysis with ${OriginalSmoothingFWHM} of total surface smoothing."
		fi
		cp ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas${RegString}${ProcSTRING}.dtseries.nii ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas${SmoothingString}${RegString}${ProcSTRING}.dtseries.nii
	fi
fi

### Apply spatial smoothing to volume analysis
if $runVolume ; then
        if [ ${FinalSmoothingFWHM} -eq 0 ] ; then
	    log_Msg "MAIN: SMOOTH_OR_PARCELLATE: SMOOTH_NIFTI: Zero Smoothing Requested, Don't Smooth"
	    SmoothedDilatedResultFile=${FEATDir}/${LevelOnefMRIName}${ProcSTRING}${SmoothingString}_dilMrim
            imcp ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}${ProcSTRING} ${SmoothedDilatedResultFile}
	else
	
	log_Msg "MAIN: SMOOTH_OR_PARCELLATE: SMOOTH_NIFTI: Standard NIFTI Volume-based Processsing"

	#Add edge-constrained volume smoothing
	log_Msg "MAIN: SMOOTH_OR_PARCELLATE: SMOOTH_NIFTI: Add edge-constrained volume smoothing"
	FinalSmoothingSigma=`echo "$FinalSmoothingFWHM / (2 * sqrt(2 * l(2)))" | bc -l`
	InputfMRI=${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}${ProcSTRING}
	InputSBRef=${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_SBRef
	fslmaths ${InputSBRef} -bin ${FEATDir}/mask_orig
	fslmaths ${FEATDir}/mask_orig -kernel gauss ${FinalSmoothingSigma} -fmean ${FEATDir}/mask_orig_weight -odt float
	fslmaths ${InputfMRI} -kernel gauss ${FinalSmoothingSigma} -fmean \
	  -div ${FEATDir}/mask_orig_weight -mas ${FEATDir}/mask_orig \
	  ${FEATDir}/${LevelOnefMRIName}${ProcSTRING}${SmoothingString} -odt float

	#Add volume dilation
	#
	# For some subjects, FreeSurfer-derived brain masks (applied to the time 
	# series data in IntensityNormalization.sh as part of 
	# GenericfMRIVolumeProcessingPipeline.sh) do not extend to the edge of brain
	# in the MNI152 space template. This is due to the limitations of volume-based
	# registration. So, to avoid a lack of coverage in a group analysis around the
	# penumbra of cortex, we will add a single dilation step to the input prior to
	# creating the Level1 maps.
	#
	# Ideally, we would condition this dilation on the resolution of the fMRI 
	# data.  Empirically, a single round of dilation gives very good group 
	# coverage of MNI brain for the 2 mm resolution of HCP fMRI data. So a single
	# dilation is what we use below.
	#
	# Note that for many subjects, this dilation will result in signal extending
	# BEYOND the limits of brain in the MNI152 template.  However, that is easily
	# fixed by masking with the MNI space brain template mask if so desired.
	#
	# The specific implementation involves:
	# a) Edge-constrained spatial smoothing on the input fMRI time series (and masking
	#    that back to the original mask).  This step was completed above.
	# b) Spatial dilation of the input fMRI time series, followed by edge constrained smoothing
	# c) Adding the voxels from (b) that are NOT part of (a) into (a).
	#
	# The motivation for this implementation is that:
	# 1) Identical voxel-wise results are obtained within the original mask.  So, users
	#    that desire the original ("tight") FreeSurfer-defined brain mask (which is
	#    implicitly represented as the non-zero voxels in the InputSBRef volume) can
	#    mask back to that if they chose, with NO impact on the voxel-wise results.
	# 2) A simpler possible approach of just dilating the result of step (a) results in 
	#    an unnatural pattern of dark/light/dark intensities at the edge of brain,
	#    whereas the combination of steps (b) and (c) yields a more natural looking 
	#    transition of intensities in the added voxels.
	log_Msg "MAIN: SMOOTH_OR_PARCELLATE: SMOOTH_NIFTI: Add volume dilation"

	# Dilate the original BOLD time series, then do (edge-constrained) smoothing
	fslmaths ${FEATDir}/mask_orig -dilM -bin ${FEATDir}/mask_dilM
	fslmaths ${FEATDir}/mask_dilM \
	  -kernel gauss ${FinalSmoothingSigma} -fmean ${FEATDir}/mask_dilM_weight -odt float
	fslmaths ${InputfMRI} -dilM -kernel gauss ${FinalSmoothingSigma} -fmean \
	  -div ${FEATDir}/mask_dilM_weight -mas ${FEATDir}/mask_dilM \
	  ${FEATDir}/${LevelOnefMRIName}${ProcSTRING}_dilM${SmoothingString} -odt float

	# Take just the additional "rim" voxels from the dilated then smoothed time series, and add them
	# into the smoothed time series (that didn't have any dilation)
	SmoothedDilatedResultFile=${FEATDir}/${LevelOnefMRIName}${ProcSTRING}${SmoothingString}_dilMrim
	fslmaths ${FEATDir}/mask_orig -binv ${FEATDir}/mask_orig_inv
	fslmaths ${FEATDir}/${LevelOnefMRIName}${ProcSTRING}_dilM${SmoothingString} \
	  -mas ${FEATDir}/mask_orig_inv \
	  -add ${FEATDir}/${LevelOnefMRIName}${ProcSTRING}${SmoothingString} \
	  ${SmoothedDilatedResultFile}
	  
        fi
fi # end Volume spatial smoothing


##### APPLY TEMPORAL FILTERING #####
# Issue 1: Temporal filtering is conducted by fslmaths, but fslmaths is not CIFTI-compliant. 
# Convert CIFTI to "fake" NIFTI file, use FSL tools (fslmaths), then convert "fake" NIFTI back to CIFTI.
# Issue 2: fslmaths -bptf removes timeseries mean (for FSL 5.0.7 onward). film_gls expects mean in image. 
# So, save the mean to file, then add it back after -bptf.

if [[ "${TemporalFilter}" == "-1" && "${LowPassFilter}" == "-1" ]]; then
	log_Msg "MAIN: TEMPORAL_FILTER: Highpass and Lowpass values set to NONE. Skipping fslmaths -bptf ..."
	if $runVolume; then
		# We drop the "dilMrim" string from the output file name, so as to avoid breaking
		# any downstream scripts.
		imcp ${SmoothedDilatedResultFile} ${FEATDir}/${LevelOnefMRIName}${TemporalFilterString}${SmoothingString}
	fi
	if [[ $runParcellated == true || $runDense == true ]]; then
		cp ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas${SmoothingString}${RegString}${ProcSTRING}${ParcellationString}.${Extension} ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas${TemporalFilterString}${SmoothingString}${RegString}${ProcSTRING}${ParcellationString}.${Extension}
	fi
else
	# Compute smoothing kernel sigma: By default, feat_model divides by 2 as an approximation
	# More accurately, sigma = FWHM / (2*sqrt(2*ln(2))) = FWHM / 2.355
	if [ "${TemporalFilter}" != "-1" ]; then
		hp_sigma=$(echo "( $TemporalFilter / $TR_vol ) / 2 " | bc -l);
	else
		hp_sigma=-1;
	fi
	if [ "${LowPassFilter}" != "-1" ]; then
		lp_sigma=$(echo "( $TemporalSmoothing / $TR_vol ) / 2 " | bc -l)
	else
		lp_sigma=-1;
	fi
	if [[ $runParcellated == true || $runDense == true ]]; then
		log_Msg "MAIN: TEMPORAL_FILTER: Add temporal filtering to CIFTI file"
		# Convert CIFTI to "fake" NIFTI
		${CARET7DIR}/wb_command -cifti-convert -to-nifti ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas${SmoothingString}${RegString}${ProcSTRING}${ParcellationString}.${Extension} ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas${SmoothingString}${RegString}${ProcSTRING}${ParcellationString}_FAKENIFTI.nii.gz
		# Save mean image
		fslmaths ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas${SmoothingString}${RegString}${ProcSTRING}${ParcellationString}_FAKENIFTI.nii.gz -Tmean ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas${SmoothingString}${RegString}${ProcSTRING}${ParcellationString}_FAKENIFTI_mean.nii.gz
		# Use fslmaths to apply high pass filter and then add mean back to image
		fslmaths ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas${SmoothingString}${RegString}${ProcSTRING}${ParcellationString}_FAKENIFTI.nii.gz -bptf ${hp_sigma} ${lp_sigma} \
		   -add ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas${SmoothingString}${RegString}${ProcSTRING}${ParcellationString}_FAKENIFTI_mean.nii.gz \
		   ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas${SmoothingString}${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}_FAKENIFTI.nii.gz
		# Convert "fake" NIFTI back to CIFTI
		${CARET7DIR}/wb_command -cifti-convert -from-nifti ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas${SmoothingString}${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}_FAKENIFTI.nii.gz ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas${SmoothingString}${RegString}${ProcSTRING}${ParcellationString}.${Extension} ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas${TemporalFilterString}${SmoothingString}${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}.${Extension}
		# Cleanup the "fake" NIFTI files
		rm ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas${SmoothingString}${RegString}${ProcSTRING}${ParcellationString}_FAKENIFTI.nii.gz ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas${SmoothingString}${RegString}${ProcSTRING}${ParcellationString}_FAKENIFTI_mean.nii.gz
	fi
	if $runVolume; then
		#Add temporal filtering to the output from above
		log_Msg "MAIN: TEMPORAL_FILTER: Add temporal filtering to NIFTI file"
		# Temporal filtering is conducted by fslmaths. 
		# fslmaths -bptf removes timeseries mean (for FSL 5.0.7 onward), which is expected by film_gls. 
		# So, save the mean to file, then add it back after -bptf.
		# We drop the "dilMrim" string from the output file name, so as to avoid breaking
		# any downstream scripts.
		fslmaths ${SmoothedDilatedResultFile} -Tmean ${SmoothedDilatedResultFile}_mean
		fslmaths ${SmoothedDilatedResultFile} -bptf ${hp_sigma} ${lp_sigma} \
		  -add ${SmoothedDilatedResultFile}_mean \
		  ${FEATDir}/${LevelOnefMRIName}${TemporalFilterString}${SmoothingString}.nii.gz
	fi
fi



##### RUN film_gls (GLM ANALYSIS ON LEVEL 1) #####

# Run CIFTI Dense Grayordinates Analysis (if requested)
if $runDense ; then
	# Dense Grayordinates Processing
	log_Msg "MAIN: RUN_GLM: Dense Grayordinates Analysis"
	#Split into surface and volume
	log_Msg "MAIN: RUN_GLM: Split into surface and volume"
	${CARET7DIR}/wb_command -cifti-separate-all ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas${TemporalFilterString}${SmoothingString}${RegString}${ProcSTRING}${LowPassSTRING}.dtseries.nii -volume ${FEATDir}/${LevelOnefMRIName}_AtlasSubcortical${TemporalFilterString}${SmoothingString}.nii.gz -left ${FEATDir}/${LevelOnefMRIName}${TemporalFilterString}${SmoothingString}${RegString}${ProcSTRING}${LowPassSTRING}.atlasroi.L.${LowResMesh}k_fs_LR.func.gii -right ${FEATDir}/${LevelOnefMRIName}${TemporalFilterString}${SmoothingString}${RegString}${ProcSTRING}${LowPassSTRING}.atlasroi.R.${LowResMesh}k_fs_LR.func.gii

	#Run film_gls on subcortical volume data
	log_Msg "MAIN: RUN_GLM: Run film_gls on subcortical volume data"
	film_gls --rn=${FEATDir}/SubcorticalVolumeStats --sa --ms=5 --in=${FEATDir}/${LevelOnefMRIName}_AtlasSubcortical${TemporalFilterString}${SmoothingString}.nii.gz --pd=${DesignMatrix} --con=${DesignContrasts} ${ExtraArgs} --thr=1 --mode=volumetric
	rm ${FEATDir}/${LevelOnefMRIName}_AtlasSubcortical${TemporalFilterString}${SmoothingString}.nii.gz

	#Run film_gls on cortical surface data 
	log_Msg "MAIN: RUN_GLM: Run film_gls on cortical surface data"
	for Hemisphere in L R ; do
		#Prepare for film_gls  
		log_Msg "MAIN: RUN_GLM: Prepare for film_gls"
		${CARET7DIR}/wb_command -metric-dilate ${FEATDir}/${LevelOnefMRIName}${TemporalFilterString}${SmoothingString}${RegString}${ProcSTRING}${LowPassSTRING}.atlasroi.${Hemisphere}.${LowResMesh}k_fs_LR.func.gii ${DownSampleFolder}/${Subject}.${Hemisphere}.midthickness${RegString}.${LowResMesh}k_fs_LR.surf.gii 50 ${FEATDir}/${LevelOnefMRIName}${TemporalFilterString}${SmoothingString}${RegString}${ProcSTRING}${LowPassSTRING}.atlasroi_dil.${Hemisphere}.${LowResMesh}k_fs_LR.func.gii -nearest

		#Run film_gls on surface data
		log_Msg "MAIN: RUN_GLM: Run film_gls on surface data"
		film_gls --rn=${FEATDir}/${Hemisphere}_SurfaceStats --sa --ms=15 --epith=5 --in2=${DownSampleFolder}/${Subject}.${Hemisphere}.midthickness${RegString}.${LowResMesh}k_fs_LR.surf.gii --in=${FEATDir}/${LevelOnefMRIName}${TemporalFilterString}${SmoothingString}${RegString}${ProcSTRING}${LowPassSTRING}.atlasroi_dil.${Hemisphere}.${LowResMesh}k_fs_LR.func.gii --pd=${DesignMatrix} --con=${DesignContrasts} ${ExtraArgs} --mode=surface
		rm ${FEATDir}/${LevelOnefMRIName}${TemporalFilterString}${SmoothingString}${RegString}${ProcSTRING}${LowPassSTRING}.atlasroi_dil.${Hemisphere}.${LowResMesh}k_fs_LR.func.gii ${FEATDir}/${LevelOnefMRIName}${TemporalFilterString}${SmoothingString}${RegString}${ProcSTRING}${LowPassSTRING}.atlasroi.${Hemisphere}.${LowResMesh}k_fs_LR.func.gii
	done

	# Merge Cortical Surface and Subcortical Volume into Grayordinates
	log_Msg "MAIN: RUN_GLM: Merge Cortical Surface and Subcortical Volume into Grayordinates"
	mkdir ${FEATDir}/GrayordinatesStats
	cat ${FEATDir}/SubcorticalVolumeStats/dof > ${FEATDir}/GrayordinatesStats/dof
	cat ${FEATDir}/SubcorticalVolumeStats/logfile > ${FEATDir}/GrayordinatesStats/logfile
	cat ${FEATDir}/L_SurfaceStats/logfile >> ${FEATDir}/GrayordinatesStats/logfile
	cat ${FEATDir}/R_SurfaceStats/logfile >> ${FEATDir}/GrayordinatesStats/logfile

	for Subcortical in ${FEATDir}/SubcorticalVolumeStats/*nii.gz ; do
		File=$( basename $Subcortical .nii.gz );
		${CARET7DIR}/wb_command -cifti-create-dense-timeseries ${FEATDir}/GrayordinatesStats/${File}.dtseries.nii -volume $Subcortical $ROIsFolder/Atlas_ROIs.${GrayordinatesResolution}.nii.gz -left-metric ${FEATDir}/L_SurfaceStats/${File}.func.gii -roi-left ${DownSampleFolder}/${Subject}.L.atlasroi.${LowResMesh}k_fs_LR.shape.gii -right-metric ${FEATDir}/R_SurfaceStats/${File}.func.gii -roi-right ${DownSampleFolder}/${Subject}.R.atlasroi.${LowResMesh}k_fs_LR.shape.gii
	done
	rm -r ${FEATDir}/SubcorticalVolumeStats ${FEATDir}/L_SurfaceStats ${FEATDir}/R_SurfaceStats
fi

# Run CIFTI Parcellated Analysis (if requested)
if $runParcellated ; then
	# Parcellated Processing
	log_Msg "MAIN: RUN_GLM: Parcellated Analysis"
	# Convert CIFTI to "fake" NIFTI
	${CARET7DIR}/wb_command -cifti-convert -to-nifti ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas${TemporalFilterString}${SmoothingString}${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}.${Extension} ${FEATDir}/${LevelOnefMRIName}_Atlas${TemporalFilterString}${SmoothingString}${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}_FAKENIFTI.nii.gz
	# Now run film_gls on the fakeNIFTI file
	film_gls --rn=${FEATDir}/ParcellatedStats --in=${FEATDir}/${LevelOnefMRIName}_Atlas${TemporalFilterString}${SmoothingString}${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}_FAKENIFTI.nii.gz --pd=${DesignMatrix} --con=${DesignContrasts} ${ExtraArgs} --thr=1 --mode=volumetric
	ls ${FEATDir}/ParcellatedStats
	# Remove "fake" NIFTI time series file
	rm ${FEATDir}/${LevelOnefMRIName}_Atlas${TemporalFilterString}${SmoothingString}${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}_FAKENIFTI.nii.gz
	# Convert "fake" NIFTI output files (copes, varcopes, zstats) back to CIFTI
	templateCIFTI=${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas${SmoothingString}${RegString}${ProcSTRING}${ParcellationString}.${Extension}
	for fakeNIFTI in `ls ${FEATDir}/ParcellatedStats/*.nii.gz` ; do
		CIFTI=$( echo $fakeNIFTI | sed -e "s|.nii.gz|.${Extension}|" );
		${CARET7DIR}/wb_command -cifti-convert -from-nifti $fakeNIFTI $templateCIFTI $CIFTI -reset-timepoints 1 1
		rm $fakeNIFTI;
	done
fi

# Standard NIFTI Volume-based Processsing###
if $runVolume ; then
	log_Msg "MAIN: RUN_GLM: Standard NIFTI Volume Analysis"
	log_Msg "MAIN: RUN_GLM: Run film_gls on volume data"
	film_gls --rn=${FEATDir}/StandardVolumeStats --sa --ms=5 --in=${FEATDir}/${LevelOnefMRIName}${TemporalFilterString}${SmoothingString}.nii.gz --pd=${DesignMatrix} --con=${DesignContrasts} ${ExtraArgs} --thr=1000

	# Cleanup
	rm -f ${FEATDir}/mask_*.nii.gz
	rm -f ${FEATDir}/${LevelOnefMRIName}${ProcSTRING}${SmoothingString}.nii.gz
	rm -f ${FEATDir}/${LevelOnefMRIName}${ProcSTRING}_dilM${SmoothingString}.nii.gz
	rm -f ${SmoothedDilatedResultFile}*.nii.gz
fi

#make an unmatched * expression become "no arguments" instead of something nonexistent
shopt -s nullglob

# Clean up contrasts where cope has no non-zero voxels (created from 'versus rest' contrasts from conditions with empty EVs)
# NOTE WELL: This will not remove 'condition A versus condition B' contrasts where one condition has no events.
for Analysis in GrayordinatesStats ParcellatedStats StandardVolumeStats; do
	for file in "$FEATDir"/"$Analysis"/cope*.nii*; do
		filebase=$( basename "$file" )
		sd=$( fslstats "$file" -V | awk '{ print $1 }' )
		if [[ "$sd" == 0 ]]; then 
			log_Msg "CLEANUP $filebase has 0 non-zero voxels. Removing all associated files."
			prefixes=( cope pe tstat varcope zstat )
			for pre in "${prefixes[@]}"; do 
				rm -v "${FEATDir}/${Analysis}/$pre${filebase#cope}"
			done
		fi
	done
done

log_Msg "MAIN: Complete"
