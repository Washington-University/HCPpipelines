#!/bin/bash

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

Subject="$1"
ResultsFolder="$2"
DownSampleFolder="$3"
LevelOnefMRINames="$4"
LevelOnefsfNames="$5"
LevelTwofMRIName="$6"
LevelTwofsfName="$7"
LowResMesh="$8"
FinalSmoothingFWHM="$9"
TemporalFilter="${10}"
VolumeBasedProcessing="${11}"
RegName="${12}"
Parcellation="${13}"
ProcSTRING="${14}"
TemporalSmoothing="${15}"


log_Msg "READ_ARGS: ${script_name} arguments: $@"

# Log variables parsed from command line arguments
log_Msg "READ_ARGS: Subject: ${Subject}"
log_Msg "READ_ARGS: ResultsFolder: ${ResultsFolder}"
log_Msg "READ_ARGS: DownSampleFolder: ${DownSampleFolder}"
log_Msg "READ_ARGS: LevelOnefMRINames: ${LevelOnefMRINames}"
log_Msg "READ_ARGS: LevelOnefsfNames: ${LevelOnefsfNames}"
log_Msg "READ_ARGS: LevelTwofMRIName: ${LevelTwofMRIName}"
log_Msg "READ_ARGS: LevelTwofsfName: ${LevelTwofsfName}"
log_Msg "READ_ARGS: LowResMesh: ${LowResMesh}"
log_Msg "READ_ARGS: FinalSmoothingFWHM: ${FinalSmoothingFWHM}"
log_Msg "READ_ARGS: TemporalFilter: ${TemporalFilter}"
log_Msg "READ_ARGS: VolumeBasedProcessing: ${VolumeBasedProcessing}"
log_Msg "READ_ARGS: RegName: ${RegName}"
log_Msg "READ_ARGS: Parcellation: ${Parcellation}"
log_Msg "READ_ARGS: ProcSTRING: ${ProcSTRING}" 
log_Msg "READ_ARGS: TemporalSmoothing: ${TemporalSmoothing}"


########################################## MAIN ##################################

##### DETERMINE ANALYSES TO RUN (DENSE, PARCELLATED, VOLUME) #####

# initialize run variables
runParcellated=false; runVolume=false; runDense=false;
Analyses=""; ExtensionList=""; ScalarExtensionList="";

# Determine whether to run Parcellated, and set strings used for filenaming
if [ "${Parcellation}" != "NONE" ] ; then
	# Run Parcellated Analyses
	runParcellated=true;
	ParcellationString="_${Parcellation}"
	ExtensionList="${ExtensionList}ptseries.nii "
	ScalarExtensionList="${ScalarExtensionList}pscalar.nii "
	Analyses="${Analyses}ParcellatedStats "; # space character at end to separate multiple analyses
	log_Msg "MAIN: DETERMINE_ANALYSES: Parcellated Analysis requested"
fi

# Determine whether to run Dense, and set strings used for filenaming
if [ "${Parcellation}" = "NONE" ]; then
	# Run Dense Analyses
	runDense=true;
	ParcellationString=""
	ExtensionList="${ExtensionList}dtseries.nii "
	ScalarExtensionList="${ScalarExtensionList}dscalar.nii "
	Analyses="${Analyses}GrayordinatesStats "; # space character at end to separate multiple analyses
	if [ ! ${FinalSmoothingFWHM} -eq 0 ] ; then
	log_Msg "MAIN: DETERMINE_ANALYSES: Dense Analysis requested"
	fi
fi

# Determine whether to run Volume, and set strings used for filenaming
if [ "$VolumeBasedProcessing" = "YES" ] ; then
        if [ ${FinalSmoothingFWHM} -eq 0 ] ; then
	runVolume=true;
	runDense=false;
	ExtensionList="nii.gz "
	ScalarExtensionList="volume.dscalar.nii "
	Analyses="StandardVolumeStats "; # space character at end to separate multiple analyses
	log_Msg "MAIN: DETERMINE_ANALYSES: Volume Analysis requested"
        else
	runVolume=true;
	ExtensionList="${ExtensionList}nii.gz "
	ScalarExtensionList="${ScalarExtensionList}volume.dscalar.nii "
	Analyses+="StandardVolumeStats "; # space character at end to separate multiple analyses	
	log_Msg "MAIN: DETERMINE_ANALYSES: Volume Analysis requested"
        fi
fi

