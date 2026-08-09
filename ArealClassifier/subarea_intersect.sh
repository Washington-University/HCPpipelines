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

opts_SetScriptDescription "finds the expected label intersections between motor/sensory areas and face/trunk/etc subregions"

opts_AddMandatory '--workingdir' 'workdir' 'folder' "what folder to put intermediate files in"
opts_AddMandatory '--area-dlabel' 'areadlabel' 'file' "the dlabel containing the cortical areas, without subcortical structure labels"
opts_AddMandatory '--subregion-dlabel' 'subregiondlabel' 'file' "the dlabel containing the subregions"
opts_AddMandatory '--cifti-template' 'ciftitemplate' 'file' "a cifti file with the desired output grayordinates space"
opts_AddMandatory '--left-surface' 'leftsurface' 'file' "left surface for dilation"
opts_AddMandatory '--right-surface' 'rightsurface' 'file' "right surface for dilation"
opts_AddOptional '--left-corrected-areas' 'leftcorrareas' 'file' "if the surfaces are group average surfaces, this gifti file should contain the group average of the individuals' vertex areas, in order to correct for loss of folding detail"
opts_AddOptional '--right-corrected-areas' 'rightcorrareas' 'file' "similar to --left-corrected-areas"
opts_AddMandatory '--intersection-out' 'intersectionout' 'file' "the intersected dlabel file with subareas and unrelated cortical areas, without subcortical labels"
opts_AddOptional '--subcortical-structures' 'subcortvol' 'file' "volume file containing subcortical structures"
opts_AddOptional '--intersection-plus-subcortical-out' 'intersectionsubcortout' 'file' "--intersection-out, plus the subcortical structures"

opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

#display the parsed/default values
opts_ShowValues

if [[ "$intersectionsubcortout" != "" ]]
then
    if [[ "$subcortvol" == "" || "$ciftitemplate" == "" ]]
    then
        log_Err_Abort "--intersection-plus-subcortical-out requires --subcortical-structures and --cifti-template"
    fi
fi

if [[ ("$leftcorrareas" == "" && "$rightcorrareas" != "") || \
      ("$leftcorrareas" != "" && "$rightcorrareas" == "") ]]
then
    log_Err_Abort "you should specify either both or neither of --left-corrected-areas and --right-corrected-areas"
fi

smallareawarn=20

#NOTE: this array also sets key ordering for the intersection labels
expected_intersections=(1_Face 1_UpperExtremity 1_Trunk 1_LowerExtremity 2_UpperExtremity 2_Trunk 2_LowerExtremity 3a_Face 3a_Ocular 3a_UpperExtremity 3a_Trunk 3a_LowerExtremity 3b_Face 3b_UpperExtremity 3b_Trunk 3b_LowerExtremity 4_Face 4_Ocular 4_UpperExtremity 4_Trunk 4_LowerExtremity)

mkdir -p "$workdir"/intersections

tempfiles_create subarea_intersect_cortical_ROIs_XXXXXX.dscalar.nii corticalrois
tempfiles_create subarea_intersect_subregion_ROIs_XXXXXX.dscalar.nii subregionrois

wb_command -cifti-all-labels-to-rois "$areadlabel" \
    1 \
    "$corticalrois"

wb_command -cifti-all-labels-to-rois "$subregiondlabel" \
    1 \
    "$subregionrois"

