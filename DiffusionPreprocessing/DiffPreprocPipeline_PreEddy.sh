#!/bin/bash
#~ND~FORMAT~MARKDOWN~
#~ND~START~
#
# # DiffPreprocPipeline_PreEddy.sh
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
# [Human Connectome Project][HCP] (HCP) Pipeline Tools
#
# ## License
#
# See the [LICENSE](https://github.com/Washington-University/Pipelines/blob/master/LICENSE.md) file
#
# ## Description
#
# This script, <code>DiffPreprocPipeline_PreEddy.sh</code>, implements the first part of the 
# Preprocessing Pipeline for diffusion MRI describe in [Glasser et al. 2013][GlasserEtAl].
# The entire Preprocessing Pipeline for diffusion MRI is split into pre-eddy, eddy,
# and post-eddy scripts so that the running of eddy processing can be submitted 
# to a cluster scheduler to take advantage of running on a set of GPUs without forcing
# the entire diffusion preprocessing to occur on a GPU enabled system.  This particular
# script implements the pre-eddy part of the diffusion preprocessing.
#
# ## Prerequisite Installed Software for the Diffusion Preprocessing Pipeline
#
# * [FSL][FSL] - FMRIB's Software Library (version 5.0.6)
#   
#   FSL's environment setup script must also be sourced
#
# * [FreeSurfer][FreeSurfer] (version 5.3.0-HCP)
#
# * [HCP-gradunwarp][HCP-gradunwarp] - (HCP version 1.0.2)
#
# ## Prerequisite Environment Variables
#
# See output of usage function: e.g. <code>$ ./DiffPreprocPipeline_PreEddy.sh --help</code>
# 
# <!-- References -->
#
# [HCP]: http://www.humanconnectome.org
# [GlasserEtAl]: http://www.ncbi.nlm.nih.gov/pubmed/23668970
# [FSL]: http://fsl.fmrib.ox.ac.uk
# [FreeSurfer]: http://freesurfer.net
# [gradunwarp]: https://github.com/ksubramz/gradunwarp.git
#
#~ND~END~

# Set up this script such that if any command exits with a non-zero value, the 
# script itself exits and does not attempt any further processing.
set -e

# Load Function Libraries
source ${HCPPIPEDIR}/global/scripts/log.shlib     # log_ functions
source ${HCPPIPEDIR}/global/scripts/version.shlib # version_ functions

# Global values
DEFAULT_B0_MAX_BVAL=50
SCRIPT_NAME=$(basename ${0})

# 
# Function Description
#  Show usage information for this script
#
usage()
{
	cat << EOF

Perform the Pre-Eddy steps of the HCP Diffusion Preprocessing Pipeline

Usage: ${SCRIPT_NAME} PARAMETER...

PARAMETERs are: [ ] = optional; < > = user supplied value
  [--help]                show usage information and exit with non-zero return
                          code
  [--version]             show version information and exit with 0 as return code
  --path=<study-path>     path to subject's data folder
  --subject=<subject-id>  subject ID
  --PEdir=<phase-encoding-dir>
                          phase encoding direction specifier: 1=RL/LR, 2=PA/AP
  --posData=<positive-phase-encoding-data>
                          @ symbol separated list of data with positive phase
                          encoding direction (e.g. dataRL1@dataRL2@...dataRLn)
  --negData=<negative-phase-encoding-data>
                          @ symbol separated list of data with negative phase 
                          encoding direction (e.g. dataLR1@dataLR2@...dataLRn)
  --echospacing=<echo-spacing>
                          Echo spacing in msecs
  [--dwiname=<DWIname>]   name to give DWI output directories.
                          Defaults to Diffusion
  [--b0maxbval=<b0-max-bval>]
                          Volumes with a bvalue smaller than this value will be 
                          considered as b0s. Defaults to ${DEFAULT_B0_MAX_BVAL}
  [--printcom=<print-command>]
                          Use the specified <print-command> to echo or otherwise
                          output the commands that would be executed instead of
                          actually running them. --printcom=echo is intended to
                          be used for testing purposes

Return Status Value:

  0                       if help was not requested, all parameters were properly 
                          formed, and processing succeeded
  Non-zero                Otherwise - malformed parameters, help requested, or a
                          processing failure was detected

Required Environment Variables:

  HCPPIPEDIR              The home directory for the version of the HCP Pipeline 
                          Scripts being used.
  HCPPIPEDIR_dMRI         Location of the Diffusion MRI Preprocessing sub-scripts
                          that are used to carry out some of the steps of the 
                          Diffusion Preprocessing Pipeline
                          (e.g. \${HCPPIPEDIR}/DiffusionPreprocessing/scripts)
  FSLDIR                  The home directory for FSL

EOF
}

