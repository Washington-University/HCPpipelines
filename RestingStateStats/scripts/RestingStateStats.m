function RestingStateStats(motionparameters,hp,TR,ICAs,noiselist,wbcommand,inputdtseries,bias,outprefix,dlabel,bcmode,outstring,WM,CSF)

% function RestingStateStats(motionparameters,hp,TR,ICAs,noiselist,wbcommand,inputdtseries,bias,outprefix,dlabel,bcmode,outstring)
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
%   multiplication) to INPUTDTSERIES.
%   N.B. In the HCP "minimal processing", the bias field is removed.
%   So, if you want the spatial variance to reflect the intensity 
%   scaling of the original data, the bias field must be "restored".
% OUTPREFIX (optional): file name prefix for the outputs; if omitted
%   then INPUTDTSERIES is used as the file name prefix.
%   Set to empty if you need a place holder for this argument.
%   If this input includes a path related (directory) component as well,
%   that will effect the location to which the outputs are saved.
% DLABEL (optional): dense label file (CIFTI), which if provided
%   results in the generation of parcellated time series (.ptseries.nii
%   files) after each stage of clean up.
% BCMODE (optional): REVERT - undoes bias field correction
%   NONE - does not change bias field correction
%   File - uses file to apply new bias field correction after reverting old
% OUTSTRING: normally 'stats'
% WM: A text file or NONE
% CSF: A text file or NONE

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

% edits by S.Kandala to add R^2 computation for global signal regression at
% various denoising stages. 2015-07-02.

% edits by T.B.Brown to convert string parameters to numeric values
% as necessary. When used with compiled Matlab, all parameters are 
% passed in as strings.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Convert input parameter strings to numerics as necessary, and show input parameters
func_name='RestingStateStats';
fprintf('%s - start\n', func_name);
fprintf('%s - motionparameters: %s\n', func_name, motionparameters);
if isdeployed
  fprintf('%s - hp: "%s"\n', func_name, hp);
  hp=str2double(hp);
end
fprintf('%s - hp: %d\n', func_name, hp);

if isdeployed
  fprintf('%s - TR: "%s"\n', func_name, TR);
  TR=str2double(TR);
end
fprintf('%s - TR: %d\n', func_name, TR);

fprintf('%s - ICAs: %s\n', func_name, ICAs);
fprintf('%s - noiselist: %s\n', func_name, noiselist);
fprintf('%s - wbcommand: %s\n', func_name, wbcommand);
fprintf('%s - inputdtseries: %s\n', func_name, inputdtseries);
fprintf('%s - bias: %s\n', func_name, bias);
fprintf('%s - outprefix: %s\n', func_name, outprefix);
fprintf('%s - dlabel: %s\n', func_name, dlabel);
fprintf('%s - bcmode: %s\n', func_name, bcmode);
fprintf('%s - outstring: %s\n', func_name, outstring);
fprintf('%s - WM: %s\n', func_name, WM);
fprintf('%s - CSF: %s\n', func_name, CSF);

% Set some options that aren't included as arguments in the function
SaveVarianceNormalizationImage = 1; %If non-zero, output map of sqrt(UnstructNoiseVar)
SaveMGT = 1; %If non-zero, save mean grayordinate time series at each stage
SaveGrayOrdinateMaps = 1; % Set to non-zero to save a number of grayordinate maps (into a single .dtseries.nii)
SaveExtraVar = 1;  % Set to non-zero to save some extra maps/stats related to UnstructNoiseMGT* and NoiseMGT*

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
% MPH: Other error checking/handling of inputs would be warranted here.
% e.g., what if OUTSTRING, WM, or CSF arguments are not supplied?

% Read set of FIX classified noise components
Inoise=load(noiselist);

%%%% Read data, (optionally revert bias field correction) and compute basic stats
BO=ciftiopen([inputdtseries '.dtseries.nii'],WBC);

% Revert bias field if requested
if ~strcmp(bcmode,'NONE');
    bias=ciftiopen(bias,WBC);
    BO.cdata=BO.cdata.*repmat(bias.cdata,1,size(BO.cdata,tpDim));
end

FixVN=0;
if exist(bcmode,'file')
    real_bias=ciftiopen(bcmode,WBC);
    BO.cdata=BO.cdata./repmat(real_bias.cdata,1,size(BO.cdata,tpDim));
    FixVN=1;
end

% Compute spatial mean/std, demean each grayordinate
MEAN = mean(BO.cdata,tpDim);
STD=std(BO.cdata,[],tpDim);
BO.cdata = demean(BO.cdata,tpDim);
OrigTCS=BO.cdata;

%%%% Highpass each grayordinate with fslmaths according to hp variable
fprintf('%s - Starting fslmaths filtering of cifti input\n',func_name);
BOdimX=size(BO.cdata,1);  BOdimZnew=ceil(BOdimX/100);  BOdimT=size(BO.cdata,tpDim);
fprintf('%s - About to save fakeNIFTI file. outprefix: %s\n',func_name,outprefix);
save_avw(reshape([BO.cdata ; zeros(100*BOdimZnew-BOdimX,BOdimT)],10,10,BOdimZnew,BOdimT),[outprefix '_fakeNIFTI'],'f',[1 1 1 TR]);

cmd_str=sprintf(['fslmaths ' outprefix '_fakeNIFTI -bptf %f -1 ' outprefix '_fakeNIFTI'],0.5*hp/TR);
fprintf('%s - About to execute: %s\n',func_name,cmd_str);
system(cmd_str);

fprintf('%s - About to reshape\n',func_name);
grot=reshape(read_avw([outprefix '_fakeNIFTI']),100*BOdimZnew,BOdimT);  BO.cdata=grot(1:BOdimX,:);  clear grot;

fprintf('%s - About to remove fakeNIFTI file',func_name);
unix(['rm ' outprefix '_fakeNIFTI.nii.gz']);    
fprintf('%s - Finished fslmaths filtering of cifti input\n',func_name);

HighPassTCS=BO.cdata;

%%%% Compute variances so far
OrigVar=var(OrigTCS,[],tpDim);
[OrigMGTRtcs,OrigMGT,OrigMGTbeta,OrigMGTVar,OrigMGTrsq] = MGTR(OrigTCS);

HighPassVar=var((OrigTCS - HighPassTCS),[],tpDim);
[HighPassMGTRtcs,HighPassMGT,HighPassMGTbeta,HighPassMGTVar,HighPassMGTrsq] = MGTR(HighPassTCS);

%%%%  Read and prepare motion confounds
% Read in the six motion parameters, compute the backward difference, and square
% If 'motionparameters' input argument doesn't already have an extension, add .txt
confounds=[]; %#ok<NASGU>
[~, ~, ext] = fileparts(motionparameters);
if isempty(ext)
  confounds=load([motionparameters '.txt']);
else
  confounds=load(motionparameters);
end
mvm=confounds;
confounds=confounds(:,1:6); %Be sure to limit to just the first 6 elements
%%confounds=normalise(confounds(:,std(confounds)>0.000001)); % remove empty columns
confounds=normalise([confounds [zeros(1,size(confounds,2)); confounds(2:end,:)-confounds(1:end-1,:)] ]);
confounds=normalise([confounds confounds.*confounds]);

