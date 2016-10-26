#!/bin/bash

#
# Author(s): Timothy B. Brown (tbbrown at wustl dot edu)
#

#
# Function description
#  Show usage information for this script
#
usage() {
    local scriptName=$(basename ${0})
    echo ""
    echo " Usage ${scriptName} --studyfolder=<study-folder> --subject=<subject-id> --taskname=<task-name> \\"
    echo "                     --templatedir=<template-dir> --outdir=<out-dir>"
    echo ""
    echo "   <study-folder> - folder in which study data resides in sub-folders named by subject ID"
    echo "   <subject-id>   - subject ID"
    echo "   <task-name>    - name of task for which to produce level 1 FSF file"
    echo "                    (e.g. tfMRI_EMOTION_LR, tfMRI_EMOTION_RL, tfMRI_WM_LR, tfMRI_WM_RL, etc.)"
    echo "   <template-dir> - folder in which to find FSF template files"
    echo "   <out-dir>      - output directory in which to place generated level 1 FSF file"
    echo ""
    echo " Image file for which to produce an FSF file will be expected to be found at: "
    echo "   <study-folder>/<subject-id>/MNINonLinear/Results/<task-name>/<task-name>.nii.gz"
    echo ""
    echo " Template file for generation of an FSF file will be expected to be found at: "
    echo "   <template-dir>/<task-name>_hp200_s4_level1.fsf"
    echo ""
    echo " Generated FSF file will be at: "
    echo "   <out-dir>/<task-name>_hp200_s4_level1.fsf"


}

#
# Function description
#  Get the command line options for this script
#
# Global output variables
#  ${StudyFolder} - study folder
#  ${Subject} - subject ID
#  ${taskname} - task name
#  ${templatedir} - template directory
#  ${outdir} - output directory
#
get_options() {
    local scriptName=$(basename ${0})
    local arguments=($@)

    # initialize global output variables
    unset StudyFolder
    unset Subject
    unset taskname
    unset templatedir
    unset outdir

    # parse arguments
    local index=0
    local numArgs=${#arguments[@]}
    local argument

    while [ ${index} -lt ${numArgs} ]; do
		argument=${arguments[index]}

		case ${argument} in
			--help)
				usage
				exit 1
				;;
			--studyfolder=*)
				StudyFolder=${argument#*=}
				index=$(( index + 1 ))
				;;
			--subject=*)
				Subject=${argument#*=}
				index=$(( index + 1 ))
				;;
			--taskname=*)
				taskname=${argument#*=}
				index=$(( index + 1 ))
				;;
			--templatedir=*)
				templatedir=${argument#*=}
				index=$(( index + 1 ))
				;;
			--outdir=*)
				outdir=${argument#*=}
				index=$(( index + 1 ))
				;;
			*)
				usage
				echo ""
				echo "ERROR: Unrecognized Option: ${argument}"
				echo ""
				exit 1
				;;
		esac
    done

    # check required parameters
    if [ -z ${StudyFolder} ]; then
		usage
		echo ""
		echo "ERROR: <study-folder> not specified"
		echo ""
		exit 1
    fi
	
    if [ -z ${Subject} ]; then
		usage
		echo ""
		echo "ERROR: <subject-id> not specified"
		echo ""
		exit 1
    fi
	
    if [ -z ${taskname} ]; then
		usage
		echo ""
		echo "ERROR: <task-name> not specified"
		echo ""
		exit 1
    fi
	
    if [ -z ${templatedir} ]; then
		usage
		echo ""
		echo "ERROR: <template-dir> not specified"
		echo ""
		exit 1
    fi
	
    if [ -z ${outdir} ]; then
		usage
		echo ""
		echo "ERROR: <out-dir> not specified"
		echo ""
		exit 1
    fi
	
    # report
    echo ""
    echo "-- ${scriptName}: Specified command-line options - Start --"
    echo "   <study-folder>: ${StudyFolder}"
    echo "   <subject-id>: ${Subject}"
    echo "   <task-name>: ${taskname}"
    echo "   <template-dir>: ${templatedir}"
    echo "   <out-dir>: ${outdir}"
    echo "-- ${scriptName}: Specified command-line options - End --"
    echo ""
}

#
# Main processing
#
main() {
    get_options $@

    # figure out where the task image file is
    taskfile=${StudyFolder}/${Subject}/MNINonLinear/Results/${taskname}/${taskname}.nii.gz

    echo ""
    echo "Preparing FSF file for: "
    echo "  ${taskfile}"
    echo ""

    # get the number of time points in the image file
    FMRI_NPTS=`fslinfo ${taskfile} | grep -w 'dim4' | awk '{print $2}'`

    # figure out where the template FSF file is
    fsf_template_file=${templatedir}/${taskname}_hp200_s4_level1.fsf

    # copy the template file to the intended destination FSF file
    cp -p ${fsf_template_file} ${outdir}/${taskname}_hp200_s4_level1.fsf

    # modify the destination by putting in the correct number of time points
    sed -i "s/fmri(npts) [0-9]*/fmri(npts) ${FMRI_NPTS}/" ${outdir}/${taskname}_hp200_s4_level1.fsf

    echo ""
    echo "Level 1 FSF file generated at: "
    echo "  ${outdir}/${taskname}_hp200_s4_level1.fsf"
    echo ""
}

# Invoke the main function
main $@





