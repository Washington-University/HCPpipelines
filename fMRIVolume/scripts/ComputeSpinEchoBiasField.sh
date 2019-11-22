#!/bin/bash

# Requirements for this script
#  installed versions of: FSL
#  environment: HCPPIPEDIR, FSLDIR

# --------------------------------------------------------------------------------
#  Usage Description Function
# --------------------------------------------------------------------------------

script_name=$(basename "${0}")

show_usage() {
	cat <<EOF

${script_name}

Usage: ${script_name} [options]

  --workingdir=<working dir>
  --subjectfolder=<subject processing folder>
  --fmriname=<name of fmri run>
  --corticallut=<FreeSurfer cortical label table>
  --subcorticallut=<FreeSurfer subcortical label table>
  --smoothingfwhm=<smoothing FWHM (in mm)>
  --inputdir=<input dir>

EOF
}

# Allow script to return a Usage statement, before any other output or checking
if [ "$#" = "0" ]; then
    show_usage
    exit 1
fi

# ------------------------------------------------------------------------------
#  Check that HCPPIPEDIR is defined and Load Function Libraries
# ------------------------------------------------------------------------------

if [ -z "${HCPPIPEDIR}" ]; then
  echo "${script_name}: ABORTING: HCPPIPEDIR environment variable must be set"
  exit 1
fi

source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@"         # Debugging functions; also sources log.shlib
source ${HCPPIPEDIR}/global/scripts/opts.shlib                 # Command line option functions

opts_ShowVersionIfRequested $@

if opts_CheckForHelpRequest $@; then
	show_usage
	exit 0
fi

# ------------------------------------------------------------------------------
#  Verify required environment variables are set and log value
# ------------------------------------------------------------------------------

log_Check_Env_Var HCPPIPEDIR
log_Check_Env_Var FSLDIR

################################################ SUPPORT FUNCTIONS ##################################################

# function for parsing options
getopt1() {
    sopt="$1"
    shift 1
    for fn in "$@" ; do
	if [ `echo "$fn" | grep -- "^${sopt}=" | wc -w` -gt 0 ] ; then
	    echo "$fn" | sed "s/^${sopt}=//"
	    return 0
	fi
    done
}

################################################## OPTION PARSING #####################################################

WD=`getopt1 "--workingdir" "$@"`
SubjectFolder=`getopt1 "--subjectfolder" "$@"` #replaces StudyFolder and Subject
fMRIName=`getopt1 "--fmriname" "$@"`
CorticalLUT=`getopt1 "--corticallut" "$@"`
SubCorticalLUT=`getopt1 "--subcorticallut" "$@"`
SmoothingFWHM=`getopt1 "--smoothingfwhm" "$@"`
InputDir=`getopt1 "--inputdir" "$@"`

if [[ -n $HCPPIPEDEBUG ]]
then
    set -x
fi

########################################## DO WORK ##########################################

Sigma=`echo "$SmoothingFWHM / ( 2 * ( sqrt ( 2 * l ( 2 ) ) ) )" | bc -l`
Caret7_Command="${CARET7DIR}"/wb_command

T1wFolder="${SubjectFolder}/T1w" #brainmask, wmparc, ribbon

#take inputs from specified directory (likely some working dir), so we don't have to put initial-registration files into the output folders temporarily
${FSLDIR}/bin/fslmaths ${InputDir}/PhaseOne_gdc_dc.nii.gz -add ${InputDir}/PhaseTwo_gdc_dc.nii.gz -Tmean ${WD}/SpinEchoMean.nii.gz
${FSLDIR}/bin/imcp ${InputDir}/SBRef_dc.nii.gz ${WD}/GRE.nii.gz

${FSLDIR}/bin/fslmaths ${WD}/SpinEchoMean.nii.gz -div ${WD}/GRE.nii.gz ${WD}/SEdivGRE.nii.gz
${FSLDIR}/bin/fslmaths ${WD}/SEdivGRE.nii.gz -mas ${T1wFolder}/brainmask_fs.nii.gz ${WD}/SEdivGRE_brain.nii.gz

#${FSLDIR}/bin/fslmaths ${WD}/SEdivGRE_brain.nii.gz -thr 1.25 -uthr 2.2 ${WD}/SEdivGRE_brain_thr.nii.gz #perhaps a bit too aggressive
Median=`${Caret7_Command} -volume-stats ${WD}/SEdivGRE_brain.nii.gz -roi ${WD}/SEdivGRE_brain.nii.gz -reduce MEDIAN`
STDev=`fslstats ${WD}/SEdivGRE_brain.nii.gz -S`
Lower=`echo "${Median}-${STDev}/3" | bc -l`
Upper=`echo "${Median}+${STDev}/3" | bc -l`
echo "Median=${Median}, STDev=${STDev}, Lower=${Lower}, Upper=${Upper}"
fslmaths ${WD}/SEdivGRE_brain.nii.gz -thr ${Lower} -uthr ${Upper} ${WD}/SEdivGRE_brain_thr.nii.gz

fslmaths ${WD}/SEdivGRE_brain_thr.nii.gz -ero -dilM -dilM -dilM -dilM -dilM -dilM -dilM -dilM -dilM -dilM -dilM -dilM -dilM -dilM ${WD}/${fMRIName}_pseudo_transmit_raw.nii.gz