fprintf('%s - Starting fslmaths filtering of motion confounds\n',func_name);
save_avw(reshape(confounds',size(confounds,2),1,1,size(confounds,1)),[outprefix '_fakeNIFTI'],'f',[1 1 1 TR]);
system(sprintf(['fslmaths ' outprefix '_fakeNIFTI -bptf %f -1 ' outprefix '_fakeNIFTI'],0.5*hp/TR));
confounds=normalise(reshape(read_avw([outprefix '_fakeNIFTI']),size(confounds,2),size(confounds,1))');
unix(['rm ' outprefix '_fakeNIFTI.nii.gz']);
fprintf('%s - Finished fslmaths filtering of motion confounds\n',func_name);

%%%%  Read ICA component timeseries
ICAorig=normalise(load(sprintf(ICAs)));

%%%%  Read WM Timeseries and Highpass Filter
if ~strcmp(WM,'NONE')
    WMtcOrig=demean(load(sprintf(WM)));
    fprintf('%s - Starting fslmaths filtering of wm tcs \n',func_name);
    save_avw(reshape(WMtcOrig',size(WMtcOrig,2),1,1,size(WMtcOrig,1)),[outprefix '_fakeNIFTI'],'f',[1 1 1 TR]);
    system(sprintf(['fslmaths ' outprefix '_fakeNIFTI -bptf %f -1 ' outprefix '_fakeNIFTI'],0.5*hp/TR));
    WMtcHP=demean(reshape(read_avw([outprefix '_fakeNIFTI']),size(WMtcOrig,2),size(WMtcOrig,1))');
    unix(['rm ' outprefix '_fakeNIFTI.nii.gz']);
    fprintf('%s - Finished fslmaths filtering of wm tcs\n',func_name);
end

%%%%  Read CSF Timeseries and Highpass Filter
if ~strcmp(CSF,'NONE')
    CSFtcOrig=demean(load(sprintf(CSF)));
    fprintf('%s - Starting fslmaths filtering of csf tcs \n',func_name);
    save_avw(reshape(CSFtcOrig',size(CSFtcOrig,2),1,1,size(CSFtcOrig,1)),[outprefix '_fakeNIFTI'],'f',[1 1 1 TR]);
    system(sprintf(['fslmaths ' outprefix '_fakeNIFTI -bptf %f -1 ' outprefix '_fakeNIFTI'],0.5*hp/TR));
    CSFtcHP=demean(reshape(read_avw([outprefix '_fakeNIFTI']),size(CSFtcOrig,2),size(CSFtcOrig,1))');
    unix(['rm ' outprefix '_fakeNIFTI.nii.gz']);
    fprintf('%s - Finished fslmaths filtering of csf tcs\n',func_name);
end

%%%% Aggressively regress out motion parameters from ICA and from data
ICA = ICAorig - (confounds * (pinv(confounds,1e-6) * ICAorig));
if ~strcmp(WM,'NONE')
    %%%% Aggressively regress out motion parameters from WM
    WMtcPM = WMtcHP - (confounds * (pinv(confounds,1e-6) * WMtcHP));
    %%%% Regress out Noise
    WMbetaICA = pinv(ICA,1e-6) * WMtcPM;
    WMtcClean = WMtcPM - (ICA(:,Inoise) * WMbetaICA(Inoise,:));
    WMtcClean = demean(WMtcClean);
end
if ~strcmp(CSF,'NONE')
    %%%% Aggressively regress out motion parameters from CSF
    CSFtcPM = CSFtcHP - (confounds * (pinv(confounds,1e-6) * CSFtcHP));
    %%%% Regress out Noise
    CSFbetaICA = pinv(ICA,1e-6) * CSFtcPM;
    CSFtcClean = CSFtcPM - (ICA(:,Inoise) * CSFbetaICA(Inoise,:));
    CSFtcClean = demean(CSFtcClean);
end
%%%% Aggressively regress out motion parameters from data
PostMotionTCS = HighPassTCS - (confounds * (pinv(confounds,1e-6) * HighPassTCS'))';
[PostMotionMGTRtcs,PostMotionMGT,PostMotionMGTbeta,PostMotionMGTVar,PostMotionMGTrsq] = MGTR(PostMotionTCS);
MotionVar=var((HighPassTCS - PostMotionTCS),[],tpDim);

%%%% FIX cleanup post motion
%Find signal and total component numbers
total = 1:size(ICA,2);
Isignal = total(~ismember(total,Inoise));

% beta for ICA (signal *and* noise components), followed by unaggressive cleanup
% (i.e., only remove unique variance associated with the noise components)
betaICA = pinv(ICA,1e-6) * PostMotionTCS';
CleanedTCS = PostMotionTCS - (ICA(:,Inoise) * betaICA(Inoise,:))';
[CleanedMGTRtcs,CleanedMGT,CleanedMGTbeta,CleanedMGTVar,CleanedMGTrsq] = MGTR(CleanedTCS);

% Estimate the unstructured ("Gaussian") noise variance as what remains
% in the time series after removing all ICA components
UnstructNoiseTCS = PostMotionTCS - (ICA * betaICA)';
[UnstructNoiseMGTRtcs,UnstructNoiseMGT,UnstructNoiseMGTbeta,UnstructNoiseMGTVar,UnstructNoiseMGTrsq] = MGTR(UnstructNoiseTCS);
UnstructNoiseVar = var(UnstructNoiseTCS,[],tpDim);

% Remove only FIX classified *signal* components, giving a ts that contains both
% structured and unstructured noise
NoiseTCS = PostMotionTCS - (ICA(:,Isignal) * betaICA(Isignal,:))';  
[NoiseMGTRtcs,NoiseMGT,NoiseMGTbeta,NoiseMGTVar,NoiseMGTrsq] = MGTR(NoiseTCS);

% Use the preceding to now estimate the structured noise variance and the
% signal specific variance ("BOLDVar")
StructNoiseTCS = NoiseTCS - UnstructNoiseTCS;
[StructNoiseMGTRtcs,StructNoiseMGT,StructNoiseMGTbeta,StructNoiseMGTVar,StructNoiseMGTrsq] = MGTR(StructNoiseTCS);
StructNoiseVar = var(StructNoiseTCS,[],tpDim);
BOLDVar = var((CleanedTCS - UnstructNoiseTCS),[],tpDim);

% These variance components are not necessarily strictly orthogonal.  The
% following variables can be used to assess the degree of overlap.
TotalUnsharedVar = UnstructNoiseVar + StructNoiseVar + BOLDVar + MotionVar + HighPassVar;
TotalSharedVar = OrigVar - TotalUnsharedVar;

%Create WM and CSF timecourses that correspond to structured and
%unstructured noise grey plots
if ~strcmp(WM,'NONE')
    % Regress out all structured signal
    WMbetaICA = pinv(ICA,1e-6) * WMtcPM;
    WMtcUnstructNoise = WMtcPM - (ICA * WMbetaICA);
    WMtcUnstructNoise = demean(WMtcUnstructNoise);
end
if ~strcmp(CSF,'NONE')
    % Regress out all structured signal    
    CSFbetaICA = pinv(ICA,1e-6) * CSFtcPM;
    CSFtcUnstructNoise = CSFtcPM - (ICA * CSFbetaICA);
    CSFtcUnstructNoise = demean(CSFtcUnstructNoise);
end

if ~strcmp(WM,'NONE')
    % Regress out all signal
    WMbetaICA = pinv(ICA,1e-6) * WMtcPM;
    WMtcStructNoise = WMtcPM - (ICA(:,Isignal) * WMbetaICA(Isignal,:));
    WMtcStructNoise = demean(WMtcStructNoise);
end
if ~strcmp(CSF,'NONE')
    % Regress out all signal    
    CSFbetaICA = pinv(ICA,1e-6) * CSFtcPM;
    CSFtcStructNoise = CSFtcPM - (ICA(:,Isignal) * CSFbetaICA(Isignal,:));
    CSFtcStructNoise = demean(CSFtcStructNoise);
end

%Create data if regressing out cleaned WM timecourse
if ~strcmp(WM,'NONE')
    betaWM = pinv(WMtcClean,1e-6) * CleanedTCS';
    WMCleanedTCS = CleanedTCS - (WMtcClean * betaWM)';
    [WMCleanedMGTRtcs,WMCleanedMGT,WMCleanedMGTbeta,WMCleanedMGTVar,WMCleanedMGTrsq] = MGTR(WMCleanedTCS);
    WMVar = var((CleanedTCS - WMCleanedTCS),[],tpDim);
end
if ~strcmp(WM,'NONE') && ~strcmp(CSF,'NONE')
    % Regress out WM from CSF signal   
    betaCSFWM = pinv(WMtcClean,1e-6) * CSFtcClean;
    CSFWM = CSFtcClean - (WMtcClean * betaCSFWM);
    CSFWM = demean(CSFWM);
    WMWM=single(zeros(length(CSFWM),1));
end

%Create data if regressing out cleaned CSF timecourse
if ~strcmp(CSF,'NONE')
    betaCSF = pinv(CSFtcClean,1e-6) * CleanedTCS';
    CSFCleanedTCS = CleanedTCS - (CSFtcClean * betaCSF)';
    [CSFCleanedMGTRtcs,CSFCleanedMGT,CSFCleanedMGTbeta,CSFCleanedMGTVar,CSFCleanedMGTrsq] = MGTR(CSFCleanedTCS);
    CSFVar = var((CleanedTCS - CSFCleanedTCS),[],tpDim);
end
if ~strcmp(WM,'NONE') && ~strcmp(CSF,'NONE')
    % Regress out CSF from WM signal   
    betaWMCSF = pinv(CSFtcClean,1e-6) * WMtcClean;
    WMCSF = WMtcClean - (CSFtcClean * betaWMCSF);
    WMCSF = demean(WMCSF);
    CSFCSF=single(zeros(length(WMCSF),1));
end

%Create data if regressing out cleaned WM and CSF timecourses
if ~strcmp(WM,'NONE') && ~strcmp(CSF,'NONE')
    betaWMCSF = pinv([WMtcClean CSFtcClean],1e-6) * CleanedTCS';
    WMCSFCleanedTCS = CleanedTCS - ([WMtcClean CSFtcClean] * betaWMCSF)';
    [WMCSFCleanedMGTRtcs,WMCSFCleanedMGT,WMCSFCleanedMGTbeta,WMCSFCleanedMGTVar,WMCSFCleanedMGTrsq] = MGTR(WMCSFCleanedTCS);
    WMCSFVar = var((CleanedTCS - WMCSFCleanedTCS),[],tpDim);
end

%Make BOLD Variance if regressing out WM and/or CSF timecourses
if ~strcmp(WM,'NONE')
    WMCleanedBOLDVar = var((WMCleanedTCS - UnstructNoiseTCS),[],tpDim);
end
if ~strcmp(CSF,'NONE')
    CSFCleanedBOLDVar = var((CSFCleanedTCS - UnstructNoiseTCS),[],tpDim);
end
if ~strcmp(WM,'NONE') && ~strcmp(CSF,'NONE')
    WMCSFCleanedBOLDVar = var((WMCSFCleanedTCS - UnstructNoiseTCS),[],tpDim);
end

% Generate "grayplots" of the various stages and differences between stages using a 
% scaling in "MR units"
if ~strcmp(WM,'NONE') && ~strcmp(CSF,'NONE')
    steps = {'OrigTCS','HighPassTCS','PostMotionTCS','CleanedTCS',...
        'UnstructNoiseTCS','WMCleanedTCS','CSFCleanedTCS','WMCSFCleanedTCS','StructNoiseTCS'};
    plotgray(OrigTCS,mvm,OrigMGT,WMtcOrig,CSFtcOrig,[outprefix '_1_' steps{1}]); %Original data with unstructured noise
    plotgray(OrigTCS-UnstructNoiseTCS,mvm,OrigMGT,WMtcOrig,CSFtcOrig,[outprefix '_1-5_' steps{1} '-' steps{5}]); %Original data without unstructured noise
    plotgray(OrigTCS-HighPassTCS,mvm,OrigMGT-HighPassMGT,WMtcOrig-WMtcHP,CSFtcOrig-CSFtcHP,[outprefix '_1-2_' steps{1} '-' steps{2}]); %Effect of highpass filter
    plotgray(HighPassTCS,mvm,HighPassMGT,WMtcHP,CSFtcHP,[outprefix '_2_' steps{2}]); %HP with unstructured noise
    plotgray(HighPassTCS-UnstructNoiseTCS,mvm,HighPassMGT,WMtcHP,CSFtcHP,[outprefix '_2-5_' steps{2} '-' steps{5}]); %HP without unstructured noise
    plotgray(HighPassTCS-PostMotionTCS,mvm,HighPassMGT-PostMotionMGT,WMtcHP-WMtcPM,CSFtcHP-CSFtcPM,[outprefix '_2-3_' steps{2} '-' steps{3}]); %Effect of motion regression 
    plotgray(PostMotionTCS,mvm,PostMotionMGT,WMtcPM,CSFtcPM,[outprefix '_3_' steps{3}]); %Motion Regression with unstructured noise
    plotgray(PostMotionTCS-UnstructNoiseTCS,mvm,PostMotionMGT,WMtcPM,CSFtcPM,[outprefix '_3-5_' steps{3} '-' steps{5}]); %Motion Regression without unstructured noise
    plotgray(PostMotionTCS-CleanedTCS,mvm,PostMotionMGT-CleanedMGT,WMtcPM-WMtcClean,CSFtcPM-CSFtcClean,[outprefix '_3-4_' steps{3} '-' steps{4}]); %Effect of structured noise regression 
    plotgray(CleanedTCS,mvm,CleanedMGT,WMtcClean,CSFtcClean,[outprefix '_4_' steps{4}]); %Cleaned data with unstructured noise
    plotgray(CleanedTCS-UnstructNoiseTCS,mvm,CleanedMGT,WMtcClean,CSFtcClean,[outprefix '_4-5_' steps{4} '-' steps{5}]); %Cleaned data without unstructured noise
    plotgray(UnstructNoiseTCS,mvm,UnstructNoiseMGT,WMtcUnstructNoise,CSFtcUnstructNoise,[outprefix '_5_' steps{5}]); %Unstructured noise only
    plotgray(WMCleanedTCS,mvm,WMCleanedMGT,WMWM,CSFWM,[outprefix '_6_' steps{6}]); %WM regressed data with unstructured noise
    plotgray(WMCleanedTCS-UnstructNoiseTCS,mvm,WMCleanedMGT,WMWM,CSFWM,[outprefix '_6-5_' steps{6} '-' steps{5}]); %WM regressed data without unstructured noise
    plotgray(CleanedTCS-WMCleanedTCS,mvm,CleanedMGT-WMCleanedMGT,WMtcClean-WMWM,CSFtcClean-CSFWM,[outprefix '_4-6_' steps{4} '-' steps{6}]); %Effect of WM regression
    plotgray(CSFCleanedTCS,mvm,CSFCleanedMGT,WMCSF,CSFCSF,[outprefix '_7_' steps{7}]); %WM regressed data with unstructured noise
    plotgray(CSFCleanedTCS-UnstructNoiseTCS,mvm,CSFCleanedMGT,WMCSF,CSFCSF,[outprefix '_7-5_' steps{7} '-' steps{5}]); %WM regressed data without unstructured noise
    plotgray(CleanedTCS-CSFCleanedTCS,mvm,CleanedMGT-CSFCleanedMGT,WMtcClean-WMCSF,CSFtcClean-CSFCSF,[outprefix '_4-7_' steps{4} '-' steps{7}]); %Effect of CSF regression
    plotgray(WMCSFCleanedTCS,mvm,WMCSFCleanedMGT,WMWM,CSFCSF,[outprefix '_8_' steps{8}]); %WM regressed data with unstructured noise
    plotgray(WMCSFCleanedTCS-UnstructNoiseTCS,mvm,WMCSFCleanedMGT,WMWM,CSFCSF,[outprefix '_8-5_' steps{8} '-' steps{5}]); %WM regressed data without unstructured noise
    plotgray(CleanedTCS-WMCSFCleanedTCS,mvm,CleanedMGT-WMCSFCleanedMGT,WMtcClean-WMWM,CSFtcClean-CSFCSF,[outprefix '_4-8_' steps{4} '-' steps{8}]); %Effect of CSF regression
    plotgray(StructNoiseTCS,mvm,StructNoiseMGT,WMtcStructNoise,CSFtcStructNoise,[outprefix '_9_' steps{9}]); %Structured noise only
end

% Generate "grayplots" of the various stages and differences between stages using a 
% scaling in z-score
if ~strcmp(WM,'NONE') && ~strcmp(CSF,'NONE')
    steps = {'OrigTCS','HighPassTCS','PostMotionTCS','CleanedTCS',...
        'UnstructNoiseTCS','WMCleanedTCS','CSFCleanedTCS','WMCSFCleanedTCS','StructNoiseTCS'};
    plotgrayz(OrigTCS,mvm,OrigMGT,WMtcOrig,CSFtcOrig,[outprefix '_1_' steps{1}]); %Original data with unstructured noise
    plotgrayz(OrigTCS-UnstructNoiseTCS,mvm,OrigMGT,WMtcOrig,CSFtcOrig,[outprefix '_1-5_' steps{1} '-' steps{5}]); %Original data without unstructured noise
    plotgrayz(OrigTCS-HighPassTCS,mvm,OrigMGT-HighPassMGT,WMtcOrig-WMtcHP,CSFtcOrig-CSFtcHP,[outprefix '_1-2_' steps{1} '-' steps{2}]); %Effect of highpass filter
    plotgrayz(HighPassTCS,mvm,HighPassMGT,WMtcHP,CSFtcHP,[outprefix '_2_' steps{2}]); %HP with unstructured noise
    plotgrayz(HighPassTCS-UnstructNoiseTCS,mvm,HighPassMGT,WMtcHP,CSFtcHP,[outprefix '_2-5_' steps{2} '-' steps{5}]); %HP without unstructured noise
    plotgrayz(HighPassTCS-PostMotionTCS,mvm,HighPassMGT-PostMotionMGT,WMtcHP-WMtcPM,CSFtcHP-CSFtcPM,[outprefix '_2-3_' steps{2} '-' steps{3}]); %Effect of motion regression 
    plotgrayz(PostMotionTCS,mvm,PostMotionMGT,WMtcPM,CSFtcPM,[outprefix '_3_' steps{3}]); %Motion Regression with unstructured noise
    plotgrayz(PostMotionTCS-UnstructNoiseTCS,mvm,PostMotionMGT,WMtcPM,CSFtcPM,[outprefix '_3-5_' steps{3} '-' steps{5}]); %Motion Regression without unstructured noise
    plotgrayz(PostMotionTCS-CleanedTCS,mvm,PostMotionMGT-CleanedMGT,WMtcPM-WMtcClean,CSFtcPM-CSFtcClean,[outprefix '_3-4_' steps{3} '-' steps{4}]); %Effect of structured noise regression 
    plotgrayz(CleanedTCS,mvm,CleanedMGT,WMtcClean,CSFtcClean,[outprefix '_4_' steps{4}]); %Cleaned data with unstructured noise
    plotgrayz(CleanedTCS-UnstructNoiseTCS,mvm,CleanedMGT,WMtcClean,CSFtcClean,[outprefix '_4-5_' steps{4} '-' steps{5}]); %Cleaned data without unstructured noise
    plotgrayz(UnstructNoiseTCS,mvm,UnstructNoiseMGT,WMtcUnstructNoise,CSFtcUnstructNoise,[outprefix '_5_' steps{5}]); %Unstructured noise only
    plotgrayz(WMCleanedTCS,mvm,WMCleanedMGT,WMWM,CSFWM,[outprefix '_6_' steps{6}]); %WM regressed data with unstructured noise
    plotgrayz(WMCleanedTCS-UnstructNoiseTCS,mvm,WMCleanedMGT,WMWM,CSFWM,[outprefix '_6-5_' steps{6} '-' steps{5}]); %WM regressed data without unstructured noise
    plotgrayz(CleanedTCS-WMCleanedTCS,mvm,CleanedMGT-WMCleanedMGT,WMtcClean-WMWM,CSFtcClean-CSFWM,[outprefix '_4-6_' steps{4} '-' steps{6}]); %Effect of WM regression
    plotgrayz(CSFCleanedTCS,mvm,CSFCleanedMGT,WMCSF,CSFCSF,[outprefix '_7_' steps{7}]); %WM regressed data with unstructured noise
    plotgrayz(CSFCleanedTCS-UnstructNoiseTCS,mvm,CSFCleanedMGT,WMCSF,CSFCSF,[outprefix '_7-5_' steps{7} '-' steps{5}]); %WM regressed data without unstructured noise
    plotgrayz(CleanedTCS-CSFCleanedTCS,mvm,CleanedMGT-CSFCleanedMGT,WMtcClean-WMCSF,CSFtcClean-CSFCSF,[outprefix '_4-7_' steps{4} '-' steps{7}]); %Effect of CSF regression
    plotgrayz(WMCSFCleanedTCS,mvm,WMCSFCleanedMGT,WMWM,CSFCSF,[outprefix '_8_' steps{8}]); %WM regressed data with unstructured noise
    plotgrayz(WMCSFCleanedTCS-UnstructNoiseTCS,mvm,WMCSFCleanedMGT,WMWM,CSFCSF,[outprefix '_8-5_' steps{8} '-' steps{5}]); %WM regressed data without unstructured noise
    plotgrayz(CleanedTCS-WMCSFCleanedTCS,mvm,CleanedMGT-WMCSFCleanedMGT,WMtcClean-WMWM,CSFtcClean-CSFCSF,[outprefix '_4-8_' steps{4} '-' steps{8}]); %Effect of CSF regression
    plotgrayz(StructNoiseTCS,mvm,StructNoiseMGT,WMtcStructNoise,CSFtcStructNoise,[outprefix '_9_' steps{9}]); %Structured noise only
end

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
UnstructNoiseMGTVarRatio = makeRatio(UnstructNoiseMGTVar,OrigVar);
NoiseMGTVarRatio = makeRatio(NoiseMGTVar,OrigVar);
CleanedMGTVarVsBOLDVarRatio = makeRatio(CleanedMGTVar,BOLDVar);
if ~strcmp(WM,'NONE')
    WMVarVsBOLDVarRatio = makeRatio(WMVar,BOLDVar);
    WMCleanedMGTVarVsWMCleanedBOLDVarRatio = makeRatio(WMCleanedMGTVar,WMCleanedBOLDVar);    
end
if ~strcmp(CSF,'NONE')
    CSFVarVsBOLDVarRatio = makeRatio(CSFVar,BOLDVar);
    CSFCleanedMGTVarVsCSFCleanedBOLDVarRatio = makeRatio(CSFCleanedMGTVar,CSFCleanedBOLDVar);    
end
if ~strcmp(WM,'NONE') && ~strcmp(CSF,'NONE')
    WMCSFVarVsBOLDVarRatio = makeRatio(WMCSFVar,BOLDVar);
    WMCSFCleanedMGTVarVsWMCSFCleanedBOLDVarRatio = makeRatio(WMCSFCleanedMGTVar,WMCSFCleanedBOLDVar);    
end

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
meanUnstructNoiseMGTVar = mean(UnstructNoiseMGTVar);
meanNoiseMGTVar = mean(NoiseMGTVar);
meanOrigMGTbeta = mean(OrigMGTbeta);
meanHighPassMGTbeta = mean(HighPassMGTbeta);
meanPostMotionMGTbeta = mean(PostMotionMGTbeta);
meanCleanedMGTbeta = mean(CleanedMGTbeta);
meanUnstructNoiseMGTbeta = mean(UnstructNoiseMGTbeta);
meanNoiseMGTbeta = mean(NoiseMGTbeta);
meanHighPassVarRatio = mean(HighPassVarRatio);
meanMotionVarRatio = mean(MotionVarRatio);
meanStructNoiseVarRatio = mean(StructNoiseVarRatio);
meanBOLDVarRatio = mean(BOLDVarRatio);
meanUnstructNoiseVarRatio = mean(UnstructNoiseVarRatio);
meanOrigMGTVarRatio = mean(OrigMGTVarRatio);
meanHighPassMGTVarRatio = mean(HighPassMGTVarRatio);
meanMotionMGTVarRatio = mean(MotionMGTVarRatio);
meanCleanedMGTVarRatio = mean(CleanedMGTVarRatio);
meanUnstructNoiseMGTVarRatio = mean(UnstructNoiseMGTVarRatio);
meanNoiseMGTVarRatio = mean(NoiseMGTVarRatio);
meanCleanedMGTVarVsBOLDVarRatio=mean(CleanedMGTVarVsBOLDVarRatio);
meanOrigMGTrsq = mean(OrigMGTrsq);
meanHighPassMGTrsq = mean(HighPassMGTrsq);
meanPostMotionMGTrsq = mean(PostMotionMGTrsq);
meanCleanedMGTrsq = mean(CleanedMGTrsq);
meanUnstructNoiseMGTrsq = mean(UnstructNoiseMGTrsq);
meanNoiseMGTrsq = mean(NoiseMGTrsq);
if ~strcmp(WM,'NONE')
    meanWMbetaICA = mean(betaWM);
    meanWMVar = mean(WMVar);
    meanWMVarVsBOLDVarRatio = mean(WMVarVsBOLDVarRatio);
    meanWMCleanedBOLDVar = mean(WMCleanedBOLDVar);
    meanWMCleanedMGTbeta = mean(WMCleanedMGTbeta);
    meanWMCleanedMGTVar = mean(WMCleanedMGTVar);
    meanWMCleanedMGTVarVsWMCleanedBOLDVarRatio = mean(WMCleanedMGTVarVsWMCleanedBOLDVarRatio);
end
if ~strcmp(CSF,'NONE')
    meanCSFbetaICA = mean(betaCSF);
    meanCSFVar = mean(CSFVar);
    meanCSFVarVsBOLDVarRatio = mean(CSFVarVsBOLDVarRatio);
    meanCSFCleanedBOLDVar = mean(CSFCleanedBOLDVar);
    meanCSFCleanedMGTbeta = mean(CSFCleanedMGTbeta);
    meanCSFCleanedMGTVar = mean(CSFCleanedMGTVar);
    meanCSFCleanedMGTVarVsCSFCleanedBOLDVarRatio = mean(CSFCleanedMGTVarVsCSFCleanedBOLDVarRatio);
end
if ~strcmp(WM,'NONE') && ~strcmp(CSF,'NONE')
    meanWMCSFbetaICA = mean(betaWMCSF'); %Because there are two entries this has to be transposted
    meanWMCSFVar = mean(WMCSFVar);
    meanWMCSFVarVsBOLDVarRatio = mean(WMCSFVarVsBOLDVarRatio);
    meanWMCSFCleanedBOLDVar = mean(WMCSFCleanedBOLDVar);
    meanWMCSFCleanedMGTbeta = mean(WMCSFCleanedMGTbeta);
    meanWMCSFCleanedMGTVar = mean(WMCSFCleanedMGTVar);
    meanWMCSFCleanedMGTVarVsWMCSFCleanedBOLDVarRatio = mean(WMCSFCleanedMGTVarVsWMCSFCleanedBOLDVarRatio);
end

% Save out variance normalization image for MSMALL/SingleSubjectConcat/MIGP
if SaveVarianceNormalizationImage
  fprintf('%s - Saving variance normalization image [i.e., sqrt(UnstructNoiseVar)]\n',func_name);
  VarianceNormalizationImage=BO;
  VarianceNormalizationImage.cdata=sqrt(UnstructNoiseVar);
  if FixVN == 1
    VarianceNormalizationImage.cdata=VarianceNormalizationImage.cdata.*real_bias.cdata;
  end
  ciftisavereset(VarianceNormalizationImage,[outprefix '_vn_RSS.dscalar.nii'],WBC);
end

% Save out grayordinate maps of a number of variables
if SaveGrayOrdinateMaps
  fprintf('%s - Saving grayordinate maps\n',func_name);
  statscifti = BO;
  statscifti.cdata = [MEAN STD COV TSNR OrigVar HighPassVar MotionVar StructNoiseVar BOLDVar UnstructNoiseVar TotalSharedVar CNR OrigMGTVar HighPassMGTVar PostMotionMGTVar CleanedMGTVar OrigMGTbeta HighPassMGTbeta PostMotionMGTbeta CleanedMGTbeta HighPassVarRatio MotionVarRatio StructNoiseVarRatio BOLDVarRatio UnstructNoiseVarRatio OrigMGTVarRatio HighPassMGTVarRatio MotionMGTVarRatio CleanedMGTVarRatio CleanedMGTVarVsBOLDVarRatio OrigMGTrsq HighPassMGTrsq PostMotionMGTrsq CleanedMGTrsq];
  if SaveExtraVar
    statscifti.cdata = cat(2,statscifti.cdata,[UnstructNoiseMGTbeta UnstructNoiseMGTVar UnstructNoiseMGTVarRatio UnstructNoiseMGTrsq NoiseMGTbeta NoiseMGTVar NoiseMGTVarRatio NoiseMGTrsq]);
  end
  if ~strcmp(WM,'NONE')
    statscifti.cdata = cat(2,statscifti.cdata,[betaWM' WMVar WMVarVsBOLDVarRatio WMCleanedBOLDVar WMCleanedMGTbeta WMCleanedMGTVar WMCleanedMGTVarVsWMCleanedBOLDVarRatio]);
  end
  if ~strcmp(CSF,'NONE')
    statscifti.cdata = cat(2,statscifti.cdata,[betaCSF' CSFVar CSFVarVsBOLDVarRatio CSFCleanedBOLDVar CSFCleanedMGTbeta CSFCleanedMGTVar CSFCleanedMGTVarVsCSFCleanedBOLDVarRatio]);
  end
  if ~strcmp(WM,'NONE') && ~strcmp(CSF,'NONE')
    statscifti.cdata = cat(2,statscifti.cdata,[betaWMCSF(1,:)' betaWMCSF(2,:)' WMCSFVar WMCSFVarVsBOLDVarRatio WMCSFCleanedBOLDVar WMCSFCleanedMGTbeta WMCSFCleanedMGTVar WMCSFCleanedMGTVarVsWMCSFCleanedBOLDVarRatio]);  
  end
  ciftisave(statscifti,[outprefix '_' outstring '.dtseries.nii'],WBC);
end

% Save out parcellated time series
if ~isempty(dlabel)
  fprintf('%s - Saving parcellated time series from each stage\n',func_name);
  
  % Generate a ptseries.nii using provided dlabel file using -cifti-parcellate,
  % which we'll need as a CIFTI ptseries template
  ciftiIn = [inputdtseries '.dtseries.nii'];
  ciftiOut = [outprefix '_template.ptseries.nii'];
  unix([WBC ' -cifti-parcellate ' ciftiIn ' ' dlabel ' COLUMN ' ciftiOut]);
  
  ptTemplate = ciftiopen(ciftiOut,WBC);

  % Parcellated time series from each stage
  savePTCS(OrigTCS,dlabel,outprefix,'Orig',ptTemplate,WBC);
  savePTCS(HighPassTCS,dlabel,outprefix,'HighPass',ptTemplate,WBC);
  savePTCS(PostMotionTCS,dlabel,outprefix,'PostMotion',ptTemplate,WBC);
  savePTCS(CleanedTCS,dlabel,outprefix,'Cleaned',ptTemplate,WBC);
  savePTCS(UnstructNoiseTCS,dlabel,outprefix,'UnstructNoise',ptTemplate,WBC);
  savePTCS(NoiseTCS,dlabel,outprefix,'Noise',ptTemplate,WBC);

  % Parcellated "MGT" regressed time series from each stage
  savePTCS(OrigMGTRtcs,dlabel,outprefix,'OrigMGTR',ptTemplate,WBC);
  savePTCS(HighPassMGTRtcs,dlabel,outprefix,'HighPassMGTR',ptTemplate,WBC);
  savePTCS(PostMotionMGTRtcs,dlabel,outprefix,'PostMotionMGTR',ptTemplate,WBC);
  savePTCS(CleanedMGTRtcs,dlabel,outprefix,'CleanedMGTR',ptTemplate,WBC);
  savePTCS(UnstructNoiseMGTRtcs,dlabel,outprefix,'UnstructNoiseMGTR',ptTemplate,WBC);
  savePTCS(NoiseMGTRtcs,dlabel,outprefix,'NoiseMGTR',ptTemplate,WBC);
end

if SaveMGT
  dlmwrite([outprefix '_OrigMGT.txt'],OrigMGT);
  dlmwrite([outprefix '_HighPassMGT.txt'],HighPassMGT);
  dlmwrite([outprefix '_PostMotionMGT.txt'],PostMotionMGT);
  dlmwrite([outprefix '_CleanedMGT.txt'],CleanedMGT);
  dlmwrite([outprefix '_UnstructNoiseMGT.txt'],UnstructNoiseMGT);
  dlmwrite([outprefix '_NoiseMGT.txt'],NoiseMGT);
end

dlmwrite([outprefix '_CleanedMGT.txt'],CleanedMGT);
if ~strcmp(WM,'NONE')
    dlmwrite([outprefix '_CleanedWMtc.txt'],WMtcClean);
end
if ~strcmp(CSF,'NONE')
    dlmwrite([outprefix '_CleanedCSFtc.txt'],CSFtcClean);
end

% Write out stats file
% (Make sure to keep varNames in correspondence with the order that
% variables are written out!)
varNames = 'TCSName,NumSignal,NumNoise,NumTotal,MEAN,STD,COV,TSNR,OrigVar,HighPassVar,MotionVar,StructNoiseVar,BOLDVar,UnstructNoiseVar,TotalSharedVar,CNR,OrigMGTVar,HighPassMGTVar,PostMotionMGTVar,CleanedMGTVar,OrigMGTbeta,HighPassMGTbeta,PostMotionMGTbeta,CleanedMGTbeta,HighPassVarRatio,MotionVarRatio,StructNoiseVarRatio,BOLDVarRatio,UnstructNoiseVarRatio,OrigMGTVarRatio,HighPassMGTVarRatio,PostMotionMGTVarRatio,CleanedMGTVarRatio,CleanedMGTVarVsBOLDVarRatio,OrigMGTrsq,HighPassMGTrsq,PostMotionMGTrsq,CleanedMGTrsq';
if SaveExtraVar
  extraVarStr = 'UnstructNoiseMGTbeta,UnstructNoiseMGTVar,UnstructNoiseMGTVarRatio,UnstructNoiseMGTrsq,NoiseMGTbeta,NoiseMGTVar,NoiseMGTVarRatio,NoiseMGTrsq';
  varNames = sprintf('%s,%s',varNames,extraVarStr);
end

if ~strcmp(WM,'NONE')
  WMStr = 'WMbeta,WMVar,WMVarVsBOLDVarRatio,WMCleanedBOLDVar,WMCleanedMGTbeta,WMCleanedMGTVar,WMCleanedMGTVarVsWMCleanedBOLDVarRatio';
  varNames = sprintf('%s,%s',varNames,WMStr);
end

if ~strcmp(CSF,'NONE')
  CSFStr = 'CSFbeta,CSFVar,CSFVarVsBOLDVarRatio,CSFCleanedBOLDVar,CSFCleanedMGTbeta,CSFCleanedMGTVar,CSFCleanedMGTVarVsCSFCleanedBOLDVarRatio';
  varNames = sprintf('%s,%s',varNames,CSFStr);
end

if ~strcmp(WM,'NONE') && ~strcmp(CSF,'NONE')
  WMCSFStr = 'WMCSFbetaWM,WMCSFbetaCSF,WMCSFVar,WMCSFVarVsBOLDVarRatio,WMCSFCleanedBOLDVar,WMCSFCleanedMGTbeta,WMCSFCleanedMGTVar,WMCSFCleanedMGTVarVsWMCSFCleanedBOLDVarRatio';
  varNames = sprintf('%s,%s',varNames,WMCSFStr);
end    
    
fid = fopen([outprefix '_' outstring '.txt'],'w');
fprintf(fid,'%s\n',varNames);
fprintf(fid,'%s,%d,%d,%d',inputdtseries,length(Isignal),length(Inoise),length(Isignal)+length(Inoise));
fprintf(fid,',%.2f,%.2f,%.4f,%.2f',meanMEAN,meanSTD,meanCOV,meanTSNR);
fprintf(fid,',%.2f,%.2f,%.2f,%.2f',meanOrigVar,meanHighPassVar,meanMotionVar,meanStructNoiseVar);
fprintf(fid,',%.2f,%.2f,%.4f,%.4f',meanBOLDVar,meanUnstructNoiseVar,meanTotalSharedVar,meanCNR);
fprintf(fid,',%.2f,%.2f,%.2f,%.2f',meanOrigMGTVar,meanHighPassMGTVar,meanPostMotionMGTVar,meanCleanedMGTVar);
fprintf(fid,',%.3f,%.3f,%.3f,%.3f',meanOrigMGTbeta,meanHighPassMGTbeta,meanPostMotionMGTbeta,meanCleanedMGTbeta);
fprintf(fid,',%.5f,%.5f,%.5f,%.5f',meanHighPassVarRatio,meanMotionVarRatio,meanStructNoiseVarRatio,meanBOLDVarRatio);
fprintf(fid,',%.5f,%.5f,%.5f',meanUnstructNoiseVarRatio,meanOrigMGTVarRatio,meanHighPassMGTVarRatio);
fprintf(fid,',%.5f,%.5f',meanMotionMGTVarRatio,meanCleanedMGTVarRatio);
fprintf(fid,',%.5f',meanCleanedMGTVarVsBOLDVarRatio);
fprintf(fid,',%.5f,%.5f,%.5f,%.5f',meanOrigMGTrsq,meanHighPassMGTrsq,meanPostMotionMGTrsq,meanCleanedMGTrsq);
if SaveExtraVar
  fprintf(fid,',%.3f,%.2f,%.5f,%.5f',meanUnstructNoiseMGTbeta,meanUnstructNoiseMGTVar,meanUnstructNoiseMGTVarRatio,meanUnstructNoiseMGTrsq);
  fprintf(fid,',%.3f,%.2f,%.5f,%.5f',meanNoiseMGTbeta,meanNoiseMGTVar,meanNoiseMGTVarRatio,meanNoiseMGTrsq);
end
if ~strcmp(WM,'NONE')
    fprintf(fid,',%.3f,%.2f,%.5f,%.2f,%.3f,%.2f,%.5f',meanWMbetaICA,meanWMVar,meanWMVarVsBOLDVarRatio,meanWMCleanedBOLDVar,meanWMCleanedMGTbeta,meanWMCleanedMGTVar,meanWMCleanedMGTVarVsWMCleanedBOLDVarRatio);
end
if ~strcmp(CSF,'NONE')
    fprintf(fid,',%.3f,%.2f,%.5f,%.2f,%.3f,%.2f,%.5f',meanCSFbetaICA,meanCSFVar,meanCSFVarVsBOLDVarRatio,meanCSFCleanedBOLDVar,meanCSFCleanedMGTbeta,meanCSFCleanedMGTVar,meanCSFCleanedMGTVarVsCSFCleanedBOLDVarRatio);
end
if ~strcmp(WM,'NONE') && ~strcmp(CSF,'NONE')
    fprintf(fid,',%.3f,%.3f,%.2f,%.5f,%.2f,%.3f,%.2f,%.5f',meanWMCSFbetaICA(1),meanWMCSFbetaICA(2),meanWMCSFVar,meanWMCSFVarVsBOLDVarRatio,meanWMCSFCleanedBOLDVar,meanWMCSFCleanedMGTbeta,meanWMCSFCleanedMGTVar,meanWMCSFCleanedMGTVarVsWMCSFCleanedBOLDVarRatio);
end
fprintf(fid,'\n');
end


%%%% HELPER FUNCTIONS %%%%

%% MGTR is a function that takes time courses as input and returns
% MGT: mean grayordinate time series
% MGTRtcs: residual time series after regressing out MGT
% MGTbeta: spatial map of the beta of the regression of MGT onto the
%          input time courses
% MGTVar: spatial map of the variance attributable to MGT
% MGTrsq: spatial map of the R^2 (fit) of the MGT regression to the input tcs
%
% Note that the input 'tcs' is not demeaned, nor does the regression 
% include an intercept. However, because the MGT regressor is demeaned 
% prior to the regression, the ensuing MGTbeta isn't impacted by any 
% mean that is present in the input tcs.
function [MGTRtcs,MGT,MGTbeta,MGTVar,MGTrsq] = MGTR(tcs)
    MGT = demean(mean(tcs,1))';
    MGTbeta = pinv(MGT,1e-6) * tcs';
    MGTRtcs = tcs - (MGT * MGTbeta)';
    MGTVar = var((tcs - MGTRtcs),[],2);
    MGTbeta = MGTbeta';
    
    % compute the R^2 of the MGT to grayordinates
    % Use 'var' as convenient mechanism to ensure that the mean is 
    % removed prior to computation
    SSresid = var(MGTRtcs,[],2);
    SStotal = var(tcs,[],2);
    MGTrsq = 1 - (SSresid./SStotal);
    % Set any instances of Inf or Nan in rsq to zero
    ind = (~isfinite(MGTrsq));
    MGTrsq(ind) = 0;
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
    ind = (label.cdata == i);
    ptseries(i,:) = mean(tcs(ind,:));
  end;
  
  ptseriesOut = ptTemplate;  % Initialize as a CIFTI structure
  ptseriesOut.cdata = ptseries;  % Change the data
  % Write it out
  ciftisave(ptseriesOut,[basename '_' saveString '.ptseries.nii'],wbcommand);
end


%%  PLOTGRAY plots the global signal, DVARS grayordinate plot
function plotgray(img,mvm,GS,WM,CSF,step) 
% Make a plot in the [fore/back]ground of FD, DVARS (@ stage),
% Gray(ordinate) plot and tmask across timecourse.

% Calculate FD
FD = sum(abs(cat(2,mvm(:,7:9),(50*pi/180)*mvm(:,10:12))),2);

% Calculate DVARS (RMS of the backward difference
DV = diff(transpose(img)); % Backward Difference
MedDV=median(rms(DV,2));
DV = rms(DV,2)-MedDV; % RMS (w/ median centering)
DV = [0;DV]; % Zero-pad to original timepoints

tp = numel(DV);
fr = transpose(1:tp);
STD=mean(std(img,[],2));
normimg = transpose(zscore(transpose(img)))*STD; %Use local normalization instead of global normalization to keep different plots comparable

CSF=(CSF/std(CSF)) * max([std(GS) std(WM)]); %Make CSF scaling more reasonable

% Basic order of plot: FD, DVARS, MGT+WM+CSF timecourse and
% gray(ordinate) graph.

% Close images, and define colormap as "jet" (R2015a and after use
% "parula")
close all;
figure('Visible','off'); %%%
set(gcf,'Units','points');
set(gcf,'Position',[3 6 tp+264 25+tp+25+216+25+216+25+216+25]);
set(gcf,'PaperPosition',[0.25 2.5 (tp+264)/72 (25+tp+25+216+25+216+25+216+25)/72]);
%colormap(jet);

% Plot FD trace
subplot(4,1,1); plot(fr,FD,'r');
ax = subplot(4,1,1);
set(ax,'Units','points','YTick',[0 0.5 1],'YTickLabel',...
    {'0','0.5','1'},'Ylim',[0 1],'FontSize',8);
set(ax,'Position',[60 25+tp+25+216+25+216+25 tp 216]);
set(ax,'XTick',[],'XTickLabel',''); xlim([1 tp]);
set(get(gca,'YLabel'),'String','FD','FontSize',12);

% Plot DV traces
subplot(4,1,2); plot(fr,DV,'b');
ax = subplot(4,1,2);
set(ax,'Units','points','YTick',[-20 0 30 80],'YTickLabel',...
    {'-20','0','30','80'},'Ylim',[-20 80],'FontSize',8);
set(ax,'Position',[60 25+tp+25+216+25 tp 216]);
set(ax,'XTick',[],'XTickLabel',''); xlim([1 tp]);
set(get(gca,'YLabel'),'String',['DV, Median:' num2str(MedDV,'%.1f')],'FontSize',12);

% Plot MGT+WM+CSF traces
subplot(4,1,3); plot(fr,CSF,'m'); hold on; plot(fr,WM,'c'); plot(fr,GS,'k');
ax = subplot(4,1,3);
set(ax,'Units','points','YTick',[-100 -50 0 50 100],'YTickLabel',...
    {'-100','-50','0','50','100'},'Ylim',[-100 100],'FontSize',8);
set(ax,'Position',[60 25+tp+25 tp 216]);
set(ax,'XTick',[],'XTickLabel',''); xlim([1 tp]);
set(get(gca,'YLabel'),'String','MGT (black), WM (cyan), CSF (magenta)','FontSize',10);

CLIM=[-200 200]; %2% of mean 10000 scaled image intensity variations

% Sub-grayplot the Left/Right/Subcortex (or volume gray ribbon if NIFTI)
subplot(4,1,4), imagesc(normimg,CLIM), colormap(gray); %colormap(bone2);
ax = subplot(4,1,4);
set(ax,'Units','points');
set(ax,'Position',[60 25 tp+52 tp]); %+52 is offset for color bar
set(ax,'XTick',[],'XTickLabel',''); xlim([1 tp]); %caxis([-2 2]); 
set(get(gca,'YLabel'),'String','Grayordinates');

XTicks = round(linspace(0,size(img,2),7));
XTicksPts = XTicks;
XTicksPts(1) = XTicks(1)+0.5;
XTicksPts(end) = XTicks(end)-0.5;

for i = 1:numel(XTicks)
    XTickString{i} = num2str(XTicks(i)); %#ok<AGROW>
end;

set(ax,'XTick',XTicksPts,'XTickLabel',XTickString,'TickLength',[0 0]);

%Make "%BOLD" color bar
colorticks=[(CLIM(1)-(CLIM(2)*0)/4) (CLIM(1)-(CLIM(1)*1)/4) (CLIM(1)-(CLIM(1)*2)/4) (CLIM(1)-(CLIM(1)*3)/4) 0 (CLIM(2)-(CLIM(2)*3)/4) (CLIM(2)-(CLIM(2)*2)/4) (CLIM(2)-(CLIM(2)*1)/4) (CLIM(2)-(CLIM(2)*0)/4)];
colorticks=(round((colorticks)))/100; %Round z scores to nearest hundreth
colortickscell={[num2str(colorticks(1)) '%'];[num2str(colorticks(2)) '%'];[num2str(colorticks(3)) '%'];[num2str(colorticks(4)) '%'];[num2str(colorticks(5)) '%'];[num2str(colorticks(6)) '%'];[num2str(colorticks(7)) '%'];[num2str(colorticks(8)) '%'];[num2str(colorticks(9)) '%']};
colorbar('YTickMode','manual','YTick',colorticks,'YTickLabel',colortickscell,'location','eastoutside','Ylim',[CLIM(1) CLIM(2)],'Units','points','FontSize',8); %Color bar refused to work with anything other than 9 ticks

% Save plot

print([step '_QC_Summary_Plot'],'-dpng','-r72'); %close; %%%
end


%%  PLOTGRAY plots the global signal, DVARS grayordinate plot
function plotgrayz(img,mvm,GS,WM,CSF,step) 
% Make a plot in the [fore/back]ground of FD, DVARS (@ stage),
% Gray(ordinate) plot and tmask across timecourse.

% Calculate FD
FD = sum(abs(cat(2,mvm(:,7:9),(50*pi/180)*mvm(:,10:12))),2);

% Calculate DVARS (RMS of the backward difference
DV = diff(transpose(img)); % Backward Difference
MedDV=median(rms(DV,2));
DV = rms(DV,2)-MedDV; % RMS (w/ median centering)
DV = [0;DV]; % Zero-pad to original timepoints

tp = numel(DV);
fr = transpose(1:tp);
STD=mean(std(img,[],2)); %#ok<NASGU>
normimg = transpose(zscore(transpose(img))); 

CSF=(CSF/std(CSF)) * max([std(GS) std(WM)]); %Make CSF scaling more reasonable

% Basic order of plot: FD, DVARS, MGT+WM+CSF timecourse and
% gray(ordinate) graph.

% Close images, and define colormap as "jet" (R2015a and after use
% "parula")
close all;
figure('Visible','off'); %%%
set(gcf,'Units','points');
set(gcf,'Position',[3 6 tp+264 25+tp+25+216+25+216+25+216+25]);
set(gcf,'PaperPosition',[0.25 2.5 (tp+264)/72 (25+tp+25+216+25+216+25+216+25)/72]);
%colormap(jet);

% Plot FD trace
subplot(4,1,1); plot(fr,FD,'r');
ax = subplot(4,1,1);
set(ax,'Units','points','YTick',[0 0.5 1],'YTickLabel',...
    {'0','0.5','1'},'Ylim',[0 1],'FontSize',8);
set(ax,'Position',[60 25+tp+25+216+25+216+25 tp 216]);
set(ax,'XTick',[],'XTickLabel',''); xlim([1 tp]);
set(get(gca,'YLabel'),'String','FD','FontSize',12);

% Plot DV traces
subplot(4,1,2); plot(fr,DV,'b');
ax = subplot(4,1,2);
set(ax,'Units','points','YTick',[-20 0 30 80],'YTickLabel',...
    {'-20','0','30','80'},'Ylim',[-20 80],'FontSize',8);
set(ax,'Position',[60 25+tp+25+216+25 tp 216]);
set(ax,'XTick',[],'XTickLabel',''); xlim([1 tp]);
set(get(gca,'YLabel'),'String',['DV, Median:' num2str(MedDV,'%.1f')],'FontSize',12);

% Plot MGT+WM+CSF traces
subplot(4,1,3); plot(fr,CSF,'m'); hold on; plot(fr,WM,'c'); plot(fr,GS,'k');
ax = subplot(4,1,3);
set(ax,'Units','points','YTick',[-100 -50 0 50 100],'YTickLabel',...
    {'-100','-50','0','50','100'},'Ylim',[-100 100],'FontSize',8);
set(ax,'Position',[60 25+tp+25 tp 216]);
set(ax,'XTick',[],'XTickLabel',''); xlim([1 tp]);
set(get(gca,'YLabel'),'String','MGT (black), WM (cyan), CSF (magenta)','FontSize',10);

CLIM=[-2 2]; % +/- 2 STD from the mean (per grayordinate)

% Sub-grayplot the Left/Right/Subcortex (or volume gray ribbon if NIFTI)
subplot(4,1,4), imagesc(normimg,CLIM), colormap(gray); %colormap(bone2);
ax = subplot(4,1,4);
set(ax,'Units','points');
set(ax,'Position',[60 25 tp+52 tp]); %+52 is offset for color bar
set(ax,'XTick',[],'XTickLabel',''); xlim([1 tp]); %caxis([-2 2]); 
set(get(gca,'YLabel'),'String','Grayordinates');

XTicks = round(linspace(0,size(img,2),7));
XTicksPts = XTicks;
XTicksPts(1) = XTicks(1)+0.5;
XTicksPts(end) = XTicks(end)-0.5;

for i = 1:numel(XTicks)
    XTickString{i} = num2str(XTicks(i)); %#ok<AGROW>
end;

set(ax,'XTick',XTicksPts,'XTickLabel',XTickString,'TickLength',[0 0]);

%Make "z-score" color bar
colorticks=[(CLIM(1)-(CLIM(2)*0)/4) (CLIM(1)-(CLIM(1)*1)/4) (CLIM(1)-(CLIM(1)*2)/4) (CLIM(1)-(CLIM(1)*3)/4) 0 (CLIM(2)-(CLIM(2)*3)/4) (CLIM(2)-(CLIM(2)*2)/4) (CLIM(2)-(CLIM(2)*1)/4) (CLIM(2)-(CLIM(2)*0)/4)];
colorticksz=colorticks; %Round z scores to nearest hundreth
colortickszcell={num2str(colorticksz(1));num2str(colorticksz(2));num2str(colorticksz(3));num2str(colorticksz(4));num2str(colorticksz(5));num2str(colorticksz(6));num2str(colorticksz(7));num2str(colorticksz(8));num2str(colorticksz(9))};
colorbar('YTickMode','manual','YTick',colorticks,'YTickLabel',colortickszcell,'location','eastoutside','Ylim',[CLIM(1) CLIM(2)],'Units','points','FontSize',8); %Color bar refused to work with anything other than 9 ticks

% Save plot

print([step '_QC_Summary_Plot_z'],'-dpng','-r72'); %close; %%%
end
