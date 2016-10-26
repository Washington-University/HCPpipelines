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
    echo " Usage ${scriptName} --studyfolder=<study-folder> --subject=<subject-id> --taskname=<task-name>"
    echo ""
    echo "   <study-folder> - folder in which study data resides in sub-folders named by subject ID"
    echo "   <subject-id>   - subject ID"
    echo "   <task-name>    - name of task for which to copy EV files into the results folder"
    echo "                    (e.g. tfMRI_EMOTION_LR, tfMRI_EMOTION_RL, tfMRI_WM_LR, tfMRI_WM_RL, etc.)"
    echo ""
}

#
# Function description
#  Get the command line options for this script
#
# Global output variables
#  ${StudyFolder} - study folder
#  ${Subject} - subject ID
#  ${taskname} - task name
#
get_options() {
    local scriptName=$(basename ${0})
    local arguments=($@)

    # initialize global output variables
    unset StudyFolder
    unset Subject
    unset taskname

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

    # report
    echo ""
    echo "-- ${scriptName}: Specified command-line options - Start --"
    echo "   <study-folder>: ${StudyFolder}"
    echo "   <subject-id>: ${Subject}"
    echo "   <task-name>: ${taskname}"
    echo "-- ${scriptName}: Specified command-line options - End --"
    echo ""
}

#
# Main processing
#
main() {
    get_options $@

    # figure out where the EVs directory to copy is
    evs_dir=${StudyFolder}/${Subject}/unprocessed/3T/${taskname}/LINKED_DATA/EPRIME/EVs

    # figure out where a copy of the EVs file should go
    dest_dir=${StudyFolder}/${Subject}/MNINonLinear/Results/${taskname}

    # copy files
    cp -rv ${evs_dir} ${dest_dir}
}

# Invoke the main function
main $@





