#!/bin/bash

get_batch_options() {
    local arguments=($@)

    unset command_line_specified_study_folder
    unset command_line_specified_subj_list
    unset command_line_specified_run_local

    local index=0
    local numArgs=${#arguments[@]}
    local argument

    while [ ${index} -lt ${numArgs} ]; do
        argument=${arguments[index]}

        case ${argument} in
            --StudyFolder=*)
                command_line_specified_study_folder=${argument/*=/""}
                index=$(( index + 1 ))
                ;;
            --SubjList=*)
                command_line_specified_subj_list=${argument/*=/""}
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

get_batch_options $@

StudyFolder="${HOME}/projects/Pipelines_ExampleData" #Location of Subject folders (named by subjectID)
Subjlist="100307" #Space delimited list of subject IDs
BatchFolder=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
EnvironmentScript="${BatchFolder}/SetUpHCPPipeline.sh" #Pipeline environment script

if [ -n "${command_line_specified_study_folder}" ]; then
    StudyFolder="${command_line_specified_study_folder}"
fi

if [ -n "${command_line_specified_subj_list}" ]; then
  # replace all "@" with " "
  command_line_specified_subj_list="${command_line_specified_subj_list//@/ }"
  # overwrite default with user specified value
  Subjlist="${command_line_specified_subj_list}"
fi

# Requirements for this script
#  installed versions of: FSL (version 5.0.6), FreeSurfer (version 5.3.0-HCP), gradunwarp (HCP version 1.0.2)
#  environment: FSLDIR , FREESURFER_HOME , HCPPIPEDIR , CARET7DIR , PATH (for gradient_unwarp.py)

#Set up pipeline environment variables and software
. ${EnvironmentScript}

# Log the originating call
echo "$@"

#if [ X$SGE_ROOT != X ] ; then
    QUEUE="-q veryshort.q"
#fi

PRINTCOM=""
#PRINTCOM="echo"
#QUEUE="-q veryshort.q"


########################################## INPUTS ##########################################

#Scripts called by this script do assume they run on the outputs of the FreeSurfer Pipeline

######################################### DO WORK ##########################################

# Naming Conventions
T1wFolder="T1w"
T2wFolder="T2w"
statsFolder="stats"
ACPCFolder="ACPCAlignment"
BiasFolder="BiasFieldCorrection_*"
BrainFolder="BrainExtraction_*"
FSAverageLink="fsaverage"
FSLHAverageLink="lh.EC_average"
FSRHAverageLink="rh.EC_average"
AtlasSpaceFolder="MNINonLinear"
ResultsFolder="Results"
xfmsFolder="xfms"
Files2Remove=("*_1mm" "T1w_acpc_brain_mask" "T1w_acpc_brain" "T1w_acpc" "*_gdc")

for Subject in $Subjlist ; do
  echo $Subject

  # Subject specific naming conventions
  SubjT1w="$StudyFolder"/"$Subject"/"$T1wFolder"
  SubjT2w="$StudyFolder"/"$Subject"/"$T2wFolder"
  SubjFS="$SubjT1w"/"${Subject}"
  SubjAtlas="$StudyFolder"/"$Subject"/"$AtlasSpaceFolder"
  SubjFiles2Remove="${Files2Remove[@]/#/$SubjT1w/}"
  SubjTmpFS=$(mktemp -d "${SubjT1w}/tmp.FS.XXXXXXXXXX")
  SubjTmpxfms=$(mktemp -d "${SubjAtlas}/tmp.xfms.XXXXXXXXXX")

  if [ -n "${command_line_specified_run_local}" ] ; then
      echo "About to run clean-up after ${HCPPIPEDIR}/PostFreeSurfer/PostFreeSurferPipeline.sh"
      queuing_command="exec"
  else
      echo "About to use fsl_sub to queue or clean-up after ${HCPPIPEDIR}/PostFreeSurfer/PostFreeSurferPipeline.sh"
      queuing_command="${FSLDIR}/bin/fsl_sub ${QUEUE}"
  fi

  # create a tempfile to submit multiple commands
  TmpFile=$(mktemp "$(pwd)/tmp.$(basename $0).cleanup.XXXXXXXXXX")
  chmod +x $TmpFile

  # write the commands to the tempfile
  echo -n "rm -rf ${SubjT2w}; " >> $TmpFile
  echo -n "rm -rf ${SubjT1w}/${ACPCFolder}; " >> $TmpFile
  echo -n "rm -rf ${SubjT1w}/${BiasFolder}; " >> $TmpFile
  echo -n "rm -rf ${SubjT1w}/${BrainFolder}; " >> $TmpFile
  echo -n "rm -f ${SubjT1w}/${FSAverageLink}; " >> $TmpFile
  echo -n "rm -f ${SubjT1w}/${FSLHAverageLink}; " >> $TmpFile
  echo -n "rm -f ${SubjT1w}/${FSRHAverageLink}; " >> $TmpFile
  echo -n "mv -f ${SubjFS}/${statsFolder} ${SubjTmpFS}/${statsFolder}; " >> $TmpFile
  echo -n "rm -rf ${SubjFS}; " >> $TmpFile
  echo -n "mv -f ${SubjTmpFS} ${SubjFS}; " >> $TmpFile
  echo -n "$FSLDIR/bin/imrm ${SubjFiles2Remove}; " >> $TmpFile
  echo -n "rm -rf ${SubjAtlas}/${ResultsFolder}; " >> $TmpFile
  echo -n "$FSLDIR/bin/immv ${SubjAtlas}/${xfmsFolder}/acpc_dc2standard ${SubjTmpxfms}/acpc_dc2standard; " >> $TmpFile
  echo -n "$FSLDIR/bin/immv ${SubjAtlas}/${xfmsFolder}/standard2acpc_dc ${SubjTmpxfms}/standard2acpc_dc; " >> $TmpFile
  echo -n "$FSLDIR/bin/immv ${SubjAtlas}/${xfmsFolder}/NonlinearRegJacobians ${SubjTmpxfms}/NonlinearRegJacobians; " >> $TmpFile
  echo -n "rm -rf ${SubjAtlas}/${xfmsFolder}; " >> $TmpFile
  echo -n "mv -f ${SubjTmpxfms} ${SubjAtlas}/${xfmsFolder}; " >> $TmpFile
  echo -n "rm -f $TmpFile; " >> $TmpFile

  # submit or execute the tempfile
  ${queuing_command} $TmpFile

done
