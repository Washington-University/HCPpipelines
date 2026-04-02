function PostPROFUMO(StudyFolder, SubjListRaw, fMRIListRaw, ConcatName, fMRIProcSTRING, OutputfMRIName, OutputSTRING, RegString, LowResMesh, TR, PFMFolder)
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

%% Parse string inputs and initialize
Subjlist = strsplit(SubjListRaw, '@');
fMRINames = strsplit(fMRIListRaw, '@');
TR = str2double(TR);
wbcommand = 'wb_command';

%% Main loop: Process each subject
for s = 1:numel(Subjlist)
  fprintf('Processing subject %d/%d: %s\n', s, numel(Subjlist), Subjlist{s});
  
  %% Identify available fMRI runs for this subject
  % Determine which fMRI runs exist for this subject
  % If ConcatName is specified, use concatenated version; otherwise check individual runs
  subfMRINames = {};
  if ~strcmp(ConcatName, '')
    % Multi-run data: check if concatenated dataset exists
    if exist([StudyFolder '/' Subjlist{s} '/MNINonLinear/Results/' ConcatName '/' ConcatName fMRIProcSTRING '.dtseries.nii'],'file')
      c = 1;
      for r = 1:numel(fMRINames)
        if exist([StudyFolder '/' Subjlist{s} '/MNINonLinear/Results/' fMRINames{r} '/' fMRINames{r} fMRIProcSTRING '.dtseries.nii'],'file')
          subfMRINames{c} = fMRINames{r};
          c = c + 1;
        end
      end  % for r = 1:numel(fMRINames)            
    end
  else
    % Single-run data: check which runs exist
    c = 1;
    for r = 1:numel(fMRINames)
      if exist([StudyFolder '/' Subjlist{s} '/MNINonLinear/Results/' fMRINames{r} '/' fMRINames{r} fMRIProcSTRING '.dtseries.nii'],'file')
        subfMRINames{c} = fMRINames{r};
        c = c + 1;
      end
    end  % for r = 1:numel(fMRINames)
  end
  
  %% Process subject if valid runs found
  if numel(subfMRINames) ~= 0
    %% Load and concatenate PFM time courses and amplitudes
    % Load PROFUMO outputs and amplitude-modulate time courses
    origTCS = [];  % Original unmodulated time courses
    TCS = [];      % Amplitude-modulated time courses
    for r = 1:numel(subfMRINames)
      runTCS = load([PFMFolder '/Results.ppp/TimeCourses/sub-' Subjlist{s} '_run-' subfMRINames{r} '.csv']);
      runAmp = load([PFMFolder '/Results.ppp/Amplitudes/sub-' Subjlist{s} '_run-' subfMRINames{r} '.csv']);

      origTCS = [origTCS ; runTCS];
      TCS = [TCS ; runTCS .* repmat(runAmp', numel(runTCS), 1)];
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
    PFMTCS = cifti_struct_create_sdseries(TCS');
    
    % Store power spectra 
    ts.Nnodes = size(TCS, 2);
    ts.Nsubjects = 1;
    ts.ts = TCS;
    ts.NtimepointsPerSubject = size(TCS, 1);
    PFMSpectra = cifti_struct_create_sdseries(nets_spectra_sp(ts)','step',1/TR);

    %% Save individual-level results
    % Save original and amplitude-modulated time courses and spectra
    ciftisave(PFMTCSorig, [StudyFolder '/' Subjlist{s} '/MNINonLinear/fsaverage_LR' LowResMesh 'k/' Subjlist{s} '.' OutputSTRING RegString '_ts_orig.' LowResMesh 'k_fs_LR.sdseries.nii'], wbcommand);
    ciftisave(PFMSpectraorig, [StudyFolder '/' Subjlist{s} '/MNINonLinear/fsaverage_LR' LowResMesh 'k/' Subjlist{s} '.' OutputSTRING RegString '_spectra_orig.' LowResMesh 'k_fs_LR.sdseries.nii'], wbcommand);

    ciftisave(PFMTCS, [StudyFolder '/' Subjlist{s} '/MNINonLinear/fsaverage_LR' LowResMesh 'k/' Subjlist{s} '.' OutputSTRING RegString '_ts.' LowResMesh 'k_fs_LR.sdseries.nii'], wbcommand);
    ciftisave(PFMSpectra, [StudyFolder '/' Subjlist{s} '/MNINonLinear/fsaverage_LR' LowResMesh 'k/' Subjlist{s} '.' OutputSTRING RegString '_spectra.' LowResMesh 'k_fs_LR.sdseries.nii'], wbcommand);

    %% Copy individual PFM maps
    % Link PROFUMO spatial maps to subject's fsaverage space directory
    copyfile([PFMFolder '/Results.ppp/Maps/sub-' Subjlist{s} '.dscalar.nii'], [StudyFolder '/' Subjlist{s} '/MNINonLinear/fsaverage_LR' LowResMesh 'k/' Subjlist{s} '.' OutputSTRING RegString '_origmaps.' LowResMesh 'k_fs_LR.dscalar.nii']);
  end  % if numel(subfMRINames) ~= 0
end  % for s = 1:numel(Subjlist)
end