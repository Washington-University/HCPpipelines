function fMRIStats(MeanCIFTI, sICATCS, Signal, CleanedCIFTITCS, CIFTIOutputName, varargin)
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
%
% Usage:
%   fMRIStats(MeanCIFTI, sICATCS, Signal, CleanedCIFTITCS, CIFTIOutputName, ...)
%
% Required arguments:
%   MeanCIFTI        - Path to mean CIFTI file
%   sICATCS          - Path to sICA timecourse CIFTI
%   Signal           - Path to signal component indices text file
%   CleanedCIFTITCS  - Path to cleaned CIFTI timeseries
%   CIFTIOutputName  - Output path for CIFTI results
%
% Optional name-value arguments (with defaults):
%   'ProcessVolume'    - '0' or '1' to process volume data (default: '0')
%   'CleanUpEffects'   - '0' or '1' to compute cleanup comparison metrics (default: '0')
%   'ICAmode'         - 'sICA' or 'sICA+tICA' mode (default: 'sICA')
%   'Caret7_Command'   - Path to wb_command (default: 'wb_command')
%
% Conditionally required (based on flags above):
%   'OrigCIFTITCS'     - Path to original CIFTI timeseries (required if CleanUpEffects='1')
%   'MeanVolume'       - Path to mean volume file (required if ProcessVolume='1')
%   'CleanedVolumeTCS' - Path to cleaned volume timeseries (required if ProcessVolume='1')
%   'VolumeOutputName' - Output path for volume results (required if ProcessVolume='1')
%   'OrigVolumeTCS'    - Path to original volume timeseries (required if CleanUpEffects='1' AND ProcessVolume='1')
%   'tICAcomponentTCS' - Path to tICA timecourse CIFTI (required if ICAmode='sICA+tICA')
%   'tICAcomponentText'- Path to tICA component indices text file (required if ICAmode='sICA+tICA')
%
% Examples:
%   % Basic CIFTI-only processing:
%   fMRIStats(meanFile, icaTCS, signalFile, cleanedFile, outputFile)
%
%   % With cleanup effects comparison:
%   fMRIStats(meanFile, icaTCS, signalFile, cleanedFile, outputFile, ...
%             'CleanUpEffects', '1', 'OrigCIFTITCS', origFile)
%
%   % With volume processing:
%   fMRIStats(meanFile, icaTCS, signalFile, cleanedFile, outputFile, ...
%             'ProcessVolume', '1', 'MeanVolume', meanVol, ...
%             'CleanedVolumeTCS', cleanedVol, 'VolumeOutputName', volOutput)

%% Parse optional arguments using inputParser
p = inputParser;
p.FunctionName = 'fMRIStats';

% Control flags (with defaults)
addParameter(p, 'ProcessVolume', '0', @ischar);
addParameter(p, 'CleanUpEffects', '0', @ischar);
addParameter(p, 'ICAmode', 'sICA', @ischar);
addParameter(p, 'Caret7_Command', 'wb_command', @ischar);

% Conditionally required arguments (default to empty)
addParameter(p, 'OrigCIFTITCS', '', @ischar);
addParameter(p, 'MeanVolume', '', @ischar);
addParameter(p, 'CleanedVolumeTCS', '', @ischar);
addParameter(p, 'VolumeOutputName', '', @ischar);
addParameter(p, 'OrigVolumeTCS', '', @ischar);
addParameter(p, 'tICAcomponentTCS', '', @ischar);
addParameter(p, 'tICAcomponentText', '', @ischar);

parse(p, varargin{:});
opts = p.Results;

%% Parse boolean strings and assign to local variables
% Boolean arguments are passed as '0' or '1' strings from bash opts_StringToBool
CleanUpEffects = strcmp(opts.CleanUpEffects, '1');
ProcessVolume = strcmp(opts.ProcessVolume, '1');
Caret7_Command = opts.Caret7_Command;

%% Validate conditionally required arguments
if CleanUpEffects && isempty(opts.OrigCIFTITCS)
    error('fMRIStats:MissingArgument', ...
          'OrigCIFTITCS is required when CleanUpEffects=''1''');
end

if ProcessVolume
    if isempty(opts.MeanVolume)
        error('fMRIStats:MissingArgument', ...
              'MeanVolume is required when ProcessVolume=''1''');
    end
    if isempty(opts.CleanedVolumeTCS)
        error('fMRIStats:MissingArgument', ...
              'CleanedVolumeTCS is required when ProcessVolume=''1''');
    end
    if isempty(opts.VolumeOutputName)
        error('fMRIStats:MissingArgument', ...
              'VolumeOutputName is required when ProcessVolume=''1''');
    end
    if CleanUpEffects && isempty(opts.OrigVolumeTCS)
        error('fMRIStats:MissingArgument', ...
              'OrigVolumeTCS is required when both ProcessVolume=''1'' and CleanUpEffects=''1''');
    end
end

if strcmp(opts.ICAmode, 'sICA+tICA')
    if isempty(opts.tICAcomponentTCS)
        error('fMRIStats:MissingArgument', ...
              'tICAcomponentTCS is required when ICAmode=''sICA+tICA''');
    end
    if isempty(opts.tICAcomponentText)
        error('fMRIStats:MissingArgument', ...
              'tICAcomponentText is required when ICAmode=''sICA+tICA''');
    end
end

%% Load CIFTI data
% Load mean image, ICA timecourses, signal component indices, and cleaned timeseries
MeanCIFTI = ciftiopen(MeanCIFTI,Caret7_Command);
sICATCS = ciftiopen(sICATCS,Caret7_Command);
Signal = load(Signal);  % indices of signal (non-noise) ICA components
CleanedCIFTITCS = ciftiopen(CleanedCIFTITCS,Caret7_Command);

% Extract only the signal component timecourses (transpose: timepoints x components)
sICATCSSignal = sICATCS.cdata(Signal,:)';
if strcmp(opts.ICAmode,'sICA+tICA')
  % ToDo: load tICA component timecourse sdseries, and signal component text, 
  % regress out noise and set that as the sICATCSSignal
end


%% Load original CIFTI data for cleanup effects comparison
if CleanUpEffects
  OrigCIFTITCS = ciftiopen(opts.OrigCIFTITCS,Caret7_Command);
  OrigCIFTITCS.cdata = demean(OrigCIFTITCS.cdata,2);  % demean across time
end  % if CleanUpEffects (load original CIFTI)

%% Load and prepare volume data (if requested)
if ProcessVolume
  VolumeGeometryName = opts.MeanVolume;  % save filename for later geometry copy
  MeanVolume = read_avw(opts.MeanVolume);
  CleanedVolumeTCS = read_avw(opts.CleanedVolumeTCS);
  
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
    OrigVolumeTCS = read_avw(opts.OrigVolumeTCS);
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
  save_avw(VolumeOutput,opts.VolumeOutputName,'f',[1 1 1 1]);
  unix(['fslcpgeom ' VolumeGeometryName ' ' opts.VolumeOutputName ' -d']);
end  % if ProcessVolume

end  % function fMRIStats
