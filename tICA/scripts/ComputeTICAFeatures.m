function [features, other_features]=ComputeTICAFeatures(StudyFolder, GroupAverageName, SubjListName, ...
                                                        fMRIListName, OutputfMRIName, tICAdim, ...
                                                        fMRIProcString, tICAFeaturesProcString, ...
                                                        Resolution, RegString, LowResMesh, ...
                                                        ToSave, ...
                                                        hp, MRFixConcatName, RecleanMode, ...
                                                        ConfigFilePath, HelpFuncPath, ...
                                                        CorticalParcellationFile, ParcelReorderFile, ...
                                                        NiftiTemplateFile, VascularTerritoryFile, ...
                                                        VesselProbMapFile, MultiBandKspaceMapFile, ...
                                                        PerfusionFile, ArrivalAtlasFile)
% Compute features for tICA components
% Usage:
%   >> features=ComputeTICAFeatures(StudyFolder,GroupAverageName,...)
%    
%  Input:
%     StudyFolder: string, the full path of study folder to use,
%     GroupAverageName: string, the group output folder name 
%     SubjListName: string, .txt file path including all the subject names
%     fMRIListName: string, .txt file path including all the fMRI run names
%     OutputfMRIName: name to use for tICA pipeline outputs
%     tICAdim: string, the dimension after tICA decomposition
%     fMRIProcString: string, file name component representing the
%     preprocessing already done, like '_hp0_clean'
%     tICAFeaturesProcString: string, processing string name representing the 
%     task, dimension, number of Wisharts, group average name and weighted regression
%     already done, like  'rfMRI_REST_d84_WF6_GROUPAVERAGENAME_WR_tICA'
%     Resolution: string, resolution of data, like '2' or '1.60'
%     RegString: the registration string corresponding to the input files, like '_MSMAll'
%     LowResMesh: string, mesh resolution, like '32' for 32k_fs_LR
%     ToSave: string, 'YES' or 'NO', indicator of whether to save the
%     feature files in output folder
%     hp: string, like '2000' or '0', high pass filter parameter
%     MRFixConcatName: string, if MultiRunFIX is applied, specify the
%     concat fMRI name
%     RecleanMode: string, 'YES' or 'NO', indicator of whether sICA dataset has
%     been recleaned
%     ConfigFilePath: string, template directory path, the location of
%     freesurfer ROI files
%     HelpFuncPath: string, help function location from launch script
%     CorticalParcellationFile: string, template file path, the HCP-MMP1.0 cortical
%     parcellation file
%     ParcelReorderFile: string, template file path, the parcel reorder file
%     NiftiTemplateFile: string, template file path, the nifti template file to use
%     VascularTerritoryFile: string, template file path, the label file for vascular territory
%     VesselProbMapFile: string, template file path, the probabilistic map file for vessel
%     MultiBandKspaceMapFile: string, template file path, the .mat file for multiband features in kspace
%     
%  Output:
%     features: table, the output table consisting of all the features
%     other_features: matlab struct, the output consisting of all the other
%     useful features that takes huge amounts of time to regenerate

%if isdeployed()
    %all arguments are actually strings, though 'tICAdim' gets turned into an integer below
%end

% hard coded
nonlinear='tanhF';
wbcommand='wb_command';
Dilate='5.0';

Subjlist = myreadtext(SubjListName);
fMRINames = myreadtext(fMRIListName);
tICAdim=fix(str2num(tICAdim));
% default files

MultiBandKspaceMaskStruct=load(MultiBandKspaceMapFile,'multiband_nuisance_mask');
MultiBandKspaceMaskOrig=MultiBandKspaceMaskStruct.multiband_nuisance_mask;
MultiBandKspaceMask=reshape(MultiBandKspaceMaskStruct.multiband_nuisance_mask,[],1);
resolution=str2double(Resolution);
%erode_mm=cell(1,8);
erode_mm=cell(1,5);
c=1;
%for i=[1.25 1.75 2.25 2.75 3.25 3.75 4.25 4.75] save for testing, could be
%useful for ring effect
for i=[1 2 3 4 5]
    erode_mm{c}=num2str(resolution*i,'%.2f');
    c=c+1;
end

% read necessary files
disp('reading necessary files as beginning...')
OutputFolder=[StudyFolder '/' GroupAverageName '/MNINonLinear/Results/' OutputfMRIName '/tICA_d' num2str(tICAdim)];

tICAMaps=ciftiopen([OutputFolder '/tICA_Maps_' num2str(tICAdim) '_' nonlinear '.dscalar.nii'], wbcommand);
tICAVolMaps=ciftiopen([OutputFolder '/tICA_VolMaps_' num2str(tICAdim) '_' nonlinear '.dscalar.nii'], wbcommand);
tICAtcsmean=ciftiopen([OutputFolder '/tICA_AVGTCS_' num2str(tICAdim) '_' nonlinear '.sdseries.nii'], wbcommand);
%tICAtcsabsmean=ciftiopen([OutputFolder '/tICA_ABSAVGTCS_' num2str(tICAdim) '_' nonlinear '.sdseries.nii'], wbcommand);
tICAspectra=ciftiopen([OutputFolder '/tICA_Spectra_' num2str(tICAdim) '_' nonlinear '.sdseries.nii'], wbcommand);
tICAspectranorm=ciftiopen([OutputFolder '/tICA_Spectra_norm_' num2str(tICAdim) '_' nonlinear '.sdseries.nii'], wbcommand);
% group norm surface map
tICAMapsGroupNorm=tICAMaps;
tICAMapsGroupNorm.cdata=(tICAMapsGroupNorm.cdata-mean(reshape(tICAMapsGroupNorm.cdata,[],1)))/std(reshape(tICAMapsGroupNorm.cdata,[],1));
ciftisave(tICAMapsGroupNorm,[OutputFolder '/tICA_Maps_' num2str(tICAdim) '_' nonlinear '_GroupNorm.dscalar.nii'],wbcommand);

% group norm volume map
tICAVolMapsGroupNorm=tICAVolMaps;
tICAVolMapsGroupNorm.cdata=(tICAVolMapsGroupNorm.cdata-mean(reshape(tICAVolMapsGroupNorm.cdata,[],1)))/std(reshape(tICAVolMapsGroupNorm.cdata,[],1));
ciftisave(tICAVolMapsGroupNorm,[OutputFolder '/tICA_VolMaps_' num2str(tICAdim) '_' nonlinear '_GroupNorm.dscalar.nii'],wbcommand);

% convert to nifti space
unix(['wb_command -cifti-separate ' OutputFolder '/tICA_VolMaps_' num2str(tICAdim) '_' nonlinear '.dscalar.nii COLUMN -volume-all ' OutputFolder '/volmap_tmp.nii.gz']);
unix(['wb_command -volume-resample ' OutputFolder '/volmap_tmp.nii.gz ' NiftiTemplateFile ' CUBIC ' OutputFolder '/volmap.nii.gz']);
unix(['wb_command -cifti-separate ' OutputFolder '/tICA_VolMaps_' num2str(tICAdim) '_' nonlinear '_GroupNorm.dscalar.nii COLUMN -volume-all ' OutputFolder '/volmap_tmp2.nii.gz']);
unix(['wb_command -volume-resample ' OutputFolder '/volmap_tmp2.nii.gz ' NiftiTemplateFile ' CUBIC ' OutputFolder '/volmap_GroupNorm.nii.gz']);

