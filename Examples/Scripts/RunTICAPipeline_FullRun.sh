#!/bin/bash

set -eu

# this is an example script to run the full tICA pipeline with new estimations on both group sICA and group tICA
# since the step ClassifyTICA is not integrated yet, manual classification must be done (the pipeline will stop and give a message about manual classification)
# then please rerun the pipeline starting from step CleanData and specify the text file containing the component numbers to be removed by cleanup
# please make sure that ICA-FIX, MSMAll and MakeAverageDataset are done properly matching the input arguments before running this tICA pipeline

# Steps to finish this full run tICA pipeline
# 1. run this example script
# 2. after 'ComputeTICAFeatures' step is finished, manually classify the group tICA components and make text file listing all the nuisance components to remove from data
# 3. rerun the script after changing the $StartStep to be 'CleanData', $ComponentsToRemoveTxt to point to a text file containing the components you want removed, and set $sICADim according to the automatically derived sICA dimension
# notice that in step3 if $ComponentsToRemoveTxt is an empty string in the launcher, it by default means that the nuisance text list is located in "$StudyFolder/$GroupAverageName/MNINonLinear/Results/${OutputfMRIName}/tICA_d${sICADim}/Noise.txt"
# otherwise, please specify the $ComponentsToRemoveTxt with the actual text file path

# Global default values
DEFAULT_STUDY_FOLDER="${HOME}/projects/Pipelines_ExampleData" # location of Subject folders (named by subjectID)
# example subjects including 175 7T HCP subjects, separated by @
DEFAULT_SUBJECT_LIST="100610@102311@102816@104416@105923@108323@109123@111312@111514@114823@115017@115825@116726@118225@125525@126426@128935@130518@131217@131722@132118@134627@134829@135124@137128@140117@144226@145834@146129@146432@146735@146937@148133@150423@155938@156334@157336@158035@158136@159239@162935@164131@164636@165436@167036@167440@169343@169444@169747@171633@172130@173334@175237@176542@177140@177645@177746@178142@178243@178647@180533@181232@181636@182436@182739@185442@186949@187345@191033@191336@191841@192439@192641@193845@195041@196144@197348@198653@199655@200210@200311@200614@201515@203418@204521@205220@209228@212419@214019@214524@221319@233326@239136@246133@249947@251833@257845@263436@283543@318637@320826@330324@346137@352738@360030@365343@380036@381038@389357@393247@395756@397760@406836@412528@429040@436845@463040@467351@473952@525541@536647@541943@547046@550439@552241@562345@572045@573249@581450@585256@601127@617748@627549@638049@654552@671855@680957@690152@706040@724446@725751@732243@751550@757764@765864@770352@771354@782561@783462@789373@814649@818859@825048@826353@833249@859671@861456@871762@872764@878776@878877@898176@899885@901139@901442@905147@910241@926862@927359@942658@951457@958976@966975@973770@995174"
DEFAULT_ENVIRONMENT_SCRIPT="${HOME}/projects/Pipelines/Examples/Scripts/SetUpHCPPipeline.sh"
DEFAULT_GROUP_NAME="S1200_MSMAll7T175" # the group average name, which must be specified the same in MakeAverageDataset before running this tICA script
DEFAULT_REG_NAME="MSMAll" # the registration string corresponding to the input files, which must be specified the same in MSMAll pipeline before running this tICA script
DEFAULT_CONFIG_FILE="${HOME}/Examples/Scripts/tICA_config.txt" # generate config file for rerunning with similar settings, or for reusing these results for future cleaning
DEFAULT_MATLAB_MODE=1 # MatlabMode

get_options() {
    local scriptName=$(basename "$0")
    local arguments=("$@")

    # initialize global variables
    StudyFolder="${DEFAULT_STUDY_FOLDER}"
    Subjlist="${DEFAULT_SUBJECT_LIST}"
    EnvironmentScript="${DEFAULT_ENVIRONMENT_SCRIPT}"
    GroupAverageName="${DEFAULT_GROUP_NAME}"
    RegName="${DEFAULT_REG_NAME}"
    ConfigFile="${DEFAULT_CONFIG_FILE}"
    MatlabMode="${DEFAULT_MATLAB_MODE}"

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
            --ConfigFile=*)
                ConfigFile="${argument#*=}"
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

    if [[ "$RegName" == "" ]]
    then
        echo "ERROR: RegName not specified"
        exit 1
    fi

    if [[ "$ConfigFile" == "" ]]
    then
        echo "ERROR: ConfigFile not specified"
        exit 1
    fi

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
    echo "   ConfigFile: ${ConfigFile}"
    echo "   MatlabMode: ${MatlabMode}"
    echo "-- ${scriptName}: Specified Command-Line Options: -- End --"

}

#
# Function Description
#	Main processing of this script
#
#	Gets user specified command line options and runs tICA group processing (please make sure the ICA-FIX, MSMAll and MakeAverageDataset are finished before running this script)
#

