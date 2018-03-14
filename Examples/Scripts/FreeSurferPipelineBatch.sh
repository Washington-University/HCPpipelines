#!/usr/bin/env bash
set -e

# set defaults
args=""
BatchFolder=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ) # folder where this script is stored
EnvironmentScript="${BatchFolder}/SetUpHCPPipeline.sh" # Pipeline environment script
StudyFolder="${HOME}/projects/Pipelines_ExampleData" # Location of subject folders (named by subject IDs in SubjList)
SubjList="100307" # Space delimited list of subject IDs
LogDir="./log"
UseT2w="TRUE"
runlocal="FALSE"

# parse the input arguments
for a in "$@" ; do
  case $a in
    --StudyFolder=*)  StudyFolder="${a#*=}"; shift ;;
    --SubjList=*)     SubjList="${a#*=}"; shift ;;
    --LogDir=*)       LogDir="${a#*=}"; shift ;;
    --noT2w)          UseT2w="FALSE"; shift ;;
    --runlocal)       runlocal="TRUE"; shift ;;
    *)                args="$args $a"; shift ;; # unsupported argument
  esac
done

# check if no redundant arguments have been set
if [[ -n $args ]] ; then
  >&2 echo ""; >&2 echo "unsupported arguments are given:" $args
  exit 1
fi

[[ $UseT2w == "FALSE" ]] && echo "Reqested to run without T2w images."

# Requirements for this script
#  installed versions of: FSL (version 5.0.6), FreeSurfer (version 5.3.0-HCP), gradunwarp (HCP version 1.0.2) if doing gradient distortion correction
#  environment: FSLDIR , FREESURFER_HOME , HCPPIPEDIR , CARET7DIR , PATH (for gradient_unwarp.py)

#Set up pipeline environment variables and software
source ${EnvironmentScript}

# Log the originating call
echo "$@"

#if [[ -n $SGE_ROOT ]] ; then
    QUEUE="-q verylong.q"
    #QUEUE="-q hcp_priority.q"
#fi

<<"BLOCK_COMMENT"
# when on the fmrib server, pick a specific jalapeno node
# unfortunately, this fails when a broken node is picked
if [[ -d /home/fmribadmin/ ]] ; then
  # randomly pick a relatively free node on jalapeno01-09
  # list all jobs running on jalapeno 01-09
  list=$(qstat -u \* | grep -o '@jalapeno0[0-9]' | cut -d'0' -f2)
  # count the number of jobs per node
  list=$(echo 1 2 3 4 5 6 7 8 9 $list | tr " " "\n" | sort -n | uniq -c | sort -n)
  # find the lowest number of users
  lowest=$(echo "$list" | head -1)
  lowest=$(echo $lowest | cut -d' ' -f1)
  # pick a random node from the ones with the fewest users
  nodes=($(echo "$list" | grep $lowest' [0-9]' | awk '{print $2}'))
  picknode=${nodes[$RANDOM % ${#nodes[@]}]}
  # assign queue
  QUEUE="$QUEUE@jalapeno0$picknode.fmrib.ox.ac.uk"
fi
BLOCK_COMMENT

PRINTCOM=""
#PRINTCOM="echo"

# set the cluster queuing or local execution command
if [[ $runlocal == TRUE ]] ; then
    echo "About to run ${HCPPIPEDIR}/FreeSurfer/FreeSurferPipeline.sh"
    queuing_command=""
else
    echo "About to use fsl_sub to queue or run ${HCPPIPEDIR}/FreeSurfer/FreeSurferPipeline.sh"
    mkdir -p $LogDir # ensure the directory to store fsl_sub logfiles exists
    queuing_command="${FSLDIR}/bin/fsl_sub ${QUEUE} -l $LogDir"
fi


########################################## INPUTS ##########################################

#Scripts called by this script do assume they run on the outputs of the PreFreeSurfer Pipeline

######################################### DO WORK ##########################################

for Subject in ${SubjList//@/ } ; do
  echo $Subject

  #Input Variables
  SubjectID="$Subject" #FreeSurfer Subject ID Name
  SubjectDIR="${StudyFolder}/${Subject}/T1w" #Location to Put FreeSurfer Subject's Folder
  T1wImage="${StudyFolder}/${Subject}/T1w/T1w_acpc_dc_restore.nii.gz" #T1w FreeSurfer Input (Full Resolution)
  T1wImageBrain="${StudyFolder}/${Subject}/T1w/T1w_acpc_dc_restore_brain.nii.gz" #T1w FreeSurfer Input (Full Resolution)
  T2wImage="${StudyFolder}/${Subject}/T1w/T2w_acpc_dc_restore.nii.gz" #T2w FreeSurfer Input (Full Resolution)

  if [[ $UseT2w = "FALSE" ]] ; then
      T2wImage=""
  elif [[ ! -r $T2wImage ]] ; then
      echo "No (readable) T2w image found for subject " $Subject ", continuing without."
      T2wImage=""
  fi

  ${queuing_command} ${HCPPIPEDIR}/FreeSurfer/FreeSurferPipeline.sh \
      --subject="$Subject" \
      --subjectDIR="$SubjectDIR" \
      --t1="$T1wImage" \
      --t1brain="$T1wImageBrain" \
      --t2="$T2wImage" \
      --printcom=$PRINTCOM

  # The following lines are used for interactive debugging to set the positional parameters: $1 $2 $3 ...

  echo "set -- --subject="$Subject" \
      --subjectDIR="$SubjectDIR" \
      --t1="$T1wImage" \
      --t1brain="$T1wImageBrain" \
      --t2="$T2wImage" \
      --printcom=$PRINTCOM"

  echo ". ${EnvironmentScript}"

done
