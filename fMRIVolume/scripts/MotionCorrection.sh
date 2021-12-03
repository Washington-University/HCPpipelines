#!/bin/bash 

# Requirements for this script
#  installed versions of: FSL
#  environment: HCPPIPEDIR, FSLDIR, HCPPIPEDIR_Global

# --------------------------------------------------------------------------------
#  Usage Description Function
# --------------------------------------------------------------------------------

script_name=$(basename "${0}")

show_usage() {
	cat <<EOF

${script_name}

Script currently parses arguments positionally, as follows:

WorkingDirectory="\$1"
InputfMRI="\$2"
Scout="\$3"
OutputfMRI="\$4"
OutputMotionRegressors="\$5"
OutputMotionMatrixFolder="\$6"
OutputMotionMatrixNamePrefix="\$7"
MotionCorrectionType="\$8"
fMRIReferenceReg="\$9"

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
source "${HCPPIPEDIR}/global/scripts/opts.shlib"               # Command line option functions
source "${HCPPIPEDIR}/global/scripts/tempfiles.shlib"          # handle temporary files

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
log_Check_Env_Var HCPPIPEDIR_Global

# --------------------------------------------------------------------------------
#  Do work
# --------------------------------------------------------------------------------

log_Msg "START"

WorkingDirectory="$1"
InputfMRI="$2"
Scout="$3"
OutputfMRI="$4"
OutputMotionRegressors="$5"
OutputMotionMatrixFolder="$6"
OutputMotionMatrixNamePrefix="$7"
MotionCorrectionType="$8"
fMRIReferenceReg="$9"

verbose_red_echo "---> ${MotionCorrectionType} based motion correction"
verbose_echo " "
verbose_echo " Using parameters ..."
verbose_echo "             WorkingDirectory: ${WorkingDirectory}"
verbose_echo "                    InputfMRI: ${InputfMRI}"
verbose_echo "                        Scout: ${Scout}"
verbose_echo "                   OutputfMRI: ${OutputfMRI}"
verbose_echo "       OutputMotionRegressors: ${OutputMotionRegressors}"
verbose_echo "     OutputMotionMatrixFolder: ${OutputMotionMatrixFolder}"
verbose_echo " OutputMotionMatrixNamePrefix: ${OutputMotionMatrixNamePrefix}"
verbose_echo "         MotionCorrectionType: ${MotionCorrectionType}"
verbose_echo "             fMRIReferenceReg: ${fMRIReferenceReg}"
verbose_echo " "

OutputfMRIBasename=`basename ${OutputfMRI}`

# Do motion correction
log_Msg "Do motion correction"
case "$MotionCorrectionType" in
    MCFLIRT)
        ${HCPPIPEDIR_Global}/mcflirt.sh ${InputfMRI} ${WorkingDirectory}/${OutputfMRIBasename} ${Scout}
    ;;
    
    FLIRT)
        ${HCPPIPEDIR_Global}/mcflirt_acc.sh ${InputfMRI} ${WorkingDirectory}/${OutputfMRIBasename} ${Scout}
    ;;
    
    *)
        log_Msg "ERROR: MotionCorrectionType must be 'MCFLIRT' or 'FLIRT'"
        exit 1
    ;;
esac

# Run nonlinear registration if needed

# If registering across runs, perform nonlinear registration if requested.
# (If using linear registration, don't need to do anything extra here, since
# linear registration is handled implicitly via the motion correction).
# Note that if registering across runs, the "$Scout" input to MotionCorrection will
# be the *reference* scout image (by construction in GenericfMRIVolume).

