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

#source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@"         # Debugging functions; also sources log.shlib
source "${HCPPIPEDIR}/global/scripts/log.shlib" "$@"            # Debugging functions; also sources log.shlib
source "${HCPPIPEDIR}/global/scripts/opts.shlib"                # Command line option functions

opts_ShowVersionIfRequested "$@"

if opts_CheckForHelpRequest "$@"; then
    show_usage
    exit 0
fi

# ------------------------------------------------------------------------------
#  Verify required environment variables are set and log value
# ------------------------------------------------------------------------------

log_Check_Env_Var HCPPIPEDIR
log_Check_Env_Var CARET7DIR

# ------------------------------------------------------------------------------
#  Start work
# ------------------------------------------------------------------------------

WorkingDirectory="$1"
Subject="$2"
HippUnfoldFolder="$3"
VolumefMRI="$4"
SBRef="$5"
doGoodVoxels="$6"
Factor="$7"
#Factor="1"                 # Factor is a scaling factor for how many std units away from mean to set threshold
NeighborhoodSmoothing="5"   # Distinguishes large vs small dropout
dilation_dist="10"

Meshes=(512 2k 8k 18k)

WB="${CARET7DIR}/wb_command"

mkdir -p "${WorkingDirectory}"

FirstRibbon="YES"

# ------------------------------------------------------------------------------
#  Generating mean, std, and coefficient of variation metric maps
# ------------------------------------------------------------------------------

fslmaths "${VolumefMRI}" \
    -Tmean "${WorkingDirectory}/${Subject}.mean" \
    -odt float

fslmaths "${VolumefMRI}" \
    -Tstd "${WorkingDirectory}/${Subject}.std" \
    -odt float

fslmaths "${WorkingDirectory}/${Subject}.std" \
    -div "${WorkingDirectory}/${Subject}.mean" \
    "${WorkingDirectory}/${Subject}.cov"