for hem in L R
do
    #not all areas overlap with all subregionss...test them all, then compare to expected
    #L_4_ROI
    for areaname in 1 2 3a 3b 4
    do
        #L_M1S1Face_ROI
        for subregionname in Face Ocular UpperExtremity Trunk LowerExtremity
        do
            wb_command -cifti-math 'x && y' "$workdir"/intersections/intersect_"$hem"_"$areaname"_"$subregionname".dscalar.nii \
                -var x "$corticalrois" -select 1 "$hem"_"$areaname"_ROI \
                -var y "$subregionrois" -select 1 "$hem"_M1S1"$subregionname"_ROI > /dev/null
            
            mapcount=$(wb_command -cifti-stats "$workdir"/intersections/intersect_"$hem"_"$areaname"_"$subregionname".dscalar.nii -reduce SUM)

            if ((mapcount > 0))
            then
                #MFG: "ocular 3b" is tiny and doesn't make sense, original labels had some overlap, but newer results seem to say it isn't there, so let's put it into ocular 3a
                if [[ "$areaname" == "3b" && "$subregionname" == "Ocular" ]]
                then
                    wb_command -cifti-math 'x || y' "$workdir"/intersections/intersect_"$hem"_3a_"$subregionname".dscalar.nii \
                        -var x "$workdir"/intersections/intersect_"$hem"_"$areaname"_"$subregionname".dscalar.nii \
                        -var y "$workdir"/intersections/intersect_"$hem"_3a_"$subregionname".dscalar.nii > /dev/null
                    
                    continue
                fi
                
                #HACK: there are no spaces in the area or subregion names, can use grep as a fast "set contains"
                #NOTE: the spaces around these expressions are intentional, prevents it from potentially matching a substring of another intersection (though probably not possible in this limited set)
                if ! (IFS=" "; echo " ${expected_intersections[*]} " | grep -q " $areaname"_"$subregionname ")
                then
                    echo "WARNING: intersection found between area $areaname and subregion $subregionname, this is not present in the group, and it is unknown what intersection to reassign it to; will be arbitrarily replaced by dilation" 1>&2
                fi
                if ((mapcount < smallareawarn))
                then
                    echo "INFO: intersection of area $areaname and subregion $subregionname contains only $mapcount vertices"
                fi
            else
                if (IFS=" "; echo " ${expected_intersections[*]} " | grep -q " $areaname"_"$subregionname ")
                then
                    echo "INFO: intersection expected but not found between area $areaname and subregion $subregionname"
                fi
            fi
        done
    done
done

#modify old keys before adding the new ones
#areas to remove: 1 2 3a 3b 4
#keys in MMP 1.0: 51 52 53 9 8 231 232 233 189 188, right 1-180, then left

removeareas=(1 2 3a 3b 4)
wb_command -cifti-label-export-table "$areadlabel" \
    1 \
    "$workdir"/origlabels.txt

function orig_label_to_key()
{
    local name="$1"
    grep -A 1 "$name" "$workdir"/origlabels.txt | tail -n 1 | cut -f1 -d' '
}

removekeys=()
for hem in L R
do
    for name in "${removeareas[@]}"
    do
        removekeys+=($(orig_label_to_key "$hem"_"$name"_ROI) )
    done
done

removekeyssorted=($(IFS=$'\n'; echo "${removekeys[*]}" | sort -n) )

tempfiles_create subarea_intersect_hemrangecheck_L_XXXXXX.label.gii leftrangecheck
tempfiles_create subarea_intersect_hemrangecheck_R_XXXXXX.label.gii rightrangecheck

wb_command -cifti-separate "$areadlabel" COLUMN \
    -label CORTEX_RIGHT "$rightrangecheck" \
    -label CORTEX_LEFT "$leftrangecheck"
rightmaxarea=$(wb_command -metric-stats "$rightrangecheck" -reduce MAX)
leftmaxarea=$(wb_command -metric-stats "$leftrangecheck" -reduce MAX)

rightfirst=$((rightmaxarea < leftmaxarea))
if ((rightfirst))
then
    split=$rightmaxarea
    last=$leftmaxarea
else
    split=$leftmaxarea
    last=$rightmaxarea
fi

