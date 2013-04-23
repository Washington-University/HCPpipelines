#!/bin/bash
usage() {
  echo "Usage: `basename $0` <Level2_fsf_file>"
  echo "   Prepares lower-level .feat directories for higher-level analyses"
  echo
}

if [ "X${1/*fsf*/match}" == "Xmatch" ]; then
	# Resolve absolute path so we can find Lev1 feat directories later
	fsfname=`echo $(cd $(dirname $1); pwd)/$(basename $1)`;
    shift
else
    usage
    exit -1
fi

# set other variables
fsfdir=`dirname "$fsfname"`;
# fsfname should be form "tfMRI_${task}_hp200_s4"
task=`echo $fsfname | sed -e "s|.*tfMRI_||" -e "s|_hp200_s4.*||"`
RLfeat="${fsfdir}/../tfMRI_${task}_RL/tfMRI_${task}_RL_hp200_s4.feat"
LRfeat="${fsfdir}/../tfMRI_${task}_LR/tfMRI_${task}_LR_hp200_s4.feat"


# find location of Lev 2 fsf file (because .feat directories should be relative to that location)
if [ ! -e $fsfname ] ; then
  usage 
  echo " "
  echo "A valid Level 2 fsf file must be provided"
  echo "$fsfname does not exist"
  exit -1
fi

numFeat=0;
# find task RL feat run 
if [ ! -d $RLfeat ] ; then
	echo "Cannot find $RLfeat"
else
	((numFeat++))
fi

# find task LR feat run
if [ ! -d $LRfeat ] ; then
	echo "Cannot find $LRfeat"
else
	((numFeat++))
fi

if [ $numFeat -eq 0 ]; then
	echo "Cannot find any lower-level .feat directories!!!"
	echo "Please run $0 from directory containing the Level2 fsf file"
	echo " "
	usage;
	exit -1
fi

for feat in $RLfeat $LRfeat; do
	# make reg directory
	mkdir -m 775 $feat/reg
	# ln -s necessary files into reg directory
	ln -s $FSLDIR/etc/flirtsch/ident.mat $feat/reg/example_func2standard.mat
	ln -s $FSLDIR/etc/flirtsch/ident.mat $feat/reg/standard2example_func.mat
	ln -s $FSLDIR/data/standard/MNI152_T1_2mm.nii.gz $feat/reg/standard.nii.gz
done

# provide user with message regarding next step
# if only one feat run was found, state that they should run feat analysis on other run, 
	# or not run Lev 2 feat
# if both feat runs were found, tell user how to run feat analysis on Lev2 fsf from that directory
echo "The following directories have been prepared for Level2 feat analysis"
for feat in $RLfeat $LRfeat; do
	if [ -d $feat ] ; then
		echo "$feat"
	fi
done


if [ $numFeat -ne 2 ] ; then
	echo "You should not run Level 2 feat analyses for this participant, because only $numFeat .feat directories are present";
else
	echo "Be certain to cd into `dirname $fsfname` before running feat `basename $fsfname`";
fi
echo 

exit 0;

