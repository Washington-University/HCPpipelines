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

# Setup this script such that if any command exits with a non-zero value, the 
# script itself exits and does not attempt any further processing.
set -e

# Load Function Libraries
source ${HCPPIPEDIR}/global/scripts/log.shlib     # log_ functions
source ${HCPPIPEDIR}/global/scripts/version.shlib # version_ functions 

# Global values
DEFAULT_DEGREES_OF_FREEDOM=6
SCRIPT_NAME=$(basename ${0})

#
# Function Description
#  Show usage information for this script
#
usage()
{
	cat << EOF

Perform the Post-Eddy steps of the HCP Diffusion Preprocessing Pipeline

Usage: ${SCRIPT_NAME} PARAMETER...

PARAMETERs are: [ ] = optional; < > = user supplied value
  [--help]                show usage information and exit with non-zero return 
                          code
  [--version]             show version information and exit with 0 as return code
  --path=<study-path>     path to subject's data folder
  --subject=<subject-id>  subject ID
  --gdcoeffs=<path-to-gradients-coefficients-file>
                          path to file containing coefficients that describe 
                          spatial variations of the scanner gradients. Use 
                          --gdcoeffs=NONE if not available.
  [--dwiname=<DWIName>]   name to give DWI output directories
	                      Defaults to Diffusion
  [--dof=<Degrees of Freedom>]
                          Degrees of Freedom for registration to structural 
                          images. Defaults to ${DEFAULT_DEGREES_OF_FREEDOM}
  [--printcom=<print-command>]
                          Use the specified <print-command> to echo or otherwise
                          output the commands that would be executed instead of
                          actually running them. --printcom=echo is intended to 
                          be used for testing purposes
  [--combine-data-flag=<value>]
                          Specified value is passed as the CombineDataFlag value
                          for the eddy_postproc.sh script.
                          If JAC resampling has been used in eddy, this value 
                          determines what to do with the output file.
                          2 - include in the output all volumes uncombined (i.e.
                              output file of eddy)
                          1 - include in the output and combine only volumes 
                              where both LR/RL (or AP/PA) pairs have been 
                              acquired
                          0 - As 1, but also include uncombined single volumes
                          Defaults to 1
                       
Return Status Value:
	 
  0                       if help was not requested, all parameters were properly 
                          formed, and processing succeeded
  Non-zero                otherwise - malformed parameters, help requested, or a 
                          processing failure was detected


Required Environment Variables:

  HCPPIPEDIR              The home directory for the version of the HCP Pipeline
                          Scripts being used.
  HCPPIPEDIR_dMRI         Location of the Diffusion MRI Preprocessing sub-scripts
                          that are used to carry out some of the steps of the
                          Diffusion Preprocessing Pipeline. 
                          (e.g. \${HCPPIPEDIR}/DiffusionPreprocessing/scripts)
  FSLDIR                  The home directory for FSL
  PATH                    Standard PATH environment variable must be set to find
                          HCP-customized version of gradient_unwarp.py

EOF
}

#
# Function Description
#  Get the command line options for this script
#
# Global Output Variables
#  ${StudyFolder}         Path to subject's data folder
#  ${Subject}             Subject ID
#  ${GdCoeffs}			  Path to file containing coefficients that describe 
#                         spatial variations of the scanner gradients. NONE 
#                         if not available.
#  ${DegreesOfFreedom}    Degrees of Freedom for registration to structural 
#                         images
#  ${DWIName}             Name to give DWI output directories
#  ${runcmd}              Set to a user specifed command to use if user has 
#                         requested that commands be echo'd (or printed)
#                         instead of actually executed. Otherwise, set to
#						  empty string.
#  ${CombineDataFlag}     CombineDataFlag value to pass to the eddy_postproc.sh
#                         script. 
#
get_options()
{
	local arguments=($@)
	
	# initialize global output variables
	unset StudyFolder
	unset Subject
	unset GdCoeffs
	DWIName="Diffusion"
	DegreesOfFreedom=${DEFAULT_DEGREES_OF_FREEDOM}
	runcmd=""
	CombineDataFlag=1
	
	# parse arguments
	local index=0
	local numArgs=${#arguments[@]}
	local argument
	
	while [ ${index} -lt ${numArgs} ] ; do
		argument=${arguments[index]}
		
		case ${argument} in
			--help)
				usage
				exit 1
				;;
			--version)
				version_show $@
				exit 0
				;;
			--path=*)
				StudyFolder=${argument#*=}
				index=$(( index + 1 ))
				;;
			--subject=*)
				Subject=${argument#*=}
				index=$(( index + 1 ))
				;;
			--gdcoeffs=*)
				GdCoeffs=${argument#*=}
				index=$(( index + 1 ))
				;;
			--dof=*)
				DegreesOfFreedom=${argument#*=}
				index=$(( index + 1 ))
				;;
			--printcom=*)
				runcmd=${argument#*=}
				index=$(( index + 1 ))
				;;
			--dwiname=*)
				DWIName=${argument#*=}
				index=$(( index + 1 ))
				;;
			--combine-data-flag=*)
				CombineDataFlag=${argument#*=}
				index=$(( index + 1 ))
				;;
			*)
				usage
				echo "ERROR: Unrecognized Option: ${argument}"
				exit 1
				;;
		esac
	done
	
	local error_msgs=""

	# check required parameters
	if [ -z ${StudyFolder} ] ; then
		error_msgs+="\nERROR: <study-path> not specified"
	fi
	
	if [ -z ${Subject} ] ; then
		error_msgs+="\nERROR: <subject-id> not specified"
	fi
	
	if [ -z ${GdCoeffs} ] ; then
		error_msgs+="\nERROR: <path-to-gradients-coefficients-file> not specified"
	fi
	
	if [ -z ${DWIName} ] ; then
		error_msgs+="\nERROR: <DWIName> not specified"
	fi

	if [ -z ${DegreesOfFreedom} ] ; then
		error_msgs+="\nERROR: DegreesOfFreedom not specified"
	fi

	if [ -z ${CombineDataFlag} ] ; then
		error_msgs+="\nERROR: CombineDataFlag not specified"
	fi

	if [ ! -z "${error_msgs}" ] ; then
		usage
		echo -e ${error_msgs}
		echo ""
		exit 1
	fi
	
	# report parameters
	echo "-- ${SCRIPT_NAME}: Specified Command-Line Parameters - Start --"
	echo "   StudyFolder: ${StudyFolder}"
	echo "   Subject: ${Subject}"
	echo "   DWIName: ${DWIName}"
	echo "   GdCoeffs: ${GdCoeffs}"
	echo "   DegreesOfFreedom: ${DegreesOfFreedom}"
	echo "   runcmd: ${runcmd}"
	echo "   CombineDataFlag: ${CombineDataFlag}"
	echo "-- ${SCRIPT_NAME}: Specified Command-Line Parameters - End --"
}

