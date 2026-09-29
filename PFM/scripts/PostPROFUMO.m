function PostPROFUMO(StudyFolder, SubjListRaw, fMRIListRaw, ConcatName, fMRIProcSTRING, OutputfMRIName, OutputSTRING, RegString, LowResMesh, TR, PFMFolder,VarNormBool,VAweightBool)
% PostPROFUMO(StudyFolder, SubjListRaw, fMRIListRaw, ConcatName, fMRIProcSTRING, OutputfMRIName, OutputSTRING, RegString, LowResMesh, TR, PFMFolder)
% This function imports PROFUMO results and generates CIFTI-format time courses
% and power spectra for each subject. The outputs are used for subsequent
% group-level PFM analysis.
%
% Inputs:
%   StudyFolder - Path to the study directory
%   SubjListRaw - Subject list as @ separated string
%   fMRIListRaw - fMRI run names as @ separated string
%   ConcatName - Name of concatenated fMRI dataset (empty if single runs)
%   fMRIProcSTRING - Processing string component (e.g., '_Atlas_hp200_clean')
%   OutputfMRIName - Name of output fMRI dataset
%   OutputSTRING - Output string for files
%   RegString - Registration string
%   LowResMesh - Mesh resolution (e.g., '10' for 10k)
%   TR - Repetition time in seconds
%   PFMFolder - Path to PROFUMO results folder
%   VarNormBool - Boolean flag for variance normalization
%   VAweightBool - Boolean flag for vertex area weighting

%% Parse string inputs and initialize
Subjlist = strsplit(SubjListRaw, '@');
fMRINames = strsplit(fMRIListRaw, '@');
TR = str2double(TR);
VarNormBool = logical(str2double(VarNormBool));
VAweightBool = logical(str2double(VAweightBool));
wbcommand = 'wb_command';
T1wFolder='T1w'; % location of individuals' ACPC-aligned physical-space images
AtlasSpaceFolder='MNINonLinear'; % location of template-space images

