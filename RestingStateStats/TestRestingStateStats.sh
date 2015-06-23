#!/bin/bash

source /home/HCPpipeline/SCRIPTS/SetUpHCPPipeline_MSM_All.sh

./RestingStateStats.sh \
 --path=${BUILD_DIR}/MSM_All_test \
 --subject=100307 \
 --fmri-name=rfMRI_REST1_LR \
 --high-pass=2000 \
 --low-res-mesh=32 \
 --final-fmri-res=2 \
 --brain-ordinates-res=2 \
 --smoothing-fwhm=2 \
 --output-proc-string="_hp2000_clean"