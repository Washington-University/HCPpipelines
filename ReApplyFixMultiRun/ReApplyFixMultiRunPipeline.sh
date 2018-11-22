#!/bin/bash

#
# # ReApplyFixPipelineMultiRun.sh
#
# ## Copyright Notice
#
# Copyright (C) 2017 The Human Connectome Project/Connectome Coordination Facility
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

usage()
{
	local script_name
	script_name=$(basename "${0}")

	cat <<EOF

${script_name}: ReApplyFix Pipeline for MultiRun ICA+FIX

Usage: ${script_name} PARAMETER...

PARAMETERs are [ ] = optional; < > = user supplied value

  Note: The PARAMETERs can be specified positinally (i.e. without using the --param=value
        form) by simply specifying all values on the command line in the order they are
		listed below.

		e.g. ${script_name} <path to study folder> <subject ID> <fMRINames> ...

  [--help] : show this usage information and exit
   --path=<path to study folder> OR --study-folder=<path to study folder>
   --subject=<subject ID> (e.g. 100610)
   --fmri-names=<fMRI Names> @-separated list of fMRI file names 
     (e.g. /path/to/study/100610/MNINonLinear/Results/tfMRI_RETCCW_7T_AP/tfMRI_RETCCW_7T_AP.nii.gz@/path/to/study/100610/MNINonLinear/Results/tfMRI_RETCW_7T_PA/tfMRI_RETCW_7T_PA.nii.gz)
   --concat-fmri-name=<concatenated fMRI scan file name>
     (e.g. /path/to/study/100610/MNINonLinear/Results/tfMRI_7T_RETCCW_AP_RETCW_PA/tfMRI_7T_RETCCW_AP_RETCW_PA.nii.gz)
   --high-pass=<num> the HighPass variable used in Multi-run ICA+FIX (e.g. 2000)
   [--reg-name=<registration name>] (e.g. MSMAll)
   --motion-regression={TRUE, FALSE}
  [--low-res-mesh=<low res mesh number>] defaults to ${G_DEFAULT_LOW_RES_MESH}
  [--matlab-run-mode={0, 1, 2}] defaults to ${G_DEFAULT_MATLAB_RUN_MODE}
    0 = Use compiled MATLAB
    1 = Use interpreted MATLAB
    2 = Use interpreted Octave

EOF
}

this_script_dir=$(readlink -f "$(dirname "$0")")

# ------------------------------------------------------------------------------
#  Get the command line options for this script.
# ------------------------------------------------------------------------------
get_options()
{
	local arguments=("$@")

	# initialize global output variables
	unset p_StudyFolder      # ${1}
	unset p_Subject          # ${2}
	unset p_fMRINames        # ${3}
	unset p_ConcatfMRIName   # ${4}
	unset p_HighPass         # ${5}
	p_RegName="NONE"         # ${6}
	unset p_LowResMesh       # ${7}
	unset p_MatlabRunMode    # ${8}
	unset p_MotionRegression # ${9}

	# set default values
	p_LowResMesh=${G_DEFAULT_LOW_RES_MESH}
	p_MatlabRunMode=${G_DEFAULT_MATLAB_RUN_MODE}
	
	# parse arguments
	local num_args=${#arguments[@]}
	local argument
	local index=0

	while [ "${index}" -lt "${num_args}" ]; do
		argument=${arguments[index]}

		case ${argument} in
			--help)
				usage
				exit 1
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
			--fmri-names=*)
				p_fMRINames=${argument#*=}
				index=$(( index + 1 ))
				;;
			--concat-fmri-name=*)
				p_ConcatfMRIName=${argument#*=}
				index=$(( index + 1 ))
				;;
			--high-pass=*)
				p_HighPass=${argument#*=}
				index=$(( index + 1 ))
				;;
			--reg-name=*)
				p_RegName=${argument#*=}
				index=$(( index + 1 ))
				;;
			--low-res-mesh=*)
				p_LowResMesh=${argument#*=}
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
				usage
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
		log_Msg "Subject ID: ${p_Subject}"
	fi	

	if [ -z "${p_fMRINames}" ]; then
		log_Err "fMRI Names (--fmri-names=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "fMRI Names: ${p_fMRINames}"
	fi

	if [ -z "${p_ConcatfMRIName}" ]; then
		log_Err "Concatenated fMRI scan name (--concat-fmri-name=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "Concatenated fMRI scan name: ${p_ConcatfMRIName}"
	fi
	
	if [ -z "${p_HighPass}" ]; then
		log_Err "High Pass (--high-pass=) required"
		error_count=$(( error_count + 1 ))
	else
	    if [[ $(echo "${p_HighPass} < 0" | bc) == "1" ]]
	    then
	        log_Err "highpass value must not be negative"
	        error_count=$(( error_count + 1 ))
	    fi
		log_Msg "High Pass: ${p_HighPass}"
	fi

	log_Msg "Reg Name: ${p_RegName}"

	if [ -z "${p_LowResMesh}" ]; then
		log_Err "Low Res Mesh (--low-res-mesh=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "Low Res Mesh: ${p_LowResMesh}"
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
				log_Msg "MATLAB Run Mode: ${p_MatlabRunMode} - Use interpreted Octave"
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
	cat ${HCPPIPEDIR}/version.txt

	# Show wb_command version
	log_Msg "Showing Connectome Workbench (wb_command) version"
	${CARET7DIR}/wb_command -version

	# Show fsl version
#	log_Msg "Showing FSL version"
#	fsl_version_get fsl_ver
#	log_Msg "FSL version: ${fsl_ver}"
}

