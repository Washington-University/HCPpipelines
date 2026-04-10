#!/bin/bash

set -eu

# This is an example script to run the full PFM postprocessing pipeline
# Steps involved:
# 1. RunPROFUMO - Run PROFUMO analysis
# 2. PostPROFUMO - Create time courses, spectra, and maps from PFM results
# 3. RSNRegression - Run RSN regression on PFM data for dual regression
# 4. GroupPFMs - Generate group-level statistics and averages
#
# Please make sure that PROFUMO, ICA-FIX, MSMAll and MakeAverageDataset are done properly 
# matching the input arguments before running this PFM pipeline 

get_options() {
    local scriptName=$(basename "$0")
    local arguments=("$@")

    # initialize variables
    StudyFolder="/media/myelin/brainmappers/Connectome_Project/YA_HCP_Final"
    #Subjlist="100610"
    Subjlist="100610@102311@102816@104416@105923@108323@109123@111312@111514@114823@115017@115825@116726@118225@125525@126426@128935@130518@131217@131722@132118@134627@134829@135124@137128@140117@144226@145834@146129@146432@146735@146937@148133@150423@155938@156334@157336@158035@158136@159239@162935@164131@164636@165436@167036@167440@169343@169444@169747@171633@172130@173334@175237@176542@177140@177645@177746@178142@178243@178647@180533@181232@181636@182436@182739@185442@186949@187345@191033@191336@191841@192439@192641@193845@195041@196144@197348@198653@199655@200210@200311@200614@201515@203418@204521@205220@209228@212419@214019@214524@221319@233326@239136@246133@249947@251833@257845@263436@283543@318637@320826@330324@346137@352738@360030@365343@380036@381038@389357@393247@395756@397760@406836@412528@429040@436845@463040@467351@473952@525541@536647@541943@547046@550439@552241@562345@572045@573249@581450@585256@601127@617748@627549@638049@654552@671855@680957@690152@706040@724446@725751@732243@751550@757764@765864@770352@771354@782561@783462@789373@814649@818859@825048@826353@833249@859671@861456@871762@872764@878776@878877@898176@899885@901139@901442@905147@910241@926862@927359@942658@951457@958976@966975@973770@995174"
    #ret exclude 473952
    #Subjlist="100610@102311@102816@104416@105923@108323@109123@111312@111514@114823@115017@115825@116726@118225@125525@126426@128935@130518@131217@131722@132118@134627@134829@135124@137128@140117@144226@145834@146129@146432@146735@146937@148133@150423@155938@156334@157336@158035@158136@159239@162935@164131@164636@165436@167036@167440@169343@169444@169747@171633@172130@173334@175237@176542@177140@177645@177746@178142@178243@178647@180533@181232@181636@182436@182739@185442@186949@187345@191033@191336@191841@192439@192641@193845@195041@196144@197348@198653@199655@200210@200311@200614@201515@203418@204521@205220@209228@212419@214019@214524@221319@233326@239136@246133@249947@251833@257845@263436@283543@318637@320826@330324@346137@352738@360030@365343@380036@381038@389357@393247@395756@397760@406836@412528@429040@436845@463040@467351@525541@536647@541943@547046@550439@552241@562345@572045@573249@581450@585256@601127@617748@627549@638049@654552@671855@680957@690152@706040@724446@725751@732243@751550@757764@765864@770352@771354@782561@783462@789373@814649@818859@825048@826353@833249@859671@861456@871762@872764@878776@878877@898176@899885@901139@901442@905147@910241@926862@927359@942658@951457@958976@966975@973770@995174"

    EnvironmentScript="/media/myelin/brainmappers/Connectome_Project/YA_HCP_Final/Scripts/SetUpHCPPipeline_PFM_AY.sh"
    GroupAverageName="S1200_MSMAll7T175"

    RegName="MSMAll"
    MatlabMode=1
    RunLocal=0
    QUEUE="matlabparallelhigh.q"

    # parse arguments
    local index argument

    for ((index = 0; index < ${#arguments[@]}; ++index))
    do
        argument="${arguments[index]}"

        case "$argument" in
            --StudyFolder=*)
                StudyFolder="${argument#*=}"
                ;;
            --Subject=*)
                Subjlist="${argument#*=}"
                ;;
            --EnvironmentScript=*)
                EnvironmentScript="${argument#*=}"
                ;;
            --GroupAverageName=*)
                GroupAverageName="${argument#*=}"
                ;;
            --RegName=*)
                RegName="${argument#*=}"
                ;;
            --MatlabMode=*)
                MatlabMode="${argument#*=}"
                ;;
            *)
                echo "ERROR: Unrecognized Option: ${argument}"
                exit 1
                ;;
        esac
    done

    # check required parameters
    if [[ "$StudyFolder" == "" ]]
    then
        echo "ERROR: StudyFolder not specified"
        exit 1
    fi

    if [[ "$Subjlist" == "" ]]
    then
        echo "ERROR: Subjlist not specified"
        exit 1
    fi

    if [[ "$EnvironmentScript" == "" ]]
    then
        echo "ERROR: EnvironmentScript not specified"
        exit 1
    fi

    if [[ "$GroupAverageName" == "" ]]
    then
        echo "ERROR: GroupAverageName not specified"
        exit 1
    fi

    # if [[ "$RegName" == "" ]]
    # then
    #     echo "ERROR: RegName not specified"
    #     exit 1
    # fi

    if [[ "$MatlabMode" == "" ]]
    then
        echo "ERROR: MatlabMode not specified"
        exit 1
    fi

    # report options
    echo "-- ${scriptName}: Specified Command-Line Options: -- Start --"
    echo "   StudyFolder: ${StudyFolder}"
    echo "   Subjlist: ${Subjlist}"
    echo "   EnvironmentScript: ${EnvironmentScript}"
    echo "   GroupAverageName: ${GroupAverageName}"
    echo "   RegName: ${RegName}"
    echo "   MatlabMode: ${MatlabMode}"
    echo "-- ${scriptName}: Specified Command-Line Options: -- End --"
}



