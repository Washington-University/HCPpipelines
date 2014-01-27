#!/bin/bash
set -e

# Preprocessing Pipeline for diffusion MRI. Generates the "data" directory that can be used as input to the fibre orientation estimation scripts.
# Stamatios Sotiropoulos, Saad Jbabdi, Jesper Andersson, Analysis Group, FMRIB Centre, 2012.
# Matt Glasser, Washington University, 2012.
 
# Requirements for this script
#  installed versions of: FSL5.0.1 or higher, FreeSurfer (version 5 or higher), gradunwarp (python code from MGH)
#  environment: FSLDIR, FREESURFER_HOME, HCPPIPEDIR_dMRI, HCPPIPEDIR, HCPPIPEDIR_Global, HCPPIPEDIR_Bin, HCPPIPEDIR_Config, PATH (for gradient_unwarp.py)

########################################## Hard-Coded variables for the pipeline #################################

b0dist=45     #Minimum distance in volumes between b0s considered for preprocessing
b0maxbval=50  #Volumes with a bvalue smaller than that will be considered as b0s
MissingFileFlag="EMPTY" #String used in the input arguments to indicate that a complete series is missing


########################################## OUTPUT DIRECTORIES ####################################################

## NB: NO assumption is made about the input paths with respect to the output directories - they can be totally different.  All input are taken directly from the input variables without additions or modifications.

# Output path specifiers:
#
# ${StudyFolder} is an input parameter
# ${Subject} is an input parameter

# Main output directories
# DiffFolder=${StudyFolder}/${Subject}/Diffusion
# T1wDiffFolder=${StudyFolder}/${Subject}/T1w/Diffusion

# All outputs are within the directory: ${StudyFolder}/${Subject}
# The full list of output directories are the following
#    $DiffFolder/rawdata
#    $DiffFolder/topup    
#    $DiffFolder/eddy
#    $DiffFolder/data
#    $DiffFolder/reg
#    $T1wDiffFolder

# Also assumes that T1 preprocessing has been carried out with results in ${StudyFolder}/${Subject}/T1w

########################################## SUPPORT FUNCTIONS #####################################################

# ------------------------------------------------------------------------------
#  Load Function Libraries
# ------------------------------------------------------------------------------

source $HCPPIPEDIR/global/scripts/log.shlib  # Logging related functions
source $HCPPIPEDIR/global/scripts/opts.shlib # Command line option functions

# --------------------------------------------------------------------------------
#  Usage Description Function
# --------------------------------------------------------------------------------

show_usage() {
    echo "Usage: `basename $0` --posData=<dataRL1@dataRL2@...>"
    echo "                     --negData=<dataLR1@dataLR2@...>"
    echo "                     --path=<StudyFolder>"
    echo "                     --subject=<SubjectID>"
    echo "                     --echospacing=<Echo Spacing in msecs>"
    echo "                     --PEdir=<Phase Encoding Direction (1 for LR/RL, 2 for AP/PA>"
    echo "                     --gdcoeffs=<Coefficients for gradient nonlinearity distortion correction('NONE' to switch off)>"
    echo "                     --printcom=<'' to run normally, 'echo' to just print and not run commands, or omit argument to run normally>"

    exit 1
}

# --------------------------------------------------------------------------------
#   Establish tool name for logging
# --------------------------------------------------------------------------------
log_SetToolName "DiffPreprocPipeline.sh"

# function for finding the min between two numbers
min(){
  if [ $1 -le $2 ]; then
     echo $1
  else
     echo $2
  fi
}

################################################## OPTION PARSING ###################################################

opts_ShowVersionIfRequested $@

if opts_CheckForHelpRequest $@; then
    show_usage
fi

if opts_CheckForImplicitHelpRequest $@; then
    show_usage
fi

log_Msg "Parsing Command Line Options"

# Input Variables
PosInputImages=`opts_GetOpt1 "--posData" $@`   # "$1" #dataRL1@dataRL2@...dataRLN
NegInputImages=`opts_GetOpt1 "--negData" $@`   # "$2" #dataLR1@dataLR2@...dataLRN
StudyFolder=`opts_GetOpt1 "--path" $@`         # "$3" #Path to subject's data folder
Subject=`opts_GetOpt1 "--subject" $@`          # "$4" #SubjectID
echospacing=`opts_GetOpt1 "--echospacing" $@`  # "$5" #Echo Spacing in msecs
PEdir=`opts_GetOpt1 "--PEdir" $@`              # "$6" #1 for LR/RL, 2 for AP/PA
GdCoeffs=`opts_GetOpt1 "--gdcoeffs" $@`        # "${7}" #Select correct coeffs for scanner gradient nonlinearities or "NONE" to turn off
RUN=`opts_GetOpt1 "--printcom" $@`             # use ="echo" for just printing everything and not running the commands (default is to run)
RUN=${RUN:-''}

