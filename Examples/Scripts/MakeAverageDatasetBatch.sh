#!/bin/bash 

get_batch_options() {
    local arguments=("$@")

    command_line_specified_study_folder=""
    command_line_specified_subj_list=""
    command_line_specified_group_average_name=""
    command_line_specified_reg_name=""
    command_line_specified_symlink_study_folder=""
    command_line_specified_run_local="FALSE"

    local index=0
    local numArgs=${#arguments[@]}
    local argument

    while [ ${index} -lt ${numArgs} ]; do
        argument=${arguments[index]}
        case ${argument} in
            --StudyFolder=*)
                command_line_specified_study_folder=${argument#*=}
                index=$(( index + 1 ))
                ;;
            --SubjList=*)
                command_line_specified_subj_list=${argument#*=}
                index=$(( index + 1 ))
                ;;
	          --GroupAverageName=*)
	              command_line_specified_group_average_name=${argument#*=}
                index=$(( index + 1 ))
		            ;;
	          --RegName=*)
	              command_line_specified_reg_name=${argument#*=}
                index=$(( index + 1 ))
                ;;
	          --SymLinkStudyFolder=*)
	              command_line_specified_symlink_study_folder=${argument#*=}
                index=$(( index + 1 ))
                ;;
            --runlocal)
                command_line_specified_run_local="TRUE"
                index=$(( index + 1 ))
                ;;
            *)
                echo ""
                echo "ERROR: Unrecognized Option: ${argument}"
                echo ""
                exit 1
                ;;
        esac
    done
}

get_batch_options "$@"

# Default values
StudyFolder="${HOME}/projects/Pipelines_ExampleData" #Location of Subject folders (named by subjectID)
Subjlist="100206 100307 100408" #Space delimited list of subject IDs
#RegName="NONE"
RegName="MSMAll"

EnvironmentScript="${HOME}/projects/Pipelines/Examples/Scripts/SetUpHCPPipeline.sh" #Pipeline environment script

# Set script variables if specified at the command line
if [ -n "${command_line_specified_study_folder}" ]; then
    StudyFolder="${command_line_specified_study_folder}"
fi

if [ -n "${command_line_specified_subj_list}" ]; then
    Subjlist="${command_line_specified_subj_list}"
    #Allow the --SubjList argument to be a file containing a list of subjects
    # In this file, the subjects may be separated by spaces or newlines 
    # (or even a combination of the two).
    if [ -e $Subjlist ] ; then
	Subjlist=`cat $Subjlist | tr "\n" " "`
    fi
fi

if [ -n "${command_line_specified_group_average_name}" ]; then
    GroupAverageName="${command_line_specified_group_average_name}"
else
    nSubj=`echo $Subjlist | wc -w`
    GroupAverageName=GroupAnalysis_n${nSubj}
fi

if [ -n "${command_line_specified_reg_name}" ]; then
    RegName="${command_line_specified_reg_name}"
fi

##### Code for running this script when StudyFolder is on a read-only file system #####
# Numerous parts of MakeAverageDataset.sh expect write-access to the StudyFolder.
# The following workaround allows one to proceed by creating a directory, 
# specified by the --SymLinkStudyFolder command line option, 
# with symlinks to the necessary contents of StudyFolder for the subjects in Subjlist.

