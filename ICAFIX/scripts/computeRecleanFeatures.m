function computeRecleanFeatures(StudyFolder, ...
                                Subject, ...
                                fMRIListName, ...
                                RunsXNumTimePoints, ...
                                hp, ...
                                Resolution, ...
                                GrayOrdinateTemplateFile, ...
                                CorticalParcellationFile, ...
                                SubRegionParcellationFile, ...
                                WMLabelFile, ...
                                CSFLabelFile, VisualAreasFile, LanguageAreasFile, SubRegionsFile, NonGreyParcelsFile)

HCPPIPEDIR = getenv('HCPPIPEDIR')

GrayOrdinateTemplate=ciftiopen(GrayOrdinateTemplateFile,'wb_command');
GrayOrdinateTemplate.cdata=single(zeros(size(GrayOrdinateTemplate.cdata))); % make a zero template
FullGreyordinateLength = length(GrayOrdinateTemplate.cdata); 

fMRINames = myreadtext(fMRIListName);
RunsXNumTimePoints = str2double(RunsXNumTimePoints);
ResolutionNum = str2double(Resolution);

CorticalParcellation=ciftiopen(CorticalParcellationFile,'wb_command');
VisualROI_CIFTI=ciftiopen(VisualAreasFile,'wb_command');
VisualROI=VisualROI_CIFTI.cdata;
NonVisualROI=1-VisualROI_CIFTI.cdata;

LanguageROI_CIFTI=ciftiopen(LanguageAreasFile,'wb_command');
LanguageROI=LanguageROI_CIFTI.cdata;
NonLanguageROI=1-LanguageROI_CIFTI.cdata;

SubRegionParcellation=ciftiopen(SubRegionParcellationFile,'wb_command');

SubRegions=get_ROI_from_txt(SubRegionsFile); % SubRegionsFile HCPpipelines/global/config/SubRegions.ROI.txt

NonGreyParcels=get_ROI_from_txt(NonGreyParcelsFile); % NonGreyParcelsFile HCPpipelines/global/config/NonGreyParcels.ROI.txt

FinalSpatialSmoothingFWHM=4;

% Calculate AdditionalSigma
%AdditionalSigma = FinalSpatialSmoothingFWHM / (2 * (sqrt(2 * log(2))));
%AdditionalSigmaString=num2str(AdditionalSigma, '%0.20f');

subj=Subject;
SubjFolderlist=[StudyFolder '/' subj];