# ------------------------------------------------------------------------------
#  Check for whether or not we have hand reclassification files
# ------------------------------------------------------------------------------

have_hand_reclassification()
{
	local StudyFolder="${1}"
	local Subject="${2}"
	local fMRIName="${3}"
	local HighPass="${4}"

	[ -e "${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_hp${HighPass}.ica/HandNoise.txt" ]
}

demeanMovementRegressors() {
	In=${1}
	log_Debug "demeanMovementRegressors: In: ${In}"
	Out=${2}
	log_Debug "demeanMovementRegressors: Out: ${Out}"
	log_Debug "demeanMovementRegressors: getting nCols"
	nCols=$(head -1 ${In} | wc -w)
	
	log_Debug "demeanMovementRegressors: nCols: ${nCols}"
	log_Debug "demeanMovementRegressors: getting nRows"
	nRows=$(wc -l < ${In})
	log_Debug "demeanMovementRegressors: nRows: ${nRows}"
	
	AllOut=""
	c=1
	while (( c <= nCols )) ; do
		ColIn=`cat ${In} | sed 's/  */ /g' | sed 's/^ //g' | cut -d " " -f ${c}`
		bcstring=$(echo "$ColIn" | tr '\n' '+' | sed 's/\+*$//g')
		valsum=$(echo "$bcstring" | bc -l)
		valmean=$(echo "$valsum / $nRows" | bc -l)
		ColOut=""
		r=1
		while (( r <= nRows )) ; do
			val=`echo "${ColIn}" | head -${r} | tail -1`
			newval=`echo "${val} - ${valmean}" | bc -l`
			ColOut=`echo ${ColOut} $(printf "%10.6f" $newval)`
			r=$((r+1))
		done
		ColOut=`echo ${ColOut} | tr ' ' '\n'`
		AllOut=`paste <(echo "${AllOut}") <(echo "${ColOut}")`
		c=$((c+1))
	done
	echo "${AllOut}" > ${Out}
}

