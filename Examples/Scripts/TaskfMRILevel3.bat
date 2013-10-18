#!/bin/bash 

StudyFolder="/media/myelin/brainmappers/Connectome_Project/HCP_PhaseII"
EnvironmentScript="/media/2TBB/Connectome_Project/Pipelines/Examples/Scripts/SetUpHCPPipeline.sh" #Pipeline environment script

###120 Q1+Q2 Subjects With Complete Structural and fMRI -- Diffusion may be incomplete###
Subjlist="100307 103414 103515 103818 105115 110411 111312 113619 114924 115320 117122 118730 118932 119833 120212 123117 124422 125525 128632 129028 130013 133827 133928 134324 135932 136833 137128 138231 139637 142828 143325 149337 149539 151223 151627 153429 156637 157336 158035 158540 159239 161731 162329 163432 167743 172332 175439 182739 185139 192439 192540 193239 194140 196144 197550 199150 200614 201111 205119 205725 209733 210617 212318 214019 214221 214423 217429 221319 249947 250427 255639 293748 298051 304020 307127 397760 414229 448347 485757 499566 528446 530635 552544 559053 579665 581349 585862 598568 627549 638049 645551 654754 665254 672756 677968 702133 729557 732243 734045 748258 753251 788876 792564 826353 856766 857263 859671 861456 865363 885975 887373 889579 894673 896778 896879 901139 917255 932554 984472 992774"
GroupAverageName="Q1-2_Related120"
LevelThreeDesignTemplate="/media/myelin/brainmappers/Connectome_Project/HCP_PhaseII/Scripts/design_template120.fsf" #Just used to get design matrix

###First 40 Q1+Q2 Subjects With Complete Structural and fMRI -- Diffusion may be incomplete###
#Subjlist="100307 103414 105115 110411 111312 113619 115320 117122 118730 118932 123117 124422 125525 128632 129028 130013 133928 135932 136833 139637 149337 149539 151223 151627 156637 161731 192540 201111 209733 212318 214423 221319 298051 397760 414229 499566 528446 654754 672756 792564"
#GroupAverageName="Q1-2_Unrelated40a"
#LevelThreeDesignTemplate="/media/myelin/brainmappers/Connectome_Project/HCP_PhaseII/Scripts/design_template40.fsf" #Just used to get design matrix


# Requirements for this script
#  installed versions of: FSL5.0.5 or higher
#  environment: FSLDIR , HCPPIPEDIR , CARET7DIR

#Set up pipeline environment variables and software
. ${EnvironmentScript}

# Log the originating call
echo "$@"

########################################## INPUTS ########################################## 

#Scripts called by this script do assume they run on the results of the HCP Task Analysis Pipeline from Q2

######################################### DO WORK ##########################################


LevelTwoTaskList="tfMRI_WM tfMRI_GAMBLING tfMRI_MOTOR tfMRI_LANGUAGE tfMRI_SOCIAL tfMRI_RELATIONAL tfMRI_EMOTION"
LevelTwoFSFList="tfMRI_WM tfMRI_GAMBLING tfMRI_MOTOR tfMRI_LANGUAGE tfMRI_SOCIAL tfMRI_RELATIONAL tfMRI_EMOTION"
LowResMesh="32"
SmoothingList="4" #For setting different final smoothings.  2 is no more smoothing.
#SmoothingList="2 4" #For setting different final smoothings.  2 is no more smoothing.
TemporalFilter="200" #Use 2000 for linear detrend
VolumeBasedProcessing="NO" #YES or NO. CAUTION: Only use YES if you want unconstrained volumetric blurring of your data, otherwise set to NO for faster, less biased, and more sensitive processing (grayordinates results do not use unconstrained volumetric blurring and are always produced).
RegNames="NONE" #NONE for regular (currently) FreeSurfer registraton of HCP Pipelines

CommonFolder="${StudyFolder}/${GroupAverageName}" #Will create if doesn't exist

Subjlist=`echo $Subjlist | sed 's/ /@/g'`

for RegName in $RegNames ; do
  i=1
  for LevelTwofMRIName in $LevelTwoTaskList ; do
    LevelTwofsfName=`echo $LevelTwoFSFList | cut -d " " -f $i`
    for FinalSmoothingFWHM in $SmoothingList ; do
      fsl_sub -q veryshort.q ${HCPPIPEDIR}/TaskfMRIAnalysis/TaskfMRILevel3.sh ${Subjlist} ${StudyFolder} ${CommonFolder} ${GroupAverageName} ${LevelThreeDesignTemplate} ${LevelTwofMRIName} ${LevelTwofsfName} ${LowResMesh} ${FinalSmoothingFWHM} ${TemporalFilter} ${VolumeBasedProcessing} ${RegName}
      echo "set -- ${Subjlist} ${StudyFolder} ${CommonFolder} ${GroupAverageName} ${LevelThreeDesignTemplate} ${LevelTwofMRIName} ${LevelTwofsfName} ${LowResMesh} ${FinalSmoothingFWHM} ${TemporalFilter} ${VolumeBasedProcessing} ${RegName}" 
    done
    i=$(($i+1))
  done
done

