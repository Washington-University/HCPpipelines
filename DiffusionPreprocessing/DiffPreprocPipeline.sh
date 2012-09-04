#!/bin/bash

# Preprocessing Pipeline for diffusion MRI. Generates the "data" directory that can be used as input to the fibre orientation estimation script.
# Stamatios Sotiropoulos, Analysis Group, FMRIB Centre, 2012.
 

#Hard-Coded variables for the pipeline
b0dist=50     #Minimum distance in volumes between considered b0s for preprocessing
b0maxbval=50  #Volumes with a bvalue smaller than that will be considered as b0s


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


Usage() {
    echo ""
    echo "Usage: DiffPreprocPipeline dataLR1@dataLR2@dataRL1@dataRL2 StudyFolder SubjectId EchoSpacing PhaseEncodingDir QCseries LocalScriptsDir GlobalScriptsDir"
    echo ""
    echo "Input filenames should include absolute paths"
    echo "Working and Output durectory will be {StudyFolder}/{SubjectId}/Diffusion"
    echo "EchoSpacing should be in msecs"
    echo "PhaseEncodingDir: 1 for LR/RL, 2 for AP/PA"
    echo "QCseries is a text file containing the number of successfully acquired directions for each series"
    echo ""
    echo ""
    echo ""
    exit 1
}

[ "$1" = "" ] && Usage
if [ $# -ne 8 ]; then
    echo "Wrong Number of Arguments!"
    Usage
fi

StudyFolder=`make_absolute $2`
StudyFolder=`echo ${StudyFolder} | sed 's/\/$/$/g'`
echospacing=$4
PEdir=$5

#ErrorHandling
if [ ${PEdir} -ne 1 ] && [ ${PEdir} -ne 2 ]; then
    echo ""
    echo "Wrong Input Argument! PhaseEncodingDir flag can be 1 or 2."
    echo ""
    exit 1
fi
 
outdir=${StudyFolder}/$3/Diffusion
if [ -d ${outdir} ]; then
    rm -r ${outdir}
fi
mkdir -p ${outdir}
echo OutputDir is ${outdir}
mkdir ${outdir}/rawdata
mkdir ${outdir}/topup
mkdir ${outdir}/eddy
mkdir ${outdir}/data

echospacing=$4
PEdir=$5
scriptsdir=$7
globalscriptsdir=$8

InputImages=$1 
InputImages=`echo ${InputImages} | sed 's/@/ /g'`

echo "Copying raw data"
for Image in ${InputImages} ; do
    absname=`${FSLDIR}/bin/imglob ${Image}`
    ${FSLDIR}/bin/imcp ${absname} ${outdir}/rawdata
    cp ${absname}.bval ${outdir}/rawdata
    cp ${absname}.bvec ${outdir}/rawdata
done
####################################################################################################
#Need to make sure that the rawdir will contain LR1,LR2,RL1,RL2 (or AP/PA). Rename the input files! 
####################################################################################################



echo "Running Basic Preprocessing"
${scriptsdir}/basic_preproc.sh ${outdir} ${echospacing} ${PEdir} ${b0dist} ${b0maxbval}

echo "Running Topup"
${scriptsdir}/run_topup.sh ${outdir}/topup ${globalscriptsdir}

echo "Running Eddy"
${scriptsdir}/run_eddy.sh ${outdir}/eddy

echo "Running Eddy PostProcessing"
${scriptsdir}/eddy_postproc.sh ${outdir} ${globalscriptsdir} 