${FSLDIR}/bin/fslmaths ${WD}/SEdivGRE_brain_thr.nii.gz -bin ${WD}/SEdivGRE_brain_thr_roi.nii.gz
${FSLDIR}/bin/fslmaths ${WD}/SEdivGRE_brain_thr.nii.gz -s 5 ${WD}/SEdivGRE_brain_thr_s5.nii.gz
${FSLDIR}/bin/fslmaths ${WD}/SEdivGRE_brain_thr_roi.nii.gz -s 5 ${WD}/SEdivGRE_brain_thr_roi_s5.nii.gz
${FSLDIR}/bin/fslmaths ${WD}/SEdivGRE_brain_thr_s5.nii.gz -div ${WD}/SEdivGRE_brain_thr_roi_s5.nii.gz -mas ${T1wFolder}/brainmask_fs.nii.gz ${WD}/SEdivGRE_brain_bias.nii.gz

${FSLDIR}/bin/fslmaths ${WD}/SEdivGRE_brain_bias.nii.gz -dilM -dilM ${WD}/${fMRIName}_pseudo_transmit_field.nii.gz

${FSLDIR}/bin/fslmaths ${WD}/SpinEchoMean.nii.gz -mas ${T1wFolder}/brainmask_fs.nii.gz -div ${WD}/SEdivGRE_brain_bias.nii.gz ${WD}/SpinEchoMean_brain_BC.nii.gz

${FSLDIR}/bin/fslmaths ${WD}/GRE.nii.gz -mas ${T1wFolder}/brainmask_fs.nii.gz -div ${WD}/SpinEchoMean_brain_BC.nii.gz ${WD}/SE_BCdivGRE_brain.nii.gz

#${FSLDIR}/bin/fslmaths ${WD}/SE_BCdivGRE_brain.nii.gz -uthr 0.5 -bin ${WD}/Dropouts.nii.gz
${FSLDIR}/bin/fslmaths ${WD}/SE_BCdivGRE_brain.nii.gz -uthr 0.6 -bin ${WD}/Dropouts.nii.gz #Adjust to 60% SE signal to compensate for above change that slightly penalizes dropout finding
${FSLDIR}/bin/fslmaths ${WD}/Dropouts.nii.gz -dilD -s ${Sigma} ${WD}/${fMRIName}_dropouts.nii.gz
${FSLDIR}/bin/fslmaths ${WD}/Dropouts.nii.gz -binv ${WD}/Dropouts_inv.nii.gz

${Caret7_Command} -volume-label-import ${T1wFolder}/wmparc.nii.gz ${SubCorticalLUT} ${WD}/SubcorticalGreyMatter.nii.gz -discard-others -drop-unused-labels
${FSLDIR}/bin/fslmaths ${WD}/SubcorticalGreyMatter.nii.gz -bin ${WD}/SubcorticalGreyMatter.nii.gz
${Caret7_Command} -volume-label-import ${T1wFolder}/ribbon.nii.gz ${CorticalLUT} ${WD}/CorticalGreyMatter.nii.gz -discard-others -drop-unused-labels
${FSLDIR}/bin/fslmaths ${WD}/CorticalGreyMatter.nii.gz -bin ${WD}/CorticalGreyMatter.nii.gz
${FSLDIR}/bin/fslmaths ${WD}/CorticalGreyMatter.nii.gz -add ${WD}/SubcorticalGreyMatter.nii.gz -bin ${WD}/AllGreyMatter.nii.gz

${FSLDIR}/bin/fslmaths ${WD}/GRE.nii.gz -mas ${WD}/AllGreyMatter.nii.gz -mas ${WD}/Dropouts_inv.nii.gz -bin ${WD}/GRE_greyroi.nii.gz
${FSLDIR}/bin/fslmaths ${WD}/GRE.nii.gz -mas ${WD}/GRE_greyroi.nii.gz -s 5 ${WD}/GRE_grey_s5.nii.gz 
${FSLDIR}/bin/fslmaths ${WD}/GRE_greyroi.nii.gz -s 5 ${WD}/GRE_greyroi_s5.nii.gz
${FSLDIR}/bin/fslmaths ${WD}/GRE_grey_s5.nii.gz -div ${WD}/GRE_greyroi_s5.nii.gz -mas ${WD}/AllGreyMatter.nii.gz -dilall -mas ${T1wFolder}/brainmask_fs.nii.gz ${WD}/GRE_bias_raw.nii.gz

${FSLDIR}/bin/fslmaths ${WD}/GRE_bias_raw.nii.gz -bin ${WD}/GRE_bias_roi.nii.gz
${FSLDIR}/bin/fslmaths ${WD}/GRE_bias_raw.nii.gz -s 5 ${WD}/GRE_bias_raw_s5.nii.gz
${FSLDIR}/bin/fslmaths ${WD}/GRE_bias_roi.nii.gz -s 5 ${WD}/GRE_bias_roi_s5.nii.gz
${FSLDIR}/bin/fslmaths ${WD}/GRE_bias_raw_s5.nii.gz -div ${WD}/GRE_bias_roi_s5.nii.gz -mas ${T1wFolder}/brainmask_fs.nii.gz ${WD}/GRE_bias.nii.gz
Mean=`fslstats ${WD}/GRE_bias.nii.gz -M`
${FSLDIR}/bin/fslmaths ${WD}/GRE_bias.nii.gz -div ${Mean} ${WD}/${fMRIName}_sebased_bias.nii.gz
${FSLDIR}/bin/fslmaths ${WD}/${fMRIName}_sebased_bias.nii.gz -ing 10000 ${WD}/${fMRIName}_sebased_reference.nii.gz

${FSLDIR}/bin/fslmaths ${WD}/${fMRIName}_sebased_bias.nii.gz -dilM -dilM ${WD}/sebased_bias_dil.nii.gz
${FSLDIR}/bin/fslmaths ${WD}/${fMRIName}_sebased_reference.nii.gz -dilM -dilM ${WD}/sebased_reference_dil.nii.gz