removeindex=0
for ((i = 1; i <= last; ++i))
do
    if ((removeindex < ${#removekeyssorted[@]} && i == removekeyssorted[removeindex]))
    then
        #remap it to a high number
        newkey=$((i + last + 1000))
        removeindex=$((removeindex + 1))
    else
        newkey=$((i - removeindex))
        if ((i > split))
        then
            #note: number of intersections for one hemisphere, not both
            newkey=$((newkey + ${#expected_intersections[@]}))
        fi
    fi
    #don't add a line if it wouldn't change the key
    if ((i != newkey))
    then
        echo "$i $newkey"
    fi
done > "$workdir"/shufflekeys.txt

wb_command -cifti-label-modify-keys "$areadlabel" \
    "$workdir"/shufflekeys.txt \
    "$workdir"/shufflekeys.dlabel.nii

#threshold out the areas, which have been moved to the end of the key range
wb_command -cifti-math "x * (x < 1000 + $last)" "$workdir"/zeroedkeys.dlabel.nii \
    -var x "$workdir"/shufflekeys.dlabel.nii

wb_command -cifti-label-export-table "$workdir"/shufflekeys.dlabel.nii 1 "$workdir"/shuffletable.txt

#combine intersect ROIs into labels

cp "$workdir"/zeroedkeys.dlabel.nii "$workdir"/zeroedkeys_mod.dlabel.nii

if ((rightfirst))
then
    i=$((rightmaxarea + 1 - ${#removeareas[@]}))
else
    i=$((rightmaxarea + 1 - 2 * ${#removeareas[@]} + ${#expected_intersections[@]}))
fi
for name in "${expected_intersections[@]}"
do
    wb_command -cifti-math "(! roi) * data + (roi > 0) * $i" "$workdir"/zeroedkeys_mod.dlabel.nii \
        -var data "$workdir"/zeroedkeys_mod.dlabel.nii \
        -var roi "$workdir"/intersections/intersect_R_"$name".dscalar.nii > /dev/null

    echo "R_${name}_ROI" >> "$workdir"/shuffletable.txt
    #grab original color from area name
    areaname=$(echo "$name" | cut -f1 -d_)
    colornums=$(grep -A 1 "R_${areaname}_ROI" "$workdir"/origlabels.txt | tail -n 1 | cut -f2- -d' ')
    echo "$i $colornums" >> "$workdir"/shuffletable.txt

    i=$((i + 1))
done

if ((rightfirst))
then
    i=$((leftmaxarea + 1 - 2 * ${#removeareas[@]} + ${#expected_intersections[@]}))
else
    i=$((leftmaxarea + 1 - ${#removeareas[@]}))
fi
for name in "${expected_intersections[@]}"
do
    wb_command -cifti-math "(! roi) * data + (roi > 0) * $i" "$workdir"/zeroedkeys_mod.dlabel.nii \
        -var data "$workdir"/zeroedkeys_mod.dlabel.nii \
        -var roi "$workdir"/intersections/intersect_L_"$name".dscalar.nii > /dev/null
    
    echo "L_${name}_ROI" >> "$workdir"/shuffletable.txt
    #grab original color from area name
    areaname=$(echo "$name" | cut -f1 -d_)
    colornums=$(grep -A 1 "L_${areaname}_ROI" "$workdir"/origlabels.txt | tail -n 1 | cut -f2- -d' ')
    echo "$i $colornums" >> "$workdir"/shuffletable.txt

    i=$((i + 1))
done

tempfiles_create subarea_intersect_raw_intersection_XXXXXX.dlabel.nii rawintersect

#MFG: keep cortical output whatever cifti space the input was
wb_command -cifti-label-import "$workdir"/zeroedkeys_mod.dlabel.nii \
    "$workdir"/shuffletable.txt \
    "$rawintersect" \
    -drop-unused-labels

#dilate to fix vertices the subregions missed
if [[ "$leftcorrareas" == "" ]]
then
    wb_command -cifti-dilate \
        "$rawintersect" \
        COLUMN 5 0 \
        "$intersectionout" \
        -left-surface "$leftsurface" \
        -right-surface "$rightsurface"
else
    wb_command -cifti-dilate \
        "$rawintersect" \
        COLUMN 5 0 \
        "$intersectionout" \
        -left-surface "$leftsurface" \
            -left-corrected-areas "$leftcorrareas" \
        -right-surface "$rightsurface" \
            -right-corrected-areas "$rightcorrareas"
fi

if [[ "$intersectionsubcortout" != "" ]]
then
    wb_command -cifti-create-dense-from-template \
        "$ciftitemplate" \
        "$intersectionsubcortout" \
        -cifti "$intersectionout" \
        -volume-all "$subcortvol" \
        -label-collision SURFACES_FIRST
fi

