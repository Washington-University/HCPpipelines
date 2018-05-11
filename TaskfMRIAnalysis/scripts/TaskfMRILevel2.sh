#!/bin/bash
set -e

########################################## PREPARE FUNCTIONS ########################################## 

source ${HCPPIPEDIR}/global/scripts/log.shlib # Logging related functions
source ${HCPPIPEDIR}/global/scripts/fsl_version.shlib # Function for getting FSL version

show_tool_versions()
{
	# Show HCP pipelines version
	log_Msg "Showing HCP Pipelines version"
	cat ${HCPPIPEDIR}/version.txt

	# Show wb_command version
	log_Msg "Showing Connectome Workbench (wb_command) version"
	${CARET7DIR}/wb_command -version

	# Show fsl version
	log_Msg "Showing FSL version"
	fsl_version_get fsl_ver
	log_Msg "FSL version: ${fsl_ver}"
}



########################################## READ COMMAND-LINE ARGUMENTS ##################################

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

# Log how the script was launched
g_script_name=`basename ${0}`
log_SetToolName "${g_script_name}"
log_Msg "${g_script_name} arguments: $@"

# Log variables parsed from command line arguments
log_Msg "Subject: ${Subject}"
log_Msg "ResultsFolder: ${ResultsFolder}"
log_Msg "DownSampleFolder: ${DownSampleFolder}"
log_Msg "LevelOnefMRINames: ${LevelOnefMRINames}"
log_Msg "LevelOnefsfNames: ${LevelOnefsfNames}"
log_Msg "LevelTwofMRIName: ${LevelTwofMRIName}"
log_Msg "LevelTwofsfName: ${LevelTwofsfName}"
log_Msg "LowResMesh: ${LowResMesh}"
log_Msg "FinalSmoothingFWHM: ${FinalSmoothingFWHM}"
log_Msg "TemporalFilter: ${TemporalFilter}"
log_Msg "VolumeBasedProcessing: ${VolumeBasedProcessing}"
log_Msg "RegName: ${RegName}"
log_Msg "Parcellation: ${Parcellation}"

# Log versions of tools used by this script
show_tool_versions

########################################## MAIN ##################################

##### DETERMINE ANALYSES TO RUN (DENSE, PARCELLATED, VOLUME) #####

# initialize run variables
runParcellated=false; runVolume=false; runDense=false; Analyses="";

# Determine whether to run Parcellated, and set strings used for filenaming
if [ "${Parcellation}" != "NONE" ] ; then
  # Run Parcellated Analyses
  runParcellated=true;
  ParcellationString="_${Parcellation}"
  Extension="ptseries.nii"
  ScalarExtension="pscalar.nii"
  Analyses="${Analyses}ParcellatedStats "; # space character at end to separate multiple analyses
fi

# Determine whether to run Dense, and set strings used for filenaming
if [ "${Parcellation}" = "NONE" ]; then
  # Run Dense Analyses
  runDense=true;
  ParcellationString=""
  Extension="dtseries.nii"
  ScalarExtension="dscalar.nii"
  Analyses="${Analyses}GrayordinatesStats "; # space character at end to separate multiple analyses
fi

# Determine whether to run Volume, and set strings used for filenaming
if [ $VolumeBasedProcessing = "YES" ] ; then
	runVolume=true;
	Extension=".nii.gz"
	Analyses="${Analyses}StandardVolumeStats "; # space character at end to separate multiple analyses	
fi

log_Msg "Analyses: ${Analyses}"
log_Msg "ParcellationString: ${ParcellationString}"
log_Msg "Extension: ${Extension}"
log_Msg "ScalarExtension: ${ScalarExtension}"


##### SET VARIABLES REQUIRED FOR FILE NAMING #####

### Set smoothing and filtering string variables used for file naming
SmoothingString="_s${FinalSmoothingFWHM}"
TemporalFilterString="_hp""$TemporalFilter"
log_Msg "SmoothingString: ${SmoothingString}"
log_Msg "TemporalFilterString: ${TemporalFilterString}"

### Set variables used for different registration procedures
if [ "${RegName}" != "NONE" ] ; then
  RegString="_${RegName}"
else
  RegString=""
fi
log_Msg "RegString: ${RegString}"

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
  LevelOneFEATDirSTRING="${LevelOneFEATDirSTRING}${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefsfName}${TemporalFilterString}${SmoothingString}_level1${RegString}${ParcellationString}.feat "; # space character at end is needed to separate multiple FEATDir strings
done

### Determine list of contrasts for this analysis
FirstFolder=`echo $LevelOneFEATDirSTRING | cut -d " " -f 1`
ContrastNames=`cat ${FirstFolder}/design.con | grep "ContrastName" | cut -f 2`
NumContrasts=`echo ${ContrastNames} | wc -w`


##### MAKE DESIGN FILES AND LEVEL2 DIRECTORY #####

