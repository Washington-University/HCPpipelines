#!/bin/bash

#
# # DeDriftAndResamplePipeline.sh
#
# ## Copyright Notice
#
# Copyright (C) 2015-2017 The Human Connectome Project
#
# * Washington University in St. Louis
# * University of Minnesota
# * Oxford University
#
# ## Author(s)
#
# * Matthew F. Glasser, Department of Anatomy and Neurobiology, Washington University in St. Louis
# * Timothy B. Brown, Neuroinformatics Research Group, Washington University in St. Louis
#
# ## Product
#
# [Human Connectome Project][HCP] (HCP) Pipelines
#
# ## License
#
# See the [LICENSE](https://github.com/Washington-Univesity/Pipelines/blob/master/LICENSE.md) file
#
# <!-- References -->
# [HCP]: http://www.humanconnectome.org
#

# ------------------------------------------------------------------------------
#  Show usage information for this script
# ------------------------------------------------------------------------------

show_usage()
{
	cat <<EOF

${g_script_name}: De-Drift and Resample"

Usage: ${g_script_name} PARAMETER...

PARAMETERs are [ ] = optional; < > = user supplied value

  Note: The PARAMETERS can be specified positionally (i.e. without using the --param=value
        form) by simply specifying all values on the command line in the order they are
        listed below.

        E.g. ${g_script_name} /path/to/study/folder 100307 164 32@59 ... NONE NONE 1

        However, to use this technique, all optional parameters (e.g. myelin target file
        and input registration name) except the final one (the MATLAB run mode) must be 
        specified as NONE.

  [--help] : show this usage information and exit
   --path=<path to study folder> OR --study-folder=<path to study folder>
   --subject=<subject ID>
   --high-res-mesh=<meshnum> String corresponding to high resolution mesh, e.g. 164
   --low-res-meshes=<meshnum@meshnum> String corresponding to low resolution meshes delimited by @, 
       (e.g. 32@59)
   --registration-name=<regname> String corresponding to the input registration sphere name
       (e.g. \${Subject}.\${Hemisphere}.sphere.\${RegName}.native.surf.gii), usually MSMAll_InitialReg...
  [--dedrift-reg-files=</Path/to/File/Left.sphere.surf.gii@/Path/to/File/Right.sphere.surf.gii>]
       Usually the spheres in global/templates/MSMAll/
  [--concat-reg-name=<regname>] String corresponding to the output name for the dedrifted registration
       (referred to as the concatenated registration), usually MSMAll. Requires --dedrift-reg-files
   --maps=<non@myelin@maps> @-delimited map name strings corresponding to maps that are not myelin maps 
       (e.g. sulc@curvature@corrThickness@thickness)
  [--myelin-maps=<myelin@maps>] @-delimited map name strings corresponding to myelin maps
       (e.g. MyelinMap@SmoothedMyelinMap). No _BC, this will be reapplied.
  [--multirun-fix-names=<day1run1@day1run2%day2run1@day2run2>] @ and % delimited list of lists of
       fMRIName strings that will have multi-run ICA+FIX reapplied to them (could be either rfMRI or
       tfMRI). Requires specifying --multirun-fix-concat-names also, with same number of concat names as
       lists of runs in this option.
  [--multirun-fix-concat-names=<day1_concat@day2_concat>] @-delimited list of names of the concatenated
       timeseries, only required when using --multirun-fix-names.
  [--multirun-fix-extract-names=<day1run1@day1run2%day2run1@day2run2>] @ and % delimited list of lists of
       fMRIName strings to extract, one list for each multi-run ICA+FIX group in --multirun-fix-names (use
       a NONE instead of the group's runs and a NONE in --multirun-fix-extract-concat-names to skip this
       for a group), only required when using --multirun-fix-extract-concat-names.  Exists to enable
       extraction of a subset of the runs in a multi-run ICA+FIX group into a new concatenated series
       (which is then named using --multirun-fix-extract-concat-names).
  [--multirun-fix-extract-concat-names=<day1_newconcat@day2_newconcat>] @-delimited list of names for the
       concatenated extracted timeseries, one for each multi-run ICA+FIX group (i.e. name in
       --multirun-fix-concat-names; use NONE to skip a group).
  [--multirun-fix-extract-extra-regnames=<regname@regname>] extract MR FIX runs for additional surface
       registrations, e.g. --multirun-fix-extract-extra-regnames=MSMSulc
  [--multirun-fix-extract-volume={TRUE, FALSE}] whether to also extract the specified MR FIX runs from the
       volume data, requires --multirun-fix-extract-concat-names to work, default FALSE.
  [--fix-names=<ICA+FIXed@fMRI@Names>] @-delimited fMRIName strings corresponding to maps that will
       have single-run ICA+FIX reapplied to them (could be either rfMRI or tfMRI). Do not specify runs
       processed with MR FIX here. Previously known as --rfmri-names.
  [--dont-fix-names=<not@ICA+FIXed@fMRI@Names>] @-delimited fMRIName strings corresponding to maps that
       will not have ICA+FIX reapplied to them (not recommended, MR FIX or at least single-run ICA+FIX is
       recommended for all fMRI data). Previously known as --tfmri-names.
   --smoothing-fwhm=<number> Smoothing FWHM that matches what was used in the fMRISurface pipeline
   --high-pass=<high-pass filter used in ICA+FIX>
   --motion-regression={TRUE, FALSE} whether FIX should do motion regression
  [--myelin-target-file=<path/to/myelin/target/file>] A myelin target file is required to run this 
       pipeline when using a different mesh resolution than the original MSMAll registration.
  [--input-reg-name=<string>] A string to enable multiple fMRI resolutions (e.g._1.6mm)
  [--matlab-run-mode={0, 1, 2}] defaults to ${G_DEFAULT_MATLAB_RUN_MODE}
       0 = Use compiled MATLAB
       1 = Use interpreted MATLAB
       2 = Use interpreted Octave

EOF
}

# ------------------------------------------------------------------------------
#  Get the command line options for this script.
# ------------------------------------------------------------------------------

