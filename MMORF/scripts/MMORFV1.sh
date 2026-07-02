set -uo pipefail
# Load helpers
#####Several advantages for this design#####
##Does not need to create an extra file
##The defaults are all sectioned. Thus if you want to change defaults, you can create another one with different parameters and use if to add to arglist##
##If you want to do multiple tensors for some reason or add extra scalars, it is relatively easy to change this code##

source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/debug.shlib" "$@"
opts_SetScriptDescription "Run MMORF registration for multiple sessions in parallel"
opts_AddMandatory '--workingdir' 'WD' 'path' 'working directory' "."
opts_AddMandatory '--refmask' 'ReferenceMask' 'mask' 'reference brain mask'
opts_AddMandatory '--DTIref' 'DTIref' 'mask' 'reference for DTI'
opts_AddMandatory '--DTIrefmask' 'DTIrefMask' 'mask' 'reference brain mask for DTI'
opts_AddMandatory "--DTImask" "DTImask" "image" "Mask for DTI"
opts_AddMandatory '--ref' 'Reference1' 'image' 'reference image'
opts_AddMandatory '--ref2' 'Reference2' 'image' 'reference image 2'
opts_AddMandatory '--t1rest' 'T1wRestore' 'image' 'bias corrected t1w image'
opts_AddMandatory '--t2rest' 'T2wRestore' 'image' 'bias corrected t2w image'
opts_AddMandatory "--Diffusion" "Diffusion" "image" "Diffusion including bvecs, bvals, and data.nii.gz"

opts_ParseArguments "$@"

DTI=${Diffusion}/data_tensor.nii.gz
brainmaskedited=$WD/TMP/brainmask_fs_transformed.nii.gz

warp_default_args=(
                    --warp_res_init 32
                    --warp_scaling 1 1 2 2 2 2 2
                    --lambda_reg 4.0e5 3.7e-1 3.1e-1 2.6e-1 2.2e-1 1.8e-1 1.5e-1
                    --hires 3.9
                    --optimiser_max_it_lowres 5
                    --optimiser_max_it_hires 5
)

scalar_default_args=(
                    --aff_ref_scalar ${FSLDIR}/etc/flirtsch/ident.mat
                    --aff_mov_scalar ${WD}/xfms/acpc2MMORFLinear.mat
                    --use_implicit_mask 0
                    --use_mask_ref_scalar 1 1 1 1 1 1 1
                    --use_mask_mov_scalar 0 0 0 0 0 0 0
                    --mask_ref_scalar ${ReferenceMask}
                    --mask_mov_scalar ${brainmaskedited}
                    --fwhm_ref_scalar 8.0 8.0 4.0 2.0 1.0 0.5 0.25
                    --fwhm_mov_scalar 8.0 8.0 4.0 2.0 1.0 0.5 0.25
                    --lambda_scalar 1 1 1 1 1 1 1
                    --estimate_bias 1
                    --bias_res_init 16
                    --lambda_bias_reg 1e9 1e9 1e9 1e9 1e9 1e9 1e9
)



tensor_default_args=(
                    --aff_ref_tensor ${FSLDIR}/etc/flirtsch/ident.mat
                    --aff_mov_tensor ${WD}/xfms/acpc2MMORFLinear.mat
                    --use_mask_ref_tensor 1 1 1 1 1 1 1
                    --use_mask_mov_tensor 1 1 1 1 1 1 1
                    --mask_ref_tensor ${DTIrefMask}
                    --mask_mov_tensor ${DTImask}
                    --fwhm_ref_tensor 8.0 8.0 4.0 2.0 1.0 0.5 0.25
                    --fwhm_mov_tensor 8.0 8.0 4.0 2.0 1.0 0.5 0.25
                    --lambda_tensor 1 1 1 1 1 1 1
)

arglist=()
arglist+=(--img_warp_space ${Reference1})
arglist+=(${warp_default_args[@]})
arglist+=(--img_ref_scalar ${Reference1})
arglist+=(--img_mov_scalar ${T1wRestore})
arglist+=(${scalar_default_args[@]})
arglist+=(--img_ref_scalar ${Reference2})
arglist+=(--img_mov_scalar ${T2wRestore})
arglist+=(${scalar_default_args[@]})
arglist+=(--img_ref_tensor ${DTIref})
arglist+=(--img_mov_tensor ${DTI})
arglist+=(${tensor_default_args[@]})
arglist+=(--warp_out ${WD}/xfms/mov_to_ref_mm_warp)
arglist+=(--jac_det_out ${WD}/xfms/mov_to_ref_mm_jac)
arglist+=(--bias_out ${WD}/xfms/mov_to_ref_mm_bias)

${FSLDIR}/bin/mmorf "${arglist[@]}"