log_Msg "MAIN: DETERMINE_ANALYSES: Analyses: ${Analyses}"
log_Msg "MAIN: DETERMINE_ANALYSES: ParcellationString: ${ParcellationString}"
log_Msg "MAIN: DETERMINE_ANALYSES: ExtensionList: ${ExtensionList}"
log_Msg "MAIN: DETERMINE_ANALYSES: ScalarExtensionList: ${ScalarExtensionList}"


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

### Figure out where the Level1 .feat directories are located
# Change '@' delimited arguments to space-delimited lists for use in for loops
LevelOnefMRINames=`echo $LevelOnefMRINames | sed 's/@/ /g'`
LevelOnefsfNames=`echo $LevelOnefsfNames | sed 's/@/ /g'`
# Loop over list to make string with paths to the Level1 .feat directories
LevelOneFEATDirSTRING=""
NumFirstLevelFolders=0; # counter
for LevelOnefMRIName in $LevelOnefMRINames ; do 
  NumFirstLevelFolders=$(($NumFirstLevelFolders+1));
  # get fsf name that corresponds to fMRI name
  LevelOnefsfName=`echo $LevelOnefsfNames | cut -d " " -f $NumFirstLevelFolders`;
  LevelOneFEATDirSTRING="${LevelOneFEATDirSTRING}${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefsfName}${TemporalFilterString}${SmoothingString}_level1${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}.feat "; # space character at end is needed to separate multiple FEATDir strings
done

##### CHECK_FILES: Check that necessary inputs exist before trying to use them #####
# Assemble list of input filenames that need to be checked
Filenames="";
# Need template fsf file
Filenames="${Filenames} ${ResultsFolder}/${LevelTwofMRIName}/${LevelTwofsfName}_hp200_s4_level2.fsf"

errMsg="";
# Check files in Level1 Analysis folders
for LevelOneFEATDir in ${LevelOneFEATDirSTRING} ; do
	Filenames="${Filenames} ${LevelOneFEATDir}/design.con"
	analysisCounter=1;
	for Analysis in ${Analyses} ; do
		Extension=`echo $ExtensionList | cut -d' ' -f $analysisCounter`;
		### Save errors if cope files are not present in Level 1 folders
		fileCount=$( ls ${LevelOneFEATDir}/${Analysis}/cope*.${Extension} 2>/dev/null | wc -l );
		if [ "$fileCount" -eq 0 ]; then
			errMsg="${errMsg}Missing all cope $Extension files in ${LevelOneFEATDir}/${Analysis}. "
		fi
		### Save errors if varcope files are not present in Level 1 folders
		fileCount=$( ls ${LevelOneFEATDir}/${Analysis}/varcope*.${Extension} 2>/dev/null | wc -l );
		if [ "$fileCount" -eq 0 ]; then
			errMsg="${errMsg}Missing all varcope $Extension files in ${LevelOneFEATDir}/${Analysis}. "
		fi
		### Save error if res4d file is not present in Level 1 folders
		fileCount=$( ls ${LevelOneFEATDir}/${Analysis}/res4d.${Extension} 2>/dev/null | wc -l );
		if [ "$fileCount" -eq 0 ]; then
			errMsg="${errMsg}Missing res4d $Extension files in ${LevelOneFEATDir}/${Analysis}. "
		fi
		### Save error if dof file is not present in Level 1 folders
		fileCount=$( ls ${LevelOneFEATDir}/${Analysis}/dof 2>/dev/null | wc -l );
		if [ "$fileCount" -eq 0 ]; then
			errMsg="${errMsg}Missing dof file in ${LevelOneFEATDir}/${Analysis}. "
		fi
		analysisCounter=$(($analysisCounter+1))
	done
done

# Now check each file in list
missingFiles="";
for Filename in $Filenames; do
	# if file does not exist, set errMsg
	[ -e "$Filename" ] || missingFiles="${missingFiles} ${Filename} "
done

# if missing files, save an error message
if [ -n "${missingFiles}" ]; then
    errMsg="${errMsg}Missing necessary input files: ${missingFiles}"
fi

# if there were errors, exit with appropriate error messages
if [ -n "${errMsg}" ]; then
	log_Err_Abort $errMsg
fi

# if no missing files, then carry on
log_Msg "CHECK INPUTS: Necessary input files exist"


##### MAKE DESIGN FILES AND LEVEL2 DIRECTORY #####

# Determine list of contrasts for this analysis
FirstFolder=`echo $LevelOneFEATDirSTRING | cut -d " " -f 1`
ContrastNames=`cat ${FirstFolder}/design.con | grep "ContrastName" | cut -f 2`
NumContrasts=`echo ${ContrastNames} | wc -w`