# Path for scripts etc (uses variables defined in SetUpHCPPipeline.sh)
scriptsdir=${HCPPIPEDIR_dMRI}
globalscriptsdir=${HCPPIPEDIR_Global}

# Build Paths 
outdir=${StudyFolder}/${Subject}/Diffusion
outdirT1w=${StudyFolder}/${Subject}/T1w/Diffusion
if [ -d ${outdir} ]; then
    ${RUN} rm -rf ${outdir}/rawdata
    ${RUN} rm -rf ${outdir}/topup
    ${RUN} rm -rf ${outdir}/eddy
    ${RUN} rm -rf ${outdir}/data
    ${RUN} rm -rf ${outdir}/reg
fi
${RUN} mkdir -p ${outdir}
${RUN} mkdir -p ${outdirT1w}

log_Msg "OutputDir is ${outdir}"
${RUN} mkdir ${outdir}/rawdata
${RUN} mkdir ${outdir}/topup
${RUN} mkdir ${outdir}/eddy
${RUN} mkdir ${outdir}/data
${RUN} mkdir ${outdir}/reg

if [ ${PEdir} -eq 1 ]; then    #RL/LR phase encoding
    basePos="RL"
    baseNeg="LR"
elif [ ${PEdir} -eq 2 ]; then  #AP/PA phase encoding
    basePos="AP"
    baseNeg="PA"
fi


########################################## DO WORK ###################################################################### 
log_Msg "Copying raw data"
#Copy RL/AP images to workingdir
PosInputImages=`echo ${PosInputImages} | sed 's/@/ /g'`
Pos_count=1
for Image in ${PosInputImages} ; do
	if [[ ${Image} =~ ^.*EMPTY.*$  ]]  ;  
	then
		Image=EMPTY
	fi
	
    if [ ${Image} = ${MissingFileFlag} ];
    then	
        PosVols[${Pos_count}]=0
    else
	PosVols[${Pos_count}]=`${FSLDIR}/bin/fslval ${Image} dim4`
	absname=`${FSLDIR}/bin/imglob ${Image}`
	${RUN} ${FSLDIR}/bin/imcp ${absname} ${outdir}/rawdata/${basePos}_${Pos_count}
	${RUN} cp ${absname}.bval ${outdir}/rawdata/${basePos}_${Pos_count}.bval
	${RUN} cp ${absname}.bvec ${outdir}/rawdata/${basePos}_${Pos_count}.bvec
    fi	
    Pos_count=$((${Pos_count} + 1))
done

#Copy LR/PA images to workingdir
NegInputImages=`echo ${NegInputImages} | sed 's/@/ /g'`
Neg_count=1
for Image in ${NegInputImages} ; do
	if [[ ${Image} =~ ^.*EMPTY.*$  ]]  ;  
	then
		Image=EMPTY
	fi
	
    if [ ${Image} = ${MissingFileFlag} ];
    then	
	NegVols[${Neg_count}]=0
    else
	NegVols[${Neg_count}]=`${FSLDIR}/bin/fslval ${Image} dim4`
	absname=`${FSLDIR}/bin/imglob ${Image}`
	${RUN} ${FSLDIR}/bin/imcp ${absname} ${outdir}/rawdata/${baseNeg}_${Neg_count}
	${RUN} cp ${absname}.bval ${outdir}/rawdata/${baseNeg}_${Neg_count}.bval
	${RUN} cp ${absname}.bvec ${outdir}/rawdata/${baseNeg}_${Neg_count}.bvec
    fi	
    Neg_count=$((${Neg_count} + 1))
done

if [ ${Pos_count} -ne ${Neg_count} ]; then
    log_Msg "Wrong number of input datasets! Make sure that you provide pairs of input filenames."
    log_Msg "If the respective file does not exist, use EMPTY in the input arguments."
    exit 1
fi