tICAVolNifti=niftiread([OutputFolder '/volmap.nii.gz']);
tICAVolNiftiGroupNorm=niftiread([OutputFolder '/volmap_GroupNorm.nii.gz']);
unix(['rm ' OutputFolder '/volmap_tmp.nii.gz'])
unix(['rm ' OutputFolder '/volmap_tmp2.nii.gz'])

% additional information
Stats=load([OutputFolder '/stats_' num2str(tICAdim) '_' nonlinear '.wb_annsub.csv']);
Mix=load([OutputFolder '/melodic_mix_' num2str(tICAdim) '_' nonlinear]);
% in cifti space
CorticalParcellation=ciftiopen(CorticalParcellationFile, wbcommand);
CorticalROIs=zeros(length(tICAMaps.cdata),max(CorticalParcellation.cdata));
for i=1:max(CorticalParcellation.cdata)
    CorticalROIs([CorticalParcellation.cdata ; zeros(length(tICAMaps.cdata)-length(CorticalParcellation.cdata),1)]==i,i)=1;
end
ParcelReorder=load(ParcelReorderFile,'-ascii');
%VertexAreas=ciftiopen([StudyFolder '/' GroupAverageName '/MNINonLinear/fsaverage_LR32k/' GroupAverageName '.midthickness' RegString '_va.32k_fs_LR.dscalar.nii'], wbcommand);

pipedir = getenv('HCPPIPEDIR');
vertarealeft = gifti([pipedir '/global/templates/standard_mesh_atlases/resample_fsaverage/fs_LR.L.midthickness_va_avg.32k_fs_LR.shape.gii']);
vertarearight = gifti([pipedir '/global/templates/standard_mesh_atlases/resample_fsaverage/fs_LR.R.midthickness_va_avg.32k_fs_LR.shape.gii']);
VertexAreas = cifti_struct_create_from_template(tICAMaps, zeros(size(tICAMaps.cdata, 1), 1, 'single'), 'dscalar');
VertexAreas = cifti_struct_dense_replace_surface_data(VertexAreas, vertarealeft.cdata, 'CORTEX_LEFT');
VertexAreas = cifti_struct_dense_replace_surface_data(VertexAreas, vertarearight.cdata, 'CORTEX_RIGHT');

clear a
for i=1:max(CorticalParcellation.cdata)
    a(i)=sum(VertexAreas.cdata(CorticalParcellation.cdata==i));
end

CorticalParcellation.cdata(length(CorticalParcellation.cdata)+1:size(tICAMaps.cdata,1),1)=0;
% read mask files
vas_mask=niftiread(VascularTerritoryFile);
vessal_prob_map=niftiread(VesselProbMapFile);

% create cifti masks
disp('creating brain masks...')
MaskSavePath = [StudyFolder '/' GroupAverageName '/MNINonLinear/ROIs_test2'];
%brain_masks(StudyFolder, GroupAverageName, Resolution, OutputfMRIName, MaskSavePath);
launch_file=[HelpFuncPath '/brain_masks.sh'];

unix([launch_file ' --study-folder="' StudyFolder '" --out-group-name="' GroupAverageName '" --fmri-resolution="' Resolution '" --output-fmri-name="' OutputfMRIName '" --mask-save-path="' MaskSavePath '" --label-text-folder="' ConfigFilePath '" --dilate="' Dilate '"'])
% check if dimension matches
size_volnifti=size(tICAVolNifti);
size_vas_mask=size(vas_mask);
if ~isequal(size_vas_mask,size_volnifti(1:3))
    error('Nifti template file is not the same dimension as vascular territory nifti file')
end
% reshape nifti files as an necessary preprocessing step
tICAVolNiftiOrig=tICAVolNifti;
tICAVolNifti=reshape(tICAVolNifti,[],size(tICAVolNifti,4));
tICAVolNiftiGroupNormOrig=tICAVolNiftiGroupNorm;
tICAVolNiftiGroupNorm=reshape(tICAVolNiftiGroupNorm,[],size(tICAVolNiftiGroupNorm,4));

vas_mask=reshape(vas_mask,[],1);
vas_mask_area=unique(vas_mask);
vas_mask_area=setdiff(vas_mask_area,[0]);

vessal_prob_map=reshape(vessal_prob_map,[],1);


subcortical_mask=ciftiopen([MaskSavePath '/' GroupAverageName '_AverageSubcortical_Mask_' OutputfMRIName '.' Resolution '.dscalar.nii'], wbcommand);
wm_mask=ciftiopen([MaskSavePath '/' GroupAverageName '_AverageWM_Mask_' OutputfMRIName '.' Resolution '.dscalar.nii'], wbcommand);
gm_mask=ciftiopen([MaskSavePath '/' GroupAverageName '_AverageGM_Mask_' OutputfMRIName '.' Resolution '.dscalar.nii'], wbcommand);
csf_mask=ciftiopen([MaskSavePath '/' GroupAverageName '_AverageCSF_Mask_' OutputfMRIName '.' Resolution '.dscalar.nii'], wbcommand);
subcortical_loc=find(subcortical_mask.cdata==1);
wm_loc=find(wm_mask.cdata==1);
gm_loc=find(gm_mask.cdata==1);
csf_loc=find(csf_mask.cdata==1);

right_cerebellar_mask=ciftiopen([MaskSavePath '/' GroupAverageName '_AverageRightCerebellar_Mask_' OutputfMRIName '.' Resolution '.dscalar.nii'], wbcommand);
left_cerebellar_mask=ciftiopen([MaskSavePath '/' GroupAverageName '_AverageLeftCerebellar_Mask_' OutputfMRIName '.' Resolution '.dscalar.nii'], wbcommand);
leftgm_mask=ciftiopen([MaskSavePath '/' GroupAverageName '_AverageLeftGM_NoCerebellar_Mask_' OutputfMRIName '.' Resolution '.dscalar.nii'], wbcommand);
rightgm_mask=ciftiopen([MaskSavePath '/' GroupAverageName '_AverageRightGM_NoCerebellar_Mask_' OutputfMRIName '.' Resolution '.dscalar.nii'], wbcommand);
right_cerebellar_loc=find(right_cerebellar_mask.cdata==1);
left_cerebellar_loc=find(left_cerebellar_mask.cdata==1);
leftgm_loc=find(leftgm_mask.cdata==1);
rightgm_loc=find(rightgm_mask.cdata==1);
%boundary_mask1=ciftiopen([MaskSavePath '/' GroupAverageName '_brainboundary_' erode_mm{1} 'mm.' Resolution '.dscalar.nii'],wbcommand);
boundary_mask2=ciftiopen([MaskSavePath '/' GroupAverageName '_brainboundary_' erode_mm{2} 'mm_' OutputfMRIName '.' Resolution '.dscalar.nii'],wbcommand);
boundary_mask3=ciftiopen([MaskSavePath '/' GroupAverageName '_brainboundary_' erode_mm{3} 'mm_' OutputfMRIName '.' Resolution '.dscalar.nii'],wbcommand);
boundary_mask4=ciftiopen([MaskSavePath '/' GroupAverageName '_brainboundary_' erode_mm{4} 'mm_' OutputfMRIName '.' Resolution '.dscalar.nii'],wbcommand);
boundary_mask5=ciftiopen([MaskSavePath '/' GroupAverageName '_brainboundary_' erode_mm{5} 'mm_' OutputfMRIName '.' Resolution '.dscalar.nii'],wbcommand);
%boundary_mask1_loc=find(boundary_mask1.cdata==1);
boundary_mask2_loc=find(boundary_mask2.cdata==1);
boundary_mask3_loc=find(boundary_mask3.cdata==1);
boundary_mask4_loc=find(boundary_mask4.cdata==1);
boundary_mask5_loc=find(boundary_mask5.cdata==1);

