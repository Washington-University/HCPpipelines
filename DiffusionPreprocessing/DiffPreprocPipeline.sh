#!/bin/bash
set -e

# Preprocessing Pipeline for diffusion MRI. Generates the "data" directory that can be used as input to the fibre orientation estimation script.
# Stamatios Sotiropoulos, Saad Jbabdi, Jesper Andersson, Analysis Group, FMRIB Centre, 2012.
# Matt Glasser, Washington University, 2012.
 

#Hard-Coded variables for the pipeline
b0dist=45     #Minimum distance in volumes between b0s considered for preprocessing
b0maxbval=50  #Volumes with a bvalue smaller than that will be considered as b0s
MissingFileFlag="EMPTY" #String used in the input arguments to indicate that a complete series is missing

make_absolute(){
    dir=$1;
    if [ -d ${dir} ]; then
	OLDWD=`pwd`
	cd ${dir}
	dir_all=`pwd`
	cd $OLDWD
    else
	dir_all=${dir}
    fi
    echo ${dir_all}
}


min(){
  if [ $1 -le $2 ]; then
     echo $1
  else
     echo $2
  fi
}


Usage() {
    echo ""
    echo "Usage: DiffPreprocPipeline dataLR1@dataLR2@..dataLRN dataRL1@dataRL2@...dataRLN StudyFolder SubjectId EchoSpacing PhaseEncodingDir LocalScriptsDir GlobalBinaryDir GlobalConfigDir GlobalScriptsDir"
    echo ""
    echo "Input filenames should include absolute paths. If for a LR/RL (AP/PA) pair one of the two files are missing set the entry to EMPTY"
    echo "Working and Output durectory will be {StudyFolder}/{SubjectId}/Diffusion"
    echo "EchoSpacing should be in msecs"
    echo "PhaseEncodingDir: 1 for LR/RL, 2 for AP/PA"
    echo "LocalScriptsDir : Absolute path for local scripts, e.g. ${Pipelines}/DiffusionPreprocessing/scripts"
	echo "GlobalBinaryDir : Absolute path for global binaries not part of software release, e.g. ${Pipelines}/global/binaries"
	echo "GlobalConfigDir : Absolute path for global configuration files, e.g. ${Pipelines}/global/config"
    echo "GlobalScriptsDir: Absolute path for global directory of scripts, e.g. ${Pipelines}/global/scripts" 
    echo ""
    echo ""
    echo ""
    exit 1
}

