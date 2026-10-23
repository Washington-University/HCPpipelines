#!/bin/bash 

# --------------------------------------------------------------------------------
#  Usage Description Function
# --------------------------------------------------------------------------------

script_name=$(basename "${0}")

show_usage() {
    cat <<EOF

${script_name}: Sub-script of GenericHippocampusfMRISurfaceProcessingPipeline.sh

EOF
}


# Allow script to return a Usage statement, before any other output or checking
if [[ "$#" = "0" ]]; then
    show_usage
    exit 1
fi

# ------------------------------------------------------------------------------
#  Check that HCPPIPEDIR is defined and Load Function Libraries
# ------------------------------------------------------------------------------

if [[ -z "${HCPPIPEDIR}" ]]; then
    echo "${script_name}: ABORTING: HCPPIPEDIR environment variable must be set"
    exit 1
fi

source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@"         # Debugging functions; also sources log.shlib
source "${HCPPIPEDIR}/global/scripts/opts.shlib"                # Command line option functions

opts_ShowVersionIfRequested "$@"

if opts_CheckForHelpRequest "$@"; then
    show_usage
    exit 0
fi

# ------------------------------------------------------------------------------
#  Start work
# ------------------------------------------------------------------------------

ResultsFolder="$1"
WorkingDirectory="$2"
Session="$3"
HippUnfoldFolder="$4"
VolumefMRI="$5"
SBRef="$6"
doGoodVoxels="$7"
Factor="$8" # Factor is a scaling factor for how many std units away from mean to set threshold
TargetMesh="$9" #Converting native mesh to hippunfold 2k. Future releases might support other mesh resolutions.

NeighborhoodSmoothing="5"   # Distinguishes large vs small dropout
dilation_dist="10"

WorkingDirectory="${ResultsFolder}/HippocampalVolumeToSurfaceMapping"

# ------------------------------------------------------------------------------
#  Generating mean, std, and coefficient of variation metric maps
# ------------------------------------------------------------------------------

# Generate baseline reference, temporal standard deviation, and CV.
MeanVolume="${VolumefMRI%.nii.gz}_mean.nii.gz"
if [[ -f "${MeanVolume}" ]]; then
    fslmaths "${MeanVolume}" -nan "${WorkingDirectory}/${Session}.mean" -odt float
else
    fslmaths "${VolumefMRI}" -nan -Tmean "${WorkingDirectory}/${Session}.mean" -odt float
fi
fslmaths "${VolumefMRI}" -nan -Tstd "${WorkingDirectory}/${Session}.std" -odt float
fslmaths "${WorkingDirectory}/${Session}.std" -div "${WorkingDirectory}/${Session}.mean" -nan "${WorkingDirectory}/${Session}.cov" -odt float