% generating DVARS and GS for each subject each fMRI runs
disp('generating DVARS and GS...')
ComputeDVARSandGS(StudyFolder,Subjlist, hp, MRFixConcatName, fMRINames, RegString, fMRIProcString, RecleanMode);

% identify strongest single subject
disp('identifying strongest single subject corresponding to each component...')

if ~isempty(MRFixConcatName)
    fMRINames={MRFixConcatName};
end

c=1;
tICATCS={};
CIFTIGS={};
CIFTIDVARS={};
% compute necessary information for single subject outlier metrics
for i=1:length(Subjlist)
    %Subjlist{i}
    SubjFolderlist=[StudyFolder '/' Subjlist{i}];
    if isfile([SubjFolderlist '/MNINonLinear/fsaverage_LR' LowResMesh 'k/' Subjlist{i} '.' tICAFeaturesProcString RegString '_ts.' LowResMesh 'k_fs_LR.sdseries.nii'])
        tICATCS_sub=ciftiopen([SubjFolderlist '/MNINonLinear/fsaverage_LR' LowResMesh 'k/' Subjlist{i} '.' tICAFeaturesProcString RegString '_ts.' LowResMesh 'k_fs_LR.sdseries.nii'], wbcommand);
        %tICASpectra_sub=ciftiopen([SubjFolderlist '/MNINonLinear/fsaverage_LR' LowResMesh 'k/' Subjlist{i} '.' tICAFeaturesProcString RegString '_spectra.' LowResMesh 'k_fs_LR.sdseries.nii'], wbcommand);
        %tICAMapsZ_sub=ciftiopen([SubjFolderlist '/MNINonLinear/fsaverage_LR' LowResMesh 'k/' Subjlist{i} '.' tICAFeaturesProcString '_SRZ' RegString '.' LowResMesh 'k_fs_LR.dscalar.nii'], wbcommand);

        CIFTIGS_sub=[];
        CIFTIDVARS_sub=[];
        %sICAFIXSignal_sub=0;
        %sICAFIXNoise_sub=0;
        
        for j=1:length(fMRINames)
            %%%%%% original
            fMRIName=fMRINames{j};
            if isfile([SubjFolderlist '/MNINonLinear/Results/' fMRIName '/' fMRIName '_Atlas' RegString fMRIProcString '_GS.sdseries.nii'])
                CIFTIGS_run=ciftiopen([SubjFolderlist '/MNINonLinear/Results/' fMRIName '/' fMRIName '_Atlas' RegString fMRIProcString '_GS.sdseries.nii'], wbcommand);
                CIFTIDVARS_run=ciftiopen([SubjFolderlist '/MNINonLinear/Results/' fMRIName '/' fMRIName '_Atlas' RegString fMRIProcString '_DVARS.sdseries.nii'], wbcommand);
                CIFTIGS_sub=[CIFTIGS_sub CIFTIGS_run.cdata];
                CIFTIDVARS_sub=[CIFTIDVARS_sub CIFTIDVARS_run.cdata];
            end
        end
        tICATCS{i}=tICATCS_sub.cdata;
        CIFTIGS{i}=CIFTIGS_sub;
        CIFTIDVARS{i}=CIFTIDVARS_sub;
        c=c+1;
    end 
end

% single subject characteristics
% 1. GSCOVS, covaraince between global signal and single subject tICA
% timeseries, higher indicating global effect
% 2. TCSVARS, variance of single subject tICA timeseries, higher indicating
% strong single subject effect
for i=1:length(tICATCS) % subjects
    if ~isempty(CIFTIGS{i})
        for j=1:tICAdim
          COV=cov(CIFTIGS{i}(1,:)',tICATCS{i}(j,:)');
          GSCOVS(i,j)=abs(COV(1,2));
          %CORRCOEF=corrcoef(CIFTIGS{i}(1,:)',tICATCS{i}(j,:)');
          %GSCORRCOEFS(i,j)=abs(CORRCOEF(1,2)); clear CORRCOEF;
          TCSVARS(i,j)=COV(2,2); clear COV;
        end
    end
end
TCSConcat=[];
DVARSConcat=[];
GSConcat=[];
for i=1:length(tICATCS)
    if ~isempty(CIFTIGS{i})
        TCSConcat=[TCSConcat tICATCS{i}];
        DVARSConcat=[DVARSConcat CIFTIDVARS{i}];
        GSConcat=[GSConcat CIFTIGS{i}];
    end
end

% runwise non-physio data
% for j=1:length(PhysiofMRINames)
%     r=rs(j);
%     RunwisetICATCS{r}=[];
%     RunwiseDVARS{r}=[];
%     RunwiseGS{r}=[];
% end
% c=1;
% for i=1:length(SubjFolderlist)
%     Subjlist{i}
%     Start=1;
%     End=0;
%     if exist([SubjFolderlist{i} '/MNINonLinear/fsaverage_LR' LowResMesh 'k/' Subjlist{i} '.' OutString RegString '_ts.' LowResMesh 'k_fs_LR.sdseries.nii']) & length(tICATCS{i})==RunsXNumTimePoints
%         for j=1:length(PhysiofMRINames)
%             r=rs(j);
%                 RunLength=RunLengths(j);
%                 End=End+RunLength;
%                 RuntICAtTCS=tICATCS{i}(:,Start:End);
%                 RunDVARS=CIFTIDVARS{i}(:,Start:End);
%                 RunGS=CIFTIGS{i}(:,Start:End);
%                 RunwisetICATCS{r}=[RunwisetICATCS{r} RuntICAtTCS];
%                 RunwiseDVARS{r}=[RunwiseDVARS{r} RunDVARS];
%                 RunwiseGS{r}=[RunwiseGS{r} RunGS];
%                 Start=Start+RunLength;
%         end
%     end
% end

% generate strongest single subject parcel-based grayplots and spatial maps
disp('generateing strongest single subject parcel-based grayplots and spatial maps...')

