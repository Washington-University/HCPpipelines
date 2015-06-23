function RestingStateStats(motionparameters,hp,TR,ICAs,noiselist,wbcommand,inputdtseries,bias,outprefix,dlabel)

% function RestingStateStats(motionparameters,hp,TR,ICAs,noiselist,wbcommand,inputdtseries,bias,outprefix,dlabel)
%
% Script for decomposing the CIFTI time series variance into 5 different
% components: high pass filter, motion regressors, structured noise,
% unstructured noise, and signal (BOLD) using a run of ICA+FIX.  Input data
% has not yet been cleaned.
%
% MOTIONPARAMETERS: File with 6 motion parameters translations and rotations X Y Z.
%   That is expanded to backward differences and square terms (i.e., 24 regressors total)
% HP: high-pass filter (in sec) to apply via 'fslmaths'
% TR: repetition time (used to set HP filter correctly)
% ICAs: mixing coefficients from the ICA decomposition; i.e., 'melodic_mix'
% NOISELIST: File listing which ICA components were classified by FIX as "noise"
% WBCOMMAND: location of 'wb_command'
% INPUTDTSERIES: input CIFTI timeseries (uncleaned timeseries after
%   registration to CIFTI standard space).
% BIAS: bias field (as dscalar.nii) to apply (via grayordinate-wise
%   multiplication) to INPUTDTSERIES. Set to empty to apply nothing.
%   N.B. In the HCP "minimal processing", the bias field is removed.
%   So, if you want the spatial variance to reflect the intensity 
%   scaling of the original data, the bias field must be "restored".
%   This is the recommended approach currently.
% OUTPREFIX (optional): file name prefix for the outputs; if omitted
%   then INPUTDTSERIES is used as the file name prefix.
%   Set to empty if you need a place holder for this argument.
%   If this input includes a path related (directory) component as well,
%   that will effect the location to which the outputs are saved.
% DLABEL (optional): dense label file (CIFTI), which if provided
%   results in the generation of parcellated time series (.ptseries.nii
%   files) after each stage of clean up.
  
%% Notes on variable dimensions:
%    cdata: NgrayOrd x Ntp (e.g., 91282 x 1200)
%    ICAs: Ntp x Ncomponents
%    confounds: Ntp x 24 (after extending with first differences and
%       squared terms)
%% Make note of the transpose operators in various equations (need to
% work with the time axis as the first dimension in the GLMs)
  
% "core" of script for HP filtering, confound regression, and
% FIX cleanup components based on "fix_3_clean.m"
  
% Authors: M.Glasser, M.Harms, S.Smith

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Set some options that aren't included as arguments in the function
SaveVarianceNormalizationImage = 1; %If non-zero, output map of sqrt(UnstructNoiseVar)
SaveMGT = 1; %If non-zero, save mean grayordinate time series at each stage
SaveGrayOrdinateMaps = 1; % Set to non-zero to save a number of grayordinate maps (into a single .dtseries.nii)

WBC=wbcommand;
tpDim = 2;  %Time point dimension of CIFTI

% Remove .dtseries.nii extension from 'inputdtseries', if it was included
K = strfind(inputdtseries,'.dtseries.nii');
if ~isempty(K)
  inputdtseries = inputdtseries(1:K-1);
end

% Other variable prep
if nargin<9 || isempty(outprefix)
  outprefix = inputdtseries;
end
if ~exist('dlabel','var')
  dlabel = [];
end


% Read set of FIX classified noise components
Inoise=load(noiselist);

%%%% Read data, (optionally revert bias field correction) and compute basic stats
BO=ciftiopen([inputdtseries '.dtseries.nii'],WBC);
% Revert bias field if requested
if ~isempty(bias)
    bias=ciftiopen(bias,WBC);
    BO.cdata=BO.cdata.*repmat(bias.cdata,1,size(BO.cdata,tpDim));
end

% Compute spatial mean/std, demean each grayordinate
MEAN = mean(BO.cdata,tpDim);
STD=std(BO.cdata,[],tpDim);
BO.cdata = demean(BO.cdata,tpDim);
OrigTCS=BO.cdata;