get_options() 
{
	local arguments=("$@")

	# initialize global output variables
	unset p_StudyFolder
	unset p_Subject
	unset p_HighResMesh
	unset p_LowResMeshes			# LowReshMeshes - @ delimited list, e.g. 32@59, multiple resolutions not currently supported for fMRI data
	unset p_RegName
	p_DeDriftRegFiles=NONE			# DeDriftRegFiles - @ delimited, L and R outputs from MSMRemoveGroupDrift.sh
	p_ConcatRegName=""
	unset p_Maps					# @ delimited
	p_MyelinMaps=NONE				# @ delimited
	p_mrFIXConcatNames=NONE			# @ delimited
	p_mrFIXNames=NONE				# @ and % delimited, % is top-level and must match number of @s in ConcatNames
	p_mrFIXExtractConcatNames=NONE  # @ delimited
	p_mrFIXExtractNames=NONE        # @ and % delimited, % is top-level and must match number of @s in ExtractConcatNames
	p_mrFIXExtractExtraRegNames=NONE # @ delimited
	p_mrFIXExtractDoVol=FALSE
	p_fixNames=NONE                 # @ delimited
	p_dontFixNames=NONE             # @ delimited
	unset p_SmoothingFWHM
	unset p_HighPass
	unset p_MotionRegression

	# set default values
	p_MyelinTargetFile="NONE"
	p_InRegName="NONE"				# e.g. "_1.6mm"
	p_MatlabRunMode=${G_DEFAULT_MATLAB_RUN_MODE}

	# parse arguments
	local num_args=${#arguments[@]}
	local argument
	local index=0

	while [ ${index} -lt ${num_args} ]; do
		argument=${arguments[index]}

		case ${argument} in
			--help)
				show_usage
				exit 0
				;;
			--path=*)
				p_StudyFolder=${argument#*=}
				index=$(( index + 1 ))
				;;
			--study-folder=*)
				p_StudyFolder=${argument#*=}
				index=$(( index + 1 ))
				;;
			--subject=*)
				p_Subject=${argument#*=}
				index=$(( index + 1 ))
				;;
			--high-res-mesh=*)
				p_HighResMesh=${argument#*=}
				index=$(( index + 1 ))
				;;
			--low-res-meshes=*)
				p_LowResMeshes=${argument#*=}
				index=$(( index + 1 ))
				;;
			--registration-name=*)
				p_RegName=${argument#*=}
				index=$(( index + 1 ))
				;;
			--dedrift-reg-files=*)
				p_DeDriftRegFiles=${argument#*=}
				index=$(( index + 1 ))
				;;
			--concat-reg-name=*)
				p_ConcatRegName=${argument#*=}
				index=$(( index + 1 ))
				;;
			--maps=*)
				p_Maps=${argument#*=}
				index=$(( index + 1 ))
				;;
			--myelin-maps=*)
				p_MyelinMaps=${argument#*=}
				index=$(( index + 1 ))
				;;
			--multirun-fix-concat-names=*)
				p_mrFIXConcatNames=${argument#*=}
				index=$(( index + 1 ))
				;;
			--multirun-fix-names=*)
				p_mrFIXNames=${argument#*=}
				index=$(( index + 1 ))
				;;
			--multirun-fix-extract-concat-names=*)
				p_mrFIXExtractConcatNames=${argument#*=}
				index=$(( index + 1 ))
				;;
			--multirun-fix-extract-names=*)
				p_mrFIXExtractNames=${argument#*=}
				index=$(( index + 1 ))
				;;
			--multirun-fix-extract-extra-regnames=*)
				p_mrFIXExtractExtraRegNames=${argument#*=}
				index=$(( index + 1 ))
				;;
			--multirun-fix-extract-volume=*)
				p_mrFIXExtractDoVol=${argument#*=}
				index=$(( index + 1 ))
				;;
			--fix-names=* | --rfmri-names=*)
				p_fixNames=${argument#*=}
				index=$(( index + 1 ))
				;;
			--dont-fix-names=* | --tfmri-names=*)
				p_dontFixNames=${argument#*=}
				index=$(( index + 1 ))
				;;
			--smoothing-fwhm=*)
				p_SmoothingFWHM=${argument#*=}
				index=$(( index + 1 ))
				;;
			--high-pass=* | --highpass=*)
				p_HighPass=${argument#*=}
				index=$(( index + 1 ))
				;;
			--myelin-target-file=*)
				p_MyelinTargetFile=${argument#*=}
				index=$(( index + 1 ))
				;;
			--input-reg-name=*)
				p_InRegName=${argument#*=}
				index=$(( index + 1 ))
				;;
			--matlab-run-mode=*)
				p_MatlabRunMode=${argument#*=}
				index=$(( index + 1 ))
				;;
			--motion-regression=*)
				p_MotionRegression=${argument#*=}
				index=$(( index + 1 ))
				;;
			*)
				show_usage
				log_Err_Abort "unrecognized option: ${argument}"
				;;
		esac
	done

	local error_count=0

	# check required parameters
	if [ -z "${p_StudyFolder}" ]; then
		log_Err "Study Folder (--path= or --study-folder=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "Study Folder: ${p_StudyFolder}"
	fi

	if [ -z "${p_Subject}" ]; then
		log_Err "Subject ID (--subject=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "Subject: ${p_Subject}"
	fi

	if [ -z "${p_HighResMesh}" ]; then
		log_Err "high resolution mesh (--high-res-mesh=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "High Resolution Mesh: ${p_HighResMesh}"
	fi
	
	if [ -z "${p_LowResMeshes}" ]; then
		log_Err "low resolution mesh list (--low-res-meshes=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "Low Resolution Meshes: ${p_LowResMeshes}"
	fi

	if [ -z "${p_RegName}" ]; then
		log_Err "Registration Name (--registration-name=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "Registration Name: ${p_RegName}"
	fi
	
	#code expects empty string, handle some magic NONEs here
	if [[ "$p_DeDriftRegFiles" == NONE ]]
	then
		p_DeDriftRegFiles=""
	fi
	
	log_Msg "De-Drifting registration files: ${p_DeDriftRegFiles}"

	if [ -z "${p_ConcatRegName}" ]; then
		p_ConcatRegName="${p_RegName}"
	else
		if [[ -z "$p_DeDriftRegFiles" ]]; then
			log_Err "--concat-reg-name must not be used unless dedrifting (just remove --concat-reg-name=<whatever> from your command)"
			error_count=$(( error_count + 1 ))
		fi
	fi
	log_Msg "registration name for outputs: ${p_ConcatRegName}"
	
	if [ -z "${p_Maps}" ]; then
		log_Err "list of structural maps to be resampled (--maps=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "list of structural maps to be resampled: ${p_Maps}"
	fi

	if [ -z "${p_MyelinMaps}" ]; then
		log_Err "list of Myelin maps to be resampled (--myelin-maps) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "list of Myelin maps to be resampled: ${p_MyelinMaps}"
	fi

	log_Msg "list of MR FIX scans: ${p_mrFIXNames}"
	log_Msg "MR FIX concat names: ${p_mrFIXConcatNames}"
	log_Msg "list of fix scans: ${p_fixNames}"
	log_Msg "list of non-fix scans: ${p_dontFixNames}"

	if [ -z "${p_SmoothingFWHM}" ]; then
		log_Err "smoothing value (--smoothing-fwhm=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "smoothing value: ${p_SmoothingFWHM}"
	fi

	if [ -z "${p_HighPass}" ]; then
		log_Err "HighPass value (--high-pass=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "HighPass value: ${p_HighPass}"
	fi

	if [ -z "${p_MyelinTargetFile}" ]; then
		log_Err "Myelin Target File (--myelin-target-file=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "Myelin Target File: ${p_MyelinTargetFile}"
	fi
	
	if [ -z "${p_InRegName}" ]; then
		log_Err "Input Registration Name (--input-reg-name=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "Input Registration Name: ${p_InRegName}"
	fi
	
	if [ -z "${p_MatlabRunMode}" ]; then
		log_Err "MATLAB run mode value (--matlab-run-mode=) required"
		error_count=$(( error_count + 1 ))
	else
		case ${p_MatlabRunMode} in 
			0)
				log_Msg "MATLAB Run Mode: ${p_MatlabRunMode} - Use compiled MATLAB"
				if [ -z "${MATLAB_COMPILER_RUNTIME}" ]; then
					log_Err_Abort "To use MATLAB run mode: ${p_MatlabRunMode}, the MATLAB_COMPILER_RUNTIME environment variable must be set"
				else
					log_Msg "MATLAB_COMPILER_RUNTIME: ${MATLAB_COMPILER_RUNTIME}"
				fi
				;;
			1)
				log_Msg "MATLAB Run Mode: ${p_MatlabRunMode} - Use interpreted MATLAB"
				;;
			2)
				log_Msg "MATLAB Run Mode: ${p_MatlabRunMode} - Use interpreted octave"
				;;
			*)
				log_Err "MATLAB Run Mode value must be 0, 1, or 2"
				error_count=$(( error_count + 1 ))
				;;
		esac
	fi

	if [ -z "${p_MotionRegression}" ]; then
		log_Err "motion correction setting (--motion-regression=) required"
		error_count=$(( error_count + 1 ))
	else
		case $(echo ${p_MotionRegression} | tr '[:upper:]' '[:lower:]') in
            ( true | yes | 1)
                p_MotionRegression=1
                ;;
            ( false | no | none | 0)
                p_MotionRegression=0
                ;;
			*)
				log_Err "motion correction setting must be TRUE or FALSE"
				error_count=$(( error_count + 1 ))
				;;
		esac
	fi
	
    if [[ -n "$p_mrFIXExtractDoVol" ]]
    then
        case $(echo ${p_mrFIXExtractDoVol} | tr '[:upper:]' '[:lower:]') in
            (true | yes | 1)
                p_mrFIXExtractDoVol=1
                ;;
            (false | no | none | 0)
                p_mrFIXExtractDoVol=0
                ;;
            *)
                log_Err "--multirun-fix-extract-volume setting must be TRUE or FALSE"
                error_count=$(( error_count + 1 ))
                ;;
        esac
    fi
	
	if [ ${error_count} -gt 0 ]; then
		log_Err_Abort "For usage information, use --help"
	fi
}

# ------------------------------------------------------------------------------
#  Show Tool Versions
# ------------------------------------------------------------------------------

show_tool_versions()
{
	# Show HCP pipelines version
	log_Msg "Showing HCP Pipelines version"
	"${HCPPIPEDIR}"/show_version --short

	# Show wb_command version
	log_Msg "Showing Connectome Workbench (wb_command) version"
	${CARET7DIR}/wb_command -version
}

# ------------------------------------------------------------------------------
#  Main processing of script.
# ------------------------------------------------------------------------------

