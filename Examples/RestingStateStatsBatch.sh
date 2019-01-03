StudyFolder="/media/myelin/brainmappers/Connectome_Project/HCP_PhaseTwo"

###449 HCP 500 Subjects with Complete Structural, fMRI
Subjlist="100307 100408 101006 101107 101309 101915 102008 102311 102816 103111 103414 103515 103818 104820 105014 105115 105216 106016 106319 106521 107321 107422 108121 108323 108525 108828 109123 109325 110411 111312 111413 111716 113215 113619 113922 114419 114924 115320 116524 117122 117324 118528 118730 118932 119833 120111 120212 120515 121618 122317 122620 123117 123420 123925 124220 124422 124826 125525 126325 126628 127630 127933 128127 128632 129028 130013 130316 130922 131217 131722 131924 133019 133625 133827 133928 134324 135225 135528 135932 136227 136833 137027 137128 137633 137936 138231 138534 139233 139637 140117 140824 140925 141422 141826 142626 142828 143325 144832 145834 146331 146432 147030 147737 148032 148335 148840 148941 149337 149539 149741 150423 150625 150726 151223 151526 151627 151728 152831 153025 153429 154431 154734 154936 155635 156233 156637 157336 157437 158035 158136 158540 159138 159239 159340 159441 160123 160830 161327 161630 161731 162026 162228 162329 162733 163129 163331 163432 163836 164030 164131 164939 166438 167036 167743 168139 168341 169444 171633 172029 172130 172332 172534 172938 173334 173435 173536 173940 175035 175439 176542 177645 178142 178748 178849 178950 179346 180129 180432 180836 180937 181131 181232 182739 183034 185139 186141 187143 187547 187850 188347 189349 189450 190031 191033 191336 191841 192439 192540 192843 193239 194140 194645 194847 195041 195849 196144 196750 197348 197550 198350 198451 198855 199150 199453 199655 199958 200109 200614 201111 201414 201818 203418 204016 204521 205119 205220 205725 205826 208024 208226 208327 209733 209834 209935 210011 210415 210617 211215 211316 211417 211720 211922 212116 212217 212318 212419 214019 214221 214423 214726 217126 217429 221319 224022 231928 233326 239944 245333 246133 249947 250427 250932 255639 256540 268850 280739 284646 285345 285446 290136 293748 298051 298455 303119 303624 307127 308331 310621 316633 329440 334635 339847 352132 352738 356948 361941 365343 366042 366446 371843 377451 380036 382242 386250 395958 397154 397760 397861 412528 414229 415837 422632 433839 436239 436845 441939 445543 448347 465852 475855 480141 485757 486759 497865 499566 500222 510326 519950 522434 528446 530635 531536 540436 541943 545345 547046 552544 559053 561242 562446 565452 566454 567052 567961 568963 570243 573249 573451 579665 580044 581349 583858 585862 586460 592455 594156 598568 599469 599671 601127 613538 620434 622236 623844 627549 638049 645551 654754 665254 672756 673455 677968 679568 680957 683256 687163 690152 695768 702133 704238 705341 709551 713239 715041 729557 732243 734045 742549 748258 748662 749361 751348 753251 756055 759869 761957 765056 770352 771354 779370 782561 784565 786569 788876 789373 792564 792766 802844 814649 816653 826353 826454 833148 833249 837560 837964 845458 849971 856766 857263 859671 861456 865363 871762 872764 877269 885975 887373 889579 894673 896778 896879 898176 899885 901038 901139 901442 904044 907656 910241 912447 917255 922854 930449 932554 951457 957974 958976 959574 965367 965771 978578 979984 983773 984472 987983 991267 992774 994273"
#Subjlist="100307"
Subjlist="114924"
#Subjlist="119833 150423 284646 786569" #rfMRI Short
#Subjlist="150423 329440 547046 713239" #tfMRI Short
#Subjlist="133928"
Subjlist="106319"
Subjlist="361941"

