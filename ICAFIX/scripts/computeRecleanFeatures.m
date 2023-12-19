function computeRecleanFeatures(StudyFolder, ...
                                SubjListName, ...
                                fMRIListName, ...
                                RunsXNumTimePoints, ...
                                hp, ...
                                Resolution, ...
                                CorticalParcellationFile, ...
                                SubRegionParcellationFile, ...
                                WMLabelFile, ...
                                CSFLabelFile)

HCPPIPEDIR = getenv('HCPPIPEDIR')

Subjlist = myreadtext(SubjListName);
fMRINames = myreadtext(fMRIListName);
RunsXNumTimePoints = str2double(RunsXNumTimePoints);
ResolutionNum = str2double(Resolution);

CorticalParcellation=ciftiopen(CorticalParcellationFile,'wb_command');

VisualAreas=[1 2 3 4 5 6 7 13 16 17 18 19 20 21 22 23 48 49 142 152 153 154 156 158 159 160 163 181 182 183 184 185 186 187 193 196 197 198 199 200 201 202 203 228 229 322 332 333 334 336 338 339 340 343];
VisualROI=single(zeros(length(CorticalParcellation.cdata),1));
for i=VisualAreas
    VisualROI(CorticalParcellation.cdata==i)=1;
end
NonVisualROI=(VisualROI-1)*-1;
VisualROI=[VisualROI' single(zeros(1,91282-length(VisualROI)))]';
NonVisualROI=[NonVisualROI' single(zeros(1,91282-length(NonVisualROI)))]';

LanguageAreas=[12 25 26 43 44 74 75 192 205 206 223 224 244 245];
LanguageROI=single(zeros(length(CorticalParcellation.cdata),1));
for i=LanguageAreas
    LanguageROI(CorticalParcellation.cdata==i)=1;
end
NonLanguageROI=(LanguageROI-1)*-1;
LanguageROI=[LanguageROI' single(zeros(1,91282-length(LanguageROI)))]';
NonLanguageROI=[NonLanguageROI' single(zeros(1,91282-length(NonLanguageROI)))]';

CorticalParcellation.cdata(length(CorticalParcellation.cdata)+1:91282,1)=0;

SubRegionParcellation=ciftiopen(SubRegionParcellationFile,'wb_command');
SubRegionParcellation.cdata(length(SubRegionParcellation.cdata)+1:91282,1)=0;

SubRegions=[176 177 178 179 180 356 357 358 359 360];

FinalSpatialSmoothingFWHM=4;

% Calculate AdditionalSigma
%AdditionalSigma = FinalSpatialSmoothingFWHM / (2 * (sqrt(2 * log(2))));
%AdditionalSigmaString=num2str(AdditionalSigma, '%0.20f');

for i=1:length(Subjlist)
    subj=Subjlist{i};
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
            %unix(['/media/myelin/brainmappers/Connectome_Project/YA_HCP_Final/Scripts/MSMAllResampleAndSmoothSICA.sh ' SubjFolderlist ' ' subj ' ' fMRIName ' ' hp ' ' Resolution ' ' num2str(FinalSpatialSmoothingFWHM) ' wb_command']);
            CIFTI_file=[SubjFolderlist '/MNINonLinear/Results/' fMRIName '/' fMRIName '_hp' hp '.ica/filtered_func_data.ica/melodic_oIC.dscalar.nii'];
            CIFTIMSMAll_file=[SubjFolderlist '/MNINonLinear/Results/' fMRIName '/' fMRIName '_hp' hp '.ica/filtered_func_data.ica/melodic_oIC_MSMAll.dscalar.nii'];
            CIFTIMSMAll_smooth_file=[SubjFolderlist '/MNINonLinear/Results/' fMRIName '/' fMRIName '_hp' hp '.ica/filtered_func_data.ica/melodic_oIC_MSMAll_4.dscalar.nii'];
            fs_path=[SubjFolderlist '/MNINonLinear/fsaverage_LR32k'];
            native_path=[SubjFolderlist '/MNINonLinear/Native'];
            vn_file_path=[SubjFolderlist '/MNINonLinear/Results/' fMRIName '/' fMRIName '_Atlas_MSMAll_hp' hp '_clean_vn.dscalar.nii'];
            vn_smooth_file_path=[SubjFolderlist '/MNINonLinear/Results/' fMRIName '/' fMRIName '_Atlas_MSMAll_hp' hp '_clean_vn_' num2str(FinalSpatialSmoothingFWHM) '.dscalar.nii'];

            left_msmsulc_msmall_cmd=['wb_command -surface-sphere-project-unproject ' fs_path '/' subj '.L.sphere.32k_fs_LR.surf.gii ' native_path '/' subj '.L.sphere.MSMSulc.native.surf.gii ' native_path '/' subj '.L.sphere.MSMAll.native.surf.gii ' fs_path '/' subj '.L.sphere.MSMSulc_MSMAll.32k_fs_LR.surf.gii'];
            unix(left_msmsulc_msmall_cmd);
            right_msmsulc_msmall_cmd=['wb_command -surface-sphere-project-unproject ' fs_path '/' subj '.R.sphere.32k_fs_LR.surf.gii ' native_path '/' subj '.R.sphere.MSMSulc.native.surf.gii ' native_path '/' subj '.R.sphere.MSMAll.native.surf.gii ' fs_path '/' subj '.R.sphere.MSMSulc_MSMAll.32k_fs_LR.surf.gii'];
            unix(right_msmsulc_msmall_cmd);
            surf_resample_cmd=['wb_command -cifti-resample ' CIFTI_file ' COLUMN ' CIFTI_file ' COLUMN ADAP_BARY_AREA ENCLOSING_VOXEL ' CIFTIMSMAll_file ' -surface-postdilate 10 -nearest -left-spheres ' fs_path '/' subj '.L.sphere.MSMSulc_MSMAll.32k_fs_LR.surf.gii ' fs_path '/' subj '.L.sphere.32k_fs_LR.surf.gii -left-area-surfs ' fs_path '/' subj '.L.midthickness.32k_fs_LR.surf.gii ' fs_path '/' subj '.L.midthickness_MSMAll.32k_fs_LR.surf.gii -right-spheres ' fs_path '/' subj '.R.sphere.MSMSulc_MSMAll.32k_fs_LR.surf.gii ' fs_path '/' subj '.R.sphere.32k_fs_LR.surf.gii -right-area-surfs ' fs_path '/' subj '.L.midthickness.32k_fs_LR.surf.gii ' fs_path '/' subj '.L.midthickness_MSMAll.32k_fs_LR.surf.gii'];
            unix(surf_resample_cmd);
            surf_smooth_cmd=['wb_command -cifti-smoothing ' CIFTIMSMAll_file ' 1.47106851007471610247 1.47106851007471610247 COLUMN ' CIFTIMSMAll_smooth_file ' -left-surface ' fs_path '/' subj '.L.midthickness_MSMAll.32k_fs_LR.surf.gii -right-surface ' fs_path '/' subj '.R.midthickness_MSMAll.32k_fs_LR.surf.gii'];
            unix(surf_smooth_cmd);
            vn_smooth_cmd=['wb_command -cifti-smoothing ' vn_file_path ' 1.47106851007471610247 1.47106851007471610247 COLUMN ' vn_smooth_file_path ' -left-surface ' fs_path '/' subj '.L.midthickness_MSMAll.32k_fs_LR.surf.gii -right-surface ' fs_path '/' subj '.R.midthickness_MSMAll.32k_fs_LR.surf.gii'];
            unix(vn_smooth_cmd);

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

            csf_cmd=['wb_command -volume-label-import ' ROIFolder '/wmparc.' Resolution '.nii.gz ' CSFLabelFile ' ' ROIFolder '/CSFReg.' Resolution '.nii.gz -discard-others -drop-unused-labels'];
            unix(csf_cmd);
            wm_cmd=['wb_command -volume-label-import ' ROIFolder '/wmparc.' Resolution '.nii.gz ' WMLabelFile ' ' ROIFolder '/WMReg.' Resolution '.nii.gz -discard-others -drop-unused-labels'];
            unix(wm_cmd);

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

            NonGreyParcels=[4 5 14 15 24 31 43 44 63 72 213 221 2 41 77 78 79 85 100 109 155 156 157 158 159 160 161 162 192 219 223 251 252 253 254 255 703 3000 3001 3002 3003 3004 3005 3006 3007 3008 3009 3010 3011 3012 3013 3014 3015 3016 3017 3018 3019 3020 3021 3022 3023 3024 3025 3026 3027 3028 3029 3030 3031 3032 3033 3034 3035 3100 3101 3102 3103 3104 3105 3106 3107 3108 3109 3110 3111 3112 3113 3114 3115 3116 3117 3118 3119 3120 3121 3122 3123 3124 3125 3126 3127 3128 3129 3130 3131 3132 3133 3134 3135 3136 3137 3138 3139 3140 3141 3142 3143 3144 3145 3146 3147 3148 3149 3150 3151 3152 3153 3154 3155 3156 3157 3158 3159 3160 3161 3162 3163 3164 3165 3166 3167 3168 3169 3170 3171 3172 3173 3174 3175 3176 3177 3178 3179 3180 3181 4000 4001 4002 4003 4004 4005 4006 4007 4008 4009 4010 4011 4012 4013 4014 4015 4016 4017 4018 4019 4020 4021 4022 4023 4024 4025 4026 4027 4028 4029 4030 4031 4032 4033 4034 4035 4100 4101 4102 4103 4104 4105 4106 4107 4108 4109 4110 4111 4112 4113 4114 4115 4116 4117 4118 4119 4120 4121 4122 4123 4124 4125 4126 4127 4128 4129 4130 4131 4132 4133 4134 4135 4136 4137 4138 4139 4140 4141 4142 4143 4144 4145 4146 4147 4148 4149 4150 4151 4152 4153 4154 4155 4156 4157 4158 4159 4160 4161 4162 4163 4164 4165 4166 4167 4168 4169 4170 4171 4172 4173 4174 4175 4176 4177 4178 4179 4180 4181 5001 5002 13100 13101 13102 13103 13104 13105 13106 13107 13108 13109 13110 13111 13112 13113 13114 13115 13116 13117 13118 13119 13120 13121 13122 13123 13124 13125 13126 13127 13128 13129 13130 13131 13132 13133 13134 13135 13136 13137 13138 13139 13140 13141 13142 13143 13144 13145 13146 13147 13148 13149 13150 13151 13152 13153 13154 13155 13156 13157 13158 13159 13160 13161 13162 13163 13164 13165 13166 13167 13168 13169 13170 13171 13172 13173 13174 13175 14100 14101 14102 14103 14104 14105 14106 14107 14108 14109 14110 14111 14112 14113 14114 14115 14116 14117 14118 14119 14120 14121 14122 14123 14124 14125 14126 14127 14128 14129 14130 14131 14132 14133 14134 14135 14136 14137 14138 14139 14140 14141 14142 14143 14144 14145 14146 14147 14148 14149 14150 14151 14152 14153 14154 14155 14156 14157 14158 14159 14160 14161 14162 14163 14164 14165 14166 14167 14168 14169 14170 14171 14172 14173 14174 14175];
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
            unix(['fslcpgeom ' SubjFolderlist '/MNINonLinear/Results/' fMRIName '/' fMRIName '_SBRef.nii.gz ' SubjFolderlist '/MNINonLinear/ROIs/VolumeSmoothROIs.' Resolution '.nii.gz -d']);
            unix([HCPPIPEDIR '/ICAFIX/scripts/VolumeSmoothSICA.sh ' SubjFolderlist ' ' subj ' ' fMRIName ' ' hp ' ' Resolution ' ' num2str(FinalSpatialSmoothingFWHM) ' wb_command']);
            VOLUMESMOOTH=read_avw([SubjFolderlist '/MNINonLinear/Results/' fMRIName '/' fMRIName '_hp' hp '.ica/filtered_func_data.ica/melodic_oIC_s' num2str(FinalSpatialSmoothingFWHM) '.nii.gz']);
            VOLUMESMOOTH=reshape(VOLUMESMOOTH,size(VOLUMESMOOTH,1)*size(VOLUMESMOOTH,2)*size(VOLUMESMOOTH,3),size(VOLUMESMOOTH,4));
            VolumeSmooth.cdata=VOLUMESMOOTH(std(VOLUMESMOOTH,[],2)>0,:);
            VolumeSmooth.cdata=VolumeSmooth.cdata./std(Volume.cdata(:));
            CIFTIMSMAllSmooth.cdata=CIFTIMSMAllSmooth.cdata./std(CIFTIMSMAll.cdata(:));
            
            row_names=cell(size(sICA,2), 1);
            clear probs
            for k=1:size(sICA,2)
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
                NewFeatures(k,8)=sum(abs(CIFTI.cdata(1:29696+29716,k)))./sum(abs(Volume.cdata(:,k))); %Cerebral Cortex/Volume
                NewFeatures(k,9)=sum(abs(CIFTI.cdata(29696+29716:end,k)))./sum(abs(Volume.cdata(:,k))); %Subcortical/Volume
                NewFeatures(k,10)=sum(abs(CIFTI.cdata(65289+1:83142,k)))./sum(abs(Volume.cdata(:,k))); %Cerebellum/Volume
                NewFeatures(k,11)=sum(abs(CIFTI.cdata(60334+1:60334+1+3472,k)))./sum(abs(Volume.cdata(:,k))); %Brainstem/Volume
                NewFeatures(k,12)=sum(abs(CIFTI.cdata(setdiff(1:91282,[1:29696+29716 60334+1:60334+1+3472 65289+1:83142]),k)))./sum(abs(Volume.cdata(:,k))); %Diencephalon/Volume
                NewFeatures(k,13)=sum(abs(CIFTI.cdata(1:29696,k)))./sum(abs(CIFTI.cdata(29696+1:29696+29716,k))); %Left Cerebral Cortex/Right Cerebral Cortex
                NewFeatures(k,14)=sum(abs(Volume.cdata(wm.cdata==1,k)))./sum(abs(Volume.cdata(:,k))); %2 Voxel Eroded WM/Volume
                NewFeatures(k,15)=sum(abs(Volume.cdata(csf.cdata==1,k)))./sum(abs(Volume.cdata(:,k))); %2 Voxel Eroded CSF/Volume
                NewFeatures(k,16)=sum(abs(Volume.cdata(edge.cdata==1,k)))./sum(abs(Volume.cdata(:,k))); %Edge/Volume (CSF outside brain)
                NewFeatures(k,17)=sum(abs(Volume.cdata(dropout.cdata>0.5,k)))./sum(abs(Volume.cdata(:,k))); %Dropout/Volume (computed using HCP Pipelines from SE and GRE Images)
                NewFeatures(k,18)=sum(abs(CIFTI.cdata(CIFTIDropouts.cdata>0.25,k)))./sum(abs(CIFTI.cdata(:,k))); %CIFTIDropout/CIFTI (computed using HCP Pipelines from SE and GRE Images)
                NewFeatures(k,19)=sum(abs(Volume.cdata(noisy.cdata==1,k)))./sum(abs(CIFTI.cdata(:,k))); %NoisyVoxels/CIFTI (top 12.5% variance)
                NewFeatures(k,20)=sum(abs(CIFTIMSMAll.cdata(VisualROI==1,k)))./sum(abs(CIFTIMSMAll.cdata(NonVisualROI==1,k))); %VisualCortexCIFTI/NonVisualCortexCIFTI
                NewFeatures(k,21)=sum(abs(CIFTIMSMAll.cdata(VisualROI==1,k)))./sum(abs(CIFTIMSMAll.cdata(65289+1:83142,k))); %VisualCortexCIFTI/CerebellumCIFTI              
                NewFeatures(k,22)=sum(abs(CIFTIMSMAll.cdata(LanguageROI==1,k)))./sum(abs(CIFTIMSMAll.cdata(NonLanguageROI==1,k))); %LanguageCortexCIFTI/NonLanguageCortexCIFTI
                NewFeatures(k,23)=sum(abs(CIFTI.cdata(:,k)))./sum(abs(Volume.cdata(NonGrey==1,k))); %CIFTI/NonGrey
                NewFeatures(k,24)=sum(abs(CIFTI.cdata(1:29696+29716,k)))./sum(abs(Volume.cdata(NonGrey==1,k))); %Cerebral Cortex/NonGrey
                NewFeatures(k,25)=sum(abs(CIFTI.cdata(:,k)))./sum(abs(Volume.cdata(NonGreyPlusEdge==1,k))); %CIFTI/NonGreyPlusEdge
                NewFeatures(k,26)=sum(abs(CIFTI.cdata(1:29696+29716,k)))./sum(abs(Volume.cdata(NonGreyPlusEdge==1,k))); %Cerebral Cortex/NonGreyPlusEdge
                NewFeatures(k,27)=sum(abs(CIFTIMSMAllSmooth.cdata(:,k)))./sum(abs(VolumeSmooth.cdata(NonGrey==1,k))); %CIFTI/NonGrey
                NewFeatures(k,28)=sum(abs(CIFTIMSMAllSmooth.cdata(1:29696+29716,k)))./sum(abs(VolumeSmooth.cdata(NonGrey==1,k))); %Cerebral Cortex/NonGrey
                NewFeatures(k,29)=sum(abs(CIFTIMSMAllSmooth.cdata(:,k)))./sum(abs(VolumeSmooth.cdata(NonGreyPlusEdge==1,k))); %CIFTI/NonGreyPlusEdge
                NewFeatures(k,30)=sum(abs(CIFTIMSMAllSmooth.cdata(1:29696+29716,k)))./sum(abs(VolumeSmooth.cdata(NonGreyPlusEdge==1,k))); %Cerebral Cortex/NonGreyPlusEdge


                NewFeatures(k,31)=mean(abs(CIFTI.cdata(:,k)))./mean(abs(Volume.cdata(:,k))); %CIFTI/Volume
                NewFeatures(k,32)=mean(abs(CIFTI.cdata(1:29696+29716,k)))./mean(abs(Volume.cdata(:,k))); %Cerebral Cortex/Volume
                NewFeatures(k,33)=mean(abs(CIFTI.cdata(29696+29716:end,k)))./mean(abs(Volume.cdata(:,k))); %Subcortical/Volume
                NewFeatures(k,34)=mean(abs(CIFTI.cdata(65289+1:83142,k)))./mean(abs(Volume.cdata(:,k))); %Cerebellum/Volume
                NewFeatures(k,35)=mean(abs(CIFTI.cdata(60334+1:60334+1+3472,k)))./mean(abs(Volume.cdata(:,k))); %Brainstem/Volume
                NewFeatures(k,36)=mean(abs(CIFTI.cdata(setdiff(1:91282,[1:29696+29716 60334+1:60334+1+3472 65289+1:83142]),k)))./mean(abs(Volume.cdata(:,k))); %Diencephalon/Volume
                NewFeatures(k,37)=mean(abs(CIFTI.cdata(1:29696,k)))./mean(abs(CIFTI.cdata(29696+1:29696+29716,k))); %Left Cerebral Cortex/Right Cerebral Cortex
                NewFeatures(k,38)=mean(abs(Volume.cdata(wm.cdata==1,k)))./mean(abs(Volume.cdata(:,k))); %2 Voxel Eroded WM/Volume
                NewFeatures(k,39)=mean(abs(Volume.cdata(csf.cdata==1,k)))./mean(abs(Volume.cdata(:,k))); %2 Voxel Eroded CSF/Volume
                NewFeatures(k,40)=mean(abs(Volume.cdata(edge.cdata==1,k)))./mean(abs(Volume.cdata(:,k))); %Edge/Volume (CSF outside brain)
                NewFeatures(k,41)=mean(abs(Volume.cdata(dropout.cdata>0.5,k)))./mean(abs(Volume.cdata(:,k))); %Dropout/Volume (computed using HCP Pipelines from SE and GRE Images)
                NewFeatures(k,42)=mean(abs(CIFTI.cdata(CIFTIDropouts.cdata>0.25,k)))./mean(abs(CIFTI.cdata(:,k))); %CIFTIDropout/CIFTI (computed using HCP Pipelines from SE and GRE Images)
                NewFeatures(k,43)=mean(abs(Volume.cdata(noisy.cdata==1,k)))./mean(abs(CIFTI.cdata(:,k))); %NoisyVoxels/CIFTI (top 12.5% variance)
                NewFeatures(k,44)=mean(abs(CIFTIMSMAll.cdata(VisualROI==1,k)))./mean(abs(CIFTIMSMAll.cdata(NonVisualROI==1,k))); %VisualCortexCIFTI/NonVisualCortexCIFTI
                NewFeatures(k,45)=mean(abs(CIFTIMSMAll.cdata(VisualROI==1,k)))./mean(abs(CIFTIMSMAll.cdata(65289+1:83142,k))); %VisualCortexCIFTI/CerebellumCIFTI              
                NewFeatures(k,46)=mean(abs(CIFTIMSMAll.cdata(LanguageROI==1,k)))./mean(abs(CIFTIMSMAll.cdata(NonLanguageROI==1,k))); %LanguageCortexCIFTI/NonLanguageCortexCIFTI
                NewFeatures(k,47)=mean(abs(CIFTI.cdata(:,k)))./mean(abs(Volume.cdata(NonGrey==1,k))); %CIFTI/NonGrey
                NewFeatures(k,48)=mean(abs(CIFTI.cdata(1:29696+29716,k)))./mean(abs(Volume.cdata(NonGrey==1,k))); %Cerebral Cortex/NonGrey
                NewFeatures(k,49)=mean(abs(CIFTI.cdata(:,k)))./mean(abs(Volume.cdata(NonGreyPlusEdge==1,k))); %CIFTI/NonGreyPlusEdge
                NewFeatures(k,50)=mean(abs(CIFTI.cdata(1:29696+29716,k)))./mean(abs(Volume.cdata(NonGreyPlusEdge==1,k))); %Cerebral Cortex/NonGreyPlusEdge
                NewFeatures(k,51)=mean(abs(CIFTIMSMAllSmooth.cdata(:,k)))./mean(abs(VolumeSmooth.cdata(NonGrey==1,k))); %CIFTI/NonGrey
                NewFeatures(k,52)=mean(abs(CIFTIMSMAllSmooth.cdata(1:29696+29716,k)))./mean(abs(VolumeSmooth.cdata(NonGrey==1,k))); %Cerebral Cortex/NonGrey
                NewFeatures(k,53)=mean(abs(CIFTIMSMAllSmooth.cdata(:,k)))./mean(abs(VolumeSmooth.cdata(NonGreyPlusEdge==1,k))); %CIFTI/NonGreyPlusEdge
                NewFeatures(k,54)=mean(abs(CIFTIMSMAllSmooth.cdata(1:29696+29716,k)))./mean(abs(VolumeSmooth.cdata(NonGreyPlusEdge==1,k))); %Cerebral Cortex/NonGreyPlusEdge


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
