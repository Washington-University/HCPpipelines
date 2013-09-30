#!/bin/sh
set -e
echo -e "\n START: PrepareSeeds"

if [ "$1" == "" ];then
    echo ""
    echo "PrepareSeeds.sh <Studyfolder> <SubjectID>"
    echo ""
    exit 1
fi

StudyFolder=$1
subj=$2
MNINonLinearFolder="${StudyFolder}/${subj}/MNINonLinear"
ROIsFolder="${StudyFolder}/${subj}/MNINonLinear/Results/Tractography"
#ROIsFolder="${StudyFolder}/${subj}/MNINonLinear/ROIs"
prepare_seeds() {
    tmp=`$FSLDIR/bin/tmpnam`
    cat <<EOM > $tmp
    addpath('/home/fs0/stam/matlab');
    addpath('/home/fs0/stam/matlab/CIFTIMatlabReaderWriter_old');
    addpath('/home/fs0/saad/matlab/surfops');
    addpath('/home/fs0/saad/matlab');
    unix(['mkdir -p ${ROIsFolder}']);
    
    fname=['/vols/Scratch/saad/example_gifti_cifti/example.dtseries.nii'];
    [cifti,BM]=open_wbfile2(fname);
    T=size(cifti.cdata,2);
    gii=gifti(['${MNINonLinearFolder}/fsaverage_LR32k/${subj}.L.white.32k_fs_LR.surf.gii']);
    vf.vertices=gii.vertices;vf.faces=gii.faces;
    vf.FaceVertexCData=zeros(size(vf.vertices,1),1);
    vf.FaceVertexCData(BM{1}.SurfaceIndices)=1;
    surfwrite(vf,['${ROIsFolder}/white.L.asc']);
    unix(['echo ${ROIsFolder}/white.L.asc > ${ROIsFolder}/surfseeds_L']);

    gii=gifti(['${MNINonLinearFolder}/fsaverage_LR32k/${subj}.R.white.32k_fs_LR.surf.gii']);
    vf.vertices=gii.vertices;vf.faces=gii.faces;
    vf.FaceVertexCData=zeros(size(vf.vertices,1),1);
    vf.FaceVertexCData(BM{2}.SurfaceIndices)=1;
    surfwrite(vf,['${ROIsFolder}/white.R.asc']);
    unix(['echo ${ROIsFolder}/white.R.asc > ${ROIsFolder}/surfseeds_R']);

    std=read_avw([getenv('FSLDIR') '/data/standard/MNI152_T1_2mm_brain']);
    unix(['rm -f ${ROIsFolder}/volseeds']);
    for i=3:length(BM)
        disp(BM{i}.BrainStructure);
        out=0*std;
        x=BM{i}.VolumeIndicesIJK;
        j=sub2ind(size(std),x(:,1),x(:,2),x(:,3));
        out(j)=1;
        save_avw(out,['${ROIsFolder}/' BM{i}.BrainStructure],'i',[2 2 2]);
        unix(['fslcpgeom ' getenv('FSLDIR') '/data/standard/MNI152_T1_2mm_brain  ${ROIsFolder}/' BM{i}.BrainStructure]);
        unix(['echo ${ROIsFolder}/' BM{i}.BrainStructure ' >> ${ROIsFolder}/volseeds']);
    end
    hemis={'L' 'R'};
    for i=1:2
        roi=gifti(['${MNINonLinearFolder}/fsaverage_LR32k/${subj}.' hemis{i} '.atlasroi.32k_fs_LR.shape.gii']);
        pial=gifti(['${MNINonLinearFolder}/fsaverage_LR32k/${subj}.' hemis{i} '.pial.32k_fs_LR.surf.gii']);
        vfc.vertices=pial.vertices;
        vfc.faces=pial.faces;
        vfc.FaceVertexCData=roi.cdata;
        surfwrite(vfc,['${ROIsFolder}/' hemis{i} '.roi.asc']);    
    end
    unix(['echo ${ROIsFolder}/L.roi.asc > ${ROIsFolder}/stop']);
    unix(['echo ${ROIsFolder}/R.roi.asc >> ${ROIsFolder}/stop']);
EOM
    nohup matlab < $tmp > `$FSLDIR/bin/tmpnam`
}

prepare_seeds

echo -e "\n END: PrepareSeeds"