###28 Registration Optimization Subjects with Complete Structural and fMRI###
#Subjlist="100307 111716 114924 120212 128632 130922 136833 153429 163432 194140 198451 199150 200614 205725 210617 211215 285446 441939 545345 559053 567052 586460 627549 702133 861456 887373 889579 932554"
#GroupAverageName="Q1-Q6_RegOpt28"
#Subjlist="100307"

fMRINames="rfMRI_REST1_LR rfMRI_REST1_RL rfMRI_REST2_LR rfMRI_REST2_RL"
fMRINames="rfMRI_REST1_LR"
fMRINames="rfMRI_REST1_RL"
#fMRINames="rfMRI_REST2_LR"
#fMRINames="rfMRI_REST2_RL"

#fMRINames="tfMRI_WM_GAMBLING_MOTOR_RL_LR tfMRI_LANGUAGE_SOCIAL_RELATIONAL_EMOTION_RL_LR"
fMRINames="tfMRI_WM_GAMBLING_MOTOR_RL_LR"
#fMRINames="tfMRI_LANGUAGE_SOCIAL_RELATIONAL_EMOTION_RL_LR"

OrigHighPass="2000" #Specified in Sigma
Caret7_Command="wb_command"
GitRepo="/media/2TBB/Connectome_Project/Pipelines"
RegName="NONE"
RegName="MSMAll_2_d41_WRN_DeDrift"
#RegName="MSMAllDBStrainFinalExp2K2Bulk1.6Shear0.4_0.00001_0.00001_0.0075_0.01_2_d40_WRN"

LowResMesh="32"
FinalfMRIResolution="2"
BrainOrdinatesResolution="2"
SmoothingFWHM="2"
OutputProcSTRING="_hp2000_clean"
dlabelFile="NONE"
MatlabRunMode="1"
BCMode="REVERT" #One of REVERT (revert bias field correction), NONE (don't change biasfield correction), CORRECT (revert original bias field correction and apply new one, requires ??? to be present)
BCMode="CORRECT" #One of REVERT (revert bias field correction), NONE (don't change biasfield correction), CORRECT (revert original bias field correction and apply new one, requires ??? to be present)
#BCMode="NONE"
OutSTRING="stats"
OutSTRING="stats_bc"
#OutSTRING="stats_biased"
WM="NONE" 
WM="${GitRepo}/global/config/FreeSurferWMRegLut.txt"
CSF="NONE" 
CSF="${GitRepo}/global/config/FreeSurferCSFRegLut.txt"
#tICAtcleanup="NONE" #Doesn't work for concatinated tfMRI
#tICAtcleanup="/media/myelin/brainmappers/Connectome_Project/HCP_PhaseTwo/Q1-Q6_Related449/MNINonLinear/Results/rfMRI_REST/BackupTICA/tICAtcs.txt"
tICAtcleanup="/media/myelin/brainmappers/Connectome_Project/HCP_PhaseTwo/Q1-Q6_Related449/MNINonLinear/Results/rfMRI_REST/tICAtcs_84_tanh_2.txt"
tICAtcleanup="/media/myelin/brainmappers/Connectome_Project/HCP_PhaseTwo/Q1-Q6_Related449/MNINonLinear/Results/tfMRI_ALLTASKS/tICAtcs_70_tanh_5.txt"
#tICAtscleanup="NONE" #Requires tICAtcleanup to not be NONE
tICAtscleanup="/media/myelin/brainmappers/Connectome_Project/HCP_PhaseTwo/Q1-Q6_Related449/MNINonLinear/Results/rfMRI_REST/tsICAtcs_84_tanh_2.txt"
tICAtscleanup="NONE" #Requires tICAtcleanup to not be NONE
Physio="FALSE" #One of TRUE or FALSE if Physio data are not found they are represented by zeros  
Physio="TRUE" #One of TRUE or FALSE if Physio data are not found when TRUE they are represented by zeros
ReUseHighPass="NO" #YES or NO
ReUseHighPass="YES" #YES or NO

