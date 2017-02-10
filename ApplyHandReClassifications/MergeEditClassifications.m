function MergeEditClassifications(OriginalFixSignal,OriginalFixNoise,ReclassifyAsSignal,ReclassifyAsNoise,HandSignalName,HandNoiseName,TrainingLabelsName,NumICAs)
%function [ output_args ] = MergeEditClassifications(OriginalFixSignal,OriginalFixNoise,ReclassifyAsSignal,ReclassifyAsNoise,HandSignalName,HandNoiseName,TrainingLabelsName,NumICAs)
%UNTITLED2 Summary of this function goes here
%   Detailed explanation goes here
%
% Author(s): M. Glasser
%
% Minor edits by T.B. Brown to show values of input parameters for debugging purposes
% Minor edits by T.B. Brown to convert string parameters to numeric values as necessary.
%                           When used with compiled MATLAB, all parameters are passed 
%                           in as strings               

func_name='MergeEditClassifications'
fprintf('%s - start\n', func_name)
fprintf('%s - OriginalFixSignal: %s\n',  func_name, OriginalFixSignal)
fprintf('%s - OriginalFixNoise: %s\n',   func_name, OriginalFixNoise)
fprintf('%s - ReclassifyAsSignal: %s\n', func_name, ReclassifyAsSignal)
fprintf('%s - ReclassifyAsNoise: %s\n',  func_name, ReclassifyAsNoise)
fprintf('%s - HandSignalName: %s\n',     func_name, HandSignalName)
fprintf('%s - HandNoiseName: %s\n',      func_name, HandNoiseName)
fprintf('%s - TrainingLabelsName: %s\n', func_name, TrainingLabelsName)
if isdeployed
  fprintf('%s - NumICAs (as string): "%s"\n', func_name, NumICAs)
  NumICAs=str2double(NumICAs)
end
fprintf('%s - NumICAs: %d\n', func_name, NumICAs)  

OriginalFixSignal = load(OriginalFixSignal);
OriginalFixNoise = load(OriginalFixNoise);
ReclassifyAsSignal = load(ReclassifyAsSignal);
ReclassifyAsNoise = load(ReclassifyAsNoise);

HandSignal = [];
HandNoise = [];
TrainingLabels = ['['];

for i=1:NumICAs
    %Signal
    if (ismember(i,OriginalFixSignal) && ~ismember(i,ReclassifyAsNoise)) || ismember(i,ReclassifyAsSignal)
        HandSignal = [HandSignal i];
    end
    %Noise
    if ismember(i,OriginalFixNoise) && ~ismember(i,ReclassifyAsSignal) || ismember(i,ReclassifyAsNoise)
        HandNoise = [HandNoise i];
        if strcmp(TrainingLabels,'[')
            TrainingLabels = [TrainingLabels num2str(i)];
        else
            TrainingLabels = [TrainingLabels ', ' num2str(i)];

        end
    end
    if ismember(i,ReclassifyAsNoise) && ismember(i,ReclassifyAsSignal)
        disp(['Duplicate Component Error with Manual Classification on ICA: ' num2str(i)]);
    end
    if ~ismember(i,OriginalFixSignal) && ~ismember(i,OriginalFixNoise)
        disp(['Missing Component Error with Automatic Classification on ICA: ' num2str(i)]);
    end
    if ismember(i,OriginalFixSignal) && ismember(i,OriginalFixNoise)
        disp(['Duplicate Component Error with Automatic Classification on ICA: ' num2str(i)]);
    end
    if ~ismember(i,HandSignal) && ~ismember(i,HandNoise)
        disp(['Missing Component Error with Manual Classification on ICA: ' num2str(i)]);
    end
end

TrainingLabels = [TrainingLabels ']'];

dlmwrite(HandNoiseName,HandNoise, 'delimiter', ' '); 
dlmwrite(HandSignalName,HandSignal, 'delimiter', ' '); 

unix(['echo "' TrainingLabels '" > ' TrainingLabelsName]);

fprintf('%s - Complete\n', func_name)

end