%%%% Highpass each grayordinate with fslmaths according to hp variable
fprintf('Starting fslmaths filtering of cifti input\n');
BOdimX=size(BO.cdata,1);  BOdimZnew=ceil(BOdimX/100);  BOdimT=size(BO.cdata,tpDim);
save_avw(reshape([BO.cdata ; zeros(100*BOdimZnew-BOdimX,BOdimT)],10,10,BOdimZnew,BOdimT),[outprefix '_fakeNIFTI'],'f',[1 1 1 TR]);
system(sprintf(['fslmaths ' outprefix '_fakeNIFTI -bptf %f -1 ' outprefix '_fakeNIFTI'],0.5*hp/TR));
grot=reshape(read_avw([outprefix '_fakeNIFTI']),100*BOdimZnew,BOdimT);  BO.cdata=grot(1:BOdimX,:);  clear grot;
unix(['rm ' outprefix '_fakeNIFTI.nii.gz']);    
fprintf('Finished fslmaths filtering of cifti input\n');

HighPassTCS=BO.cdata;

%%%% Compute variances so far
OrigVar=var(OrigTCS,[],tpDim);
[OrigMGTRtcs OrigMGT OrigbetaMGT OrigMGTVar] = MGTR(OrigTCS);

HighPassVar=var((OrigTCS - HighPassTCS),[],tpDim);
[HighPassMGTRtcs HighPassMGT HighPassbetaMGT HighPassMGTVar] = MGTR(HighPassTCS);

%%%%  Read and prepare motion confounds
% Read in the six motion parameters, compute the backward difference, and square
% If 'motionparameters' input argument doesn't already have an extension, add .txt
confounds=[];
[~, ~, ext] = fileparts(motionparameters);
if isempty(ext)
  confounds=load([motionparameters '.txt']);
else
  confounds=load(motionparameters);
end
confounds=confounds(:,1:6); %Be sure to limit to just the first 6 elements
%%confounds=normalise(confounds(:,std(confounds)>0.000001)); % remove empty columns
confounds=normalise([confounds [zeros(1,size(confounds,2)); confounds(2:end,:)-confounds(1:end-1,:)] ]);
confounds=normalise([confounds confounds.*confounds]);