main() {

    # get command line options
    get_options "$@"

    # set up pipeline environment variables and software
    source "${EnvironmentScript}"

    # general settings
    # set the ICA mode
    # NEW - estimate a new sICA and a new tICA
    # REUSE_SICA_ONLY - reuse an existing sICA and estimate a new tICA
    # INITIALIZE_TICA - reuse an existing sICA and use an existing tICA to start the estimation
    # REUSE_TICA - reuse an existing sICA and an existing tICA"
    ICAmode="NEW"

    # set the start step beginning from MIGP which is by default the first step
    StartStep="MIGP"
    ConfigIn=""
    ComponentsToRemoveTxt=""
    # since ClassifyTICA is not yet integrated, the pipeline stops at that point, and manual classification is required
    # once it does, rerun the tICA pipeline with StartStep="CleanData", the classification file, and the config file (which contains the automatic sICA dimensionality that was used)
    # so, uncomment these three lines and edit the third one
    #StartStep="CleanData"
    #ConfigIn="$ConfigFile"
    #ComponentsToRemoveTxt="/path/to/your/classification.txt"

    # set how many subjects to do in parallel (local, not cluster-distributed) during individual projection and cleanup, defaults to all detected physical cores, '-1'
    parLimit=-1

    # general inputs
    # set list of fMRI on which ICA+FIX has been run, use @ to separate runs
    fMRINames="rfMRI_REST1_7T_PA@rfMRI_REST2_7T_AP@rfMRI_REST3_7T_PA@rfMRI_REST4_7T_AP"

    # set the output fMRI for the output folder and the other output tICA files
    OutputfMRIName="rfMRI_REST_7T"

    # set the MR concat fMRI name, if multi-run FIX was used, you must specify the concat name with this option, otherwise use an empty string
    MRFixConcatName=""

    # set the file name component representing the preprocessing already done, e.g. '_Atlas_MSMAll_hp0_clean'
    fMRIProcSTRING="_Atlas_MSMAll_hp2000_clean"

    # set temporal highpass full-width (2*sigma) to use, should be the same from running FIX, match with $fMRIProcSTRING
    HighPass="2000"

    # set the resolution of data, like '2' or '1.60' or '2.40'
    fMRIResolution="1.60"

    # set the number of Wishart filtering used in icaDim
    # 6 for HCP-style data of ~2000k-5000k timepoints
    # 5 for HCP-style data of <2000k timepoints
    numWisharts="6"

    # set the mesh resolution, like '32' for 32k_fs_LR
    LowResMesh="32"

    # set the output spectra size for sICA individual projection, RunsXNumTimePoints, like '4800' for 'rfMRI_REST' with four runs or '3880' for 'tfMRI_Concat' with full task concat
    subjectExpectedTimepoints="3600"
    # end of general inputs

    # step0: MIGP inputs
    # set the override number of PCA components to use for group sICA, defaults to subjectExpectedTimepoints above
    PCAOutputDim="3600"

    # set the override internal MIGP dimensionality
    PCAInternalDim="3600"

    # set if resume from a previous interrupted MIGP run, if present
    migpResume="YES"

    # step1: GroupSICA inputs
    # set the number of iterations or mode for estimating sICA dimensionality, default 100
    sicadimIters="100"

    # step2: indProjSICA inputs
    # set the low sICA dimensionalities to use for determining weighting for individual projection, defaults to '7@8@9@10@11@12@13@14@15@16@17@18@19@20@21'
    LowsICADims="7@8@9@10@11@12@13@14@15@16@17@18@19@20@21"

    # step3: ConcatGroupSICA inputs
    # hardcoded conventions are used

    # step4: ComputeGroupTICA inputs
    # hardcoded conventions are used

    # step5: indProjTICA inputs
    # hardcoded conventions are used

    # step6: ComputeTICAFeatures inputs
    # set whether the data should use ReCleanSignal.txt for DVARS, should match with $fMRIProcSTRING
    RecleanModeString="NO"

    # step7: ClassifyTICA inputs
    # not integrated yet

    # step8: CleanData inputs
    # set whether the input data used the legacy bias correction
    FixLegacyBiasString="NO"

    # tICA pipeline
    "$HCPPIPEDIR"/tICA/tICAPipeline.sh --study-folder="$StudyFolder" \
                                    --subject-list="$Subjlist" \
                                    --fmri-names="$fMRINames" \
                                    --output-fmri-name="$OutputfMRIName" \
                                    --mrfix-concat-name="$MRFixConcatName" \
                                    --proc-string="$fMRIProcSTRING" \
                                    --melodic-high-pass="$HighPass" \
                                    --out-group-name="$GroupAverageName" \
                                    --fmri-resolution="$fMRIResolution" \
                                    --surf-reg-name="$RegName" \
                                    --ica-mode="$ICAmode" \
                                    --pca-internal-dim="$PCAInternalDim" \
                                    --pca-out-dim="$PCAOutputDim" \
                                    --num-wishart="$numWisharts" \
                                    --sicadim-iters="$sicadimIters" \
                                    --low-res="$LowResMesh" \
                                    --low-sica-dims="$LowsICADims" \
                                    --subject-expected-timepoints="$subjectExpectedTimepoints" \
                                    --reclean-mode="$RecleanModeString" \
                                    --starting-step="$StartStep" \
                                    --manual-components-to-remove="$ComponentsToRemoveTxt" \
                                    --fix-legacy-bias="$FixLegacyBiasString" \
                                    --parallel-limit="$parLimit" \
                                    --matlab-run-mode="$MatlabMode" \
                                    --config="$ConfigIn" \
                                    --config-out="$ConfigFile"
    
}

#
# Invoke the main function to get things started
#
main "$@"