#
# Function Description
#	Main processing of this script
#
#	Gets user specified command line options and runs PFM postprocessing pipeline 
#   (please make sure the PROFUMO, ICA-FIX, MSMAll and MakeAverageDataset are finished before running this script)
#

main() {

    # get command line options
    get_options "$@"

    # set up pipeline environment variables and software
    source "${EnvironmentScript}"

    if ((RunLocal)) || [[ "$QUEUE" == "" ]]; then
      echo "running locally"
      queuing_command=("$HCPPIPEDIR"/global/scripts/captureoutput.sh)
    else
      echo "queueing with fsl_sub to $QUEUE"
      queuing_command=("$FSLDIR/bin/fsl_sub" -q "$QUEUE")
    fi

    # general settings
    # set the start step beginning from RunPROFUMO which is by default the first step
    StartStep="RunPROFUMO"
    StopStep="GroupPFMs"

    # set how many subjects to do in parallel (local, not cluster-distributed) during RSN regression, defaults to all detected physical cores, '-1'
    parLimit=-1

    
    # general inputs
    fMRINames="rfMRI_REST1_LR@rfMRI_REST1_RL@rfMRI_REST2_LR@rfMRI_REST2_RL" 

    randSeed=123 # random seed for PROFUMO 

    OutputfMRIName="rfMRI_REST"
    # set the MR concat fMRI name, if multi-run FIX was used, leave empty for single runs
    ConcatName=""

    # set the output spectra size for individual projection, RunsXNumTimePoints    #subjectExpectedTimepoints="3655"
    subjectExpectedTimepoints="4800"

    # set temporal highpass full-width (2*sigma) used in preprocessing
    HighPass="2000"

    #set fMRIResolution of data, like '2','1.60' or '2.40'
    fMRIResolution="2.0"  

    # PFM settings for REST data
    # set the PFM dimensionality
    PFMdim="99" 

    PFMFolder=${StudyFolder}/$GroupAverageName/MNINonLinear/Results/${OutputfMRIName}_PFM_d${PFMdim}
    # Reference image for PROFUMO
    RefImage="${StudyFolder}/$GroupAverageName/MNINonLinear/Results/${OutputfMRIName}/${OutputfMRIName}_Atlas_MSMAll_hp${HighPass}_clean_rclean_tclean_meanvn.dscalar.nii"
    
    # set the file name component representing the preprocessing already done
    fMRIProcSTRING="hp${HighPass}_clean_rclean_tclean"

    # set the mesh resolution, like '32' for 32k_fs_LR
    LowResMesh="32"

    
    # Define OutputSTRING with seed designation
    OutputSTRING="${OutputfMRIName}_d${PFMdim}_${GroupAverageName}_seed${randSeed}_PFMs"

    # RSN regression settings
    FixLegacyBiasString="NO"
    ScaleFactor="0.01"
    LowDims="7@8@9@10@11@12@13@14@15@16@17@18@19@20@21"

    # Volume template file
    VolumeTemplateCIFTI="/media/myelin/brainmappers/Connectome_Project/YA_HCP_Final/S1200_MSMAll7T175/MNINonLinear/${GroupAverageName}_CIFTIVolumeTemplate_${OutputfMRIName}.${fMRIResolution}.dscalar.nii"
 
    # PROFUMO settings
    ProfumoSingularity="/media/myelin/andrea/HCPpipelines/PFM/profumo_v2.sif" 
    ProfumoConfig="${PFMFolder}/dataLocations.json"  
    TR="1.0"
    ProfumoThreads="14"
    DOFCorrection="0.5"
    CovModel="Subject"
    nStarts="5" # number of multi-start iterations for PROFUMO
    RandomSeed="$randSeed" # random seed for PROFUMO reproducibility
    # RefImage will be auto-set based on data type below
    
    # build Profumo data location json
    mkdir -p $PFMFolder
    echo '{' > $ProfumoConfig
    for Subject in $(echo $Subjlist | tr "@" "\n"); do
        echo -e "\t\"$Subject\": {" >> $ProfumoConfig
        for fMRIName in $(echo $fMRINames | tr "@" "\n"); do
            runFile="${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_Atlas_${RegName}_${fMRIProcSTRING}.dtseries.nii"
            if [[ -e $runFile ]]; then
                echo -e "\t\t\"$fMRIName\": \"$runFile\"," >> $ProfumoConfig
            fi
        done
        perl -pi -e 'if (eof) { s/,$// }' $ProfumoConfig  # remove trailing comma
        echo -e "\t}," >> $ProfumoConfig
    done
    perl -pi -e 'if (eof) { s/,$// }' $ProfumoConfig  # remove trailing comma
    echo "}" >> $ProfumoConfig

    # PFM pipeline execution
    echo "Starting PFM postprocessing pipeline..."
    echo "Data type: ${OutputfMRIName}"
    echo "PFM dimension: ${PFMdim}"

    "${queuing_command[@]}" "$HCPPIPEDIR"/PFM/PFMPipeline.sh \
                                    --study-folder="$StudyFolder" \
                                    --subject-list="$Subjlist" \
                                    --fmri-names="$fMRINames" \
                                    --output-fmri-name="$OutputfMRIName" \
                                    --output-string="$OutputSTRING" \
                                    --proc-string="$fMRIProcSTRING" \
                                    --group-average-name="$GroupAverageName" \
                                    --pfm-dimension="$PFMdim" \
                                    --pfm-folder="$PFMFolder" \
                                    --surf-reg-name="$RegName" \
                                    --concat-name="$ConcatName" \
                                    --fmri-resolution="$fMRIResolution" \
                                    --low-res-mesh="$LowResMesh" \
                                    --runs-timepoints="$subjectExpectedTimepoints" \
                                    --low-dims="$LowDims" \
                                    --fix-legacy-bias="$FixLegacyBiasString" \
                                    --scale-factor="$ScaleFactor" \
                                    --starting-step="$StartStep" \
                                    --stop-after-step="$StopStep" \
                                    --parallel-limit="$parLimit" \
                                    --matlab-run-mode="$MatlabMode" \
                                    --profumo-config="$ProfumoConfig" \
                                    --profumo-singularity="$ProfumoSingularity" \
                                    --profumo-tr="$TR" \
                                    --profumo-threads="$ProfumoThreads" \
                                    --profumo-dof-correction="$DOFCorrection" \
                                    --profumo-cov-model="$CovModel" \
                                    --profumo-multi-start-iterations="$nStarts" \
                                    --profumo-random-seed="$RandomSeed" \
                                    --ref-image="$RefImage" \
                                    --volume-template-file="$VolumeTemplateCIFTI"
    
    echo "PFM pipeline submitted successfully!"
}

#
# Invoke the main function to get things started
#
main "$@"

