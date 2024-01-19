function computeRecleanFeatures(StudyFolder, ...
                                Subject, ...
                                fMRIListName, ...
                                RunsXNumTimePoints, ...
                                hp, ...
                                Resolution, ...
                                CorticalParcellationFile, ...
                                WMLabelFile, ...
                                CSFLabelFile, VisualAreasFile, LanguageAreasFile, SubRegionsFile, NonGreyParcelsFile)

fMRINames = myreadtext(fMRIListName);
RunsXNumTimePoints = str2double(RunsXNumTimePoints);

CorticalParcellation=ciftiopen(CorticalParcellationFile,'wb_command');
VisualROI_CIFTI=ciftiopen(VisualAreasFile,'wb_command');
VisualROI=VisualROI_CIFTI.cdata;
NonVisualROI=1-VisualROI_CIFTI.cdata;

LanguageROI_CIFTI=ciftiopen(LanguageAreasFile,'wb_command');
LanguageROI=LanguageROI_CIFTI.cdata;
NonLanguageROI=1-LanguageROI_CIFTI.cdata;

SubRegionsROI=ciftiopen(SubRegionsFile,'wb_command');

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

    MelodicFile=[SubjFolderlist '/MNINonLinear/Results/' fMRIName '/' fMRIName '_hp' hp '.ica/filtered_func_data.ica/melodic_mix'];
    if exist(MelodicFile,'file')
        sICA=load(MelodicFile);
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
        system(['wb_command -volume-label-import ' ROIFolder '/wmparc.' Resolution '.nii.gz ' NonGreyParcelsFile ' ' ROIFolder '/NonGrey.' Resolution '.nii.gz -discard-others -drop-unused-labels']);

        WM=read_avw([SubjFolderlist '/MNINonLinear/ROIs/WMReg.' Resolution '.nii.gz']);
        CSF=read_avw([SubjFolderlist '/MNINonLinear/ROIs/CSFReg.' Resolution '.nii.gz']);
        NONGREY=read_avw([SubjFolderlist '/MNINonLinear/ROIs/NonGrey.' Resolution '.nii.gz']);
        % dropout file is not ready for lifespan
        %DROPOUT=read_avw([SubjFolderlist '/MNINonLinear/Results/' fMRIName '/' fMRIName '_dropouts.nii.gz']);
        dropout_file=[SubjFolderlist '/MNINonLinear/Results/' fMRIName '/' fMRIName '_dropouts.nii.gz'];

        DROPOUT=read_avw(dropout_file);
        VOLUME=read_avw([SubjFolderlist '/MNINonLinear/Results/' fMRIName '/' fMRIName '_hp' hp '.ica/filtered_func_data.ica/melodic_oIC.nii.gz']);
        SBREFOrig = read_avw([SubjFolderlist '/MNINonLinear/Results/' fMRIName '/' fMRIName '_SBRef.nii.gz']);
        
        VOLUME = reshape(VOLUME, prod([size(VOLUME, 1), size(VOLUME, 2), size(VOLUME, 3)]), size(VOLUME, 4));
        volumeValid = range(VOLUME, 2) > 0;
        Volume_data = VOLUME(volumeValid, :);
        
        [wmparc_data, WMPARC] = vol_reshape_and_mask(WMPARC, volumeValid);
        wm_data = vol_reshape_and_mask(WM, volumeValid);
        csf_data = vol_reshape_and_mask(CSF, volumeValid);
        nongray_data = vol_reshape_and_mask(NONGREY, volumeValid);
        dropout_data = vol_reshape_and_mask(DROPOUT, volumeValid);
        sbref_data = vol_reshape_and_mask(SBREFOrig, volumeValid);
        
        wm_data(wm_data ~= 0) = 1;
        csf_data(csf_data ~= 0) = 1;
        noisy_data=(sum(Volume_data,2)./sbref_data)>prctile(sum(Volume_data,2)./sbref_data,87.5);
        edge_data=wmparc_data==0;
        Volume_data=Volume_data./std(Volume_data(:));
        CIFTI.cdata=CIFTI.cdata./std(CIFTI.cdata(:));
        
        nongray_data(nongray_data ~= 0) =1;

        NonGrey=nongray_data;
        NonGreyPlusEdge=NonGrey+edge_data;
        Grey=(NonGreyPlusEdge-1)*-1;
        VolSmoothROIs_data=wmparc_data.*0;
        VolSmoothROIs_data(NonGrey==1)=1;
        VolSmoothROIs_data(Grey==1)=2;
        VolSmoothROIs_data(edge_data==1)=3;
        VOLSMOOTHROIS=WMPARC.*0;
        VOLSMOOTHROIS(volumeValid) = VolSmoothROIs_data;
        VOLSMOOTHROIS=reshape(VOLSMOOTHROIS,size(SBREFOrig,1),size(SBREFOrig,2),size(SBREFOrig,3),size(SBREFOrig,4));
        save_avw(VOLSMOOTHROIS,[SubjFolderlist '/MNINonLinear/ROIs/VolumeSmoothROIs.' Resolution '.nii.gz'],'f',[1.6 1.6 1.6 1]);
        system(['fslcpgeom ' SubjFolderlist '/MNINonLinear/Results/' fMRIName '/' fMRIName '_SBRef.nii.gz ' SubjFolderlist '/MNINonLinear/ROIs/VolumeSmoothROIs.' Resolution '.nii.gz -d']);
        
        SmoothingSigma=FinalSpatialSmoothingFWHM/(2*sqrt(2*log(2)));
        system(['wb_command -volume-label-import ' SubjFolderlist '/MNINonLinear/ROIs/VolumeSmoothROIs.' Resolution '.nii.gz "" ' SubjFolderlist '/MNINonLinear/ROIs/VolumeSmoothROIs.' Resolution '.nii.gz']);
        system(['wb_command -volume-parcel-smoothing ' SubjFolderlist '/MNINonLinear/Results/' fMRIName '/' fMRIName '_hp' hp '.ica/filtered_func_data.ica/melodic_oIC.nii.gz ' SubjFolderlist '/MNINonLinear/ROIs/VolumeSmoothROIs.' Resolution '.nii.gz ' num2str(SmoothingSigma) ' ' SubjFolderlist '/MNINonLinear/Results/' fMRIName '/' fMRIName '_hp' hp '.ica/filtered_func_data.ica/melodic_oIC_FWHM' num2str(FinalSpatialSmoothingFWHM) '.nii.gz']);

        VOLUMESMOOTH=read_avw([SubjFolderlist '/MNINonLinear/Results/' fMRIName '/' fMRIName '_hp' hp '.ica/filtered_func_data.ica/melodic_oIC_FWHM' num2str(FinalSpatialSmoothingFWHM) '.nii.gz']);
        VolumeSmooth_data = vol_reshape_and_mask(VOLUMESMOOTH, volumeValid);
        VolumeSmooth_data=VolumeSmooth_data./std(Volume_data(:));
        CIFTIMSMAllSmooth.cdata=CIFTIMSMAllSmooth.cdata./std(CIFTIMSMAll.cdata(:));
        
        % structure idx
        CIFTI_LENGTH=length(CIFTI.cdata);

        CORTEX_Left_idx_list_tmp = cifti_diminfo_dense_get_surface_info(CIFTI.diminfo{1}, 'CORTEX_LEFT');
        CORTEX_Left_idx_list = CORTEX_Left_idx_list_tmp.ciftilist;

        CORTEX_Right_idx_list_tmp = cifti_diminfo_dense_get_surface_info(CIFTI.diminfo{1}, 'CORTEX_RIGHT');
        CORTEX_Right_idx_list = CORTEX_Right_idx_list_tmp.ciftilist;

        CORTEX_idx_list = [CORTEX_Left_idx_list, CORTEX_Right_idx_list];

        CEREBELLUM_Left_idx_list_tmp = cifti_diminfo_dense_get_volume_structure_info(CIFTI.diminfo{1}, 'CEREBELLUM_LEFT');
        CEREBELLUM_Left_idx_list = CEREBELLUM_Left_idx_list_tmp.ciftilist;

        CEREBELLUM_Right_idx_list_tmp = cifti_diminfo_dense_get_volume_structure_info(CIFTI.diminfo{1}, 'CEREBELLUM_RIGHT');
        CEREBELLUM_Right_idx_list = CEREBELLUM_Right_idx_list_tmp.ciftilist;

        CEREBELLUM_idx_list = [CEREBELLUM_Left_idx_list, CEREBELLUM_Right_idx_list];
        
        BRAIN_STEM_idx_list_tmp = cifti_diminfo_dense_get_volume_structure_info(CIFTI.diminfo{1}, 'BRAIN_STEM');
        BRAIN_STEM_idx_list = BRAIN_STEM_idx_list_tmp.ciftilist;

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
            NewFeatures(k,7)=sum(abs(CIFTI.cdata(:,k)))./sum(abs(Volume_data(:,k))); %CIFTI/Volume
            NewFeatures(k, 8)=sum(abs(CIFTI.cdata(CORTEX_idx_list, k))) ./ sum(abs(Volume_data(:, k))); %Cerebral Cortex/Volume
            NewFeatures(k,9)=sum(abs(CIFTI.cdata(setdiff(1:CIFTI_LENGTH,[CORTEX_idx_list]),k)))./sum(abs(Volume_data(:,k))); %Subcortical/Volume
            NewFeatures(k,10)=sum(abs(CIFTI.cdata(CEREBELLUM_idx_list,k)))./sum(abs(Volume_data(:,k))); %Cerebellum/Volume
            NewFeatures(k,11)=sum(abs(CIFTI.cdata(BRAIN_STEM_idx_list,k)))./sum(abs(Volume_data(:,k))); %Brainstem/Volume
            NewFeatures(k,12)=sum(abs(CIFTI.cdata(setdiff(1:CIFTI_LENGTH,[CORTEX_idx_list BRAIN_STEM_idx_list CEREBELLUM_idx_list]),k)))./sum(abs(Volume_data(:,k))); %Diencephalon/Volume
            NewFeatures(k,13)=sum(abs(CIFTI.cdata(CORTEX_Left_idx_list,k)))./sum(abs(CIFTI.cdata(CORTEX_Right_idx_list,k))); %Left Cerebral Cortex/Right Cerebral Cortex
            NewFeatures(k,14)=sum(abs(Volume_data(wm_data==1,k)))./sum(abs(Volume_data(:,k))); %2 Voxel Eroded WM/Volume
            NewFeatures(k,15)=sum(abs(Volume_data(csf_data==1,k)))./sum(abs(Volume_data(:,k))); %2 Voxel Eroded CSF/Volume
            NewFeatures(k,16)=sum(abs(Volume_data(edge_data==1,k)))./sum(abs(Volume_data(:,k))); %Edge/Volume (CSF outside brain)
            NewFeatures(k,17)=sum(abs(Volume_data(dropout_data>0.5,k)))./sum(abs(Volume_data(:,k))); %Dropout/Volume (computed using HCP Pipelines from SE and GRE Images)
            NewFeatures(k,18)=sum(abs(CIFTI.cdata(CIFTIDropouts.cdata>0.25,k)))./sum(abs(CIFTI.cdata(:,k))); %CIFTIDropout/CIFTI (computed using HCP Pipelines from SE and GRE Images)
            NewFeatures(k,19)=sum(abs(Volume_data(noisy_data==1,k)))./sum(abs(CIFTI.cdata(:,k))); %NoisyVoxels/CIFTI (top 12.5% variance)
            NewFeatures(k,20)=sum(abs(CIFTIMSMAll.cdata(VisualROI==1,k)))./sum(abs(CIFTIMSMAll.cdata(NonVisualROI==1,k))); %VisualCortexCIFTI/NonVisualCortexCIFTI
            NewFeatures(k,21)=sum(abs(CIFTIMSMAll.cdata(VisualROI==1,k)))./sum(abs(CIFTIMSMAll.cdata(CEREBELLUM_idx_list,k))); %VisualCortexCIFTI/CerebellumCIFTI              
            NewFeatures(k,22)=sum(abs(CIFTIMSMAll.cdata(LanguageROI==1,k)))./sum(abs(CIFTIMSMAll.cdata(NonLanguageROI==1,k))); %LanguageCortexCIFTI/NonLanguageCortexCIFTI
            NewFeatures(k,23)=sum(abs(CIFTI.cdata(:,k)))./sum(abs(Volume_data(NonGrey==1,k))); %CIFTI/NonGrey
            NewFeatures(k,24)=sum(abs(CIFTI.cdata(CORTEX_idx_list,k)))./sum(abs(Volume_data(NonGrey==1,k))); %Cerebral Cortex/NonGrey
            NewFeatures(k,25)=sum(abs(CIFTI.cdata(:,k)))./sum(abs(Volume_data(NonGreyPlusEdge==1,k))); %CIFTI/NonGreyPlusEdge
            NewFeatures(k,26)=sum(abs(CIFTI.cdata(CORTEX_idx_list,k)))./sum(abs(Volume_data(NonGreyPlusEdge==1,k))); %Cerebral Cortex/NonGreyPlusEdge
            NewFeatures(k,27)=sum(abs(CIFTIMSMAllSmooth.cdata(:,k)))./sum(abs(VolumeSmooth_data(NonGrey==1,k))); %CIFTI/NonGrey
            NewFeatures(k,28)=sum(abs(CIFTIMSMAllSmooth.cdata(CORTEX_idx_list,k)))./sum(abs(VolumeSmooth_data(NonGrey==1,k))); %Cerebral Cortex/NonGrey
            NewFeatures(k,29)=sum(abs(CIFTIMSMAllSmooth.cdata(:,k)))./sum(abs(VolumeSmooth_data(NonGreyPlusEdge==1,k))); %CIFTI/NonGreyPlusEdge
            NewFeatures(k,30)=sum(abs(CIFTIMSMAllSmooth.cdata(CORTEX_idx_list,k)))./sum(abs(VolumeSmooth_data(NonGreyPlusEdge==1,k))); %Cerebral Cortex/NonGreyPlusEdge

            NewFeatures(k,31)=mean(abs(CIFTI.cdata(:,k)))./mean(abs(Volume_data(:,k))); %CIFTI/Volume
            NewFeatures(k,32)=mean(abs(CIFTI.cdata(CORTEX_idx_list,k)))./mean(abs(Volume_data(:,k))); %Cerebral Cortex/Volume
            NewFeatures(k,33)=mean(abs(CIFTI.cdata(setdiff(1:CIFTI_LENGTH,[CORTEX_idx_list]),k)))./mean(abs(Volume_data(:,k))); %Subcortical/Volume
            NewFeatures(k,34)=mean(abs(CIFTI.cdata(CEREBELLUM_idx_list,k)))./mean(abs(Volume_data(:,k))); %Cerebellum/Volume
            NewFeatures(k,35)=mean(abs(CIFTI.cdata(BRAIN_STEM_idx_list,k)))./mean(abs(Volume_data(:,k))); %Brainstem/Volume
            NewFeatures(k,36)=mean(abs(CIFTI.cdata(setdiff(1:CIFTI_LENGTH,[CORTEX_idx_list BRAIN_STEM_idx_list CEREBELLUM_idx_list]),k)))./mean(abs(Volume_data(:,k))); %Diencephalon/Volume
            NewFeatures(k,37)=mean(abs(CIFTI.cdata(CORTEX_Left_idx_list,k)))./mean(abs(CIFTI.cdata(CORTEX_Right_idx_list,k))); %Left Cerebral Cortex/Right Cerebral Cortex
            NewFeatures(k,38)=mean(abs(Volume_data(wm_data==1,k)))./mean(abs(Volume_data(:,k))); %2 Voxel Eroded WM/Volume
            NewFeatures(k,39)=mean(abs(Volume_data(csf_data==1,k)))./mean(abs(Volume_data(:,k))); %2 Voxel Eroded CSF/Volume
            NewFeatures(k,40)=mean(abs(Volume_data(edge_data==1,k)))./mean(abs(Volume_data(:,k))); %Edge/Volume (CSF outside brain)
            NewFeatures(k,41)=mean(abs(Volume_data(dropout_data>0.5,k)))./mean(abs(Volume_data(:,k))); %Dropout/Volume (computed using HCP Pipelines from SE and GRE Images)
            NewFeatures(k,42)=mean(abs(CIFTI.cdata(CIFTIDropouts.cdata>0.25,k)))./mean(abs(CIFTI.cdata(:,k))); %CIFTIDropout/CIFTI (computed using HCP Pipelines from SE and GRE Images)
            NewFeatures(k,43)=mean(abs(Volume_data(noisy_data==1,k)))./mean(abs(CIFTI.cdata(:,k))); %NoisyVoxels/CIFTI (top 12.5% variance)
            NewFeatures(k,44)=mean(abs(CIFTIMSMAll.cdata(VisualROI==1,k)))./mean(abs(CIFTIMSMAll.cdata(NonVisualROI==1,k))); %VisualCortexCIFTI/NonVisualCortexCIFTI
            NewFeatures(k,45)=mean(abs(CIFTIMSMAll.cdata(VisualROI==1,k)))./mean(abs(CIFTIMSMAll.cdata(CEREBELLUM_idx_list,k))); %VisualCortexCIFTI/CerebellumCIFTI              
            NewFeatures(k,46)=mean(abs(CIFTIMSMAll.cdata(LanguageROI==1,k)))./mean(abs(CIFTIMSMAll.cdata(NonLanguageROI==1,k))); %LanguageCortexCIFTI/NonLanguageCortexCIFTI
            NewFeatures(k,47)=mean(abs(CIFTI.cdata(:,k)))./mean(abs(Volume_data(NonGrey==1,k))); %CIFTI/NonGrey
            NewFeatures(k,48)=mean(abs(CIFTI.cdata(CORTEX_idx_list,k)))./mean(abs(Volume_data(NonGrey==1,k))); %Cerebral Cortex/NonGrey
            NewFeatures(k,49)=mean(abs(CIFTI.cdata(:,k)))./mean(abs(Volume_data(NonGreyPlusEdge==1,k))); %CIFTI/NonGreyPlusEdge
            NewFeatures(k,50)=mean(abs(CIFTI.cdata(CORTEX_idx_list,k)))./mean(abs(Volume_data(NonGreyPlusEdge==1,k))); %Cerebral Cortex/NonGreyPlusEdge
            NewFeatures(k,51)=mean(abs(CIFTIMSMAllSmooth.cdata(:,k)))./mean(abs(VolumeSmooth_data(NonGrey==1,k))); %CIFTI/NonGrey
            NewFeatures(k,52)=mean(abs(CIFTIMSMAllSmooth.cdata(CORTEX_idx_list,k)))./mean(abs(VolumeSmooth_data(NonGrey==1,k))); %Cerebral Cortex/NonGrey
            NewFeatures(k,53)=mean(abs(CIFTIMSMAllSmooth.cdata(:,k)))./mean(abs(VolumeSmooth_data(NonGreyPlusEdge==1,k))); %CIFTI/NonGreyPlusEdge
            NewFeatures(k,54)=mean(abs(CIFTIMSMAllSmooth.cdata(CORTEX_idx_list,k)))./mean(abs(VolumeSmooth_data(NonGreyPlusEdge==1,k))); %Cerebral Cortex/NonGreyPlusEdge

            for idx=1:max(CorticalParcellation.cdata)
                NewFeatures(k,idx+54)=mean(abs(CIFTIMSMAll.cdata(CorticalParcellation.cdata==idx,k)));
            end

            for idx=1:size(SubRegionsROI.cdata, 2)
                NewFeatures(k,idx+54+max(CorticalParcellation.cdata))=mean(abs(CIFTIMSMAll.cdata(SubRegionsROI.cdata(:,idx)==1,k)));
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

function [maskeddata, flatdata] = vol_reshape_and_mask(indata, mask)
    flatdata = reshape(indata, prod([size(indata, 1), size(indata, 2), size(indata, 3)]), size(indata, 4));
    maskeddata = flatdata(mask, :);
end