function GroupPFMs(StudyFolder, SubjlistRaw, PFMdim, OutputPrefix, RegName, LowResMesh, RunsXNumTimePoints, PFMFolder)
% GroupPFMs(StudyFolder, SubjlistRaw, PFMdim, OutputPrefix, RegName, LowResMesh, RunsXNumTimePoints, PFMFolder)
% This function aggregates individual subject PFM results and computes
% group-level time course masks, spectra, maps, and statistics.
%
% Inputs:
%   StudyFolder - Path to the study directory
%   SubjlistRaw - Subject list as @ separated string
%   PFMdim - PFM dimensionality
%   OutputPrefix - Prefix for output files
%   RegName - Registration string (e.g., '_MSMAll')
%   LowResMesh - Mesh resolution (e.g., '32' for 32k_fs_LR)
%   RunsXNumTimePoints - Total expected timepoints across runs
%   PFMFolder - Output folder for group-level results

%% Initialize parameters
wbcommand = 'wb_command';

%% Parse input arguments
subjList = regexp(SubjlistRaw,'@','split');
nS = numel(subjList);
RunsXNumTimePoints = str2double(RunsXNumTimePoints);
PFMdim = str2double(PFMdim);
if nargin < 8; error('All arguments are required.'); end % Validate all inputs

%% Preallocate arrays for group concatenation
% TCSMask: binary mask indicating valid timepoints per subject
% TCSAll: concatenated time courses across subjects
% spectra, PFMmaps, PFMvolMaps: accumulators for group averages
[TCSMask, TCSAll] = deal(zeros(PFMdim, RunsXNumTimePoints, nS, 'single'));
[spectra, PFMmaps, PFMvolMaps] = deal([]);

%% Load and accumulate individual subject results
for iS = 1:nS
  subj = subjList{iS};
  subjDir = [StudyFolder '/' subj '/MNINonLinear/fsaverage_LR' LowResMesh 'k'];
  fprintf('Processing %s ... \n', subj);
  
  %% Load individual PFM results from standard subject locations
  % Load spatial maps, volume maps, time courses, and power spectra
  PFMMapsSub = ciftiopen([subjDir '/' subj '.' OutputPrefix '_DR' RegName '.' LowResMesh 'k_fs_LR.dscalar.nii'], wbcommand);
  PFMVolMapsSub = ciftiopen([subjDir '/' subj '.' OutputPrefix '_DR' RegName '_vol.' LowResMesh 'k_fs_LR.dscalar.nii'], wbcommand);
  TCSSub = ciftiopen([subjDir '/' subj '.' OutputPrefix '_DR' RegName '_ts.' LowResMesh 'k_fs_LR.sdseries.nii'], wbcommand);
  SpectraSub = ciftiopen([subjDir '/' subj '.' OutputPrefix '_DR' RegName '_spectra.' LowResMesh 'k_fs_LR.sdseries.nii'], wbcommand);

  %% Clean up NaNs and Infs in volume maps
  % Replace invalid values with zeros to prevent propagation to group statistics
  infMask = isinf(PFMVolMapsSub.cdata);
  nanMask = isnan(PFMVolMapsSub.cdata);
  if any(infMask, 'all')
    warning('Found Infs in PFM VolMaps for subject %s. Replacing with zeros.\n', subj);
    PFMVolMapsSub.cdata(isinf(PFMVolMapsSub.cdata)) = 0;
  end
  if any(nanMask, 'all')
    warning('Found NaNs in PFM VolMaps for subject %s. Replacing with zeros.\n', subj);
    PFMVolMapsSub.cdata(isnan(PFMVolMapsSub.cdata)) = 0;
  end

  %% Store subject time course in concatenated array
  TCSAll(1:size(TCSSub.cdata, 1), 1:size(TCSSub.cdata, 2), iS) = TCSSub.cdata;

  %% Accumulate spectra and maps for group averaging
  % Only accumulate if subject has expected number of timepoints
  if size(TCSSub.cdata, 2) == RunsXNumTimePoints
    TCSMask(:, :, iS) = repmat(1, PFMdim, RunsXNumTimePoints, 1);
    if isempty(spectra)
      spectra = SpectraSub;
      spectra.cdata = SpectraSub.cdata * 0;
    end
    spectra.cdata = spectra.cdata + SpectraSub.cdata;
  end
  
  % Accumulate spatial maps from all subjects with valid data
  if isempty(PFMmaps)
    PFMmaps = PFMMapsSub;
    PFMmaps.cdata = PFMMapsSub.cdata * 0;
    PFMvolMaps = PFMVolMapsSub;
    PFMvolMaps.cdata = PFMVolMapsSub.cdata * 0;
  end
  PFMmaps.cdata = PFMmaps.cdata + PFMMapsSub.cdata;
  PFMvolMaps.cdata = PFMvolMaps.cdata + PFMVolMapsSub.cdata;
