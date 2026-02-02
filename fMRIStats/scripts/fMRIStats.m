function fMRIStats(MeanCIFTI,MeanVolume,sICATCS,Signal,OrigCIFTITCS,OrigVolumeTCS,CleanedCIFTITCS,CleanedVolumeTCS,CIFTIOutputName,VolumeOutputName,CleanUpEffectsStr,ProcessVolumeStr,Caret7_Command)
% fMRIStats - Compute fMRI quality metrics from ICA-cleaned data
%
% This function computes several fMRI quality metrics including:
%   - Modified TSNR (mTSNR): Mean / UnstructuredNoiseSTD
%   - Functional CNR (fCNR): SignalSTD / UnstructuredNoiseSTD  
%   - Percent BOLD: SignalSTD / Mean * 100
%
% The signal is estimated by regressing the ICA signal component timecourses
% into the cleaned data. Unstructured noise is the residual after removing
% the reconstructed signal from the cleaned data.
%
% If CleanUpEffects is enabled, additional metrics comparing cleaned vs
% uncleaned data are computed to assess the effect of sICA or sICA+tICA cleanup.

%% Parse boolean strings
% Boolean arguments are passed as '0' or '1' strings from bash opts_StringToBool
CleanUpEffects = strcmp(CleanUpEffectsStr, '1');
ProcessVolume = strcmp(ProcessVolumeStr, '1');

%% Load CIFTI data
% Load mean image, ICA timecourses, signal component indices, and cleaned timeseries
MeanCIFTI = ciftiopen(MeanCIFTI,Caret7_Command);
sICATCS = ciftiopen(sICATCS,Caret7_Command);
Signal = load(Signal);  % indices of signal (non-noise) ICA components
CleanedCIFTITCS = ciftiopen(CleanedCIFTITCS,Caret7_Command);

% Extract only the signal component timecourses (transpose: timepoints x components)
sICATCSSignal = sICATCS.cdata(Signal,:)';
tICAmode = false;  % ToDo
if tICAmode
  % ToDo: load tICA timecourse sdseries, and single component text, 
  % regress out noise and set that as the sICATCSSignal
end


%% Load original CIFTI data for cleanup effects comparison
if CleanUpEffects
  OrigCIFTITCS = ciftiopen(OrigCIFTITCS,Caret7_Command);
  OrigCIFTITCS.cdata = demean(OrigCIFTITCS.cdata,2);  % demean across time
end  % if CleanUpEffects (load original CIFTI)

%% Load and prepare volume data (if requested)
if ProcessVolume
  VolumeGeometryName = MeanVolume;  % save filename for later geometry copy
  MeanVolume = read_avw(MeanVolume);
  CleanedVolumeTCS = read_avw(CleanedVolumeTCS);
  
  % Reshape 4D volumes to 2D (voxels x time) for easier processing
  nVoxels = size(MeanVolume,1) * size(MeanVolume,2) * size(MeanVolume,3);
  MeanVolume2D = reshape(MeanVolume, nVoxels, 1);
  CleanedVolumeTCS2D = reshape(CleanedVolumeTCS, nVoxels, size(CleanedVolumeTCS,4));
  
  % Create brain mask and apply to reduce memory/computation
  MASK = MeanVolume2D ~= 0;
  MeanVolume2DMasked = MeanVolume2D(MASK);
  CleanedVolumeTCS2DMasked = CleanedVolumeTCS2D(MASK,:);
  clear CleanedVolumeTCS CleanedVolumeTCS2D
  
  % Load original volume data for cleanup effects comparison
  if CleanUpEffects
    OrigVolumeTCS = read_avw(OrigVolumeTCS);
    OrigVolumeTCS2D = reshape(OrigVolumeTCS, nVoxels, size(OrigVolumeTCS,4));
    OrigVolumeTCS2DMasked = OrigVolumeTCS2D(MASK,:);
    OrigVolumeTCS2DMasked = demean(OrigVolumeTCS2DMasked,2);
    clear OrigVolumeTCS OrigVolumeTCS2D        
  end  % if CleanUpEffects (load original volume)
end  % if ProcessVolume (load volume data)

%% Compute CIFTI signal reconstruction and quality metrics
% Initialize output structure from mean CIFTI
CIFTIOutput = MeanCIFTI;