#Create two files for each phase encoding direction, that for each series contains the number of corresponding volumes and the number of actual volumes.
#The file e.g. RL_SeriesCorrespVolNum.txt will contain as many rows as non-EMPTY series. The entry M in row J indicates that volumes 0-M from RLseries J
#has corresponding LR pairs. This file is used in basic_preproc to generate topup/eddy indices and extract corresponding b0s for topup.
#The file e.g. Pos_SeriesVolNum.txt will have as many rows as maximum series pairs (even unmatched pairs). The entry M N in row J indicates that the RLSeries J has its 0-M volumes corresponding to LRSeries J and RLJ has N volumes in total. This file is used in eddy_combine.
log_Msg "Create two files for each phase encoding direction"
Paired_flag=0
for (( j=1; j<${Pos_count}; j++ )) ; do
    CorrVols=`min ${NegVols[${j}]} ${PosVols[${j}]}`
    ${RUN} echo ${CorrVols} ${PosVols[${j}]} >> ${outdir}/eddy/Pos_SeriesVolNum.txt
    if [ ${PosVols[${j}]} -ne 0 ]; then
	${RUN} echo ${CorrVols} >> ${outdir}/rawdata/${basePos}_SeriesCorrespVolNum.txt
	if [ ${CorrVols} -ne 0 ]; then
	    Paired_flag=1
	fi
    fi	
done
for (( j=1; j<${Neg_count}; j++ )) ; do
    CorrVols=`min ${NegVols[${j}]} ${PosVols[${j}]}`
    ${RUN} echo ${CorrVols} ${NegVols[${j}]} >> ${outdir}/eddy/Neg_SeriesVolNum.txt
    if [ ${NegVols[${j}]} -ne 0 ]; then
	${RUN} echo ${CorrVols} >> ${outdir}/rawdata/${baseNeg}_SeriesCorrespVolNum.txt
    fi	
done

if [ ${Paired_flag} -eq 0 ]; then
    log_Msg "Wrong Input! No pairs of phase encoding directions have been found!"
    log_Msg "At least one pair is needed!"
    exit 1
fi

log_Msg "Running Basic Preprocessing"
${RUN} ${scriptsdir}/basic_preproc.sh ${outdir} ${echospacing} ${PEdir} ${b0dist} ${b0maxbval}

log_Msg "Running Topup"
${RUN} ${scriptsdir}/run_topup.sh ${outdir}/topup

log_Msg "Running Eddy"
${RUN} ${scriptsdir}/run_eddy.sh ${outdir}/eddy

GdFlag=0
if [ ! ${GdCoeffs} = "NONE" ] ; then
    log_Msg "Gradient nonlinearity distortion correction coefficients found!"
    GdFlag=1
fi

log_Msg "Running Eddy PostProcessing"
${RUN} ${scriptsdir}/eddy_postproc.sh ${outdir} ${GdCoeffs}

#Naming Conventions
T1wFolder="${StudyFolder}/${Subject}/T1w" #Location of T1w images
T1wImage="${T1wFolder}/T1w_acpc_dc"
T1wRestoreImage="${T1wFolder}/T1w_acpc_dc_restore"
T1wRestoreImageBrain="${T1wFolder}/T1w_acpc_dc_restore_brain"
BiasField="${T1wFolder}/BiasField_acpc_dc"
FreeSurferBrainMask="${T1wFolder}/brainmask_fs"
RegOutput="${outdir}"/reg/"Scout2T1w"
QAImage="${outdir}"/reg/"T1wMulEPI"
DiffRes=`${FSLDIR}/bin/fslval ${outdir}/data/data pixdim1`
DiffRes=`printf "%0.2f" ${DiffRes}`

log_Msg "Running Diffusion to Structural Registration"
${RUN} ${scriptsdir}/DiffusionToStructural.sh \
  --t1folder="${T1wFolder}" \
  --subject="${Subject}" \
  --workingdir="${outdir}/reg" \
  --datadiffdir="${outdir}/data" \
  --t1="${T1wImage}" \
  --t1restore="${T1wRestoreImage}" \
  --t1restorebrain="${T1wRestoreImageBrain}" \
  --biasfield="${BiasField}" \
  --brainmask="${FreeSurferBrainMask}" \
  --datadiffT1wdir="${outdirT1w}" \
  --regoutput="${RegOutput}" \
  --QAimage="${QAImage}" \
  --gdflag=${GdFlag} --diffresol=${DiffRes}

log_Msg "Completed"