tICAMaps_SS=tICAMaps;
tICAVolMaps_SS=tICAVolMaps;
tICAMapsZ_SS=tICAMaps;
tICAVolMapsZ_SS=tICAVolMaps;
tICAtcs_SS=tICAtcsmean;
tICAspectra_SS=tICAspectra;
tICAtcs_SS.cdata=tICAtcsmean.cdata*0;
tICAspectra_SS.cdata=tICAspectra.cdata*0;
%Find strongest individual subjects for components
[~, I]=max(TCSVARS);
for i=1:size(TCSVARS,2)
    %Subjlist{I(i)}
    SubjFolderlist=[StudyFolder '/' Subjlist{I(i)}];
    tICAMaps_sub=ciftiopen([SubjFolderlist '/MNINonLinear/fsaverage_LR' LowResMesh 'k/' Subjlist{I(i)} '.' tICAFeaturesProcString '_SR' RegString '.' LowResMesh 'k_fs_LR.dscalar.nii'],'wb_command');      
    tICAVolMaps_sub=ciftiopen([SubjFolderlist '/MNINonLinear/fsaverage_LR' LowResMesh 'k/' Subjlist{I(i)} '.' tICAFeaturesProcString '_SR' RegString '_vol.' LowResMesh 'k_fs_LR.dscalar.nii'],'wb_command');
    tICAMaps_SS.cdata(:,i)=tICAMaps_sub.cdata(:,i);
    try
        tICAVolMaps_SS.cdata(:,i)=tICAVolMaps_sub.cdata(:,i);
    catch
       [StudyFolder '/' Subjlist{I(i)}]
       tICAFeaturesProcString
    end
    tICAMapsZ_sub=ciftiopen([SubjFolderlist '/MNINonLinear/fsaverage_LR' LowResMesh 'k/' Subjlist{I(i)} '.' tICAFeaturesProcString '_SRZ' RegString '.' LowResMesh 'k_fs_LR.dscalar.nii'],'wb_command');      
    tICAVolMapsZ_sub=ciftiopen([SubjFolderlist '/MNINonLinear/fsaverage_LR' LowResMesh 'k/' Subjlist{I(i)} '.' tICAFeaturesProcString '_SRZ' RegString '_vol.' LowResMesh 'k_fs_LR.dscalar.nii'],'wb_command');
    tICAMapsZ_SS.cdata(:,i)=tICAMapsZ_sub.cdata(:,i);
    tICAVolMapsZ_SS.cdata(:,i)=tICAVolMapsZ_sub.cdata(:,i);
    tICATCS_sub=ciftiopen([SubjFolderlist '/MNINonLinear/fsaverage_LR' LowResMesh 'k/' Subjlist{I(i)} '.' tICAFeaturesProcString RegString '_ts.' LowResMesh 'k_fs_LR.sdseries.nii'],'wb_command');
    tICASpectra_sub=ciftiopen([SubjFolderlist '/MNINonLinear/fsaverage_LR' LowResMesh 'k/' Subjlist{I(i)} '.' tICAFeaturesProcString RegString '_spectra.' LowResMesh 'k_fs_LR.sdseries.nii'],'wb_command');
    tICAtcs_SS.cdata(i,1:length(tICATCS_sub.cdata(i,:)))=tICATCS_sub.cdata(i,:);
    tICAspectra_SS.cdata(i,1:length(tICASpectra_sub.cdata(i,:)))=tICASpectra_sub.cdata(i,:);

    tICASingleComponentSpaceXTime=zeros(size(CorticalROIs,2),length(tICATCS_sub.cdata),size(tICATCS_sub.cdata,1),'single');
    for j=1:size(tICAMaps.cdata,2)
        tICASingleComponentSpaceXTime(:,:,j)=CorticalROIs'*(tICAMaps_sub.cdata(:,j)*tICATCS_sub.cdata(j,:));
    end
    rtICASingleComponentSpaceXTime=[];

    for k=1:size(tICAMaps.cdata,2)%tICA_dim
    c=1;
    for j=ParcelReorder
        rtICASingleComponentSpaceXTime(c:c-1+round((a(j)/min(a))),:,k)=repmat(tICASingleComponentSpaceXTime(j,:,k),round((a(j)/min(a))),1);
        c=c+round((a(j)/min(a)));
    end
    end

    temp=tICAtcs_SS;
    temp.cdata=zeros(size(rtICASingleComponentSpaceXTime,1),size(tICAtcs_SS.cdata,2),'single');
    temp.cdata(:,1:size(rtICASingleComponentSpaceXTime,2))=squeeze(rtICASingleComponentSpaceXTime(:,:,i))./repmat(std(sum(rtICASingleComponentSpaceXTime,3),[],2),1,size(rtICASingleComponentSpaceXTime,2));
    ciftisavereset(temp,[OutputFolder '/tICA' num2str(i,'%02.f') '_SS.sdseries.nii'],'wb_command');
    temp.cdata(:,1:size(rtICASingleComponentSpaceXTime,2))=squeeze(sum(rtICASingleComponentSpaceXTime(:,:,:),3))./repmat(std(sum(rtICASingleComponentSpaceXTime,3),[],2),1,size(rtICASingleComponentSpaceXTime,2));
    ciftisavereset(temp,[OutputFolder '/All' num2str(i,'%02.f') '_SS.sdseries.nii'],'wb_command');
end
ciftisave(tICAMaps_SS,[OutputFolder '/tICA_Maps_' num2str(tICAdim) '_tanhF_SS.dscalar.nii'],wbcommand);
ciftisave(tICAVolMaps_SS,[OutputFolder '/tICA_VolMaps_' num2str(tICAdim) '_tanhF_SS.dscalar.nii'],wbcommand);
ciftisave(tICAMapsZ_SS,[OutputFolder '/tICA_MapsZ_' num2str(tICAdim) '_tanhF_SS.dscalar.nii'],wbcommand);
ciftisave(tICAVolMapsZ_SS,[OutputFolder '/tICA_VolMapsZ_' num2str(tICAdim) '_tanhF_SS.dscalar.nii'],wbcommand);
unix(['wb_command -cifti-separate ' OutputFolder '/tICA_VolMapsZ_' num2str(tICAdim) '_' nonlinear '_SS.dscalar.nii COLUMN -volume-all ' OutputFolder '/volmapZ_tmp.nii.gz']);
unix(['wb_command -volume-resample ' OutputFolder '/volmapZ_tmp.nii.gz ' NiftiTemplateFile ' CUBIC ' OutputFolder '/volmapZ_ss.nii.gz']);
unix(['rm ' OutputFolder '/volmapZ_tmp.nii.gz'])
ciftisave(tICAtcs_SS,[OutputFolder '/tICA_TCS_' num2str(tICAdim) '_' nonlinear '_SS.sdseries.nii'],wbcommand);
ciftisave(tICAspectra_SS,[OutputFolder '/tICA_Spectra_' num2str(tICAdim) '_' nonlinear '_SS.sdseries.nii'],wbcommand);

tICAMapsZ_SS=ciftiopen([OutputFolder '/tICA_MapsZ_' num2str(tICAdim) '_tanhF_SS.dscalar.nii'], wbcommand);
tICAVolMapsZ_SS=ciftiopen([OutputFolder '/tICA_VolMapsZ_' num2str(tICAdim) '_tanhF_SS.dscalar.nii'], wbcommand);

% convert to nifti space
unix(['wb_command -cifti-separate ' OutputFolder '/tICA_VolMapsZ_' num2str(tICAdim) '_tanhF_SS.dscalar.nii COLUMN -volume-all ' OutputFolder '/volmapZ_tmp.nii.gz']);
unix(['wb_command -volume-resample ' OutputFolder '/volmapZ_tmp.nii.gz ' NiftiTemplateFile ' CUBIC ' OutputFolder '/volmapZ.nii.gz']);

tICAVolSSZNiftiOrig=niftiread([OutputFolder '/volmapZ.nii.gz']);
tICAVolSSZNifti=reshape(tICAVolSSZNiftiOrig,[],size(tICAVolSSZNiftiOrig,4));
unix(['rm ' OutputFolder '/volmapZ_tmp.nii.gz'])

