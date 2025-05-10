#!/bin/bash
set -eu

pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
    pipedirguessed=1
    export HCPPIPEDIR="$(dirname -- "$0")/../.."
fi

source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/debug.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/tempfiles.shlib" "$@"

opts_SetScriptDescription "Performs Gaussian mixture modeling on precomputed ICs, as volume or dscalar"

opts_AddMandatory '--input' 'inFile0' 'file' "input file name"
opts_AddMandatory '--output' 'outFile0' 'file' "output filename"

opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

opts_ShowValues

# See also:
# https://www.jiscmail.ac.uk/cgi-bin/webadmin?A2=fsl;6e85d498.1607
# https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/MELODIC#Using_melodic_for_just_doing_mixture-modelling
# https://www.fmrib.ox.ac.uk/datasets/techrep/tr02cb1/tr02cb1.pdf
#
# Created by Burke Rosen
# 2024-07-08
# Dependencies: workbench, FSL
# Written with workbench 2.0 and FSL 6.0.7.1
# Refactored from matlab to bash 2025-05-09 by Copilot GPT-4.1 and TSC-1.0
#
# ToDo:
# Feed arbitrary melodic arguments.

tDir
tDir=$(mktemp -d)

ciftiinput=0
inFile="$inFile0"
# convert input if needed
case "$inFile0" in
    (*.dscalar.nii)
        # convert input cifti to nifti
        ciftiinput=1
        #self-cleaning temporaries
        tempfiles_create mixtureModel_fakenifti_XXXXXX.nii inFile
        wb_command -cifti-convert -to-nifti "$inFile0" "$inFile" -smaller-dims
        for ((i = 1; i <= 3; ++i))
        do
            thisdim=$(fslval "$inFile" dim$i)
            if ((thisdim == 1))
            then
                log_Warn "singleton dimension in converted nifti, melodic may not interpret correctly!"
                break
            fi
        done
        ;;
    (*.nii | *.nii.gz)
        ;;
    (*)
        log_Err_Abort "--input is not a nifti or dscalar cifti?"
        ;;
esac

outFile="$outFile0"
ciftioutput=0
case "$outFile0" in
    (*.dscalar.nii)
        ciftioutput=1
        if ((! ciftiinput))
        then
            log_Err_Abort "cifti output only supported for cifti input."
        fi
        #we don't call other scripts, and this doesn't affect any parent processes, don't need to change it back
        export FSLOUTPUTTYPE=NIFTI
        tempfiles_create mixtureModel_fakeniftiout_XXXXXX.nii outFile
        ;;
    (*.nii)
        export FSLOUTPUTTYPE=NIFTI
        ;;
    (*.nii.gz)
        export FSLOUTPUTTYPE=NIFTI_GZ
        ;;
    (*)
        log_Err_Abort "--output is not a nifti or dscalar cifti?"
        ;;
esac

# run gaussian mixture modeling with melodic
mkdir -p "$tDir"
echo "1" > "$tDir/grot"
melodic -i "$inFile" --ICs="$inFile" --mix="$tDir/grot" -o "$tDir" --Oall --report -v --mmthresh=0

# check for multiple z-score maps
allfiles=("$tDir"/stats/thresh_zstat*)
for file in "${allfiles[@]}"
do
    mapCount=$(fslval "$file" dim4 | tr -d ' ')
    if ((mapCount > 1))
    then
        log_Warn "warning: At least one component returned two z-score maps (alpha = 0.05 and 0.01)! Using first map only."
        break
    fi
done
# concatenate volumes
wb_shortcuts -volume-concatenate -map 1 "${outFile}" $(IFS=$'\n'; echo "${allfiles[*]}" | sort -V)

# clean up temporary files
rm -r "$tDir"

# convert output to cifti, if needed
if ((ciftioutput))
then
    wb_command -cifti-convert -from-nifti "${outFile}" "$inFile0" "$outFile0"
fi