%% Main loop: Process each subject
for s = 1:numel(Subjlist)
    fprintf('Processing subject %d/%d: %s\n', s, numel(Subjlist), Subjlist{s});
  
    %% Identify available fMRI runs for this subject
    % Determine which fMRI runs exist for this subject
    % If ConcatName is specified, use concatenated version; otherwise check individual runs
    subfMRINames = {};
    if ~strcmp(ConcatName, '')
        % Multi-run data: check if concatenated dataset exists
        if exist([StudyFolder '/' Subjlist{s} '/' AtlasSpaceFolder '/Results/' ConcatName '/' ConcatName fMRIProcSTRING '.dtseries.nii'],'file')
            c = 1;
            for r = 1:numel(fMRINames)
                if exist([StudyFolder '/' Subjlist{s} '/' AtlasSpaceFolder '/Results/' fMRINames{r} '/' fMRINames{r} fMRIProcSTRING '.dtseries.nii'],'file')
                    subfMRINames{c} = fMRINames{r};
                    c = c + 1;
                end
            end  % for r = 1:numel(fMRINames)            
        end
    else
        % Single-run data: check which runs exist
        c = 1;
        for r = 1:numel(fMRINames)
            if exist([StudyFolder '/' Subjlist{s} '/' AtlasSpaceFolder '/Results/' fMRINames{r} '/' fMRINames{r} fMRIProcSTRING '.dtseries.nii'],'file')
                subfMRINames{c} = fMRINames{r};
                c = c + 1;
            end
        end  % for r = 1:numel(fMRINames)
    end
  
    %% Process subject if valid runs found
    if numel(subfMRINames) ~= 0
        % VN file(s): the concat _vn for multi-run data, or each run's _vn for single runs
        if ~strcmp(ConcatName, '')
            vnFiles = {[StudyFolder '/' Subjlist{s} '/' AtlasSpaceFolder '/Results/' ConcatName '/' ConcatName fMRIProcSTRING '_vn.dscalar.nii']};
        else
            vnFiles = cell(1, numel(subfMRINames));
            for r = 1:numel(subfMRINames)
                vnFiles{r} = [StudyFolder '/' Subjlist{s} '/' AtlasSpaceFolder '/Results/' subfMRINames{r} '/' subfMRINames{r} fMRIProcSTRING '_vn.dscalar.nii'];
            end
        end
        if VAweightBool
          %  create temporary VA_norm cifti with volume grayordinates filled with ones areas for weighting 
          ciftiTemplate = vnFiles{1}; % any _vn file works as the grayordinate template
          VAnorm = [StudyFolder '/' Subjlist{s} '/' T1wFolder '/fsaverage_LR' LowResMesh 'k/' Subjlist{s} '.midthickness' RegString '_va_norm.' LowResMesh 'k_fs_LR.dscalar.nii'];
          tmp_VAgray_file = [tempname '.dscalar.nii'];
          tmp_jnk_file = [tempname '.nii.gz'];
          tmp_roi_file = [tempname '.nii.gz'];
          system(sprintf('%s -cifti-separate "%s" COLUMN -volume-all "%s" -roi "%s" -crop', wbcommand, ciftiTemplate, tmp_jnk_file, tmp_roi_file));
          system(sprintf('%s -cifti-create-dense-from-template "%s" "%s" -cifti "%s" -volume-all "%s" -from-cropped', wbcommand, ciftiTemplate, tmp_VAgray_file, VAnorm, tmp_roi_file));
        end

        %% Load and concatenate PFM time courses and amplitudes
        % Load PROFUMO outputs and amplitude-modulate time courses
        origTCS = [];  % Original unmodulated time courses
        TCS = [];      % Amplitude-modulated time courses
        for r = 1:numel(subfMRINames)
            runTCS = load([PFMFolder '/Results.ppp/TimeCourses/sub-' Subjlist{s} '_run-' subfMRINames{r} '.csv']);
            runAmp = load([PFMFolder '/Results.ppp/Amplitudes/sub-' Subjlist{s} '_run-' subfMRINames{r} '.csv']);

            origTCS = [origTCS ; runTCS];
            TCS = [TCS ; runTCS .* repmat(runAmp', size(runTCS, 1), 1)];
            end  % for r = 1:numel(subfMRINames)
        
        %% Create original time course and spectral CIFTI files
        % Generate CIFTI structure for unmodulated time courses
        PFMTCSorig = cifti_struct_create_sdseries(origTCS','step',TR);
        
        % Store power spectra 
        ts.Nnodes = size(origTCS, 2);
        ts.Nsubjects = 1;
        ts.ts = origTCS;
        ts.NtimepointsPerSubject = size(origTCS, 1);
        PFMSpectraorig = cifti_struct_create_sdseries(nets_spectra_sp(ts)','step',1/TR);
        
        %% Create  time course and spectral CIFTI files
        % Generate CIFTI structure for  time courses
        PFMTCS = cifti_struct_create_sdseries(TCS','step',TR);
        
        % Store power spectra 
        ts.Nnodes = size(TCS, 2);
        ts.Nsubjects = 1;
        ts.ts = TCS;
        ts.NtimepointsPerSubject = size(TCS, 1);
        PFMSpectra = cifti_struct_create_sdseries(nets_spectra_sp(ts)','step',1/TR);

        %% Save non-map results
        % Save original and amplitude-modulated time courses and spectra
        ciftisave(PFMTCSorig, [StudyFolder '/' Subjlist{s} '/' AtlasSpaceFolder '/fsaverage_LR' LowResMesh 'k/' Subjlist{s} '.' OutputSTRING RegString '_ts_orig.' LowResMesh 'k_fs_LR.sdseries.nii'], wbcommand);
        ciftisave(PFMSpectraorig, [StudyFolder '/' Subjlist{s} '/' AtlasSpaceFolder '/fsaverage_LR' LowResMesh 'k/' Subjlist{s} '.' OutputSTRING RegString '_spectra_orig.' LowResMesh 'k_fs_LR.sdseries.nii'], wbcommand);

        ciftisave(PFMTCS, [StudyFolder '/' Subjlist{s} '/' AtlasSpaceFolder '/fsaverage_LR' LowResMesh 'k/' Subjlist{s} '.' OutputSTRING RegString '_ts.' LowResMesh 'k_fs_LR.sdseries.nii'], wbcommand);
        ciftisave(PFMSpectra, [StudyFolder '/' Subjlist{s} '/' AtlasSpaceFolder '/fsaverage_LR' LowResMesh 'k/' Subjlist{s} '.' OutputSTRING RegString '_spectra.' LowResMesh 'k_fs_LR.sdseries.nii'], wbcommand);

        %% Handle maps
        % restore variance
        if VarNormBool
            fprintf('Restoring variance\n');
                        % average VN across runs (a single file for multi-run concat)
            clean_VN = 0;
            for v = 1:numel(vnFiles)
                clean_VN = clean_VN + ciftiopen(vnFiles{v}, wbcommand).cdata;
            end
            clean_VN = clean_VN / numel(vnFiles);
            mapFile = [PFMFolder '/Results.ppp/Maps/sub-' Subjlist{s} '.dscalar.nii'];
            maps = ciftiopen(mapFile, wbcommand);
            maps.cdata = maps.cdata .* clean_VN;
            ciftisave(maps, mapFile, wbcommand);
        end

        % divide out vertex area weights
        if VAweightBool
            fprintf('Dividing out vertex area weights\n');
            VAgray = ciftiopen(tmp_VAgray_file, wbcommand).cdata;
            mapFile = [PFMFolder '/Results.ppp/Maps/sub-' Subjlist{s} '.dscalar.nii'];
            maps = ciftiopen(mapFile, wbcommand);
            maps.cdata = maps.cdata ./ VAgray;
            ciftisave(maps, mapFile, wbcommand);
        end
        
        % Copy PFM maps from PFM folder to subject's AtlasSpaceFolder/fsaverage_LR<LowResMesh> space directory
        copyfile([PFMFolder '/Results.ppp/Maps/sub-' Subjlist{s} '.dscalar.nii'], [StudyFolder '/' Subjlist{s} '/' AtlasSpaceFolder '/fsaverage_LR' LowResMesh 'k/' Subjlist{s} '.' OutputSTRING RegString '_origmaps.' LowResMesh 'k_fs_LR.dscalar.nii']);

        % clean up temporary files
        if VAweightBool
          delete(tmp_VAgray_file);
          delete(tmp_roi_file);
          delete(tmp_jnk_file);
        end
    end  % if numel(subfMRINames) ~= 0
end  % for s = 1:numel(Subjlist)
end