#
# Function Description
#  Get the command line options for this script
#
# Global Output Variables
#  ${StudyFolder}         Path to subject's data folder
#  ${Subject}             Subject ID
#  ${PEdir}	              Phase Encoding Direction, 1=RL/LR, 2=PA/AP
#  ${PosInputImages}      @ symbol separated list of data with positive phase 
#                         encoding direction
#  ${NegInputImages}      @ symbol separated lsit of data with negative phase
#                         encoding direction 
#  ${echospacing}         Echo spacing in msecs
#  ${DWIName}             Name to give DWI output directories
#  ${b0maxbval}           Volumes with a bvalue smaller than this value will 
#                         be considered as b0s
#  ${runcmd}              Set to a user specified command to use if user has 
#                         requested that commands be echo'd (or printed) 
#                         instead of actually executed. Otherwise, set to 
#                         empty string.
#
get_options()
{
	local arguments=($@)
	
	# initialize global output variables
	unset StudyFolder
	unset Subject
	unset PEdir
	unset PosInputImages
	unset NegInputImages
	unset echospacing
	DWIName="Diffusion"
	b0maxbval=${DEFAULT_B0_MAX_BVAL}
	runcmd=""
	
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
			--PEdir=*)
				PEdir=${argument#*=}
				index=$(( index + 1 ))
				;;
			--posData=*)
				PosInputImages=${argument#*=}
				index=$(( index + 1 ))
				;;
			--negData=*)
				NegInputImages=${argument#*=}
				index=$(( index + 1 ))
				;;
			--dwiname=*)
				DWIName=${argument#*=}
				index=$(( index + 1 ))
				;;
			--echospacing=*)
				echospacing=${argument#*=}
				index=$(( index + 1 ))
				;;
			--b0maxbval=*)
				b0maxbval=${argument#*=}
				index=$(( index + 1 ))
				;;
			--printcom=*)
				runcmd=${argument#*=}
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
	
	if [ -z ${PEdir} ] ; then
		error_msgs+="\nERROR: <phase-encoding-dir> not specified"
	fi
	
	if [ -z ${PosInputImages} ] ; then
		error_msgs+="\nERROR: <positive-phase-encoded-data> not specified"
	fi
	
	if [ -z ${NegInputImages} ] ; then
		error_msgs+="\nERROR: <negative-phase-encoded-data> not specified"
	fi
	
	if [ -z ${echospacing} ] ; then
		error_msgs+="\nERROR: <echo-spacing> not specified"
	fi
	
	if [ -z ${b0maxbval} ] ; then
		error_msgs+="\nERROR: <b0-max-bval> not specified"
	fi
	
	if [ -z ${DWIName} ] ; then
		error_msgs+="\nERROR: <DWIName> not specified"
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
	echo "   PEdir: ${PEdir}"
	echo "   PosInputImages: ${PosInputImages}"
	echo "   NegInputImages: ${NegInputImages}"
	echo "   echospacing: ${echospacing}"
	echo "   DWIName: ${DWIName}"
	echo "   b0maxbval: ${b0maxbval}"
	echo "   runcmd: ${runcmd}"
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
	
	if [ ! -e ${HCPPIPEDIR_dMRI}/basic_preproc.sh ] ; then
		error_msgs+="\nERROR: HCPPIPEDIR_dMRI/basic_preproc.sh not found"
	fi
	
	if [ ! -e ${HCPPIPEDIR_dMRI}/run_topup.sh ] ; then
		error_msgs+="\nERROR: HCPPIPEDIR_dMRI/run_topup.sh not found"
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
#  find the minimum of two specified numbers
#
min()
{
	if [ $1 -le $2 ]
	then
		echo $1
	else
		echo $2
	fi
}

#
# Function Description
#  Main processing of script
#
#  Gets user specified command line options, runs Pre-Eddy steps of Diffusion Preprocessing
#
main()
{
	# Hard-Coded variables for the pipeline
	MissingFileFlag="EMPTY"  # String used in the input arguments to indicate that a complete series is missing
	b0dist=45                # Minimum distance in volums between b0s considered for preprocessing
	
	# Get Command Line Options
	get_options $@
	
	# Validate environment variables
	validate_environment_vars $@
	
	# Establish tool name for logging
	log_SetToolName "${SCRIPT_NAME}"
	
	# Establish output directory paths
	outdir=${StudyFolder}/${Subject}/${DWIName}
	outdirT1w=${StudyFolder}/${Subject}/T1w/${DWIName}
	
	# Delete any existing output sub-directories
	if [ -d ${outdir} ] ; then
		${runcmd} rm -rf ${outdir}/rawdata
		${runcmd} rm -rf ${outdir}/topup
		${runcmd} rm -rf ${outdir}/eddy
		${runcmd} rm -rf ${outdir}/data
		${runcmd} rm -rf ${outdir}/reg
	fi
	
	# Make sure output directories exist
	${runcmd} mkdir -p ${outdir}
	${runcmd} mkdir -p ${outdirT1w}
	
	log_Msg "outdir: ${outdir}"
	${runcmd} mkdir ${outdir}/rawdata
	${runcmd} mkdir ${outdir}/topup
	${runcmd} mkdir ${outdir}/eddy
	${runcmd} mkdir ${outdir}/data
	${runcmd} mkdir ${outdir}/reg
	
	if [ ${PEdir} -eq 1 ] ; then    # RL/LR phase encoding
		basePos="RL"
		baseNeg="LR"
	elif [ ${PEdir} -eq 2 ] ; then  # PA/AP phase encoding
		basePos="PA"
		baseNeg="AP"
	else
		log_Msg "ERROR: Invalid Phase Encoding Directory (PEdir} specified: ${PEdir}"
		exit 1
	fi
	
	log_Msg "basePos: ${basePos}"
	log_Msg "baseNeg: ${baseNeg}"
	
	# copy positive raw data
	log_Msg "Copying positive raw data to working directory"
	PosInputImages=`echo ${PosInputImages} | sed 's/@/ /g'`
	log_Msg "PosInputImages: ${PosInputImages}"
	
	Pos_count=1
	for Image in ${PosInputImages} ; do
		if [[ ${Image} =~ ^.*EMPTY.*$  ]] ; then
			Image=EMPTY
		fi
		
		if [ ${Image} = ${MissingFileFlag} ] ; then
			PosVols[${Pos_count}]=0
		else
			PosVols[${Pos_count}]=`${FSLDIR}/bin/fslval ${Image} dim4`
			absname=`${FSLDIR}/bin/imglob ${Image}`
			${runcmd} ${FSLDIR}/bin/imcp ${absname} ${outdir}/rawdata/${basePos}_${Pos_count}
			${runcmd} cp ${absname}.bval ${outdir}/rawdata/${basePos}_${Pos_count}.bval
			${runcmd} cp ${absname}.bvec ${outdir}/rawdata/${basePos}_${Pos_count}.bvec
		fi
		Pos_count=$((${Pos_count} + 1))
	done
	
	# copy negative raw data
	log_Msg "Copying negative raw data to working directory"
	NegInputImages=`echo ${NegInputImages} | sed 's/@/ /g'`
	log_Msg "NegInputImages: ${NegInputImages}"
	
	Neg_count=1
	for Image in ${NegInputImages} ; do
		if [[ ${Image} =~ ^.*EMPTY.*$  ]] ; then
			Image=EMPTY
		fi
		
		if [ ${Image} = ${MissingFileFlag} ] ; then
			NegVols[${Neg_count}]=0
		else
			NegVols[${Neg_count}]=`${FSLDIR}/bin/fslval ${Image} dim4`
			absname=`${FSLDIR}/bin/imglob ${Image}`
			${runcmd} ${FSLDIR}/bin/imcp ${absname} ${outdir}/rawdata/${baseNeg}_${Neg_count}
			${runcmd} cp ${absname}.bval ${outdir}/rawdata/${baseNeg}_${Neg_count}.bval
			${runcmd} cp ${absname}.bvec ${outdir}/rawdata/${baseNeg}_${Neg_count}.bvec
		fi
		Neg_count=$((${Neg_count} + 1))
	done
	
	# verify positive and negative datasets are provided in pairs
	if [ ${Pos_count} -ne ${Neg_count} ] ; then
		log_Msg "Wrong number of input datasets! Make sure that you provide pairs of input filenames."
		log_Msg "If the respective file does not exist, use EMPTY in the input arguments."
		exit 1
	fi

	# Create two files for each phase encoding direction, that for each series contain the number of 
	# corresponding volumes and the number of actual volumes. The file e.g. RL_SeriesCorrespVolNum.txt
	# will contain as many rows as non-EMPTY series. The entry M in row J indicates that volumes 0-M 
	# from RLseries J has corresponding LR pairs. This file is used in basic_preproc to generate 
	# topup/eddy indices and extract corresponding b0s for topup. The file e.g. Pos_SeriesVolNum.txt 
	# will have as many rows as maximum series pairs (even unmatched pairs). The entry M N in row J 
	# indicates that the RLSeries J has its 0-M volumes corresponding to LRSeries J and RLJ has N 
	# volumes in total. This file is used in eddy_combine.
	log_Msg "Create two files for each phase encoding direction"
	
	Paired_flag=0
	for (( j=1; j<${Pos_count}; j++ )) ; do
		CorrVols=`min ${NegVols[${j}]} ${PosVols[${j}]}`
		${runcmd} echo ${CorrVols} ${PosVols[${j}]} >> ${outdir}/eddy/Pos_SeriesVolNum.txt
		if [ ${PosVols[${j}]} -ne 0 ]
		then
			${runcmd} echo ${CorrVols} >> ${outdir}/rawdata/${basePos}_SeriesCorrespVolNum.txt
			if [ ${CorrVols} -ne 0 ]
			then
				Paired_flag=1
			fi
		fi
	done
	
	for (( j=1; j<${Neg_count}; j++ )) ; do
		CorrVols=`min ${NegVols[${j}]} ${PosVols[${j}]}`
		${runcmd} echo ${CorrVols} ${NegVols[${j}]} >> ${outdir}/eddy/Neg_SeriesVolNum.txt
		if [ ${NegVols[${j}]} -ne 0 ]
		then
			${runcmd} echo ${CorrVols} >> ${outdir}/rawdata/${baseNeg}_SeriesCorrespVolNum.txt
		fi
	done
	
	if [ ${Paired_flag} -eq 0 ] ; then
		log_Msg "Wrong Input! No pairs of phase encoding directions have been found!"
		log_Msg "At least one pair is needed!"
		exit 1
	fi
	
	log_Msg "Running Basic Preprocessing"
	${runcmd} ${HCPPIPEDIR_dMRI}/basic_preproc.sh ${outdir} ${echospacing} ${PEdir} ${b0dist} ${b0maxbval}
	
	log_Msg "Running Topup"
	${runcmd} ${HCPPIPEDIR_dMRI}/run_topup.sh ${outdir}/topup
	
	log_Msg "Completed"
	exit 0
}

#
# Invoke the main function to get things started
#
main $@