main()
{
	# Show tool versions
	show_tool_versions

	log_Msg "Starting main functionality"

	# Retrieve positional parameters
	local StudyFolder="${1}"
	local Subject="${2}"
	local fMRINames="${3}"
	local ConcatfMRINameOnly="${4}"
	#script used to take absolute paths, so generate the absolute path and leave the old code
	local ConcatfMRIName="${StudyFolder}/${Subject}/MNINonLinear/Results/${ConcatfMRINameOnly}/${ConcatfMRINameOnly}.nii.gz"
	local HighPass="${5}"
	local RegName="${6}"

	local LowResMesh
	if [ -z "${7}" ]; then
		LowResMesh=${G_DEFAULT_LOW_RES_MESH}
	else
		LowResMesh="${7}"
	fi
	
	local MatlabRunMode
	if [ -z "${8}" ]; then
		MatlabRunMode=${G_DEFAULT_MATLAB_RUN_MODE}
	else
		MatlabRunMode="${8}"
	fi

	local domot="${9}"
	# Log values retrieved from positional parameters
	log_Msg "StudyFolder: ${StudyFolder}"
	log_Msg "Subject: ${Subject}"
	log_Msg "fMRINames: ${fMRINames}"
	log_Msg "ConcatfMRIName: ${ConcatfMRIName}"
	log_Msg "HighPass: ${HighPass}"
	log_Msg "RegName: ${RegName}"
	log_Msg "LowResMesh: ${LowResMesh}"
	log_Msg "MatlabRunMode: ${MatlabRunMode}"

	# Naming Conventions and other variables
	local Caret7_Command="${CARET7DIR}/wb_command"
	log_Msg "Caret7_Command: ${Caret7_Command}"

	local RegString
	if [ "${RegName}" != "NONE" ] ; then
		RegString="_${RegName}"
	else
		RegString=""
	fi

	if [ ! -z ${LowResMesh} ] && [ ${LowResMesh} != ${G_DEFAULT_LOW_RES_MESH} ]; then
		RegString+=".${LowResMesh}k"
	fi

	log_Msg "RegString: ${RegString}"
	
	#fix_3_clean looks at an environment variable for where to get ciftiopen, etc from, so for interpreted modes, it sources the fix settings.sh just for that step, which should point to a working copy
	export FSL_FIX_WBC="${Caret7_Command}"
	export FSL_MATLAB_PATH="${FSLDIR}/etc/matlab"

	local ML_PATHS="addpath('${FSL_MATLAB_PATH}'); addpath('${FSL_FIXDIR}');"

	# Make appropriate files if they don't exist

	local aggressive=0
	local newclassification=0
	local hp=${HighPass}
	local DoVol=0
	local fixlist=".fix"
    # if we have a hand classification and no regname, do volume
	if have_hand_reclassification ${StudyFolder} ${Subject} `basename ${ConcatfMRIName}` ${HighPass}
	then
		fixlist="HandNoise.txt"
		#TSC: if regname (which is surface) isn't NONE, assume the hand classification was previously used with volume data?
		if [[ "${RegName}" == "NONE" ]]
		then
			#WARNING: fix 1.067 and earlier doesn't actually look at the value of DoVol - if the argument exists, it doesn't do volume
			DoVol=1
		fi
	fi
	log_Msg "Use fixlist=$fixlist"
	
	local fmris=${fMRINames//@/ } # replaces the @ that combines the filenames with a space
	log_Msg "fmris: ${fmris}"

	local ConcatName=${ConcatfMRIName}
	log_Msg "ConcatName: ${ConcatName}"

	DIR=`pwd`
	log_Msg "PWD : $DIR"
	###LOOP HERE --> Since the files are being passed as a group

	echo $fmris | tr ' ' '\n' #separates paths separated by ' '

	#Loops over the files and does highpass to each of them
    NIFTIvolMergeSTRING=""
    NIFTIvolhpVNMergeSTRING=""
    SBRefVolSTRING=""
    MeanVolSTRING=""
    VNVolSTRING=""
    CIFTIMergeSTRING=""
    CIFTIhpVNMergeSTRING=""
    MeanCIFTISTRING=""
    VNCIFTISTRING=""
    MovementNIFTIMergeSTRING=""
    MovementNIFTIhpMergeSTRING=""
    MovementTXTMergeSTRING=""

	for fmriname in $fmris ; do
	    #script used to take absolute paths, so generate the absolute path and leave the old code
	    fmri="${StudyFolder}/${Subject}/MNINonLinear/Results/${fmriname}/${fmriname}.nii.gz"
    	log_Msg "Top of loop through fmris: fmri: ${fmri}"
	    NIFTIvolMergeSTRING=`echo "${NIFTIvolMergeSTRING}$($FSLDIR/bin/remove_ext $fmri)_demean "`
	    NIFTIvolhpVNMergeSTRING=`echo "${NIFTIvolhpVNMergeSTRING}$($FSLDIR/bin/remove_ext $fmri)_hp${hp}_vn "`
	    SBRefVolSTRING=`echo "${SBRefVolSTRING}$($FSLDIR/bin/remove_ext $fmri)_SBRef "`
	    MeanVolSTRING=`echo "${MeanVolSTRING}$($FSLDIR/bin/remove_ext $fmri)_mean "`
    	VNVolSTRING=`echo "${VNVolSTRING}$($FSLDIR/bin/remove_ext $fmri)_vn "`
		CIFTIMergeSTRING=`echo "${CIFTIMergeSTRING} -cifti $($FSLDIR/bin/remove_ext $fmri)_Atlas${RegString}_demean.dtseries.nii"`
	    CIFTIhpVNMergeSTRING=`echo "${CIFTIhpVNMergeSTRING} -cifti $($FSLDIR/bin/remove_ext $fmri)_Atlas${RegString}_hp${hp}_vn.dtseries.nii"`
	    MeanCIFTISTRING=`echo "${MeanCIFTISTRING} -cifti $($FSLDIR/bin/remove_ext $fmri)_Atlas${RegString}_mean.dscalar.nii "`
    	VNCIFTISTRING=`echo "${VNCIFTISTRING} -cifti $($FSLDIR/bin/remove_ext $fmri)_Atlas${RegString}_vn.dscalar.nii "`
    	MovementNIFTIMergeSTRING=`echo "${MovementNIFTIMergeSTRING}$($FSLDIR/bin/remove_ext $fmri)_hp$hp.ica/mc/prefiltered_func_data_mcf_conf.nii.gz "`
    	MovementNIFTIhpMergeSTRING=`echo "${MovementNIFTIhpMergeSTRING}$($FSLDIR/bin/remove_ext $fmri)_hp$hp.ica/mc/prefiltered_func_data_mcf_conf_hp.nii.gz "`
		cd `dirname $fmri`
		fmri=`basename $fmri`
		fmri=`$FSLDIR/bin/imglob $fmri`
		#[ `imtest $fmri` != 1 ] && echo No valid 4D_FMRI input file specified && exit 1
		echo $fmri
		tr=`$FSLDIR/bin/fslval $fmri pixdim4`
		echo $fmri
		echo $tr
		log_Msg "processing FMRI file $fmri with highpass $hp"
    
		if [[ ! -f ${fmri}_demean.nii.gz ]]
		then
		    ${FSLDIR}/bin/fslmaths $fmri -Tmean ${fmri}_mean
	        ${FSLDIR}/bin/fslmaths $fmri -sub ${fmri}_mean ${fmri}_demean
        fi

        if [[ ! -f Movement_Regressors_demean.txt ]]
        then
    	    demeanMovementRegressors Movement_Regressors.txt Movement_Regressors_demean.txt
	    fi
	    MovementTXTMergeSTRING=`echo "${MovementTXTMergeSTRING}$(pwd)/Movement_Regressors_demean.txt "`
	    
	    if [[ ! -f $($FSLDIR/bin/remove_ext $fmri)_Atlas${RegString}_demean.dtseries.nii ]]
	    then
	        ${FSL_FIX_WBC} -cifti-reduce $($FSLDIR/bin/remove_ext $fmri)_Atlas${RegString}.dtseries.nii MEAN $($FSLDIR/bin/remove_ext $fmri)_Atlas${RegString}_mean.dscalar.nii
	        ${FSL_FIX_WBC} -cifti-math "TCS - MEAN" $($FSLDIR/bin/remove_ext $fmri)_Atlas${RegString}_demean.dtseries.nii -var TCS $($FSLDIR/bin/remove_ext $fmri)_Atlas${RegString}.dtseries.nii -var MEAN $($FSLDIR/bin/remove_ext $fmri)_Atlas${RegString}_mean.dscalar.nii -select 1 1 -repeat
        fi

        if [[ ! -f "$($FSLDIR/bin/remove_ext $fmri)_Atlas${RegString}_hp${hp}_vn.dtseries.nii" || \
              ! -f "$($FSLDIR/bin/remove_ext $fmri)_Atlas${RegString}_vn.dscalar.nii" || \
              ! -f "$($FSLDIR/bin/remove_ext $fmri)_hp${hp}_vn.nii.gz" || \
              ! -f "$($FSLDIR/bin/remove_ext $fmri)_vn.nii.gz" ]]
        then
            if [[ -e .fix.functionhighpassandvariancenormalize.log ]] ; then
                rm .fix.functionhighpassandvariancenormalize.log
            fi
	    	case ${MatlabRunMode} in
		    0)
			    # Use Compiled Matlab
                "${FSL_FIXDIR}/compiled/$(uname -s)/$(uname -m)/run_functionhighpassandvariancenormalize.sh" "${MATLAB_COMPILER_RUNTIME}" "$tr" "$hp" "$fmri" "${FSL_FIX_WBC}" "${RegString}"
                ;;
            1)
                # interpreted matlab
                (source "${FSL_FIXDIR}/settings.sh"; echo "${ML_PATHS} addpath('${FSL_FIX_CIFTIRW}'); addpath('${this_script_dir}/../ICAFIX'); functionhighpassandvariancenormalize($tr, $hp, '$fmri', '${FSL_FIX_WBC}', '${RegString}');" | matlab -nojvm -nodisplay -nosplash)
                ;;
            2)
                # interpreted octave
                (source "${FSL_FIXDIR}/settings.sh"; echo "${ML_PATHS} addpath('${FSL_FIX_CIFTIRW}'); addpath('${this_script_dir}/../ICAFIX'); functionhighpassandvariancenormalize($tr, $hp, '$fmri', '${FSL_FIX_WBC}', '${RegString}');" | octave-cli -q --no-window-system)
                ;;
            esac
	    fi

        log_Msg "Dims: $(cat ${fmri}_dims.txt)"
        
        if [[ ! -f $(pwd)/${fmri}_hp$hp.ica/mc/prefiltered_func_data_mcf_conf.nii.gz ]]
        then
	        fslmaths $(pwd)/${fmri}_hp$hp.ica/mc/prefiltered_func_data_mcf_conf.nii.gz -Tmean $(pwd)/${fmri}_hp$hp.ica/mc/prefiltered_func_data_mcf_conf_mean.nii.gz
	        fslmaths $(pwd)/${fmri}_hp$hp.ica/mc/prefiltered_func_data_mcf_conf.nii.gz -sub $(pwd)/${fmri}_hp$hp.ica/mc/prefiltered_func_data_mcf_conf_mean.nii.gz $(pwd)/${fmri}_hp$hp.ica/mc/prefiltered_func_data_mcf_conf.nii.gz
	        $FSLDIR/bin/imrm $(pwd)/${fmri}_hp$hp.ica/mc/prefiltered_func_data_mcf_conf_mean.nii.gz
	    fi

	    fmri=${fmri}_hp$hp
	    #cd ${fmri}.ica
	    # Per https://github.com/Washington-University/Pipelines/issues/60, the following line doesn't appear to be necessary
	    #$FSLDIR/bin/imln ../$fmri filtered_func_data
	    #cd ..
	    log_Msg "Bottom of loop through fmris: fmri: ${fmri}"

	done
	###END LOOP

	AlreadyHP="-1"

    if [[ ! -f `remove_ext ${ConcatName}`.nii.gz ]]
    then
        fslmerge -tr `remove_ext ${ConcatName}`_demean ${NIFTIvolMergeSTRING} $tr
        fslmerge -tr `remove_ext ${ConcatName}`_hp${hp}_vn ${NIFTIvolhpVNMergeSTRING} $tr
        fslmerge -t  `remove_ext ${ConcatName}`_SBRef ${SBRefVolSTRING}
        fslmerge -t  `remove_ext ${ConcatName}`_mean ${MeanVolSTRING}
        fslmerge -t  `remove_ext ${ConcatName}`_vn ${VNVolSTRING}
        fslmaths `remove_ext ${ConcatName}`_SBRef -Tmean `remove_ext ${ConcatName}`_SBRef
        fslmaths `remove_ext ${ConcatName}`_mean -Tmean `remove_ext ${ConcatName}`_mean
        fslmaths `remove_ext ${ConcatName}`_vn -Tmean `remove_ext ${ConcatName}`_vn
        fslmaths `remove_ext ${ConcatName}`_hp${hp}_vn -mul `remove_ext ${ConcatName}`_vn `remove_ext ${ConcatName}`_hp${hp} 
        fslmaths `remove_ext ${ConcatName}`_demean -add `remove_ext ${ConcatName}`_mean `remove_ext ${ConcatName}`
        
        fslmaths `remove_ext ${ConcatName}`_SBRef -bin `remove_ext ${ConcatName}`_brain_mask # Inserted to create mask to be used in melodic for suppressing memory error - Takuya Hayashi
    fi
    
    if [[ ! -f `remove_ext ${ConcatName}`_Atlas${RegString}_hp$hp.dtseries.nii ]]
    then
        ${FSL_FIX_WBC} -cifti-merge `remove_ext ${ConcatName}`_Atlas${RegString}_demean.dtseries.nii ${CIFTIMergeSTRING}
        ${FSL_FIX_WBC} -cifti-average `remove_ext ${ConcatName}`_Atlas${RegString}_mean.dscalar.nii ${MeanCIFTISTRING}
        ${FSL_FIX_WBC} -cifti-average `remove_ext ${ConcatName}`_Atlas${RegString}_vn.dscalar.nii ${VNCIFTISTRING}
        ${FSL_FIX_WBC} -cifti-math "TCS + MEAN" `remove_ext ${ConcatName}`_Atlas${RegString}.dtseries.nii -var TCS `remove_ext ${ConcatName}`_Atlas${RegString}_demean.dtseries.nii -var MEAN `remove_ext ${ConcatName}`_Atlas${RegString}_mean.dscalar.nii -select 1 1 -repeat
        ${FSL_FIX_WBC} -cifti-merge `remove_ext ${ConcatName}`_Atlas${RegString}_hp${hp}_vn.dtseries.nii ${CIFTIhpVNMergeSTRING}
        ${FSL_FIX_WBC} -cifti-math "TCS * VN" `remove_ext ${ConcatName}`_Atlas${RegString}_hp${hp}.dtseries.nii -var TCS `remove_ext ${ConcatName}`_Atlas${RegString}_hp${hp}_vn.dtseries.nii -var VN `remove_ext ${ConcatName}`_Atlas${RegString}_vn.dscalar.nii -select 1 1 -repeat
    fi
	
	ConcatFolder=`dirname ${ConcatName}`
	cd ${ConcatFolder}
	##Check to see if concatination occured

	local concat_fmri_orig=`basename $(remove_ext ${ConcatName})`
	local concatfmri=`basename $(remove_ext ${ConcatName})`_hp$hp

    #this directory should exist and not be empty
	cd `remove_ext ${concatfmri}`.ica

	pwd
	echo ../${concat_fmri_orig}_Atlas${RegString}_hp$hp.dtseries.nii

	if [[ -f ../${concat_fmri_orig}_Atlas${RegString}_hp$hp.dtseries.nii ]] ; then
		log_Msg "FOUND FILE: ../${concat_fmri_orig}_Atlas${RegString}_hp$hp.dtseries.nii"
		log_Msg "Performing imln"

		rm -f Atlas.dtseries.nii
		$FSLDIR/bin/imln ../${concat_fmri_orig}_Atlas${RegString}_hp$hp.dtseries.nii Atlas.dtseries.nii
		
		log_Msg "START: Showing linked files"
		ls -l ../${concat_fmri_orig}_Atlas${RegString}_hp$hp.dtseries.nii
		ls -l Atlas.dtseries.nii
		log_Msg "END: Showing linked files"
	else
		log_Warn "FILE NOT FOUND: ../${concat_fmri_orig}_Atlas${RegString}_hp$hp.dtseries.nii"
	fi
	
	${FSLDIR}/bin/imln ../${concatfmri} filtered_func_data
    
	case ${MatlabRunMode} in
		0)
			# Use Compiled Matlab
			
			local matlab_exe="${HCPPIPEDIR}"
			matlab_exe+="/ReApplyFix/scripts/Compiled_fix_3_clean/run_fix_3_clean.sh"
	
			#matlab_compiler_runtime=${MATLAB_COMPILER_RUNTIME}
			local matlab_function_arguments=("'${fixlist}'" "${aggressive}" "${domot}" "${AlreadyHP}")
			if [[ DoVol == 0 ]]
			then
    			matlab_function_arguments+=("${DoVol}")
			fi
			local matlab_logfile="${StudyFolder}/${Subject}_${concat_fmri_orig}_${HighPass}${RegString}.matlab.log"
			local matlab_cmd=("${matlab_exe}" "${MATLAB_COMPILER_RUNTIME}" "${matlab_function_arguments[@]}")

			# redirect tokens must be parsed by bash before doing variable expansion, and thus can't be inside a variable
			log_Msg "Run MATLAB command: ${matlab_cmd[*]} >> ${matlab_logfile} 2>&1"
			"${matlab_cmd[@]}" >> "${matlab_logfile}" 2>&1
			log_Msg "MATLAB command return code $?"
			;;
		
		1)
			# Use interpreted MATLAB
            if [[ DoVol == 0 ]]
            then
    			(source "${FSL_FIXDIR}/settings.sh"; matlab -nojvm -nodisplay -nosplash <<M_PROG
${ML_PATHS} fix_3_clean('${fixlist}',${aggressive},${domot},${AlreadyHP},${DoVol});
M_PROG
)
            else
    			(source "${FSL_FIXDIR}/settings.sh"; matlab -nojvm -nodisplay -nosplash <<M_PROG
${ML_PATHS} fix_3_clean('${fixlist}',${aggressive},${domot},${AlreadyHP});
M_PROG
)
            fi

			;;

		2)
			# Use interpreted OCTAVE
            if [[ DoVol == 0 ]]
            then
    			(source "${FSL_FIXDIR}/settings.sh"; octave-cli -q --no-window-system <<M_PROG
${ML_PATHS} fix_3_clean('${fixlist}',${aggressive},${domot},${AlreadyHP},${DoVol});
M_PROG
)
            else
    			(source "${FSL_FIXDIR}/settings.sh"; octave-cli -q --no-window-system <<M_PROG
${ML_PATHS} fix_3_clean('${fixlist}',${aggressive},${domot},${AlreadyHP});
M_PROG
)
            fi

			;;

		*)
			# Unsupported MATLAB run mode
			log_Err_Abort "Unsupported MATLAB run mode value: ${MatlabRunMode}"
			;;
	esac

	cd ..

	pwd
	echo ${concatfmri}.ica/Atlas_clean.dtseries.nii
	
	if [[ -f ${concatfmri}.ica/filtered_func_data_clean.nii.gz ]]
	then
	    $FSLDIR/bin/immv ${concatfmri}.ica/filtered_func_data_clean ${concatfmri}_clean
        $FSLDIR/bin/immv ${concatfmri}.ica/filtered_func_data_clean_vn ${concatfmri}_clean_vnf
	fi

	if [[ -f ${concatfmri}.ica/Atlas_clean.dtseries.nii ]] ; then
		/bin/mv ${concatfmri}.ica/Atlas_clean.dtseries.nii ${concat_fmri_orig}_Atlas${RegString}_hp${hp}_clean.dtseries.nii
		/bin/mv ${concatfmri}.ica/Atlas_clean_vn.dscalar.nii ${concat_fmri_orig}_Atlas${RegString}_hp${hp}_clean_vn.dscalar.nii
	fi
	
	Start="1"
	for fmriname in $fmris ; do
	    #script used to take absolute paths, so generate the absolute path and leave the old code
	    fmri="${StudyFolder}/${Subject}/MNINonLinear/Results/${fmriname}/${fmriname}.nii.gz"
		NumTPS=`${FSL_FIX_WBC} -file-information $(remove_ext ${fmri})_Atlas${RegString}.dtseries.nii -no-map-info -only-number-of-maps`
	    Stop=`echo "${NumTPS} + ${Start} -1" | bc -l`
	    log_Msg "Start=${Start} Stop=${Stop}"
	
	    log_Debug_Msg "cifti merging"
	    cifti_out=`remove_ext ${fmri}`_Atlas${RegString}_hp${hp}_clean.dtseries.nii
	    ${FSL_FIX_WBC} -cifti-merge ${cifti_out} -cifti ${concat_fmri_orig}_Atlas${RegString}_hp${hp}_clean.dtseries.nii -column ${Start} -up-to ${Stop}
	    ${FSL_FIX_WBC} -cifti-math "((TCS / VNA) * VN) + Mean" `remove_ext ${fmri}`_Atlas${RegString}_hp${hp}_clean.dtseries.nii -var TCS `remove_ext ${fmri}`_Atlas${RegString}_hp${hp}_clean.dtseries.nii -var VNA `remove_ext ${concat_fmri_orig}`_Atlas${RegString}_vn.dscalar.nii -select 1 1 -repeat -var VN `remove_ext ${fmri}`_Atlas${RegString}_vn.dscalar.nii -select 1 1 -repeat -var Mean `remove_ext ${fmri}`_Atlas${RegString}_mean.dscalar.nii -select 1 1 -repeat

	    readme_for_cifti_out=${cifti_out%.dtseries.nii}.README.txt
	    touch ${readme_for_cifti_out}
	    short_cifti_out=${cifti_out##*/}
	    echo "${short_cifti_out} was generated by applying \"multi-run FIX\" (using 'ReApplyFixPipelineMultiRun.sh')" >> ${readme_for_cifti_out}
	    echo "across the following individual runs:" >> ${readme_for_cifti_out}
	    for readme_fmri_name in ${fmris} ; do
    	    #script used to take absolute paths, so generate the absolute path and leave the old code
    	    readme_fmri="${StudyFolder}/${Subject}/MNINonLinear/Results/${readme_fmri_name}/${readme_fmri_name}.nii.gz"
		    echo "  ${readme_fmri}" >> ${readme_for_cifti_out}
	    done
		
		if (( DoVol == 1 ))
		then
	        log_Debug_Msg "volume merging"
	        ${FSL_FIX_WBC} -volume-merge `remove_ext ${fmri}`_hp${hp}_clean.nii.gz -volume ${concatfmri}_clean.nii.gz -subvolume ${Start} -up-to ${Stop}
	        fslmaths `remove_ext ${fmri}`_hp${hp}_clean.nii.gz -div `remove_ext ${concat_fmri_orig}`_vn -mul `remove_ext ${fmri}`_vn -add `remove_ext ${fmri}`_mean `remove_ext ${fmri}`_hp${hp}_clean.nii.gz
        fi
	    Start=`echo "${Start} + ${NumTPS}" | bc -l`
	done

	cd ${DIR}

	log_Msg "Completing main functionality"
}

