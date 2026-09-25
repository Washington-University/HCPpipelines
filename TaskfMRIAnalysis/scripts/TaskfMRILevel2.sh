#!/bin/bash
- eu
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
source "${HCPPIPEDIR}/global/scripts/log.shlib" "$@"         # Debugging functions; also sources log.shlib

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
	wb_command -version

	# Show fsl version
	fsl_version_get fsl_ver
}

# Log versions of tools used by this script
show_tool_versions

########################################## READ_ARGS ##################################

Subject="$1"
Structure="$2"
ResultsFolder="$3"
DownSampleFolder="$4"
LevelOnefMRINames="$5"
LevelOnefsfNames="$6"
LevelTwofMRIName="$7"
LevelTwofsfName="$8"
LowResMesh="$9"
FinalSmoothingFWHM="${10}"
TemporalFilter="${11}"
VolumeBasedProcessing="${12}"
RegName="${13}"
Parcellation="${14}"
ProcSTRING="${15}"
TemporalSmoothing="${16}"


log_Msg "READ_ARGS: ${script_name} arguments: $@"

# Log variables parsed from command line arguments
log_Msg "READ_ARGS: Subject: ${Subject}"
log_Msg "READ_ARGS: Structure: ${Structure}"
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

case "${Structure}" in
    Hippocampus)
	    StructureString="_Hipp${LowResMesh}k"

        runDense=true
        ParcellationString=""
        ExtensionList="dtseries.nii "
        ScalarExtensionList="dscalar.nii "
        Analyses="GrayordinatesStats "

        if [[ "${Parcellation}" != "NONE" ]]; then
            log_Err_Abort "Parcellated analysis is not currently supported for hippocampal task analysis"
        fi

        if [[ "${VolumeBasedProcessing}" == "YES" ]]; then
            log_Err_Abort "Volume-based Level 2 analysis is not supported for hippocampal task analysis"
        fi

        log_Msg "MAIN: DETERMINE_ANALYSES: Hippocampal Dense Analysis requested"
        ;;

    Cortex)
        StructureString="_Cortex${LowResMesh}k"

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
	;;
    *)
        log_Err_Abort "Structure must be Cortex or Hippocampus. Structure=${Structure}"
        ;;
esac

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
case "${Structure}" in
    Cortex)
        if [ "${RegName}" != "NONE" ] ; then
            RegString="_${RegName}"
        else
            RegString=""
        fi
        ;;
    Hippocampus)
        RegString=""
        ;;
    *)
        log_Err_Abort "Structure must be Cortex or Hippocampus. Structure=${Structure}"
        ;;
esac

log_Msg "MAIN: SET_NAME_STRINGS: SmoothingString: ${SmoothingString}"
log_Msg "MAIN: SET_NAME_STRINGS: TemporalFilterString: ${TemporalFilterString}"
log_Msg "MAIN: SET_NAME_STRINGS: RegString: ${RegString}"

### Figure out where the Level1 .feat directories are located
# Change '@' delimited arguments to space-delimited lists for use in for loops
LevelOnefMRINames=`echo $LevelOnefMRINames | sed 's/@/ /g'`
LevelOnefsfNames=`echo $LevelOnefsfNames | sed 's/@/ /g'`
# Loop over list to make string with paths to the Level1 .feat directories

LevelOneFEATDirSTRING=""
NumFirstLevelFolders=0

for LevelOnefMRIName in ${LevelOnefMRINames}; do
    NumFirstLevelFolders=$((NumFirstLevelFolders + 1))
    LevelOnefsfName=$(echo "${LevelOnefsfNames}" | cut -d " " -f "${NumFirstLevelFolders}")
    LevelOneFEATDir="${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefsfName}${TemporalFilterString}${SmoothingString}${StructureString}_level1${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}.feat"
    LevelOneFEATDirSTRING="${LevelOneFEATDirSTRING}${LevelOneFEATDir} "
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
LevelTwoFEATDir="${ResultsFolder}/${LevelTwofMRIName}/${LevelTwofsfName}${TemporalFilterString}${SmoothingString}${StructureString}_level2${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}.feat"
if [ -e ${LevelTwoFEATDir} ] ; then
  rm -r ${LevelTwoFEATDir}
  mkdir ${LevelTwoFEATDir}
else
  mkdir -p ${LevelTwoFEATDir}
fi

