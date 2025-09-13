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

compile_function AFI_GroupAverageCorrectedMaps \
    -I "$scriptdir" \
    -I "$HCPPIPEDIR/global/matlab" \
    -I "$HCPCIFTIRWDIR" \
    -I "$HCPPIPEDIR/global/fsl/etc/matlab"
compile_function AFI_GroupAverage \
    -I "$scriptdir" \
    -I "$HCPPIPEDIR/global/matlab" \
    -I "$HCPCIFTIRWDIR" \
    -I "$HCPPIPEDIR/global/fsl/etc/matlab"
compile_function AFI_OptimizeSmoothing \
    -I "$scriptdir" \
    -I "$HCPPIPEDIR/global/matlab" \
    -I "$HCPCIFTIRWDIR" \
    -I "$HCPPIPEDIR/global/fsl/etc/matlab"

compile_function B1Tx_GroupAverageCorrectedMaps \
    -I "$scriptdir" \
    -I "$HCPPIPEDIR/global/matlab" \
    -I "$HCPCIFTIRWDIR" \
    -I "$HCPPIPEDIR/global/fsl/etc/matlab"
compile_function B1Tx_GroupAverage \
    -I "$scriptdir" \
    -I "$HCPPIPEDIR/global/matlab" \
    -I "$HCPCIFTIRWDIR" \
    -I "$HCPPIPEDIR/global/fsl/etc/matlab"
compile_function B1Tx_OptimizeSmoothing \
    -I "$scriptdir" \
    -I "$HCPPIPEDIR/global/matlab" \
    -I "$HCPCIFTIRWDIR" \
    -I "$HCPPIPEDIR/global/fsl/etc/matlab"

compile_function PseudoTransmit_GroupAverageCorrectedMaps \
    -I "$scriptdir" \
    -I "$HCPPIPEDIR/global/matlab" \
    -I "$HCPCIFTIRWDIR" \
    -I "$HCPPIPEDIR/global/fsl/etc/matlab"
compile_function PseudoTransmit_GroupAverage \
    -I "$scriptdir" \
    -I "$HCPPIPEDIR/global/matlab" \
    -I "$HCPCIFTIRWDIR" \
    -I "$HCPPIPEDIR/global/fsl/etc/matlab"
compile_function PseudoTransmit_OptimizeSmoothing \
    -I "$scriptdir" \
    -I "$HCPPIPEDIR/global/matlab" \
    -I "$HCPCIFTIRWDIR" \
    -I "$HCPPIPEDIR/global/fsl/etc/matlab"