EnvironmentScript="${GitRepo}/Examples/Scripts/SetUpHCPPipeline.sh" #Pipeline environment script

# Requirements for this script
#  installed versions of: FSL5.0.2 or higher , FreeSurfer (version 5.2 or higher) , gradunwarp (python code from MGH)
#  environment: FSLDIR , FREESURFER_HOME , HCPPIPEDIR , CARET7DIR , PATH (for gradient_unwarp.py)

#Set up pipeline environment variables and software
. ${EnvironmentScript}

# Log the originating call
echo "$@"

if [ X$SGE_ROOT != X ] ; then
    QUEUE="-q long.q"
fi

PRINTCOM=""
#PRINTCOM="echo"
QUEUE="-q dyn.q"
QUEUE="-q q6.q"
QUEUE="-q NotNice.q"

#Reversed to prevent collisions
for fMRIName in ${fMRINames} ; do
  for Subject in ${Subjlist} ; do
    
    #if [ ! -e ${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/RestingStateStats/${fMRIName}_Atlas_MSMAll_2_d41_WRN_DeDrift_PhysioCleanedMGT.txt ] ; then
    #if [ ! -e ${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/RestingStateStats/${fMRIName}_Atlas_MSMAll_2_d41_WRN_DeDrift_tCleanedMGT.txt ] ; then
    #if [ `cat ${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_Atlas_MSMAll_2_d41_WRN_DeDrift_stats_bc.txt | tail -1 | sed 's/,/ /g' | wc -w` -lt 225 ] ; then
    #if [ ! -e  ${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_Atlas_MSMAll_2_d41_WRN_DeDrift_hp2000_clean_vn.dscalar.nii ] ; then
      rm -r ${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/RestingStateStats 

      ${FSLDIR}/bin/fsl_sub ${QUEUE} \
        ${HCPPIPEDIR}/RestingStateStats/RestingStateStats.sh \
        --path=${StudyFolder} \
        --subject=${Subject} \
        --fmri-name=${fMRIName} \
        --high-pass=${OrigHighPass} \
        --reg-name=${RegName} \
        --low-res-mesh=${LowResMesh} \
        --final-fmri-res=${FinalfMRIResolution} \
        --brain-ordinates-res=${BrainOrdinatesResolution} \
        --smoothing-fwhm=${SmoothingFWHM} \
        --output-proc-string=${OutputProcSTRING} \
        --dlabel-file=${dlabelFile} \
        --matlab-run-mode=${MatlabRunMode} \
        --bc-mode=${BCMode} \
        --out-string=${OutSTRING} \
        --wm=${WM} \
        --csf=${CSF} \
        --ticatcleanup=${tICAtcleanup} \
        --ticatscleanup=${tICAtscleanup} \
        --physio=${Physio} \
        --reuse-high-pass=${ReUseHighPass}      

      # The following lines are used for interactive debugging to set the positional parameters: $1 $2 $3 ...
      
      echo "set -- --path=$StudyFolder \
        --subject=${Subject} \
        --fmri-name=${fMRIName} \
        --high-pass=${OrigHighPass} \
        --reg-name=${RegName} \
        --low-res-mesh=${LowResMesh} \
        --final-fmri-res=${FinalfMRIResolution} \
        --brain-ordinates-res=${BrainOrdinatesResolution} \
        --smoothing-fwhm=${SmoothingFWHM} \
        --output-proc-string=${OutputProcSTRING} \
        --dlabel-file=${dlabelFile} \
        --matlab-run-mode=${MatlabRunMode} \
        --bc-mode=${BCMode} \
        --out-string=${OutSTRING} \
        --csf=${CSF} \
        --ticatcleanup=${tICAtcleanup} \
        --ticatscleanup=${tICAtscleanup} \
        --physio=${Physio} \
        --reuse-high-pass=${ReUseHighPass}"

      echo ". ${EnvironmentScript}"
      sleep 1
    #else
    #  echo "${Subject} ${fMRIName} already processed"
    #fi
  done
done