for Structure in hipp dentate; do

    for Hemisphere in L R; do

        # ------------------------------------------------------------------------------
        #  Establishing input and output files
        # ------------------------------------------------------------------------------

        Prefix="${Subject}.${Hemisphere}.${Structure}"

        ThicknessMetric="${HippUnfoldFolder}/native/${Prefix}_thickness.native.shape.gii"

        InnerSurface="${HippUnfoldFolder}/native/${Prefix}_inner.native.surf.gii"
        MidSurface="${HippUnfoldFolder}/native/${Prefix}_midthickness.native.surf.gii"
        OuterSurface="${HippUnfoldFolder}/native/${Prefix}_outer.native.surf.gii"

        OnesMetric="${WorkingDirectory}/${Prefix}_ones.native.func.gii"
        ProbabilisticRibbon="${WorkingDirectory}/${Prefix}.ribbon_probabilistic.nii.gz"
        BinaryRibbon="${WorkingDirectory}/${Prefix}.ribbon.nii.gz"


        # ------------------------------------------------------------------------------
        #  Generating an all-ones surface metric
        # ------------------------------------------------------------------------------

        "${WB}" -metric-math \
            '1' \
            "${OnesMetric}" \
            -var x \
            "${ThicknessMetric}"


        # ------------------------------------------------------------------------------
        #  Mapping the all-ones metric into SBRef volume space using the inner and
        #  outer surfaces as ribbon boundaries
        # ------------------------------------------------------------------------------

        "${WB}" -metric-to-volume-mapping \
            "${OnesMetric}" \
            "${MidSurface}" \
            "${SBRef}" \
            "${ProbabilisticRibbon}" \
            -ribbon-constrained \
                "${InnerSurface}" \
                "${OuterSurface}"


        # ------------------------------------------------------------------------------
        #  Thresholding the fractional ribbon at greater than 0 to create a binary mask
        # ------------------------------------------------------------------------------

        "${WB}" -volume-math \
            "x > 0" \
            "${BinaryRibbon}" \
            -var x \
            "${ProbabilisticRibbon}"


        # ------------------------------------------------------------------------------
        #  Generating good-voxel mask for each structure
        # ------------------------------------------------------------------------------

        if [[ "${doGoodVoxels}" == "YES" ]]; then

            fslmaths "${WorkingDirectory}/${Subject}.cov" \
                -mas "${BinaryRibbon}" \
                "${WorkingDirectory}/${Prefix}_cov_ribbon"

            meanIntensity=$(fslstats "${WorkingDirectory}/${Prefix}_cov_ribbon" -M)

            fslmaths "${WorkingDirectory}/${Prefix}_cov_ribbon" \
                -div ${meanIntensity} \
                "${WorkingDirectory}/${Prefix}_cov_ribbon_norm"

            fslmaths "${WorkingDirectory}/${Prefix}_cov_ribbon_norm" \
                -bin \
                -s "${NeighborhoodSmoothing}" \
                "${WorkingDirectory}/${Prefix}_SmoothNorm"

            fslmaths "${WorkingDirectory}/${Prefix}_cov_ribbon_norm" \
                -s "${NeighborhoodSmoothing}" \
                -div "${WorkingDirectory}/${Prefix}_SmoothNorm" \
                -dilD \
                "${WorkingDirectory}/${Prefix}_cov_ribbon_norm_s${NeighborhoodSmoothing}"

            fslmaths "${WorkingDirectory}/${Subject}.cov" \
                -div ${meanIntensity} \
                -div "${WorkingDirectory}/${Prefix}_cov_ribbon_norm_s${NeighborhoodSmoothing}" \
                "${WorkingDirectory}/${Prefix}_cov_norm_modulate"

            fslmaths "${WorkingDirectory}/${Prefix}_cov_norm_modulate" \
                -mas "${BinaryRibbon}" \
                "${WorkingDirectory}/${Prefix}_cov_norm_modulate_ribbon"

            STD=$(fslstats \
                "${WorkingDirectory}/${Prefix}_cov_norm_modulate_ribbon" \
                -S)

            echo "STD: ${STD}"

            MEAN=$(fslstats \
                "${WorkingDirectory}/${Prefix}_cov_norm_modulate_ribbon" \
                -M)

            echo "MEAN: ${MEAN}"

            Lower=$(echo "${MEAN} - (${STD} * ${Factor})" | bc -l)
            echo "LOWER: ${Lower}"

            Upper=$(echo "${MEAN} + (${STD} * ${Factor})" | bc -l)
            echo "UPPER: ${Upper}"

            fslmaths "${WorkingDirectory}/${Subject}.mean" \
                -bin \
                "${WorkingDirectory}/${Prefix}_mask"

            fslmaths "${WorkingDirectory}/${Prefix}_cov_norm_modulate" \
                -thr "${Upper}" \
                -bin \
                -sub "${WorkingDirectory}/${Prefix}_mask" \
                -mul -1 \
                -mas "${BinaryRibbon}" \
                "${WorkingDirectory}/${Prefix}_goodvoxels"
        fi


        NativeFolder="${HippUnfoldFolder}/native"

        InnerSurface="${NativeFolder}/${Prefix}_inner.native.surf.gii"
        MidSurface="${NativeFolder}/${Prefix}_midthickness.native.surf.gii"
        OuterSurface="${NativeFolder}/${Prefix}_outer.native.surf.gii"

        NativeFlat="${NativeFolder}/${Prefix}_flat.native.surf.gii"
        NativeSurfArea="${NativeFolder}/${Prefix}_surfarea.native.shape.gii"

        NativeROI="${WorkingDirectory}/${Prefix}_ones.native.func.gii"


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

                "${WB}" -volume-to-surface-mapping \
                    "${WorkingDirectory}/${Subject}.${Map}.nii.gz" \
                    "${MidSurface}" \
                    "${NativeMetric}" \
                    -ribbon-constrained \
                        "${InnerSurface}" \
                        "${OuterSurface}" \
                        -volume-roi "${WorkingDirectory}/${Prefix}_goodvoxels.nii.gz" \
                        -dilate-missing ${dilation_dist} \
                            -nearest

            else

                "${WB}" -volume-to-surface-mapping \
                    "${WorkingDirectory}/${Subject}.${Map}.nii.gz" \
                    "${MidSurface}" \
                    "${NativeMetric}" \
                    -ribbon-constrained \
                        "${InnerSurface}" \
                        "${OuterSurface}" \
                        -dilate-missing ${dilation_dist} \
                            -nearest
            fi

            "${WB}" -metric-dilate \
                "${NativeMetric}" \
                "${MidSurface}" \
                "${dilation_dist}" \
                "${NativeMetric}" \
                -nearest

            "${WB}" -metric-mask \
                "${NativeMetric}" \
                "${NativeROI}" \
                "${NativeMetric}"


            # -----------------------------------------------------------------
            # Map using all ribbon voxels
            # -----------------------------------------------------------------

            "${WB}" -volume-to-surface-mapping \
                "${WorkingDirectory}/${Subject}.${Map}.nii.gz" \
                "${MidSurface}" \
                "${NativeAllMetric}" \
                -ribbon-constrained \
                    "${InnerSurface}" \
                    "${OuterSurface}" \
                    -dilate-missing ${dilation_dist} \
                        -nearest

            "${WB}" -metric-mask \
                "${NativeAllMetric}" \
                "${NativeROI}" \
                "${NativeAllMetric}"


            # -----------------------------------------------------------------
            # Resample native metrics using unfolded flat surfaces
            # -----------------------------------------------------------------

            for Mesh in ${Meshes[@]}; do

                MeshFolder="${HippUnfoldFolder}/${Mesh}"

                TargetFlat="${MeshFolder}/${Prefix}_flat.${Mesh}.surf.gii"
                TargetMidSurface="${MeshFolder}/${Prefix}_midthickness.${Mesh}.surf.gii"
                TargetSurfArea="${MeshFolder}/${Prefix}_surfarea.${Mesh}.shape.gii"

                TargetROI="${WorkingDirectory}/${Prefix}_ones.${Mesh}.func.gii"

                TargetMetric="${WorkingDirectory}/${Prefix}_${Map}.${Mesh}.func.gii"
                TargetAllMetric="${WorkingDirectory}/${Prefix}_${Map}_all.${Mesh}.func.gii"


                "${WB}" -metric-math \
                    "x * 0 + 1" \
                    "${TargetROI}" \
                    -var x "${TargetSurfArea}"


                "${WB}" -metric-resample \
                    "${NativeMetric}" \
                    "${NativeFlat}" \
                    "${TargetFlat}" \
                    ADAP_BARY_AREA \
                    "${TargetMetric}" \
                    -area-surfs \
                        "${MidSurface}" \
                        "${TargetMidSurface}" \
                    -current-roi "${NativeROI}" \
                    -bypass-sphere-check

                "${WB}" -metric-mask \
                    "${TargetMetric}" \
                    "${TargetROI}" \
                    "${TargetMetric}"


                "${WB}" -metric-resample \
                    "${NativeAllMetric}" \
                    "${NativeFlat}" \
                    "${TargetFlat}" \
                    ADAP_BARY_AREA \
                    "${TargetAllMetric}" \
                    -area-surfs \
                        "${MidSurface}" \
                        "${TargetMidSurface}" \
                    -current-roi "${NativeROI}" \
                    -bypass-sphere-check

                "${WB}" -metric-mask \
                    "${TargetAllMetric}" \
                    "${TargetROI}" \
                    "${TargetAllMetric}"

            done
        done

        # =====================================================================
        # Map goodvoxels in volume space
        # =====================================================================

        if [[ "${doGoodVoxels}" == "YES" ]]; then

            NativeGoodVoxels="${WorkingDirectory}/${Prefix}_goodvoxels.native.func.gii"

            "${WB}" -volume-to-surface-mapping \
                "${WorkingDirectory}/${Prefix}_goodvoxels.nii.gz" \
                "${MidSurface}" \
                "${NativeGoodVoxels}" \
                -ribbon-constrained \
                    "${InnerSurface}" \
                    "${OuterSurface}" \
                    -dilate-missing ${dilation_dist} \
                        -nearest

            "${WB}" -metric-mask \
                "${NativeGoodVoxels}" \
                "${NativeROI}" \
                "${NativeGoodVoxels}"


            for Mesh in ${Meshes[@]}; do

                MeshFolder="${HippUnfoldFolder}/${Mesh}"

                TargetFlat="${MeshFolder}/${Prefix}_flat.${Mesh}.surf.gii"
                TargetMidSurface="${MeshFolder}/${Prefix}_midthickness.${Mesh}.surf.gii"
                TargetROI="${WorkingDirectory}/${Prefix}_ones.${Mesh}.func.gii"

                TargetGoodVoxels="${WorkingDirectory}/${Prefix}_goodvoxels.${Mesh}.func.gii"


                "${WB}" -metric-resample \
                    "${NativeGoodVoxels}" \
                    "${NativeFlat}" \
                    "${TargetFlat}" \
                    ADAP_BARY_AREA \
                    "${TargetGoodVoxels}" \
                    -area-surfs \
                        "${MidSurface}" \
                        "${TargetMidSurface}" \
                    -current-roi "${NativeROI}" \
                    -bypass-sphere-check

                "${WB}" -metric-mask \
                    "${TargetGoodVoxels}" \
                    "${TargetROI}" \
                    "${TargetGoodVoxels}"

            done

        fi


        # =====================================================================
        # Map complete fMRI timeseries to native hippocampal surface
        # =====================================================================

        NativefMRI="${WorkingDirectory}/${Prefix}_fMRI.native.func.gii"


        if [[ "${doGoodVoxels}" == "YES" ]]; then

            "${WB}" -volume-to-surface-mapping \
                "${VolumefMRI}.nii.gz" \
                "${MidSurface}" \
                "${NativefMRI}" \
                -ribbon-constrained \
                    "${InnerSurface}" \
                    "${OuterSurface}" \
                    -volume-roi "${WorkingDirectory}/${Prefix}_goodvoxels.nii.gz" \
                    -dilate-missing ${dilation_dist} \
                        -nearest

        else

            "${WB}" -volume-to-surface-mapping \
                "${VolumefMRI}.nii.gz" \
                "${MidSurface}" \
                "${NativefMRI}" \
                -ribbon-constrained \
                    "${InnerSurface}" \
                    "${OuterSurface}" \
                    -dilate-missing ${dilation_dist} \
                        -nearest

        fi

        "${WB}" -metric-dilate \
            "${NativefMRI}" \
            "${MidSurface}" \
            "${dilation_dist}" \
            "${NativefMRI}" \
            -nearest

        "${WB}" -metric-mask \
            "${NativefMRI}" \
            "${NativeROI}" \
            "${NativefMRI}"

        log_Msg "Generated fMRI file in native space at: ${NativefMRI}"


        # =====================================================================
        # Resample complete fMRI timeseries to all densities
        # =====================================================================

        for Mesh in ${Meshes[@]}; do

            MeshFolder="${HippUnfoldFolder}/${Mesh}"

            TargetFlat="${MeshFolder}/${Prefix}_flat.${Mesh}.surf.gii"
            TargetMidSurface="${MeshFolder}/${Prefix}_midthickness.${Mesh}.surf.gii"
            TargetROI="${WorkingDirectory}/${Prefix}_ones.${Mesh}.func.gii"

            TargetfMRI="${WorkingDirectory}/${Prefix}_fMRI.${Mesh}.func.gii"


            "${WB}" -metric-resample \
                "${NativefMRI}" \
                "${NativeFlat}" \
                "${TargetFlat}" \
                ADAP_BARY_AREA \
                "${TargetfMRI}" \
                -area-surfs \
                    "${MidSurface}" \
                    "${TargetMidSurface}" \
                -current-roi "${NativeROI}" \
                -bypass-sphere-check


            "${WB}" -metric-dilate \
                "${TargetfMRI}" \
                "${TargetMidSurface}" \
                ${dilation_dist} \
                "${TargetfMRI}" \
                -nearest


            "${WB}" -metric-mask \
                "${TargetfMRI}" \
                "${TargetROI}" \
                "${TargetfMRI}"


            log_Msg "Generated fMRI file in ${Mesh} mesh at: ${TargetfMRI}"

            # =====================================================================
            # Map VN volume to native hippocampal surface
            # =====================================================================

            VolumefMRIVN="${VolumefMRI}_vn.nii.gz"
            TargetfMRIVN="${WorkingDirectory}/${Prefix}_fMRI_vn.${Mesh}.func.gii"

            "${WB}" -volume-to-surface-mapping \
                "${VolumefMRIVN}" \
                "${TargetMidSurface}" \
                "${TargetfMRIVN}" \
                -cubic

            "${WB}" -metric-mask \
                "${TargetfMRIVN}" \
                "${TargetROI}" \
                "${TargetfMRIVN}"

            log_Msg "Generated VN file in ${Mesh} mesh at: ${TargetfMRIVN}"
        done
    done
done