# Edit template.fsf and place it in LevelTwoFEATDir
sed -e "s|_hp200_s4_level1|${TemporalFilterString}${SmoothingString}${StructureString}_level1${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}|g" -e "s|_hp200_s4_level2|${TemporalFilterString}${SmoothingString}${StructureString}_level2${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}|g" "${ResultsFolder}/${LevelTwofMRIName}/${LevelTwofsfName}_hp200_s4_level2.fsf" > "${LevelTwoFEATDir}/design.fsf"

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
	log_Msg "Copy over Level 1 stats folders"
	mkdir -p ${LevelTwoFEATDir}/${Analysis}
	i=1
	for LevelOneFEATDir in ${LevelOneFEATDirSTRING} ; do
		mkdir -p ${LevelTwoFEATDir}/${Analysis}/${i}
		cp ${LevelOneFEATDir}/${Analysis}/* ${LevelTwoFEATDir}/${Analysis}/${i}
		i=$(($i+1))
	done

	###  flameo with --CIFTI flag
	if [ "${Analysis}" != "StandardVolumeStats" ] ; then
		CIFTIused="YES"

		### Create dof and Mask CIFTI files for input to flameo
		log_Msg "Create CIFTI dof and mask files for input to flameo"
		i=1
		MERGE_ARGS=()

		while (( i <= NumFirstLevelFolders )); do
			RunDir="${LevelTwoFEATDir}/${Analysis}/${i}"
			dof=$(<"${RunDir}/dof")
			# Previously: fslmaths ${LevelTwoFEATDir}/${Analysis}/${i}/res4d.nii.gz -Tstd -bin -mul $dof ${LevelTwoFEATDir}/${Analysis}/${i}/dofmask.nii.gz
			wb_command -cifti-reduce "${RunDir}/res4d.${Extension}" STDEV "${RunDir}/res4d_std.dscalar.nii"
			wb_command -cifti-math "(x > 0) * ${dof}" "${RunDir}/dofmask.dscalar.nii" -var x "${RunDir}/res4d_std.dscalar.nii"
			MERGE_ARGS+=(-cifti "${RunDir}/dofmask.dscalar.nii")
			((i++))
		done
		# Previously: fslmerge -t ${LevelTwoFEATDir}/${Analysis}/dof.nii.gz $MERGESTRING
		#Previously: fslmaths ${LevelTwoFEATDir}/${Analysis}/dof.nii.gz -Tmin -bin ${LevelTwoFEATDir}/${Analysis}/mask.nii.gz
		wb_command -cifti-merge "${LevelTwoFEATDir}/${Analysis}/dof.dscalar.nii" "${MERGE_ARGS[@]}"
		wb_command -cifti-reduce "${LevelTwoFEATDir}/${Analysis}/dof.dscalar.nii" MIN "${LevelTwoFEATDir}/${Analysis}/dof_min.dscalar.nii"
		wb_command -cifti-math "x > 0" "${LevelTwoFEATDir}/${Analysis}/mask.dscalar.nii" -var x "${LevelTwoFEATDir}/${Analysis}/dof_min.dscalar.nii"

		### FSL does not recognize HIPPOCAMPUS_DENTATE_LEFT/RIGHT.
		### Solution: For hippocampal analysis, temporarily represent dentate as CORTEX_LEFT/RIGHT.
		if [[ "${Structure}" == "Hippocampus" ]] ; then
			for File in dof mask ; do
				wb_command -cifti-separate ${LevelTwoFEATDir}/${Analysis}/${File}.dscalar.nii COLUMN \
					-metric HIPPOCAMPUS_LEFT ${LevelTwoFEATDir}/${Analysis}/${File}.L.hipp.func.gii \
					-metric HIPPOCAMPUS_RIGHT ${LevelTwoFEATDir}/${Analysis}/${File}.R.hipp.func.gii \
					-metric HIPPOCAMPUS_DENTATE_LEFT ${LevelTwoFEATDir}/${Analysis}/${File}.L.dentate.func.gii \
					-metric HIPPOCAMPUS_DENTATE_RIGHT ${LevelTwoFEATDir}/${Analysis}/${File}.R.dentate.func.gii

				wb_command -cifti-create-dense-scalar ${LevelTwoFEATDir}/${Analysis}/${File}.fsl.dscalar.nii \
					-metric HIPPOCAMPUS_LEFT ${LevelTwoFEATDir}/${Analysis}/${File}.L.hipp.func.gii \
					-metric HIPPOCAMPUS_RIGHT ${LevelTwoFEATDir}/${Analysis}/${File}.R.hipp.func.gii \
					-metric CORTEX_LEFT ${LevelTwoFEATDir}/${Analysis}/${File}.L.dentate.func.gii \
					-metric CORTEX_RIGHT ${LevelTwoFEATDir}/${Analysis}/${File}.R.dentate.func.gii
			done
		fi
	else
		CIFTIused="NO"
		log_Msg "Create NIFTI dof and Mask files for input to flameo"
		MERGESTRING=""
		i=1
		while [ "$i" -le "${NumFirstLevelFolders}" ] ; do
			dof=`cat ${LevelTwoFEATDir}/${Analysis}/${i}/dof`
			fslmaths ${LevelTwoFEATDir}/${Analysis}/${i}/res4d.nii.gz -Tstd -bin -mul $dof ${LevelTwoFEATDir}/${Analysis}/${i}/dofmask.nii.gz
			MERGESTRING="${MERGESTRING}${LevelTwoFEATDir}/${Analysis}/${i}/dofmask.nii.gz "
			i=$(($i+1))
		done
		fslmerge -t ${LevelTwoFEATDir}/${Analysis}/dof.nii.gz $MERGESTRING
		fslmaths ${LevelTwoFEATDir}/${Analysis}/dof.nii.gz -Tmin -bin ${LevelTwoFEATDir}/${Analysis}/mask.nii.gz
	fi


	### Create merged cope and varcope files for input to flameo (Level 2 analysis)
	log_Msg "Merge COPES and VARCOPES for ${NumContrasts} Contrasts"
	copeCounter=1
	while [ "$copeCounter" -le "${NumContrasts}" ] ; do
		log_Msg "Contrast Number: ${copeCounter}"
		COPEMERGE=""
		VARCOPEMERGE=""
		i=1
		while [ "$i" -le "${NumFirstLevelFolders}" ] ; do
			if [ "${CIFTIused}" = "YES" ] ; then
				COPEMERGE="${COPEMERGE}-cifti ${LevelTwoFEATDir}/${Analysis}/${i}/cope${copeCounter}.${Extension} "
				VARCOPEMERGE="${VARCOPEMERGE}-cifti ${LevelTwoFEATDir}/${Analysis}/${i}/varcope${copeCounter}.${Extension} "
			else
				COPEMERGE="${COPEMERGE}${LevelTwoFEATDir}/${Analysis}/${i}/cope${copeCounter}.nii.gz "
				VARCOPEMERGE="${VARCOPEMERGE}${LevelTwoFEATDir}/${Analysis}/${i}/varcope${copeCounter}.nii.gz "
			fi
			i=$(($i+1))
		done
		if [ "${CIFTIused}" = "YES" ] ; then
			wb_command -cifti-merge ${LevelTwoFEATDir}/${Analysis}/cope${copeCounter}.${Extension} ${COPEMERGE}
			wb_command -cifti-merge ${LevelTwoFEATDir}/${Analysis}/varcope${copeCounter}.${Extension} ${VARCOPEMERGE}
		else
			fslmerge -t ${LevelTwoFEATDir}/${Analysis}/cope${copeCounter}.nii.gz $COPEMERGE
			fslmerge -t ${LevelTwoFEATDir}/${Analysis}/varcope${copeCounter}.nii.gz $VARCOPEMERGE
		fi
		copeCounter=$(($copeCounter+1))
	done

	### Run 2nd level analysis using flameo
	log_Msg "Run flameo (Level 2 analysis) for ${NumContrasts} Contrasts"
	copeCounter=1
	while [ "$copeCounter" -le "${NumContrasts}" ] ; do
		log_Msg "Contrast Number: ${copeCounter}"
		log_Msg "$( which flameo )"
		cd ${LevelTwoFEATDir}
		if [ "${CIFTIused}" = "YES" ] ; then

			if [[ "${Structure}" == "Hippocampus" ]] ; then
				for File in cope${copeCounter} varcope${copeCounter} ; do
					wb_command -cifti-separate \
						${Analysis}/${File}.${Extension} COLUMN \
						-metric HIPPOCAMPUS_LEFT ${Analysis}/${File}.L.hipp.func.gii \
						-metric HIPPOCAMPUS_RIGHT ${Analysis}/${File}.R.hipp.func.gii \
						-metric HIPPOCAMPUS_DENTATE_LEFT ${Analysis}/${File}.L.dentate.func.gii \
						-metric HIPPOCAMPUS_DENTATE_RIGHT ${Analysis}/${File}.R.dentate.func.gii

					wb_command -cifti-create-dense-timeseries \
						${Analysis}/${File}.fsl.${Extension} \
						-metric HIPPOCAMPUS_LEFT ${Analysis}/${File}.L.hipp.func.gii \
						-metric HIPPOCAMPUS_RIGHT ${Analysis}/${File}.R.hipp.func.gii \
						-metric CORTEX_LEFT ${Analysis}/${File}.L.dentate.func.gii \
						-metric CORTEX_RIGHT ${Analysis}/${File}.R.dentate.func.gii \
						-timestep 1
				done

				flameo --cope=${Analysis}/cope${copeCounter}.fsl.${Extension} \
				       --vc=${Analysis}/varcope${copeCounter}.fsl.${Extension} \
				       --dvc=${Analysis}/dof.fsl.dscalar.nii \
				       --mask=${Analysis}/mask.fsl.dscalar.nii \
				       --ld=${Analysis}/cope${copeCounter}.feat \
				       --dm=design.mat \
				       --cs=design.grp \
				       --tc=design.con \
				       --runmode=fe \
				       --CIFTI

				### Restore CORTEX_LEFT/RIGHT back to the correct dentate structures
				### in the FLAMEO outputs.
				for Stat in zstat1 cope1 varcope1 ; do
					wb_command -cifti-separate \
						${Analysis}/cope${copeCounter}.feat/${Stat}.nii COLUMN \
						-metric HIPPOCAMPUS_LEFT ${Analysis}/${Stat}.L.hipp.func.gii \
						-metric HIPPOCAMPUS_RIGHT ${Analysis}/${Stat}.R.hipp.func.gii \
						-metric CORTEX_LEFT ${Analysis}/${Stat}.L.dentate.func.gii \
						-metric CORTEX_RIGHT ${Analysis}/${Stat}.R.dentate.func.gii

					wb_command -cifti-create-dense-timeseries \
						${Analysis}/cope${copeCounter}.feat/${Stat}.${Extension} \
						-metric HIPPOCAMPUS_LEFT ${Analysis}/${Stat}.L.hipp.func.gii \
						-metric HIPPOCAMPUS_RIGHT ${Analysis}/${Stat}.R.hipp.func.gii \
						-metric HIPPOCAMPUS_DENTATE_LEFT ${Analysis}/${Stat}.L.dentate.func.gii \
						-metric HIPPOCAMPUS_DENTATE_RIGHT ${Analysis}/${Stat}.R.dentate.func.gii \
						-timestep 1
				done

			else
				flameo --cope=${Analysis}/cope${copeCounter}.${Extension} \
				       --vc=${Analysis}/varcope${copeCounter}.${Extension} \
				       --dvc=${Analysis}/dof.dscalar.nii \
				       --mask=${Analysis}/mask.dscalar.nii \
				       --ld=${Analysis}/cope${copeCounter}.feat \
				       --dm=design.mat \
				       --cs=design.grp \
				       --tc=design.con \
				       --runmode=fe \
				       --CIFTI
			fi
		else
			flameo --cope=${Analysis}/cope${copeCounter}.nii.gz \
			       --vc=${Analysis}/varcope${copeCounter}.nii.gz \
			       --dvc=${Analysis}/dof.nii.gz \
			       --mask=${Analysis}/mask.nii.gz \
			       --ld=${Analysis}/cope${copeCounter}.feat \
			       --dm=design.mat \
			       --cs=design.grp \
			       --tc=design.con \
			       --runmode=fe
		fi
		log_Msg "Successfully completed flameo for Contrast Number: ${copeCounter}"
		cd $OLDPWD
		copeCounter=$(($copeCounter+1))
	done

	### Cleanup Temporary Files (which were copied from Level1 stats directories)
	log_Msg "Cleanup Temporary Files"
	i=1
	while [ "$i" -le "${NumFirstLevelFolders}" ] ; do
		rm -r ${LevelTwoFEATDir}/${Analysis}/${i}
		i=$(($i+1))
	done


	### Generate Files for Viewing
	log_Msg "Generate Files for Viewing"
	# Initialize strings used for fslmerge command
	zMergeSTRING=""
	bMergeSTRING=""
	vMergeSTRING=""
	#touch ${LevelTwoFEATDir}/Contrasttemp.txt # line can be removed because the line below (echo "${Subject}...) now creates the text file instead of overwriting it. > instead of >>
	[ "${Analysis}" = "StandardVolumeStats" ] && touch ${LevelTwoFEATDir}/wbtemp.txt
	[ -e "${LevelTwoFEATDir}/Contrasts.txt" ] && rm ${LevelTwoFEATDir}/Contrasts.txt

	# Loop over contrasts to identify cope and zstat files to merge into wb_view scalars
	copeCounter=1;
	while [ "$copeCounter" -le "${NumContrasts}" ] ; do
		Contrast=`echo $ContrastNames | cut -d " " -f $copeCounter`
		# Contrasts.txt is used to store the contrast names for this analysis
		echo ${Contrast} >> ${LevelTwoFEATDir}/Contrasts.txt
		# Contrasttemp.txt is a temporary file used to name the maps in the CIFTI scalar file
		echo "${Subject}_${LevelTwofsfName}_level2_${Contrast}${TemporalFilterString}${SmoothingString}${StructureString}${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}" > ${LevelTwoFEATDir}/Contrasttemp.txt
		if [ "${Analysis}" = "StandardVolumeStats" ] ; then

			### Make temporary dtseries files to convert into scalar files
			# Converting volume to dense timeseries requires a volume label file
			echo "OTHER" >> ${LevelTwoFEATDir}/wbtemp.txt
			echo "1 255 255 255 255" >> ${LevelTwoFEATDir}/wbtemp.txt
			wb_command -volume-label-import ${LevelTwoFEATDir}/StandardVolumeStats/mask.nii.gz ${LevelTwoFEATDir}/wbtemp.txt ${LevelTwoFEATDir}/StandardVolumeStats/mask.nii.gz -discard-others -unlabeled-value 0
			rm ${LevelTwoFEATDir}/wbtemp.txt

			# Convert temporary volume CIFTI timeseries files
			wb_command -cifti-create-dense-timeseries ${LevelTwoFEATDir}/${Subject}_${LevelTwofsfName}_level2_zstat_${Contrast}${TemporalFilterString}${SmoothingString}${StructureString}${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}.volume.dtseries.nii -volume ${LevelTwoFEATDir}/StandardVolumeStats/cope${copeCounter}.feat/zstat1.nii.gz ${LevelTwoFEATDir}/StandardVolumeStats/mask.nii.gz -timestep 1 -timestart 1
			wb_command -cifti-create-dense-timeseries ${LevelTwoFEATDir}/${Subject}_${LevelTwofsfName}_level2_cope_${Contrast}${TemporalFilterString}${SmoothingString}${StructureString}${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}.volume.dtseries.nii -volume ${LevelTwoFEATDir}/StandardVolumeStats/cope${copeCounter}.feat/cope1.nii.gz ${LevelTwoFEATDir}/StandardVolumeStats/mask.nii.gz -timestep 1 -timestart 1
			wb_command -cifti-create-dense-timeseries ${LevelTwoFEATDir}/${Subject}_${LevelTwofsfName}_level2_varcope_${Contrast}${TemporalFilterString}${SmoothingString}${StructureString}${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}.volume.dtseries.nii -volume ${LevelTwoFEATDir}/StandardVolumeStats/cope${copeCounter}.feat/varcope1.nii.gz ${LevelTwoFEATDir}/StandardVolumeStats/mask.nii.gz -timestep 1 -timestart 1

			# Convert volume CIFTI timeseries files to scalar files
			wb_command -cifti-convert-to-scalar ${LevelTwoFEATDir}/${Subject}_${LevelTwofsfName}_level2_zstat_${Contrast}${TemporalFilterString}${SmoothingString}${StructureString}${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}.volume.dtseries.nii ROW ${LevelTwoFEATDir}/${Subject}_${LevelTwofsfName}_level2_zstat_${Contrast}${TemporalFilterString}${SmoothingString}${StructureString}${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}.${ScalarExtension} -name-file ${LevelTwoFEATDir}/Contrasttemp.txt
			wb_command -cifti-convert-to-scalar ${LevelTwoFEATDir}/${Subject}_${LevelTwofsfName}_level2_cope_${Contrast}${TemporalFilterString}${SmoothingString}${StructureString}${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}.volume.dtseries.nii ROW ${LevelTwoFEATDir}/${Subject}_${LevelTwofsfName}_level2_cope_${Contrast}${TemporalFilterString}${SmoothingString}${StructureString}${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}.${ScalarExtension} -name-file ${LevelTwoFEATDir}/Contrasttemp.txt
			wb_command -cifti-convert-to-scalar ${LevelTwoFEATDir}/${Subject}_${LevelTwofsfName}_level2_varcope_${Contrast}${TemporalFilterString}${SmoothingString}${StructureString}${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}.volume.dtseries.nii ROW ${LevelTwoFEATDir}/${Subject}_${LevelTwofsfName}_level2_varcope_${Contrast}${TemporalFilterString}${SmoothingString}${StructureString}${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}.${ScalarExtension} -name-file ${LevelTwoFEATDir}/Contrasttemp.txt

			# Delete the temporary volume CIFTI timeseries files
			rm ${LevelTwoFEATDir}/${Subject}_${LevelTwofsfName}_level2_{cope,varcope,zstat}_${Contrast}${TemporalFilterString}${SmoothingString}${StructureString}${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}.volume.dtseries.nii
		else
			### Convert CIFTI dense or parcellated timeseries to scalar files
			wb_command -cifti-convert-to-scalar ${LevelTwoFEATDir}/${Analysis}/cope${copeCounter}.feat/zstat1.${Extension} ROW ${LevelTwoFEATDir}/${Subject}_${LevelTwofsfName}_level2_zstat_${Contrast}${TemporalFilterString}${SmoothingString}${StructureString}${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}.${ScalarExtension} -name-file ${LevelTwoFEATDir}/Contrasttemp.txt
			wb_command -cifti-convert-to-scalar ${LevelTwoFEATDir}/${Analysis}/cope${copeCounter}.feat/cope1.${Extension} ROW ${LevelTwoFEATDir}/${Subject}_${LevelTwofsfName}_level2_cope_${Contrast}${TemporalFilterString}${SmoothingString}${StructureString}${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}.${ScalarExtension} -name-file ${LevelTwoFEATDir}/Contrasttemp.txt
			wb_command -cifti-convert-to-scalar ${LevelTwoFEATDir}/${Analysis}/cope${copeCounter}.feat/varcope1.${Extension} ROW ${LevelTwoFEATDir}/${Subject}_${LevelTwofsfName}_level2_varcope_${Contrast}${TemporalFilterString}${SmoothingString}${StructureString}${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}.${ScalarExtension} -name-file ${LevelTwoFEATDir}/Contrasttemp.txt
		fi

		# These merge strings are used below to combine the multiple scalar files into a single file for visualization
		zMergeSTRING="${zMergeSTRING}-cifti ${LevelTwoFEATDir}/${Subject}_${LevelTwofsfName}_level2_zstat_${Contrast}${TemporalFilterString}${SmoothingString}${StructureString}${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}.${ScalarExtension} "
		bMergeSTRING="${bMergeSTRING}-cifti ${LevelTwoFEATDir}/${Subject}_${LevelTwofsfName}_level2_cope_${Contrast}${TemporalFilterString}${SmoothingString}${StructureString}${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}.${ScalarExtension} "
		vMergeSTRING="${vMergeSTRING}-cifti ${LevelTwoFEATDir}/${Subject}_${LevelTwofsfName}_level2_varcope_${Contrast}${TemporalFilterString}${SmoothingString}${StructureString}${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}.${ScalarExtension} "

		# Remove Contrasttemp.txt file
		rm ${LevelTwoFEATDir}/Contrasttemp.txt
		copeCounter=$(($copeCounter+1))
	done

	# Perform the merge into viewable scalar files
	wb_command -cifti-merge ${LevelTwoFEATDir}/${Subject}_${LevelTwofsfName}_level2_zstat${TemporalFilterString}${SmoothingString}${StructureString}${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}.${ScalarExtension} ${zMergeSTRING}
	wb_command -cifti-merge ${LevelTwoFEATDir}/${Subject}_${LevelTwofsfName}_level2_cope${TemporalFilterString}${SmoothingString}${StructureString}${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}.${ScalarExtension} ${bMergeSTRING}
	wb_command -cifti-merge ${LevelTwoFEATDir}/${Subject}_${LevelTwofsfName}_level2_varcope${TemporalFilterString}${SmoothingString}${StructureString}${RegString}${ProcSTRING}${LowPassSTRING}${ParcellationString}.${ScalarExtension} ${vMergeSTRING}

	analysisCounter=$(($analysisCounter+1))
done  # end loop: for Analysis in ${Analyses}

log_Msg "Complete"