#!/bin/bash
set -eux

scriptdir=$(dirname "$0")

function compile_function()
{
    local funcName="$1"
    shift 1
    local outdir="$scriptdir"/Compiled_"$funcName"
    mkdir -p "$outdir"
    "$MATLAB_HOME"/bin/mcc -m -v "$funcName".m "$@" -d "$outdir"
}

#addpath() adds to the front, while -I adds to the back, so reverse the order

compile_function RSNregression \
    -I "$scriptdir" \
    -I "$HCPPIPEDIR/global/matlab" \
    -I "$HCPPIPEDIR/global/matlab/nets_spectra" \
    -I "$HCPCIFTIRWDIR" \
    -I "$HCPPIPEDIR/global/fsl/etc/matlab"

