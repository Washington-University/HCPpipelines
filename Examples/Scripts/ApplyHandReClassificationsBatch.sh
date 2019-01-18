
StudyFolder="${HOME}/projects/Pipelines_ExampleData" #Location of Subject folders (named by subjectID)
Subjlist="100307" #Space delimited list of subject IDs

# List of fMRI runs
# If running on output from multi-run FIX, use ConcatName as value for fMRINames
fMRINames="rfMRI_REST1_LR rfMRI_REST1_RL rfMRI_REST2_LR rfMRI_REST2_RL"

HighPass="2000"

for Subject in ${Subjlist} ; do
  for fMRIName in ${fMRINames} ; do
    ${HCPPIPEDIR}/ICAFIX/ApplyHandReClassifications.sh ${StudyFolder} ${Subject} ${fMRIName} ${HighPass}
#    echo "set -- ${StudyFolder} ${Subject} ${fMRIName} ${HighPass}"
  done
done