fprintf('Starting fslmaths filtering of motion confounds\n');
save_avw(reshape(confounds',size(confounds,2),1,1,size(confounds,1)),[outprefix '_fakeNIFTI'],'f',[1 1 1 TR]);
system(sprintf(['fslmaths ' outprefix '_fakeNIFTI -bptf %f -1 ' outprefix '_fakeNIFTI'],0.5*hp/TR));
confounds=normalise(reshape(read_avw([outprefix '_fakeNIFTI']),size(confounds,2),size(confounds,1))');
unix(['rm ' outprefix '_fakeNIFTI.nii.gz']);
fprintf('Finished fslmaths filtering of motion confounds\n');

%%%%  Read ICA component timeseries
ICAorig=normalise(load(sprintf(ICAs)));

%%%% Aggressively regress out motion parameters from ICA and from data
ICA = ICAorig - (confounds * (pinv(confounds) * ICAorig));
PostMotionTCS = HighPassTCS - (confounds * (pinv(confounds) * HighPassTCS'))';
[PostMotionMGTRtcs PostMotionMGT PostMotionbetaMGT PostMotionMGTVar] = MGTR(PostMotionTCS);
MotionVar=var((HighPassTCS - PostMotionTCS),[],tpDim);

%%%% FIX cleanup post motion
%Find signal and total component numbers
total = [1:1:size(ICA,2)];
Isignal = total(~ismember(total,Inoise));

% beta for ICA (signal *and* noise components), followed by unaggressive cleanup
% (i.e., only remove unique variance associated with the noise components)
betaICA = pinv(ICA) * PostMotionTCS';
CleanedTCS = PostMotionTCS - (ICA(:,Inoise) * betaICA(Inoise,:))';
[CleanedMGTRtcs CleanedMGT CleanedbetaMGT CleanedMGTVar] = MGTR(CleanedTCS);

% Estimate the unstructured ("Gaussian") noise variance as what remains
% in the time series after removing all ICA components
UnstructNoiseTCS = PostMotionTCS - (ICA * betaICA)';
[UnstructNoiseMGTRtcs UnstructNoiseMGT UnstructNoiseBetaMGT UnstructNoiseMGTVar] = MGTR(UnstructNoiseTCS);
UnstructNoiseVar = var(UnstructNoiseTCS,[],tpDim);

% Remove only FIX classified *signal* components, giving a ts that contains both
% structured and unstructured noise
NoiseTCS = PostMotionTCS - (ICA(:,Isignal) * betaICA(Isignal,:))';  
[NoiseMGTRtcs NoiseMGT NoiseBetaMGT NoiseMGTVar] = MGTR(NoiseTCS);

% Use the preceding to now estimate the structured noise variance and the
% signal specific variance ("BOLDVar")
StructNoiseVar = var(NoiseTCS,[],tpDim) - UnstructNoiseVar;
BOLDVar = var(CleanedTCS,[],tpDim) - UnstructNoiseVar;

% These variance components are not necessarily strictly orthogonal.  The
% following variables can be used to assess the degree of overlap.
TotalUnsharedVar = UnstructNoiseVar + StructNoiseVar + BOLDVar + MotionVar + HighPassVar;
TotalSharedVar = OrigVar - TotalUnsharedVar;

% Compute some grayordinate CIFTI maps of COV and TSNR
COV = sqrt(UnstructNoiseVar) ./ MEAN;
COV(isnan(COV)) = 0; 
TSNR = MEAN ./ sqrt(UnstructNoiseVar);
TSNR(isnan(TSNR)) = 0;
CNR = sqrt(BOLDVar ./ UnstructNoiseVar);
CNR(isnan(CNR)) = 0;

% Compute grayordinate variance ratio images, normalized to OrigVar
HighPassVarRatio = makeRatio(HighPassVar,OrigVar);
MotionVarRatio = makeRatio(MotionVar,OrigVar);
StructNoiseVarRatio = makeRatio(StructNoiseVar,OrigVar);
BOLDVarRatio = makeRatio(BOLDVar,OrigVar);
UnstructNoiseVarRatio = makeRatio(UnstructNoiseVar,OrigVar);
OrigMGTVarRatio = makeRatio(OrigMGTVar,OrigVar);
HighPassMGTVarRatio = makeRatio(HighPassMGTVar,OrigVar);
MotionMGTVarRatio = makeRatio(PostMotionMGTVar,OrigVar);
CleanedMGTVarRatio = makeRatio(CleanedMGTVar,OrigVar);

% Compute summary measures across grayordinates
meanMEAN = mean(MEAN);
meanSTD = mean(STD);
meanCOV = mean(COV); 
meanTSNR = mean(TSNR);

meanOrigVar = mean(OrigVar);
meanHighPassVar = mean(HighPassVar);
meanMotionVar = mean(MotionVar);
meanUnstructNoiseVar = mean(UnstructNoiseVar);
meanStructNoiseVar = mean(StructNoiseVar);
meanBOLDVar = mean(BOLDVar);
meanTotalSharedVar = mean(TotalSharedVar);
meanCNR = mean(CNR);
meanOrigMGTVar = mean(OrigMGTVar);
meanHighPassMGTVar = mean(HighPassMGTVar);
meanPostMotionMGTVar = mean(PostMotionMGTVar);
meanCleanedMGTVar = mean(CleanedMGTVar);
meanOrigbetaMGT = mean(OrigbetaMGT);
meanHighPassbetaMGT = mean(HighPassbetaMGT);
meanPostMotionbetaMGT = mean(PostMotionbetaMGT);
meanCleanedbetaMGT = mean(CleanedbetaMGT);
meanHighPassVarRatio = mean(HighPassVarRatio);
meanMotionVarRatio = mean(MotionVarRatio);
meanStructNoiseVarRatio = mean(StructNoiseVarRatio);
meanBOLDVarRatio = mean(BOLDVarRatio);
meanUnstructNoiseVarRatio = mean(UnstructNoiseVarRatio);
meanOrigMGTVarRatio = mean(OrigMGTVarRatio);
meanHighPassMGTVarRatio = mean(HighPassMGTVarRatio);
meanMotionMGTVarRatio = mean(MotionMGTVarRatio);
meanCleanedMGTVarRatio = mean(CleanedMGTVarRatio);

% Save out variance normalization image for MSMALL/SingleSubjectConcat/MIGP
if SaveVarianceNormalizationImage
  fprintf('Saving variance normalization image [i.e., sqrt(UnstructNoiseVar)]\n');
  VarianceNormalizationImage=BO;
  VarianceNormalizationImage.cdata=sqrt(UnstructNoiseVar);
  ciftisavereset(VarianceNormalizationImage,[outprefix '_vn.dscalar.nii'],WBC);
end

% Save out grayordinate maps of a number of variables
if SaveGrayOrdinateMaps
  fprintf('Saving grayordinate maps\n');
  statscifti = BO;
  statscifti.cdata = [MEAN STD COV TSNR OrigVar HighPassVar MotionVar StructNoiseVar BOLDVar UnstructNoiseVar TotalSharedVar CNR OrigMGTVar HighPassMGTVar PostMotionMGTVar CleanedMGTVar OrigbetaMGT HighPassbetaMGT PostMotionbetaMGT CleanedbetaMGT HighPassVarRatio MotionVarRatio StructNoiseVarRatio BOLDVarRatio UnstructNoiseVarRatio OrigMGTVarRatio HighPassMGTVarRatio MotionMGTVarRatio CleanedMGTVarRatio];

  ciftisave(statscifti,[outprefix '_stats.dtseries.nii'],WBC);
end

% Save out parcellated time series
if ~isempty(dlabel)
  fprintf('Saving parcellated time series from each stage\n');
  
  % Generate a ptseries.nii using provided dlabel file using -cifti-parcellate,
  % which we'll need as a CIFTI ptseries template
  ciftiIn = [inputdtseries '.dtseries.nii'];
  ciftiOut = [outprefix '_template.ptseries.nii'];
  unix([WBC ' -cifti-parcellate ' ciftiIn ' ' dlabel ' COLUMN ' ciftiOut]);
  
  ptTemplate = ciftiopen(ciftiOut,WBC);

  % Parcellated time series from each stage
  savePTCS(OrigTCS,dlabel,outprefix,'OrigTCS',ptTemplate,WBC);
  savePTCS(HighPassTCS,dlabel,outprefix,'HighPassTCS',ptTemplate,WBC);
  savePTCS(PostMotionTCS,dlabel,outprefix,'PostMotionTCS',ptTemplate,WBC);
  savePTCS(CleanedTCS,dlabel,outprefix,'CleanedTCS',ptTemplate,WBC);
  savePTCS(UnstructNoiseTCS,dlabel,outprefix,'UnstructNoiseTCS',ptTemplate,WBC);
  savePTCS(NoiseTCS,dlabel,outprefix,'NoiseTCS',ptTemplate,WBC);

  % Parcellated "MGT" regressed time series from each stage
  savePTCS(OrigMGTRtcs,dlabel,outprefix,'OrigMGTRTCS',ptTemplate,WBC);
  savePTCS(HighPassMGTRtcs,dlabel,outprefix,'HighPassMGTRTCS',ptTemplate,WBC);
  savePTCS(PostMotionMGTRtcs,dlabel,outprefix,'PostMotionMGTRTCS',ptTemplate,WBC);
  savePTCS(CleanedMGTRtcs,dlabel,outprefix,'CleanedMGTRTCS',ptTemplate,WBC);
  savePTCS(UnstructNoiseMGTRtcs,dlabel,outprefix,'UnstructNoiseMGTRTCS',ptTemplate,WBC);
  savePTCS(NoiseMGTRtcs,dlabel,outprefix,'NoiseMGTRTCS',ptTemplate,WBC);
end

if SaveMGT
  dlmwrite([outprefix '_OrigMGT.txt'],OrigMGT);
  dlmwrite([outprefix '_HighPassMGT.txt'],HighPassMGT);
  dlmwrite([outprefix '_PostMotionMGT.txt'],PostMotionMGT);
  dlmwrite([outprefix '_CleanedMGT.txt'],CleanedMGT);
  dlmwrite([outprefix '_UnstructNoiseMGT.txt'],UnstructNoiseMGT);
  dlmwrite([outprefix '_NoiseMGT.txt'],NoiseMGT);
end

% Write out stats file
% (Make sure to keep varNames in correspondence with the order that
% variables are written out!)
varNames = ['TCSName,NumSignal,NumNoise,NumTotal,MEAN,STD,COV,TSNR,OrigVar,HPVar,MotionVar,StructNoiseVar,BOLDVar,UnstructNoiseVar,TotalSharedVar,CNR,OrigMGTVar,PostHPMGTVar,PostMotionMGTVar,CleanedMGTVar,OrigbetaMGT,PostHPbetaMGT,PostMotionbetaMGT,CleanedbetaMGT,HPVarRatio,MotionVarRatio,StructNoiseVarRatio,BOLDVarRatio,UnstructNoiseVarRatio,OrigMGTVarRatio,PostHPMGTVarRatio,PostMotionMGTVarRatio,CleanedMGTVarRatio'];

fid = fopen([outprefix '_stats.txt'],'w');
fprintf(fid,'%s\n',varNames);
fprintf(fid,'%s,%d,%d,%d',inputdtseries,length(Isignal),length(Inoise),length(Isignal)+length(Inoise));
fprintf(fid,',%.2f,%.2f,%.4f,%.2f',meanMEAN,meanSTD,meanCOV,meanTSNR);
fprintf(fid,',%.2f,%.2f,%.2f,%.2f',meanOrigVar,meanHighPassVar,meanMotionVar,meanStructNoiseVar);
fprintf(fid,',%.2f,%.2f,%.4f,%.4f',meanBOLDVar,meanUnstructNoiseVar,meanTotalSharedVar,meanCNR);
fprintf(fid,',%.2f,%.2f,%.2f,%.2f',meanOrigMGTVar,meanHighPassMGTVar,meanPostMotionMGTVar,meanCleanedMGTVar);
fprintf(fid,',%.3f,%.3f,%.3f,%.3f',meanOrigbetaMGT,meanHighPassbetaMGT,meanPostMotionbetaMGT,meanCleanedbetaMGT);
fprintf(fid,',%.5f,%.5f,%.5f,%.5f',meanHighPassVarRatio,meanMotionVarRatio,meanStructNoiseVarRatio,meanBOLDVarRatio);
fprintf(fid,',%.5f,%.5f,%.5f',meanUnstructNoiseVarRatio,meanOrigMGTVarRatio,meanHighPassMGTVarRatio);
fprintf(fid,',%.5f,%.5f',meanMotionMGTVarRatio,meanCleanedMGTVarRatio);
fprintf(fid,'\n');

end


%%%% HELPER FUNCTIONS %%%%

%% MGTR is a function that takes time courses as input and returns
%% MGT: mean grayordinate time series
%% MGTRtcs: residual time series after regressing out MGT
%% betaMGT: spatial map of the beta of the regression of MGT onto the
%%          input time courses
%% MGTVar: spatial map of the variance attributable to MGT
function [MGTRtcs MGT betaMGT MGTVar] = MGTR(tcs)
    MGT = demean(mean(tcs,1))';
    betaMGT = pinv(MGT) * tcs';
    MGTRtcs = tcs - (MGT * betaMGT)';
    MGTVar = var((tcs - MGTRtcs),[],2);
    betaMGT = betaMGT';
end

function [out] = makeRatio(num,den)
  out = num./den;
  out(isnan(out)) = 0;  %Set NaN's to 0
end

%% SAVEPTCS saves out parcellated time series given a dlabel input
function [] = savePTCS(tcs,dlabelfile,basename,saveString,ptTemplate,wbcommand)
  tpDim = 2;  %Time point dimension
  
  nTP = size(tcs,tpDim);
  label = ciftiopen(dlabelfile,wbcommand);    
  nParcels = max(label.cdata);
  ptseries = zeros(nParcels,nTP);
  for i = 1:nParcels
    ind = find(label.cdata == i);
    ptseries(i,:) = mean(tcs(ind,:));
  end;
  
  ptseriesOut = ptTemplate;  % Initialize as a CIFTI structure
  ptseriesOut.cdata = ptseries;  % Change the data
  % Write it out
  ciftisave(ptseriesOut,[basename '_' saveString '.ptseries.nii'],wbcommand);
end
