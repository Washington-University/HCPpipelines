function [ output_args ] = MergeEditClassifications(OriginalFixSignal,OriginalFixNoise,ReclassifyAsSignal,ReclassifyAsNoise,HandSignalName,HandNoiseName,TrainingLabelsName,NumICAs)
%UNTITLED2 Summary of this function goes here
%   Detailed explanation goes here

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


end