for Structure in hipp dentate; do
    for Hemisphere in L R; do
        # ------------------------------------------------------------------------------
        #  Establishing input and output files
        # ------------------------------------------------------------------------------

        Prefix="${Session}.${Hemisphere}.${Structure}"

        ThicknessMetric="${HippUnfoldFolder}/Native/${Prefix}_thickness.native.shape.gii"
        InnerSurface="${HippUnfoldFolder}/Native/${Prefix}_inner.native.surf.gii"
        MidSurface="${HippUnfoldFolder}/Native/${Prefix}_midthickness.native.surf.gii"
        OuterSurface="${HippUnfoldFolder}/Native/${Prefix}_outer.native.surf.gii"

        OnesMetric="${WorkingDirectory}/${Prefix}_ones.native.func.gii"
        ProbabilisticRibbon="${WorkingDirectory}/${Prefix}.ribbon_probabilistic.nii.gz"
        BinaryRibbon="${WorkingDirectory}/${Prefix}.ribbon.nii.gz"


        # ------------------------------------------------------------------------------
        #  Generating an all-ones surface metric
        # ------------------------------------------------------------------------------

        wb_command -metric-math '1' "${OnesMetric}" -var x "${ThicknessMetric}"

        # ------------------------------------------------------------------------------
        #  Mapping the all-ones metric into SBRef volume space using the inner and
        #  outer surfaces as ribbon boundaries
        # ------------------------------------------------------------------------------

        wb_command -metric-to-volume-mapping "${OnesMetric}" "${MidSurface}" "${SBRef}" "${ProbabilisticRibbon}" -ribbon-constrained "${InnerSurface}" "${OuterSurface}"

        # ------------------------------------------------------------------------------
        #  Thresholding the fractional ribbon at greater than 0 to create a binary mask
        # ------------------------------------------------------------------------------

        wb_command -volume-math "x > 0" "${BinaryRibbon}" -var x "${ProbabilisticRibbon}"

        # ------------------------------------------------------------------------------
        #  Generating good-voxel mask for each structure
        # ------------------------------------------------------------------------------

        if [[ "${doGoodVoxels}" == "YES" ]]; then

            fslmaths "${WorkingDirectory}/${Session}.cov" -mas "${BinaryRibbon}" "${WorkingDirectory}/${Prefix}_cov_ribbon"
            meanIntensity=$(fslstats "${WorkingDirectory}/${Prefix}_cov_ribbon" -M)
            fslmaths "${WorkingDirectory}/${Prefix}_cov_ribbon" -div ${meanIntensity} "${WorkingDirectory}/${Prefix}_cov_ribbon_norm"
            fslmaths "${WorkingDirectory}/${Prefix}_cov_ribbon_norm" -bin -s "${NeighborhoodSmoothing}" "${WorkingDirectory}/${Prefix}_SmoothNorm"
            fslmaths "${WorkingDirectory}/${Prefix}_cov_ribbon_norm" -s "${NeighborhoodSmoothing}" -div "${WorkingDirectory}/${Prefix}_SmoothNorm" -dilD "${WorkingDirectory}/${Prefix}_cov_ribbon_norm_s${NeighborhoodSmoothing}"
            fslmaths "${WorkingDirectory}/${Session}.cov" -div ${meanIntensity} -div "${WorkingDirectory}/${Prefix}_cov_ribbon_norm_s${NeighborhoodSmoothing}" "${WorkingDirectory}/${Prefix}_cov_norm_modulate"
            fslmaths "${WorkingDirectory}/${Prefix}_cov_norm_modulate" -mas "${BinaryRibbon}" "${WorkingDirectory}/${Prefix}_cov_norm_modulate_ribbon"

            STD=$(fslstats "${WorkingDirectory}/${Prefix}_cov_norm_modulate_ribbon" -S)
            echo "STD: ${STD}"
            MEAN=$(fslstats "${WorkingDirectory}/${Prefix}_cov_norm_modulate_ribbon" -M)
            echo "MEAN: ${MEAN}"
            Upper=$(echo "${MEAN} + (${STD} * ${Factor})" | bc -l)
            echo "UPPER: ${Upper}"

            fslmaths "${WorkingDirectory}/${Session}.mean" -bin "${WorkingDirectory}/${Prefix}_mask"
            fslmaths "${WorkingDirectory}/${Prefix}_cov_norm_modulate" -thr "${Upper}" -bin -sub "${WorkingDirectory}/${Prefix}_mask" -mul -1 -mas "${BinaryRibbon}" "${WorkingDirectory}/${Prefix}_goodvoxels"
        fi


        NativeFolder="${HippUnfoldFolder}/Native"

        InnerSurface="${NativeFolder}/${Prefix}_inner.native.surf.gii"
        MidSurface="${NativeFolder}/${Prefix}_midthickness.native.surf.gii"
        OuterSurface="${NativeFolder}/${Prefix}_outer.native.surf.gii"

        NativeFlat="${NativeFolder}/${Prefix}_flat.native.surf.gii"

        # =====================================================================
        # Map mean and covariance volumes
        # =====================================================================

        for Map in mean cov; do
            NativeMetric="${WorkingDirectory}/${Prefix}_${Map}.native.func.gii"
            NativeAllMetric="${WorkingDirectory}/${Prefix}_${Map}_all.native.func.gii"

            # -----------------------------------------------------------------
            # Map using good voxels
            # -----------------------------------------------------------------

            if [[ "${doGoodVoxels}" == "YES" ]]; then
                wb_command -volume-to-surface-mapping "${WorkingDirectory}/${Session}.${Map}.nii.gz" "${MidSurface}" "${NativeMetric}" \
                    -ribbon-constrained "${InnerSurface}" "${OuterSurface}" -volume-roi "${WorkingDirectory}/${Prefix}_goodvoxels.nii.gz" -dilate-missing ${dilation_dist} -nearest
            else

                wb_command -volume-to-surface-mapping "${WorkingDirectory}/${Session}.${Map}.nii.gz" "${MidSurface}" "${NativeMetric}" \
                    -ribbon-constrained "${InnerSurface}" "${OuterSurface}" -dilate-missing ${dilation_dist} -nearest
            fi

            wb_command -metric-dilate "${NativeMetric}" "${MidSurface}" "${dilation_dist}" "${NativeMetric}" -nearest

            # -----------------------------------------------------------------
            # Map using all ribbon voxels
            # -----------------------------------------------------------------

            wb_command -volume-to-surface-mapping "${WorkingDirectory}/${Session}.${Map}.nii.gz" "${MidSurface}" "${NativeAllMetric}" \
                -ribbon-constrained "${InnerSurface}" "${OuterSurface}" -dilate-missing ${dilation_dist} -nearest

            # -----------------------------------------------------------------
            # Resample native metrics using unfolded flat surfaces
            # -----------------------------------------------------------------


            MeshFolder="${HippUnfoldFolder}/${TargetMesh}"

            TargetFlat="${MeshFolder}/${Prefix}_flat.${TargetMesh}.surf.gii"
            TargetMidSurface="${MeshFolder}/${Prefix}_midthickness.${TargetMesh}.surf.gii"
            TargetMetric="${WorkingDirectory}/${Prefix}_${Map}.${TargetMesh}.func.gii"
            TargetAllMetric="${WorkingDirectory}/${Prefix}_${Map}_all.${TargetMesh}.func.gii"

            wb_command -metric-resample "${NativeMetric}" "${NativeFlat}" "${TargetFlat}" ADAP_BARY_AREA "${TargetMetric}" \
                -area-surfs "${MidSurface}" "${TargetMidSurface}" -bypass-sphere-check
            wb_command -metric-resample "${NativeAllMetric}" "${NativeFlat}" "${TargetFlat}" ADAP_BARY_AREA "${TargetAllMetric}" \
                -area-surfs "${MidSurface}" "${TargetMidSurface}" -bypass-sphere-check
        done

        # =====================================================================
        # Map goodvoxels in volume space
        # =====================================================================

        if [[ "${doGoodVoxels}" == "YES" ]]; then

            NativeGoodVoxels="${WorkingDirectory}/${Prefix}_goodvoxels.native.func.gii"

            wb_command -volume-to-surface-mapping "${WorkingDirectory}/${Prefix}_goodvoxels.nii.gz" "${MidSurface}" "${NativeGoodVoxels}" \
                -ribbon-constrained "${InnerSurface}" "${OuterSurface}" -dilate-missing ${dilation_dist} -nearest

            MeshFolder="${HippUnfoldFolder}/${TargetMesh}"

            TargetFlat="${MeshFolder}/${Prefix}_flat.${TargetMesh}.surf.gii"
            TargetMidSurface="${MeshFolder}/${Prefix}_midthickness.${TargetMesh}.surf.gii"
            TargetGoodVoxels="${WorkingDirectory}/${Prefix}_goodvoxels.${TargetMesh}.func.gii"


            wb_command -metric-resample "${NativeGoodVoxels}" "${NativeFlat}" "${TargetFlat}" ADAP_BARY_AREA "${TargetGoodVoxels}" \
                -area-surfs "${MidSurface}" "${TargetMidSurface}" -bypass-sphere-check
        fi

        # =====================================================================
        # Map complete fMRI timeseries to native hippocampal surface
        # =====================================================================

            MeshFolder="${HippUnfoldFolder}/Native"
            TargetfMRI="${WorkingDirectory}/${Prefix}_fMRI.native.func.gii"
            TargetMidSurface="${MeshFolder}/${Prefix}_midthickness.native.surf.gii"

            # Map fMRI volume to native surface
            if [[ "${doGoodVoxels}" == "YES" ]]; then
                wb_command -volume-to-surface-mapping "${VolumefMRI}" "${TargetMidSurface}" "${TargetfMRI}" -ribbon-constrained "${InnerSurface}" "${OuterSurface}" \
                    -volume-roi "${WorkingDirectory}/${Prefix}_goodvoxels.nii.gz" -dilate-missing "${dilation_dist}" -nearest
            else
                wb_command -volume-to-surface-mapping "${VolumefMRI}" "${TargetMidSurface}" "${TargetfMRI}" \
                    -ribbon-constrained "${InnerSurface}" "${OuterSurface}" -dilate-missing "${dilation_dist}" -nearest
            fi
            NativefMRI="${TargetfMRI}"
            log_Msg "Generated fMRI file in native mesh at: ${TargetfMRI}"

            # Dilate = native mesh fMRI
            wb_command -metric-dilate "${TargetfMRI}" "${TargetMidSurface}" "${dilation_dist}" "${TargetfMRI}" -nearest

            MeshFolder="${HippUnfoldFolder}/${TargetMesh}"
            TargetfMRI="${WorkingDirectory}/${Prefix}_fMRI.${TargetMesh}.func.gii"
            TargetFlat="${MeshFolder}/${Prefix}_flat.${TargetMesh}.surf.gii"
            TargetMidSurface="${MeshFolder}/${Prefix}_midthickness.${TargetMesh}.surf.gii"
            # Resample native fMRI surface to target mesh
            wb_command -metric-resample "${NativefMRI}" "${NativeFlat}" "${TargetFlat}" ADAP_BARY_AREA "${TargetfMRI}" \
                -area-surfs "${MidSurface}" "${TargetMidSurface}" -bypass-sphere-check
            log_Msg "Generated fMRI file in mesh resolution ${TargetMesh} at: ${TargetfMRI}"
            # Dilate target-mesh fMRI
            wb_command -metric-dilate "${TargetfMRI}" "${TargetMidSurface}" "${dilation_dist}" "${TargetfMRI}" -nearest


        # =====================================================================
        # Map VN volume to native hippocampal surface
        # =====================================================================
        VolumefMRIVN="${VolumefMRI%.nii.gz}_vn.nii.gz"

        if [[ ! -f "${VolumefMRIVN}" ]]; then
            log_Err_Abort "Cannot find VN volume: ${VolumefMRIVN}"
        fi

        FiniteVolumefMRIVN="${WorkingDirectory}/${Session}_vn_finite.nii.gz"

        fslmaths "${VolumefMRIVN}" -thr -1e30 -uthr 1e30 -nan "${FiniteVolumefMRIVN}" #Thresholding inf and -inf and replacing nan with 0

        NativefMRIVN="${WorkingDirectory}/${Prefix}_fMRI_vn.native.func.gii"
        MeshFolder="${HippUnfoldFolder}/Native"
        TargetFlat="${MeshFolder}/${Prefix}_flat.native.surf.gii"
        TargetMidSurface="${MeshFolder}/${Prefix}_midthickness.native.surf.gii"

        # Map VN volume to native surface
        wb_command -volume-to-surface-mapping "${FiniteVolumefMRIVN}" "${TargetMidSurface}" "${NativefMRIVN}" -cubic

        log_Msg "Generated VN file in native mesh at: ${NativefMRIVN}"

        MeshFolder="${HippUnfoldFolder}/${TargetMesh}"
        TargetFlat="${MeshFolder}/${Prefix}_flat.${TargetMesh}.surf.gii"
        TargetMidSurface="${MeshFolder}/${Prefix}_midthickness.${TargetMesh}.surf.gii"
        TargetfMRIVN="${WorkingDirectory}/${Prefix}_fMRI_vn.${TargetMesh}.func.gii"

        # Resample native VN surface to other mesh surface
        wb_command -metric-resample "${NativefMRIVN}" "${NativeFlat}" "${TargetFlat}" ADAP_BARY_AREA "${TargetfMRIVN}" -area-surfs "${MidSurface}" "${TargetMidSurface}" -bypass-sphere-check

        log_Msg "Generated VN file in ${TargetMesh} mesh at: ${TargetfMRIVN}"
    done