main()
{
	log_Msg "Starting main functionality"

	# Retrieve positional parameters
	local StudyFolder="${1}"
	local Subject="${2}"
	local HighResMesh="${3}"
	local LowResMeshes="${4}"
	local RegName="${5}"
	local DeDriftRegFiles="${6}"
	local OutputRegName="${7}"
	local Maps="${8}"
	local MyelinMaps="${9}"
	local fixNames="${10}"
	local dontFixNames="${11}"
	local mrFIXNames="${12}"
	local mrFIXConcatNames="${13}"
	local SmoothingFWHM="${14}"
	local HighPass="${15}"
	local MotionRegression="${16}"
	local MyelinTargetFile="${17}"
	local InRegName="${18}"
	local MatlabRunMode="${19}"
	local mrFIXExtractNames="${20}"
	local mrFIXExtractConcatNames="${21}"
	local mrFIXExtractExtraRegNames="${22}"
	local mrFIXExtractDoVol="${23}"

	#code expects empty string, transform magic NONEs into empty
	if [ "${MyelinTargetFile}" = "NONE" ]; then
		MyelinTargetFile=""
	fi

	if [ "${InRegName}" = "NONE" ]; then
		InRegName=""
	fi
	
	if [ -z "$MatlabRunMode" ]; then
		MatlabRunMode="$G_DEFAULT_MATLAB_RUN_MODE"
	fi

	# Log values retrieved from positional parameters
	log_Msg "StudyFolder: ${StudyFolder}"
	log_Msg "Subject: ${Subject}"
	log_Msg "HighResMesh: ${HighResMesh}"
	log_Msg "LowResMeshes: ${LowResMeshes}"
	log_Msg "RegName: ${RegName}"
	log_Msg "DeDriftRegFiles: ${DeDriftRegFiles}"
	log_Msg "OutputRegName: ${OutputRegName}"
	log_Msg "Maps: ${Maps}"
	log_Msg "MyelinMaps: ${MyelinMaps}"
	log_Msg "mrFIXNames: ${mrFIXNames}"
	log_Msg "mrFIXConcatNames: ${mrFIXConcatNames}"
	log_Msg "mrFIXExtractNames: ${mrFIXExtractNames}"
	log_Msg "mrFIXExtractConcatNames: ${mrFIXExtractConcatNames}"
	log_Msg "mrFIXExtractExtraRegNames: ${mrFIXExtractExtraRegNames}"
	log_Msg "mrFIXExtractDoVol: ${mrFIXExtractDoVol}"
	log_Msg "fixNames: ${fixNames}"
	log_Msg "dontFixNames: ${dontFixNames}"
	log_Msg "SmoothingFWHM: ${SmoothingFWHM}"
	log_Msg "HighPass: ${HighPass}"
	log_Msg "MotionRegression: ${MotionRegression}"
	log_Msg "MyelinTargetFile: ${MyelinTargetFile}"
	log_Msg "InRegName: ${InRegName}"
	log_Msg "MatlabRunMode: ${MatlabRunMode}"

	# Naming Conventions and other variables
	local Caret7_Command="${CARET7DIR}/wb_command"
	log_Msg "Caret7_Command: ${Caret7_Command}"

	LowResMeshes=`echo ${LowResMeshes} | sed 's/@/ /g'`
	log_Msg "After delimiter substitution, LowResMeshes: ${LowResMeshes}"

	DeDriftRegFiles=`echo "$DeDriftRegFiles" | sed s/"@"/" "/g`
	log_Msg "After delimiter substitution, DeDriftRegFiles: ${DeDriftRegFiles}"

	Maps=`echo "$Maps" | sed s/"@"/" "/g`
	log_Msg "After delimiter substitution, Maps: ${Maps}"

    #these elses result in empty when given the empty string, make NONE do the same
    if [[ "${MyelinMaps}" == "NONE" ]]
    then
        MyelinMaps=""
    else
    	MyelinMaps=`echo "$MyelinMaps" | sed s/"@"/" "/g`
	fi
	log_Msg "After delimiter substitution, MyelinMaps: ${MyelinMaps}"

	if [ "${fixNames}" = "NONE" ] ; then
		fixNames=()
	else
		#fixNames=`echo "$fixNames" | sed s/"@"/" "/g`
		IFS=@ read -a fixNames <<< "${fixNames}"
	fi
	log_Msg "After delimiter substitution, fixNames: ${fixNames[@]}"

	if [ "${dontFixNames}" = "NONE" ] ; then
		dontFixNames=()
	else
		#dontFixNames=`echo "$dontFixNames" | sed s/"@"/" "/g`
		IFS=@ read -a dontFixNames <<< "${dontFixNames}"
	fi
	log_Msg "After delimiter substitution, dontFixNames: ${dontFixNames[@]}"

	if [[ "${mrFIXNames}" == "NONE" ]] ; then
		mrFIXNames=()
	else
		#need a flat list of all the names in order to resample - do this before we destroy the original value of the variable
		IFS=@% read -a mrFIXNamesAll <<< "${mrFIXNames}"
		#two-level list, % and @, parse only one stage here
		IFS=% read -a mrFIXNames <<< "${mrFIXNames}"
	fi
	log_Msg "After delimiter substitution, mrFIXNames: ${mrFIXNames[@]}"
	
	if [[ "$mrFIXConcatNames" == "NONE" ]]
	then
		mrFIXConcatNames=()
	else
		IFS=@ read -a mrFIXConcatNames <<< "$mrFIXConcatNames"
	fi
	log_Msg "After delimiter substitution, mrFIXConcatNames: ${mrFIXConcatNames[@]}"
	
	if (( ${#mrFIXNames[@]} != ${#mrFIXConcatNames[@]} ))
	then
		log_Err_Abort "number of MR FIX concat names and run groups are different"
	fi
	
	if [[ "${mrFIXExtractNames}" == "NONE" ]] ; then
		mrFIXExtractNamesArr=()
	else
		#two-level list, % and @, parse only one stage here
		IFS=% read -a mrFIXExtractNamesArr <<< "${mrFIXExtractNames}"
	fi
	log_Msg "After delimiter substitution, mrFIXExtractNamesArr: ${mrFIXExtractNamesArr[@]}"
	
	if [[ "$mrFIXExtractConcatNames" == "NONE" ]]
	then
		mrFIXExtractConcatNamesArr=()
	else
		IFS=@ read -a mrFIXExtractConcatNamesArr <<< "$mrFIXExtractConcatNames"
	fi
	log_Msg "After delimiter substitution, mrFIXExtractConcatNamesArr: ${mrFIXExtractConcatNamesArr[@]}"
	
	if (( ${#mrFIXExtractNamesArr[@]} != ${#mrFIXExtractConcatNamesArr[@]} ))
	then
		log_Err_Abort "number of MR FIX extract concat names and run groups are different (use NONE to skip a group)"
	fi
	
	if (( ${#mrFIXExtractConcatNamesArr[@]} > 0 && ${#mrFIXConcatNames[@]} != ${#mrFIXExtractConcatNamesArr[@]} ))
	then
		log_Err_Abort "number of MR FIX extract groups doesn't match number of MR FIX groups (use NONE to skip a group)"
	fi
	
	if [[ "$mrFIXExtractExtraRegNames" == NONE ]]
	then
		extractExtraRegNamesArr=()
	else
		IFS=@ read -a extractExtraRegNamesArr <<< "$mrFIXExtractExtraRegNames"
	fi
	log_Msg "After delimiter substitution, extractExtraRegNamesArr: ${extractExtraRegNamesArr[@]}"
	
	if ((mrFIXExtractDoVol && ${#mrFIXExtractConcatNamesArr[@]} == 0))
	then
		log_Err_Abort "--multirun-fix-extract-volume=TRUE requires --multirun-fix-concat-names"
	fi
	
	CorrectionSigma=$(echo "sqrt ( 200 )" | bc -l)
	log_Msg "CorrectionSigma: ${CorrectionSigma}"

	AtlasFolder="${StudyFolder}/${Subject}/MNINonLinear"
	log_Msg "AtlasFolder: ${AtlasFolder}"

	T1wFolder="${StudyFolder}/${Subject}/T1w"
	log_Msg "T1wFolder: ${T1wFolder}"

	NativeFolder="${AtlasFolder}/Native"
	log_Msg "NativeFolder: ${NativeFolder}"

	NativeT1wFolder="${T1wFolder}/Native"
	log_Msg "NativeT1wFolder: ${NativeT1wFolder}"

	ResultsFolder="${AtlasFolder}/Results"
	log_Msg "ResultsFolder: ${ResultsFolder}"

	#Naming Conventions
	local DownSampleFolderNames=""
	local DownSampleT1wFolderNames=""
	for LowResMesh in ${LowResMeshes} ; do
		DownSampleFolderNames=`echo "${DownSampleFolderNames}${AtlasFolder}/fsaverage_LR${LowResMesh}k "`
		DownSampleT1wFolderNames=`echo "${DownSampleT1wFolderNames}${T1wFolder}/fsaverage_LR${LowResMesh}k "`
	done
	log_Msg "DownSampleFolderNames: ${DownSampleFolderNames}"
	log_Msg "DownSampleT1wFolderNames: ${DownSampleT1wFolderNames}"

	# Concat Reg
	log_Msg "Concat Reg"
	for Hemisphere in L R ; do
		if [ $Hemisphere = "L" ] ; then 
			Structure="CORTEX_LEFT"
			DeDriftRegFile=`echo ${DeDriftRegFiles} | cut -d " " -f 1`
		elif [ $Hemisphere = "R" ] ; then 
			Structure="CORTEX_RIGHT"
			DeDriftRegFile=`echo ${DeDriftRegFiles} | cut -d " " -f 2`
		fi 

		log_Msg "Hemisphere: ${Hemisphere}"
		log_Msg "Structure: ${Structure}"
		log_Msg "DeDriftRegFile: ${DeDriftRegFile}"

		if [ ! ${RegName} = ${OutputRegName} ] ; then #RegName is already the completed registration, don't overwrite
			${Caret7_Command} -surface-sphere-project-unproject ${NativeFolder}/${Subject}.${Hemisphere}.sphere.${RegName}.native.surf.gii ${AtlasFolder}/${Subject}.${Hemisphere}.sphere.${HighResMesh}k_fs_LR.surf.gii ${DeDriftRegFile} ${NativeFolder}/${Subject}.${Hemisphere}.sphere.${OutputRegName}.native.surf.gii
		fi

		# Make MSM Registration Areal Distortion Maps
		log_Msg "Make MSM Registration Areal Distortion Maps"
		${Caret7_Command} -surface-vertex-areas ${NativeFolder}/${Subject}.${Hemisphere}.sphere.native.surf.gii ${NativeFolder}/${Subject}.${Hemisphere}.sphere.native.shape.gii
		${Caret7_Command} -surface-vertex-areas ${NativeFolder}/${Subject}.${Hemisphere}.sphere.${OutputRegName}.native.surf.gii ${NativeFolder}/${Subject}.${Hemisphere}.sphere.${OutputRegName}.native.shape.gii
		${Caret7_Command} -metric-math "ln(spherereg / sphere) / ln(2)" ${NativeFolder}/${Subject}.${Hemisphere}.ArealDistortion_${OutputRegName}.native.shape.gii -var sphere ${NativeFolder}/${Subject}.${Hemisphere}.sphere.native.shape.gii -var spherereg ${NativeFolder}/${Subject}.${Hemisphere}.sphere.${OutputRegName}.native.shape.gii
		rm ${NativeFolder}/${Subject}.${Hemisphere}.sphere.native.shape.gii ${NativeFolder}/${Subject}.${Hemisphere}.sphere.${OutputRegName}.native.shape.gii

		${Caret7_Command} -surface-distortion ${NativeFolder}/${Subject}.${Hemisphere}.sphere.native.surf.gii ${NativeFolder}/${Subject}.${Hemisphere}.sphere.${OutputRegName}.native.surf.gii ${NativeFolder}/${Subject}.${Hemisphere}.EdgeDistortion_${OutputRegName}.native.shape.gii -edge-method
		
		${Caret7_Command} -surface-distortion "${NativeFolder}"/"${Subject}"."${Hemisphere}".sphere.native.surf.gii "${NativeFolder}"/"${Subject}"."${Hemisphere}".sphere.${OutputRegName}.native.surf.gii "${NativeFolder}"/"$Subject"."$Hemisphere".Strain_${OutputRegName}.native.shape.gii -local-affine-method
	    ${Caret7_Command} -metric-merge "${NativeFolder}"/"$Subject"."$Hemisphere".StrainJ_${OutputRegName}.native.shape.gii -metric "${NativeFolder}"/"$Subject"."$Hemisphere".Strain_${OutputRegName}.native.shape.gii -column 1
	    ${Caret7_Command} -metric-merge "${NativeFolder}"/"$Subject"."$Hemisphere".StrainR_${OutputRegName}.native.shape.gii -metric "${NativeFolder}"/"$Subject"."$Hemisphere".Strain_${OutputRegName}.native.shape.gii -column 2
	    ${Caret7_Command} -metric-math "ln(var) / ln (2)" "${NativeFolder}"/"$Subject"."$Hemisphere".StrainJ_${OutputRegName}.native.shape.gii -var var "${NativeFolder}"/"$Subject"."$Hemisphere".StrainJ_${OutputRegName}.native.shape.gii
	    ${Caret7_Command} -metric-math "ln(var) / ln (2)" "${NativeFolder}"/"$Subject"."$Hemisphere".StrainR_${OutputRegName}.native.shape.gii -var var "${NativeFolder}"/"$Subject"."$Hemisphere".StrainR_${OutputRegName}.native.shape.gii
	    rm "${NativeFolder}"/"$Subject"."$Hemisphere".Strain_${OutputRegName}.native.shape.gii
	done

	${Caret7_Command} -cifti-create-dense-timeseries ${NativeFolder}/${Subject}.ArealDistortion_${OutputRegName}.native.dtseries.nii -left-metric ${NativeFolder}/${Subject}.L.ArealDistortion_${OutputRegName}.native.shape.gii -roi-left ${NativeFolder}/${Subject}.L.atlasroi.native.shape.gii -right-metric ${NativeFolder}/${Subject}.R.ArealDistortion_${OutputRegName}.native.shape.gii -roi-right ${NativeFolder}/${Subject}.R.atlasroi.native.shape.gii
	${Caret7_Command} -cifti-convert-to-scalar ${NativeFolder}/${Subject}.ArealDistortion_${OutputRegName}.native.dtseries.nii ROW ${NativeFolder}/${Subject}.ArealDistortion_${OutputRegName}.native.dscalar.nii
	${Caret7_Command} -set-map-name ${NativeFolder}/${Subject}.ArealDistortion_${OutputRegName}.native.dscalar.nii 1 ${Subject}_ArealDistortion_${OutputRegName}
	${Caret7_Command} -cifti-palette ${NativeFolder}/${Subject}.ArealDistortion_${OutputRegName}.native.dscalar.nii MODE_USER_SCALE ${NativeFolder}/${Subject}.ArealDistortion_${OutputRegName}.native.dscalar.nii -pos-user 0 1 -neg-user 0 -1 -interpolate true -palette-name ROY-BIG-BL -disp-pos true -disp-neg true -disp-zero false
	rm ${NativeFolder}/${Subject}.ArealDistortion_${OutputRegName}.native.dtseries.nii 

	${Caret7_Command} -cifti-create-dense-timeseries ${NativeFolder}/${Subject}.EdgeDistortion_${OutputRegName}.native.dtseries.nii -left-metric ${NativeFolder}/${Subject}.L.EdgeDistortion_${OutputRegName}.native.shape.gii -roi-left ${NativeFolder}/${Subject}.L.atlasroi.native.shape.gii -right-metric ${NativeFolder}/${Subject}.R.EdgeDistortion_${OutputRegName}.native.shape.gii -roi-right ${NativeFolder}/${Subject}.R.atlasroi.native.shape.gii
	${Caret7_Command} -cifti-convert-to-scalar ${NativeFolder}/${Subject}.EdgeDistortion_${OutputRegName}.native.dtseries.nii ROW ${NativeFolder}/${Subject}.EdgeDistortion_${OutputRegName}.native.dscalar.nii
	${Caret7_Command} -set-map-name ${NativeFolder}/${Subject}.EdgeDistortion_${OutputRegName}.native.dscalar.nii 1 ${Subject}_EdgeDistortion_${OutputRegName}
	${Caret7_Command} -cifti-palette ${NativeFolder}/${Subject}.EdgeDistortion_${OutputRegName}.native.dscalar.nii MODE_USER_SCALE ${NativeFolder}/${Subject}.EdgeDistortion_${OutputRegName}.native.dscalar.nii -pos-user 0 1 -neg-user 0 -1 -interpolate true -palette-name ROY-BIG-BL -disp-pos true -disp-neg true -disp-zero false
	rm ${NativeFolder}/${Subject}.EdgeDistortion_${OutputRegName}.native.dtseries.nii 

	${Caret7_Command} -cifti-create-dense-timeseries ${NativeFolder}/${Subject}.StrainJ_${OutputRegName}.native.dtseries.nii -left-metric ${NativeFolder}/${Subject}.L.StrainJ_${OutputRegName}.native.shape.gii -roi-left ${NativeFolder}/${Subject}.L.atlasroi.native.shape.gii -right-metric ${NativeFolder}/${Subject}.R.StrainJ_${OutputRegName}.native.shape.gii -roi-right ${NativeFolder}/${Subject}.R.atlasroi.native.shape.gii
	${Caret7_Command} -cifti-convert-to-scalar ${NativeFolder}/${Subject}.StrainJ_${OutputRegName}.native.dtseries.nii ROW ${NativeFolder}/${Subject}.StrainJ_${OutputRegName}.native.dscalar.nii
	${Caret7_Command} -set-map-name ${NativeFolder}/${Subject}.StrainJ_${OutputRegName}.native.dscalar.nii 1 ${Subject}_StrainJ_${OutputRegName}
	${Caret7_Command} -cifti-palette ${NativeFolder}/${Subject}.StrainJ_${OutputRegName}.native.dscalar.nii MODE_USER_SCALE ${NativeFolder}/${Subject}.StrainJ_${OutputRegName}.native.dscalar.nii -pos-user 0 1 -neg-user 0 -1 -interpolate true -palette-name ROY-BIG-BL -disp-pos true -disp-neg true -disp-zero false
	rm ${NativeFolder}/${Subject}.StrainJ_${OutputRegName}.native.dtseries.nii
	
	${Caret7_Command} -cifti-create-dense-timeseries ${NativeFolder}/${Subject}.StrainR_${OutputRegName}.native.dtseries.nii -left-metric ${NativeFolder}/${Subject}.L.StrainR_${OutputRegName}.native.shape.gii -roi-left ${NativeFolder}/${Subject}.L.atlasroi.native.shape.gii -right-metric ${NativeFolder}/${Subject}.R.StrainR_${OutputRegName}.native.shape.gii -roi-right ${NativeFolder}/${Subject}.R.atlasroi.native.shape.gii
	${Caret7_Command} -cifti-convert-to-scalar ${NativeFolder}/${Subject}.StrainR_${OutputRegName}.native.dtseries.nii ROW ${NativeFolder}/${Subject}.StrainR_${OutputRegName}.native.dscalar.nii
	${Caret7_Command} -set-map-name ${NativeFolder}/${Subject}.StrainR_${OutputRegName}.native.dscalar.nii 1 ${Subject}_StrainR_${OutputRegName}
	${Caret7_Command} -cifti-palette ${NativeFolder}/${Subject}.StrainR_${OutputRegName}.native.dscalar.nii MODE_USER_SCALE ${NativeFolder}/${Subject}.StrainR_${OutputRegName}.native.dscalar.nii -pos-user 0 1 -neg-user 0 -1 -interpolate true -palette-name ROY-BIG-BL -disp-pos true -disp-neg true -disp-zero false
	rm ${NativeFolder}/${Subject}.StrainR_${OutputRegName}.native.dtseries.nii

	DownSampleFolder=`echo ${DownSampleFolderNames} | cut -d " " -f 1`
	log_Msg "DownSampleFolder: ${DownSampleFolder}"

	DownSampleT1wFolder=`echo ${DownSampleT1wFolderNames} | cut -d " " -f 1`
	log_Msg "DownSampleT1wFolder: ${DownSampleT1wFolder}"

	LowResMesh=`echo ${LowResMeshes} | cut -d " " -f 1`
	log_Msg "LowResMesh: ${LowResMesh}"

	# Supports multiple lowres meshes
	log_Msg "Supports multiple lowres meshes"
	for Mesh in ${LowResMeshes} ${HighResMesh} ; do
		log_Msg "Working with Mesh: ${Mesh}"

		if [ $Mesh = ${HighResMesh} ] ; then
			Folder=${AtlasFolder}
			Scale="4"
		else 
			i=1
			for LowResMesh in ${LowResMeshes} ; do
				if [ ${LowResMesh} = ${Mesh} ] ; then
					Folder=`echo ${DownSampleFolderNames} | cut -d " " -f ${i}`
					DownSampleT1wFolder=`echo ${DownSampleT1wFolderNames} | cut -d " " -f ${i}`
				fi
				Scale="1"
				i=$(($i+1))
			done
		fi

		if [ -e ${Folder}/${Subject}.${OutputRegName}.${Mesh}k_fs_LR.wb.spec ] ; then
			rm ${Folder}/${Subject}.${OutputRegName}.${Mesh}k_fs_LR.wb.spec
		fi

		${Caret7_Command} -add-to-spec-file ${Folder}/${Subject}.${OutputRegName}.${Mesh}k_fs_LR.wb.spec INVALID ${AtlasFolder}/T1w_restore.nii.gz
		${Caret7_Command} -add-to-spec-file ${Folder}/${Subject}.${OutputRegName}.${Mesh}k_fs_LR.wb.spec INVALID ${AtlasFolder}/T2w_restore.nii.gz

		if [ ! ${Mesh} = ${HighResMesh} ] ; then
			if [ -e ${DownSampleT1wFolder}/${Subject}.${OutputRegName}.${Mesh}k_fs_LR.wb.spec ] ; then
				rm ${DownSampleT1wFolder}/${Subject}.${OutputRegName}.${Mesh}k_fs_LR.wb.spec
			fi

			${Caret7_Command} -add-to-spec-file ${DownSampleT1wFolder}/${Subject}.${OutputRegName}.${Mesh}k_fs_LR.wb.spec INVALID ${T1wFolder}/T1w_acpc_dc_restore.nii.gz
			${Caret7_Command} -add-to-spec-file ${DownSampleT1wFolder}/${Subject}.${OutputRegName}.${Mesh}k_fs_LR.wb.spec INVALID ${T1wFolder}/T2w_acpc_dc_restore.nii.gz
		fi

		for Hemisphere in L R ; do
			if [ $Hemisphere = "L" ] ; then 
				Structure="CORTEX_LEFT"
			elif [ $Hemisphere = "R" ] ; then 
				Structure="CORTEX_RIGHT"
			fi
			log_Msg "Hemisphere: ${Hemisphere}"
			log_Msg "Structure: ${Structure}"

			${Caret7_Command} -add-to-spec-file ${Folder}/${Subject}.${OutputRegName}.${Mesh}k_fs_LR.wb.spec ${Structure} ${Folder}/${Subject}.${Hemisphere}.sphere.${Mesh}k_fs_LR.surf.gii
			if [ -e ${Folder}/${Subject}.${Hemisphere}.flat.${Mesh}k_fs_LR.surf.gii ] ; then
				${Caret7_Command} -add-to-spec-file ${Folder}/${Subject}.${OutputRegName}.${Mesh}k_fs_LR.wb.spec ${Structure} ${Folder}/${Subject}.${Hemisphere}.flat.${Mesh}k_fs_LR.surf.gii
			fi

			# Create downsampled fs_LR spec files.   
			log_Msg "Create downsampled fs_LR spec files."
			for Surface in white midthickness pial ; do
				${Caret7_Command} -surface-resample ${NativeFolder}/${Subject}.${Hemisphere}.${Surface}.native.surf.gii ${NativeFolder}/${Subject}.${Hemisphere}.sphere.${OutputRegName}.native.surf.gii ${Folder}/${Subject}.${Hemisphere}.sphere.${Mesh}k_fs_LR.surf.gii BARYCENTRIC ${Folder}/${Subject}.${Hemisphere}.${Surface}_${OutputRegName}.${Mesh}k_fs_LR.surf.gii
				${Caret7_Command} -add-to-spec-file ${Folder}/${Subject}.${OutputRegName}.${Mesh}k_fs_LR.wb.spec ${Structure} ${Folder}/${Subject}.${Hemisphere}.${Surface}_${OutputRegName}.${Mesh}k_fs_LR.surf.gii
			done

			log_Debug_Msg "0.1"
			local anatomical_surface_in=${Folder}/${Subject}.${Hemisphere}.midthickness_${OutputRegName}.${Mesh}k_fs_LR.surf.gii
			log_File_Must_Exist "${anatomical_surface_in}"
			${Caret7_Command} -surface-generate-inflated ${anatomical_surface_in} ${Folder}/${Subject}.${Hemisphere}.inflated_${OutputRegName}.${Mesh}k_fs_LR.surf.gii ${Folder}/${Subject}.${Hemisphere}.very_inflated_${OutputRegName}.${Mesh}k_fs_LR.surf.gii -iterations-scale ${Scale}
			${Caret7_Command} -add-to-spec-file ${Folder}/${Subject}.${OutputRegName}.${Mesh}k_fs_LR.wb.spec ${Structure} ${Folder}/${Subject}.${Hemisphere}.inflated_${OutputRegName}.${Mesh}k_fs_LR.surf.gii
			${Caret7_Command} -add-to-spec-file ${Folder}/${Subject}.${OutputRegName}.${Mesh}k_fs_LR.wb.spec ${Structure} ${Folder}/${Subject}.${Hemisphere}.very_inflated_${OutputRegName}.${Mesh}k_fs_LR.surf.gii
    
			if [ ! ${Mesh} = ${HighResMesh} ] ; then
				# Create downsampled fs_LR spec file in structural space.  
				log_Msg "Create downsampled fs_LR spec file in structural space."
				
				for Surface in white midthickness pial ; do
					${Caret7_Command} -surface-resample ${NativeT1wFolder}/${Subject}.${Hemisphere}.${Surface}.native.surf.gii ${NativeFolder}/${Subject}.${Hemisphere}.sphere.${OutputRegName}.native.surf.gii ${Folder}/${Subject}.${Hemisphere}.sphere.${Mesh}k_fs_LR.surf.gii BARYCENTRIC ${DownSampleT1wFolder}/${Subject}.${Hemisphere}.${Surface}_${OutputRegName}.${Mesh}k_fs_LR.surf.gii
					${Caret7_Command} -add-to-spec-file ${DownSampleT1wFolder}/${Subject}.${OutputRegName}.${Mesh}k_fs_LR.wb.spec ${Structure} ${DownSampleT1wFolder}/${Subject}.${Hemisphere}.${Surface}_${OutputRegName}.${Mesh}k_fs_LR.surf.gii
				done

				log_Debug_Msg "0.2"
				anatomical_surface_in=${DownSampleT1wFolder}/${Subject}.${Hemisphere}.midthickness_${OutputRegName}.${Mesh}k_fs_LR.surf.gii
				log_File_Must_Exist "${anatomical_surface_in}"
				${Caret7_Command} -surface-generate-inflated ${anatomical_surface_in} ${DownSampleT1wFolder}/${Subject}.${Hemisphere}.inflated_${OutputRegName}.${Mesh}k_fs_LR.surf.gii ${DownSampleT1wFolder}/${Subject}.${Hemisphere}.very_inflated_${OutputRegName}.${Mesh}k_fs_LR.surf.gii -iterations-scale ${Scale}
				${Caret7_Command} -add-to-spec-file ${DownSampleT1wFolder}/${Subject}.${OutputRegName}.${Mesh}k_fs_LR.wb.spec ${Structure} ${DownSampleT1wFolder}/${Subject}.${Hemisphere}.inflated_${OutputRegName}.${Mesh}k_fs_LR.surf.gii
				${Caret7_Command} -add-to-spec-file ${DownSampleT1wFolder}/${Subject}.${OutputRegName}.${Mesh}k_fs_LR.wb.spec ${Structure} ${DownSampleT1wFolder}/${Subject}.${Hemisphere}.very_inflated_${OutputRegName}.${Mesh}k_fs_LR.surf.gii

				# Compute vertex areas for other analyses
				log_Msg "Create vertex areas for other analyses"

				log_Debug_Msg "0.3"
				local surface=${DownSampleT1wFolder}/${Subject}.${Hemisphere}.midthickness_${OutputRegName}.${Mesh}k_fs_LR.surf.gii
				log_File_Must_Exist "${surface}"
				${Caret7_Command} -surface-vertex-areas ${surface} ${DownSampleT1wFolder}/${Subject}.${Hemisphere}.midthickness_${OutputRegName}_va.${Mesh}k_fs_LR.shape.gii 

				${Caret7_Command} -add-to-spec-file ${DownSampleT1wFolder}/${Subject}.${OutputRegName}.${Mesh}k_fs_LR.wb.spec ${Structure} ${Folder}/${Subject}.${Hemisphere}.sphere.${Mesh}k_fs_LR.surf.gii
				if [ -e ${Folder}/${Subject}.${Hemisphere}.flat.${Mesh}k_fs_LR.surf.gii ] ; then
					${Caret7_Command} -add-to-spec-file ${DownSampleT1wFolder}/${Subject}.${OutputRegName}.${Mesh}k_fs_LR.wb.spec ${Structure} ${Folder}/${Subject}.${Hemisphere}.flat.${Mesh}k_fs_LR.surf.gii
				fi
			fi  
		done

		if [ ! ${Mesh} = ${HighResMesh} ] ; then 
			# Normalize vertex areas mean to 1 for other analyses
			log_Msg "Normalize vertex areas mean to 1 for other analyses"
			${Caret7_Command} -cifti-create-dense-scalar ${DownSampleT1wFolder}/${Subject}.midthickness_${OutputRegName}_va.${Mesh}k_fs_LR.dscalar.nii -left-metric ${DownSampleT1wFolder}/${Subject}.L.midthickness_${OutputRegName}_va.${Mesh}k_fs_LR.shape.gii -roi-left ${Folder}/${Subject}.L.atlasroi.${Mesh}k_fs_LR.shape.gii -right-metric ${DownSampleT1wFolder}/${Subject}.R.midthickness_${OutputRegName}_va.${Mesh}k_fs_LR.shape.gii -roi-right ${Folder}/${Subject}.R.atlasroi.${Mesh}k_fs_LR.shape.gii
			VAMean=`${Caret7_Command} -cifti-stats ${DownSampleT1wFolder}/${Subject}.midthickness_${OutputRegName}_va.${Mesh}k_fs_LR.dscalar.nii -reduce MEAN`
			${Caret7_Command} -cifti-math "VA / ${VAMean}" ${DownSampleT1wFolder}/${Subject}.midthickness_${OutputRegName}_va_norm.${Mesh}k_fs_LR.dscalar.nii -var VA ${DownSampleT1wFolder}/${Subject}.midthickness_${OutputRegName}_va.${Mesh}k_fs_LR.dscalar.nii
		fi
    
		# Resample scalar maps and apply new bias field
		log_Msg "Resample scalar maps and apply new bias field"

		for Map in ${Maps} ${MyelinMaps} SphericalDistortion ArealDistortion EdgeDistortion StrainJ StrainR ; do
			log_Msg "Map: ${Map}"

			for MapMap in ${MyelinMaps} ; do
				log_Msg "MapMap: ${MapMap}"

				if [ ${MapMap} = ${Map} ] ; then

					# ----- Begin moved statements -----

					# Recompute Myelin Map Bias Field Based on Better Registration
					log_Msg "Recompute Myelin Map Bias Field Based on Better Registration"

					local cifti_in=${NativeFolder}/${Subject}.MyelinMap.native.dscalar.nii
					log_File_Must_Exist "${cifti_in}" # 1

					local cifti_template=${DownSampleFolder}/${Subject}.MyelinMap.${LowResMesh}k_fs_LR.dscalar.nii
					log_File_Must_Exist "${cifti_template}" # 2

					local cifti_out=${DownSampleFolder}/${Subject}.MyelinMap_${OutputRegName}.${LowResMesh}k_fs_LR.dscalar.nii

					local left_spheres_current_sphere=${NativeFolder}/${Subject}.L.sphere.${OutputRegName}.native.surf.gii
					log_File_Must_Exist "${left_spheres_current_sphere}" # 3

					local left_spheres_new_sphere=${DownSampleFolder}/${Subject}.L.sphere.${LowResMesh}k_fs_LR.surf.gii
					log_File_Must_Exist "${left_spheres_new_sphere}" # 4

					local left_area_surfs_current_area=${NativeT1wFolder}/${Subject}.L.midthickness.native.surf.gii
					log_File_Must_Exist "${left_area_surfs_current_area}" # 5

					local left_area_surfs_new_area=${DownSampleT1wFolder}/${Subject}.L.midthickness_${OutputRegName}.${LowResMesh}k_fs_LR.surf.gii
					log_File_Must_Exist "${left_area_surfs_new_area}" # 6 - This is the one that doesn't exist

					local right_spheres_current_sphere=${NativeFolder}/${Subject}.R.sphere.${OutputRegName}.native.surf.gii
					log_File_Must_Exist "${right_spheres_current_sphere}"

					local right_spheres_new_sphere=${DownSampleFolder}/${Subject}.R.sphere.${LowResMesh}k_fs_LR.surf.gii
					log_File_Must_Exist "${right_spheres_new_sphere}"

					local right_area_surfs_current_area=${NativeT1wFolder}/${Subject}.R.midthickness.native.surf.gii
					log_File_Must_Exist "${right_area_surfs_current_area}"

					local right_area_surfs_new_area=${DownSampleT1wFolder}/${Subject}.R.midthickness_${OutputRegName}.${LowResMesh}k_fs_LR.surf.gii
					log_File_Must_Exist "${right_area_surfs_new_area}"

					log_Debug_Msg "Point 1.1"

					${Caret7_Command} -cifti-resample ${cifti_in} COLUMN ${cifti_template} COLUMN ADAP_BARY_AREA ENCLOSING_VOXEL ${cifti_out} -surface-postdilate 40 -left-spheres ${left_spheres_current_sphere} ${left_spheres_new_sphere} -left-area-surfs ${left_area_surfs_current_area} ${left_area_surfs_new_area} -right-spheres ${right_spheres_current_sphere} ${right_spheres_new_sphere} -right-area-surfs ${right_area_surfs_current_area} ${right_area_surfs_new_area}

					log_Debug_Msg "Point 1.2"

					if [[ ! -e ${DownSampleFolder}/${Subject}.atlas_MyelinMap_BC.${LowResMesh}k_fs_LR.dscalar.nii ]] ; then
						if [[ ! -z ${MyelinTargetFile} ]] ; then
							cp ${MyelinTargetFile} ${DownSampleFolder}/${Subject}.atlas_MyelinMap_BC.${LowResMesh}k_fs_LR.dscalar.nii
						else
							log_Err_Abort "A --myelin-target-file is required to run this pipeline when using a different mesh resolution than the original MSMAll registration"
						fi
					fi

					${Caret7_Command} -cifti-math "Individual - Reference" ${DownSampleFolder}/${Subject}.BiasField_${OutputRegName}.${LowResMesh}k_fs_LR.dscalar.nii -var Individual ${DownSampleFolder}/${Subject}.MyelinMap_${OutputRegName}.${LowResMesh}k_fs_LR.dscalar.nii -var Reference ${DownSampleFolder}/${Subject}.atlas_MyelinMap_BC.${LowResMesh}k_fs_LR.dscalar.nii
					${Caret7_Command} -cifti-smoothing ${DownSampleFolder}/${Subject}.BiasField_${OutputRegName}.${LowResMesh}k_fs_LR.dscalar.nii ${CorrectionSigma} 0 COLUMN ${DownSampleFolder}/${Subject}.BiasField_${OutputRegName}.${LowResMesh}k_fs_LR.dscalar.nii -left-surface ${DownSampleT1wFolder}/${Subject}.L.midthickness_${OutputRegName}.${LowResMesh}k_fs_LR.surf.gii -right-surface ${DownSampleT1wFolder}/${Subject}.R.midthickness_${OutputRegName}.${LowResMesh}k_fs_LR.surf.gii
					${Caret7_Command} -cifti-resample ${DownSampleFolder}/${Subject}.BiasField_${OutputRegName}.${LowResMesh}k_fs_LR.dscalar.nii COLUMN ${NativeFolder}/${Subject}.MyelinMap.native.dscalar.nii COLUMN ADAP_BARY_AREA ENCLOSING_VOXEL ${NativeFolder}/${Subject}.BiasField_${OutputRegName}.native.dscalar.nii -surface-postdilate 40 -left-spheres ${DownSampleFolder}/${Subject}.L.sphere.${LowResMesh}k_fs_LR.surf.gii ${NativeFolder}/${Subject}.L.sphere.${OutputRegName}.native.surf.gii -left-area-surfs ${DownSampleT1wFolder}/${Subject}.L.midthickness_${OutputRegName}.${LowResMesh}k_fs_LR.surf.gii ${NativeT1wFolder}/${Subject}.L.midthickness.native.surf.gii -right-spheres ${DownSampleFolder}/${Subject}.R.sphere.${LowResMesh}k_fs_LR.surf.gii ${NativeFolder}/${Subject}.R.sphere.${OutputRegName}.native.surf.gii -right-area-surfs ${DownSampleT1wFolder}/${Subject}.R.midthickness_${OutputRegName}.${LowResMesh}k_fs_LR.surf.gii ${NativeT1wFolder}/${Subject}.R.midthickness.native.surf.gii 

					# ----- End moved statements -----

					${Caret7_Command} -cifti-math "Var - Bias" ${NativeFolder}/${Subject}.${Map}_BC_${OutputRegName}.native.dscalar.nii -var Var ${NativeFolder}/${Subject}.${Map}.native.dscalar.nii -var Bias ${NativeFolder}/${Subject}.BiasField_${OutputRegName}.native.dscalar.nii
					Map="${Map}_BC"

					log_Debug_Msg "Point 1.3"
				fi
			done

			log_Debug_Msg "Point 2.0"

			if [[ ${Map} = "ArealDistortion" || ${Map} = "EdgeDistortion" || ${Map} = "StrainJ" || ${Map} = "StrainR" || ${Map} = "MyelinMap_BC" || ${Map} = "SmoothedMyelinMap_BC" ]] ; then
				NativeMap="${Map}_${OutputRegName}"
			else
				NativeMap="${Map}"
			fi

			log_Debug_Msg "Point 3.0"

			if [ ! ${Mesh} = ${HighResMesh} ] ; then
				${Caret7_Command} -cifti-resample ${NativeFolder}/${Subject}.${NativeMap}.native.dscalar.nii COLUMN ${Folder}/${Subject}.MyelinMap_BC.${Mesh}k_fs_LR.dscalar.nii COLUMN ADAP_BARY_AREA ENCLOSING_VOXEL ${Folder}/${Subject}.${Map}_${OutputRegName}.${Mesh}k_fs_LR.dscalar.nii -surface-postdilate 30 -left-spheres ${NativeFolder}/${Subject}.L.sphere.${OutputRegName}.native.surf.gii ${Folder}/${Subject}.L.sphere.${Mesh}k_fs_LR.surf.gii -left-area-surfs ${NativeT1wFolder}/${Subject}.L.midthickness.native.surf.gii ${DownSampleT1wFolder}/${Subject}.L.midthickness_${OutputRegName}.${Mesh}k_fs_LR.surf.gii -right-spheres ${NativeFolder}/${Subject}.R.sphere.${OutputRegName}.native.surf.gii ${Folder}/${Subject}.R.sphere.${Mesh}k_fs_LR.surf.gii -right-area-surfs ${NativeT1wFolder}/${Subject}.R.midthickness.native.surf.gii ${DownSampleT1wFolder}/${Subject}.R.midthickness_${OutputRegName}.${Mesh}k_fs_LR.surf.gii
				for MapMap in ${Maps} ${MyelinMaps} ; do
					if [[ ${MapMap} = ${Map} || ${MapMap}_BC = ${Map} ]] ; then
						${Caret7_Command} -add-to-spec-file ${Folder}/${Subject}.${OutputRegName}.${Mesh}k_fs_LR.wb.spec INVALID ${Folder}/${Subject}.${Map}_${OutputRegName}.${Mesh}k_fs_LR.dscalar.nii
						${Caret7_Command} -add-to-spec-file ${DownSampleT1wFolder}/${Subject}.${OutputRegName}.${Mesh}k_fs_LR.wb.spec INVALID ${Folder}/${Subject}.${Map}_${OutputRegName}.${Mesh}k_fs_LR.dscalar.nii
					fi
				done
			else
				${Caret7_Command} -cifti-resample ${NativeFolder}/${Subject}.${NativeMap}.native.dscalar.nii COLUMN ${Folder}/${Subject}.MyelinMap_BC.${Mesh}k_fs_LR.dscalar.nii COLUMN ADAP_BARY_AREA ENCLOSING_VOXEL ${Folder}/${Subject}.${Map}_${OutputRegName}.${Mesh}k_fs_LR.dscalar.nii -surface-postdilate 30 -left-spheres ${NativeFolder}/${Subject}.L.sphere.${OutputRegName}.native.surf.gii ${Folder}/${Subject}.L.sphere.${Mesh}k_fs_LR.surf.gii -left-area-surfs ${NativeT1wFolder}/${Subject}.L.midthickness.native.surf.gii ${Folder}/${Subject}.L.midthickness_${OutputRegName}.${Mesh}k_fs_LR.surf.gii -right-spheres ${NativeFolder}/${Subject}.R.sphere.${OutputRegName}.native.surf.gii ${Folder}/${Subject}.R.sphere.${Mesh}k_fs_LR.surf.gii -right-area-surfs ${NativeT1wFolder}/${Subject}.R.midthickness.native.surf.gii ${Folder}/${Subject}.R.midthickness_${OutputRegName}.${Mesh}k_fs_LR.surf.gii   
				for MapMap in ${Maps} ${MyelinMaps} ; do
					if [[ ${MapMap} = ${Map} || ${MapMap}_BC = ${Map} ]] ; then
						${Caret7_Command} -add-to-spec-file ${Folder}/${Subject}.${OutputRegName}.${Mesh}k_fs_LR.wb.spec INVALID ${Folder}/${Subject}.${Map}_${OutputRegName}.${Mesh}k_fs_LR.dscalar.nii
					fi
				done
			fi

			log_Debug_Msg "Point 4.0"
		done
		log_Debug_Msg "Point 5.0"
	done
	
	log_Debug_Msg "Point 6.0"

	for Map in ${MyelinMaps} ; do
		log_Debug_Msg "Point 6.1"
		${Caret7_Command} -add-to-spec-file ${NativeFolder}/${Subject}.native.wb.spec INVALID ${NativeFolder}/${Subject}.${Map}_BC_${OutputRegName}.native.dscalar.nii
		log_Debug_Msg "Point 6.2"
		${Caret7_Command} -add-to-spec-file ${NativeT1wFolder}/${Subject}.native.wb.spec INVALID ${NativeFolder}/${Subject}.${Map}_BC_${OutputRegName}.native.dscalar.nii
		log_Debug_Msg "Point 6.3"
	done

	log_Debug_Msg "Point 7.0"

	# Set Variables (Does not support multiple resolution meshes):
	DownSampleFolder=`echo ${DownSampleFolderNames} | cut -d " " -f 1`
	DownSampleT1wFolder=`echo ${DownSampleT1wFolderNames} | cut -d " " -f 1`
	LowResMesh=`echo ${LowResMeshes} | cut -d " " -f 1`

	# Resample (and resmooth) TS from Native 
	log_Msg "Resample (and resmooth) TS from Native"
	for fMRIName in "${fixNames[@]}" "${dontFixNames[@]}" "${mrFIXNamesAll[@]}" ; do
		log_Msg "fMRIName: ${fMRIName}"
		cp ${ResultsFolder}/${fMRIName}/${fMRIName}_Atlas${InRegName}.dtseries.nii ${ResultsFolder}/${fMRIName}/${fMRIName}_Atlas_${OutputRegName}.dtseries.nii
		for Hemisphere in L R ; do
			if [ $Hemisphere = "L" ] ; then 
				Structure="CORTEX_LEFT"
			elif [ $Hemisphere = "R" ] ; then 
				Structure="CORTEX_RIGHT"
			fi 

			log_Msg "Hemisphere: ${Hemisphere}"
			log_Msg "Structure: ${Structure}"

			${Caret7_Command} -metric-resample ${ResultsFolder}/${fMRIName}/${fMRIName}.${Hemisphere}.native.func.gii ${NativeFolder}/${Subject}.${Hemisphere}.sphere.${OutputRegName}.native.surf.gii ${DownSampleFolder}/${Subject}.${Hemisphere}.sphere.${LowResMesh}k_fs_LR.surf.gii ADAP_BARY_AREA ${ResultsFolder}/${fMRIName}/${fMRIName}_${OutputRegName}.${Hemisphere}.atlasroi.${LowResMesh}k_fs_LR.func.gii -area-surfs ${NativeT1wFolder}/${Subject}.${Hemisphere}.midthickness.native.surf.gii ${DownSampleT1wFolder}/${Subject}.${Hemisphere}.midthickness_${OutputRegName}.${LowResMesh}k_fs_LR.surf.gii -current-roi ${NativeFolder}/${Subject}.${Hemisphere}.roi.native.shape.gii
			${Caret7_Command} -metric-dilate ${ResultsFolder}/${fMRIName}/${fMRIName}_${OutputRegName}.${Hemisphere}.atlasroi.${LowResMesh}k_fs_LR.func.gii ${DownSampleT1wFolder}/${Subject}.${Hemisphere}.midthickness_${OutputRegName}.${LowResMesh}k_fs_LR.surf.gii 30 ${ResultsFolder}/${fMRIName}/${fMRIName}_${OutputRegName}.${Hemisphere}.atlasroi.${LowResMesh}k_fs_LR.func.gii -nearest
			${Caret7_Command} -metric-mask ${ResultsFolder}/${fMRIName}/${fMRIName}_${OutputRegName}.${Hemisphere}.atlasroi.${LowResMesh}k_fs_LR.func.gii ${DownSampleFolder}/${Subject}.${Hemisphere}.atlasroi.${LowResMesh}k_fs_LR.shape.gii ${ResultsFolder}/${fMRIName}/${fMRIName}_${OutputRegName}.${Hemisphere}.atlasroi.${LowResMesh}k_fs_LR.func.gii
			Sigma=`echo "$SmoothingFWHM / ( 2 * ( sqrt ( 2 * l ( 2 ) ) ) )" | bc -l`
			${Caret7_Command} -metric-smoothing ${DownSampleT1wFolder}/${Subject}.${Hemisphere}.midthickness_${OutputRegName}.${LowResMesh}k_fs_LR.surf.gii ${ResultsFolder}/${fMRIName}/${fMRIName}_${OutputRegName}.${Hemisphere}.atlasroi.${LowResMesh}k_fs_LR.func.gii ${Sigma} ${ResultsFolder}/${fMRIName}/${fMRIName}_s${SmoothingFWHM}_${OutputRegName}.${Hemisphere}.atlasroi.${LowResMesh}k_fs_LR.func.gii -roi ${DownSampleFolder}/${Subject}.${Hemisphere}.atlasroi.${LowResMesh}k_fs_LR.shape.gii
			${Caret7_Command} -cifti-replace-structure ${ResultsFolder}/${fMRIName}/${fMRIName}_Atlas_${OutputRegName}.dtseries.nii COLUMN -metric ${Structure} ${ResultsFolder}/${fMRIName}/${fMRIName}_s${SmoothingFWHM}_${OutputRegName}.${Hemisphere}.atlasroi.${LowResMesh}k_fs_LR.func.gii
		done
	done

	# ReApply FIX Cleanup
	log_Msg "ReApply FIX Cleanup"
	log_Msg "fixNames: ${fixNames[@]}"
	for fMRIName in "${fixNames[@]}" ; do
		log_Msg "fMRIName: ${fMRIName}"
		reapply_fix_cmd=("${HCPPIPEDIR}/ICAFIX/ReApplyFixPipeline.sh" --path="${StudyFolder}" --subject="${Subject}" --fmri-name="${fMRIName}" --high-pass="${HighPass}" --reg-name="${OutputRegName}" --matlab-run-mode="${MatlabRunMode}" --motion-regression="${MotionRegression}")
		log_Msg "reapply_fix_cmd: ${reapply_fix_cmd[*]}"
		"${reapply_fix_cmd[@]}"
	done
	
	# reapply multirun fix
	
    for (( i = 0; i < ${#mrFIXConcatNames[@]}; ++i ))
    do
        log_Msg "ReApply MultiRun FIX Cleanup"
        log_Msg "mrFIXNames: ${mrFIXNames[$i]}"
        log_Msg "mrFIXConcatNames: ${mrFIXConcatNames[$i]}"
        #stage 2 parsing is done by reapply script
        reapply_mr_fix_cmd=("${HCPPIPEDIR}/ICAFIX/ReApplyFixMultiRunPipeline.sh" --path="${StudyFolder}" --subject="${Subject}" --fmri-names="${mrFIXNames[$i]}" --concat-fmri-name="${mrFIXConcatNames[$i]}" --high-pass="${HighPass}" --reg-name="${OutputRegName}" --matlab-run-mode="${MatlabRunMode}" --motion-regression="${MotionRegression}")
        log_Msg "reapply_mr_fix_cmd: ${reapply_mr_fix_cmd[*]}"
        "${reapply_mr_fix_cmd[@]}"
        
        for regname in "$OutputRegName" "${extractExtraRegNamesArr[@]+"${extractExtraRegNamesArr[@]}"}"
        do
            #MSMSulc special naming convention
            if [[ "$regname" == "MSMSulc" ]]
            then
                regname=""
                regstring=""
            else
                regstring=_"$regname"
            fi
            
            extract_cmd=("${HCPPIPEDIR}/global/scripts/ExtractFromMRFIXConcat.sh"
                            --study-folder="$StudyFolder"
                            --subject="$Subject"
                            --multirun-fix-names="${mrFIXNames[$i]}"
                            --csv-out="$StudyFolder/$Subject/MNINonLinear/Results/${mrFIXConcatNames[$i]}/${mrFIXConcatNames[$i]}_Runs.csv"
                            --concat-cifti-input="$StudyFolder/$Subject/MNINonLinear/Results/${mrFIXConcatNames[$i]}/${mrFIXConcatNames[$i]}_Atlas${regstring}_hp${HighPass}_clean.dtseries.nii"
                            --surf-reg-name="$regname")
            
            if (( ${#mrFIXExtractConcatNamesArr[@]} > 0 )) && [[ "${mrFIXExtractConcatNamesArr[$i]}" != NONE && "${mrFIXExtractConcatNamesArr[$i]}" != "" ]]
            then
                mkdir -p "$StudyFolder/$Subject/MNINonLinear/Results/${mrFIXExtractConcatNamesArr[$i]}"
                
                # Using clean_vn.dscalar.nii estimated from the full concat group for the extracted concat group as well.
                # (i.e., estimate for the variance normalization map is based on the full concat group, not
                #  the subset of extracted scans)
                
                # The per-run differences in (unstructured) noise variance were removed before concatenation.
                # The average of those maps (across runs) was multiplied back into the concatenated time series
                #  (in 'hcp_fix_multi_run'), so that the entire concatenated time series has a spatial pattern of
                #  unstructured noise consistent with the average across runs.
                # Given this manner of constructing the concatenated time series, any subset of runs extracted from
                #  the full concatenated set should use this same average map for later variance normalization.
                # We use the "clean_vn" map for this purpose and thus copy it from the full concatenated set to the
                #  extracted set of runs.
                # As a final subtlety, note that the "clean_vn" map itself is not identical to the aforementioned average of
                #  the individual run vn maps, but it is conceptually very similar. In particular, clean_vn is derived within
                #  FIX itself from the concatenated time series by regressing out all structured signals and using the
                #  residual to estimate the unstructured noise, whereas the individual run vn maps were computed using
                #  PCA-based reconstruction of the unstructured noise in 'icaDim.m'.
                
                cp "$StudyFolder/$Subject/MNINonLinear/Results/${mrFIXConcatNames[$i]}/${mrFIXConcatNames[$i]}_Atlas${regstring}_hp${HighPass}_clean_vn.dscalar.nii" \
                    "$StudyFolder/$Subject/MNINonLinear/Results/${mrFIXExtractConcatNamesArr[$i]}/${mrFIXExtractConcatNamesArr[$i]}_Atlas${regstring}_hp${HighPass}_clean_vn.dscalar.nii"
                
                extract_cmd+=(--multirun-fix-names-to-use="${mrFIXExtractNamesArr[$i]}"
                              --cifti-out="$StudyFolder/$Subject/MNINonLinear/Results/${mrFIXExtractConcatNamesArr[$i]}/${mrFIXExtractConcatNamesArr[$i]}_Atlas${regstring}_hp${HighPass}_clean.dtseries.nii")
            fi
            
            "${extract_cmd[@]}"
        done
        
        if ((mrFIXExtractDoVol))
        then
            # Using clean_vn.nii.gz estimated from the full concat group for the extracted concat group as well.
            cp "$StudyFolder/$Subject/MNINonLinear/Results/${mrFIXConcatNames[$i]}/${mrFIXConcatNames[$i]}_hp${HighPass}_clean_vn.nii.gz" \
                "$StudyFolder/$Subject/MNINonLinear/Results/${mrFIXExtractConcatNamesArr[$i]}/${mrFIXExtractConcatNamesArr[$i]}_hp${HighPass}_clean_vn.nii.gz"
            
            extract_cmd=("${HCPPIPEDIR}/global/scripts/ExtractFromMRFIXConcat.sh"
                            --study-folder="$StudyFolder"
                            --subject="$Subject"
                            --multirun-fix-names="${mrFIXNames[$i]}"
                            --multirun-fix-names-to-use="${mrFIXExtractNamesArr[$i]}"
                            --volume-out="$StudyFolder/$Subject/MNINonLinear/Results/${mrFIXExtractConcatNamesArr[$i]}/${mrFIXExtractConcatNamesArr[$i]}_hp${HighPass}_clean.nii.gz"
                            --concat-volume-input="$StudyFolder/$Subject/MNINonLinear/Results/${mrFIXConcatNames[$i]}/${mrFIXConcatNames[$i]}_hp${HighPass}_clean.nii.gz")
            
            "${extract_cmd[@]}"
        fi
    done

	log_Msg "Completing main functionality"
}

# ------------------------------------------------------------------------------
#  "Global" processing - everything above here should be in a function
# ------------------------------------------------------------------------------

# Establish defaults
G_DEFAULT_MATLAB_RUN_MODE=1		# Use interpreted MATLAB

# Set global variables
g_script_name=$(basename "${0}")

# Allow script to return a Usage statement, before any other output
if [ "$#" = "0" ]; then
    show_usage
    exit 1
fi

# Verify HCPPIPEDIR environment variable is set
if [ -z "${HCPPIPEDIR}" ]; then
	echo "${g_script_name}: ABORTING: HCPPIPEDIR environment variable must be set"
	exit 1
fi

# Load function libraries
set -e                                                         # debug trap doesn't trigger in functions, temporary fix - needs to be *before* sourcing debug.shlib for detection of interactive shell to disable it
source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@"         # Debugging functions; also sources log.shlib
source ${HCPPIPEDIR}/global/scripts/opts.shlib                 # Command line option functions

opts_ShowVersionIfRequested $@

if opts_CheckForHelpRequest $@; then
	show_usage
	exit 0
fi

${HCPPIPEDIR}/show_version

log_Debug_On

# Verify required environment variables are set and log value
log_Check_Env_Var HCPPIPEDIR
log_Check_Env_Var CARET7DIR

# Show tool versions
show_tool_versions

# Determine whether named or positional parameters are used and invoke the 'main' function
if [[ ${1} == --* ]]; then
	# Named parameters (e.g. --parameter-name=parameter-value) are used
	log_Msg "Using named parameters"

	# Get command line options
	get_options "$@"

	# Invoke main functionality use positional parameters
	#     ${1}               ${2}           ${3}               ${4}                ${5}           ${6}                   ${7}                 ${8}        ${9}              ${10}             ${11}             ${12}             ${13}                  ${14}                ${15}           ${16}                   ${17}                   ${18}            ${19}                ${20}                    ${21}                          ${22}                            ${23}
	main "${p_StudyFolder}" "${p_Subject}" "${p_HighResMesh}" "${p_LowResMeshes}" "${p_RegName}" "${p_DeDriftRegFiles}" "${p_ConcatRegName}" "${p_Maps}" "${p_MyelinMaps}" "${p_fixNames}" "${p_dontFixNames}" "${p_mrFIXNames}" "${p_mrFIXConcatNames}" "${p_SmoothingFWHM}" "${p_HighPass}" "${p_MotionRegression}" "${p_MyelinTargetFile}" "${p_InRegName}" "${p_MatlabRunMode}" "${p_mrFIXExtractNames}" "${p_mrFIXExtractConcatNames}" "${p_mrFIXExtractExtraRegNames}" "${p_mrFIXExtractDoVol}"
	
else
	# Positional parameters are used
	log_Msg "Using positional parameters"
	main "$@"

fi

