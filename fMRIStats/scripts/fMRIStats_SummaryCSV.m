function fMRIStats_SummaryCSV(citiFile, varargin)
% fMRIStats_SummaryCSV(citiFile, varargin)
%
% Loads fMRIStats output from a single CIFTI dscalar file and writes 
% summary CSV with cortex/subcortex regional averages.
%
% Arguments:
%   citiFile - Path to CIFTI dscalar file
%
% Optional name-value arguments:
%   'Caret7_Command' - Path to wb_command for CIFTI I/O (default: 'wb_command')

%% Parse optional arguments using inputParser
p = inputParser;
p.FunctionName = 'fMRIStats_SummaryCSV';
addParameter(p, 'Caret7_Command', 'wb_command', @ischar);
parse(p, varargin{:});
Caret7_Command = p.Results.Caret7_Command;

%% Validate inputs
if nargin < 1
  error('fMRIStats_SummaryCSV:InsufficientArguments', ...
    'fMRIStats_SummaryCSV requires at least 1 argument: citiFile');
end

%% Generate output CSV name from input file
[filepath, basename, ~] = fileparts(citiFile);
summaryCSVName = fullfile(filepath, [basename '_Summary.csv']);

%% Load CIFTI file
CIFTI = ciftiopen(citiFile, Caret7_Command);
data = CIFTI.cdata;
metricNames = {CIFTI.diminfo{2}.maps(:).name};

[cortex_indices, subcortex_indices] = deal([]);
for iMod = 1:numel(CIFTI.diminfo{1}.models)
  model = CIFTI.diminfo{1}.models{iMod};
  if strcmp(model.type, 'surf')
    cortex_indices = [cortex_indices, model.start:model.start+model.count-1];
  else
    subcortex_indices = [subcortex_indices, model.start:model.start+model.count-1];
  end
end
regions = struct('name', {'Cortex', 'Subcortex'}, 'indices', {cortex_indices, subcortex_indices});

%% Compute regional averages
nMetrics = size(data, 2);
nRegions = numel(regions);
regionValues = zeros(nRegions, nMetrics);

for iReg = 1:nRegions
  reg_indices = regions(iReg).indices;
  if ~isempty(reg_indices)
    data_region = data(reg_indices, :);
    
    % For STD metrics, use RMS; for others use mean
    for iMet = 1:nMetrics
      if endsWith(metricNames{iMet}, 'STD')
        regionValues(iReg, iMet) = sqrt(mean(data_region(:, iMet).^2));
      else
        regionValues(iReg, iMet) = mean(data_region(:, iMet));
      end
    end
  else
    regionValues(iReg, :) = NaN(1, nMetrics);
  end
end

%% Write summary CSV
fid = fopen(summaryCSVName, 'w');
% Write header row: metric names
fprintf(fid, 'Region');
for iMet = 1:nMetrics
  fprintf(fid, ',%s', metricNames{iMet});
end
fprintf(fid, '\n');

% Write data rows
for iReg = 1:nRegions
  fprintf(fid, '%s', regions(iReg).name);
  for iMet = 1:nMetrics
    fprintf(fid, ',%g', regionValues(iReg, iMet));
  end
  fprintf(fid, '\n');
end
fprintf('Successfully wrote summary CSV to: %s\n', summaryCSVName);
fclose(fid);