done

# =====================================================================
# Combine the four surface metrics into CIFTIs, then remove the GIFTIs
# =====================================================================

for Mesh in native ${TargetMesh}; do
    Maps="mean cov mean_all cov_all fMRI fMRI_vn"

    if [[ "${doGoodVoxels}" == "YES" ]]; then
        Maps="${Maps} goodvoxels"
    fi

    for Map in ${Maps}; do
        LeftHipp="${WorkingDirectory}/${Session}.L.hipp_${Map}.${Mesh}.func.gii"
        RightHipp="${WorkingDirectory}/${Session}.R.hipp_${Map}.${Mesh}.func.gii"
        LeftDentate="${WorkingDirectory}/${Session}.L.dentate_${Map}.${Mesh}.func.gii"
        RightDentate="${WorkingDirectory}/${Session}.R.dentate_${Map}.${Mesh}.func.gii"

        if [[ "${Map}" == "fMRI" ]]; then
            OutputCifti="${WorkingDirectory}/${Session}.${Mesh}.dtseries.nii"
            TR=$(fslval "${VolumefMRI}" pixdim4)
            wb_command -cifti-create-dense-timeseries "${OutputCifti}" -timestep "${TR}" -metric HIPPOCAMPUS_LEFT "${LeftHipp}" -metric HIPPOCAMPUS_RIGHT "${RightHipp}" -metric HIPPOCAMPUS_DENTATE_LEFT "${LeftDentate}" -metric HIPPOCAMPUS_DENTATE_RIGHT "${RightDentate}"
        else

            OutputCifti="${WorkingDirectory}/${Session}_${Map}.${Mesh}.dscalar.nii"
            wb_command -cifti-create-dense-scalar "${OutputCifti}" -metric HIPPOCAMPUS_LEFT "${LeftHipp}" -metric HIPPOCAMPUS_RIGHT "${RightHipp}" -metric HIPPOCAMPUS_DENTATE_LEFT "${LeftDentate}" -metric HIPPOCAMPUS_DENTATE_RIGHT "${RightDentate}"
        fi

        if [[ -f "${OutputCifti}" ]]; then
            rm "${LeftHipp}" "${RightHipp}" "${LeftDentate}" "${RightDentate}"
            log_Msg "Created ${OutputCifti}"
        fi
    done
done

# Remove the all-ones metrics after ribbon mapping is complete.
for Structure in hipp dentate; do
    for Hemisphere in L R; do
        rm "${WorkingDirectory}/${Session}.${Hemisphere}.${Structure}_ones.native.func.gii"
    done
done

log_Msg "HippocampalVolumeToSurfaceMapping.sh completed"
