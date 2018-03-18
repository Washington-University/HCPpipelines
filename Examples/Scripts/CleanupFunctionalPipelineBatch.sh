#!/usr/bin/env bash
set -e

# set defaults
args=""
BatchFolder=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ) # folder where this script is stored
EnvironmentScript="${BatchFolder}/SetUpHCPPipeline.sh" # Pipeline environment script
StudyFolder="${HOME}/projects/Pipelines_ExampleData" # Location of subject folders (named by subject IDs in SubjList)
SubjList="100307" # Space delimited list of subject IDs
LogDir="./log"
runlocal="FALSE"

# parse the input arguments
for a in "$@" ; do
  case $a in
    --StudyFolder=*)  StudyFolder="${a#*=}"; shift ;;
    --SubjList=*)     SubjList="${a#*=}"; shift ;;
    --LogDir=*)       LogDir="${a#*=}"; shift ;;
    --runlocal)       runlocal="TRUE"; shift ;;
    *)                args="$args $a"; shift ;; # unsupported argument
  esac
done

# check if no redundant arguments have been set
if [[ -n $args ]] ; then
  >&2 echo ""; >&2 echo "unsupported arguments are given:" $args
  exit 1
fi

# Requirements for this script
#  installed versions of: FSL (version 5.0.6), FreeSurfer (version 5.3.0-HCP), gradunwarp (HCP version 1.0.2) if doing gradient distortion correction
#  environment: FSLDIR , FREESURFER_HOME , HCPPIPEDIR , CARET7DIR , PATH (for gradient_unwarp.py)

# Set up pipeline environment variables and software
source ${EnvironmentScript}

# Log the originating call
echo "$@"

#if [[ -n $SGE_ROOT ]] ; then
    QUEUE="-q veryshort.q"
    #QUEUE="-q hcp_priority.q"
#fi

PRINTCOM=""
#PRINTCOM="echo"

# set the cluster queuing or local execution command
if [[ $runlocal == TRUE ]] ; then
    echo "About to run ${HCPPIPEDIR}/Examples/Scripts/CleanupFunctionalPipelineBatch.sh"
    queuing_command=""
else
    echo "About to use fsl_sub to queue or run ${HCPPIPEDIR}/Examples/Scripts/CleanupFunctionalPipelineBatch.sh"
    mkdir -p $LogDir # ensure the directory to store fsl_sub logfiles exists
    queuing_command="${FSLDIR}/bin/fsl_sub ${QUEUE} -l $LogDir -N CleanupFunctionalPipeline"
fi


########################################## INPUTS ##########################################

#Scripts called by this script do assume they run on the outputs of the FreeSurfer Pipeline

######################################### DO WORK ##########################################

# Naming Conventions
T1wFolder="T1w"
AtlasSpaceFolder="MNINonLinear"
DiffusionFolder="Diffusion"
UnprocessedFolder="unprocessed"
ResultsFolder="Results"

for Subject in ${SubjList//@/ } ; do
  echo $Subject

  # Subject specific naming conventions
  SubjT1w="$StudyFolder"/"$Subject"/"$T1wFolder"
  SubjAtlas="$StudyFolder"/"$Subject"/"$AtlasSpaceFolder"
  Folders2Remove=$(ls "$StudyFolder/$Subject" | tr ' ' '\n' | grep -v "$T1wFolder\|$AtlasSpaceFolder\|$DiffusionFolder\|$UnprocessedFolder") || true
  Folders2Remove="$(echo $Folders2Remove)"
  [[ -z $Folders2Remove ]] && Folders2Remove="NONE"
  fmriList=$(ls "$SubjAtlas/$ResultsFolder")
  fmriList="$(echo $fmriList)"

  # create a tempfile to submit multiple commands
  tmpFile=$(mktemp "${LogDir}/tmp.$(basename $0).cleanup.XXXXXXXXXX")
  chmod +x $tmpFile

  # write the commands to the tempfile
  cat > $tmpFile <<EOF
#!/usr/bin/env bash
set -e
echo Cleanup started
#for folder in $Folders2Remove ; do
#  rm -rf "$StudyFolder/$Subject/\$folder"
#done
rm -rf $SubjT1w/$ResultsFolder
echo "working on:"
for fmriName in $fmriList ; do
  echo "  \$fmriName"
  rm -rf "$StudyFolder/$Subject/\$fmriName"
  fmriDirTmp=\$(mktemp -d "$SubjAtlas/$ResultsFolder/tmp.\$fmriName.XXXXXXXXXX")
  mv -f "$SubjAtlas/$ResultsFolder/\$fmriName/\$fmriName".nii.gz "\$fmriDirTmp/\$fmriName".nii.gz
  mv -f "$SubjAtlas/$ResultsFolder/\$fmriName/\$fmriName"_hp2000_clean.nii.gz "\$fmriDirTmp/\$fmriName"_hp2000_clean.nii.gz
  mv -f "$SubjAtlas/$ResultsFolder/\$fmriName/\$fmriName"_Atlas.dtseries.nii "\$fmriDirTmp/\$fmriName"_Atlas.dtseries.nii
  mv -f "$SubjAtlas/$ResultsFolder/\$fmriName/\$fmriName"_Atlas_hp2000_clean.dtseries.nii "\$fmriDirTmp/\$fmriName"_Atlas_hp2000_clean.dtseries.nii
  mv -f "$SubjAtlas/$ResultsFolder/\$fmriName"/Movement_RelativeRMS_mean.txt "\$fmriDirTmp"/Movement_RelativeRMS_mean.txt
  rm -rf "$SubjAtlas/$ResultsFolder/\$fmriName"
  mv -f "\$fmriDirTmp" "$SubjAtlas/$ResultsFolder/\$fmriName"
done
echo Cleanup finished
rm -f $tmpFile
EOF

  # submit or execute the tempfile
  ${queuing_command} sh $tmpFile

done