[ "$1" = "" ] && Usage
if [ $# -ne 10 ]; then
    echo "Wrong Number of Arguments!"
    Usage
fi

StudyFolder=`make_absolute $3`
StudyFolder=`echo ${StudyFolder} | sed 's/\/$/$/g'`
Subject="$4"
echospacing=$5
PEdir=$6
scriptsdir=$7
binarydir=$8
configdir=$9
globalscriptsdir="${10}"

#ErrorHandling
if [ ${PEdir} -ne 1 ] && [ ${PEdir} -ne 2 ]; then
    echo ""
    echo "Wrong Input Argument! PhaseEncodingDir flag can be 1 or 2."
    echo ""
    exit 1
fi
 
outdir=${StudyFolder}/$4/Diffusion
if [ -d ${outdir} ]; then
    rm -rf ${outdir}
fi
mkdir -p ${outdir}
echo OutputDir is ${outdir}
mkdir ${outdir}/rawdata
mkdir ${outdir}/topup
mkdir ${outdir}/eddy
mkdir ${outdir}/data
mkdir ${outdir}/reg

if [ ${PEdir} -eq 1 ]; then    #RL/LR phase encoding
    basePos="RL"
    baseNeg="LR"
elif [ ${PEdir} -eq 2 ]; then  #AP/PA phase encoding
    basePos="AP"
    baseNeg="PA"
fi

echo "Copying raw data"
#Copy RL/AP images to workingdir
InputImages=`echo "$2"` 
InputImages=`echo ${InputImages} | sed 's/@/ /g'`
Pos_count=1
for Image in ${InputImages} ; do
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
	${FSLDIR}/bin/imcp ${absname} ${outdir}/rawdata/${basePos}_${Pos_count}
	cp ${absname}.bval ${outdir}/rawdata/${basePos}_${Pos_count}.bval
	cp ${absname}.bvec ${outdir}/rawdata/${basePos}_${Pos_count}.bvec
    fi	
    Pos_count=$((${Pos_count} + 1))
done

#Copy LR/PA images to workingdir
InputImages=`echo "$1"` 
InputImages=`echo ${InputImages} | sed 's/@/ /g'`
Neg_count=1
for Image in ${InputImages} ; do
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
	${FSLDIR}/bin/imcp ${absname} ${outdir}/rawdata/${baseNeg}_${Neg_count}
	cp ${absname}.bval ${outdir}/rawdata/${baseNeg}_${Neg_count}.bval
	cp ${absname}.bvec ${outdir}/rawdata/${baseNeg}_${Neg_count}.bvec
    fi	
    Neg_count=$((${Neg_count} + 1))
done

if [ ${Pos_count} -ne ${Neg_count} ]; then
    echo "Wrong number of input datasets! Make sure that you provide pairs of input filenames."
    echo "If the respective file does not exist, use EMPTY in the input arguments."
    exit 1
fi

#Create two files for each phase encoding direction, that for each series contains the number of corresponding volumes and the number of actual volumes.
#The file e.g. RL_SeriesCorrespVolNum.txt will contain as many rows as non-EMPTY series. The entry M in row J indicates that volumes 0-M from RLseries J
#has corresponding LR pairs. This file is used in basic_preproc to generate topup/eddy indices and extract corresponding b0s for topup.
#The file e.g. Pos_SeriesVolNum.txt will have as many rows as maximum series pairs (even unmatched pairs). The entry M N in row J indicates that the RLSeries J has its 0-M volumes corresponding to LRSeries J and RLJ has N volumes in total. This file is used in eddy_combine.
Paired_flag=0
for (( j=1; j<${Pos_count}; j++ )) ; do
    CorrVols=`min ${NegVols[${j}]} ${PosVols[${j}]}`
    echo ${CorrVols} ${PosVols[${j}]} >> ${outdir}/eddy/Pos_SeriesVolNum.txt
    if [ ${PosVols[${j}]} -ne 0 ]; then
	echo ${CorrVols} >> ${outdir}/rawdata/${basePos}_SeriesCorrespVolNum.txt
	if [ ${CorrVols} -ne 0 ]; then
	    Paired_flag=1
	fi
    fi	
done
for (( j=1; j<${Neg_count}; j++ )) ; do
    CorrVols=`min ${NegVols[${j}]} ${PosVols[${j}]}`
    echo ${CorrVols} ${NegVols[${j}]} >> ${outdir}/eddy/Neg_SeriesVolNum.txt
    if [ ${NegVols[${j}]} -ne 0 ]; then
	echo ${CorrVols} >> ${outdir}/rawdata/${baseNeg}_SeriesCorrespVolNum.txt
    fi	
done

if [ ${Paired_flag} -eq 0 ]; then
    echo "Wrong Input! No pairs of phase encoding directions have been found!"
    echo "At least one pair is needed!"
    exit 1
fi

echo "Running Basic Preprocessing"
${scriptsdir}/basic_preproc.sh ${outdir} ${echospacing} ${PEdir} ${b0dist} ${b0maxbval}

echo "Running Topup"
${scriptsdir}/run_topup.sh ${outdir}/topup ${binarydir} ${configdir}

echo "Running Eddy"
${scriptsdir}/run_eddy.sh ${outdir}/eddy ${binarydir}

echo "Running Eddy PostProcessing"
${scriptsdir}/eddy_postproc.sh ${outdir} ${binarydir} ${configdir}

#Naming Conventions
T1wImage="T1w_acpc_dc"
T1wRestoreImage="T1w_acpc_dc_restore"
T1wRestoreImageBrain="T1w_acpc_dc_restore_brain"
T1wFolder="${StudyFolder}/${Subject}/T1w" #Location of T1w images
AtlasSpaceFolder="${StudyFolder}/${Subject}/MNINonLinear"
BiasField="BiasField_acpc_dc"
FreeSurferBrainMask="brainmask_fs"
RegOutput="Scout2T1w"
AtlasTransform="acpc_dc2standard"
QAImage="T1wMulEPI"
xfmsFolder="xfms"
OutputTransform="diff2str.mat"
OutputInvTransform="str2diff.mat"
OutputAtlasTransform="diff2standard"
OutputInvAtlasTransform="standard2diff"
OutputBrainMask="nodif_brain_mask"

echo "Running Diffusion to Structural Registration"
${scriptsdir}/DiffusionToStructural.sh \
${outdir}/reg \
${outdir}/data/data.nii.gz \
"$T1wFolder"/"$T1wImage" \
"$T1wFolder"/"$T1wRestoreImage" \
"$T1wFolder"/"$T1wRestoreImageBrain" \
"$AtlasSpaceFolder"/"$xfmsFolder"/"$AtlasTransform" \
"$T1wFolder"/xfms/"$OutputTransform" \
"$T1wFolder"/xfms/"$OutputInvTransform" \
"$AtlasSpaceFolder"/"$xfmsFolder"/"$OutputAtlasTransform" \
"$AtlasSpaceFolder"/"$xfmsFolder"/"$OutputInvAtlasTransform" \
"$T1wFolder"/"$BiasField" \
"$T1wFolder" \
"$Subject" \
"${outdir}"/reg/"$RegOutput" \
"${outdir}"/reg/"$QAImage" \
"$T1wFolder"/"$FreeSurferBrainMask" \
"${outdir}"/data/"$OutputBrainMask" \
${globalscriptsdir} 



