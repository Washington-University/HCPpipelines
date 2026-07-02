StudyFolder="${HOME}/projects/HCPpipelines_ExampleData"
Sessionlist="100307 100610"
EnvironmentScript="${HOME}/projects/HCPpipelines/Examples/Scripts/SetUpHCPPipeline.sh" #Pipeline environment script

source "${EnvironmentScript}"
QUEUE=""

for Session in ${Sessionlist}; do
    echo "Launching MMORF registration for session ${Session}"
    $FSLDIR/bin/fsl_sub \
    -q ${QUEUE} \
    mmorf \
    --config=${StudyFolder}/${Session}/MMORFNonLinear/xfms/T1w_acpc_dc_restore.ini
done