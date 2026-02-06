#!/bin/bash 

Usage () {
echo ""
echo "Usage $0 <StudyFolder> <Subject ID> [options]"
echo ""
echo "   Options:"
echo "       -m <num> :           : BBR (0: no-BBR, 1: T1w-based (e.g. MION fMRI), 2: T2w-based [default])"
echo "       -S <num>             : specify Nth session (applying to RunMode 1-3) You need all sets of variables in hcppipe_conf.txt"
echo "                              (i.e., Tasklist, Taskreflist, TopupPositive, TopupNegative, PhaseEncodingList,"
echo "                              and DwellTime, TruePatientPosition [HFS, HFSx, FFSx], ScannerPatientPosition "
echo "                              [HFS, HFP, FFS, FFP])"
echo "       -f <fmriname>        : specify fmriname"
echo "       -b <num>             : bias field correction (0: NONE [default], 1: T1w-based, 2: SE-EPI-based)"
echo "       -R <MCFLIRT | FLIRT> : Motion correction type (defulat=MCFLIRT)"
echo "       -s <1-3>             : RunMode:" 
echo "                              1 : MotionCorrection and subsequent step 2 and 3"
echo "                              2 : DistortionCorrectionAndEPI2T1wReg and subsequent step 3"
echo "                              3 : OneStemResampling and IntensityNormalization"
#echo "                              4 : MotionCorrectXRuns"
#echo "                              5 : ResampleXRuns"
echo "       -n                   : do not use Jacobian"
echo "       -t <TRUE or FALSE>   : use T2w as PhaseZero (default: TRUE), do not use this when you scanned fMRI in the different session of T2w"
echo "       -d                   : dry run (print commands in the terminal but not run)" 
echo ""
exit 1;
}
[ "$2" = "" ] && Usage

if [ "$SPECIES" = "" ] ; then echo "ERROR: please export SPECIES first to any of Macaque, MacaqueCyno, MacaqueRhesus, Marmoset, NightMonkey, Chimp, Human"; exit 1;fi
if [ "$HCPPIPEDIR" = "" ] ; then echo "ERROR please export HCPPIPEDIR before running this script"; exit 1; fi
EnvironmentScript="$HCPPIPEDIR/Examples/Scripts/SetUpHCPPipeline.sh"
source ${EnvironmentScript}
source $HCPPIPEDIR/Examples/Scripts/SetUpSPECIES.sh $SPECIES
source $HCPPIPEDIR/FreeSurfer/custom/SetUpFSNHP.sh

# WMProjAbs

StudyFolder=$1;
Subjlist=$2;

shift;shift;
### Optional arguments####
BBR="T2w";
Bias="0";
MCType="MCFLIRT"
RunMode="1"
UseT2wAsPhaseZero="TRUE"
DryRun="FALSE"

while getopts m:f:b:R:s:nS:t:d OPT
 do
 case "$OPT" in 
   "m" ) moveto="$OPTARG";;
   "f" ) fmriname="`remove_ext $OPTARG`";;
   "b" ) Bias="$OPTARG";;
   "R" ) MCType="$OPTARG";;
   "s" ) RunMode="$OPTARG" ;;
   "S" ) SpecSessionlist="$OPTARG" ;;
   "n" ) UseJacobian="false" ;;
   "t" ) UseT2wAsPhaseZero="$OPTARG";;
   "d" ) DryRun="TRUE";;
    * )  usage_exit;;
 esac
done;

if [ "$moveto" = "0" ] ; then
	BBR="NONE"
elif [ "$moveto" = "1" ] ; then
	BBR="T1w"
elif [ "$moveto" = "2" ] ; then
	BBR="T2w"
fi

if [ "$Bias" = 0 ] ; then
    	BiasCorrection="NONE" #NONE, LEGACY, or SEBASED: LEGACY uses the T1w bias field, SEBASED calculates bias field from spin echo images (which requires TOPUP distortion correction)
elif [ "$Bias" = 1 ] ; then
    	BiasCorrection="LEGACY"
elif [ "$Bias" = 2 ] ; then
    	BiasCorrection="SEBASED"