disp('generateing features...')
num_space_metrics=4;
tICA_feature_row_names=cell(tICAdim, 1);
outlier_stat=zeros(tICAdim,2);
% group spatial maps
subcortical_stat=zeros(tICAdim,num_space_metrics);
wm_stat=zeros(tICAdim,num_space_metrics);
gm_stat=zeros(tICAdim,num_space_metrics);
csf_stat=zeros(tICAdim,num_space_metrics);
right_cerebellar_stat=zeros(tICAdim,num_space_metrics);
left_cerebellar_stat=zeros(tICAdim,num_space_metrics);
leftgm_stat=zeros(tICAdim,num_space_metrics);
rightgm_stat=zeros(tICAdim,num_space_metrics);
boundary_stat=zeros(tICAdim,num_space_metrics*4);
vas_stat=zeros(tICAdim,length(vas_mask_area)*3);
vessal_stat=zeros(tICAdim,5);
kspace_mask_stat=zeros(tICAdim,6);
parcel_features=zeros(tICAdim, max(CorticalParcellation.cdata));

subcortical_stat_groupnorm=zeros(tICAdim,num_space_metrics);
wm_stat_groupnorm=zeros(tICAdim,num_space_metrics);
gm_stat_groupnorm=zeros(tICAdim,num_space_metrics);
csf_stat_groupnorm=zeros(tICAdim,num_space_metrics);
right_cerebellar_stat_groupnorm=zeros(tICAdim,num_space_metrics);
left_cerebellar_stat_groupnorm=zeros(tICAdim,num_space_metrics);
leftgm_stat_groupnorm=zeros(tICAdim,num_space_metrics);
rightgm_stat_groupnorm=zeros(tICAdim,num_space_metrics);
boundary_stat_groupnorm=zeros(tICAdim,num_space_metrics*4);
vas_stat_groupnorm=zeros(tICAdim,length(vas_mask_area)*3);
vessal_stat_groupnorm=zeros(tICAdim,5);
kspace_mask_stat_groupnorm=zeros(tICAdim,6);
parcel_features_groupnorm=zeros(tICAdim, max(CorticalParcellation.cdata));

% single subject z statistic map
subcortical_stat_Zss=zeros(tICAdim,num_space_metrics);
wm_stat_Zss=zeros(tICAdim,num_space_metrics);
gm_stat_Zss=zeros(tICAdim,num_space_metrics);
csf_stat_Zss=zeros(tICAdim,num_space_metrics);
right_cerebellar_stat_Zss=zeros(tICAdim,num_space_metrics);
left_cerebellar_stat_Zss=zeros(tICAdim,num_space_metrics);
leftgm_stat_Zss=zeros(tICAdim,num_space_metrics);
rightgm_stat_Zss=zeros(tICAdim,num_space_metrics);
boundary_stat_Zss=zeros(tICAdim,num_space_metrics*4);
vas_stat_Zss=zeros(tICAdim,length(vas_mask_area)*3);
vessal_stat_Zss=zeros(tICAdim,5);
kspace_mask_stat_Zss=zeros(tICAdim,6);
parcel_features_Zss=zeros(tICAdim, max(CorticalParcellation.cdata));

% group spectrum
spectrum_stat=zeros(tICAdim, 1);
% single subject timeseries
ss_tcs_stat=zeros(tICAdim,12);
CE_ss_tcs_stat=zeros(tICAdim,1);
sum_outlier_ss_tcs_stat=zeros(tICAdim,1);
% single subject power spectrum
ss_spectrum_stat=zeros(tICAdim,3);
% single subject grayplot
gp_coeff_var=zeros(tICAdim,4);
gp_xcorr_stat=zeros(tICAdim,5);
gp_xcorr_fit_stat=zeros(tICAdim,2);
lagdices=5;
gp_match_stat=zeros(tICAdim,12);
gp_match_stat_factor=zeros(tICAdim,12);
gp_outlier_stat=zeros(tICAdim,2);
factor=1;

disp(['vas atlas start'])
vas_atlas=ciftiopen(PerfusionFile,'wb_command');
vas_correlation_atlas=zeros(tICAdim, 2);
vas_atlas_first=ciftiopen(ArrivalAtlasFile,'wb_command');

for i=1:tICAdim
    tmp=corrcoef(vas_atlas.cdata, tICAMaps.cdata(:,i));
    vas_correlation_atlas(i,1)=abs(tmp(1,2));
    tmp=corrcoef(vas_atlas_first.cdata, tICAMaps.cdata(:,i));
    vas_correlation_atlas(i,2)=abs(tmp(1,2));
end
disp(['vas atlas end'])


