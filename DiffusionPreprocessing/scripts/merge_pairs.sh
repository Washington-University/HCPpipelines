#!/usr/bin/env bash
#
# Merges the individually processed data pairs into a single diffusion image
# Called from DiffusionPreprocessing/DiffPreprocPipeline_Split.sh
#
set -e
echo -e "\n START: merge_split"

workingdir=$1
DWIName=$2
NPairs=$3


mkdir -p ${workingdir}/${DWIName}

#
# Merges the individual images
#
echo "merging data"
cmd="fslmerge -t ${workingdir}/${DWIName}/data"
for ImageIndex in $(seq 1 ${NPairs} ) ; do
    cmd+=" ${workingdir}/${DWIName}_scan${ImageIndex}/data"
done
${cmd}

mean_image()
{
    echo "computing mean of $1"
    cmd="fsladd ${workingdir}/${DWIName}/$1 -m"
    for ImageIndex in $(seq 1 ${NPairs} ) ; do
        cmd+=" ${workingdir}/${DWIName}_scan${ImageIndex}/$1"
    done
    ${cmd}
}

mean_image nodif_brain_mask
# include voxels based on majority voting (erring on the side of inclusion)
fslmaths ${workingdir}/${DWIName}/nodif_brain_mask -thr 0.49 -bin ${workingdir}/${DWIName}/nodif_brain_mask

if [ -f ${workingdir}/${DWIName}_scan1/grad_dev.nii* ]; then
    mean_image grad_dev
fi


#
# Merges the individual b-values and b-vectors
#
merge_text()
{
	echo "merging $1"
	cmd="paste"
	for ImageIndex in $(seq 1 ${NPairs} ) ; do
		cmd+=" ${workingdir}/${DWIName}_scan${ImageIndex}/$1"
	done
	${cmd} >${workingdir}/${DWIName}/$1
}

merge_text bvals
merge_text bvecs

echo -e "\n END: merge_split"

