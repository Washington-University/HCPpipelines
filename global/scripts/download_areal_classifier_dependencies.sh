#!/bin/bash
set -eu

scriptloc="$(dirname "$0")"

if [ "$1" = "ARENA_v1" ]; then
    cd "$scriptloc"/../../ArealClassifier/data/arena_v1/
    wget -O arena_v1_weights.zip 'https://balsa.wustl.edu/myelin/download?dirName=public&filepath=ArealClassifierWeights%2Farena_v1_weights.zip&dirPass='
    unzip -o arena_v1_weights.zip -q
elif [ "$1" = "ARENA_v2" ]; then
    cd "$scriptloc"/../../ArealClassifier/data/arena_v2/
    wget -O arena_v2_weights.zip 'https://balsa.wustl.edu/myelin/download?dirName=public&filepath=ArealClassifierWeights%2Farena_v2_weights.zip&dirPass='
    unzip -o arena_v2_weights.zip -q
elif [ "$1" = "MATLAB" ]; then
    cd "$scriptloc"/../../ArealClassifier/data/mlp_classifier/
    wget -O mlp_weights.zip 'https://balsa.wustl.edu/myelin/download?dirName=public&filepath=ArealClassifierWeights%2Fmlp_weights.zip&dirPass='
    unzip -o mlp_weights.zip -q
elif [ "$1" = "MMP_ROIs" ]; then
    cd "$scriptloc"/../../ArealClassifier/data/HCP_MMP_ROIs/
    wget -O HCP_MMP_ROIs.zip 'https://balsa.wustl.edu/myelin/download?dirName=public&filepath=ArealClassifierWeights%2FHCP_MMP_ROIs.zip&dirPass='
    unzip -o HCP_MMP_ROIs.zip -q
else
    echo "Error: invalid input '$1'. Expected ARENA_v1, ARENA_v2, MATLAB, or MMP_ROIs." >&2
    return 1 2>/dev/null || exit 1
fi