end  % for iS = 1:nS

%% Create output directory if needed
if ~exist(PFMFolder, 'dir'); mkdir(PFMFolder); end
dimStr = num2str(PFMdim);

%% Concatenate and reshape group time courses
% Create single concatenated time series from all subjects
TCSMaskConcat = TCSSub;
TCSMaskConcat.cdata = squeeze(reshape(TCSMask, PFMdim, RunsXNumTimePoints * nS));
TCSFullConcat = TCSSub;
TCSFullConcat.cdata = squeeze(reshape(TCSAll, PFMdim, RunsXNumTimePoints * nS));
ciftisavereset(TCSMaskConcat, [PFMFolder '/PFM_TCSMASK_' dimStr '.sdseries.nii'], wbcommand);
ciftisavereset(TCSFullConcat, [PFMFolder '/PFM_TCS_' dimStr '.sdseries.nii'], wbcommand);

%% Compute group average time courses
% Calculate mean time course and mean absolute value time course
TCSAVG = TCSSub;
TCSAVG.cdata = sum(TCSAll .* TCSMask, 3) / nS;
TCSABSAVG = TCSSub;
TCSABSAVG.cdata = sum(abs(TCSAll .* TCSMask), 3) / nS;
ciftisavereset(TCSAVG, [PFMFolder '/PFM_AVGTCS_' dimStr '.sdseries.nii'], wbcommand);
ciftisavereset(TCSABSAVG, [PFMFolder '/PFM_ABSAVGTCS_' dimStr '.sdseries.nii'], wbcommand);

%% Compute group-level statistics
% Calculate variance explained by each PFM component
PFMTSTDs = std(TCSFullConcat.cdata, [], 2);
PFMPercentVariances = (((PFMTSTDs .^ 2) / sum(PFMTSTDs .^ 2)) * 100);
dlmwrite([PFMFolder '/PFM_stats_' dimStr '.wb_annsub.csv'], [(1:PFMdim)' round(PFMPercentVariances, 2)], ',');

%% Average group spectra
% Normalize by number of subjects with valid data
spectra.cdata = spectra.cdata / nS;
ciftisavereset(spectra, [PFMFolder '/PFM_Spectra_' dimStr '.sdseries.nii'], wbcommand);

%% Average group spatial maps
% Compute mean PFM maps across all subjects
PFMmaps.cdata = PFMmaps.cdata / nS;
PFMvolMaps.cdata = PFMvolMaps.cdata / nS;

%% Save group-level spatial maps
% Output group-averaged surface and volume PFM maps
ciftisavereset(PFMmaps, [PFMFolder '/PFM_Maps_' num2str(PFMdim) '.dscalar.nii'], wbcommand);
ciftisavereset(PFMvolMaps, [PFMFolder '/PFM_VolMaps_' num2str(PFMdim) '.dscalar.nii'], wbcommand);
end