#!/bin/bash 
set -e

# Requirements for this script
#  installed versions of: FSL5.0.1 or higher
#  environment: FSLDIR

################################################ SUPPORT FUNCTIONS ##################################################

Usage() {
  echo "`basename $0`: Script for using topup to perform distortion correction and averaging"
  echo " "
  echo "Usage: `basename $0` <working dir> \"<input images>\" <output image> <topup config file>"
  echo "                 (assumes two input images in a double quoted list, an up/down pair)"
}

# function for parsing options
getopt1() {
    sopt="$1"
    shift 1
    for fn in $@ ; do
	if [ `echo $fn | grep -- "^${sopt}=" | wc -w` -gt 0 ] ; then
	    echo $fn | sed "s/^${sopt}=//"
	    return 0
	fi
    done
}

################################################### OUTPUT FILES #####################################################

# Outputs (in $WD): up  down  imain  topupfield  rdc_avg
# Outputs (not in $WD): ${OutputFile}

################################################## OPTION PARSING #####################################################

# Just give usage if no arguments specified
if [ $# -eq 0 ] ; then Usage; exit 0; fi
# check for correct options
if [ $# -lt 3 ] ; then Usage; exit 1; fi

# parse arguments  (NB: cannot use nice parsing as the second argument is a double quoted string that is a list of images separated by spaces!)
WD="$1"
InputFiles="$2"
OutputFile="$3"
TopupConfig="$4"

echo " "
echo " START: TopupDistortionCorrectAndAverage"

mkdir -p $WD

# Record the input options in a log file
echo "$0 $@" >> $WD/log.txt
echo "PWD = `pwd`" >> $WD/log.txt
echo "date: `date`" >> $WD/log.txt
echo " " >> $WD/log.txt

########################################## DO WORK ########################################## 


#HACK FOR TOPUP NOT ACCEPTING z-direction distortion correction
echo "0 1 0 1" > ${WD}/topupdatain.txt
echo "0 -1 0 1" >> ${WD}/topupdatain.txt
Files=""
i="1"
Directions="up dn"
for File in $InputFiles ; do
  Direction=`echo $Directions | cut -d " " -f $i`
  ${FSLDIR}/bin/fslswapdim ${File}.nii.gz -x z y ${WD}/${Direction}.nii.gz
  Files="${Files}${WD}/${Direction}.nii.gz "
  i=$(($i+1))
done

${FSLDIR}/bin/fslmerge -t ${WD}/imain $Files

${FSLDIR}/bin/topup --verbose --imain=${WD}/imain --datain=${WD}/topupdatain.txt --config=${TopupConfig} --out=${WD}/topupfield

FileList=`echo $Files | sed 's/ /,/g'`
${FSLDIR}/bin/applytopup --imain=${FileList} --datain=${WD}/topupdatain.txt --topup=${WD}/topupfield --inindex=1,2 --method=lsr --out=${WD}/rdc_avg

#More HACK
${FSLDIR}/bin/fslswapdim ${WD}/rdc_avg -x z y ${OutputFile}

echo " "
echo " END: TopDistortionCorrectAndAverage"
echo " END: `date`" >> $WD/log.txt

########################################## QA STUFF ########################################## 

if [ -e $WD/qa.txt ] ; then rm -f $WD/qa.txt ; fi
echo "cd `pwd`" >> $WD/qa.txt
echo "# Compare images before and after distortion correction" >> $WD/qa.txt
echo "fslview ${InputFiles} ${OutputFile}" >> $WD/qa.txt

##############################################################################################
