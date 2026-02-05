function GroupPFMs(StudyFolder, SubjlistRaw, PFMdim, OutputPrefix, RegName, LowResMesh, RunsXNumTimePoints, PFMFolder)

  %% example parameters for 1071 3T MSMAll Rest
  % StudyFolder = '/media/myelin/brainmappers/Connectome_Project/YA_HCP_Final';
  % SubjlistRaw = "100206@100307";
  % PFMdim = 92;
  % OutputPrefix = ['rfMRI_REST_d92_WF5_S1200_MSMAll3T1071_PFMs_tclean'];
  % RegName = '_MSMAll'; %e.g. _MSMAll
  % LowResMesh = '32';
  % RunsXNumTimePoints = 4800;
  % PFMFolder = '/media/myelin/brainmappers/Connectome_Project/YA_HCP_Final/S1200_MSMAll3T1071/MNINonLinear/Results/rfMRI_REST/PFMs_chpc';

  wbcommand = 'wb_command';

  %% parse arguments
  subjList = regexp(SubjlistRaw,'@','split');
  nS = numel(subjList);
  RunsXNumTimePoints = str2double(RunsXNumTimePoints);
  PFMdim = str2double(PFMdim);
  if nargin < 8;error('All arguments are required.');end % failsafe

  %% preallocate
  [TCSMask, TCSAll] = deal(zeros(PFMdim,RunsXNumTimePoints, nS,'single'));
  [spectra,PFMmaps, PFMvolMaps] = deal([]);
  %PFMMapsAll = zeros(CIFTIVertices,PFMdim, nS,'single');
  %PFMVolMapsAll = zeros(CIFTIVol,PFMdim, nS,'single');

  %% loop over subjects
  for iS = 1:nS
    subj = subjList{iS};
    subjDir = [StudyFolder '/' subj '/MNINonLinear/fsaverage_LR' LowResMesh 'k'];
    fprintf('processing %s ... \n', subj);
    
    % load subject data
    PFMMapsSub = ciftiopen([subjDir '/' subj '.' OutputPrefix '_DR' RegName '.' LowResMesh 'k_fs_LR.dscalar.nii'],wbcommand);
    PFMVolMapsSub = ciftiopen([subjDir '/' subj '.' OutputPrefix '_DR' RegName '_vol.' LowResMesh 'k_fs_LR.dscalar.nii'],wbcommand);
    TCSSub = ciftiopen([subjDir '/' subj '.' OutputPrefix '_DR' RegName '_ts.' LowResMesh 'k_fs_LR.sdseries.nii'],wbcommand);
    SpectraSub = ciftiopen([subjDir '/' subj '.' OutputPrefix '_DR' RegName '_spectra.' LowResMesh 'k_fs_LR.sdseries.nii'],wbcommand);
  

    % clean up NaNs and Infs in PFM VolMaps
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

    % store subject TCS in TCSALL array
    TCSAll(1:size(TCSSub.cdata,1),1:size(TCSSub.cdata,2),iS) = TCSSub.cdata;

    % Perform running sum of spectra and PFM maps
    if size(TCSSub.cdata,2)  ==  RunsXNumTimePoints
      TCSMask(:,:,iS) = repmat(1,PFMdim,RunsXNumTimePoints,1);
      if isempty(spectra)
        spectra = SpectraSub;
        spectra.cdata = SpectraSub.cdata*0;
      end
      spectra.cdata = spectra.cdata + SpectraSub.cdata;
    end
    if isempty(PFMmaps)
      PFMmaps = PFMMapsSub;
      PFMmaps.cdata = PFMMapsSub.cdata*0;
      PFMvolMaps = PFMVolMapsSub;
      PFMvolMaps.cdata = PFMVolMapsSub.cdata*0;
    end
    PFMmaps.cdata = PFMmaps.cdata + PFMMapsSub.cdata;
    PFMvolMaps.cdata = PFMvolMaps.cdata + PFMVolMapsSub.cdata;
  end % for iS = 1:nS

  %% package and save outputs
  if ~exist(PFMFolder,'dir');mkdir(PFMFolder);end
  dimStr = num2str(PFMdim);
  % timeseries
  TCSMaskConcat = TCSSub;
  TCSMaskConcat.cdata = squeeze(reshape(TCSMask,PFMdim,RunsXNumTimePoints* nS));
  TCSFullConcat = TCSSub;
  TCSFullConcat.cdata = squeeze(reshape(TCSAll,PFMdim,RunsXNumTimePoints* nS));
  ciftisavereset(TCSMaskConcat,[PFMFolder '/PFM_TCSMASK_' dimStr '.sdseries.nii'],wbcommand);
  ciftisavereset(TCSFullConcat,[PFMFolder '/PFM_TCS_' dimStr '.sdseries.nii'],wbcommand);

  TCSAVG = TCSSub;
  TCSAVG.cdata = sum(TCSAll.*TCSMask,3)/nS;
  TCSABSAVG = TCSSub;
  TCSABSAVG.cdata = sum(abs(TCSAll.*TCSMask),3)/nS;
  ciftisavereset(TCSAVG,[PFMFolder '/PFM_AVGTCS_' dimStr '.sdseries.nii'],wbcommand);
  ciftisavereset(TCSABSAVG,[PFMFolder '/PFM_ABSAVGTCS_' dimStr '.sdseries.nii'],wbcommand);


  % PFM stats
  PFMTSTDs = std(TCSFullConcat.cdata,[],2);
  PFMPercentVariances = (((PFMTSTDs.^2)/sum(PFMTSTDs.^2))*100);
  dlmwrite([PFMFolder '/PFM_stats_' dimStr '.wb_annsub.csv'],[(1:PFMdim)' round(PFMPercentVariances,2)],',');

  % spectra
  spectra.cdata = spectra.cdata/nS;
  ciftisavereset(spectra,[PFMFolder '/PFM_Spectra_' dimStr '.sdseries.nii'],wbcommand);
  
  
  % PFM maps
  PFMmaps.cdata = PFMmaps.cdata/nS;
  PFMvolMaps.cdata = PFMvolMaps.cdata/nS;

  %TRIM = repmat(squeeze(trimmean(PFMMapsAll,10,3)),1,1, nS);
  %MAD = repmat(squeeze(mad(PFMMapsAll,1,3)*1.4826),1,1, nS);
  %MASK = (PFMMapsAll>TRIM-MAD*2).*(PFMMapsAll<TRIM + MAD*2); clear TRIM MAD;
  %PFMMaps = squeeze(sum(PFMMapsAll.*MASK,3)./sum(MASK,3));
  %clear MASK;

  %TRIM = repmat(squeeze(trimmean(PFMVolMapsAll,10,3)),1,1, nS);
  %MAD = repmat(squeeze(mad(PFMVolMapsAll,1,3)*1.4826),1,1, nS);
  %MASK = (PFMVolMapsAll>TRIM-MAD*2).*(PFMVolMapsAll<TRIM + MAD*2); clear TRIM MAD;
  %PFMVolMaps = squeeze(sum(PFMVolMapsAll.*MASK,3)./sum(MASK,3));
  %clear MASK;

  ciftisavereset(PFMmaps,[PFMFolder '/PFM_Maps_' num2str(PFMdim) '.dscalar.nii'],wbcommand);
  ciftisavereset(PFMvolMaps,[PFMFolder '/PFM_VolMaps_' num2str(PFMdim) '.dscalar.nii'],wbcommand);
end