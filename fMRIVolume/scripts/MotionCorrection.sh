#!/bin/bash 
set -e

# --------------------------------------------------------------------------------
#  Load Function Libraries
# --------------------------------------------------------------------------------

source $HCPPIPEDIR_Global/log.shlib # Logging related functions

# --------------------------------------------------------------------------------
#  Establish tool name for logging
# --------------------------------------------------------------------------------

log_SetToolName "MotionCorrection.sh"
log_Msg "START"

WorkingDirectory="$1"
InputfMRI="$2"
Scout="$3"
OutputfMRI="$4"
OutputMotionRegressors="$5"
OutputMotionMatrixFolder="$6"
OutputMotionMatrixNamePrefix="$7"
MotionCorrectionType="$8"

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

# Move output files about
mv -f ${WorkingDirectory}/${OutputfMRIBasename}/mc.par ${WorkingDirectory}/${OutputfMRIBasename}.par
if [ -e $OutputMotionMatrixFolder ] ; then
  rm -r $OutputMotionMatrixFolder
fi
mkdir $OutputMotionMatrixFolder

mv -f ${WorkingDirectory}/${OutputfMRIBasename}/* ${OutputMotionMatrixFolder}
mv -f ${WorkingDirectory}/${OutputfMRIBasename}.nii.gz ${OutputfMRI}.nii.gz

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
  random=$RANDOM

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
  rm $random
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

