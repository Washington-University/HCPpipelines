#!/bin/bash
#~ND~FORMAT~MARKDOWN~
#~ND~START~
#
# # DiffPreprocPipeline_PostEddy.sh
#
# ## Copyright Notice
#
# Copyright (C) 2012-2016 The Human Connectome Project
#
# * Washington University in St. Louis
# * University of Minnesota
# * Oxford University
#
# ## Author(s)
#
# * Stamatios Sotiropoulos, FMRIB Analysis Group, Oxford University
# * Saad Jbabdi, FMRIB Analysis Group, Oxford University
# * Jesper Andersson, FMRIB Analysis Group, Oxford University
# * Matthew F. Glasser, Department of Anatomy and Neurobiology, Washington University in St. Louis
# * Timothy B. Brown, Neuroinformatics Research Group, Washington University in St. Louis
#
# ## Product
#
# [Human Connectome Project][HCP] (HCP) Pipelines
#
# ## License
#
# See the [LICENSE](https://github.com/Washington-University/Pipelines/blob/master/LICENSE.md) file
#
# ## Description
#
# This script, <code>DiffPreprocPipeline_PostEddy.sh</code>, implements the
# third (and last) part of the Preprocessing Pipeline for diffusion MRI described
# in [Glasser et al. 2013][GlasserEtAl]. The entire Preprocessing Pipeline for
# diffusion MRI is split into pre-eddy, eddy, and post-eddy scripts so that
# the running of eddy processing can be submitted to a cluster scheduler to
# take advantage of running on a set of GPUs without forcing the entire diffusion
# preprocessing to occur on a GPU enabled system.  This particular script
# implements the post-eddy part of the diffusion preprocessing.
#
# ## Prerequisite Installed Software for the Diffusion Preprocessing Pipeline
#
# * [FSL][FSL] - FMRIB's Software Library (version 5.0.6)
#
#   FSL's environment setup script must also be sourced
#
# * [FreeSurfer][FreeSurfer] (version 5.3.0-HCP)
#
# * [HCP-gradunwarp][HCP-gradunwarp] (HCP version 1.0.2)
#
# ## Prerequisite Environment Variables
#
# See output of usage function: e.g. <code>$ ./DiffPreprocPipeline_PostEddy.sh --help</code>
#
# <!-- References -->
#
# [HCP]: http://www.humanconnectome.org
# [GlasserEtAl]: http://www.ncbi.nlm.nih.gov/pubmed/23668970
# [FSL]: http://fsl.fmrib.ox.ac.uk
# [FreeSurfer]: http://freesurfer.net
# [HCP-gradunwarp]: https://github.com/Washington-University/gradunwarp/releases
#
#~ND~END~

set -eu

pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
    pipedirguessed=1
    #fix this if the script is more than one level below HCPPIPEDIR
    export HCPPIPEDIR="$(dirname -- "$0")/.."
fi

# Load function libraries
source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@" # Debugging functions; also sources log.shlib
source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"
source "${HCPPIPEDIR}/global/scripts/version.shlib"      # version_ functions

