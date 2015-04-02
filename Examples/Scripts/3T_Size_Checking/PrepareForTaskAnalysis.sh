#!/bin/bash 

SubjectList="100307"

TaskNameList=""
TaskNameList="${TaskNameList} EMOTION"
TaskNameList="${TaskNameList} GAMBLING"
TaskNameList="${TaskNameList} LANGUAGE"
TaskNameList="${TaskNameList} MOTOR"
TaskNameList="${TaskNameList} RELATIONAL"
TaskNameList="${TaskNameList} SOCIAL"
TaskNameList="${TaskNameList} WM"

DirectionList=""
DirectionList="${DirectionList} RL"
DirectionList="${DirectionList} LR"

StudyFolder="${HOME}/data/3T_Size_Checking"

for subject in ${SubjectList}
do
	
	for task in ${TaskNameList} 
	do
		
		for direction in ${DirectionList}
		do

			# Prepare for Level 1

			../generate_level1_fsf.sh \
				--studyfolder=${StudyFolder} \
				--subject=${subject} \
				--taskname=tfMRI_${task}_${direction} \
				--templatedir=../../fsf_templates \
				--outdir=${StudyFolder}/${subject}/MNINonLinear/Results/tfMRI_${task}_${direction}

			../copy_evs_into_results.sh \
				--studyfolder=${StudyFolder} \
				--subject=${subject} \
				--taskname=tfMRI_${task}_${direction}

		done

		# Prepare for Level 2

		mkdir -p ${StudyFolder}/${subject}/MNINonLinear/Results/tfMRI_${task}
		cp -v ../../fsf_templates/tfMRI_${task}_hp200_s4_level2.fsf ${StudyFolder}/${subject}/MNINonLinear/Results/tfMRI_${task}

	done

done
