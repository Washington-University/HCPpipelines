#!/bin/bash 

get_usage_and_exit(){
    echo "usage: "
    echo "PostFreeSurferPipelineBatch-long.sh [options]"
    echo "options:"
    echo "  --StudyFolder <study folder>    root processing directory [/media/myelin/brainmappers/Connectome_Project/MishaLongitudinal/hcp]"
    echo "  --runlocal                      run locally [TRUE]"
    exit -1
}

get_batch_options() {
    local arguments=("$@")

    command_line_specified_study_folder=""
    command_line_specified_subj=""
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
            --Subject=*)
                command_line_specified_subj=${argument#*=}
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
StudyFolder=/media/myelin/brainmappers/Connectome_Project/MishaLongitudinal/hcp/FSLong-test
#StudyFolder="${HOME}/projects/Pipelines_ExampleData" #Location of Subject folders (named by subjectID)

#list of subject labels, space separated
Subjlist="HCA6002236"

#list of timepoints per each subject. Subject timepoint groups are space separated, timepoints within group are @ separated
Timepoint_list="HCA6002236_V1_MR@HCA6002236_V2_MR"

#list of longitudinal template labels, one per subject, space separated
Template_list="HCA6002236_V1_V2"


#EnvironmentScript="${HOME}/projects/Pipelines/Examples/Scripts/SetUpHCPPipeline.sh" #Pipeline environment script
EnvironmentScript=/media/myelin/brainmappers/Connectome_Project/MishaLongitudinal/hcp/scripts/SetUpHCPPipeline-long.sh


#if [ -n "${command_line_specified_study_folder}" ]; then
#    StudyFolder="${command_line_specified_study_folder}"
#fi

#if [ -n "${command_line_specified_subj}" ]; then
#    Subjlist="${command_line_specified_subj}"
#fi

if [ -z "$StudyFolder" ]; then echo "No study folder specified"; get_usage_and_exit; fi
if [ -z "$Subjlist" ]; then echo "No experiments were specified"; get_usage_and_exit; fi
if [ -z "$Timepoint_list" ]; then echo "No study folder specified"; get_usage_and_exit; fi
if [ -z "$EnvironmentScript" ]; then echo "No experiments were specified"; get_usage_and_exit; fi

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

########################################## INPUTS ########################################## 

#Scripts called by this script do assume they run on the outputs of the FreeSurfer Pipeline

######################################### DO WORK ##########################################

Template_list=( ${Template_list[@]} )

for i in ${!Subjlist[@]}; do
  Subject=${Subjlist[i]}
  LongitudinalTemplate=${Template_list[i]}
  IFS=@ read -r -a Timepoints <<< "${Timepoint_list[i]}"
  
  echo Subject: $Subject
  echo Template: $Template
  echo Timepoints: ${Timepoints[@]}

  #Input Variables common for timepoint and template modes.
  SurfaceAtlasDIR="${HCPPIPEDIR_Templates}/standard_mesh_atlases"
  GrayordinatesSpaceDIR="${HCPPIPEDIR_Templates}/91282_Greyordinates"
  GrayordinatesResolution="2" #Usually 2mm, if multiple delimit with @, must already exist in templates dir
  HighResMesh="164" #Usually 164k vertices
  LowResMeshes="32" #Usually 32k vertices, if multiple delimit with @, must already exist in templates dir
  SubcorticalGrayLabels="${HCPPIPEDIR_Config}/FreeSurferSubcorticalLabelTableLut.txt"
  FreeSurferLabels="${HCPPIPEDIR_Config}/FreeSurferAllLut.txt"
  ReferenceMyelinMaps="${HCPPIPEDIR_Templates}/standard_mesh_atlases/Conte69.MyelinMap_BC.164k_fs_LR.dscalar.nii"
  RegName="MSMSulc" #MSMSulc is recommended, if binary is not available use FS (FreeSurfer)
  if [[ "${command_line_specified_run_local}" == "TRUE" || "$QUEUE" == "" ]] ; then
	echo "About to locally run ${HCPPIPEDIR}/PostFreeSurfer/PostFreeSurferPipeline.sh"
		#NOTE: fsl_sub without -q runs locally and captures output in files
	      	queuing_command=("$FSLDIR/bin/fsl_sub")
	else
		echo "About to use fsl_sub to queue ${HCPPIPEDIR}/PostFreeSurfer/PostFreeSurferPipeline.sh"
		queuing_command=("$FSLDIR/bin/fsl_sub" -q "$QUEUE")	
  fi

  for Timepoint in ${Timepoints[@]}; do
  	#input variables specific for timepoint mode (if any)  		  
  	# ...
	
	#DEBUG
	#continue
	#process each timepoint
	$queuing_command "$HCPPIPEDIR"/PostFreeSurfer/PostFreeSurferPipeline.sh \
	      --study-folder="$StudyFolder" \
	      --subject="$Subject" \
	      --surfatlasdir="$SurfaceAtlasDIR" \
	      --grayordinatesdir="$GrayordinatesSpaceDIR" \
	      --grayordinatesres="$GrayordinatesResolution" \
	      --hiresmesh="$HighResMesh" \
	      --lowresmesh="$LowResMeshes" \
	      --subcortgraylabels="$SubcorticalGrayLabels" \
	      --freesurferlabels="$FreeSurferLabels" \
	      --refmyelinmaps="$ReferenceMyelinMaps" \
	      --regname="$RegName" \
	      --longitudinal_mode="TIMEPOINT" \
	      --longitudinal_template="$LongitudinalTemplate" \
	      --longitudinal_timepoint="$Timepoint"
	#DEBUG
	#break
  done
  #DEBUG
  #break;
  
  #input variables specific for template mode (if any)
  # ...
  #process template
  $queuing_command "$HCPPIPEDIR"/PostFreeSurfer/PostFreeSurferPipeline.sh \
      --study-folder="$StudyFolder" \
      --subject="$Subject" \
      --surfatlasdir="$SurfaceAtlasDIR" \
      --grayordinatesdir="$GrayordinatesSpaceDIR" \
      --grayordinatesres="$GrayordinatesResolution" \
      --hiresmesh="$HighResMesh" \
      --lowresmesh="$LowResMeshes" \
      --subcortgraylabels="$SubcorticalGrayLabels" \
      --freesurferlabels="$FreeSurferLabels" \
      --refmyelinmaps="$ReferenceMyelinMaps" \
      --regname="$RegName" \
      --longitudinal_mode="TEMPLATE" \
      --longitudinal_template="$LongitudinalTemplate" \
      --longitudinal_timepoint="$Timepoint"

  # The following lines are used for interactive debugging to set the positional parameters: $1 $2 $3 ...
  
  # echo "set -- --study-folder=$StudyFolder \
  #    --subject=$Subject \
  #    --surfatlasdir=$SurfaceAtlasDIR \
  #    --grayordinatesdir=$GrayordinatesSpaceDIR \
  #    --grayordinatesres=$GrayordinatesResolutions \
  #    --hiresmesh=$HighResMesh \
  #    --lowresmesh=$LowResMeshes \
  #    --subcortgraylabels=$SubcorticalGrayLabels \
  #    --freesurferlabels=$FreeSurferLabels \
  #    --refmyelinmaps=$ReferenceMyelinMaps \
  #    --regname=$RegName"
      
  # echo ". ${EnvironmentScript}"
done