# 
# Function Description
#  Validate necessary environment variables
#
validate_environment_vars()
{
	local error_msgs=""
	
	# validate
	if [ -z ${HCPPIPEDIR_dMRI} ] ; then
		error_msgs+="\nERROR: HCPPIPEDIR_dMRI environment variable not set"
	fi
	
	if [ ! -e ${HCPPIPEDIR_dMRI}/eddy_postproc.sh ] ; then
		error_msgs+="\nERROR: HCPPIPEDIR_dMRI/eddy_postproc.sh not found"
	fi
	
	if [ ! -e ${HCPPIPEDIR_dMRI}/DiffusionToStructural.sh ] ; then
		error_msgs+="\nERROR: HCPPIPEDIR_dMRI/DiffusionToStructural.sh not found"
	fi
	
	if [ -z ${FSLDIR} ] ; then
		error_msgs+="\nERROR: FSLDIR environment variable not set"
	fi

	if [ ! -z "${error_msgs}" ] ; then
		usage
		echo -e ${error_msgs}
		echo ""
		exit 1
	fi
	
	# report
	echo "-- ${SCRIPT_NAME}: Environment Variables Used - Start --"
	echo "   HCPPIPEDIR_dMRI: ${HCPPIPEDIR_dMRI}"
	echo "   FSLDIR: ${FSLDIR}"
	echo "-- ${SCRIPT_NAME}: Environment Variables Used - End --"
}

#
# Function Description
#  Main processing of script
#
#  Gets user specified command line options, runs Post-Eddy steps of Diffusion Preprocessing
#
main()
{
	# Get Command Line Options
	get_options $@
	
	# Validate environment variables
	validate_environment_vars $@
	
	# Establish tool name for logging
	log_SetToolName "${SCRIPT_NAME}"
	
	# Establish output directory paths
	outdir=${StudyFolder}/${Subject}/${DWIName}
	outdirT1w=${StudyFolder}/${Subject}/T1w/${DWIName}
	
	# Determine whether Gradient Nonlinearity Distortion coefficients are supplied
	GdFlag=0
	if [ ! ${GdCoeffs} = "NONE" ] ; then
		log_Msg "Gradient nonlinearity distortion correction coefficients found!"
		GdFlag=1
	fi
	
	log_Msg "Running Eddy PostProcessing"
	${runcmd} ${HCPPIPEDIR_dMRI}/eddy_postproc.sh ${outdir} ${GdCoeffs} ${CombineDataFlag}
	
	# Establish variables that follow naming conventions
	T1wFolder="${StudyFolder}/${Subject}/T1w" #Location of T1w images
	T1wImage="${T1wFolder}/T1w_acpc_dc"
	T1wRestoreImage="${T1wFolder}/T1w_acpc_dc_restore"
	T1wRestoreImageBrain="${T1wFolder}/T1w_acpc_dc_restore_brain"
	BiasField="${T1wFolder}/BiasField_acpc_dc"
	FreeSurferBrainMask="${T1wFolder}/brainmask_fs"
	RegOutput="${outdir}"/reg/"Scout2T1w"
	QAImage="${outdir}"/reg/"T1wMulEPI"
	DiffRes=`${FSLDIR}/bin/fslval ${outdir}/data/data pixdim1`
	DiffRes=`printf "%0.2f" ${DiffRes}`
	
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

	from_files=""
	from_files+=" ${from_directory}/eddy_unwarped_images.eddy_outlier_map "
	from_files+=" ${from_directory}/eddy_unwarped_images.eddy_outlier_n_sqr_stdev_map "
	from_files+=" ${from_directory}/eddy_unwarped_images.eddy_outlier_n_stdev_map"
	from_files+=" ${from_directory}/eddy_unwarped_images.eddy_outlier_report "
	from_files+=" ${from_directory}/eddy_unwarped_images.eddy_movement_rms "
	from_files+=" ${from_directory}/eddy_unwarped_images.eddy_restricted_movement_rms "
	from_files+=" ${from_directory}/eddy_unwarped_images.eddy_parameters "
	from_files+=" ${from_directory}/eddy_unwarped_images.eddy_post_eddy_shell_alignment_parameters "

	mkdir --parents ${to_location}
	for filename in ${from_files} ; do
		cp --verbose ${filename} ${to_location}
	done
	
	log_Msg "Completed"
	exit 0
}

#
# Invoke the main function to get things started
#
main $@
