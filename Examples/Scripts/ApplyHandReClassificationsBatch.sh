Subjlist="M126 M128 M129 M131 M132" #Space delimited list of subject IDs
Subjlist="M132" #Space delimited list of subject IDs
StudyFolder="/media/myelin/brainmappers/Connectome_Project/InVivoMacaques" #Location of Subject folders (named by subjectID)

FunctionalNames="rfMRI_REST"
FunctionalNames="rfMRI_REST_iso"

HighPass="2000"
GitRepo="/media/2TBB/Connectome_Project/Pipelines"

for Subject in ${Subjlist} ; do
  for FunctionalName in ${FunctionalNames} ; do
    "$GitRepo"/ApplyHandReClassifications.sh ${StudyFolder} ${Subject} ${FunctionalName} ${HighPass}
    echo "set -- ${StudyFolder} ${Subject} ${FunctionalName} ${HighPass}"
  done
done