# Make LevelTwoFEATDir
LevelTwoFEATDir="${ResultsFolder}/${LevelTwofMRIName}/${LevelTwofsfName}${TemporalFilterString}${SmoothingString}_level2${RegString}${ParcellationString}.feat"
if [ -e ${LevelTwoFEATDir} ] ; then
  rm -r ${LevelTwoFEATDir}
  mkdir ${LevelTwoFEATDir}
else
  mkdir -p ${LevelTwoFEATDir}
fi

# Edit template.fsf and place it in LevelTwoFEATDir
cat ${ResultsFolder}/${LevelTwofMRIName}/${LevelTwofsfName}_hp200_s4_level2.fsf | sed s/_hp200_s4/${TemporalFilterString}${SmoothingString}${RegString}${ParcellationString}/g > ${LevelTwoFEATDir}/design.fsf

# Make additional design files required by flameo
log_Msg "Make design files"
cd ${LevelTwoFEATDir}; # Run feat_model inside LevelTwoFEATDir so relative paths work
feat_model ${LevelTwoFEATDir}/design
cd $OLDPWD; # Go back to previous directory using bash built-in $OLDPWD


##### RUN flameo (FIXED-EFFECTS GLM ANALYSIS ON LEVEL2) #####

### Loop over Level 2 Analyses requested
log_Msg "Loop over Level 2 Analyses requested: ${Analyses}"
for Analysis in ${Analyses} ; do
	log_Msg "Run Analysis: ${Analysis}"

	### Exit if cope files are not present in Level 1 folders
	fileCount=$( ls ${FirstFolder}/${Analysis}/cope1.${Extension} 2>/dev/null | wc -l );
	if [ "$fileCount" -eq 0 ]; then
		log_Msg "ERROR: Missing expected cope files in ${FirstFolder}/${Analysis}"
		log_Msg "ERROR: Exiting $g_script_name"
		exit 1
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
		CIFTItemplate="${LevelOneFEATDir}/${Analysis}/pe1.${Extension}"

		# convert flameo input files for review: ${LevelTwoFEATDir}/${Analysis}/*.nii.gz
		# convert flameo output files for each cope: ${LevelTwoFEATDir}/${Analysis}/cope*.feat/*.nii.gz
	   for fakeNIFTI in ${LevelTwoFEATDir}/${Analysis}/*.nii.gz ${LevelTwoFEATDir}/${Analysis}/cope*.feat/*.nii.gz; do
			CIFTI=$( echo $fakeNIFTI | sed -e "s|.nii.gz|.${Extension}|" );
			${CARET7DIR}/wb_command -cifti-convert -from-nifti $fakeNIFTI $CIFTItemplate $CIFTI -reset-timepoints 1 1
			rm $fakeNIFTI
		done
	fi

done  # end loop: for Analysis in ${Analyses}



### Generate Files for Viewing
log_Msg "Generate Files for Viewing"

# Initialize strings used for fslmerge command
zMergeSTRING=""
bMergeSTRING=""
touch ${LevelTwoFEATDir}/Contrasttemp.txt

if $runVolume ; then
	VolzMergeSTRING=""
	VolbMergeSTRING=""
	touch ${LevelTwoFEATDir}/wbtemp.txt
fi

if [ -e "${LevelTwoFEATDir}/Contrasts.txt" ] ; then
	rm ${LevelTwoFEATDir}/Contrasts.txt
fi

# Loop over contrasts to identify cope and zstat files to merge into wb_view scalars
copeCounter=1;
while [ "$copeCounter" -le "${NumContrasts}" ] ; do
	Contrast=`echo $ContrastNames | cut -d " " -f $copeCounter`
	echo "${Subject}_${LevelTwofsfName}_level2_${Contrast}${TemporalFilterString}${SmoothingString}${RegString}${ParcellationString}" >> ${LevelTwoFEATDir}/Contrasttemp.txt
	echo ${Contrast} >> ${LevelTwoFEATDir}/Contrasts.txt
	${CARET7DIR}/wb_command -cifti-convert-to-scalar ${LevelTwoFEATDir}/${Analysis}/cope${copeCounter}.feat/zstat1.${Extension} ROW ${LevelTwoFEATDir}/${Subject}_${LevelTwofsfName}_level2_zstat_${Contrast}${TemporalFilterString}${SmoothingString}${RegString}${ParcellationString}.${ScalarExtension} -name-file ${LevelTwoFEATDir}/Contrasttemp.txt
	${CARET7DIR}/wb_command -cifti-convert-to-scalar ${LevelTwoFEATDir}/${Analysis}/cope${copeCounter}.feat/cope1.${Extension} ROW ${LevelTwoFEATDir}/${Subject}_${LevelTwofsfName}_level2_cope_${Contrast}${TemporalFilterString}${SmoothingString}${RegString}${ParcellationString}.${ScalarExtension} -name-file ${LevelTwoFEATDir}/Contrasttemp.txt
	rm ${LevelTwoFEATDir}/Contrasttemp.txt
	zMergeSTRING="${zMergeSTRING}-cifti ${LevelTwoFEATDir}/${Subject}_${LevelTwofsfName}_level2_zstat_${Contrast}${TemporalFilterString}${SmoothingString}${RegString}${ParcellationString}.${ScalarExtension} "
	bMergeSTRING="${bMergeSTRING}-cifti ${LevelTwoFEATDir}/${Subject}_${LevelTwofsfName}_level2_cope_${Contrast}${TemporalFilterString}${SmoothingString}${RegString}${ParcellationString}.${ScalarExtension} "

	if $runVolume ; then
		echo "OTHER" >> ${LevelTwoFEATDir}/wbtemp.txt
		echo "1 255 255 255 255" >> ${LevelTwoFEATDir}/wbtemp.txt
		${CARET7DIR}/wb_command -volume-label-import ${LevelTwoFEATDir}/StandardVolumeStats/mask.nii.gz ${LevelTwoFEATDir}/wbtemp.txt ${LevelTwoFEATDir}/StandardVolumeStats/mask.nii.gz -discard-others -unlabeled-value 0
		rm ${LevelTwoFEATDir}/wbtemp.txt
		${CARET7DIR}/wb_command -cifti-create-dense-timeseries ${LevelTwoFEATDir}/${Subject}_${LevelTwofsfName}_level2vol_zstat_${Contrast}${TemporalFilterString}${SmoothingString}.dtseries.nii -volume ${LevelTwoFEATDir}/StandardVolumeStats/cope${copeCounter}.feat/zstat1.nii.gz ${LevelTwoFEATDir}/StandardVolumeStats/mask.nii.gz -timestep 1 -timestart 1
		${CARET7DIR}/wb_command -cifti-convert-to-scalar ${LevelTwoFEATDir}/${Subject}_${LevelTwofsfName}_level2vol_zstat_${Contrast}${TemporalFilterString}${SmoothingString}.dtseries.nii ROW ${LevelTwoFEATDir}/${Subject}_${LevelTwofsfName}_level2vol_zstat_${Contrast}${TemporalFilterString}${SmoothingString}.dscalar.nii -name-file ${LevelTwoFEATDir}/Contrasttemp.txt
		${CARET7DIR}/wb_command -cifti-create-dense-timeseries ${LevelTwoFEATDir}/${Subject}_${LevelTwofsfName}_level2vol_cope_${Contrast}${TemporalFilterString}${SmoothingString}.dtseries.nii -volume ${LevelTwoFEATDir}/StandardVolumeStats/cope${copeCounter}.feat/cope1.nii.gz ${LevelTwoFEATDir}/StandardVolumeStats/mask.nii.gz -timestep 1 -timestart 1
		${CARET7DIR}/wb_command -cifti-convert-to-scalar ${LevelTwoFEATDir}/${Subject}_${LevelTwofsfName}_level2vol_cope_${Contrast}${TemporalFilterString}${SmoothingString}.dtseries.nii ROW ${LevelTwoFEATDir}/${Subject}_${LevelTwofsfName}_level2vol_cope_${Contrast}${TemporalFilterString}${SmoothingString}.dscalar.nii -name-file ${LevelTwoFEATDir}/Contrasttemp.txt
		rm ${LevelTwoFEATDir}/${Subject}_${LevelTwofsfName}_level2vol_{cope,zstat}_${Contrast}${TemporalFilterString}${SmoothingString}.dtseries.nii
		VolzMergeSTRING="${VolzMergeSTRING}-cifti ${LevelTwoFEATDir}/${Subject}_${LevelTwofsfName}_level2vol_zstat_${Contrast}${TemporalFilterString}${SmoothingString}.dscalar.nii "
		VolbMergeSTRING="${VolbMergeSTRING}-cifti ${LevelTwoFEATDir}/${Subject}_${LevelTwofsfName}_level2vol_cope_${Contrast}${TemporalFilterString}${SmoothingString}.dscalar.nii "
	fi
	copeCounter=$(($copeCounter+1))
done

# Perform the merge into viewable scalar files
${CARET7DIR}/wb_command -cifti-merge ${LevelTwoFEATDir}/${Subject}_${LevelTwofsfName}_level2_zstat${TemporalFilterString}${SmoothingString}${RegString}${ParcellationString}.${ScalarExtension} ${zMergeSTRING}
${CARET7DIR}/wb_command -cifti-merge ${LevelTwoFEATDir}/${Subject}_${LevelTwofsfName}_level2_cope${TemporalFilterString}${SmoothingString}${RegString}${ParcellationString}.${ScalarExtension} ${bMergeSTRING}
if $runVolume  ; then
	${CARET7DIR}/wb_command -cifti-merge ${LevelTwoFEATDir}/${Subject}_${LevelTwofsfName}_level2vol_zstat${TemporalFilterString}${SmoothingString}.dscalar.nii ${VolzMergeSTRING}
	${CARET7DIR}/wb_command -cifti-merge ${LevelTwoFEATDir}/${Subject}_${LevelTwofsfName}_level2vol_cope${TemporalFilterString}${SmoothingString}.dscalar.nii ${VolbMergeSTRING}
fi

log_Msg "Complete"