if [ "${fMRIReferenceReg}" == "nonlinear" ] ; then
  verbose_echo " ... computing nonlinear transform to reference"
  verbose_echo "     ... generating bold average"
  # Generating a mean image to increase signal-to-noise ratio when registering to scout.
  ${FSLDIR}/bin/fslmaths ${WorkingDirectory}/${OutputfMRIBasename} -Tmean ${WorkingDirectory}/${OutputfMRIBasename}_avg

  # Note that the name of the warp is hard-coded into OneStepResampling.sh
  cmd=("${FSLDIR}/bin/fnirt" --in="${WorkingDirectory}/${OutputfMRIBasename}_avg" --ref="${Scout}" --iout="${WorkingDirectory}/${OutputfMRIBasename}_avg_nonlin" --fout="${WorkingDirectory}/postmc2fmriref_warp")
  verbose_echo "     ... running fnirt: ${cmd[*]}"
  "${cmd[@]}"

  verbose_echo "     ... applying warp"
  tmcbold="_nonlin"
  ${FSLDIR}/bin/applywarp --rel --interp=spline -i ${WorkingDirectory}/${OutputfMRIBasename} -r ${Scout}  -w ${WorkingDirectory}/postmc2fmriref_warp -o ${WorkingDirectory}/${OutputfMRIBasename}${tmcbold}  
else
  tmcbold=""
fi

# Move output files about
mv -f ${WorkingDirectory}/${OutputfMRIBasename}/mc.par ${WorkingDirectory}/${OutputfMRIBasename}.par
if [ -e $OutputMotionMatrixFolder ] ; then
  rm -r $OutputMotionMatrixFolder
fi
mkdir $OutputMotionMatrixFolder