for i=1:tICAdim
    % volume mask region (cifti + nifti)
    CiftiVolMapForFeature=tICAVolMaps;
    NiftiVolMapForFeature=tICAVolNifti;
    NiftiVolMapForFeatureOrig=tICAVolNiftiOrig;
    subcortical_stat(i,:)=brain_region_features(CiftiVolMapForFeature.cdata(subcortical_loc,i), CiftiVolMapForFeature.cdata(:,i), subcortical_mask);
    wm_stat(i,:)=brain_region_features(CiftiVolMapForFeature.cdata(wm_loc,i), CiftiVolMapForFeature.cdata(:,i), wm_mask);
    gm_stat(i,:)=brain_region_features(CiftiVolMapForFeature.cdata(gm_loc,i), CiftiVolMapForFeature.cdata(:,i), gm_mask);
    csf_stat(i,:)=brain_region_features(CiftiVolMapForFeature.cdata(csf_loc,i), CiftiVolMapForFeature.cdata(:,i), csf_mask);
    right_cerebellar_stat(i,:)=brain_region_features(CiftiVolMapForFeature.cdata(right_cerebellar_loc,i), CiftiVolMapForFeature.cdata(:,i), right_cerebellar_mask);
    left_cerebellar_stat(i,:)=brain_region_features(CiftiVolMapForFeature.cdata(left_cerebellar_loc,i), CiftiVolMapForFeature.cdata(:,i), left_cerebellar_mask);
    leftgm_stat(i,:)=brain_region_features(CiftiVolMapForFeature.cdata(leftgm_loc,i), CiftiVolMapForFeature.cdata(:,i), leftgm_mask);
    rightgm_stat(i,:)=brain_region_features(CiftiVolMapForFeature.cdata(rightgm_loc,i), CiftiVolMapForFeature.cdata(:,i), rightgm_mask);
    
    boundary_stat(i,1:num_space_metrics)=brain_region_features(CiftiVolMapForFeature.cdata(boundary_mask2_loc,i), CiftiVolMapForFeature.cdata(:,i), boundary_mask2);
    boundary_stat(i,num_space_metrics+1:num_space_metrics*2)=brain_region_features(CiftiVolMapForFeature.cdata(boundary_mask3_loc,i), CiftiVolMapForFeature.cdata(:,i), boundary_mask3);
    boundary_stat(i,num_space_metrics*2+1:num_space_metrics*3)=brain_region_features(CiftiVolMapForFeature.cdata(boundary_mask4_loc,i), CiftiVolMapForFeature.cdata(:,i), boundary_mask4);
    boundary_stat(i,num_space_metrics*3+1:num_space_metrics*4)=brain_region_features(CiftiVolMapForFeature.cdata(boundary_mask5_loc,i), CiftiVolMapForFeature.cdata(:,i), boundary_mask5);
    for j=1:length(vas_mask_area)
        vas_stat(i,3*j-2)=mean(NiftiVolMapForFeature(vas_mask==vas_mask_area(j),i));
        vas_stat(i,3*j-1)=std(NiftiVolMapForFeature(vas_mask==vas_mask_area(j),i));
        vas_stat(i,3*j)=std_outlier(NiftiVolMapForFeature(vas_mask==vas_mask_area(j),i));
    end
    vessal_stat(i,1)=sum(NiftiVolMapForFeature(:,i).*vessal_prob_map);
    vessal_stat(i,2)=sum(abs(NiftiVolMapForFeature(:,i)).*vessal_prob_map);
    vessal_stat(i,3)=std_outlier(NiftiVolMapForFeature(vessal_prob_map~=0,i));
    vessal_stat(i,4)=sum(NiftiVolMapForFeature(:,i).*vessal_prob_map)/length(find(vessal_prob_map~=0));
    vessal_stat(i,5)=sum(abs(NiftiVolMapForFeature(:,i)).*vessal_prob_map)/length(find(vessal_prob_map~=0));
    tmp_volume=NiftiVolMapForFeatureOrig(:,:,:,i);
    tmp_fftn_mag=abs(fftshift(fftn(tmp_volume)));
    kspace_mask_stat(i,1)=mean(reshape(tmp_fftn_mag.*MultiBandKspaceMaskOrig,[],1));
    kspace_mask_stat(i,2)=std(reshape(tmp_fftn_mag.*MultiBandKspaceMaskOrig,[],1));
    kspace_mask_stat(i,3)=std_outlier(reshape(tmp_fftn_mag.*MultiBandKspaceMaskOrig,[],1));
    kspace_mask_stat(i,4)=mean(reshape(tmp_fftn_mag.*MultiBandKspaceMaskOrig,[],1))/mean(reshape(tmp_fftn_mag(find(tmp_fftn_mag>0)),[],1));
    kspace_mask_stat(i,5)=mean(reshape(tmp_fftn_mag.*MultiBandKspaceMaskOrig,[],1))/max(reshape(tmp_fftn_mag(find(tmp_fftn_mag>0)),[],1));
    tmp=corrcoef(reshape(tmp_fftn_mag,[],1),MultiBandKspaceMask);
    kspace_mask_stat(i,6)=tmp(1,2);
    
    % parcel based features
    for j=1:max(CorticalParcellation.cdata)
        parcel_features(i,j)=mean(abs(tICAMaps.cdata(CorticalParcellation.cdata==j,i)));
    end
    % group norm
    CiftiVolMapForFeature=tICAVolMapsGroupNorm;
    NiftiVolMapForFeature=tICAVolNiftiGroupNorm;
    NiftiVolMapForFeatureOrig=tICAVolNiftiGroupNormOrig;
    subcortical_stat_groupnorm(i,:)=brain_region_features(CiftiVolMapForFeature.cdata(subcortical_loc,i), CiftiVolMapForFeature.cdata(:,i), subcortical_mask);
    wm_stat_groupnorm(i,:)=brain_region_features(CiftiVolMapForFeature.cdata(wm_loc,i), CiftiVolMapForFeature.cdata(:,i), wm_mask);
    gm_stat_groupnorm(i,:)=brain_region_features(CiftiVolMapForFeature.cdata(gm_loc,i), CiftiVolMapForFeature.cdata(:,i), gm_mask);
    csf_stat_groupnorm(i,:)=brain_region_features(CiftiVolMapForFeature.cdata(csf_loc,i), CiftiVolMapForFeature.cdata(:,i), csf_mask);
    right_cerebellar_stat_groupnorm(i,:)=brain_region_features(CiftiVolMapForFeature.cdata(right_cerebellar_loc,i), CiftiVolMapForFeature.cdata(:,i), right_cerebellar_mask);
    left_cerebellar_stat_groupnorm(i,:)=brain_region_features(CiftiVolMapForFeature.cdata(left_cerebellar_loc,i), CiftiVolMapForFeature.cdata(:,i), left_cerebellar_mask);
    leftgm_stat_groupnorm(i,:)=brain_region_features(CiftiVolMapForFeature.cdata(leftgm_loc,i), CiftiVolMapForFeature.cdata(:,i), leftgm_mask);
    rightgm_stat_groupnorm(i,:)=brain_region_features(CiftiVolMapForFeature.cdata(rightgm_loc,i), CiftiVolMapForFeature.cdata(:,i), rightgm_mask);
    
    boundary_stat_groupnorm(i,1:num_space_metrics)=brain_region_features(CiftiVolMapForFeature.cdata(boundary_mask2_loc,i), CiftiVolMapForFeature.cdata(:,i), boundary_mask2);
    boundary_stat_groupnorm(i,num_space_metrics+1:num_space_metrics*2)=brain_region_features(CiftiVolMapForFeature.cdata(boundary_mask3_loc,i), CiftiVolMapForFeature.cdata(:,i), boundary_mask3);
    boundary_stat_groupnorm(i,num_space_metrics*2+1:num_space_metrics*3)=brain_region_features(CiftiVolMapForFeature.cdata(boundary_mask4_loc,i), CiftiVolMapForFeature.cdata(:,i), boundary_mask4);
    boundary_stat_groupnorm(i,num_space_metrics*3+1:num_space_metrics*4)=brain_region_features(CiftiVolMapForFeature.cdata(boundary_mask5_loc,i), CiftiVolMapForFeature.cdata(:,i), boundary_mask5);
    for j=1:length(vas_mask_area)
        vas_stat_groupnorm(i,3*j-2)=mean(NiftiVolMapForFeature(vas_mask==vas_mask_area(j),i));
        vas_stat_groupnorm(i,3*j-1)=std(NiftiVolMapForFeature(vas_mask==vas_mask_area(j),i));
        vas_stat_groupnorm(i,3*j)=std_outlier(NiftiVolMapForFeature(vas_mask==vas_mask_area(j),i));
    end
    vessal_stat_groupnorm(i,1)=sum(NiftiVolMapForFeature(:,i).*vessal_prob_map);
    vessal_stat_groupnorm(i,2)=sum(abs(NiftiVolMapForFeature(:,i)).*vessal_prob_map);
    vessal_stat_groupnorm(i,3)=std_outlier(NiftiVolMapForFeature(vessal_prob_map~=0,i));
    vessal_stat_groupnorm(i,4)=sum(NiftiVolMapForFeature(:,i).*vessal_prob_map)/length(find(vessal_prob_map~=0));
    vessal_stat_groupnorm(i,5)=sum(abs(NiftiVolMapForFeature(:,i)).*vessal_prob_map)/length(find(vessal_prob_map~=0));
    tmp_volume=NiftiVolMapForFeatureOrig(:,:,:,i);
    tmp_fftn_mag=abs(fftshift(fftn(tmp_volume)));
    kspace_mask_stat_groupnorm(i,1)=mean(reshape(tmp_fftn_mag.*MultiBandKspaceMaskOrig,[],1));
    kspace_mask_stat_groupnorm(i,2)=std(reshape(tmp_fftn_mag.*MultiBandKspaceMaskOrig,[],1));
    kspace_mask_stat_groupnorm(i,3)=std_outlier(reshape(tmp_fftn_mag.*MultiBandKspaceMaskOrig,[],1));
    kspace_mask_stat_groupnorm(i,4)=mean(reshape(tmp_fftn_mag.*MultiBandKspaceMaskOrig,[],1))/mean(reshape(tmp_fftn_mag(find(tmp_fftn_mag>0)),[],1));
    kspace_mask_stat_groupnorm(i,5)=mean(reshape(tmp_fftn_mag.*MultiBandKspaceMaskOrig,[],1))/max(reshape(tmp_fftn_mag(find(tmp_fftn_mag>0)),[],1));
    tmp=corrcoef(reshape(tmp_fftn_mag,[],1),MultiBandKspaceMask);
    kspace_mask_stat_groupnorm(i,6)=tmp(1,2);
    % parcel based features
    for j=1:max(CorticalParcellation.cdata)
        parcel_features_groupnorm(i,j)=mean(abs(tICAMapsGroupNorm.cdata(CorticalParcellation.cdata==j,i)));
    end
    % single subject spatial features
    CiftiVolMapForFeature=tICAVolMapsZ_SS;
    NiftiVolMapForFeature=tICAVolSSZNifti;
    NiftiVolMapForFeatureOrig=tICAVolSSZNiftiOrig;
    subcortical_stat_Zss(i,:)=brain_region_features(CiftiVolMapForFeature.cdata(subcortical_loc,i), CiftiVolMapForFeature.cdata(:,i), subcortical_mask);
    wm_stat_Zss(i,:)=brain_region_features(CiftiVolMapForFeature.cdata(wm_loc,i), CiftiVolMapForFeature.cdata(:,i), wm_mask);
    gm_stat_Zss(i,:)=brain_region_features(CiftiVolMapForFeature.cdata(gm_loc,i), CiftiVolMapForFeature.cdata(:,i), gm_mask);
    csf_stat_Zss(i,:)=brain_region_features(CiftiVolMapForFeature.cdata(csf_loc,i), CiftiVolMapForFeature.cdata(:,i), csf_mask);
    right_cerebellar_stat_Zss(i,:)=brain_region_features(CiftiVolMapForFeature.cdata(right_cerebellar_loc,i), CiftiVolMapForFeature.cdata(:,i), right_cerebellar_mask);
    left_cerebellar_stat_Zss(i,:)=brain_region_features(CiftiVolMapForFeature.cdata(left_cerebellar_loc,i), CiftiVolMapForFeature.cdata(:,i), left_cerebellar_mask);
    leftgm_stat_Zss(i,:)=brain_region_features(CiftiVolMapForFeature.cdata(leftgm_loc,i), CiftiVolMapForFeature.cdata(:,i), leftgm_mask);
    rightgm_stat_Zss(i,:)=brain_region_features(CiftiVolMapForFeature.cdata(rightgm_loc,i), CiftiVolMapForFeature.cdata(:,i), rightgm_mask);
    
    boundary_stat_Zss(i,1:num_space_metrics)=brain_region_features(CiftiVolMapForFeature.cdata(boundary_mask2_loc,i), CiftiVolMapForFeature.cdata(:,i), boundary_mask2);
    boundary_stat_Zss(i,num_space_metrics+1:num_space_metrics*2)=brain_region_features(CiftiVolMapForFeature.cdata(boundary_mask3_loc,i), CiftiVolMapForFeature.cdata(:,i), boundary_mask3);
    boundary_stat_Zss(i,num_space_metrics*2+1:num_space_metrics*3)=brain_region_features(CiftiVolMapForFeature.cdata(boundary_mask4_loc,i), CiftiVolMapForFeature.cdata(:,i), boundary_mask4);
    boundary_stat_Zss(i,num_space_metrics*3+1:num_space_metrics*4)=brain_region_features(CiftiVolMapForFeature.cdata(boundary_mask5_loc,i), CiftiVolMapForFeature.cdata(:,i), boundary_mask5);
    for j=1:length(vas_mask_area)
        vas_stat_Zss(i,3*j-2)=mean(NiftiVolMapForFeature(vas_mask==vas_mask_area(j),i));
        vas_stat_Zss(i,3*j-1)=std(NiftiVolMapForFeature(vas_mask==vas_mask_area(j),i));
        vas_stat_Zss(i,3*j)=std_outlier(NiftiVolMapForFeature(vas_mask==vas_mask_area(j),i));
    end
    vessal_stat_Zss(i,1)=sum(NiftiVolMapForFeature(:,i).*vessal_prob_map);
    vessal_stat_Zss(i,2)=sum(abs(NiftiVolMapForFeature(:,i)).*vessal_prob_map);
    vessal_stat_Zss(i,3)=std_outlier(NiftiVolMapForFeature(vessal_prob_map~=0,i));
    vessal_stat_Zss(i,4)=sum(NiftiVolMapForFeature(:,i).*vessal_prob_map)/length(find(vessal_prob_map~=0));
    vessal_stat_Zss(i,5)=sum(abs(NiftiVolMapForFeature(:,i)).*vessal_prob_map)/length(find(vessal_prob_map~=0));
    tmp_volume=NiftiVolMapForFeatureOrig(:,:,:,i);
    tmp_fftn_mag=abs(fftshift(fftn(tmp_volume)));
    kspace_mask_stat_Zss(i,1)=mean(reshape(tmp_fftn_mag.*MultiBandKspaceMaskOrig,[],1));
    kspace_mask_stat_Zss(i,2)=std(reshape(tmp_fftn_mag.*MultiBandKspaceMaskOrig,[],1));
    kspace_mask_stat_Zss(i,3)=std_outlier(reshape(tmp_fftn_mag.*MultiBandKspaceMaskOrig,[],1));
    if ~isempty(find(tmp_fftn_mag>0))
        kspace_mask_stat_Zss(i,4)=mean(reshape(tmp_fftn_mag.*MultiBandKspaceMaskOrig,[],1))/mean(reshape(tmp_fftn_mag(find(tmp_fftn_mag>0)),[],1));
        kspace_mask_stat_Zss(i,5)=mean(reshape(tmp_fftn_mag.*MultiBandKspaceMaskOrig,[],1))/max(reshape(tmp_fftn_mag(find(tmp_fftn_mag>0)),[],1));
    else
        kspace_mask_stat_Zss(i,4)=0;
        kspace_mask_stat_Zss(i,5)=0;
    end
    tmp=corrcoef(reshape(tmp_fftn_mag,[],1),MultiBandKspaceMask);
    kspace_mask_stat_Zss(i,6)=tmp(1,2);
    % parcel based features
    for j=1:max(CorticalParcellation.cdata)
        parcel_features_Zss(i,j)=mean(abs(tICAMapsZ_SS.cdata(CorticalParcellation.cdata==j,i)));
    end
    
    
    % check if component is single subject related
    outlier_stat(i,1)=std_outlier(TCSVARS(:,i));
    outlier_stat(i,2)=std_outlier(GSCOVS(:,i));
    
    % single subject timeseries statistics
    SubjFolderlist=[StudyFolder '/' Subjlist{I(i)}];
    ss_tcs=ciftiopen([SubjFolderlist '/MNINonLinear/fsaverage_LR' LowResMesh 'k/' Subjlist{I(i)} '.' tICAFeaturesProcString RegString '_ts.' LowResMesh 'k_fs_LR.sdseries.nii'],'wb_command'); 
    ss_tcs_stat(i,:)=single_subject_tcs_features(ss_tcs.cdata(i,:));
    CE_ss_tcs_stat(i,1)=CE(ss_tcs.cdata(i,:));
    sum_outlier_ss_tcs_stat(i,1)=sum_outlier(ss_tcs.cdata(i,:));
    % single subject power spectrum statistics
    power_spectrum=pwelch_ps(ss_tcs.cdata(i,:));
    ss_spectrum_stat(i,1)=max(power_spectrum);
    ss_spectrum_stat(i,2)=mean(power_spectrum);
    ss_spectrum_stat(i,3)=std(power_spectrum);
    % group power spectrum stat
    spectrum_stat(i,1)=max(tICAspectranorm.cdata(i,:));

    % single subject grayplot statistics
    if i < 10
        i_string=['0' num2str(i)];
    else
        i_string=num2str(i);
    end
    grayplot_All=ciftiopen([OutputFolder '/All' i_string '_SS.sdseries.nii'], 'wb_command');
    grayplot_tICA=ciftiopen([OutputFolder '/tICA' i_string '_SS.sdseries.nii'], 'wb_command');
    gp_coeff_var(i,1)=std(reshape(grayplot_tICA.cdata,[],1));
    gp_coeff_var(i,2)=mean(reshape(grayplot_tICA.cdata,[],1));
    gp_coeff_var(i,3)=std(abs(reshape(grayplot_tICA.cdata,[],1)));
    gp_coeff_var(i,4)=mean(abs(reshape(grayplot_tICA.cdata,[],1)));
    gp_xcorr_stat(i,1)=gp_xcorr(grayplot_All.cdata,grayplot_tICA.cdata,lagdices);
    gp_xcorr_stat(i,2)=gp_xcorr(grayplot_All.cdata,grayplot_tICA.cdata,50);
    gp_xcorr_stat(i,3)=gp_xcorr(grayplot_All.cdata,grayplot_tICA.cdata,100);
    gp_xcorr_stat(i,4)=gp_xcorr(grayplot_All.cdata,grayplot_tICA.cdata,200);
    gp_xcorr_stat(i,5)=gp_xcorr(grayplot_All.cdata,grayplot_tICA.cdata,400);
    gp_xcorr_fit_stat(i,1:2)=polyfit([5,50,100,200,400],gp_xcorr_stat(i,:),1);
    gp_match_stat(i,:)=gp_match(double(grayplot_All.cdata), double(grayplot_tICA.cdata), factor);
    gp_match_stat_factor(i,:)=gp_match(double(grayplot_All.cdata), double(grayplot_tICA.cdata), gp_coeff_var(i,1));
    gp_outlier_stat(i,1)=std_outlier(std(grayplot_tICA.cdata,[],2));
    gp_outlier_stat(i,2)=gp_outlier_stat(i,1)*outlier_stat(i,1);

    % row names
    tICA_feature_row_names{i,1}=[GroupAverageName '_' OutputfMRIName '_d' num2str(tICAdim) '_' num2str(i-1)];
