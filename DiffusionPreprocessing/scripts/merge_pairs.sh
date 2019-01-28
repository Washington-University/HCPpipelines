#!/usr/bin/env bash
#
# Merges the individually processed data pairs into a single diffusion image
# Called from DiffusionPreprocessing/DiffPreprocPipeline_Merge.sh
#

set -e

outdir=$1
indirs="${@:2}"

mkdir -p ${outdir}

#
# Merges the individual images
#
echo "merging data"
cmd="${FSLDIR}/bin/fslmerge -t ${outdir}/${DWIName}/data"
for indir in ${indirs} ; do
    cmd+=" ${indir}/data"
done
${cmd}

mean_image()
{
    echo "computing mean of $1"
	local error_msgs=""
    cmd="${FSLDIR}/bin/fsladd ${outdir}/$1 -m"
    for indir in ${indirs} ; do
        cmd+=" ${indir}/$1"
    done
    ${cmd}
}

mean_image nodif_brain_mask
# include voxels based on majority voting (erring on the side of inclusion)
${FSLDIR}/bin/fslmaths ${outdir}/nodif_brain_mask -thr 0.49 -bin ${outdir}/nodif_brain_mask

if [ -f ${indir}/grad_dev.nii* ]; then
    mean_image grad_dev
fi


#
# Merges the individual b-values and b-vectors
#
merge_text()
{
	echo "merging $1"
	cmd="paste"
    for indir in ${indirs} ; do
		cmd+=" ${indir}/$1"
	done
	${cmd} >${indir}/$1
}

merge_text bvals
merge_text bvecs

echo -e "\n END: merge_pairs"

