#!/bin/bash 
set -e
echo -e "\n START: MotionCorrection_FLIRTBased"

WorkingDirectory="$1"
InputfMRI="$2"
Scout="$3"
OutputfMRI="$4"
OutputMotionRegressors="$5"
OutputMotionMatrixFolder="$6"
OutputMotionMatrixNamePrefix="$7"
PipelineScripts="$8"
GlobalScripts="$9"

OutputfMRIFile=`basename "$OutputfMRI"`

#Do motion correction
"$GlobalScripts"/mcflirt_acc.sh "$InputfMRI" "$WorkingDirectory"/"$OutputfMRIFile" "$Scout"
mv -f "$WorkingDirectory"/"$OutputfMRIFile"/mc.par "${WorkingDirectory}/${OutputfMRIFile}.par"
if [ ! -e $OutputMotionMatrixFolder ] ; then
  mkdir $OutputMotionMatrixFolder
else 
  rm -r $OutputMotionMatrixFolder
  mkdir $OutputMotionMatrixFolder
fi
mv -f "$WorkingDirectory"/"$OutputfMRIFile"/* $OutputMotionMatrixFolder
mv -f "$WorkingDirectory"/"$OutputfMRIFile".nii.gz "$OutputfMRI".nii.gz
DIR=`pwd`
if [ -e $OutputMotionMatrixFolder ] ; then
  cd $OutputMotionMatrixFolder
  Matrices=`ls`
  for Matrix in $Matrices ; do
    MatrixNumber=`basename "$Matrix" | cut -d "_" -f 2`
    mv $Matrix `echo "$OutputMotionMatrixNamePrefix""$MatrixNumber" | cut -d "." -f 1`
  done
  cd $DIR
fi

#Make 4dfp style motion parameter and derivative regressors for timeseries
#Take the temporal derivative in column $1 of input $2 and output it as $3
#Vectorized Matlab: d=[a(2)-a(1);(a(1:end-2)-a(3:end))/2;a(end)-a(end-1)]
#Bash version of above algorithm
function Derive {
  i="$1"
  in="$2"
  out="$3"
  Var=`cat "$in" | sed s/"  "/" "/g | cut -d " " -f $i`
  Length=`echo $Var | wc -w`
  length=$(($Length - 1))
  TCS=($Var)
  random=$RANDOM
  j=0
  while [ $j -le $length ] ; do
    if [ $j -eq 0 ] ; then
      Forward=`echo ${TCS[$(($j+1))]} | awk -F"E" 'BEGIN{OFMT="%10.10f"} {print $1 * (10 ^ $2)}'`
      Back=`echo ${TCS[$j]} | awk -F"E" 'BEGIN{OFMT="%10.10f"} {print $1 * (10 ^ $2)}'`
      Answer=`echo "$Forward - $Back" | bc -l`
    elif [ $j -eq $length ] ; then
      Forward=`echo ${TCS[$j]} | awk -F"E" 'BEGIN{OFMT="%10.10f"} {print $1 * (10 ^ $2)}'`
      Back=`echo ${TCS[$(($j-1))]} | awk -F"E" 'BEGIN{OFMT="%10.10f"} {print $1 * (10 ^ $2)}'`
      Answer=`echo "$Forward - $Back" | bc -l`
    else
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

in="${WorkingDirectory}/${OutputfMRIFile}.par"
out="$OutputMotionRegressors".txt
cat $in | sed s/"  "/" "/g > $out
i=1
while [ $i -le 6 ] ; do
  Derive $i $in $out
  i=`echo "$i + 1" | bc`
done

cat $out | sed s/"  "/" "/g > ${out}_
mv ${out}_ $out

awk -f "$GlobalScripts"/trendout.awk $out > "$OutputMotionRegressors"_dt.txt

echo "   END: MotionCorrection_FLIRTBased"