for j=1:length(fMRINames)
    fMRIName=fMRINames{j};

    sICA=load([SubjFolderlist '/MNINonLinear/Results/' fMRIName '/' fMRIName '_hp' hp '.ica/filtered_func_data.ica/melodic_mix']);
    num_comps=size(sICA,2);

    OrigFeatures=single(zeros(num_comps,186));
    NewFeatures=single(zeros(num_comps,424));

    if exist([SubjFolderlist '/MNINonLinear/Results/' fMRIName '/' fMRIName '_hp' hp '.ica/Noise.txt'],'file')
        sICA=load([SubjFolderlist '/MNINonLinear/Results/' fMRIName '/' fMRIName '_hp' hp '.ica/filtered_func_data.ica/melodic_mix']);
        Noise=load([SubjFolderlist '/MNINonLinear/Results/' fMRIName '/' fMRIName '_hp' hp '.ica/Noise.txt']);
        % prob_file=readtable([SubjFolderlist '/MNINonLinear/Results/' fMRIName '/' fMRIName '_hp' hp '.ica/Probability.txt']);
        % probability=table2array(prob_file(:,4));
        if isfile([SubjFolderlist '/MNINonLinear/Results/' fMRIName '/' fMRIName '_hp' hp '.ica/fix4melview_HCP_Style_Single_Multirun_Dedrift_thr10.txt'])
            prob_file = importdata([SubjFolderlist '/MNINonLinear/Results/' fMRIName '/' fMRIName '_hp' hp '.ica/fix4melview_HCP_Style_Single_Multirun_Dedrift_thr10.txt']);
        elseif isfile([SubjFolderlist '/MNINonLinear/Results/' fMRIName '/' fMRIName '_hp' hp '.ica/fix4melview_HCP_hp2000_thr10.txt'])
            prob_file = importdata([SubjFolderlist '/MNINonLinear/Results/' fMRIName '/' fMRIName '_hp' hp '.ica/fix4melview_HCP_hp2000_thr10.txt']);
        end
        probability=prob_file.data(1:size(sICA,2),:);
        Stats=load([SubjFolderlist '/MNINonLinear/Results/' fMRIName '/' fMRIName '_hp' hp '.ica/filtered_func_data.ica/melodic_ICstats']);
        FeaturesFile=load([SubjFolderlist '/MNINonLinear/Results/' fMRIName '/' fMRIName '_hp' hp '.ica/fix/features.csv']);
        Powerspectra=load([SubjFolderlist '/MNINonLinear/Results/' fMRIName '/' fMRIName '_hp' hp '.ica/filtered_func_data.ica/melodic_FTmix']);

        % derive TR
        file_name=[SubjFolderlist '/MNINonLinear/Results/' fMRIName '/' fMRIName '_Atlas.dtseries.nii'];
        CIFTIDenseTimeSeries=ciftiopen(file_name, "wb_command");
        TR = CIFTIDenseTimeSeries.diminfo{2}.seriesStep;

        PowerspectraScale=[(1/(TR*2))/size(Powerspectra,1):(1/(TR*2))/size(Powerspectra,1):1/(TR*2)];
        StandardPowerspectraScale=[(1/(TR*2))/(RunsXNumTimePoints/2):(1/(TR*2))/(RunsXNumTimePoints/2):1/(TR*2)];
        sICAweighted=sICA.*repmat(Stats(:,1)',length(sICA),1);
        sICAnoisy=sum(abs(sICA),2);
        sICAnoisy=sICAnoisy>prctile(sICAnoisy,87.5);

        CIFTI=ciftiopen([SubjFolderlist '/MNINonLinear/Results/' fMRIName '/' fMRIName '_hp' hp '.ica/filtered_func_data.ica/melodic_oIC.dscalar.nii'],'wb_command');
        CIFTIVN=ciftiopen([SubjFolderlist '/MNINonLinear/Results/' fMRIName '/' fMRIName '_Atlas_hp' hp '_clean_vn.dscalar.nii'],'wb_command');
        CIFTI.cdata=CIFTI.cdata./repmat(CIFTIVN.cdata,1,size(CIFTI.cdata,2));
        %system(['/media/myelin/brainmappers/Connectome_Project/YA_HCP_Final/Scripts/MSMAllResampleAndSmoothSICA.sh ' SubjFolderlist ' ' subj ' ' fMRIName ' ' hp ' ' Resolution ' ' num2str(FinalSpatialSmoothingFWHM) ' wb_command']);
        CIFTI_file=[SubjFolderlist '/MNINonLinear/Results/' fMRIName '/' fMRIName '_hp' hp '.ica/filtered_func_data.ica/melodic_oIC.dscalar.nii'];
        CIFTIMSMAll_file=[SubjFolderlist '/MNINonLinear/Results/' fMRIName '/' fMRIName '_hp' hp '.ica/filtered_func_data.ica/melodic_oIC_MSMAll.dscalar.nii'];
        CIFTIMSMAll_smooth_file=[SubjFolderlist '/MNINonLinear/Results/' fMRIName '/' fMRIName '_hp' hp '.ica/filtered_func_data.ica/melodic_oIC_MSMAll_4.dscalar.nii'];
        fs_path=[SubjFolderlist '/MNINonLinear/fsaverage_LR32k'];
        native_path=[SubjFolderlist '/MNINonLinear/Native'];
        vn_file_path=[SubjFolderlist '/MNINonLinear/Results/' fMRIName '/' fMRIName '_Atlas_MSMAll_hp' hp '_clean_vn.dscalar.nii'];
        vn_smooth_file_path=[SubjFolderlist '/MNINonLinear/Results/' fMRIName '/' fMRIName '_Atlas_MSMAll_hp' hp '_clean_vn_' num2str(FinalSpatialSmoothingFWHM) '.dscalar.nii'];

        system(['wb_command -surface-sphere-project-unproject ' fs_path '/' subj '.L.sphere.32k_fs_LR.surf.gii ' native_path '/' subj '.L.sphere.MSMSulc.native.surf.gii ' native_path '/' subj '.L.sphere.MSMAll.native.surf.gii ' fs_path '/' subj '.L.sphere.MSMSulc_MSMAll.32k_fs_LR.surf.gii']);
        system(['wb_command -surface-sphere-project-unproject ' fs_path '/' subj '.R.sphere.32k_fs_LR.surf.gii ' native_path '/' subj '.R.sphere.MSMSulc.native.surf.gii ' native_path '/' subj '.R.sphere.MSMAll.native.surf.gii ' fs_path '/' subj '.R.sphere.MSMSulc_MSMAll.32k_fs_LR.surf.gii']);
        system(['wb_command -cifti-resample ' CIFTI_file ' COLUMN ' CIFTI_file ' COLUMN ADAP_BARY_AREA ENCLOSING_VOXEL ' CIFTIMSMAll_file ' -surface-postdilate 10 -nearest -left-spheres ' fs_path '/' subj '.L.sphere.MSMSulc_MSMAll.32k_fs_LR.surf.gii ' fs_path '/' subj '.L.sphere.32k_fs_LR.surf.gii -left-area-surfs ' fs_path '/' subj '.L.midthickness.32k_fs_LR.surf.gii ' fs_path '/' subj '.L.midthickness_MSMAll.32k_fs_LR.surf.gii -right-spheres ' fs_path '/' subj '.R.sphere.MSMSulc_MSMAll.32k_fs_LR.surf.gii ' fs_path '/' subj '.R.sphere.32k_fs_LR.surf.gii -right-area-surfs ' fs_path '/' subj '.L.midthickness.32k_fs_LR.surf.gii ' fs_path '/' subj '.L.midthickness_MSMAll.32k_fs_LR.surf.gii']);
        system(['wb_command -cifti-smoothing ' CIFTIMSMAll_file ' 1.47106851007471610247 1.47106851007471610247 COLUMN ' CIFTIMSMAll_smooth_file ' -left-surface ' fs_path '/' subj '.L.midthickness_MSMAll.32k_fs_LR.surf.gii -right-surface ' fs_path '/' subj '.R.midthickness_MSMAll.32k_fs_LR.surf.gii']);
        system(['wb_command -cifti-smoothing ' vn_file_path ' 1.47106851007471610247 1.47106851007471610247 COLUMN ' vn_smooth_file_path ' -left-surface ' fs_path '/' subj '.L.midthickness_MSMAll.32k_fs_LR.surf.gii -right-surface ' fs_path '/' subj '.R.midthickness_MSMAll.32k_fs_LR.surf.gii']);

        CIFTIMSMAll=ciftiopen(CIFTIMSMAll_file,'wb_command');
        CIFTIMSMAllVN=ciftiopen(vn_file_path,'wb_command');
        CIFTIMSMAll.cdata=CIFTIMSMAll.cdata./repmat(CIFTIMSMAllVN.cdata,1,size(CIFTIMSMAll.cdata,2));           
        CIFTIMSMAllSmooth=ciftiopen([SubjFolderlist '/MNINonLinear/Results/' fMRIName '/' fMRIName '_hp' hp '.ica/filtered_func_data.ica/melodic_oIC_MSMAll_' num2str(FinalSpatialSmoothingFWHM) '.dscalar.nii'],'wb_command');
        CIFTIMSMAllSmoothVN=ciftiopen([SubjFolderlist '/MNINonLinear/Results/' fMRIName '/' fMRIName '_Atlas_MSMAll_hp' hp '_clean_vn_' num2str(FinalSpatialSmoothingFWHM) '.dscalar.nii'],'wb_command');
        CIFTIMSMAllSmooth.cdata=CIFTIMSMAllSmooth.cdata./repmat(CIFTIMSMAllSmoothVN.cdata,1,size(CIFTIMSMAllSmooth.cdata,2));           
        %CIFTIDropouts=ciftiopen([SubjFolderlist '/MNINonLinear/Results/' fMRIName '/' fMRIName '_dropouts.dscalar.nii'],'wb_command');
        cifti_dropout_file=[SubjFolderlist '/MNINonLinear/Results/' fMRIName '/' fMRIName '_dropouts.dscalar.nii'];

        CIFTIDropouts=ciftiopen(cifti_dropout_file,'wb_command');
        WMPARC=read_avw([SubjFolderlist '/MNINonLinear/ROIs/wmparc.' Resolution '.nii.gz']);
        ROIFolder=[SubjFolderlist '/MNINonLinear/ROIs'];

        system(['wb_command -volume-label-import ' ROIFolder '/wmparc.' Resolution '.nii.gz ' CSFLabelFile ' ' ROIFolder '/CSFReg.' Resolution '.nii.gz -discard-others -drop-unused-labels']);
        system(['wb_command -volume-label-import ' ROIFolder '/wmparc.' Resolution '.nii.gz ' WMLabelFile ' ' ROIFolder '/WMReg.' Resolution '.nii.gz -discard-others -drop-unused-labels']);

        WM=read_avw([SubjFolderlist '/MNINonLinear/ROIs/WMReg.' Resolution '.nii.gz']);
        CSF=read_avw([SubjFolderlist '/MNINonLinear/ROIs/CSFReg.' Resolution '.nii.gz']);
        % dropout file is not ready for lifespan
        %DROPOUT=read_avw([SubjFolderlist '/MNINonLinear/Results/' fMRIName '/' fMRIName '_dropouts.nii.gz']);
        dropout_file=[SubjFolderlist '/MNINonLinear/Results/' fMRIName '/' fMRIName '_dropouts.nii.gz'];

        DROPOUT=read_avw(dropout_file);
        VOLUME=read_avw([SubjFolderlist '/MNINonLinear/Results/' fMRIName '/' fMRIName '_hp' hp '.ica/filtered_func_data.ica/melodic_oIC.nii.gz']);
        VOLUME=reshape(VOLUME,size(VOLUME,1)*size(VOLUME,2)*size(VOLUME,3),size(VOLUME,4));
        Volume.cdata=VOLUME(std(VOLUME,[],2)>0,:);
        WMPARC=reshape(WMPARC,size(WMPARC,1)*size(WMPARC,2)*size(WMPARC,3),size(WMPARC,4));
        wmparc.cdata=WMPARC(std(VOLUME,[],2)>0,:);
        WM=reshape(WM,size(WM,1)*size(WM,2)*size(WM,3),size(WM,4));
        wm.cdata=WM(std(VOLUME,[],2)>0,:);
        wm.cdata(wm.cdata~=0)=1;
        CSF=reshape(CSF,size(CSF,1)*size(CSF,2)*size(CSF,3),size(CSF,4));
        csf.cdata=CSF(std(VOLUME,[],2)>0,:);
        csf.cdata(csf.cdata~=0)=1;
        DROPOUT=reshape(DROPOUT,size(DROPOUT,1)*size(DROPOUT,2)*size(DROPOUT,3),size(DROPOUT,4));
        dropout.cdata=DROPOUT(std(VOLUME,[],2)>0,:);
        SBREF=read_avw([SubjFolderlist '/MNINonLinear/Results/' fMRIName '/' fMRIName '_SBRef.nii.gz']);
        SBREFOrig=SBREF;
        SBREF=reshape(SBREF,size(SBREF,1)*size(SBREF,2)*size(SBREF,3),size(SBREF,4));
        sbref.cdata=SBREF(std(VOLUME,[],2)>0,:);
        noisy.cdata=(sum(Volume.cdata,2)./sbref.cdata)>prctile(sum(Volume.cdata,2)./sbref.cdata,87.5);
        edge.cdata=wmparc.cdata==0;
        Volume.cdata=Volume.cdata./std(Volume.cdata(:));
        CIFTI.cdata=CIFTI.cdata./std(CIFTI.cdata(:));

        NonGrey=single(zeros(length(wmparc.cdata),1));
        for k=NonGreyParcels
            NonGrey(wmparc.cdata==k)=1;
        end
        NonGreyPlusEdge=NonGrey+edge.cdata;
        Grey=(NonGreyPlusEdge-1)*-1;
        VolSmoothROIs.cdata=wmparc.cdata.*0;
        VolSmoothROIs.cdata(NonGrey==1)=1;
        VolSmoothROIs.cdata(Grey==1)=2;
        VolSmoothROIs.cdata(edge.cdata==1)=3;
        VOLSMOOTHROIS=WMPARC.*0;
        VOLSMOOTHROIS(std(VOLUME,[],2)>0)=VolSmoothROIs.cdata;
        VOLSMOOTHROIS=reshape(VOLSMOOTHROIS,size(SBREFOrig,1),size(SBREFOrig,2),size(SBREFOrig,3),size(SBREFOrig,4));
        save_avw(VOLSMOOTHROIS,[SubjFolderlist '/MNINonLinear/ROIs/VolumeSmoothROIs.' Resolution '.nii.gz'],'f',[1.6 1.6 1.6 1]);
        system(['fslcpgeom ' SubjFolderlist '/MNINonLinear/Results/' fMRIName '/' fMRIName '_SBRef.nii.gz ' SubjFolderlist '/MNINonLinear/ROIs/VolumeSmoothROIs.' Resolution '.nii.gz -d']);
        system([HCPPIPEDIR '/ICAFIX/scripts/VolumeSmoothSICA.sh ' SubjFolderlist ' ' subj ' ' fMRIName ' ' hp ' ' Resolution ' ' num2str(FinalSpatialSmoothingFWHM) ' wb_command']);
        VOLUMESMOOTH=read_avw([SubjFolderlist '/MNINonLinear/Results/' fMRIName '/' fMRIName '_hp' hp '.ica/filtered_func_data.ica/melodic_oIC_s' num2str(FinalSpatialSmoothingFWHM) '.nii.gz']);
        VOLUMESMOOTH=reshape(VOLUMESMOOTH,size(VOLUMESMOOTH,1)*size(VOLUMESMOOTH,2)*size(VOLUMESMOOTH,3),size(VOLUMESMOOTH,4));
        VolumeSmooth.cdata=VOLUMESMOOTH(std(VOLUMESMOOTH,[],2)>0,:);
        VolumeSmooth.cdata=VolumeSmooth.cdata./std(Volume.cdata(:));
        CIFTIMSMAllSmooth.cdata=CIFTIMSMAllSmooth.cdata./std(CIFTIMSMAll.cdata(:));
        
        % structure idx
        CIFTI_LENGTH=length(CIFTI.cdata);
        CORTEX_start_idx=min(cifti_diminfo_dense_get_surface_info(CIFTI.diminfo{1}, 'CORTEX_LEFT').ciftilist);
        CORTEX_LEFT_end_idx=max(cifti_diminfo_dense_get_surface_info(CIFTI.diminfo{1}, 'CORTEX_LEFT').ciftilist);
        CORTEX_RIGHT_end_idx=min(cifti_diminfo_dense_get_surface_info(CIFTI.diminfo{1}, 'CORTEX_RIGHT').ciftilist);

        CORTEX_end_idx=max(cifti_diminfo_dense_get_surface_info(CIFTI.diminfo{1}, 'CORTEX_RIGHT').ciftilist);
        CEREBELLUM_start_idx=min(cifti_diminfo_dense_get_volume_structure_info(CIFTI.diminfo{1}, 'CEREBELLUM_LEFT').ciftilist);
        CEREBELLUM_end_idx=max(cifti_diminfo_dense_get_volume_structure_info(CIFTI.diminfo{1}, 'CEREBELLUM_RIGHT').ciftilist);
        BRIAN_STEM_start_idx=min(cifti_diminfo_dense_get_volume_structure_info(CIFTI.diminfo{1}, 'BRAIN_STEM').ciftilist);
        BRIAN_STEM_end_idx=min(cifti_diminfo_dense_get_volume_structure_info(CIFTI.diminfo{1}, 'BRAIN_STEM').ciftilist);
        
        row_names=cell(num_comps, 1);
        probs=zeros(num_comps,1);
        for k=1:num_comps
            row_names{k}=[subj '_' fMRIName '_' num2str(k)];
            probs(k,:)=probability(k);
            OrigFeatures(k,:)=FeaturesFile(k,:);

            NewFeatures(k,1)=Stats(k,1); %Percent explained variance
            NewFeatures(k,2)=Stats(k,2); %Percent total variance
            NewFeatures(k,3)=sum(Powerspectra(PowerspectraScale>0.25,k))./sum(Powerspectra((PowerspectraScale>0.005).*(PowerspectraScale<0.1)==1,k)); %Ratio of power spectrum less than 0.005 to BOLD range
            NewFeatures(k,4)=sum(Powerspectra(PowerspectraScale<0.005,k))./sum(Powerspectra((PowerspectraScale>0.005).*(PowerspectraScale<0.1)==1,k)); %Ratio of power spectrum greater than 0.25 to BOLD range
            NewFeatures(k,5)=sum(abs(sICAweighted(sICAnoisy,k)))./sum(abs(sICAweighted(:,k))); %Ratio of amplitude at noisy (top 12.5% variance) timepoints to all timepoints weighted by explained variance
            NewFeatures(k,6)=sum(abs(sICA(sICAnoisy,k)))./sum(abs(sICA(:,k))); %Ratio of amplitude at noisy (top 12.5% variance) timepoints to all timepoints unweighted
            NewFeatures(k,7)=sum(abs(CIFTI.cdata(:,k)))./sum(abs(Volume.cdata(:,k))); %CIFTI/Volume
            NewFeatures(k,8)=sum(abs(CIFTI.cdata(CORTEX_start_idx:CORTEX_end_idx,k)))./sum(abs(Volume.cdata(:,k))); %Cerebral Cortex/Volume
            NewFeatures(k,9)=sum(abs(CIFTI.cdata(CORTEX_end_idx:end,k)))./sum(abs(Volume.cdata(:,k))); %Subcortical/Volume
            NewFeatures(k,10)=sum(abs(CIFTI.cdata(CEREBELLUM_start_idx:CEREBELLUM_end_idx,k)))./sum(abs(Volume.cdata(:,k))); %Cerebellum/Volume
            NewFeatures(k,11)=sum(abs(CIFTI.cdata(BRIAN_STEM_start_idx:BRIAN_STEM_end_idx,k)))./sum(abs(Volume.cdata(:,k))); %Brainstem/Volume
            NewFeatures(k,12)=sum(abs(CIFTI.cdata(setdiff(1:CIFTI_LENGTH,[CORTEX_start_idx:CEREBELLUM_end_idx BRIAN_STEM_start_idx:BRIAN_STEM_end_idx CEREBELLUM_start_idx:CEREBELLUM_end_idx]),k)))./sum(abs(Volume.cdata(:,k))); %Diencephalon/Volume
            NewFeatures(k,13)=sum(abs(CIFTI.cdata(CORTEX_start_idx:CORTEX_LEFT_end_idx,k)))./sum(abs(CIFTI.cdata(CORTEX_RIGHT_end_idx:CEREBELLUM_end_idx,k))); %Left Cerebral Cortex/Right Cerebral Cortex
            NewFeatures(k,14)=sum(abs(Volume.cdata(wm.cdata==1,k)))./sum(abs(Volume.cdata(:,k))); %2 Voxel Eroded WM/Volume
            NewFeatures(k,15)=sum(abs(Volume.cdata(csf.cdata==1,k)))./sum(abs(Volume.cdata(:,k))); %2 Voxel Eroded CSF/Volume
            NewFeatures(k,16)=sum(abs(Volume.cdata(edge.cdata==1,k)))./sum(abs(Volume.cdata(:,k))); %Edge/Volume (CSF outside brain)
            NewFeatures(k,17)=sum(abs(Volume.cdata(dropout.cdata>0.5,k)))./sum(abs(Volume.cdata(:,k))); %Dropout/Volume (computed using HCP Pipelines from SE and GRE Images)
            NewFeatures(k,18)=sum(abs(CIFTI.cdata(CIFTIDropouts.cdata>0.25,k)))./sum(abs(CIFTI.cdata(:,k))); %CIFTIDropout/CIFTI (computed using HCP Pipelines from SE and GRE Images)
            NewFeatures(k,19)=sum(abs(Volume.cdata(noisy.cdata==1,k)))./sum(abs(CIFTI.cdata(:,k))); %NoisyVoxels/CIFTI (top 12.5% variance)
            NewFeatures(k,20)=sum(abs(CIFTIMSMAll.cdata(VisualROI==1,k)))./sum(abs(CIFTIMSMAll.cdata(NonVisualROI==1,k))); %VisualCortexCIFTI/NonVisualCortexCIFTI
            NewFeatures(k,21)=sum(abs(CIFTIMSMAll.cdata(VisualROI==1,k)))./sum(abs(CIFTIMSMAll.cdata(CEREBELLUM_start_idx:CEREBELLUM_end_idx,k))); %VisualCortexCIFTI/CerebellumCIFTI              
            NewFeatures(k,22)=sum(abs(CIFTIMSMAll.cdata(LanguageROI==1,k)))./sum(abs(CIFTIMSMAll.cdata(NonLanguageROI==1,k))); %LanguageCortexCIFTI/NonLanguageCortexCIFTI
            NewFeatures(k,23)=sum(abs(CIFTI.cdata(:,k)))./sum(abs(Volume.cdata(NonGrey==1,k))); %CIFTI/NonGrey
            NewFeatures(k,24)=sum(abs(CIFTI.cdata(1:CEREBELLUM_end_idx,k)))./sum(abs(Volume.cdata(NonGrey==1,k))); %Cerebral Cortex/NonGrey
            NewFeatures(k,25)=sum(abs(CIFTI.cdata(:,k)))./sum(abs(Volume.cdata(NonGreyPlusEdge==1,k))); %CIFTI/NonGreyPlusEdge
            NewFeatures(k,26)=sum(abs(CIFTI.cdata(1:CEREBELLUM_end_idx,k)))./sum(abs(Volume.cdata(NonGreyPlusEdge==1,k))); %Cerebral Cortex/NonGreyPlusEdge
            NewFeatures(k,27)=sum(abs(CIFTIMSMAllSmooth.cdata(:,k)))./sum(abs(VolumeSmooth.cdata(NonGrey==1,k))); %CIFTI/NonGrey
            NewFeatures(k,28)=sum(abs(CIFTIMSMAllSmooth.cdata(1:CEREBELLUM_end_idx,k)))./sum(abs(VolumeSmooth.cdata(NonGrey==1,k))); %Cerebral Cortex/NonGrey
            NewFeatures(k,29)=sum(abs(CIFTIMSMAllSmooth.cdata(:,k)))./sum(abs(VolumeSmooth.cdata(NonGreyPlusEdge==1,k))); %CIFTI/NonGreyPlusEdge
            NewFeatures(k,30)=sum(abs(CIFTIMSMAllSmooth.cdata(1:CEREBELLUM_end_idx,k)))./sum(abs(VolumeSmooth.cdata(NonGreyPlusEdge==1,k))); %Cerebral Cortex/NonGreyPlusEdge

            NewFeatures(k,31)=mean(abs(CIFTI.cdata(:,k)))./mean(abs(Volume.cdata(:,k))); %CIFTI/Volume
            NewFeatures(k,32)=mean(abs(CIFTI.cdata(CORTEX_start_idx:CORTEX_end_idx,k)))./mean(abs(Volume.cdata(:,k))); %Cerebral Cortex/Volume
            NewFeatures(k,33)=mean(abs(CIFTI.cdata(CORTEX_end_idx:end,k)))./mean(abs(Volume.cdata(:,k))); %Subcortical/Volume
            NewFeatures(k,34)=mean(abs(CIFTI.cdata(CEREBELLUM_start_idx:CEREBELLUM_end_idx,k)))./mean(abs(Volume.cdata(:,k))); %Cerebellum/Volume
            NewFeatures(k,35)=mean(abs(CIFTI.cdata(BRIAN_STEM_start_idx:BRIAN_STEM_end_idx,k)))./mean(abs(Volume.cdata(:,k))); %Brainstem/Volume
            NewFeatures(k,36)=mean(abs(CIFTI.cdata(setdiff(1:CIFTI_LENGTH,[1:CEREBELLUM_end_idx BRIAN_STEM_start_idx:BRIAN_STEM_end_idx CEREBELLUM_start_idx:CEREBELLUM_end_idx]),k)))./mean(abs(Volume.cdata(:,k))); %Diencephalon/Volume
            NewFeatures(k,37)=mean(abs(CIFTI.cdata(CORTEX_start_idx:CORTEX_LEFT_end_idx,k)))./mean(abs(CIFTI.cdata(CORTEX_RIGHT_end_idx:CEREBELLUM_end_idx,k))); %Left Cerebral Cortex/Right Cerebral Cortex
            NewFeatures(k,38)=mean(abs(Volume.cdata(wm.cdata==1,k)))./mean(abs(Volume.cdata(:,k))); %2 Voxel Eroded WM/Volume
            NewFeatures(k,39)=mean(abs(Volume.cdata(csf.cdata==1,k)))./mean(abs(Volume.cdata(:,k))); %2 Voxel Eroded CSF/Volume
            NewFeatures(k,40)=mean(abs(Volume.cdata(edge.cdata==1,k)))./mean(abs(Volume.cdata(:,k))); %Edge/Volume (CSF outside brain)
            NewFeatures(k,41)=mean(abs(Volume.cdata(dropout.cdata>0.5,k)))./mean(abs(Volume.cdata(:,k))); %Dropout/Volume (computed using HCP Pipelines from SE and GRE Images)
            NewFeatures(k,42)=mean(abs(CIFTI.cdata(CIFTIDropouts.cdata>0.25,k)))./mean(abs(CIFTI.cdata(:,k))); %CIFTIDropout/CIFTI (computed using HCP Pipelines from SE and GRE Images)
            NewFeatures(k,43)=mean(abs(Volume.cdata(noisy.cdata==1,k)))./mean(abs(CIFTI.cdata(:,k))); %NoisyVoxels/CIFTI (top 12.5% variance)
            NewFeatures(k,44)=mean(abs(CIFTIMSMAll.cdata(VisualROI==1,k)))./mean(abs(CIFTIMSMAll.cdata(NonVisualROI==1,k))); %VisualCortexCIFTI/NonVisualCortexCIFTI
            NewFeatures(k,45)=mean(abs(CIFTIMSMAll.cdata(VisualROI==1,k)))./mean(abs(CIFTIMSMAll.cdata(CEREBELLUM_start_idx:CEREBELLUM_end_idx,k))); %VisualCortexCIFTI/CerebellumCIFTI              
            NewFeatures(k,46)=mean(abs(CIFTIMSMAll.cdata(LanguageROI==1,k)))./mean(abs(CIFTIMSMAll.cdata(NonLanguageROI==1,k))); %LanguageCortexCIFTI/NonLanguageCortexCIFTI
            NewFeatures(k,47)=mean(abs(CIFTI.cdata(:,k)))./mean(abs(Volume.cdata(NonGrey==1,k))); %CIFTI/NonGrey
            NewFeatures(k,48)=mean(abs(CIFTI.cdata(1:CEREBELLUM_end_idx,k)))./mean(abs(Volume.cdata(NonGrey==1,k))); %Cerebral Cortex/NonGrey
            NewFeatures(k,49)=mean(abs(CIFTI.cdata(:,k)))./mean(abs(Volume.cdata(NonGreyPlusEdge==1,k))); %CIFTI/NonGreyPlusEdge
            NewFeatures(k,50)=mean(abs(CIFTI.cdata(1:CEREBELLUM_end_idx,k)))./mean(abs(Volume.cdata(NonGreyPlusEdge==1,k))); %Cerebral Cortex/NonGreyPlusEdge
            NewFeatures(k,51)=mean(abs(CIFTIMSMAllSmooth.cdata(:,k)))./mean(abs(VolumeSmooth.cdata(NonGrey==1,k))); %CIFTI/NonGrey
            NewFeatures(k,52)=mean(abs(CIFTIMSMAllSmooth.cdata(1:CEREBELLUM_end_idx,k)))./mean(abs(VolumeSmooth.cdata(NonGrey==1,k))); %Cerebral Cortex/NonGrey
            NewFeatures(k,53)=mean(abs(CIFTIMSMAllSmooth.cdata(:,k)))./mean(abs(VolumeSmooth.cdata(NonGreyPlusEdge==1,k))); %CIFTI/NonGreyPlusEdge
            NewFeatures(k,54)=mean(abs(CIFTIMSMAllSmooth.cdata(1:CEREBELLUM_end_idx,k)))./mean(abs(VolumeSmooth.cdata(NonGreyPlusEdge==1,k))); %Cerebral Cortex/NonGreyPlusEdge

            for l=1:max(CorticalParcellation.cdata)
                NewFeatures(k,l+54)=mean(abs(CIFTIMSMAll.cdata(CorticalParcellation.cdata==l,k)));
            end

            for l=1:length(SubRegions)
                NewFeatures(k,l+54+max(CorticalParcellation.cdata))=mean(abs(CIFTIMSMAll.cdata(SubRegionParcellation.cdata==SubRegions(l),k)));
            end

        end
        save([SubjFolderlist '/MNINonLinear/Results/' fMRIName '/' fMRIName '_hp' hp '.ica/original_fix_features.mat'], 'OrigFeatures', '-v7.3')
        save([SubjFolderlist '/MNINonLinear/Results/' fMRIName '/' fMRIName '_hp' hp '.ica/reclean_features.mat'], 'NewFeatures', '-v7.3')
        save([SubjFolderlist '/MNINonLinear/Results/' fMRIName '/' fMRIName '_hp' hp '.ica/fix_prob.mat'], 'probs', '-v7.3')

        T_fix = cell2table(num2cell(OrigFeatures), 'RowNames', row_names);
        T_reclean = cell2table(num2cell(NewFeatures), 'RowNames', row_names);
        T_fix_prob = cell2table(num2cell(probs), 'RowNames', row_names);
        T_fix_reclean = cell2table(num2cell([OrigFeatures, NewFeatures]), 'RowNames', row_names);

        writetable(T_fix, [SubjFolderlist '/MNINonLinear/Results/' fMRIName '/' fMRIName '_hp' hp '.ica/original_fix_features.csv'], 'WriteRowNames', true);
        writetable(T_reclean, [SubjFolderlist '/MNINonLinear/Results/' fMRIName '/' fMRIName '_hp' hp '.ica/reclean_features.csv'], 'WriteRowNames', true);
        writetable(T_fix_reclean, [SubjFolderlist '/MNINonLinear/Results/' fMRIName '/' fMRIName '_hp' hp '.ica/fix_reclean_features.csv'], 'WriteRowNames', true);
        writetable(T_fix_prob, [SubjFolderlist '/MNINonLinear/Results/' fMRIName '/' fMRIName '_hp' hp '.ica/fix_prob.csv'], 'WriteRowNames', true);
    end
end

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