# ------------------------------------------------------------------------------
#  "Global" processing - everything above here should be in a function
# ------------------------------------------------------------------------------

set -e # If any command exits with non-zero value, this script exits

# Verify that HCPPIPEDIR environment variable is set
if [ -z "${HCPPIPEDIR}" ]; then
	echo "$(basename ${0}): ABORTING: HCPPIPEDIR environment variable must be set"
	exit 1
fi

# Load function libraries
source ${HCPPIPEDIR}/global/scripts/log.shlib # Logging related functions
source ${HCPPIPEDIR}/global/scripts/fsl_version.shlib # Functions for getting FSL version
log_SetToolName "ReApplyFixPipelineMultiRun.sh"
log_Msg "HCPPIPEDIR: ${HCPPIPEDIR}"

# Verify any other needed environment variables are set
log_Check_Env_Var CARET7DIR
log_Check_Env_Var FSLDIR

# Establish default MATLAB run mode
G_DEFAULT_MATLAB_RUN_MODE=1		# Use interpreted MATLAB

# Establish default low res mesh
G_DEFAULT_LOW_RES_MESH=32
	
# Determine whether named or positional parameters are used
if [[ ${1} == --* ]]; then
	# Named parameters (e.g. --parameter-name=parameter-value) are used
	log_Msg "Using named parameters"

	# Get command line options
	get_options "$@"

	# Invoke main functionality
	#     ${1}               ${2}           ${3}             ${4}                  ${5}            ${6}           ${7}              ${8}                ${9}
	main "${p_StudyFolder}" "${p_Subject}" "${p_fMRINames}" "${p_ConcatfMRIName}" "${p_HighPass}" "${p_RegName}" "${p_LowResMesh}" "${p_MatlabRunMode}" "${p_MotionRegression}"

else
	# Positional parameters are used
	log_Msg "Using positional parameters"
	main "$@"

fi







