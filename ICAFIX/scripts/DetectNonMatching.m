function [ output_args ] = DetectNonMatching(NoiseICAs,HandNoiseICAs,NonMatchingComponentsName,NumICAs,Subject,rfMRIName)
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here

NoiseICAs = load(NoiseICAs);
HandNoiseICAs = load(HandNoiseICAs);

NonMatchingComponents = [];

for i=1:NumICAs
    if (ismember(i,NoiseICAs) && ~ismember(i,HandNoiseICAs)) || (~ismember(i,NoiseICAs) && ismember(i,HandNoiseICAs))
        NonMatchingComponents = [NonMatchingComponents i];
        disp([Subject ' ' rfMRIName ' ICA Component ' num2str(i) ' NonMatching']);
    end
end

dlmwrite(NonMatchingComponentsName,NonMatchingComponents, 'delimiter', ' '); 
    

end