end

brain_region_stat=[subcortical_stat, wm_stat, gm_stat, csf_stat, ...
                   right_cerebellar_stat, left_cerebellar_stat, leftgm_stat, rightgm_stat];
brain_region_stat_groupnorm=[subcortical_stat_groupnorm, wm_stat_groupnorm, gm_stat_groupnorm, csf_stat_groupnorm, ...
                            right_cerebellar_stat_groupnorm, left_cerebellar_stat_groupnorm, leftgm_stat_groupnorm, rightgm_stat_groupnorm];
brain_region_stat_Zss=[subcortical_stat_Zss, wm_stat_Zss, gm_stat_Zss, csf_stat_Zss, ...
                            right_cerebellar_stat_Zss, left_cerebellar_stat_Zss, leftgm_stat_Zss, rightgm_stat_Zss];
spectrum_stat_groupscale=spectrum_stat/max(spectrum_stat);
spectrum_stat_groupnorm=(spectrum_stat-mean(spectrum_stat))/std(spectrum_stat);
global_idx_old=abs(log2(sum(tICAMaps.cdata>0)./sum(tICAMaps.cdata<0)))';
global_idx=2*max([sum(tICAMaps.cdata>0)./sum(tICAMaps.cdata~=0);sum(tICAMaps.cdata<0)./sum(tICAMaps.cdata~=0)])'-1;
global_idx_groupnorm=2*max([sum(tICAMapsGroupNorm.cdata>0)./sum(tICAMapsGroupNorm.cdata~=0);sum(tICAMapsGroupNorm.cdata<0)./sum(tICAMapsGroupNorm.cdata~=0)])'-1;
global_idx_Zss=2*max([sum(tICAMapsZ_SS.cdata>0)./sum(tICAMapsZ_SS.cdata~=0);sum(tICAMapsZ_SS.cdata<0)./sum(tICAMapsZ_SS.cdata~=0)])'-1;