if [ -n "${command_line_specified_symlink_study_folder}" ]; then
    SymLinkStudyFolder=${command_line_specified_symlink_study_folder}
    mkdir -p ${SymLinkStudyFolder}
    for subj in $Subjlist ; do
	echo "Symlinking selected contents of ${StudyFolder}/${subj} into ${SymLinkStudyFolder}/${subj}"
	mkdir -p $SymLinkStudyFolder/$subj/MNINonLinear
	mkdir -p $SymLinkStudyFolder/$subj/T1w
	# A recursive symlinking of *all* the files for each subject is time consuming.
	# The following set of files/directories appears to be sufficient
	cp -psu $StudyFolder/$subj/MNINonLinear/* $SymLinkStudyFolder/$subj/MNINonLinear 2> /dev/null
	cp -rpsu $StudyFolder/$subj/MNINonLinear/fsaverage* $SymLinkStudyFolder/$subj/MNINonLinear/.  2> /dev/null
	cp -rpsu $StudyFolder/$subj/MNINonLinear/Native $SymLinkStudyFolder/$subj/MNINonLinear/.  2> /dev/null
	cp -rpsu $StudyFolder/$subj/T1w/fsaverage* $SymLinkStudyFolder/$subj/T1w/. 2> /dev/null
	cp -rpsu $StudyFolder/$subj/T1w/Native $SymLinkStudyFolder/$subj/T1w/. 2> /dev/null
    done
    # Use this as our new "StudyFolder" for the purposes of MakeAverageDataset.sh
    StudyFolder=$SymLinkStudyFolder
fi

# Requirements for this script
#  installed versions of: FSL, Connectome Workbench (wb_command)
#  environment: HCPPIPEDIR, FSLDIR, CARET7DIR

#Set up pipeline environment variables and software
source "$EnvironmentScript"

# Log the originating call
echo "$@"

#NOTE: syntax for QUEUE has changed compared to earlier pipeline releases,
#DO NOT include "-q " at the beginning
#default to no queue, implying run local
QUEUE=""
#QUEUE="hcp_priority.q"

if [[ -n $HCPPIPEDEBUG ]]
then
    set -x
fi

SurfaceAtlasDIR="${HCPPIPEDIR}/global/templates/standard_mesh_atlases" 
GrayordinatesSpaceDIR="${HCPPIPEDIR}/global/templates/91282_Greyordinates" 
HighResMesh="164"
LowResMesh="32"
FreeSurferLabels="${HCPPIPEDIR}/global/config/FreeSurferAllLut.txt"
Sigma="1" #Pregradient Smoothing

VideenMaps="corrThickness thickness MyelinMap_BC SmoothedMyelinMap_BC"
GreyScaleMaps="sulc curvature"
if [ "$RegName" = "NONE" ] ; then
    DistortionMaps="SphericalDistortion" #Don't Include ArealDistortion or EdgeDistortion with RegName NONE  ###TODO why?
else
    DistortionMaps="SphericalDistortion ArealDistortion EdgeDistortion"
fi
GradientMaps="MyelinMap_BC SmoothedMyelinMap_BC corrThickness"
MultiMaps="NONE" #For dscalar maps with multiple maps per subject
STDMaps="sulc curvature corrThickness thickness MyelinMap_BC"

Subjlist=`echo ${Subjlist} | sed 's/ /@/g'`
VideenMaps=`echo ${VideenMaps} | sed 's/ /@/g'`
GreyScaleMaps=`echo ${GreyScaleMaps} | sed 's/ /@/g'`
DistortionMaps=`echo ${DistortionMaps} | sed 's/ /@/g'`
GradientMaps=`echo ${GradientMaps} | sed 's/ /@/g'`
STDMaps=`echo ${STDMaps} | sed 's/ /@/g'`
MultiMaps=`echo ${MultiMaps} | sed 's/ /@/g'`

if [[ "${command_line_specified_run_local}" == "TRUE" || "$QUEUE" == "" ]] ; then
    echo "About to locally run ${HCPPIPEDIR}/Supplemental/MakeAverageDataset/MakeAverageDataset.sh"
    queuing_command=("$HCPPIPEDIR"/global/scripts/captureoutput.sh)
else
    echo "About to use fsl_sub to queue ${HCPPIPEDIR}/Supplemental/MakeAverageDataset/MakeAverageDataset.sh"
    queuing_command=("${FSLDIR}/bin/fsl_sub" -q "$QUEUE")
fi

# Optional arguments in MakeAverageDataset.sh:
# --no-merged-t1t2-vols: Skip creation of merged T1/T2 volumes.  Will still generate T1/T2 average.
# --no-label-vols: Skip creation of both merged and average wmparc and ribbon volumes.
# These can be helpful if you have a lot of subjects and are memory constrained.
"${queuing_command[@]}" "$HCPPIPEDIR"/Supplemental/MakeAverageDataset/MakeAverageDataset.sh \
    --subject-list="$Subjlist" \
    --study-folder="$StudyFolder" \
    --group-average-name="$GroupAverageName" \
    --surface-atlas-dir="$SurfaceAtlasDIR" \
    --grayordinates-space-dir="$GrayordinatesSpaceDIR" \
    --high-res-mesh="$HighResMesh" \
    --low-res-meshes="$LowResMesh" \
    --freesurfer-labels="$FreeSurferLabels" \
    --sigma="$Sigma" \
    --reg-name="$RegName" \
    --videen-maps="$VideenMaps" \
    --greyscale-maps="$GreyScaleMaps" \
    --distortion-maps="$DistortionMaps" \
    --gradient-maps="$GradientMaps" \
    --std-maps="$STDMaps" \
    --multi-maps="$MultiMaps"

# The following lines are used for interactive debugging to set the positional parameters: $1 $2 $3 ...

echo "set -- --subject-list=$Subjlist \
    --study-folder=$StudyFolder \
    --group-average-name=$GroupAverageName \
    --surface-atlas-dir=$SurfaceAtlasDIR \
    --grayordinates-space-dir=$GrayordinatesSpaceDIR \
    --high-res-mesh=$HighResMesh \
    --low-res-meshes=$LowResMesh \
    --freesurfer-labels=$FreeSurferLabels \
    --sigma=$Sigma \
    --reg-name=$RegName \
    --videen-maps=$VideenMaps \
    --greyscale-maps=$GreyScaleMaps \
    --distortion-maps=$DistortionMaps \
    --gradient-maps=$GradientMaps \
    --std-maps=$STDMaps \
    --multi-maps=$MultiMaps"

 echo ". ${EnvironmentScript}"