mv -f ${WorkingDirectory}/${OutputfMRIBasename}/* ${OutputMotionMatrixFolder}
mv -f ${WorkingDirectory}/${OutputfMRIBasename}${tmcbold}.nii.gz ${OutputfMRI}.nii.gz

# Change names of all matrices in OutputMotionMatrixFolder
log_Msg "Change names of all matrices in OutputMotionMatrixFolder"
DIR=`pwd`
if [ -e $OutputMotionMatrixFolder ] ; then
  cd $OutputMotionMatrixFolder
  Matrices=`ls`
  for Matrix in $Matrices ; do
    MatrixNumber=`basename ${Matrix} | cut -d "_" -f 2`
    mv $Matrix `echo ${OutputMotionMatrixNamePrefix}${MatrixNumber} | cut -d "." -f 1`
  done
  cd $DIR
fi

# Move over the nonlinear warp to be used in OneStepResampling
if [ "${fMRIReferenceReg}" == "nonlinear" ] ; then
  verbose_echo "     ... moving warp to ${OutputMotionMatrixFolder}"
  mv -f ${WorkingDirectory}/postmc2fmriref_warp.nii.gz ${OutputMotionMatrixFolder} 
fi

# Make 4dfp style motion parameter and derivative regressors for timeseries
# Take the backwards temporal derivative in column $1 of input $2 and output it as $3
# Vectorized Matlab: d=[zeros(1,size(a,2));(a(2:end,:)-a(1:end-1,:))];
# Bash version of above algorithm
function DeriveBackwards {
  i="$1"
  in="$2"
  out="$3"
  # Var becomes a string of values from column $i in $in. Single space separated
  Var=`cat "$in" | sed s/"  "/" "/g | cut -d " " -f $i`
  Length=`echo $Var | wc -w`
  # TCS becomes an array of the values from column $i in $in (derived from Var)
  TCS=($Var)
  # random is a random file name for temporary output
  tempfiles_create MotionCorrectionRandom_XXXXXX.txt random

  # Cycle through our array of values from column $i
  j=0
  while [ $j -lt $Length ] ; do
    if [ $j -eq 0 ] ; then
      # Backward derivative of first volume is set to 0
      Answer=`echo "0"`
    else
      # Compute the backward derivative of non-first volumes

      # Format numeric value (convert scientific notation to decimal) jth row of ith column
      # in $in (mcpar)
      Forward=`echo ${TCS[$j]} | awk -F"E" 'BEGIN{OFMT="%10.10f"} {print $1 * (10 ^ $2)}'`
    
      # Similarly format numeric value for previous row (j-1)
      Back=`echo ${TCS[$(($j-1))]} | awk -F"E" 'BEGIN{OFMT="%10.10f"} {print $1 * (10 ^ $2)}'`

      # Compute backward derivative as current minus previous
      Answer=`echo "scale=10; $Forward - $Back" | bc -l`
    fi
    # 0 prefix the resulting number
    Answer=`echo $Answer | sed s/"^\."/"0."/g | sed s/"^-\."/"-0."/g`
    echo `printf "%10.6f" $Answer` >> $random
    j=$(($j + 1))
  done
  paste -d " " $out $random > ${out}_
  mv ${out}_ ${out}
}

# Run the Derive function to generate appropriate regressors from the par file
log_Msg "Run the Derive function to generate appropriate regressors from the par file"
in=${WorkingDirectory}/${OutputfMRIBasename}.par
out=${OutputMotionRegressors}.txt
cat $in | sed s/"  "/" "/g > $out
i=1
while [ $i -le 6 ] ; do
  DeriveBackwards $i $in $out
  i=`echo "$i + 1" | bc`
done

cat ${out} | awk '{for(i=1;i<=NF;i++)printf("%10.6f ",$i);printf("\n")}' > ${out}_
mv ${out}_ $out

awk -f ${HCPPIPEDIR_Global}/mtrendout.awk $out > ${OutputMotionRegressors}_dt.txt

log_Msg "END"

# Make 4dfp style motion parameter and derivative regressors for timeseries
# Take the unbiased temporal derivative in column $1 of input $2 and output it as $3
# Vectorized Matlab: d=[a(2,:)-a(1,:);(a(3:end,:)-a(1:end-2,:))/2;a(end,:)-a(end-1,:)];
# Bash version of above algorithm
# This algorithm was used in Q1 Version 1 of the data, future versions will use DeriveBackwards
function DeriveUnBiased {
  i="$1"
  in="$2"
  out="$3"
  Var=`cat "$in" | sed s/"  "/" "/g | cut -d " " -f $i`
  Length=`echo $Var | wc -w`
  length1=$(($Length - 1))
  TCS=($Var)
  random=$RANDOM
  j=0
  while [ $j -le $length1 ] ; do
    if [ $j -eq 0 ] ; then # This is the forward derivative for the first row
      Forward=`echo ${TCS[$(($j+1))]} | awk -F"E" 'BEGIN{OFMT="%10.10f"} {print $1 * (10 ^ $2)}'`
      Back=`echo ${TCS[$j]} | awk -F"E" 'BEGIN{OFMT="%10.10f"} {print $1 * (10 ^ $2)}'`
      Answer=`echo "$Forward - $Back" | bc -l`
    elif [ $j -eq $length1 ] ; then # This is the backward derivative for the last row
      Forward=`echo ${TCS[$j]} | awk -F"E" 'BEGIN{OFMT="%10.10f"} {print $1 * (10 ^ $2)}'`
      Back=`echo ${TCS[$(($j-1))]} | awk -F"E" 'BEGIN{OFMT="%10.10f"} {print $1 * (10 ^ $2)}'`
      Answer=`echo "$Forward - $Back" | bc -l`
    else # This is the center derivative for all other rows.
      Forward=`echo ${TCS[$(($j+1))]} | awk -F"E" 'BEGIN{OFMT="%10.10f"} {print $1 * (10 ^ $2)}'`
      Back=`echo ${TCS[$(($j-1))]} | awk -F"E" 'BEGIN{OFMT="%10.10f"} {print $1 * (10 ^ $2)}'`
      Answer=`echo "scale=10; ( $Forward - $Back ) / 2" | bc -l`
    fi
    Answer=`echo $Answer | sed s/"^\."/"0."/g | sed s/"^-\."/"-0."/g`
    echo `printf "%10.6f" $Answer` >> $random
    j=$(($j + 1))
  done
  paste -d " " $out $random > ${out}_
  mv ${out}_ ${out}
  rm $random
}

