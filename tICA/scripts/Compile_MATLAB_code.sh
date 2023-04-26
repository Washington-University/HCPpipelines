#!/bin/bash
set -eux

scriptdir=$(dirname "$0")

function compile_function()
{
    local funcName="$1"
    shift 1
    local outdir="$scriptdir"/Compiled_"$funcName"
    mkdir -p "$outdir"
    "$MATLAB_HOME"/bin/mcc -m -R -nodisplay -v "$funcName".m "$@" -d "$outdir"
}

#addpath() adds to the front, while -I adds to the back, so reverse the order
#icasso uses feval with a default function of sim2dis (which it implements), without pragmas to help the compiler, so add it here so we don't forget if we update icasso

compile_function MIGP \
    -I "$HCPCIFTIRWDIR" \
    -I "$scriptdir" \
    -I "$HCPPIPEDIR/global/matlab"

compile_function GroupSICA \
    -I "$HCPCIFTIRWDIR" \
    -I "$scriptdir" \
    -I "$scriptdir/FastICA_25" \
    -I "$scriptdir/icasso122" \
    -a "$scriptdir/icasso122/sim2dis.m" \
    -a "$scriptdir/icasso122/sqrtsim2dis.m" \
    -I "$HCPPIPEDIR/global/matlab" \
    -I "$HCPPIPEDIR/global/matlab/icaDim"

compile_function ConcatGroupSICA \
    -I "$HCPCIFTIRWDIR" \
    -I "$scriptdir" \
    -I "$scriptdir/FastICA_25" \
    -I "$scriptdir/icasso122" \
    -a "$scriptdir/icasso122/sim2dis.m" \
    -a "$scriptdir/icasso122/sqrtsim2dis.m" \
    -I "$HCPPIPEDIR/global/matlab" \
    -I "$HCPPIPEDIR/global/matlab/icaDim"

compile_function ComputeGroupTICA \
    -I "$HCPCIFTIRWDIR" \
    -I "$scriptdir" \
    -I "$scriptdir/FastICA_25" \
    -I "$scriptdir/icasso122" \
    -a "$scriptdir/icasso122/sim2dis.m" \
    -a "$scriptdir/icasso122/sqrtsim2dis.m" \
    -I "$HCPPIPEDIR/global/matlab" \
    -I "$HCPPIPEDIR/global/matlab/nets_spectra" \
    -I "$HCPPIPEDIR/global/matlab/icaDim"

compile_function ComputeTICAFeatures \
    -I "$scriptdir" \
    -I "$scriptdir/feature_helpers" \
    -I "$HCPCIFTIRWDIR" \
    -I "$HCPPIPEDIR/global/matlab"

compile_function tICACleanData \
    -I "$scriptdir" \
    -I "$HCPCIFTIRWDIR" \
    -I "$HCPPIPEDIR/global/matlab" \
    -I "$HCPPIPEDIR/global/fsl/etc/matlab"

