#!/bin/bash
set -e

# Requirements for this script
#  installed versions of: FSL6.0.4 or higher , FreeSurfer (version 6.0.0 or higher) ,
#  environment: FSLDIR , FREESURFER_HOME , HCPPIPEDIR , CARET7DIR

# make pipeline engine happy...
if [ $# -eq 1 ] ; then
    echo "Version unknown..."
    exit 0
fi

########################################## PIPELINE OVERVIEW ##########################################

#TODO

########################################## OUTPUT DIRECTORIES ##########################################

#TODO

# --------------------------------------------------------------------------------
#  Load Function Libraries
# --------------------------------------------------------------------------------
defaultopt() {
    echo $1
}

source $HCPPIPEDIR/global/scripts/log.shlib  # Logging related functions
source $HCPPIPEDIR/global/scripts/opts.shlib # Command line option functions

########################################## SUPPORT FUNCTIONS ##########################################

# --------------------------------------------------------------------------------
#  Usage Description Function
# --------------------------------------------------------------------------------

show_usage() {
    echo "Usage information To Be Written"
    exit 1
}

# --------------------------------------------------------------------------------
#   Establish tool name for logging
# --------------------------------------------------------------------------------
log_SetToolName "FreeSurferPipeline.sh"

################################################## OPTION PARSING #####################################################

opts_ShowVersionIfRequested $@

if opts_CheckForHelpRequest $@; then
    show_usage
fi

log_Msg "Start FreeSurferPipeline.sh"

log_Msg "Parsing Command Line Options"

# Input Variables
SubjectID=`opts_GetOpt1 "--subject" $@` #FreeSurfer Subject ID Name
SubjectDIR=`opts_GetOpt1 "--subjectDIR" $@` #Location to Put FreeSurfer Subject's Folder
T1wImage=$(remove_ext `opts_GetOpt1 "--t1" $@`) #T1w FreeSurfer Input for head (Full Resolution)
T1wImageBrain=$(remove_ext `opts_GetOpt1 "--t1brain" $@`) #T1w FreeSurfer Input for brain (Full Resolution)
T2wImage=$(remove_ext `opts_GetOpt1 "--t2" $@`) #T2w FreeSurfer Input for brain (Full Resolution)
recon_all_seed=`opts_GetOpt1 "--seed" $@`

#FSLinearTransform=`opts_GetOpt1 "--fslinear" $@`
GCAdir=`opts_GetOpt1 "--gcadir" $@` # Needed for NHP
#RescaleVolumeTransform=`opts_GetOpt1 "--rescaletrans" $@` # Not needed anymore - TH Feb 2023
AsegEdit=`opts_GetOpt1 "--asegedit" $@` # Needed to use aseg.edit.mgz
ControlPoints=`opts_GetOpt1 "--controlpoints" $@` # Needed to use $SubjectID/tmp/control.dat -TH Nov 2017
WmEdit=`opts_GetOpt1 "--wmedit" $@` # Needed to use wm.edit.mgz, - TH Nov 4th 2015
T2wType=`opts_GetOpt1 "--t2wtype" $@` # T2w, FLAIR or NONE for FreeSurferHiresPial.sh -TH Nov 4th 2015
SPECIES=`opts_GetOpt1 "--species" $@` # Human, Chimp, Macaque, Marmoset, NightMonkey - TH 2016-2023
IntensityCor=`opts_GetOpt1 "--intensitycor" $@` # NU (default for Human) or FAST (default for NHP) or ANTS - Methods for intensity correction TH Aug 2019
BrainMasking=`opts_GetOpt1 "--brainmasking" $@` # FS (default for Human) or HCP (default for NHP) - Methods for brain masking TH Aug 2019
RunMode=`opts_GetOpt1 "--runmode" $@`  # Run in step mode (1: FSinit and later (default), 2: Normalize1 and later, 3: Brainmask Edit and later, 4: Aseg Edit and later, 5: WMLesion and Control dat and later, 6: WM edit and later, 7: SurfReg, 8: FS pial)


# default parameters
SPECIES=`defaultopt $SPECIES Human`

# ------------------------------------------------------------------------------
# Species-specific values
# ------------------------------------------------------------------------------
# CurvStats		: mris_curvature_stats, required in human not in NHP
# AvgCurv 		: mrisp_paint, average curvature, required in human not in NHP
# initcc             : mri_fill, the default init value of mid corpus callosum (cc) for human (0 0 27).
#                      The values for NHP must be read by viewing GCA atlas and locating mid cc by freeview - Akiko Uematsu, Feb 2023
# dist		       : mris_register, distance term. Default is 5. Marmoset should  be 20  - TH Feb 2016
# max_degrees  	: mris_register, max angle. Default is 68. Marmoset should be 50  - TH Feb 2016
# MaxThickness       : FSHighresPial, MaxThickness needs to be also set for each species.
# VariableSigma      : FSHighresPial, Variable sigma needs to be set larger value for inflate pial enough.
# GreySigma          : FSHighresPial, Sigma controls smoothness of within grey matter tissue contrast field being removed. Use smaller spatial frequency (sigma) of myelin distribution in marmoset 

if [[ "$SPECIES" =~ "Human" ]] ; then 
	ScaleFactor=1.0
	initcc="127 120 145"  # voxel coordinate corresponding to 0 0 27 in Talairach space (mm) 
	GCAdir="${FREESURFER_HOME}/average"
	CurvStats="-curvstats"
	AvgCurv="-avgcurv"
	MaxThickness="6"
	VariableSigma="8"
	GreySigma="5" #in mm
	BiasFieldFastSmoothingSigma=20
	BiasFieldAntsSplineSpace=200
	IntensityCor=${IntensityCor:-NU}
elif [[ $SPECIES =~ Chimp ]] ; then
	ScaleFactor=1.25
	initcc="0 -8 21"
	MaxThickness="6"
	VariableSigma="8"
	GreySigma="5" #in mm
	BiasFieldFastSmoothingSigma=25  # = 20*$ScaleFactor
	BiasFieldAntsSplineSpace=250
	IntensityCor=${IntensityCor:-FAST}
elif [[ $SPECIES =~ Macaque ]] ; then 
	ScaleFactor=2
	initcc="128 98 124" # voxel coordinate in orig.mgz and wm.mgz
	MaxThickness="5"
	VariableSigma="8"
	GreySigma="5" #in mm 
	BiasFieldFastSmoothingSigma=20  # 8> 10 >> 40 for white of A16101401, 20 is the best among 5,10,20,40 for white of A21051401
	BiasFieldAntsSplineSpace=400
	IntensityCor=${IntensityCor:-FAST}
elif [[ $SPECIES =~ NightMonkey ]] ; then
	ScaleFactor=4
	initcc="0 -12 24"
	MaxThickness="4"
	VariableSigma="12"
	GreySigma="5" #in mm
	BiasFieldFastSmoothingSigma=8
	BiasFieldAntsSplineSpace=400
	IntensityCor=${IntensityCor:-FAST}
elif [[ $SPECIES =~ Marmoset ]] ; then
	ScaleFactor=5
	initcc="126 106 122"	
	dist="-dist 20";
	maxdegree="-max_degrees 40";
	MaxThickness="3"
	VariableSigma="10"
	GreySigma="1" #in mm
	BiasFieldFastSmoothingSigma=4
	BiasFieldAntsSplineSpace=500
	IntensityCor=${IntensityCor:-FAST}
fi

if [[ ! -z $initcc ]] ; then
	cccrs="-cc-crs $initcc"
fi

# ------------------------------------------------------------------------------
#  Show Command Line Options
# ------------------------------------------------------------------------------

log_Msg "Finished Parsing Command Line Options"
log_Msg "SubjectID: ${SubjectID}"
log_Msg "SubjectDIR: ${SubjectDIR}"
log_Msg "SPECIES: ${SPECIES}"
log_Msg "T1wImage: ${T1wImage}"
log_Msg "T1wImageBrain: ${T1wImageBrain}"
log_Msg "T2wImage: ${T2wImage}"
log_Msg "recon_all_seed: ${recon_all_seed}"
log_Msg "GCAdir: ${GCAdir}"
log_Msg "AsegEdit: ${AsegEdit}"
log_Msg "ControlPoints: ${ControlPoints}"
log_Msg "WmEdit: ${WmEdit}"
log_Msg "T2wType: ${T2wType}"
log_Msg "IntensityCor method: ${IntensityCor}"
log_Msg "Brain masking method: ${BrainMasking}"
log_Msg "RunMode: ${RunMode}"

# figure out whether to include a random seed generator seed in all the recon-all command lines
seed_cmd_appendix=""
if [ -z "${recon_all_seed}" ] ; then
	seed_cmd_appendix=""
else
	seed_cmd_appendix="-norandomness -rng-seed ${recon_all_seed}"
fi
log_Msg "seed_cmd_appendix: ${seed_cmd_appendix}"

# ------------------------------------------------------------------------------
#  Show Environment Variables
# ------------------------------------------------------------------------------

log_Msg "HCPPIPEDIR: ${HCPPIPEDIR}"
log_Msg "HCPPIPEDIR_FS: ${HCPPIPEDIR_FS}"
log_Msg "FREESURFER_HOME: ${FREESURFER_HOME}"

# ------------------------------------------------------------------------------
#  Identify Tools
# ------------------------------------------------------------------------------

which_flirt=`which flirt`
flirt_version=`flirt -version`
log_Msg "which flirt: ${which_flirt}"
log_Msg "flirt -version: ${flirt_version}"

which_applywarp=`which applywarp`
log_Msg "which applywarp: ${which_applywarp}"

which_fslstats=`which fslstats`
log_Msg "which fslstats: ${which_fslstats}"

which_fslmaths=`which fslmaths`
log_Msg "which fslmaths: ${which_fslmaths}"

which_recon_all=`which ${FREESURFER_HOME}/bin/recon-all`
recon_all_version=`${FREESURFER_HOME}/bin/recon-all --version`
log_Msg "which recon-all: ${which_recon_all}"
log_Msg "recon-all --version: ${recon_all_version}"

ReconAll="${FREESURFER_HOME}/bin/recon-all"

which_mri_convert=`which mri_convert`
log_Msg "which mri_convert: ${which_mri_convert}"

which_mri_em_register=`which mri_em_register`
mri_em_register_version=`mri_em_register --version`
log_Msg "which mri_em_register: ${which_mri_em_register}"
log_Msg "mri_em_register --version: ${mri_em_register_version}"

which_mri_watershed=`which mri_watershed`
mri_watershed_version=`mri_watershed --version`
log_Msg "which mri_watershed: ${which_mri_watershed}"
log_Msg "mri_watershed --version: ${mri_watershed_version}"

# Start work

PipelineScripts=${HCPPIPEDIR_FS}

export SUBJECTS_DIR="$SubjectDIR"

if [ -e "$SubjectDIR"/"$SubjectID"/scripts/IsRunning.lh+rh ] ; then
  rm "$SubjectDIR"/"$SubjectID"/scripts/IsRunning.lh+rh
elif [ -e "$SubjectDIR"/"$SubjectID"_1mm/scripts/IsRunning.lh+rh ] ; then
  rm "$SubjectDIR"/"$SubjectID"_1mm/scripts/IsRunning.lh+rh
fi

# Both the SGE and PBS cluster schedulers use the environment variable NSLOTS to indicate the number of cores
# a job will use.  If this environment variable is set, we will use it to determine the number of cores to
# tell recon-all to use.

NSLOTS=8

if [[ -z ${NSLOTS} ]] ; then
	num_cores=8
else
	num_cores="${NSLOTS}"
fi
log_Msg "num_cores: ${num_cores}"

function runFSinit () {

	log_Msg "Scale T1w volume and normalize resolution"
	"$PipelineScripts"/ScaleVolume.sh -i "$T1wImage" -s "$ScaleFactor" -o "$T1wImage"_1mm --omat="$SubjectDIR"/xfms/real2fs

	log_Msg "Scale T1w brain volume and normalize resolution"
	"$PipelineScripts"/ScaleVolume.sh -i "$T1wImageBrain" -s "$ScaleFactor" -o "$T1wImageBrain"_1mm --interp=ENCLOSING_VOXEL

	if [[ ! $T2wImage =~ NONE ]] ; then
		log_Msg "Scale T2w volume and normalized resolution"
		"$PipelineScripts"/ScaleVolume.sh -i "$T2wImage" -s "$ScaleFactor" -o "$T2wImage"_1mm
	fi
	Mean=`fslstats $T1wImageBrain -M`
	fslmaths "$T1wImage"_1mm.nii.gz -div $Mean -mul 150 -abs "$T1wImage"_1mm.nii.gz

	#Initial Recon-all Steps
	if [ -e "$SubjectDIR"/"$SubjectID" ] ; then
		log_Msg "Removing previous FS directory"
 		rm -rf "$SubjectDIR"/"$SubjectID"
	fi
	if [ -e "$SubjectDIR"/"$SubjectID"_1mm ] ; then
		log_Msg "Removing previous FS 1mm directory"
		rm -rf "$SubjectDIR"/"$SubjectID"_1mm
	fi

	log_Msg "Initial recon-all steps"

	${ReconAll} -i "$T1wImage"_1mm.nii.gz -subjid $SubjectID -sd $SubjectDIR -motioncor -openmp ${num_cores} ${seed_cmd_appendix}
	fslmaths "$T1wImageBrain"_1mm.nii.gz -thr 0 -add 1 "$SubjectDIR"/"$SubjectID"/mri/brainmask.orig.nii.gz
	mri_convert "$SubjectDIR"/"$SubjectID"/mri/brainmask.orig.nii.gz "$SubjectDIR"/"$SubjectID"/mri/brainmask.conf.mgz --conform

}

function runNormalize1 () {

	# Intensity bias correction
	if [[ "$IntensityCor" = "FAST" || "$IntensityCor" = "ANTS" ]] ; then
		if [ "$IntensityCor" = "FAST" ] ; then
			BiasFieldSmoothing="$BiasFieldFastSmoothingSigma"
		else
			BiasFieldSmoothing="$BiasFieldAntsSplineSpace"
		fi
		# Use FAST or ANTS for biasfield correction
		log_Msg "Intensity correction using $IntensityCor with a smoothing level: $BiasFieldSmoothing"
	 	"$PipelineScripts"/IntensityCor.sh "$SubjectDIR"/"$SubjectID"/mri/orig.mgz "$SubjectDIR"/"$SubjectID"/mri/brainmask.conf.mgz \
		"$SubjectDIR"/"$SubjectID"/mri/nu.mgz -t1 -m "$IntensityCor" "$BiasFieldSmoothing"
		log_Msg "Second recon-all steps for normaliztion 1"
		${ReconAll} -subjid $SubjectID -sd $SubjectDIR -normalization -openmp ${num_cores} ${seed_cmd_appendix}

	else
		# Call recon-all with flags that are part of "-autorecon1", with the exception of -skullstrip.
		# -skullstrip of FreeSurfer not reliable for Phase II data because of poor FreeSurfer mri_em_register registrations with Skull on,
		# so run registration with PreFreeSurfer masked data and then generate brain mask as usual.
		log_Msg "Second recon-all steps for normaliztion 1"
		${ReconAll} -subjid $SubjectID -sd $SubjectDIR -talairach -nuintensitycor -normalization -openmp ${num_cores} ${seed_cmd_appendix}
	fi

}

function runFSbrainmaskandseg () {

	# Generate brain mask
	export OMP_NUM_THREADS=${num_cores}

	if  [ -e "$SubjectDIR"/"$SubjectID"/mri/brainmask.edit.mgz ] ; then
		mri_mask "$SubjectDIR"/"$SubjectID"/mri/nu.mgz "$SubjectDIR"/"$SubjectID"/mri/brainmask.edit.mgz "$SubjectDIR"/"$SubjectID"/mri/brainmask.mgz
	elif [ "$BrainMasking" = "FS" ] ; then
		# recon -skullstrip
		mri_em_register "$SubjectDIR"/"$SubjectID"/mri/nu.mgz "$GCAdir"/RB_all_withskull_2008-03-26.gca \
		"$SubjectDIR"/"$SubjectID"/mri/transforms/talairach_with_skull.lta
		mri_watershed -T1 -brain_atlas "$GCAdir"/RB_all_withskull_2008-03-26.gca \
		"$SubjectDIR"/"$SubjectID"/mri/transforms/talairach_with_skull.lta "$SubjectDIR"/"$SubjectID"/mri/T1.mgz \
		"$SubjectDIR"/"$SubjectID"/mri/brainmask.auto.mgz
		cp "$SubjectDIR"/"$SubjectID"/mri/brainmask.auto.mgz "$SubjectDIR"/"$SubjectID"/mri/brainmask.mgz
	elif [ "$BrainMasking" = "HCP" ] ; then
		mri_mask "$SubjectDIR"/"$SubjectID"/mri/nu.mgz "$SubjectDIR"/"$SubjectID"/mri/brainmask.conf.mgz "$SubjectDIR"/"$SubjectID"/mri/brainmask.mgz
	else
		mri_mask "$SubjectDIR"/"$SubjectID"/mri/nu.mgz "$SubjectDIR"/"$SubjectID"/mri/brainmask.conf.mgz "$SubjectDIR"/"$SubjectID"/mri/brainmask.mgz
	fi


	# Registration and normalization with GCA
	log_Msg "Third recon-all steps for registration and normaliztion to GCA"
	${ReconAll} -subjid $SubjectID -sd $SubjectDIR -gcareg -canorm -careg -calabel -gca-dir $GCAdir
	cp "$SubjectDIR"/"$SubjectID"/mri/norm.mgz "$SubjectDIR"/"$SubjectID"/mri/norm.orig.mgz

}

function runFSnoCC () {

	if [ "$AsegEdit" != "NONE" ] ; then
		i="+"
		while [ -e "$SubjectDIR"/"$SubjectID"/mri/aseg.auto_noCCseg.mgz ] ; do
			if [ ! -e "$SubjectDIR"/"$SubjectID"/mri/aseg.auto_noCCseg${i}.mgz ] ; then
				cp "$SubjectDIR"/"$SubjectID"/mri/aseg.auto_noCCseg.mgz "$SubjectDIR"/"$SubjectID"/mri/aseg.auto_noCCseg${i}.mgz
				break
			else
				i="${i}+"
			fi
		done
		cp $AsegEdit "$SubjectDIR"/"$SubjectID"/mri/aseg.auto_noCCseg.mgz

		log_Msg "Run mri_cc"

		DIR=`pwd`
		cd "$SubjectDIR"/"$SubjectID"/mri
		mri_cc -aseg aseg.auto_noCCseg.mgz -o aseg.auto.mgz -lta "$SubjectDIR"/"$SubjectID"/mri/transforms/cc_up.lta "$SubjectID"
		cp aseg.auto.mgz aseg.presurf.mgz
		cd $DIR
	fi
	cp "$SubjectDIR"/"$SubjectID"/mri/aseg.auto.mgz "$SubjectDIR"/"$SubjectID"/mri/aseg.mgz

}

function runNormalize2 () {

	if [ "$ControlPoints" != "NONE" ] ; then
		mkdir -p "$SubjectDIR"/"$SubjectID"/tmp
		cp "$ControlPoints" "$SubjectDIR"/"$SubjectID"/tmp/control.dat
		# the following line is to suppress error in mris_fix_toplogy
		for i in lh.curv rh.curv ; do if [ -e "$SubjectDIR"/"$SubjectID"/surf/$i ] ; then rm "$SubjectDIR"/"$SubjectID"/surf/$i ;fi;done
	fi

	log_Msg "Fourth recon-all steps for normalization2"

	${ReconAll} -subjid $SubjectID -sd $SubjectDIR -normalization2 -maskbfs -segmentation

	## Paste claustrum to wm.mgz - TH, Oct 2017
	cp "$SubjectDIR"/"$SubjectID"/mri/aseg.auto.mgz "$SubjectDIR"/"$SubjectID"/mri/aseg+claustrum.mgz
	DIR=`pwd`
	cd "$SubjectDIR"/"$SubjectID"/mri
	cp wm.mgz wm.orig.mgz
	mri_convert wm.mgz wm.nii.gz
	mri_convert aseg+claustrum.mgz aseg+claustrum.nii.gz
	fslmaths aseg+claustrum.nii.gz -thr 138 -uthr 138 -bin -add aseg+claustrum.nii.gz -thr 139 -uthr 139 -bin -mul 250 \
	-max wm.nii.gz wm.nii.gz # pasting claustrum to wm.mgz

	## deweight cortical gray in wm.mgz to remove prunning of white surface into gray - Takuya Hayahsi Dec 2017
	if [[ $ControlPoints = NONE ]] ; then
		fslmaths aseg+claustrum.nii.gz -thr 42 -uthr 42 -bin -mul -39 -add aseg+claustrum.nii.gz -thr 3 -uthr 3 \
		-bin -s 0.25 -sub 1 -mul -1 -mul wm.nii.gz -thr 50 wm.nii.gz -odt char
	fi
	## paste wm skeleton for NHP - TH Aug 2019
	if [[ $SPECIES =~ Marmoset || $SPECIES =~ Macaque || $SPECIES =~ NightMonkey ]] ; then
		mkdir -p ../../../MNINonLinear/ROIs
		imcp $TemplateWMSkeleton ../../../MNINonLinear/ROIs/Atlas_wmskeleton.nii.gz
		applywarp -i ../../../MNINonLinear/ROIs/Atlas_wmskeleton.nii.gz -r ../../T1w_acpc_dc_restore_1mm.nii.gz -w \
		../../../MNINonLinear/xfms/standard2acpc_dc.nii.gz --postmat=../../xfms/real2fs.mat -o wmskeleton.nii.gz --interp=nn
             fslmaths wmskeleton.nii.gz -thr 0.1 -bin -mul 255 wmskeleton.nii.gz # Setting 255 is effective 
		mri_convert -ns 1 -odt uchar wmskeleton.nii.gz wmskeleton_conf.nii.gz --conform
		immv wmskeleton_conf.nii.gz wmskeleton.nii.gz
		fslmaths wmskeleton.nii.gz -max wm.nii.gz wm.nii.gz
	fi
	## paste wm lesion when requested
	if (( $(imtest ../../../MNINonLinear/WMLesion/wmlesion.nii.gz) == 1 || $(imtest ../../../T1w/WMLesion/wmlesion.nii.gz) == 1 )) ; then
		if (( $(imtest ../../../MNINonLinear/WMLesion/wmlesion.nii.gz) == 1 )) ; then
			log_Msg "Found wmlesion in MNINonLinear space"
			applywarp -i ../../../MNINonLinear/WMLesion/wmlesion  -r ../../T1w_acpc_dc_restore.nii.gz \
			-w ../../../MNINonLinear/xfms/standard2acpc_dc.nii.gz -o wmlesion.nii.gz --interp=nn
		elif (( $(imtest ../../../T1w/WMLesion/wmlesion.nii.gz) == 1 )) ; then
			log_Msg "Found wmlesion in T1w space"
			fslmaths ../../../T1w/WMLesion/wmlesion wmlesion.nii.gz
		fi
		fslmaths wmlesion.nii.gz -thr 0.01 -bin wmlesion_bin.nii.gz 
		"$PipelineScripts"/ScaleVolume.sh -i wmlesion_bin.nii.gz -s "$ScaleFactor" -o wmlesion_bin_1mm --interp=ENCLOSING_VOXEL
		mri_convert -ns 1 -odt uchar wmlesion_bin_1mm.nii.gz wmlesion_bin_1mm_conf.nii.gz --conform
		fslmaths wmlesion_bin_1mm_conf.nii.gz -mul  -max wm.nii.gz wm.nii.gz
	fi
	## convert back to mgz format
	mri_convert -ns 1 -odt uchar wm.nii.gz wm.mgz  # save in 8-bit
	cd $DIR

}

function runFSwhite () {

	if [ "$WmEdit" != "NONE" ] ; then
		WM="wm"
		while [ -e "$SubjectDIR"/"$SubjectID"/mri/${WM}.mgz ] ; do
			WM="${WM}+"
		done
		mv "$SubjectDIR"/"$SubjectID"/mri/wm.mgz "$SubjectDIR"/"$SubjectID"/mri/${WM}.mgz
		cp $WmEdit "$SubjectDIR"/"$SubjectID"/mri/wm.mgz
	fi

	if [ ! -e "$SubjectDIR"/"$SubjectID"/mri/wm+.mgz ] ; then 
		## Replace claustrum by putamen in aseg for accurate white surface estimation with mris_make_surface - TH, Oct 2017
		if [[ ! $SPECIES = Human || $CLAUSTRUM2PUTAMEN = "NONE" ]] ; then
			DIR=`pwd`
			cd "$SubjectDIR"/"$SubjectID"/mri
			fslmaths aseg+claustrum.nii.gz -thr 139 -uthr 139 -bin -mul 51 claustrum2putamen.rh
			fslmaths aseg+claustrum.nii.gz -thr 138 -uthr 138 -bin -mul 12 claustrum2putamen.lh
			fslmaths aseg+claustrum.nii.gz -thr 138 -uthr 138 -bin -add aseg+claustrum.nii.gz -thr 139 -uthr 139 \
			-binv -mul aseg+claustrum.nii.gz -add claustrum2putamen.lh.nii.gz -add claustrum2putamen.rh.nii.gz \
			aseg.nii.gz -odt char
			mri_convert -ns 1 -odt uchar aseg.nii.gz aseg.mgz
			cd $DIR
		fi
	fi

	log_Msg "Fifth recon-all steps for white"
	${ReconAll} -subjid $SubjectID -sd $SubjectDIR -fill $cccrs -tessellate -smooth1 -inflate1 -qsphere -fix -white -openmp ${num_cores} ${seed_cmd_appendix}

	# Highres and white stuffs and fine-tune T2w to T1w registration
	log_Msg "High resolution white matter and fine tune T2w to T1w registration"
	"$PipelineScripts"/FreeSurferHiresWhite_RIKEN.sh "$SubjectID" "$SubjectDIR" "$T1wImage" "$T2wImage" "$ScaleFactor"

}

function orig2white () {
	cp "$SubjectDIR"/"$SubjectID"/surf/lh.white "$SubjectDIR"/"$SubjectID"/surf/lh.white.init
	cp "$SubjectDIR"/"$SubjectID"/surf/lh.orig "$SubjectDIR"/"$SubjectID"/surf/lh.white
	cp "$SubjectDIR"/"$SubjectID"/surf/rh.white "$SubjectDIR"/"$SubjectID"/surf/rh.white.init
	cp "$SubjectDIR"/"$SubjectID"/surf/rh.orig "$SubjectDIR"/"$SubjectID"/surf/rh.white
	mris_curvature 

}

function runFSsurfreg () {

	#Intermediate Recon-all Steps

	if [[ ! -z $dist || ! -z $max_degree ]] ; then 
		if [ -e  "$SubjectDIR"/"$SubjectID"/scripts/expert.opts ] ; then
			rm "$SubjectDIR"/"$SubjectID"/scripts/expert.opts
		fi
		echo "mris_register $dist $maxdegree" > "$SubjectDIR"/"$SubjectID"/scripts/expert.opts
		ExpertOpts="-expert "$SubjectDIR"/"$SubjectID"/scripts/expert.opts -xopts-overwrite"
	fi
	log_Msg "Sixth recon-all steps for surf reeg"
	${ReconAll} -subjid $SubjectID -sd $SubjectDIR -smooth2 -inflate2 $CurvStats -sphere -surfreg -jacobian_white $AvgCurv -cortparc $ExpertOpts

}

function runFSpial () {

	#Highres pial stuff (this module adjusts the pial surface based on the the T2w image)
	if [[ ! $SPECIES =~ Human ]] ; then
		log_Msg "Rescale volume and surface to native space"
		"$PipelineScripts"/RescaleVolumeAndSurface.sh "$SubjectDIR" "$SubjectID" "$SubjectDIR"/xfms/real2fs "$T1wImage" "$T2wImage"
	fi

	log_Msg "High resolution pial surface"
	"$PipelineScripts"/FreeSurferHiresPial_RIKEN.sh "$SubjectID" "$SubjectDIR" "$T1wImage" "$T2wImage" "$T2wType" "$MaxThickness" "$VariableSigma" "$GreySigma" "$BiasFieldFastSmoothingSigma"

	if [[ $SPECIES =~ Human ]] ; then
		${ReconAll} -subjid $SubjectID -sd $SubjectDIR -parcstats -cortparc2 -parcstats2 -cortparc3 -parcstats3 -cortribbon \
		-segstats -aparc2aseg -segstats -wmparc -balabels -openmp ${num_cores} ${seed_cmd_appendix}
	fi

	log_Msg "Finished FreeSurferPipeline"

exit 0;

}

function main {

if   [ "$RunMode" = "1" ] ; then
	runFSinit;runNormalize1;runFSbrainmaskandseg;runFSnoCC;runNormalize2;runFSwhite;runFSsurfreg;runFSpial;
elif [ "$RunMode" = "2" ] ; then
	          runNormalize1;runFSbrainmaskandseg;runFSnoCC;runNormalize2;runFSwhite;runFSsurfreg;runFSpial;
elif [ "$RunMode" = "3" ] ; then
	                        runFSbrainmaskandseg;runFSnoCC;runNormalize2;runFSwhite;runFSsurfreg;runFSpial;
elif [ "$RunMode" = "4" ] ; then
	                                             runFSnoCC;runNormalize2;runFSwhite;runFSsurfreg;runFSpial;
elif [ "$RunMode" = "5" ] ; then
	                                                       runNormalize2;runFSwhite;runFSsurfreg;runFSpial;
elif [ "$RunMode" = "6" ] ; then
	                                                                     runFSwhite;runFSsurfreg;runFSpial;
elif [ "$RunMode" = "7" ] ; then
     	                                                                                runFSsurfreg;runFSpial;
elif [ "$RunMode" = "8" ] ; then
	                                                                                             runFSpial;
fi

}

main;