% Regress signal ICA timecourses into cleaned data to get spatial betas
% Beta = (X'X)^-1 * X' * Y, where X = ICA timecourses, Y = cleaned data
CIFTIBetas = MeanCIFTI;
CIFTIBetas.cdata = (pinv(sICATCSSignal) * CleanedCIFTITCS.cdata')';

% Reconstruct signal timeseries from betas and ICA timecourses
CIFTIRecon = CleanedCIFTITCS;
CIFTIRecon.cdata = CIFTIBetas.cdata * sICATCSSignal';
ReconSTD = std(CIFTIRecon.cdata,[],2);  % signal amplitude (std across time)

% Compute unstructured noise as residual after removing reconstructed signal
CIFTIUnstruct = CleanedCIFTITCS;
CIFTIUnstruct.cdata = CleanedCIFTITCS.cdata - CIFTIRecon.cdata;
UnstructSTD = std(CIFTIUnstruct.cdata,[],2);  % unstructured noise amplitude

%% Compute CIFTI quality metrics
% mTSNR: ratio of mean signal to unstructured noise
mTSNR = MeanCIFTI.cdata ./ UnstructSTD;

% fCNR: ratio of structured signal to unstructured noise
fCNR = ReconSTD ./ UnstructSTD;

% Percent BOLD: signal amplitude as percentage of mean
PercBOLD = ReconSTD ./ MeanCIFTI.cdata * 100;

%% Compute CIFTI cleanup effects metrics (comparing cleaned vs uncleaned)
if CleanUpEffects
  % Structured artifact = what was removed by cleaning
  CIFTIStruct = CleanedCIFTITCS;
  CIFTIStruct.cdata = OrigCIFTITCS.cdata - CleanedCIFTITCS.cdata;
  StructSTD = std(CIFTIStruct.cdata,[],2);
  
  % Combined structured + unstructured noise (original - signal)
  CIFTIStructUnstruct = CleanedCIFTITCS;
  CIFTIStructUnstruct.cdata = OrigCIFTITCS.cdata - CIFTIRecon.cdata;
  StructUnstructSTD = std(CIFTIStructUnstruct.cdata,[],2);
  
  % Metrics computed on uncleaned data for comparison
  mTSNROrig = MeanCIFTI.cdata ./ StructUnstructSTD;
  fCNROrig = ReconSTD ./ StructUnstructSTD;
  
  % Cleanup ratio: how much noise was reduced by cleaning
  Ratio = StructUnstructSTD ./ UnstructSTD;
  
  % Assemble output with all metrics
  CIFTIOutput.cdata = [MeanCIFTI.cdata UnstructSTD ReconSTD mTSNR fCNR PercBOLD ...
                       StructSTD StructUnstructSTD mTSNROrig fCNROrig Ratio];
  CIFTIOutput.diminfo{1,2} = cifti_diminfo_make_scalars(size(CIFTIOutput.cdata,2),...
    {'Mean','UnstructuredNoiseSTD','SignalSTD','ModifiedTSNR','FunctionalCNR','PercentBOLD',...
     'StructuredArtifactSTD','StructuredAndUnstructuredSTD','UncleanedTSNR','UncleanedFunctionalCNR','CleanUpRatio'});
else
  % Assemble output with basic metrics only
  CIFTIOutput.cdata = [MeanCIFTI.cdata UnstructSTD ReconSTD mTSNR fCNR PercBOLD];
  CIFTIOutput.diminfo{1,2} = cifti_diminfo_make_scalars(size(CIFTIOutput.cdata,2),...
    {'Mean','UnstructuredNoiseSTD','SignalSTD','ModifiedTSNR','FunctionalCNR','PercentBOLD'});
end  % if CleanUpEffects (CIFTI cleanup metrics)

%% Save CIFTI output
ciftisave(CIFTIOutput,CIFTIOutputName,Caret7_Command);

%% Compute volume quality metrics (if requested)
if ProcessVolume
  %% Compute volume signal reconstruction
  % Same approach as CIFTI: regress ICA timecourses, reconstruct signal
  VolumeBetas2DMasked = (pinv(sICATCSSignal) * CleanedVolumeTCS2DMasked')';
  VolumeRecon2DMasked = VolumeBetas2DMasked * sICATCSSignal';
  ReconSTD = std(VolumeRecon2DMasked,[],2);
  
  % Unstructured noise residual
  VolumeUnstruct2DMasked = CleanedVolumeTCS2DMasked - VolumeRecon2DMasked;
  UnstructSTD = std(VolumeUnstruct2DMasked,[],2);

  %% Compute volume quality metrics
  mTSNR = MeanVolume2DMasked ./ UnstructSTD;
  fCNR = ReconSTD ./ UnstructSTD;
  PercBOLD = ReconSTD ./ MeanVolume2DMasked * 100;

  %% Compute volume cleanup effects metrics
  if CleanUpEffects
    VolumeStruct2DMasked = OrigVolumeTCS2DMasked - CleanedVolumeTCS2DMasked;
    StructSTD = std(VolumeStruct2DMasked,[],2);
    
    VolumeStructUnstruct2DMasked = OrigVolumeTCS2DMasked - VolumeRecon2DMasked;
    StructUnstructSTD = std(VolumeStructUnstruct2DMasked,[],2);
    
    mTSNROrig = MeanVolume2DMasked ./ StructUnstructSTD;
    fCNROrig = ReconSTD ./ StructUnstructSTD;
    Ratio = StructUnstructSTD ./ UnstructSTD;
      
    VolumeOutput2DMasked = [MeanVolume2DMasked UnstructSTD ReconSTD mTSNR fCNR PercBOLD ...
                           StructSTD StructUnstructSTD mTSNROrig fCNROrig Ratio];
  else
    VolumeOutput2DMasked = [MeanVolume2DMasked UnstructSTD ReconSTD mTSNR fCNR PercBOLD];
  end  % if CleanUpEffects (volume cleanup metrics)
  
  %% Save volume output
  % Unmask and reshape back to 4D
  VolumeOutput2D = zeros(numel(MeanVolume2D), size(VolumeOutput2DMasked,2),'single');
  VolumeOutput2D(MASK,:) = VolumeOutput2DMasked;
  VolumeOutput = reshape(VolumeOutput2D, size(MeanVolume,1), size(MeanVolume,2), ...
                         size(MeanVolume,3), size(VolumeOutput2DMasked,2));
  
  % Save and copy geometry from original
  save_avw(VolumeOutput,VolumeOutputName,'f',[1 1 1 1]);
  unix(['fslcpgeom ' VolumeGeometryName ' ' VolumeOutputName ' -d']);
end  % if ProcessVolume

end  % function fMRIStats