# Make LevelTwoFEATDir
LevelTwoFEATDir="${ResultsFolder}/${LevelTwofMRIName}/${LevelTwofsfName}${TemporalFilterString}${SmoothingString}_level2${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}.feat"
if [ -e ${LevelTwoFEATDir} ] ; then
  rm -r ${LevelTwoFEATDir}
  mkdir ${LevelTwoFEATDir}
else
  mkdir -p ${LevelTwoFEATDir}
fi

# Edit template.fsf and place it in LevelTwoFEATDir
cat ${ResultsFolder}/${LevelTwofMRIName}/${LevelTwofsfName}_hp200_s4_level2.fsf | sed s/_hp200_s4/${TemporalFilterString}${SmoothingString}${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}/g > ${LevelTwoFEATDir}/design.fsf

# Make additional design files required by flameo
log_Msg "Make design files"
cd ${LevelTwoFEATDir}; # Run feat_model inside LevelTwoFEATDir so relative paths work
feat_model design
cd $OLDPWD; # Go back to previous directory using bash built-in $OLDPWD


##### RUN flameo (FIXED-EFFECTS GLM ANALYSIS ON LEVEL2) #####

### Loop over Level 2 Analyses requested
log_Msg "Loop over Level 2 Analyses requested: ${Analyses}"
analysisCounter=1;
for Analysis in ${Analyses} ; do
	log_Msg "Run Analysis: ${Analysis}"
	Extension=`echo $ExtensionList | cut -d' ' -f $analysisCounter`;
	ScalarExtension=`echo $ScalarExtensionList | cut -d' ' -f $analysisCounter`;

	### Exit if cope files are not present in Level 1 folders
	fileCount=$( ls ${FirstFolder}/${Analysis}/cope1.${Extension} 2>/dev/null | wc -l );
	if [ "$fileCount" -eq 0 ]; then
		log_Err_Abort "Missing expected cope files in ${FirstFolder}/${Analysis}"
	fi

	### Copy Level 1 stats folders into Level 2 analysis directory
	log_Msg "Copy over Level 1 stats folders and convert CIFTI to NIFTI if required"
	mkdir -p ${LevelTwoFEATDir}/${Analysis}
	i=1
	for LevelOneFEATDir in ${LevelOneFEATDirSTRING} ; do
		mkdir -p ${LevelTwoFEATDir}/${Analysis}/${i}
		cp ${LevelOneFEATDir}/${Analysis}/* ${LevelTwoFEATDir}/${Analysis}/${i}
		i=$(($i+1))
	done

	### convert CIFTI files to fakeNIFTI if required
	if [ "${Analysis}" != "StandardVolumeStats" ] ; then
		log_Msg "Convert CIFTI files to fakeNIFTI"
		fakeNIFTIused="YES"
		for CIFTI in ${LevelTwoFEATDir}/${Analysis}/*/*.${Extension} ; do
			fakeNIFTI=$( echo $CIFTI | sed -e "s|.${Extension}|.nii.gz|" );
			${CARET7DIR}/wb_command -cifti-convert -to-nifti $CIFTI $fakeNIFTI
			rm $CIFTI
		done
	else
		fakeNIFTIused="NO"
	fi

	### Create dof and Mask files for input to flameo (Level 2 analysis)
	log_Msg "Create dof and Mask files for input to flameo (Level 2 analysis)"
	MERGESTRING=""
	i=1
	while [ "$i" -le "${NumFirstLevelFolders}" ] ; do
		dof=`cat ${LevelTwoFEATDir}/${Analysis}/${i}/dof`
		fslmaths ${LevelTwoFEATDir}/${Analysis}/${i}/res4d.nii.gz -Tstd -bin -mul $dof ${LevelTwoFEATDir}/${Analysis}/${i}/dofmask.nii.gz
		MERGESTRING=`echo "${MERGESTRING}${LevelTwoFEATDir}/${Analysis}/${i}/dofmask.nii.gz "`
		i=$(($i+1))
	done
	fslmerge -t ${LevelTwoFEATDir}/${Analysis}/dof.nii.gz $MERGESTRING
	fslmaths ${LevelTwoFEATDir}/${Analysis}/dof.nii.gz -Tmin -bin ${LevelTwoFEATDir}/${Analysis}/mask.nii.gz

	### Create merged cope and varcope files for input to flameo (Level 2 analysis)
	log_Msg "Merge COPES and VARCOPES for ${NumContrasts} Contrasts"
	copeCounter=1
	while [ "$copeCounter" -le "${NumContrasts}" ] ; do
		log_Msg "Contrast Number: ${copeCounter}"
		COPEMERGE=""
		VARCOPEMERGE=""
		i=1
		while [ "$i" -le "${NumFirstLevelFolders}" ] ; do
		  COPEMERGE="${COPEMERGE}${LevelTwoFEATDir}/${Analysis}/${i}/cope${copeCounter}.nii.gz "
		  VARCOPEMERGE="${VARCOPEMERGE}${LevelTwoFEATDir}/${Analysis}/${i}/varcope${copeCounter}.nii.gz "
		  i=$(($i+1))
		done
		fslmerge -t ${LevelTwoFEATDir}/${Analysis}/cope${copeCounter}.nii.gz $COPEMERGE
		fslmerge -t ${LevelTwoFEATDir}/${Analysis}/varcope${copeCounter}.nii.gz $VARCOPEMERGE
		copeCounter=$(($copeCounter+1))
	done

	### Run 2nd level analysis using flameo
	log_Msg "Run flameo (Level 2 analysis) for ${NumContrasts} Contrasts"
	copeCounter=1
	while [ "$copeCounter" -le "${NumContrasts}" ] ; do
		log_Msg "Contrast Number: ${copeCounter}"
		log_Msg "$( which flameo )"
		log_Msg "Command: flameo --cope=${Analysis}/cope${copeCounter}.nii.gz \\"
		log_Msg "  --vc=${Analysis}/varcope${copeCounter}.nii.gz \\"
		log_Msg "  --dvc=${Analysis}/dof.nii.gz \\"
		log_Msg "  --mask=${Analysis}/mask.nii.gz \\"
		log_Msg "  --ld=${Analysis}/cope${copeCounter}.feat \\"
		log_Msg "  --dm=design.mat \\"
		log_Msg "  --cs=design.grp \\"
		log_Msg "  --tc=design.con \\"
		log_Msg "  --runmode=fe"

		cd ${LevelTwoFEATDir}; # run flameo within LevelTwoFEATDir so relative paths work
		flameo --cope=${Analysis}/cope${copeCounter}.nii.gz \
			   --vc=${Analysis}/varcope${copeCounter}.nii.gz \
			   --dvc=${Analysis}/dof.nii.gz \
			   --mask=${Analysis}/mask.nii.gz \
			   --ld=${Analysis}/cope${copeCounter}.feat \
			   --dm=design.mat \
			   --cs=design.grp \
			   --tc=design.con \
			   --runmode=fe

		log_Msg "Successfully completed flameo for Contrast Number: ${copeCounter}"
		cd $OLDPWD; # Go back to previous directory using bash built-in $OLDPWD
		copeCounter=$(($copeCounter+1))
	done

	### Cleanup Temporary Files (which were copied from Level1 stats directories)
	log_Msg "Cleanup Temporary Files"
	i=1
	while [ "$i" -le "${NumFirstLevelFolders}" ] ; do
		rm -r ${LevelTwoFEATDir}/${Analysis}/${i}
		i=$(($i+1))
	done

	### Convert fakeNIFTI Files back to CIFTI (if necessary)
	if [ "$fakeNIFTIused" = "YES" ] ; then
		log_Msg "Convert fakeNIFTI files back to CIFTI"
		CIFTItemplate=$( ls ${LevelOneFEATDir}/${Analysis}/cope*.${Extension} | head -1)

		# convert flameo input files for review: ${LevelTwoFEATDir}/${Analysis}/*.nii.gz
		# convert flameo output files for each cope: ${LevelTwoFEATDir}/${Analysis}/cope*.feat/*.nii.gz
		for fakeNIFTI in ${LevelTwoFEATDir}/${Analysis}/*.nii.gz ${LevelTwoFEATDir}/${Analysis}/cope*.feat/*.nii.gz; do
			CIFTI=$( echo $fakeNIFTI | sed -e "s|.nii.gz|.${Extension}|" );
			${CARET7DIR}/wb_command -cifti-convert -from-nifti $fakeNIFTI $CIFTItemplate $CIFTI -reset-timepoints 1 1
			rm $fakeNIFTI
		done
	fi
	
	### Generate Files for Viewing
	log_Msg "Generate Files for Viewing"
	# Initialize strings used for fslmerge command
	zMergeSTRING=""
	bMergeSTRING=""
	vMergeSTRING=""
	touch ${LevelTwoFEATDir}/Contrasttemp.txt
	[ "${Analysis}" = "StandardVolumeStats" ] && touch ${LevelTwoFEATDir}/wbtemp.txt
	[ -e "${LevelTwoFEATDir}/Contrasts.txt" ] && rm ${LevelTwoFEATDir}/Contrasts.txt

	# Loop over contrasts to identify cope and zstat files to merge into wb_view scalars
	copeCounter=1;
	while [ "$copeCounter" -le "${NumContrasts}" ] ; do
		Contrast=`echo $ContrastNames | cut -d " " -f $copeCounter`
		# Contrasts.txt is used to store the contrast names for this analysis
		echo ${Contrast} >> ${LevelTwoFEATDir}/Contrasts.txt
		# Contrasttemp.txt is a temporary file used to name the maps in the CIFTI scalar file
		echo "${Subject}_${LevelTwofsfName}_level2_${Contrast}${TemporalFilterString}${SmoothingString}${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}" >> ${LevelTwoFEATDir}/Contrasttemp.txt

		if [ "${Analysis}" = "StandardVolumeStats" ] ; then

			### Make temporary dtseries files to convert into scalar files
			# Converting volume to dense timeseries requires a volume label file
			echo "OTHER" >> ${LevelTwoFEATDir}/wbtemp.txt
			echo "1 255 255 255 255" >> ${LevelTwoFEATDir}/wbtemp.txt
			${CARET7DIR}/wb_command -volume-label-import ${LevelTwoFEATDir}/StandardVolumeStats/mask.nii.gz ${LevelTwoFEATDir}/wbtemp.txt ${LevelTwoFEATDir}/StandardVolumeStats/mask.nii.gz -discard-others -unlabeled-value 0
			rm ${LevelTwoFEATDir}/wbtemp.txt

			# Convert temporary volume CIFTI timeseries files
			${CARET7DIR}/wb_command -cifti-create-dense-timeseries ${LevelTwoFEATDir}/${Subject}_${LevelTwofsfName}_level2_zstat_${Contrast}${TemporalFilterString}${SmoothingString}${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}.volume.dtseries.nii -volume ${LevelTwoFEATDir}/StandardVolumeStats/cope${copeCounter}.feat/zstat1.nii.gz ${LevelTwoFEATDir}/StandardVolumeStats/mask.nii.gz -timestep 1 -timestart 1
			${CARET7DIR}/wb_command -cifti-create-dense-timeseries ${LevelTwoFEATDir}/${Subject}_${LevelTwofsfName}_level2_cope_${Contrast}${TemporalFilterString}${SmoothingString}${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}.volume.dtseries.nii -volume ${LevelTwoFEATDir}/StandardVolumeStats/cope${copeCounter}.feat/cope1.nii.gz ${LevelTwoFEATDir}/StandardVolumeStats/mask.nii.gz -timestep 1 -timestart 1
			${CARET7DIR}/wb_command -cifti-create-dense-timeseries ${LevelTwoFEATDir}/${Subject}_${LevelTwofsfName}_level2_varcope_${Contrast}${TemporalFilterString}${SmoothingString}${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}.volume.dtseries.nii -volume ${LevelTwoFEATDir}/StandardVolumeStats/cope${copeCounter}.feat/varcope1.nii.gz ${LevelTwoFEATDir}/StandardVolumeStats/mask.nii.gz -timestep 1 -timestart 1

			# Convert volume CIFTI timeseries files to scalar files
			${CARET7DIR}/wb_command -cifti-convert-to-scalar ${LevelTwoFEATDir}/${Subject}_${LevelTwofsfName}_level2_zstat_${Contrast}${TemporalFilterString}${SmoothingString}${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}.volume.dtseries.nii ROW ${LevelTwoFEATDir}/${Subject}_${LevelTwofsfName}_level2_zstat_${Contrast}${TemporalFilterString}${SmoothingString}${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}.${ScalarExtension} -name-file ${LevelTwoFEATDir}/Contrasttemp.txt
			${CARET7DIR}/wb_command -cifti-convert-to-scalar ${LevelTwoFEATDir}/${Subject}_${LevelTwofsfName}_level2_cope_${Contrast}${TemporalFilterString}${SmoothingString}${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}.volume.dtseries.nii ROW ${LevelTwoFEATDir}/${Subject}_${LevelTwofsfName}_level2_cope_${Contrast}${TemporalFilterString}${SmoothingString}${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}.${ScalarExtension} -name-file ${LevelTwoFEATDir}/Contrasttemp.txt
			${CARET7DIR}/wb_command -cifti-convert-to-scalar ${LevelTwoFEATDir}/${Subject}_${LevelTwofsfName}_level2_varcope_${Contrast}${TemporalFilterString}${SmoothingString}${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}.volume.dtseries.nii ROW ${LevelTwoFEATDir}/${Subject}_${LevelTwofsfName}_level2_varcope_${Contrast}${TemporalFilterString}${SmoothingString}${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}.${ScalarExtension} -name-file ${LevelTwoFEATDir}/Contrasttemp.txt

			# Delete the temporary volume CIFTI timeseries files
			rm ${LevelTwoFEATDir}/${Subject}_${LevelTwofsfName}_level2_{cope,varcope,zstat}_${Contrast}${TemporalFilterString}${SmoothingString}${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}.volume.dtseries.nii
		else
			### Convert CIFTI dense or parcellated timeseries to scalar files
			${CARET7DIR}/wb_command -cifti-convert-to-scalar ${LevelTwoFEATDir}/${Analysis}/cope${copeCounter}.feat/zstat1.${Extension} ROW ${LevelTwoFEATDir}/${Subject}_${LevelTwofsfName}_level2_zstat_${Contrast}${TemporalFilterString}${SmoothingString}${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}.${ScalarExtension} -name-file ${LevelTwoFEATDir}/Contrasttemp.txt
			${CARET7DIR}/wb_command -cifti-convert-to-scalar ${LevelTwoFEATDir}/${Analysis}/cope${copeCounter}.feat/cope1.${Extension} ROW ${LevelTwoFEATDir}/${Subject}_${LevelTwofsfName}_level2_cope_${Contrast}${TemporalFilterString}${SmoothingString}${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}.${ScalarExtension} -name-file ${LevelTwoFEATDir}/Contrasttemp.txt
			${CARET7DIR}/wb_command -cifti-convert-to-scalar ${LevelTwoFEATDir}/${Analysis}/cope${copeCounter}.feat/varcope1.${Extension} ROW ${LevelTwoFEATDir}/${Subject}_${LevelTwofsfName}_level2_varcope_${Contrast}${TemporalFilterString}${SmoothingString}${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}.${ScalarExtension} -name-file ${LevelTwoFEATDir}/Contrasttemp.txt
		fi

		# These merge strings are used below to combine the multiple scalar files into a single file for visualization
		zMergeSTRING="${zMergeSTRING}-cifti ${LevelTwoFEATDir}/${Subject}_${LevelTwofsfName}_level2_zstat_${Contrast}${TemporalFilterString}${SmoothingString}${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}.${ScalarExtension} "
		bMergeSTRING="${bMergeSTRING}-cifti ${LevelTwoFEATDir}/${Subject}_${LevelTwofsfName}_level2_cope_${Contrast}${TemporalFilterString}${SmoothingString}${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}.${ScalarExtension} "
		vMergeSTRING="${vMergeSTRING}-cifti ${LevelTwoFEATDir}/${Subject}_${LevelTwofsfName}_level2_varcope_${Contrast}${TemporalFilterString}${SmoothingString}${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}.${ScalarExtension} "

		# Remove Contrasttemp.txt file
		rm ${LevelTwoFEATDir}/Contrasttemp.txt
		copeCounter=$(($copeCounter+1))
	done

	# Perform the merge into viewable scalar files
	${CARET7DIR}/wb_command -cifti-merge ${LevelTwoFEATDir}/${Subject}_${LevelTwofsfName}_level2_zstat${TemporalFilterString}${SmoothingString}${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}.${ScalarExtension} ${zMergeSTRING}
	${CARET7DIR}/wb_command -cifti-merge ${LevelTwoFEATDir}/${Subject}_${LevelTwofsfName}_level2_cope${TemporalFilterString}${SmoothingString}${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}.${ScalarExtension} ${bMergeSTRING}
	${CARET7DIR}/wb_command -cifti-merge ${LevelTwoFEATDir}/${Subject}_${LevelTwofsfName}_level2_varcope${TemporalFilterString}${SmoothingString}${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}.${ScalarExtension} ${vMergeSTRING}
	
	analysisCounter=$(($analysisCounter+1))
done  # end loop: for Analysis in ${Analyses}


log_Msg "Complete"
