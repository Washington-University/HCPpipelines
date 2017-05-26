%function [ output_args ] = ComputeVN(cleandtseries,bias,ICAtcs,ICANoise,OutputVN,wbcommand)
function ComputeVN(cleandtseries,bias,ICAtcs,ICANoise,OutputVN,wbcommand)
%Compute CIFTI variance normalization based on ICA+FIX outputs
%This function regresses the structured signal out of the data
%to create a dense timeseries of only unstructured noise
%the standard deviation of this map is used to normalize
%the dense timeseries.

% edits by T.B. Brown to print debugging information.
func_name='ComputeVN'
fprintf('%s - start\n', func_name)
fprintf('%s - cleandtseries: %s\n', func_name, cleandtseries)
fprintf('%s - bias: %s\n', func_name, bias)
fprintf('%s - ICAtcs: %s\n', func_name, ICAtcs)
fprintf('%s - ICANoise: %s\n', func_name, ICANoise)
fprintf('%s - OutputVN: %s\n', func_name, OutputVN)
fprintf('%s - wbcommand: %s\n', func_name, wbcommand)


cleandtseries=ciftiopen(cleandtseries,wbcommand);

VN=cleandtseries;
ICAtcs=normalise(load(ICAtcs));
ICANoise=load(ICANoise);
ICASignal=setdiff([1:1:size(ICAtcs,2)],ICANoise);

cleandtseries.cdata=demean(cleandtseries.cdata,2);

if ~strcmp(bias,'NONE') %Revert the bias field if asked to before computing VN
    bias=ciftiopen(bias,wbcommand);
    cleandtseries.cdata=cleandtseries.cdata*repmat(bias.cdata,1,size(cleandtseries.cdata,2));    
end

betaICA=pinv(ICAtcs(:,ICASignal))*cleandtseries.cdata';
unstructurednoiseTCS=cleandtseries.cdata - (ICAtcs(:,ICASignal)*betaICA)'; %Regress out the signal only because noise has already been regressed out
VN.cdata=max(sqrt(var(unstructurednoiseTCS,[],2)),0.001); %Avoid divide by zero errors
ciftisavereset(VN,OutputVN,wbcommand);

fprintf('%s - complete\n', func_name)