#compatibility
if (($# > 0))
then
    newargs=()
    origargs=("$@")
    extra_eddy_args_manual=()
    changeargs=0
    for ((i = 0; i < ${#origargs[@]}; ++i))
    do
        case "${origargs[i]}" in
            (--select-best-b0)
                #"--select-best-b0 true" works as-is, detect it and copy it as-is, but don't trigger the argument change
                if ((i + 1 < ${#origargs[@]})) && (opts_StringToBool "${origargs[i + 1]}" &> /dev/null)
                then
                    newargs+=("${origargs[i]}" "${origargs[i + 1]}")
                    #skip the boolean value, we took care of it
                    i=$((i + 1))
                else
                    newargs+=("${origargs[i]}"=TRUE)
                    changeargs=1
                fi
                ;;
            (*)
                #copy anything unrecognized
                newargs+=("${origargs[i]}")
                ;;
        esac
    done
    if ((changeargs))
    then
        echo "original arguments: $*"
        set -- "${newargs[@]}"
        echo "new arguments: $*"
        echo "extra eddy arguments: ${extra_eddy_args_manual[*]+"${extra_eddy_args_manual[*]}"}"
    fi
fi

# Establish defaults
DEFAULT_DEGREES_OF_FREEDOM=6

opts_SetScriptDescription "Perform the Post-Eddy steps of the HCP Diffusion Preprocessing Pipeline"

opts_AddMandatory '--path' 'StudyFolder' 'Path' "path to subject's data folder" 

opts_AddMandatory '--subject' 'Subject' 'subject ID' "subject-id"

opts_AddMandatory '--gdcoeffs' 'GdCoeffs' 'Path' "Path to file containing coefficients that describe spatial variations of the scanner gradients. Applied *after* 'eddy'. Use --gdcoeffs=NONE if not available."

opts_AddOptional '--dwiname' 'DWIName' 'String' "Name to give DWI output directories. Defaults to Diffusion" "Diffusion"

opts_AddOptional '--dof' 'DegreesOfFreedom' 'Number' "Degrees of Freedom for post eddy registration to structural images. Defaults to '${DEFAULT_DEGREES_OF_FREEDOM}'" "'${DEFAULT_DEGREES_OF_FREEDOM}'"

opts_AddOptional '--select-best-b0' 'SelectBestB0String' 'Boolean' "If set selects the best b0 for each phase encoding direction to pass on to topup rather than the default behaviour of using equally spaced b0's throughout the scan. The best b0 is identified as the least distorted (i.e., most similar to the average b0 after registration)." "False"

opts_AddOptional '--combine-data-flag' 'CombineDataFlag' 'number' "Specified value is passed as the CombineDataFlag value for the eddy_postproc.sh script. If JAC resampling has been used in eddy, this value determines what to do with the output file.
  2 - include in the output all volumes uncombined (i.e., output file of eddy)
  1 - include in the output and combine only volumes where both LR/RL (or AP/PA) pairs have been acquired
  0 - As 1, but also include uncombined single volumes
Defaults to 1" "1"

opts_AddOptional '--printcom' 'runcmd' 'echo' 'to echo or otherwise  output the commands that would be executed instead of  actually running them. --printcom=echo is intended to  be used for testing purposes'


opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

opts_ShowValues

#parse booleans
SelectBestB0=$(opts_StringToBool "$SelectBestB0String")

"$HCPPIPEDIR"/show_version

# Verify required environment variables are set and log value
log_Check_Env_Var HCPPIPEDIR
log_Check_Env_Var FSLDIR
log_Check_Env_Var HCPPIPEDIR_Global # Needed in eddy_postproc.sh and DiffusionToStructural.sh

# Set other necessary variables, contingent on HCPPIPEDIR
HCPPIPEDIR_dMRI=${HCPPIPEDIR}/DiffusionPreprocessing/scripts

#
# Function Description
#  Validate necessary scripts exist
#
validate_scripts() {
	local error_msgs=""

	if [ ! -e ${HCPPIPEDIR_dMRI}/eddy_postproc.sh ]; then
		error_msgs+="\nERROR: ${HCPPIPEDIR_dMRI}/eddy_postproc.sh not found"
	fi

	if [ ! -e ${HCPPIPEDIR_dMRI}/DiffusionToStructural.sh ]; then
		error_msgs+="\nERROR: ${HCPPIPEDIR_dMRI}/DiffusionToStructural.sh not found"
	fi

	if [ ! -z "${error_msgs}" ]; then
		show_usage
		echo -e ${error_msgs}
		echo ""
		exit 1
	fi
}

#
# Function Description
#  Main processing of script
#
#  Gets user specified command line options, runs Post-Eddy steps of Diffusion Preprocessing
#
# Validate scripts
validate_scripts "$@"

# Establish output directory paths
outdir=${StudyFolder}/${Subject}/${DWIName}
outdirT1w=${StudyFolder}/${Subject}/T1w/${DWIName}

# Determine whether Gradient Nonlinearity Distortion coefficients are supplied
GdFlag=0
if [ ! ${GdCoeffs} = "NONE" ]; then
	log_Msg "Gradient nonlinearity distortion correction coefficients found!"
	GdFlag=1
fi

log_Msg "Running Eddy PostProcessing"
# Note that gradient distortion correction is applied after 'eddy' in the dMRI Pipeline
select_flag="0"
if ((SelectBestB0)); then
	select_flag="1"
fi
${runcmd} ${HCPPIPEDIR_dMRI}/eddy_postproc.sh ${outdir} ${GdCoeffs} ${CombineDataFlag} ${select_flag}

# Establish variables that follow naming conventions
T1wFolder="${StudyFolder}/${Subject}/T1w" #Location of T1w images
T1wImage="${T1wFolder}/T1w_acpc_dc"
T1wRestoreImage="${T1wFolder}/T1w_acpc_dc_restore"
T1wRestoreImageBrain="${T1wFolder}/T1w_acpc_dc_restore_brain"
BiasField="${T1wFolder}/BiasField_acpc_dc"
FreeSurferBrainMask="${T1wFolder}/brainmask_fs"
RegOutput="${outdir}"/reg/"Scout2T1w"
QAImage="${outdir}"/reg/"T1wMulEPI"
DiffRes=$(${FSLDIR}/bin/fslval ${outdir}/data/data pixdim1)
DiffRes=$(printf "%0.2f" ${DiffRes})

log_Msg "Running Diffusion to Structural Registration"
${runcmd} ${HCPPIPEDIR_dMRI}/DiffusionToStructural.sh \
	--t1folder="${T1wFolder}" \
	--subject="${Subject}" \
	--workingdir="${outdir}/reg" \
	--datadiffdir="${outdir}/data" \
	--t1="${T1wImage}" \
	--t1restore="${T1wRestoreImage}" \
	--t1restorebrain="${T1wRestoreImageBrain}" \
	--biasfield="${BiasField}" \
	--brainmask="${FreeSurferBrainMask}" \
	--datadiffT1wdir="${outdirT1w}" \
	--regoutput="${RegOutput}" \
	--QAimage="${QAImage}" \
	--dof="${DegreesOfFreedom}" \
	--gdflag=${GdFlag} \
	--diffresol=${DiffRes}

to_location="${outdirT1w}/eddylogs"
from_directory="${outdir}/eddy"
log_Msg "Copying eddy log files to package location: ${to_location}"

# Log files are any 'eddy' output that doesn't have a .nii extension
from_files=$(ls ${from_directory}/eddy_unwarped_images.* | grep -v .nii)

${runcmd} mkdir -p ${to_location}
for filename in ${from_files}; do
	${runcmd} cp -p ${filename} ${to_location}
done

${runcmd} mkdir -p ${outdirT1w}/QC
${runcmd} cp -p ${outdir}/QC/* ${outdirT1w}/QC
${runcmd} immv ${outdirT1w}/cnr_maps ${outdirT1w}/QC/cnr_maps

log_Msg "Completed!"
exit 0