variability=(std(TCSVARS)./sqrt(Stats(:,2)'))';
TCSConcat_tmp=TCSConcat;DVARSConcat_tmp=DVARSConcat;
DVARS_measure=var(TCSConcat_tmp(:,abs(DVARSConcat_tmp(1,:))>12),[],2)./var(TCSConcat_tmp,[],2);
features=table(brain_region_stat, boundary_stat, vas_stat, vessal_stat, kspace_mask_stat, ...
               parcel_features, ...
               brain_region_stat_groupnorm, boundary_stat_groupnorm, vas_stat_groupnorm, vessal_stat_groupnorm, kspace_mask_stat_groupnorm, ...
               parcel_features_groupnorm, ...
               brain_region_stat_Zss, boundary_stat_Zss, vas_stat_Zss, vessal_stat_Zss, kspace_mask_stat_Zss, ...
               parcel_features_Zss, ...
               spectrum_stat, ...
               spectrum_stat_groupscale, spectrum_stat_groupnorm, ...
               global_idx_old, global_idx, ...
               global_idx_groupnorm, ...
               global_idx_Zss, ...
               ss_tcs_stat, CE_ss_tcs_stat, sum_outlier_ss_tcs_stat, ...
               ss_spectrum_stat, ...
               outlier_stat, variability, DVARS_measure, ...
               gp_coeff_var, gp_xcorr_stat, gp_xcorr_fit_stat, gp_match_stat,...
               gp_match_stat_factor, gp_outlier_stat, ...
               'RowNames',tICA_feature_row_names);
% add new features here
% example: features.statistics_spectra_norm=statistics_spectra_norm, make
% sure the feature size is equal to the total number of components 

features.vas_correlation_atlas=vas_correlation_atlas;

% other useful features to output for further investigation
other_features.tICATCS=tICATCS;
other_features.CIFTIGS=CIFTIGS;
other_features.CIFTIDVARS=CIFTIDVARS;
other_features.TCSVARS=TCSVARS;
other_features.GSCOVS=GSCOVS;

if strcmp(ToSave, 'YES')
    disp('saving features...')
    writetable(features, [OutputFolder '/features.csv'], 'WriteRowNames',true);
    save([OutputFolder '/other_features.mat'], 'other_features', '-v7.3');
end
disp('done!')
end

function lines = myreadtext(filename)
    fid = fopen(filename);
    if fid < 0
        error(['unable to open file ' filename]);
    end
    array = textscan(fid, '%s', 'Delimiter', {'\n'});
    fclose(fid);
    lines = array{1};
end