fi
##############################

PRINTCOM=""
#PRINTCOM="echo"
#QUEUE="-T 360"
unset Tasklist
unset Gradient

for Subject in $(echo $Subjlist | sed -e 's/@/ /g'); do   # loop for subjects
  if [ "$Tasklist" = "" ] ; then 
   if [ -e ${StudyFolder}/${Subject}/RawData/hcppipe_conf.txt ] ; then
    source ${StudyFolder}/${Subject}/RawData/hcppipe_conf.txt

   else
    echo "Cannot find hcppipe_conf.txt in ${Subject}/RawData";
    echo "Exiting without processing.";
    exit 1;
   fi
  fi

 OrigTasklist=$(echo $Tasklist | sed -e 's/^@//g' | sed -e 's/@$//g')
 OrigTaskreflist=$(echo $Taskreflist | sed -e 's/^@//g' | sed -e 's/@$//g')
 OrigTopupPositive=$(echo $TopupPositive | sed -e 's/^@//g' | sed -e 's/@$//g')
 OrigTopupNegative=$(echo $TopupNegative | sed -e 's/^@//g' | sed -e 's/@$//g')
 OrigPhaseEncodinglist=$(echo $PhaseEncodinglist | sed -e 's/^@//g' | sed -e 's/@$//g')
 OrigFmriconcatlist=$(echo $Fmriconcatlist | sed -e 's/^@//g' | sed -e 's/@$//g')
 OrigDwellTime=$(echo $DwellTime | sed -e 's/^@//g' | sed -e 's/@$//g')
 OrigInitWorldMat=$(echo $InitWorldMat | sed -e 's/^@//g' | sed -e 's/@$//g')
 OrigScannerPatientPosition=$(echo $ScannerPatientPosition | sed -e 's/^@//g' | sed -e 's/@$//g')
 OrigTruePatientPosition=$(echo $TruePatientPosition | sed -e 's/^@//g' | sed -e 's/@$//g')
 OrigTopupPositive2=$(echo $TopupPositive2 | sed -e 's/^@//g' | sed -e 's/@$//g')
 OrigTopupNegative2=$(echo $TopupNegative2 | sed -e 's/^@//g' | sed -e 's/@$//g')
 AllfMRINames=$(echo $(echo $OrigTasklist | sed -e 's/@/ /g') | sed -e 's/ /@/g') # fMRINames separated by @

 if [ ! -z $SpecSessionlist ] ; then
	Sessionlist=$(echo $SpecSessionlist | sed -e 's/,/ /g')
 else
	nsession=$(echo $OrigTasklist | awk -F"@" '{print NF}')
	Sessionlist=$(seq 1 $nsession);
 fi

 for session in $Sessionlist ; do   # loop for sessions

  SessionTasklist=$(echo $OrigTasklist | cut -d '@' -f ${session})
  SessionTaskreflist=$(echo $OrigTaskreflist | cut -d '@' -f ${session})
  SessionTopupPositive=$(echo $OrigTopupPositive | cut -d '@' -f ${session})
  SessionTopupNegative=$(echo $OrigTopupNegative | cut -d '@' -f ${session})
  PhaseEncodinglist=$(echo $OrigPhaseEncodinglist | cut -d '@' -f ${session})
  fmriconcat=$(echo $OrigFmriconcatlist | cut -d '@' -f ${session} | sed -e 's/ //g')
  DwellTime=$(echo $OrigDwellTime | cut -d '@' -f ${session} | sed -e 's/ //g')
  ScannerPatientPosition=$(echo $OrigScannerPatientPosition | cut -d '@' -f ${session} | sed -e 's/ //g')
  TruePatientPosition=$(echo $OrigTruePatientPosition | cut -d '@' -f ${session} | sed -e 's/ //g')
  SessionTopupPositive2=$(echo $OrigTopupPositive2 | cut -d '@' -f ${session})
  SessionTopupNegative2=$(echo $OrigTopupNegative2 | cut -d '@' -f ${session})

  if [ ! -z "$OrigInitWorldMat" ] ; then
    InitWorldMat=${StudyFolder}/${Subject}/RawData/$(echo $OrigInitWorldMat | cut -d '@' -f ${session} | sed -e 's/ //g')
    if [ ! -e $InitWorldMat ] ; then
         echo "ERROR: cannot find $InitWorldMat"
         exit 1;
    fi
  fi
  if [ -z "$TruePatientPosition" ] ; then
        TruePatientPosition=HFS
  fi
  if [ -z "$ScannerPatientPosition" ] ; then
        ScannerPatientPosition=HFS
  fi

  nSessionTasklist=$(echo $SessionTasklist | wc -w)
  fmrinumlist=""
  if [ -n "$fmriname"  ] ; then
    j=1; 
    for i in $SessionTasklist; do 
      if [[ "$(remove_ext $i)" = "$fmriname" ]] ; then 
        fmrinumlist="$j" ;
      fi;
      j=`expr $j + 1`;
    done
  else
    fmrinumlist=$(seq 1 $nSessionTasklist)
  fi

  for fmrinum in $fmrinumlist ; do
    fMRINameOrig=$(echo $SessionTasklist | cut -d " " -f $fmrinum)
    UnwarpDir=$(echo $PhaseEncodinglist | cut -d " " -f $fmrinum)
    fMRIName=$(basename $(remove_ext $fMRINameOrig))

    #echo "Removing initial 10 volumes from fMRI time series data"
    #${HCPPIPEDIR}/global/scripts/removeinitvolumes.sh ${StudyFolder}/${Subject}/RawData/${fMRIName} 10
    fMRITimeSeries=$(imglob -extension ${StudyFolder}/${Subject}/RawData/$fMRIName)
    fMRISBRef=$(imglob -extension ${StudyFolder}/${Subject}/RawData/$(echo $SessionTaskreflist | cut -d " " -f $fmrinum)) #A single band reference image (SBRef) is recommended if using multiband, set to NONE if you want to use the first volume of the timeseries for motion correction

    if [[ $fMRITimeSeries = "" || $fMRISBRef = "" ]] ; then
      	echo " ERROR: cannot find fmri runs"; exit 1;
    fi
    ###Previous data was processed with 2x the correct echo spacing because ipat was not accounted for###
    #DwellTime="0.00115" #Echo Spacing or Dwelltime of fMRI image = 1/(BandwidthPerPixelPhaseEncode * # of phase encoding samples): DICOM field (0019,1028) = BandwidthPerPixelPhaseEncode, DICOM field (0051,100b) AcquisitionMatrixText first value (# of phase encoding samples) 
    if [[ -n $SessionTopupPositive  && -n $SessionTopupNegative ]] ; then
	   DistortionCorrection="TOPUP" #FIELDMAP or TOPUP, distortion correction is required for accurate processing
	   #For the spin echo field map volume with a negative phase encoding direction (LR in HCP data),
	   #set to NONE if using regular FIELDMAP

      if [ -n $(echo $SessionTopupNegative | cut -d " " -f $fmrinum) ] ; then
    		SpinEchoPhaseEncodeNegative=$(imglob -extension ${StudyFolder}/${Subject}/RawData/$(echo $SessionTopupNegative | cut -d " " -f $fmrinum))
	   else
    		SpinEchoPhaseEncodeNegative=$(imglob -extension ${StudyFolder}/${Subject}/RawData/$(echo $SessionTopupNegative | cut -d " " -f 1))
	   fi
	   #For the spin echo field map volume with a positive phase encoding direction (RL in HCP data),
	   #set to NONE if using regular FIELDMAP
	   if [ -n $(echo $SessionTopupPositive | cut -d " " -f $fmrinum) ] ; then
    		SpinEchoPhaseEncodePositive=$(imglob -extension ${StudyFolder}/${Subject}/RawData/$(echo $SessionTopupPositive | cut -d " " -f $fmrinum))
	   else
    		SpinEchoPhaseEncodePositive=$(imglob -extension ${StudyFolder}/${Subject}/RawData/$(echo $SessionTopupPositive | cut -d " " -f 1))
	   fi
	   PhaseInputName="NONE" #Expects a 3D Phase volume, set to NONE if using TOPUP
	   MagnitudeInputName="NONE" #Expects 4D Magnitude volume with two 3D timepoints, set to NONE if using TOPUP

      # Jacobian
      UseJacobian="${UseJacobian:-True}"

      # second SEPhase
      if [[ -n $SessionTopupPositive2 && -n $SessionTopupNegative2 ]] ; then
		  if [ -n $(echo $SessionTopupNegative2 | cut -d " " -f $fmrinum) ] ; then
	    		SpinEchoPhaseEncodeNegative2=$(imglob -extension ${StudyFolder}/${Subject}/RawData/$(echo $SessionTopupNegative2 | cut -d " " -f $fmrinum))
		  else
	    		SpinEchoPhaseEncodeNegative2=$(imglob -extension ${StudyFolder}/${Subject}/RawData/$(echo $SessionTopupNegative2 | cut -d " " -f 1))
		  fi
		  if [ -n $(echo $SessionTopupPositive2 | cut -d " " -f $fmrinum) ] ; then
	    		SpinEchoPhaseEncodePositive2=$(imglob -extension ${StudyFolder}/${Subject}/RawData/$(echo $SessionTopupPositive2 | cut -d " " -f $fmrinum))
		  else
	    		SpinEchoPhaseEncodePositive2=$(imglob -extension ${StudyFolder}/${Subject}/RawData/$(echo $SessionTopupPositive2 | cut -d " " -f 1))
		  fi
	   else
		  SpinEchoPhaseEncodeNegative2=NONE
		  SpinEchoPhaseEncodePositive2=NONE
      fi

      # use T2w as a phase zero - TH Jan 2023
      if [[ $(imtest ${StudyFolder}/${Subject}/T2w/T2w) = 1 && $UseT2wAsPhaseZero = TRUE ]] ; then
         SpinEchoPhaseEncodeZero=${StudyFolder}/${Subject}/T2w/T2w
	     SpinEchoPhaseEncodeZeroFSBrainmask=${StudyFolder}/${Subject}/T2w/T2w_brainmask_fs
	  else
         SpinEchoPhaseEncodeZero=NONE
	  fi


    elif [[ $MagnitudeInputName != "" && PhaseInputName != "" ]] ; then

       MagnitudeInputNAME="`imglob -extension ${StudyFolder}/${Subject}/RawData/${MagnitudeInputName}`"
       PhaseInputNAME="`imglob -extension ${StudyFolder}/${Subject}/RawData/${PhaseInputName}`"
       DistortionCorrection="FIELDMAP"
       DeltaTE="1.02" #2.46ms for 3T, 1.02ms for 7T, set to NONE if using TOPUP
       DeltaTE="2.46"
       UseJacobian="${UseJacobian:-False}"

    else
       echo "ERROR: no fieldmap data supplied" ;  
       exit 1
    fi

    # Gradient unwarping
    GradientDistortionCoeffs="NONE" #Gradient distortion correction coefficents, set to NONE to turn off
    if [ "$Gradient" != "" ] ; then
      GradientDistortionCoeffs="${GradientDistortionCoeffsDIR}/coeff_${Gradient}.grad"
    fi

    if [[ "${RunMode}" = 1 || "${RunMode}" = 2 || "${RunMode}" = 3 ]] ; then

     #${FSLDIR}/bin/fsl_sub $QUEUE -l $StudyFolder/$Subject/logs \
     if [ $DryRun = "FALSE" ] ; then
     ${HCPPIPEDIR}/fMRIVolume/GenericfMRIVolumeProcessingPipeline.sh \
      --path=$StudyFolder \
      --subject=$Subject \
      --fmriname=$fMRIName \
      --fmritcs=$fMRITimeSeries \
      --fmriscout=$fMRISBRef \
      --SEPhaseNeg=$SpinEchoPhaseEncodeNegative \
      --SEPhasePos=$SpinEchoPhaseEncodePositive \
      --SEPhaseNeg2=$SpinEchoPhaseEncodeNegative2 \
      --SEPhasePos2=$SpinEchoPhaseEncodePositive2 \
      --SEPhaseZero=$SpinEchoPhaseEncodeZero \
      --SEPhaseZeroFSBrainmask=$SpinEchoPhaseEncodeZeroFSBrainmask \
      --fmapmag=$MagnitudeInputNAME \
      --fmapphase=$PhaseInputNAME \
      --fmapgeneralelectric=$GEB0InputName \
      --echospacing=$DwellTime \
      --echodiff=$DeltaTE \
      --unwarpdir=$UnwarpDir \
      --fmrires=$FinalFMRIResolution \
      --dcmethod=$DistortionCorrection \
      --gdcoeffs=$GradientDistortionCoeffs \
      --topupconfig=$TopUpConfig \
      --printcom=$PRINTCOM \
      --biascorrection=$BiasCorrection \
      --usejacobian=$UseJacobian \
      --mctype=${MCType}      \
      --bbr=${BBR}      \
      --wmprojabs=${WMProjAbs}  \
      --initworldmat=${InitWorldMat} \
      --scannerpatientposition=${ScannerPatientPosition} \
      --truepatientposition=${TruePatientPosition} \
      --species=${SPECIES} \
      --betspecieslabel=${betspecieslabel} \
      --brainscalefactor=${BrainScaleFactor} \
      --runmode=${RunMode}
      fi
   # The following lines are used for interactive debugging to set the positional parameters: $1 $2 $3 ...
      if [ $DryRun = FALSE ] ; then
       CMD="set --"
      else
       CMD="${HCPPIPEDIR}/fMRIVolume/GenericfMRIVolumeProcessingPipeline.sh"
      fi
       echo "$CMD --path=$StudyFolder \
      --subject=$Subject \
      --fmriname=$fMRIName \
      --fmritcs=$fMRITimeSeries \
      --fmriscout=$fMRISBRef \
      --SEPhaseNeg=$SpinEchoPhaseEncodeNegative \
      --SEPhasePos=$SpinEchoPhaseEncodePositive \
      --SEPhaseNeg2=$SpinEchoPhaseEncodeNegative2 \
      --SEPhasePos2=$SpinEchoPhaseEncodePositive2 \
      --SEPhaseZero=$SpinEchoPhaseEncodeZero \
      --SEPhaseZeroFSBrainmask=$SpinEchoPhaseEncodeZeroFSBrainmask \
      --fmapmag=$MagnitudeInputNAME \
      --fmapphase=$PhaseInputNAME \
      --fmapgeneralelectric=$GEB0InputName \
      --echospacing=$DwellTime \
      --echodiff=$DeltaTE \
      --unwarpdir=$UnwarpDir \
      --fmrires=$FinalFMRIResolution \
      --dcmethod=$DistortionCorrection \
      --gdcoeffs=$GradientDistortionCoeffs \
      --topupconfig=$TopUpConfig \
      --printcom=$PRINTCOM \
      --biascorrection=$BiasCorrection \
      --usejacobian=$UseJacobian \
      --mctype=${MCType} \
      --bbr=${BBR}   \
      --wmprojabs=${WMProjAbs}  \
      --initworldmat=${InitWorldMat} \
      --scannerpatientposition=${ScannerPatientPosition} \
      --truepatientposition=${TruePatientPosition} \
      --species=${SPECIES} \
      --betspecieslabel=${betspecieslabel} \
      --brainscalefactor=${BrainScaleFactor} \
      --runmode=${RunMode}"

      if [ $DryRun = FALSE ] ; then
        echo ". ${EnvironmentScript}"
      fi
    fi
   done
 done 

 if   [[ "${RunMode}" = 4 ]] ; then

    ${HCPPIPEDIR}/fMRIVolume/GenericfMRIVolumeMotionCorrectXRunsNHP.sh $StudyFolder $Subject $AllfMRINames -x

 elif [[ "${RunMode}" = 5 ]] ; then

    ${HCPPIPEDIR}/fMRIVolume/GenericfMRIVolumeMotionCorrectXRunsNHP.sh $StudyFolder $Subject $AllfMRINames -r ${BBR} 

 fi
done


