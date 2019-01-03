function RestingStateStats(motionparameters,hp,TR,ICAs,noiselist,wbcommand,inputdtseries,bias,outprefix,dlabel,bcmode,outstring,WM,CSF,tICAtNoiseList,tICAtcsName,tICAtsNoiseList,sICAtcsName,Physio,ReUseHighPass)

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
% BCMODE (optional): REVERT - undoes bias field correction
%   NONE - does not change bias field correction
%   File - uses file to apply new bias field correction after reverting old
% OUTSTRING: normally 'stats'
% WM: A text file or NONE
% CSF: A text file or NONE
% tICAtNoiseList: A text file or NONE
% tICAtcsName: A text file or NONE
% tICAtsNoiseList: A text file or NONE
% Physio: A text file or FALSE
% ReUseHighPass: YES or NO

%% Notes on variable dimensions:
%    cdata: NgrayOrd x Ntp (e.g., 91282 x 1200)
%    ICAs: Ntp x Ncomponents
%    Motiontc: Ntp x 24 (after extending with first differences and
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
NumPhysioEVs=14; %Not currently possible to discover, perhaps should be moved to launcher
NumPhysioRaw=2; %Not currently possible to discover, perhaps should be moved to launcher

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
fprintf('%s - tICAtNoiseList: %s\n', func_name, tICAtNoiseList);
fprintf('%s - tICAtcs: %s\n', func_name, tICAtcsName);
fprintf('%s - tICAtsNoiseList: %s\n', func_name, tICAtsNoiseList);
fprintf('%s - sICAtcs: %s\n', func_name, sICAtcsName);
fprintf('%s - Physio: %s\n', func_name, Physio);
fprintf('%s - ReUseHighPass: %s\n', func_name, ReUseHighPass);

% Set some options that aren't included as arguments in the function
SaveVarianceNormalizationImage = 1; %If non-zero, output map of sqrt(UnstructNoiseVar)
SaveMGT = 1; %If non-zero, save mean grayordinate time series at each stage
SaveFDDVARS = 1; %If non-zero, save FD and DVARS timeseries at each stage
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
if strcmp(ReUseHighPass,'YES');
    fid = fopen([inputdtseries '.txt']);
    txtfileArray = textscan(fid,'%s');
    txtfileArray = txtfileArray{1,1};
    BO=ciftiopen([txtfileArray{1,1} '.dtseries.nii'],WBC);
    BOHP=ciftiopen([txtfileArray{2,1} '.dtseries.nii'],WBC);
else
    BO=ciftiopen([inputdtseries '.dtseries.nii'],WBC);
end

% Revert bias field if requested
if ~strcmp(bcmode,'NONE');
    bias=ciftiopen(bias,WBC);
    if strcmp(ReUseHighPass,'YES');
        BOHP.cdata=BOHP.cdata.*repmat(bias.cdata,1,size(BOHP.cdata,tpDim));    
    end
    BO.cdata=BO.cdata.*repmat(bias.cdata,1,size(BO.cdata,tpDim));
end

FixVN=0;
if exist(bcmode,'file')
    real_bias=ciftiopen(bcmode,WBC);
    if strcmp(ReUseHighPass,'YES');
        BOHP.cdata=BOHP.cdata./repmat(real_bias.cdata,1,size(BOHP.cdata,tpDim));
    end
    BO.cdata=BO.cdata./repmat(real_bias.cdata,1,size(BO.cdata,tpDim));
    FixVN=1;
end

% Compute spatial mean/std, demean each grayordinate
MEAN = mean(BO.cdata,tpDim);
STD=std(BO.cdata,[],tpDim);
BO.cdata = demean(BO.cdata,tpDim);
OrigTCS=BO.cdata;

if ~strcmp(ReUseHighPass,'YES');
    if ~((hp==2000) || (hp==0))
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
    else
      HighPassTCS=detrend(BO.cdata')';
    end
else
    HighPassTCS=BOHP.cdata;
end

%%%% Compute variances so far
OrigVar=var(OrigTCS,[],tpDim);
[OrigMGTRtcs,OrigMGT,OrigMGTbeta,OrigMGTVar,OrigMGTrsq] = MGTR(OrigTCS);

HighPassVar=var((OrigTCS - HighPassTCS),[],tpDim);
[HighPassMGTRtcs,HighPassMGT,HighPassMGTbeta,HighPassMGTVar,HighPassMGTrsq] = MGTR(HighPassTCS);

%%%%  Read and prepare motion tcs
% Read in the six motion parameters, compute the backward difference, and square
% If 'motionparameters' input argument doesn't already have an extension, add .txt
if ~strcmp(ReUseHighPass,'YES');
    Motiontc=[]; %#ok<NASGU>
    [~, ~, ext] = fileparts(motionparameters);
    if isempty(ext)
      Motiontc=load([motionparameters '.txt']);
    else
      Motiontc=load(motionparameters);
    end
    mvm=Motiontc; 
    Motiontc=Motiontc(:,1:6); %Be sure to limit to just the first 6 elements
    %%Motiontc=normalise(Motiontc(:,std(Motiontc)>0.000001)); % remove empty columns
    Motiontc=normalise([Motiontc [zeros(1,size(Motiontc,2)); Motiontc(2:end,:)-Motiontc(1:end-1,:)] ]);
    Motiontc=normalise([Motiontc Motiontc.*Motiontc]);

    fprintf('%s - Starting fslmaths filtering of motion tcs\n',func_name);
    save_avw(reshape(Motiontc',size(Motiontc,2),1,1,size(Motiontc,1)),[outprefix '_fakeNIFTI'],'f',[1 1 1 TR]);
    system(sprintf(['fslmaths ' outprefix '_fakeNIFTI -bptf %f -1 ' outprefix '_fakeNIFTI'],0.5*hp/TR));
    MotiontcHP=normalise(reshape(read_avw([outprefix '_fakeNIFTI']),size(Motiontc,2),size(Motiontc,1))');
    unix(['rm ' outprefix '_fakeNIFTI.nii.gz']);
    fprintf('%s - Finished fslmaths filtering of motion tcs\n',func_name);
    %mvm=MotiontcHP(:,1:12);
else
    fid = fopen([motionparameters '.txt']);
    txtfileArray = textscan(fid,'%s');
    txtfileArray = txtfileArray{1,1};
    Motiontc=reshape(read_avw(txtfileArray{1,1}),str2num(txtfileArray{3,1}),str2num(txtfileArray{4,1}))';
    %mvm=Motiontc; 
    Motiontc=normalise(reshape(read_avw(txtfileArray{1,1}),str2num(txtfileArray{3,1}),str2num(txtfileArray{4,1}))');
    Motiontc=Motiontc(:,1:6); %Be sure to limit to just the first 6 elements
    %%Motiontc=normalise(Motiontc(:,std(Motiontc)>0.000001)); % remove empty columns
    Motiontc=normalise([Motiontc [zeros(1,size(Motiontc,2)); Motiontc(2:end,:)-Motiontc(1:end-1,:)] ]);
    Motiontc=normalise([Motiontc Motiontc.*Motiontc]);
    MotiontcHP=normalise(reshape(read_avw(txtfileArray{2,1}),str2num(txtfileArray{3,1}),str2num(txtfileArray{4,1}))');
    mvm=load(txtfileArray{5,1});
    %mvm=MotiontcHP(:,1:12);
end

%%%%  Read ICA component timeseries
ICAorig=normalise(load(sprintf(ICAs)));

%%%%  Read tICA component timeseries
if ~strcmp(tICAtNoiseList,'NONE')
    tICAtNoise=load(tICAtNoiseList);
    tICAtcs_raw=load(tICAtcsName);
    tICAtcs=normalise(tICAtcs_raw);
    if ~strcmp(tICAtsNoiseList,'NONE')
        tICAtsNoise=load(tICAtsNoiseList);
        tICAtsNoise=[tICAtNoise tICAtsNoise];
    end    
    sICAtcs_raw=load(sICAtcsName);
    sICAtcs=normalise(sICAtcs_raw);
end

%%%%  Read WM Timeseries and Highpass Filter
if ~strcmp(WM,'NONE')
    if ~strcmp(ReUseHighPass,'YES');
        WMtcOrig=demean(load(sprintf(WM)));
        fprintf('%s - Starting fslmaths filtering of wm tcs \n',func_name);
        save_avw(reshape(WMtcOrig',size(WMtcOrig,2),1,1,size(WMtcOrig,1)),[outprefix '_fakeNIFTI'],'f',[1 1 1 TR]);
        system(sprintf(['fslmaths ' outprefix '_fakeNIFTI -bptf %f -1 ' outprefix '_fakeNIFTI'],0.5*hp/TR));
        WMtcHP=demean(reshape(read_avw([outprefix '_fakeNIFTI']),size(WMtcOrig,2),size(WMtcOrig,1))');
        unix(['rm ' outprefix '_fakeNIFTI.nii.gz']);
        fprintf('%s - Finished fslmaths filtering of wm tcs\n',func_name);
    else
        fid = fopen([WM '.txt']);
        txtfileArray = textscan(fid,'%s');
        txtfileArray = txtfileArray{1,1};
        WMtcOrig=demean(load(sprintf(txtfileArray{1,1})));
        WMtcHP=demean(load(sprintf(txtfileArray{2,1})));
    end
end

%%%%  Read CSF Timeseries and Highpass Filter
if ~strcmp(CSF,'NONE')
    if ~strcmp(ReUseHighPass,'YES');
        CSFtcOrig=demean(load(sprintf(CSF)));
        fprintf('%s - Starting fslmaths filtering of csf tcs \n',func_name);
        save_avw(reshape(CSFtcOrig',size(CSFtcOrig,2),1,1,size(CSFtcOrig,1)),[outprefix '_fakeNIFTI'],'f',[1 1 1 TR]);
        system(sprintf(['fslmaths ' outprefix '_fakeNIFTI -bptf %f -1 ' outprefix '_fakeNIFTI'],0.5*hp/TR));
        CSFtcHP=demean(reshape(read_avw([outprefix '_fakeNIFTI']),size(CSFtcOrig,2),size(CSFtcOrig,1))');
        unix(['rm ' outprefix '_fakeNIFTI.nii.gz']);
        fprintf('%s - Finished fslmaths filtering of csf tcs\n',func_name);
    else
        fid = fopen([CSF '.txt']);
        txtfileArray = textscan(fid,'%s');
        txtfileArray = txtfileArray{1,1};
        CSFtcOrig=demean(load(sprintf(txtfileArray{1,1})));
        CSFtcHP=demean(load(sprintf(txtfileArray{2,1})));   
    end
end

%%%%  Read Physio Timeseries and Highpass Filter
if ~strcmp(Physio,'FALSE')
    if ~strcmp(ReUseHighPass,'YES');
        if exist(Physio,'file') == 2
            fid = fopen(Physio);
            txtfileArray = textscan(fid,'%s');
            txtfileArray = txtfileArray{1,1};
            PhysiotcOrig=txtfileArray{1,1};
            RawPhysio=txtfileArray{2,1};
            PhysiotcOrig=load(PhysiotcOrig);
            if length(PhysiotcOrig) == length(ICAorig)
                RVT=PhysiotcOrig(:,14);
                HR=PhysiotcOrig(:,13);
                PhysiotcOrig=normalise(PhysiotcOrig);
                RawPhysio=load(RawPhysio);
                RawPhysio(:,1)=RawPhysio(:,1)./TR; %Convert time to Vols
                fprintf('%s - Starting fslmaths filtering of physio tcs \n',func_name);
                save_avw(reshape(PhysiotcOrig',size(PhysiotcOrig,2),1,1,size(PhysiotcOrig,1)),[outprefix '_fakeNIFTI'],'f',[1 1 1 TR]);
                system(sprintf(['fslmaths ' outprefix '_fakeNIFTI -bptf %f -1 ' outprefix '_fakeNIFTI'],0.5*hp/TR));
                PhysiotcHP=demean(reshape(read_avw([outprefix '_fakeNIFTI']),size(PhysiotcOrig,2),size(PhysiotcOrig,1))');
                unix(['rm ' outprefix '_fakeNIFTI.nii.gz']);
                fprintf('%s - Finished fslmaths filtering of physio tcs\n',func_name);
                PhysioSwitch='On';
            else
                PhysiotcOrig=single(zeros(length(mvm),NumPhysioEVs));
                RawPhysio=single(zeros(length(mvm),NumPhysioRaw));
                HR=single(zeros(length(mvm),1));
                RVT=single(zeros(length(mvm),1));
                Physio='FALSE';
                PhysioSwitch='On';
            end
        else
            PhysiotcOrig=single(zeros(length(mvm),NumPhysioEVs));
            RawPhysio=single(zeros(length(mvm),NumPhysioRaw));
            HR=single(zeros(length(mvm),1));
            RVT=single(zeros(length(mvm),1));
            Physio='FALSE';
            PhysioSwitch='On';
        end
     else
        fid = fopen([Physio '.txt']);
        txtfileArray = textscan(fid,'%s');
        txtfileArray = txtfileArray{1,1};
        PhysiotcOrig=reshape(read_avw(txtfileArray{1,1}),NumPhysioEVs,length(ICAorig))';
        PhysiotcHP=reshape(read_avw(txtfileArray{2,1}),NumPhysioEVs,length(ICAorig))';
        PhysioMask=reshape(read_avw(txtfileArray{3,1}),1,length(ICAorig))';
        RawPhysio=load(txtfileArray{4,1});
        RawMaskPhysio=load(txtfileArray{5,1});
        %mvm=load(txtfileArray{6,1});
        RVT=PhysiotcOrig(:,14);
        HR=PhysiotcOrig(:,13);
        PhysiotcOrig=normalise(PhysiotcOrig);
        RawPhysio(:,1)=RawPhysio(:,1)./TR; %Convert time to Vols
        PhysioSwitch='On';
        if sum(PhysioMask) == 0
            Physio='FALSE';
        end
     end
else
    PhysioSwitch='Off';
end
%%%% Aggressively regress out motion parameters from ICA and from data
ICA = ICAorig - (MotiontcHP * (pinv(MotiontcHP) * ICAorig));
if ~strcmp(WM,'NONE')
    %%%% Aggressively regress out motion parameters from WM
    WMtcPM = WMtcHP - (MotiontcHP * (pinv(MotiontcHP) * WMtcHP));
    %%%% Regress out Noise
    WMbetaICA = pinv(ICA) * WMtcPM;
    WMtcClean = WMtcPM - (ICA(:,Inoise) * WMbetaICA(Inoise,:));
    WMtcClean = demean(WMtcClean);
    %%%% Regress out temporal ICA Noise
    if ~strcmp(tICAtNoiseList,'NONE')
        WMbetatICA = pinv(tICAtcs) * WMtcClean;
        WMtctClean = WMtcClean - (tICAtcs(:,tICAtNoise) * WMbetatICA(tICAtNoise,:));
        WMtctClean = demean(WMtctClean);
        if ~strcmp(tICAtsNoiseList,'NONE')
            WMtctsClean = WMtcClean - (tICAtcs(:,tICAtsNoise) * WMbetatICA(tICAtsNoise,:));
            WMtctsClean = demean(WMtctsClean);
        end
    end
end
if ~strcmp(CSF,'NONE')
    %%%% Aggressively regress out motion parameters from CSF
    CSFtcPM = CSFtcHP - (MotiontcHP * (pinv(MotiontcHP) * CSFtcHP));
    %%%% Regress out Noise
    CSFbetaICA = pinv(ICA) * CSFtcPM;
    CSFtcClean = CSFtcPM - (ICA(:,Inoise) * CSFbetaICA(Inoise,:));
    CSFtcClean = demean(CSFtcClean);
    %%%% Regress out temporal ICA Noise
    if ~strcmp(tICAtNoiseList,'NONE')
        CSFbetatICA = pinv(tICAtcs) * CSFtcClean;
        CSFtctClean = CSFtcClean - (tICAtcs(:,tICAtNoise) * CSFbetatICA(tICAtNoise,:));
        CSFtctClean = demean(CSFtctClean);
        if ~strcmp(tICAtsNoiseList,'NONE')
            CSFtctsClean = CSFtcClean - (tICAtcs(:,tICAtsNoise) * CSFbetatICA(tICAtsNoise,:));
            CSFtctsClean = demean(CSFtctsClean);
        end   
    end   
end
if ~strcmp(Physio,'FALSE')
    %%%% Aggressively regress out motion parameters from Physio
    PhysiotcPM = PhysiotcHP - (MotiontcHP * (pinv(MotiontcHP) * PhysiotcHP));
    %%%% Regress out Noise
    PhysiobetaICA = pinv(ICA) * PhysiotcPM;
    PhysiotcClean = PhysiotcPM - (ICA(:,Inoise) * PhysiobetaICA(Inoise,:));
    PhysiotcClean = demean(PhysiotcClean);
    %%%% Regress out temporal ICA Noise
    %if ~strcmp(tICAtNoiseList,'NONE')   
        %PhysiobetatICA = pinv(tICAtcs) * PhysiotcClean;
        %PhysiotctClean = PhysiotcClean - (tICAtcs(:,tICAtNoise) * PhysiobetatICA(tICAtNoise,:));
        %PhysiotctClean = demean(PhysiotctClean);
        %if ~strcmp(tICAtsNoiseList,'NONE')   
            %PhysiotctsClean = PhysiotcClean - (tICAtcs(:,tICAtsNoise) * PhysiobetatICA(tICAtsNoise,:));
            %PhysiotctsClean = demean(PhysiotctsClean);
        %end   
    %end   
end
%%%% Aggressively regress out motion parameters from data
PostMotionTCS = HighPassTCS - (MotiontcHP * (pinv(MotiontcHP) * HighPassTCS'))';
[PostMotionMGTRtcs,PostMotionMGT,PostMotionMGTbeta,PostMotionMGTVar,PostMotionMGTrsq] = MGTR(PostMotionTCS);
MotionVar=var((HighPassTCS - PostMotionTCS),[],tpDim);

%%%% FIX cleanup post motion
%Find signal and total component numbers
total = 1:size(ICA,2);
Isignal = total(~ismember(total,Inoise));

if ~strcmp(tICAtNoiseList,'NONE')
    total = 1:size(tICAtcs,2);
    tICAtSignal = total(~ismember(total,tICAtNoise));
    if ~strcmp(tICAtsNoiseList,'NONE')
        tICAtsSignal = total(~ismember(total,tICAtsNoise));
    end
end

% beta for ICA (signal *and* noise components), followed by unaggressive cleanup
% (i.e., only remove unique variance associated with the noise components)
betaICA = pinv(ICA) * PostMotionTCS';
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
    WMbetaICA = pinv(ICA) * WMtcPM;
    WMtcUnstructNoise = WMtcPM - (ICA * WMbetaICA);
    WMtcUnstructNoise = demean(WMtcUnstructNoise);
    % Regress out all structured signal
end
if ~strcmp(CSF,'NONE')
    % Regress out all structured signal    
    CSFbetaICA = pinv(ICA) * CSFtcPM;
    CSFtcUnstructNoise = CSFtcPM - (ICA * CSFbetaICA);
    CSFtcUnstructNoise = demean(CSFtcUnstructNoise);
    % Regress out all structured signal
end

if ~strcmp(WM,'NONE')
    % Regress out all signal
    WMbetaICA = pinv(ICA) * WMtcPM;
    WMtcStructNoise = WMtcPM - (ICA(:,Isignal) * WMbetaICA(Isignal,:));
    WMtcStructNoise = demean(WMtcStructNoise);
end
if ~strcmp(CSF,'NONE')
    % Regress out all signal    
    CSFbetaICA = pinv(ICA) * CSFtcPM;
    CSFtcStructNoise = CSFtcPM - (ICA(:,Isignal) * CSFbetaICA(Isignal,:));
    CSFtcStructNoise = demean(CSFtcStructNoise);
end

%Create data if regressing out cleaned WM timecourse
if ~strcmp(WM,'NONE')
    betaWM = pinv(WMtcClean) * CleanedTCS';
    WMCleanedTCS = CleanedTCS - (WMtcClean * betaWM)';
    [WMCleanedMGTRtcs,WMCleanedMGT,WMCleanedMGTbeta,WMCleanedMGTVar,WMCleanedMGTrsq] = MGTR(WMCleanedTCS);
    WMVar = var((CleanedTCS - WMCleanedTCS),[],tpDim);
end
if ~strcmp(WM,'NONE') && ~strcmp(CSF,'NONE')
    % Regress out WM from CSF signal   
    betaCSFWM = pinv(WMtcClean) * CSFtcClean;
    CSFWM = CSFtcClean - (WMtcClean * betaCSFWM);
    CSFWM = demean(CSFWM);
    WMWM=single(zeros(length(CSFWM),1));
end

%Create data if regressing out cleaned CSF timecourse
if ~strcmp(CSF,'NONE')
    betaCSF = pinv(CSFtcClean) * CleanedTCS';
    CSFCleanedTCS = CleanedTCS - (CSFtcClean * betaCSF)';
    [CSFCleanedMGTRtcs,CSFCleanedMGT,CSFCleanedMGTbeta,CSFCleanedMGTVar,CSFCleanedMGTrsq] = MGTR(CSFCleanedTCS);
    CSFVar = var((CleanedTCS - CSFCleanedTCS),[],tpDim);
end
if ~strcmp(WM,'NONE') && ~strcmp(CSF,'NONE')
    % Regress out CSF from WM signal   
    betaWMCSF = pinv(CSFtcClean) * WMtcClean;
    WMCSF = WMtcClean - (CSFtcClean * betaWMCSF);
    WMCSF = demean(WMCSF);
    CSFCSF=single(zeros(length(WMCSF),1));
end

%Create data if regressing out cleaned WM and CSF timecourses
if ~strcmp(WM,'NONE') && ~strcmp(CSF,'NONE')
    betaWMCSF = pinv([WMtcClean CSFtcClean]) * CleanedTCS';
    WMCSFCleanedTCS = CleanedTCS - ([WMtcClean CSFtcClean] * betaWMCSF)';
    [WMCSFCleanedMGTRtcs,WMCSFCleanedMGT,WMCSFCleanedMGTbeta,WMCSFCleanedMGTVar,WMCSFCleanedMGTrsq] = MGTR(WMCSFCleanedTCS);
    WMCSFVar = var((CleanedTCS - WMCSFCleanedTCS),[],tpDim);
end

%Create data if regressing out cleaned Physio timecourse
if ~strcmp(Physio,'FALSE')
    betaPhysio = pinv(PhysiotcClean) * CleanedTCS';
    PhysioCleanedTCS = CleanedTCS - (PhysiotcClean * betaPhysio)';
    [PhysioCleanedMGTRtcs,PhysioCleanedMGT,PhysioCleanedMGTbeta,PhysioCleanedMGTVar,PhysioCleanedMGTrsq] = MGTR(PhysioCleanedTCS);
    PhysioVar = var((CleanedTCS - PhysioCleanedTCS),[],tpDim);
    if ~strcmp(WM,'NONE') && ~strcmp(CSF,'NONE')
        % Regress out Physio from WM and CSF signals   
        betaWMPhysio = pinv(PhysiotcClean) * WMtcClean;
        WMPhysio = WMtcClean - (PhysiotcClean * betaWMPhysio);
        WMPhysio = demean(WMPhysio);

        betaCSFPhysio = pinv(PhysiotcClean) * CSFtcClean;
        CSFPhysio = CSFtcClean - (PhysiotcClean * betaCSFPhysio);
        CSFPhysio = demean(CSFPhysio);

    end
end

%Create data if regressing out MGT
if ~strcmp(WM,'NONE')
    WMbetaMGT = pinv(CleanedMGT) * WMtcClean;
    WMtcMGT = WMtcClean - (CleanedMGT * WMbetaMGT);
    WMtcMGT = demean(WMtcMGT);
end
if ~strcmp(CSF,'NONE')
    CSFbetaMGT = pinv(CleanedMGT) * CSFtcClean;
    CSFtcMGT = CSFtcClean - (CleanedMGT * CSFbetaMGT);
    CSFtcMGT = demean(CSFtcMGT);
end


%Make BOLD Variance if regressing out WM and/or CSF timecourses or Physio timecourses
if ~strcmp(WM,'NONE')
    WMCleanedBOLDVar = var((WMCleanedTCS - UnstructNoiseTCS),[],tpDim);
end
if ~strcmp(CSF,'NONE')
    CSFCleanedBOLDVar = var((CSFCleanedTCS - UnstructNoiseTCS),[],tpDim);
end
if ~strcmp(WM,'NONE') && ~strcmp(CSF,'NONE')
    WMCSFCleanedBOLDVar = var((WMCSFCleanedTCS - UnstructNoiseTCS),[],tpDim);
end
if ~strcmp(Physio,'FALSE')
    PhysioCleanedBOLDVar = var((PhysioCleanedTCS - UnstructNoiseTCS),[],tpDim);
end

%Clean data from temporal ICA noise components
if ~strcmp(tICAtNoiseList,'NONE')
    % beta for tICA (signal *and* noise components), followed by unaggressive cleanup
    % (i.e., only remove unique variance associated with the noise components)
    betatICA = pinv(tICAtcs) * CleanedTCS';
    betaICAtcs=pinv(tICAtcs) * ICA(:,Isignal);
    
    tCleanedTCS = CleanedTCS - (tICAtcs(:,tICAtNoise) * betatICA(tICAtNoise,:))';
    [tCleanedMGTRtcs,tCleanedMGT,tCleanedMGTbeta,tCleanedMGTVar,tCleanedMGTrsq] = MGTR(tCleanedTCS);
    ICAtclean=ICA(:,Isignal) - (tICAtcs(:,tICAtNoise) * betaICAtcs(tICAtNoise,:));
    betaICAtclean=pinv(ICAtclean) * tCleanedTCS';
    tCleanedUnstructuredNoiseTCS=tCleanedTCS - (ICAtclean * betaICAtclean)';
    [tCleanedUnstructuredNoiseMGTRtcs,tCleanedUnstructuredNoiseMGT,tCleanedUnstructuredNoiseMGTbeta,tCleanedUnstructuredNoiseMGTVar,tCleanedUnstructuredNoiseMGTrsq] = MGTR(tCleanedUnstructuredNoiseTCS);
    tCleanedUnstructuredNoiseVar=var(tCleanedUnstructuredNoiseTCS,[],tpDim);
    tStructuredNoiseVar = var((CleanedTCS - tCleanedTCS),[],tpDim);
    tCleanedBOLDVar = var((tCleanedTCS - tCleanedUnstructuredNoiseTCS),[],tpDim);
    tNoiseTCS = CleanedTCS - (tICAtcs(:,tICAtSignal) * betatICA(tICAtSignal,:))';
    [tNoiseMGTRtcs,tNoiseMGT,tNoiseMGTbeta,tNoiseMGTVar,tNoiseMGTrsq] = MGTR(tNoiseTCS);
    if ~strcmp(tICAtsNoiseList,'NONE')
        tsCleanedTCS = CleanedTCS - (tICAtcs(:,tICAtsNoise) * betatICA(tICAtsNoise,:))';
        [tsCleanedMGTRtcs,tsCleanedMGT,tsCleanedMGTbeta,tsCleanedMGTVar,tsCleanedMGTrsq] = MGTR(tsCleanedTCS);
        ICAtsclean=ICA(:,Isignal) - (tICAtcs(:,tICAtsNoise) * betaICAtcs(tICAtsNoise,:));
        betaICAtsclean=pinv(ICAtsclean) * tsCleanedTCS';
        tsCleanedUnstructuredNoiseTCS=tsCleanedTCS - (ICAtsclean * betaICAtsclean)';
        [tsCleanedUnstructuredNoiseMGTRtcs,tsCleanedUnstructuredNoiseMGT,tsCleanedUnstructuredNoiseMGTbeta,tsCleanedUnstructuredNoiseMGTVar,tsCleanedUnstructuredNoiseMGTrsq] = MGTR(tsCleanedUnstructuredNoiseTCS);
        tsCleanedUnstructuredNoiseVar=var(tsCleanedUnstructuredNoiseTCS,[],tpDim);
        tsStructuredNoiseVar = var((CleanedTCS - tsCleanedTCS),[],tpDim);
        tsCleanedBOLDVar = var((tsCleanedTCS - tsCleanedUnstructuredNoiseTCS),[],tpDim);
        tsNoiseTCS = CleanedTCS - (tICAtcs(:,tICAtsSignal) * betatICA(tICAtsSignal,:))';
        [tsNoiseMGTRtcs,tsNoiseMGT,tsNoiseMGTbeta,tsNoiseMGTVar,tsNoiseMGTrsq] = MGTR(tsNoiseTCS);
    end
    %tCleanedUnstructuredNoiseTCS=CleanedTCS - (tICAtcs * betatICA)'; %Don't add a bunch of unstructured noise to the data, instead regress out tICA Noise from sICA tcs
    betasICA = pinv(sICAtcs) * CleanedTCS';
    tICAmix = pinv(normalise(betasICA')) * betatICA'; %Isolate variances in tICAmix
end

%Create WM and CSF timecourses that correspond to structured and
%unstructured noise grey plots
if ~strcmp(WM,'NONE')
    if ~strcmp(tICAtNoiseList,'NONE')
        WMbetatICA = pinv(ICAtclean) * WMtcClean;
        WMtctCleanedUnstructNoise = WMtcClean - (ICAtclean * WMbetatICA);
        WMtctCleanedUnstructNoise = demean(WMtctCleanedUnstructNoise);
        if ~strcmp(tICAtsNoiseList,'NONE')
            WMbetatsICA = pinv(ICAtsclean) * WMtcClean;
            WMtctsCleanedUnstructNoise = WMtcClean - (ICAtsclean * WMbetatsICA);
            WMtctsCleanedUnstructNoise = demean(WMtctsCleanedUnstructNoise);
        end
    end
end
if ~strcmp(CSF,'NONE')
    if ~strcmp(tICAtNoiseList,'NONE')
        CSFbetatICA = pinv(ICAtclean) * CSFtcClean;
        CSFtctCleanedUnstructNoise = CSFtcClean - (ICAtclean * CSFbetatICA);
        CSFtctCleanedUnstructNoise = demean(CSFtctCleanedUnstructNoise);
        if ~strcmp(tICAtsNoiseList,'NONE')
            CSFbetatsICA = pinv(ICAtsclean) * CSFtcClean;
            CSFtctsCleanedUnstructNoise = CSFtcClean - (ICAtsclean * CSFbetatsICA);
            CSFtctsCleanedUnstructNoise = demean(CSFtctsCleanedUnstructNoise);
        end
    end
end

%Create data if regressing out MGT
if ~strcmp(WM,'NONE')
    if ~strcmp(tICAtNoiseList,'NONE')
        WMtctCleanbetaMGT = pinv(tCleanedMGT) * WMtctClean;
        WMtctCleanMGT = WMtctClean - (tCleanedMGT * WMtctCleanbetaMGT);
        WMtctCleanMGT = demean(WMtctCleanMGT);
        if ~strcmp(tICAtsNoiseList,'NONE')
            WMtctsCleanbetaMGT = pinv(tsCleanedMGT) * WMtctsClean;
            WMtctsCleanMGT = WMtctsClean - (tsCleanedMGT * WMtctsCleanbetaMGT);
            WMtctsCleanMGT = demean(WMtctsCleanMGT);
        end
    end
end
if ~strcmp(CSF,'NONE')
    if ~strcmp(tICAtNoiseList,'NONE')
        CSFtctCleanbetaMGT = pinv(tCleanedMGT) * CSFtctClean;
        CSFtctCleanMGT = CSFtctClean - (tCleanedMGT * CSFtctCleanbetaMGT);
        CSFtctCleanMGT = demean(CSFtctCleanMGT);
        if ~strcmp(tICAtsNoiseList,'NONE')
            CSFtctsCleanbetaMGT = pinv(tsCleanedMGT) * CSFtctsClean;
            CSFtctsCleanMGT = CSFtctsClean - (tsCleanedMGT * CSFtctsCleanbetaMGT);
            CSFtctsCleanMGT = demean(CSFtctsCleanMGT);
        end
    end
end


% Generate "grayplots" of the various stages and differences between stages using a 
% scaling in "MR units"
if ~strcmp(WM,'NONE') && ~strcmp(CSF,'NONE')
    steps = {'OrigTCS','HighPassTCS','PostMotionTCS','CleanedTCS',...
        'UnstructNoiseTCS','WMCleanedTCS','CSFCleanedTCS','WMCSFCleanedTCS','StructNoiseTCS','tCleanedTCS','tcleanedUnstructNoiseTCS','PhysioCleanedTCS','tsCleanedTCS','tscleanedUnstructNoiseTCS','CleanedMGTRTCS','UnstructNoiseMGTRTCS','tCleanedMGTRTCS','tcleanedUnstructNoiseMGTRTCS','tsCleanedMGTRTCS','tscleanedUnstructNoiseMGTRTCS'};
    plotgray(OrigTCS,mvm,HR,RVT,RawPhysio,OrigMGT,WMtcOrig,CSFtcOrig,[outprefix '_1_' steps{1}]); %Original data with unstructured noise
    plotgray(OrigTCS-UnstructNoiseTCS,mvm,HR,RVT,RawPhysio,OrigMGT,WMtcOrig,CSFtcOrig,[outprefix '_1-5_' steps{1} '-' steps{5}]); %Original data without unstructured noise
    plotgray(OrigTCS-HighPassTCS,mvm,HR,RVT,RawPhysio,OrigMGT-HighPassMGT,WMtcOrig-WMtcHP,CSFtcOrig-CSFtcHP,[outprefix '_1-2_' steps{1} '-' steps{2}]); %Effect of highpass filter
    plotgray(HighPassTCS,mvm,HR,RVT,RawPhysio,HighPassMGT,WMtcHP,CSFtcHP,[outprefix '_2_' steps{2}]); %HP with unstructured noise
    plotgray(HighPassTCS-UnstructNoiseTCS,mvm,HR,RVT,RawPhysio,HighPassMGT,WMtcHP,CSFtcHP,[outprefix '_2-5_' steps{2} '-' steps{5}]); %HP without unstructured noise
    plotgray(HighPassTCS-PostMotionTCS,mvm,HR,RVT,RawPhysio,HighPassMGT-PostMotionMGT,WMtcHP-WMtcPM,CSFtcHP-CSFtcPM,[outprefix '_2-3_' steps{2} '-' steps{3}]); %Effect of motion regression 
    plotgray(PostMotionTCS,mvm,HR,RVT,RawPhysio,PostMotionMGT,WMtcPM,CSFtcPM,[outprefix '_3_' steps{3}]); %Motion Regression with unstructured noise
    plotgray(PostMotionTCS-UnstructNoiseTCS,mvm,HR,RVT,RawPhysio,PostMotionMGT,WMtcPM,CSFtcPM,[outprefix '_3-5_' steps{3} '-' steps{5}]); %Motion Regression without unstructured noise
    plotgray(PostMotionTCS-CleanedTCS,mvm,HR,RVT,RawPhysio,PostMotionMGT-CleanedMGT,WMtcPM-WMtcClean,CSFtcPM-CSFtcClean,[outprefix '_3-4_' steps{3} '-' steps{4}]); %Effect of structured noise regression 
    plotgray(CleanedTCS,mvm,HR,RVT,RawPhysio,CleanedMGT,WMtcClean,CSFtcClean,[outprefix '_4_' steps{4}]); %Cleaned data with unstructured noise
    plotgray(CleanedTCS-UnstructNoiseTCS,mvm,HR,RVT,RawPhysio,CleanedMGT,WMtcClean,CSFtcClean,[outprefix '_4-5_' steps{4} '-' steps{5}]); %Cleaned data without unstructured noise
    plotgray(UnstructNoiseTCS,mvm,HR,RVT,RawPhysio,UnstructNoiseMGT,WMtcUnstructNoise,CSFtcUnstructNoise,[outprefix '_5_' steps{5}]); %Unstructured noise only
    plotgray(WMCleanedTCS,mvm,HR,RVT,RawPhysio,WMCleanedMGT,WMWM,CSFWM,[outprefix '_6_' steps{6}]); %WM regressed data with unstructured noise
    plotgray(WMCleanedTCS-UnstructNoiseTCS,mvm,HR,RVT,RawPhysio,WMCleanedMGT,WMWM,CSFWM,[outprefix '_6-5_' steps{6} '-' steps{5}]); %WM regressed data without unstructured noise
    plotgray(CleanedTCS-WMCleanedTCS,mvm,HR,RVT,RawPhysio,CleanedMGT-WMCleanedMGT,WMtcClean-WMWM,CSFtcClean-CSFWM,[outprefix '_4-6_' steps{4} '-' steps{6}]); %Effect of WM regression
    plotgray(CSFCleanedTCS,mvm,HR,RVT,RawPhysio,CSFCleanedMGT,WMCSF,CSFCSF,[outprefix '_7_' steps{7}]); %CSF regressed data with unstructured noise
    plotgray(CSFCleanedTCS-UnstructNoiseTCS,mvm,HR,RVT,RawPhysio,CSFCleanedMGT,WMCSF,CSFCSF,[outprefix '_7-5_' steps{7} '-' steps{5}]); %CSF regressed data without unstructured noise
    plotgray(CleanedTCS-CSFCleanedTCS,mvm,HR,RVT,RawPhysio,CleanedMGT-CSFCleanedMGT,WMtcClean-WMCSF,CSFtcClean-CSFCSF,[outprefix '_4-7_' steps{4} '-' steps{7}]); %Effect of CSF regression
    plotgray(WMCSFCleanedTCS,mvm,HR,RVT,RawPhysio,WMCSFCleanedMGT,WMWM,CSFCSF,[outprefix '_8_' steps{8}]); %WMCSF regressed data with unstructured noise
    plotgray(WMCSFCleanedTCS-UnstructNoiseTCS,mvm,HR,RVT,RawPhysio,WMCSFCleanedMGT,WMWM,CSFCSF,[outprefix '_8-5_' steps{8} '-' steps{5}]); %WMCSF regressed data without unstructured noise
    plotgray(CleanedTCS-WMCSFCleanedTCS,mvm,HR,RVT,RawPhysio,CleanedMGT-WMCSFCleanedMGT,WMtcClean-WMWM,CSFtcClean-CSFCSF,[outprefix '_4-8_' steps{4} '-' steps{8}]); %Effect of CSF regression
    plotgray(StructNoiseTCS,mvm,HR,RVT,RawPhysio,StructNoiseMGT,WMtcStructNoise,CSFtcStructNoise,[outprefix '_9_' steps{9}]); %Structured noise only
    plotgray(CleanedMGTRtcs,mvm,HR,RVT,RawPhysio,single(zeros(length(CleanedMGT),1)),WMtcMGT,CSFtcMGT,[outprefix '_15_' steps{15}]); %Cleaned data after GSR with unstructured noise
    plotgray(CleanedMGTRtcs-UnstructNoiseMGTRtcs,mvm,HR,RVT,RawPhysio,single(zeros(length(CleanedMGT),1)),WMtcMGT,CSFtcMGT,[outprefix '_15-16_' steps{15} '-' steps{16}]); %Cleaned data after GSR without unstructured noise
    
    if ~strcmp(tICAtNoiseList,'NONE')
        plotgray(CleanedTCS-tCleanedTCS,mvm,HR,RVT,RawPhysio,CleanedMGT-tCleanedMGT,WMtcClean-WMtctClean,CSFtcClean-CSFtctClean,[outprefix '_4-10_' steps{4} '-' steps{10}]); %Effect of temporal ICA structured noise regression 
        plotgray(tCleanedTCS,mvm,HR,RVT,RawPhysio,tCleanedMGT,WMtctClean,CSFtctClean,[outprefix '_10_' steps{10}]); %temporal ICA Cleaned data with unstructured noise
        plotgray(tCleanedTCS-tCleanedUnstructuredNoiseTCS,mvm,HR,RVT,RawPhysio,tCleanedMGT,WMtctClean,CSFtctClean,[outprefix '_10-11_' steps{10} '-' steps{11}]); %temporal ICA noise cleaned data without unstructured noise   
        plotgray(tCleanedUnstructuredNoiseTCS,mvm,HR,RVT,RawPhysio,tCleanedUnstructuredNoiseMGT,WMtctCleanedUnstructNoise,CSFtctCleanedUnstructNoise,[outprefix '_11_' steps{11}]); %temporal ICA noise cleaned unstructured noise
        plotgray(UnstructNoiseTCS-tCleanedUnstructuredNoiseTCS,mvm,HR,RVT,RawPhysio,UnstructNoiseMGT-tCleanedUnstructuredNoiseMGT,WMtcUnstructNoise-WMtctCleanedUnstructNoise,CSFtcUnstructNoise-CSFtctCleanedUnstructNoise,[outprefix '_5-11_' steps{5} '-' steps{11}]); %original unstructured noise - temporal ICA noise cleaned unstructured noise
        plotgray(tCleanedMGTRtcs,mvm,HR,RVT,RawPhysio,single(zeros(length(tCleanedMGT),1)),WMtctCleanMGT,CSFtctCleanMGT,[outprefix '_17_' steps{17}]); %tCleaned data after GSR with unstructured noise
        plotgray(tCleanedMGTRtcs-tCleanedUnstructuredNoiseMGTRtcs,mvm,HR,RVT,RawPhysio,single(zeros(length(tCleanedMGT),1)),WMtctCleanMGT,CSFtctCleanMGT,[outprefix '_17-18_' steps{17} '-' steps{18}]); %tCleaned data after GSR without unstructured noise
        if ~strcmp(tICAtsNoiseList,'NONE')
            plotgray(CleanedTCS-tsCleanedTCS,mvm,HR,RVT,RawPhysio,CleanedMGT-tsCleanedMGT,WMtcClean-WMtctsClean,CSFtcClean-CSFtctsClean,[outprefix '_4-13_' steps{4} '-' steps{13}]); %Effect of temporal ICA structured noise and sleep component regression 
            plotgray(tsCleanedTCS,mvm,HR,RVT,RawPhysio,tsCleanedMGT,WMtctsClean,CSFtctsClean,[outprefix '_13_' steps{13}]); %temporal ICA noise and sleep cleaned data with unstructured noise
            plotgray(tsCleanedTCS-tsCleanedUnstructuredNoiseTCS,mvm,HR,RVT,RawPhysio,tsCleanedMGT,WMtctsClean,CSFtctsClean,[outprefix '_13-14_' steps{13} '-' steps{14}]); %temporal ICA noise and sleep cleaned data without unstructured noise   
            plotgray(tsCleanedUnstructuredNoiseTCS,mvm,HR,RVT,RawPhysio,tsCleanedUnstructuredNoiseMGT,WMtctsCleanedUnstructNoise,CSFtctsCleanedUnstructNoise,[outprefix '_14_' steps{14}]); %temporal ICA noise and sleep cleaned unstructured noise
            plotgray(UnstructNoiseTCS-tsCleanedUnstructuredNoiseTCS,mvm,HR,RVT,RawPhysio,UnstructNoiseMGT-tsCleanedUnstructuredNoiseMGT,WMtcUnstructNoise-WMtctsCleanedUnstructNoise,CSFtcUnstructNoise-CSFtctsCleanedUnstructNoise,[outprefix '_5-14_' steps{5} '-' steps{14}]); %original unstructured noise - temporal ICA noise and sleep cleaned unstructured noise
            plotgray(tCleanedTCS-tsCleanedTCS,mvm,HR,RVT,RawPhysio,tCleanedMGT-tsCleanedMGT,WMtctClean-WMtctsClean,CSFtctClean-CSFtctsClean,[outprefix '_10-13_' steps{10} '-' steps{13}]); %Effect of temporal ICA sleep regression 
            plotgray(tsCleanedMGTRtcs,mvm,HR,RVT,RawPhysio,single(zeros(length(tsCleanedMGT),1)),WMtctsCleanMGT,CSFtctsCleanMGT,[outprefix '_19_' steps{19}]); %tsCleaned data after GSR with unstructured noise
            plotgray(tsCleanedMGTRtcs-tsCleanedUnstructuredNoiseMGTRtcs,mvm,HR,RVT,RawPhysio,single(zeros(length(tsCleanedMGT),1)),WMtctsCleanMGT,CSFtctsCleanMGT,[outprefix '_19-20_' steps{19} '-' steps{20}]); %tsCleaned data after GSR without unstructured noise
        end
    end
    
    if ~strcmp(Physio,'FALSE')
        plotgray(CleanedTCS-PhysioCleanedTCS,mvm,HR,RVT,RawPhysio,CleanedMGT-PhysioCleanedMGT,WMtcClean-WMPhysio,CSFtcClean-CSFPhysio,[outprefix '_4-12_' steps{4} '-' steps{12}]); %Effect of Physio noise regression         
        plotgray(PhysioCleanedTCS,mvm,HR,RVT,RawPhysio,PhysioCleanedMGT,WMPhysio,CSFPhysio,[outprefix '_12_' steps{12}]); %Physio regressed data with unstructured noise
        plotgray(PhysioCleanedTCS-UnstructNoiseTCS,mvm,HR,RVT,RawPhysio,PhysioCleanedMGT,WMPhysio,CSFPhysio,[outprefix '_12-5_' steps{12} '-' steps{5}]); %Physio regressed data without unstructured noise            
    end
end

%% These not kept up to date -- Too many plots! %%
% Generate "grayplots" of the various stages and differences between stages using a 
% scaling in z-score
%if ~strcmp(WM,'NONE') && ~strcmp(CSF,'NONE')
%    steps = {'OrigTCS','HighPassTCS','PostMotionTCS','CleanedTCS',...
%        'UnstructNoiseTCS','WMCleanedTCS','CSFCleanedTCS','WMCSFCleanedTCS','StructNoiseTCS','tCleanedTCS','tcleanedUnstructNoiseTCS','PhysioCleanedTCS','tsCleanedTCS','tscleanedUnstructNoiseTCS'};
%    plotgrayz(OrigTCS,mvm,HR,RVT,RawPhysio,OrigMGT,WMtcOrig,CSFtcOrig,[outprefix '_1_' steps{1}]); %Original data with unstructured noise
%    plotgrayz(OrigTCS-UnstructNoiseTCS,mvm,HR,RVT,RawPhysio,OrigMGT,WMtcOrig,CSFtcOrig,[outprefix '_1-5_' steps{1} '-' steps{5}]); %Original data without unstructured noise
%    plotgrayz(OrigTCS-HighPassTCS,mvm,HR,RVT,RawPhysio,OrigMGT-HighPassMGT,WMtcOrig-WMtcHP,CSFtcOrig-CSFtcHP,[outprefix '_1-2_' steps{1} '-' steps{2}]); %Effect of highpass filter
%    plotgrayz(HighPassTCS,mvm,HR,RVT,RawPhysio,HighPassMGT,WMtcHP,CSFtcHP,[outprefix '_2_' steps{2}]); %HP with unstructured noise
%    plotgrayz(HighPassTCS-UnstructNoiseTCS,mvm,HR,RVT,RawPhysio,HighPassMGT,WMtcHP,CSFtcHP,[outprefix '_2-5_' steps{2} '-' steps{5}]); %HP without unstructured noise
%    plotgrayz(HighPassTCS-PostMotionTCS,mvm,HR,RVT,RawPhysio,HighPassMGT-PostMotionMGT,WMtcHP-WMtcPM,CSFtcHP-CSFtcPM,[outprefix '_2-3_' steps{2} '-' steps{3}]); %Effect of motion regression 
%    plotgrayz(PostMotionTCS,mvm,HR,RVT,RawPhysio,PostMotionMGT,WMtcPM,CSFtcPM,[outprefix '_3_' steps{3}]); %Motion Regression with unstructured noise
%    plotgrayz(PostMotionTCS-UnstructNoiseTCS,mvm,HR,RVT,RawPhysio,PostMotionMGT,WMtcPM,CSFtcPM,[outprefix '_3-5_' steps{3} '-' steps{5}]); %Motion Regression without unstructured noise
%    plotgrayz(PostMotionTCS-CleanedTCS,mvm,HR,RVT,RawPhysio,PostMotionMGT-CleanedMGT,WMtcPM-WMtcClean,CSFtcPM-CSFtcClean,[outprefix '_3-4_' steps{3} '-' steps{4}]); %Effect of structured noise regression 
%    plotgrayz(CleanedTCS,mvm,HR,RVT,RawPhysio,CleanedMGT,WMtcClean,CSFtcClean,[outprefix '_4_' steps{4}]); %Cleaned data with unstructured noise
%    plotgrayz(CleanedTCS-UnstructNoiseTCS,mvm,HR,RVT,RawPhysio,CleanedMGT,WMtcClean,CSFtcClean,[outprefix '_4-5_' steps{4} '-' steps{5}]); %Cleaned data without unstructured noise
%    plotgrayz(UnstructNoiseTCS,mvm,HR,RVT,RawPhysio,UnstructNoiseMGT,WMtcUnstructNoise,CSFtcUnstructNoise,[outprefix '_5_' steps{5}]); %Unstructured noise only
%    plotgrayz(WMCleanedTCS,mvm,HR,RVT,RawPhysio,WMCleanedMGT,WMWM,CSFWM,[outprefix '_6_' steps{6}]); %WM regressed data with unstructured noise
%    plotgrayz(WMCleanedTCS-UnstructNoiseTCS,mvm,HR,RVT,RawPhysio,WMCleanedMGT,WMWM,CSFWM,[outprefix '_6-5_' steps{6} '-' steps{5}]); %WM regressed data without unstructured noise
%    plotgrayz(CleanedTCS-WMCleanedTCS,mvm,HR,RVT,RawPhysio,CleanedMGT-WMCleanedMGT,WMtcClean-WMWM,CSFtcClean-CSFWM,[outprefix '_4-6_' steps{4} '-' steps{6}]); %Effect of WM regression
%    plotgrayz(CSFCleanedTCS,mvm,HR,RVT,RawPhysio,CSFCleanedMGT,WMCSF,CSFCSF,[outprefix '_7_' steps{7}]); %WM regressed data with unstructured noise
%    plotgrayz(CSFCleanedTCS-UnstructNoiseTCS,mvm,HR,RVT,RawPhysio,CSFCleanedMGT,WMCSF,CSFCSF,[outprefix '_7-5_' steps{7} '-' steps{5}]); %WM regressed data without unstructured noise
%    plotgrayz(CleanedTCS-CSFCleanedTCS,mvm,HR,RVT,RawPhysio,CleanedMGT-CSFCleanedMGT,WMtcClean-WMCSF,CSFtcClean-CSFCSF,[outprefix '_4-7_' steps{4} '-' steps{7}]); %Effect of CSF regression
%    plotgrayz(WMCSFCleanedTCS,mvm,HR,RVT,RawPhysio,WMCSFCleanedMGT,WMWM,CSFCSF,[outprefix '_8_' steps{8}]); %WM regressed data with unstructured noise
%    plotgrayz(WMCSFCleanedTCS-UnstructNoiseTCS,mvm,HR,RVT,RawPhysio,WMCSFCleanedMGT,WMWM,CSFCSF,[outprefix '_8-5_' steps{8} '-' steps{5}]); %WM regressed data without unstructured noise
%    plotgrayz(CleanedTCS-WMCSFCleanedTCS,mvm,HR,RVT,RawPhysio,CleanedMGT-WMCSFCleanedMGT,WMtcClean-WMWM,CSFtcClean-CSFCSF,[outprefix '_4-8_' steps{4} '-' steps{8}]); %Effect of CSF regression
%    plotgrayz(StructNoiseTCS,mvm,HR,RVT,RawPhysio,StructNoiseMGT,WMtcStructNoise,CSFtcStructNoise,[outprefix '_9_' steps{9}]); %Structured noise only

%    if ~strcmp(tICAtNoiseList,'NONE')
%        plotgrayz(CleanedTCS-tCleanedTCS,mvm,HR,RVT,RawPhysio,CleanedMGT-tCleanedMGT,WMtcClean-WMtctClean,CSFtcClean-CSFtctClean,[outprefix '_4-10_' steps{4} '-' steps{10}]); %Effect of temporal ICA structured noise regression 
%        plotgrayz(tCleanedTCS,mvm,HR,RVT,RawPhysio,tCleanedMGT,WMtctClean,CSFtctClean,[outprefix '_10_' steps{10}]); %temporal ICA Cleaned data with unstructured noise
%        plotgrayz(tCleanedTCS-tCleanedUnstructuredNoiseTCS,mvm,HR,RVT,RawPhysio,tCleanedMGT,WMtctClean,CSFtctClean,[outprefix '_10-11_' steps{10} '-' steps{11}]); %temporal ICA noise cleaned data without unstructured noise   
%        plotgrayz(tCleanedUnstructuredNoiseTCS,mvm,HR,RVT,RawPhysio,tCleanedUnstructuredNoiseMGT,WMtctCleanedUnstructNoise,CSFtctCleanedUnstructNoise,[outprefix '_11_' steps{11}]); %temporal ICA noise cleaned unstructured noise
%        plotgrayz(UnstructNoiseTCS-tCleanedUnstructuredNoiseTCS,mvm,HR,RVT,RawPhysio,UnstructNoiseMGT-tCleanedUnstructuredNoiseMGT,WMtcUnstructNoise-WMtctCleanedUnstructNoise,CSFtcUnstructNoise-CSFtctCleanedUnstructNoise,[outprefix '_5-11_' steps{5} '-' steps{11}]); %original unstructured noise - temporal ICA noise cleaned unstructured noise
%        if ~strcmp(tICAtsNoiseList,'NONE')
%            plotgrayz(CleanedTCS-tsCleanedTCS,mvm,HR,RVT,RawPhysio,CleanedMGT-tsCleanedMGT,WMtcClean-WMtctsClean,CSFtcClean-CSFtctsClean,[outprefix '_4-13_' steps{4} '-' steps{13}]); %Effect of temporal ICA structured noise and sleep component regression 
%            plotgrayz(tsCleanedTCS,mvm,HR,RVT,RawPhysio,tsCleanedMGT,WMtctsClean,CSFtctsClean,[outprefix '_13_' steps{13}]); %temporal ICA noise and sleep cleaned data with unstructured noise
%            plotgrayz(tsCleanedTCS-tsCleanedUnstructuredNoiseTCS,mvm,HR,RVT,RawPhysio,tsCleanedMGT,WMtctsClean,CSFtctsClean,[outprefix '_13-14_' steps{13} '-' steps{14}]); %temporal ICA noise and sleep cleaned data without unstructured noise   
%            plotgrayz(tsCleanedUnstructuredNoiseTCS,mvm,HR,RVT,RawPhysio,tsCleanedUnstructuredNoiseMGT,WMtctsCleanedUnstructNoise,CSFtctsCleanedUnstructNoise,[outprefix '_14_' steps{14}]); %temporal ICA noise and sleep cleaned unstructured noise
%            plotgrayz(UnstructNoiseTCS-tsCleanedUnstructuredNoiseTCS,mvm,HR,RVT,RawPhysio,UnstructNoiseMGT-tsCleanedUnstructuredNoiseMGT,WMtcUnstructNoise-WMtctsCleanedUnstructNoise,CSFtcUnstructNoise-CSFtctsCleanedUnstructNoise,[outprefix '_5-14_' steps{5} '-' steps{14}]); %original unstructured noise - temporal ICA noise and sleep cleaned unstructured noise
%            plotgrayz(tCleanedTCS-tsCleanedTCS,mvm,HR,RVT,RawPhysio,tCleanedMGT-tsCleanedMGT,WMtctClean-WMtctsClean,CSFtctClean-CSFtctsClean,[outprefix '_10-13_' steps{10} '-' steps{13}]); %Effect of temporal ICA sleep regression 
%        end
%    end
    
%    if ~strcmp(Physio,'FALSE')
%        plotgrayz(CleanedTCS-PhysioCleanedTCS,mvm,HR,RVT,RawPhysio,CleanedMGT-PhysioCleanedMGT,WMtcClean-WMPhysio,CSFtcClean-CSFPhysio,[outprefix '_4-12_' steps{4} '-' steps{12}]); %Effect of Physio noise regression         
%        plotgrayz(PhysioCleanedTCS,mvm,HR,RVT,RawPhysio,PhysioCleanedMGT,WMPhysio,CSFPhysio,[outprefix '_12_' steps{12}]); %Physio regressed data with unstructured noise
%        plotgrayz(PhysioCleanedTCS-UnstructNoiseTCS,mvm,HR,RVT,RawPhysio,PhysioCleanedMGT,WMPhysio,CSFPhysio,[outprefix '_12-5_' steps{12} '-' steps{5}]); %Physio regressed data without unstructured noise
%   end
%end

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
if ~strcmp(tICAtNoiseList,'NONE')
    tCleanedMGTVarVsBOLDVarRatio = makeRatio(tCleanedMGTVar,BOLDVar);
    tCleanedMGTVarVstCleanedBOLDVarRatio = makeRatio(tCleanedMGTVar,tCleanedBOLDVar);
    tStructNoiseVarRatio=makeRatio(tStructuredNoiseVar,OrigVar);
    tStructNoiseVarVsBOLDVarRatio=makeRatio(tStructuredNoiseVar,BOLDVar);
    tCleanedMGTVarRatio = makeRatio(tCleanedMGTVar,OrigVar);
    tCleanedBOLDVarRatio = makeRatio(tCleanedBOLDVar,OrigVar);
    tNoiseMGTVarRatio = makeRatio(tNoiseMGTVar,OrigVar);
    tNoiseMGTVarVsCleanedMGTVarRatio = makeRatio(tNoiseMGTVar,max(CleanedMGTVar,1));
    if ~strcmp(tICAtsNoiseList,'NONE')
        tsCleanedMGTVarVsBOLDVarRatio = makeRatio(tsCleanedMGTVar,BOLDVar);
        tsCleanedMGTVarVstsCleanedBOLDVarRatio = makeRatio(tsCleanedMGTVar,tsCleanedBOLDVar);
        tsStructNoiseVarRatio=makeRatio(tsStructuredNoiseVar,OrigVar);
        tsStructNoiseVarVsBOLDVarRatio=makeRatio(tsStructuredNoiseVar,BOLDVar);
        tsCleanedMGTVarRatio = makeRatio(tsCleanedMGTVar,OrigVar);
        tsCleanedBOLDVarRatio = makeRatio(tsCleanedBOLDVar,OrigVar);
        tsNoiseMGTVarRatio = makeRatio(tsNoiseMGTVar,OrigVar);
        tsNoiseMGTVarVsCleanedMGTVarRatio = makeRatio(tsNoiseMGTVar,max(CleanedMGTVar,1));
    end
end
if ~strcmp(Physio,'FALSE')
    PhysioVarVsBOLDVarRatio = makeRatio(PhysioVar,BOLDVar);
    PhysioCleanedMGTVarVsPhysioCleanedBOLDVarRatio = makeRatio(PhysioCleanedMGTVar,PhysioCleanedBOLDVar);
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
if ~strcmp(tICAtNoiseList,'NONE')
    meantStructuredNoiseVar = mean(tStructuredNoiseVar);
    meantCleanedMGTVarVsBOLDVarRatio = mean(tCleanedMGTVarVsBOLDVarRatio);
    meantCleanedBOLDVar = mean(tCleanedBOLDVar);
    meantCleanedMGTbeta = mean(tCleanedMGTbeta);
    meantCleanedMGTVar = mean(tCleanedMGTVar);
    meantCleanedMGTVarVstCleanedBOLDVarRatio = mean(tCleanedMGTVarVstCleanedBOLDVarRatio);
    meantCleanedUnstructuredNoiseVar=mean(tCleanedUnstructuredNoiseVar);
    meantStructNoiseVarRatio=mean(tStructNoiseVarRatio);
    meantStructNoiseVarVsBOLDVarRatio=mean(tStructNoiseVarVsBOLDVarRatio);
    meantCleanedMGTVarRatio=mean(tCleanedMGTVarRatio);
    meantCleanedBOLDVarRatio=mean(tCleanedBOLDVarRatio);
    meantNoiseMGTVarRatio=mean(tNoiseMGTVarRatio);
    meantNoiseMGTVarVsCleanedMGTVarRatio=mean(tNoiseMGTVarVsCleanedMGTVarRatio);
    meantNoiseMGTVar=mean(tNoiseMGTVar);
    if ~strcmp(tICAtsNoiseList,'NONE')
        meantsStructuredNoiseVar = mean(tsStructuredNoiseVar);
        meantsCleanedMGTVarVsBOLDVarRatio = mean(tsCleanedMGTVarVsBOLDVarRatio);
        meantsCleanedBOLDVar = mean(tsCleanedBOLDVar);
        meantsCleanedMGTbeta = mean(tsCleanedMGTbeta);
        meantsCleanedMGTVar = mean(tsCleanedMGTVar);
        meantsCleanedMGTVarVstsCleanedBOLDVarRatio = mean(tsCleanedMGTVarVstsCleanedBOLDVarRatio);
        meantsCleanedUnstructuredNoiseVar=mean(tsCleanedUnstructuredNoiseVar);
        meantsStructNoiseVarRatio=mean(tsStructNoiseVarRatio);
        meantsStructNoiseVarVsBOLDVarRatio=mean(tsStructNoiseVarVsBOLDVarRatio);
        meantsCleanedMGTVarRatio=mean(tsCleanedMGTVarRatio);
        meantsCleanedBOLDVarRatio=mean(tsCleanedBOLDVarRatio);
        meantsNoiseMGTVarRatio=mean(tsNoiseMGTVarRatio);
        meantsNoiseMGTVarVsCleanedMGTVarRatio=mean(tsNoiseMGTVarVsCleanedMGTVarRatio);
        meantsNoiseMGTVar=mean(tsNoiseMGTVar);
    end
end
if ~strcmp(Physio,'FALSE')
    meanPhysiobeta = mean(betaPhysio);
    meanPhysioVar = mean(PhysioVar);
    meanPhysioVarVsBOLDVarRatio = mean(PhysioVarVsBOLDVarRatio);
    meanPhysioCleanedBOLDVar = mean(PhysioCleanedBOLDVar);
    meanPhysioCleanedMGTbeta = mean(PhysioCleanedMGTbeta);
    meanPhysioCleanedMGTVar = mean(PhysioCleanedMGTVar);
    meanPhysioCleanedMGTVarVsPhysioCleanedBOLDVarRatio = mean(PhysioCleanedMGTVarVsPhysioCleanedBOLDVarRatio);
end

% Calculate DVARS (RMS of the backward difference
DV = diff(transpose(UnstructNoiseTCS)); % Backward Difference
MedDV=median(rms(DV,2));
DV = rms(DV,2)-MedDV; % RMS (w/ median centering)
DV = [0;DV]; % Zero-pad to original timepoints
DVDips5=sum(DV>5)+sum(DV<-5);
DVDips10=sum(DV>10)+sum(DV<-10);
DVDips15=sum(DV>15)+sum(DV<-15);
DVDips20=sum(DV>20)+sum(DV<-20);
DVDips25=sum(DV>25)+sum(DV<-25);
DVDips50=sum(DV>50)+sum(DV<-50);

% Calculate FD
FD = sum(abs(cat(2,mvm(:,7:9),(50*pi/180)*mvm(:,10:12))),2);
MeanFD=mean(FD);

% Save out variance normalization image for MSMALL/SingleSubjectConcat/MIGP
%if SaveVarianceNormalizationImage
fprintf('%s - Saving variance normalization image [i.e., sqrt(UnstructNoiseVar)]\n',func_name);
VarianceNormalizationImage=BO;
VarianceNormalizationImage.cdata=sqrt(UnstructNoiseVar); %%%Possibly an error, perhaps should be a "bias field" instead of a full subjectwise normalization.  This probably explains my issues getting %BOLD units to work for resting state
if FixVN == 1
  VarianceNormalizationImage.cdata=VarianceNormalizationImage.cdata.*real_bias.cdata;
end
MeanVN=mean(VarianceNormalizationImage.cdata);
ciftisavereset(VarianceNormalizationImage,[outprefix '_vn.dscalar.nii'],WBC);
%end

% Save out grayordinates TCS for tICA cleaned data
if ~strcmp(tICAtNoiseList,'NONE') 
    tCleanedBO=BO;
    tCleanedBO.cdata=tCleanedTCS;
    tCleanedBO.cdata=tCleanedBO.cdata+repmat(MEAN,1,size(BO.cdata,tpDim));
    if FixVN == 1
        tCleanedBO.cdata=tCleanedBO.cdata.*repmat(real_bias.cdata,1,size(BO.cdata,tpDim));
    end
    if ~strcmp(bcmode,'NONE');
        tCleanedBO.cdata=tCleanedBO.cdata./repmat(bias.cdata,1,size(BO.cdata,tpDim));
    end
    ciftisave(tCleanedBO,[inputdtseries '_hp' num2str(hp) '_clean_tclean.dtseries.nii'],WBC);
    if ~strcmp(tICAtsNoiseList,'NONE') 
        tsCleanedBO=BO;
        tsCleanedBO.cdata=tsCleanedTCS;
        tsCleanedBO.cdata=tsCleanedBO.cdata+repmat(MEAN,1,size(BO.cdata,tpDim));
        if FixVN == 1
            tsCleanedBO.cdata=tsCleanedBO.cdata.*repmat(real_bias.cdata,1,size(BO.cdata,tpDim));
        end
        if ~strcmp(bcmode,'NONE');
            tsCleanedBO.cdata=tsCleanedBO.cdata./repmat(bias.cdata,1,size(BO.cdata,tpDim));
        end
        ciftisave(tsCleanedBO,[inputdtseries '_hp' num2str(hp) '_clean_tsclean.dtseries.nii'],WBC);
    end
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
    if ~strcmp(tICAtNoiseList,'NONE')
        statscifti.cdata = cat(2,statscifti.cdata,[tStructuredNoiseVar tCleanedMGTVarVsBOLDVarRatio tCleanedBOLDVar tCleanedMGTbeta tCleanedMGTVar tCleanedMGTVarVstCleanedBOLDVarRatio tCleanedUnstructuredNoiseVar tStructNoiseVarRatio tStructNoiseVarVsBOLDVarRatio tCleanedMGTVarRatio tCleanedBOLDVarRatio tNoiseMGTVarRatio tNoiseMGTVarVsCleanedMGTVarRatio tNoiseMGTVar]);
        if ~strcmp(tICAtsNoiseList,'NONE')
            statscifti.cdata = cat(2,statscifti.cdata,[tsStructuredNoiseVar tsCleanedMGTVarVsBOLDVarRatio tsCleanedBOLDVar tsCleanedMGTbeta tsCleanedMGTVar tsCleanedMGTVarVstsCleanedBOLDVarRatio tsCleanedUnstructuredNoiseVar tsStructNoiseVarRatio tsStructNoiseVarVsBOLDVarRatio tsCleanedMGTVarRatio tsCleanedBOLDVarRatio tsNoiseMGTVarRatio tsNoiseMGTVarVsCleanedMGTVarRatio tsNoiseMGTVar]);
        end
    end
    if ~strcmp(Physio,'FALSE')
        statscifti.cdata = cat(2,statscifti.cdata,[single(ones(length(MEAN),1)) PhysioVar PhysioVarVsBOLDVarRatio PhysioCleanedBOLDVar PhysioCleanedMGTbeta PhysioCleanedMGTVar PhysioCleanedMGTVarVsPhysioCleanedBOLDVarRatio]);
    else
        statscifti.cdata = cat(2,statscifti.cdata,single(zeros(length(MEAN),7)));
    end
    ciftisave(statscifti,[outprefix '_' outstring '.dtseries.nii'],WBC);

    betascifti = BO;
    betaMotion=(pinv(Motiontc) * OrigTCS')';
    betaNamesMotion=sprintf('X_Trans\nY_Trans\nZ_Trans\nX_Rot\nY_Rot\nZ_Rot\ndX_Trans\ndY_Trans\ndZ_Trans\ndX_Rot\ndY_Rot\ndZ_Rot\nX_Trans^2\nY_Trans^2\nZ_Trans^2\nX_Rot^2\nY_Rot^2\nZ_Rot^2\ndX_Trans^2\ndY_Trans^2\ndZ_Trans^2\ndX_Rot^2\ndY_Rot^2\ndZ_Rot^2');

    if strcmp(PhysioSwitch,'On');
        betaNamesPhysio='EV1';
        for i=2:NumPhysioEVs
            betaNamesPhysio=sprintf('%s\n%s',betaNamesPhysio,['EV' num2str(i)]);
        end
        if ~strcmp(Physio,'FALSE')
            betaNamesPhysio='EV1';
            for i=2:NumPhysioEVs
                betaNamesPhysio=sprintf('%s\n%s',betaNamesPhysio,['EV' num2str(i)]);
            end
            betaPhysio=(pinv(PhysiotcOrig) * OrigTCS')';
            betaAll=(pinv([Motiontc PhysiotcOrig]) * OrigTCS')';
        else
            betaPhysio=single(zeros(length(BO.cdata),NumPhysioEVs));
            betaAll=single(zeros(length(BO.cdata),NumPhysioEVs+size(Motiontc,2)));
        end
        betaNames=sprintf('%s\n%s\n%s\n%s',betaNamesMotion,betaNamesPhysio,betaNamesMotion,betaNamesPhysio);
        betascifti.cdata=[betaMotion betaPhysio betaAll];
    else
        betaNames=sprintf('%s\n%s\n%s\n%s',betaNamesMotion);
        betascifti.cdata=betaMotion;
    end
    fid = fopen([outprefix '_NameFile.txt'],'w');
    fprintf(fid,'%s',betaNames);
    fclose(fid);
    ciftisave(betascifti,[outprefix '_' outstring '_betas.dtseries.nii'],WBC);
    unix([WBC ' -cifti-convert-to-scalar ' outprefix '_' outstring '_betas.dtseries.nii ROW ' outprefix '_' outstring '_betas.dscalar.nii -name-file ' outprefix '_NameFile.txt']);
    unix(['rm ' outprefix '_NameFile.txt ' outprefix '_' outstring '_betas.dtseries.nii']);
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
  if ~strcmp(Physio,'FALSE')
      savePTCS(PhysioCleanedTCS,dlabel,outprefix,'PhysioCleaned',ptTemplate,WBC);
  end    
  if ~strcmp(tICAtNoiseList,'NONE')
      savePTCS(tCleanedTCS,dlabel,outprefix,'tCleaned',ptTemplate,WBC);
      savePTCS(tNoiseTCS,dlabel,outprefix,'tNoise',ptTemplate,WBC);
      savePTCS(tCleanedUnstructuredNoiseTCS,dlabel,outprefix,'tCleanedUnstructNoise',ptTemplate,WBC);
      if ~strcmp(tICAtsNoiseList,'NONE')
          savePTCS(tsCleanedTCS,dlabel,outprefix,'tsCleaned',ptTemplate,WBC);
          savePTCS(tsNoiseTCS,dlabel,outprefix,'tsNoise',ptTemplate,WBC);
          savePTCS(tsCleanedUnstructuredNoiseTCS,dlabel,outprefix,'tsCleanedUnstructNoise',ptTemplate,WBC);
      end
  end
  
  % Parcellated "MGT" regressed time series from each stage
  savePTCS(OrigMGTRtcs,dlabel,outprefix,'OrigMGTR',ptTemplate,WBC);
  savePTCS(HighPassMGTRtcs,dlabel,outprefix,'HighPassMGTR',ptTemplate,WBC);
  savePTCS(PostMotionMGTRtcs,dlabel,outprefix,'PostMotionMGTR',ptTemplate,WBC);
  savePTCS(CleanedMGTRtcs,dlabel,outprefix,'CleanedMGTR',ptTemplate,WBC);
  savePTCS(UnstructNoiseMGTRtcs,dlabel,outprefix,'UnstructNoiseMGTR',ptTemplate,WBC);
  savePTCS(NoiseMGTRtcs,dlabel,outprefix,'NoiseMGTR',ptTemplate,WBC);
  if ~strcmp(Physio,'FALSE')
      savePTCS(PhysioCleanedMGTRtcs,dlabel,outprefix,'PhysioCleanedMGTR',ptTemplate,WBC);
  end    
  if ~strcmp(tICAtNoiseList,'NONE')
      savePTCS(tUnstructNoiseMGTRtcs,dlabel,outprefix,'tUnstructNoiseMGTR',ptTemplate,WBC);
      savePTCS(tNoiseMGTRtcs,dlabel,outprefix,'tNoiseMGTR',ptTemplate,WBC);
      savePTCS(tCleanedUnstructuredNoiseMGTRtcs,dlabel,outprefix,'tCleanedUnstructNoiseMGTR',ptTemplate,WBC);
      if ~strcmp(tICAtsNoiseList,'NONE')
          savePTCS(tsUnstructNoiseMGTRtcs,dlabel,outprefix,'tsUnstructNoiseMGTR',ptTemplate,WBC);
          savePTCS(tsNoiseMGTRtcs,dlabel,outprefix,'tsNoiseMGTR',ptTemplate,WBC);
          savePTCS(tsCleanedUnstructuredNoiseMGTRtcs,dlabel,outprefix,'tsCleanedUnstructNoiseMGTR',ptTemplate,WBC);
      end
  end
end

if SaveMGT
  dlmwrite([outprefix '_OrigMGT.txt'],OrigMGT);
  dlmwrite([outprefix '_HighPassMGT.txt'],HighPassMGT);
  dlmwrite([outprefix '_PostMotionMGT.txt'],PostMotionMGT);
  dlmwrite([outprefix '_CleanedMGT.txt'],CleanedMGT);
  dlmwrite([outprefix '_UnstructNoiseMGT.txt'],UnstructNoiseMGT);
  dlmwrite([outprefix '_NoiseMGT.txt'],NoiseMGT);
  if ~strcmp(Physio,'FALSE')
      dlmwrite([outprefix '_PhysioCleanedMGT.txt'],PhysioCleanedMGT);
  end    
  if ~strcmp(tICAtNoiseList,'NONE')
      dlmwrite([outprefix '_tCleanedMGT.txt'],tCleanedMGT);
      dlmwrite([outprefix '_tNoiseMGT.txt'],tNoiseMGT);
      dlmwrite([outprefix '_tCleanedUnstructuredNoiseMGT.txt'],tCleanedUnstructuredNoiseMGT);
      if ~strcmp(tICAtsNoiseList,'NONE')
          dlmwrite([outprefix '_tsCleanedMGT.txt'],tsCleanedMGT);
          dlmwrite([outprefix '_tsNoiseMGT.txt'],tsNoiseMGT);
          dlmwrite([outprefix '_tsCleanedUnstructuredNoiseMGT.txt'],tsCleanedUnstructuredNoiseMGT);
      end
  end
end

if SaveFDDVARS
  dlmwrite([outprefix '_FD.txt'],FD); 
  dlmwrite([outprefix '_OrigDVARS.txt'],[0;rms(diff(transpose(OrigTCS)),2)-median(rms(diff(transpose(OrigTCS)),2))]);
  dlmwrite([outprefix '_HighPassDVARS.txt'],[0;rms(diff(transpose(HighPassTCS)),2)-median(rms(diff(transpose(HighPassTCS)),2))]);
  dlmwrite([outprefix '_PostMotionDVARS.txt'],[0;rms(diff(transpose(PostMotionTCS)),2)-median(rms(diff(transpose(PostMotionTCS)),2))]);
  dlmwrite([outprefix '_CleanedDVARS.txt'],[0;rms(diff(transpose(CleanedTCS)),2)-median(rms(diff(transpose(CleanedTCS)),2))]);
  dlmwrite([outprefix '_Cleaned-UnstructNoiseDVARS.txt'],[0;rms(diff(transpose(CleanedTCS-UnstructNoiseTCS)),2)-median(rms(diff(transpose(CleanedTCS-UnstructNoiseTCS)),2))]);
  dlmwrite([outprefix '_UnstructNoiseDVARS.txt'],[0;rms(diff(transpose(UnstructNoiseTCS)),2)-median(rms(diff(transpose(UnstructNoiseTCS)),2))]);
  dlmwrite([outprefix '_NoiseDVARS.txt'],[0;rms(diff(transpose(StructNoiseTCS)),2)-median(rms(diff(transpose(StructNoiseTCS)),2))]);
  if ~strcmp(Physio,'FALSE')
      dlmwrite([outprefix '_PhysioCleanedDVARS.txt'],[0;rms(diff(transpose(PhysioCleanedTCS)),2)-median(rms(diff(transpose(PhysioCleanedTCS)),2))]);
  end    
  if ~strcmp(tICAtNoiseList,'NONE')
      dlmwrite([outprefix '_tCleanedDVARS.txt'],[0;rms(diff(transpose(tCleanedTCS)),2)-median(rms(diff(transpose(tCleanedTCS)),2))]);
      dlmwrite([outprefix '_tCleaned-tCleanedUnstructuredNoiseDVARS.txt'],[0;rms(diff(transpose(tCleanedTCS-tCleanedUnstructuredNoiseTCS)),2)-median(rms(diff(transpose(tCleanedTCS-tCleanedUnstructuredNoiseTCS)),2))]);
      dlmwrite([outprefix '_tNoiseDVARS.txt'],[0;rms(diff(transpose(tNoiseTCS)),2)-median(rms(diff(transpose(tNoiseTCS)),2))]);
      dlmwrite([outprefix '_tCleanedUnstructuredNoiseDVARS.txt'],[0;rms(diff(transpose(tCleanedUnstructuredNoiseTCS)),2)-median(rms(diff(transpose(tCleanedUnstructuredNoiseTCS)),2))]);
      if ~strcmp(tICAtsNoiseList,'NONE')
          dlmwrite([outprefix '_tsCleanedDVARS.txt'],[0;rms(diff(transpose(tsCleanedTCS)),2)-median(rms(diff(transpose(tsCleanedTCS)),2))]);
          dlmwrite([outprefix '_tsCleaned-tsCleanedUnstructuredNoiseDVARS.txt'],[0;rms(diff(transpose(tsCleanedTCS-tsCleanedUnstructuredNoiseTCS)),2)-median(rms(diff(transpose(tsCleanedTCS-tsCleanedUnstructuredNoiseTCS)),2))]);
          dlmwrite([outprefix '_tsNoiseDVARS.txt'],[0;rms(diff(transpose(tsNoiseTCS)),2)-median(rms(diff(transpose(tsNoiseTCS)),2))]);
          dlmwrite([outprefix '_tsCleanedUnstructuredNoiseDVARS.txt'],[0;rms(diff(transpose(tsCleanedUnstructuredNoiseTCS)),2)-median(rms(diff(transpose(tsCleanedUnstructuredNoiseTCS)),2))]);
      end
  end
end

if ~strcmp(WM,'NONE')
    dlmwrite([outprefix '_CleanedWMtc.txt'],WMtcClean);
    dlmwrite([outprefix '_tCleanedWMtc.txt'],WMtctClean);
end
if ~strcmp(CSF,'NONE')
    dlmwrite([outprefix '_CleanedCSFtc.txt'],CSFtcClean);
    dlmwrite([outprefix '_tCleanedCSFtc.txt'],CSFtctClean);
end
if ~strcmp(Physio,'FALSE')
    dlmwrite([outprefix '_CleanedPhysiotc.txt'],PhysiotcClean);
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

if ~strcmp(tICAtNoiseList,'NONE')
  tICAStr = 'tStructuredNoiseVar,tCleanedMGTVarVsBOLDVarRatio,tCleanedBOLDVar,tCleanedMGTbeta,tCleanedMGTVar,tCleanedMGTVarVstCleanedBOLDVarRatio,tCleanedUnstructuredNoiseVar,tStructNoiseVarRatio,tStructNoiseVarVsBOLDVarRatio,tCleanedMGTVarRatio,tCleanedBOLDVarRatio,tNoiseMGTVarRatio,tNoiseMGTVarVsCleanedMGTVarRatio,tNoiseMGTVar';
  varNames = sprintf('%s,%s',varNames,tICAStr);
  if ~strcmp(tICAtsNoiseList,'NONE')
      tsICAStr = 'tsStructuredNoiseVar,tsCleanedMGTVarVsBOLDVarRatio,tsCleanedBOLDVar,tsCleanedMGTbeta,tsCleanedMGTVar,tsCleanedMGTVarVstsCleanedBOLDVarRatio,tsCleanedUnstructuredNoiseVar,tsStructNoiseVarRatio,tsStructNoiseVarVsBOLDVarRatio,tsCleanedMGTVarRatio,tsCleanedBOLDVarRatio,tsNoiseMGTVarRatio,tsNoiseMGTVarVsCleanedMGTVarRatio,tsNoiseMGTVar';
      varNames = sprintf('%s,%s',varNames,tsICAStr);
    end
end

if ~strcmp(Physio,'FALSE')
  PhysioStr = 'PhysioPresent,PhysioVar,PhysioVarVsBOLDVarRatio,PhysioCleanedBOLDVar,PhysioCleanedMGTbeta,PhysioCleanedMGTVar,PhysioCleanedMGTVarVsPhysioCleanedBOLDVarRatio';
  varNames = sprintf('%s,%s',varNames,PhysioStr);
end


DVDipsStr = 'DVDips5,DVDips10,DVDips15,DVDips20,DVDips25,DVDips50';
varNames = sprintf('%s,%s',varNames,DVDipsStr);

varNames = sprintf('%s,%s',varNames,'MedDV');

varNames = sprintf('%s,%s',varNames,'MeanFD');

varNames = sprintf('%s,%s',varNames,'RVTvar');

varNames = sprintf('%s,%s',varNames,'MeanVN');

if ~strcmp(tICAtNoiseList,'NONE')
    for i=1:size(tICAtcs,2)
        ICAName=[num2str(i) 'vnICA'];
        varNames = sprintf('%s,%s',varNames,ICAName);
    end
end

if ~strcmp(tICAtNoiseList,'NONE')
    for i=1:size(tICAtcs,2)
        ICAName=[num2str(i) 'ICA'];
        varNames = sprintf('%s,%s',varNames,ICAName);
    end
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
if ~strcmp(tICAtNoiseList,'NONE')
    fprintf(fid,',%.2f,%.5f,%.2f,%.3f,%.2f,%.5f,%.2f,%.5f,%.5f,%.5f,%.5f,%.5f,%.5f,%.2f',meantStructuredNoiseVar,meantCleanedMGTVarVsBOLDVarRatio,meantCleanedBOLDVar,meantCleanedMGTbeta,meantCleanedMGTVar,meantCleanedMGTVarVstCleanedBOLDVarRatio,meantCleanedUnstructuredNoiseVar,meantStructNoiseVarRatio,meantStructNoiseVarVsBOLDVarRatio,meantCleanedMGTVarRatio,meantCleanedBOLDVarRatio,meantNoiseMGTVarRatio,meantNoiseMGTVarVsCleanedMGTVarRatio,meantNoiseMGTVar);   
    if ~strcmp(tICAtsNoiseList,'NONE')
        fprintf(fid,',%.2f,%.5f,%.2f,%.3f,%.2f,%.5f,%.2f,%.5f,%.5f,%.5f,%.5f,%.5f,%.5f,%.2f',meantsStructuredNoiseVar,meantsCleanedMGTVarVsBOLDVarRatio,meantsCleanedBOLDVar,meantsCleanedMGTbeta,meantsCleanedMGTVar,meantsCleanedMGTVarVstsCleanedBOLDVarRatio,meantsCleanedUnstructuredNoiseVar,meantsStructNoiseVarRatio,meantsStructNoiseVarVsBOLDVarRatio,meantsCleanedMGTVarRatio,meantsCleanedBOLDVarRatio,meantsNoiseMGTVarRatio,meantsNoiseMGTVarVsCleanedMGTVarRatio,meantsNoiseMGTVar);   
    end
end
if ~strcmp(Physio,'FALSE')
    fprintf(fid,',%d,%.2f,%.5f,%.2f,%.3f,%.2f,%.5f',1,meanPhysioVar,meanPhysioVarVsBOLDVarRatio,meanPhysioCleanedBOLDVar,meanPhysioCleanedMGTbeta,meanPhysioCleanedMGTVar,meanPhysioCleanedMGTVarVsPhysioCleanedBOLDVarRatio);
else
    fprintf(fid,',%d,%.2f,%.5f,%.2f,%.3f,%.2f,%.5f',0,0,0,0,0,0,0);        
end
fprintf(fid,',%d,%d,%d,%d,%d,%d',DVDips5,DVDips10,DVDips15,DVDips20,DVDips25,DVDips50);

fprintf(fid,',%.3f',MedDV);

fprintf(fid,',%.3f',MeanFD);

if ~strcmp(Physio,'FALSE')
    fprintf(fid,',%.3f',var(RVT));
else
    fprintf(fid,',%.3f',0);
end

fprintf(fid,',%.3f',MeanVN);

if ~strcmp(tICAtNoiseList,'NONE')
    for i=1:size(tICAtcs,2)
        fprintf(fid,',%.2f',var(tICAtcs_raw(:,i))); %VN Version
    end
end
if ~strcmp(tICAtNoiseList,'NONE')
    for i=1:size(tICAtcs,2)
        fprintf(fid,',%.2f',sum(tICAmix(:,i).^2)); %Non-VN Version
    end
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
    MGTbeta = pinv(normalise(MGT)) * tcs'; 
    MGTRtcs = tcs - (normalise(MGT) * MGTbeta)';
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
function plotgray(img,mvm,HR,RVT,RawPhysio,GS,WM,CSF,step) 
% Make a plot in the [fore/back]ground of FD, DVARS (@ stage),
% Gray(ordinate) plot and tmask across timecourse.

% Calculate FD
FD = sum(abs(cat(2,mvm(:,7:9),(50*pi/180)*mvm(:,10:12))),2);
MeanFD=mean(FD);

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
set(gcf,'Position',[3 6 tp+264 25+tp+25+108+25+108+25+108+25+108+25+108+25]);
set(gcf,'PaperPosition',[0.25 2.5 (tp+264)/72 (25+tp+25+108+25+108+25+108+25+108+25+108+25)/72]);
%colormap(jet);

% Plot FD trace
subplot(6,1,1); plot(fr,FD,'r');
ax = subplot(6,1,1);
set(ax,'Units','points','YTick',[0 1 2],'YTickLabel',...
    {'0','1','2'},'Ylim',[0 2],'FontSize',8);
set(ax,'Position',[60 25+tp+25+108+25+108+25+108+25+108+25 tp 108]);
set(ax,'XTick',[],'XTickLabel',''); xlim([1 tp]);
set(get(gca,'YLabel'),'String',['FD (r), Mean:' num2str(MeanFD,'%.2f')],'FontSize',12);

% Plot DV trace
subplot(6,1,2); plot(fr,DV,'b'); 
ax = subplot(6,1,2);
set(ax,'Units','points','YTick',[-100 -20 -10 0 10 20 100],'YTickLabel',...
    {'-100','-20','-10','0','10','20','100'},'Ylim',[-100 100],'FontSize',8);
set(ax,'Position',[60 25+tp+25+108+25+108+25+108+25 tp 108]);
set(ax,'XTick',[],'XTickLabel',''); xlim([1 tp]);
set(get(gca,'YLabel'),'String',[' DV (b), Median:' num2str(MedDV,'%.1f')],'FontSize',12);

% Plot Resp trace
subplot(6,1,3); plot(RawPhysio(:,1),normalise(RawPhysio(:,2)),'r');
ax = subplot(6,1,3);
set(ax,'Units','points','YTick',[-2 -1 0 1 2],'YTickLabel',...
    {'-2','-1','0','1','2'},'Ylim',[-2 2],'FontSize',8);
set(ax,'Position',[60 25+tp+25+108+25+108+25 tp 108]);
set(ax,'XTick',[],'XTickLabel',''); xlim([1 tp]);
set(get(gca,'YLabel'),'String',['Resp (r)'],'FontSize',12);

% Plot RVT trace
subplot(6,1,4); plot(fr,RVT,'b'); 
ax = subplot(6,1,4);
set(ax,'Units','points','YTick',[-2 -1 0 1 2],'YTickLabel',...
    {'-2','-1','0','1','2'},'Ylim',[-2 2],'FontSize',8);
set(ax,'Position',[60 25+tp+25+108+25 tp 108]);
set(ax,'XTick',[],'XTickLabel',''); xlim([1 tp]);
set(get(gca,'YLabel'),'String',['RVT (b), STD:' num2str(std(RVT),'%.1f')],'FontSize',12);

% Plot MGT+WM+CSF traces
subplot(6,1,5); plot(fr,CSF,'m'); hold on; plot(fr,WM,'c'); plot(fr,GS,'k');
ax = subplot(6,1,5);
set(ax,'Units','points','YTick',[-100 -50 0 50 100],'YTickLabel',...
    {'-100','-50','0','50','100'},'Ylim',[-100 100],'FontSize',8);
set(ax,'Position',[60 25+tp+25 tp 108]);
set(ax,'XTick',[],'XTickLabel',''); xlim([1 tp]);
set(get(gca,'YLabel'),'String','MGT (b), WM (c), CSF (m)','FontSize',10);

CLIM=[-200 200]; %2% of mean 10000 scaled image intensity variations

% Sub-grayplot the Left/Right/Subcortex (or volume gray ribbon if NIFTI)
subplot(6,1,6), imagesc(normimg,CLIM), colormap(gray); %colormap(bone2);
ax = subplot(6,1,6);
set(ax,'Units','points');
set(ax,'Position',[60 25 tp tp]); 
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
%colorbar('TicksMode','manual','Ticks',colorticks,'TickLabelsMode','manual','TickLabels',colortickscell,'location','eastoutside','LimitsMode','manual','Limits',[CLIM(1) CLIM(2)],'Units','points','FontSize',8,'Units','pixels','Position',[60+tp+25 25 52 tp]); %Color bar refused to work with anything other than 9 ticks
colorbar('Units','pixels','Position',[60+tp+25 25 52 tp]); %Color bar refused to work with anything other than 9 ticks


% Save plot

print([step '_QC_Summary_Plot'],'-dpng','-r72'); %close; %%%
end


%%  PLOTGRAY plots the global signal, DVARS grayordinate plot
function plotgrayz(img,mvm,HR,RVT,RawPhysio,GS,WM,CSF,step) 
% Make a plot in the [fore/back]ground of FD, DVARS (@ stage),
% Gray(ordinate) plot and tmask across timecourse.

% Calculate FD
FD = sum(abs(cat(2,mvm(:,7:9),(50*pi/180)*mvm(:,10:12))),2);
MeanFD=mean(FD);

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
set(gcf,'Position',[3 6 tp+264 25+tp+25+108+25+108+25+108+25+108+25+108+25]);
set(gcf,'PaperPosition',[0.25 2.5 (tp+264)/72 (25+tp+25+108+25+108+25+108+25+108+25+108+25)/72]);
%colormap(jet);

% Plot FD trace
subplot(6,1,1); plot(fr,FD,'r');
ax = subplot(6,1,1);
set(ax,'Units','points','YTick',[0 1 2],'YTickLabel',...
    {'0','1','2'},'Ylim',[0 2],'FontSize',8);
set(ax,'Position',[60 25+tp+25+108+25+108+25+108+25+108+25 tp 108]);
set(ax,'XTick',[],'XTickLabel',''); xlim([1 tp]);
set(get(gca,'YLabel'),'String',['FD (r), Mean:' num2str(MeanFD,'%.2f')],'FontSize',12);

% Plot DV trace
subplot(6,1,2); plot(fr,DV,'b'); 
ax = subplot(6,1,2);
set(ax,'Units','points','YTick',[-100 -20 -10 0 10 20 100],'YTickLabel',...
    {'-100','-20','-10','0','10','20','100'},'Ylim',[-100 100],'FontSize',8);
set(ax,'Position',[60 25+tp+25+108+25+108+25+108+25 tp 108]);
set(ax,'XTick',[],'XTickLabel',''); xlim([1 tp]);
set(get(gca,'YLabel'),'String',[' DV (b), Median:' num2str(MedDV,'%.1f')],'FontSize',12);

% Plot Resp trace
subplot(6,1,3); plot(RawPhysio(:,1),normalise(RawPhysio(:,2)),'r');
ax = subplot(6,1,3);
set(ax,'Units','points','YTick',[-2 -1 0 1 2],'YTickLabel',...
    {'-2','-1','0','1','2'},'Ylim',[-2 2],'FontSize',8);
set(ax,'Position',[60 25+tp+25+108+25+108+25 tp 108]);
set(ax,'XTick',[],'XTickLabel',''); xlim([1 tp]);
set(get(gca,'YLabel'),'String',['Resp (r)'],'FontSize',12);

% Plot RVT trace
subplot(6,1,4); plot(fr,RVT,'b'); 
ax = subplot(6,1,4);
set(ax,'Units','points','YTick',[-2 -1 0 1 2],'YTickLabel',...
    {'-2','-1','0','1','2'},'Ylim',[-2 2],'FontSize',8);
set(ax,'Position',[60 25+tp+25+108+25 tp 108]);
set(ax,'XTick',[],'XTickLabel',''); xlim([1 tp]);
set(get(gca,'YLabel'),'String',['RVT (b), STD:' num2str(std(RVT),'%.1f')],'FontSize',12);

% Plot MGT+WM+CSF traces
subplot(6,1,5); plot(fr,CSF,'m'); hold on; plot(fr,WM,'c'); plot(fr,GS,'k');
ax = subplot(6,1,5);
set(ax,'Units','points','YTick',[-100 -50 0 50 100],'YTickLabel',...
    {'-100','-50','0','50','100'},'Ylim',[-100 100],'FontSize',8);
set(ax,'Position',[60 25+tp+25 tp 108]);
set(ax,'XTick',[],'XTickLabel',''); xlim([1 tp]);
set(get(gca,'YLabel'),'String','MGT (b), WM (c), CSF (m)','FontSize',10);

CLIM=[-2 2]; % +/- 2 STD from the mean (per grayordinate)

% Sub-grayplot the Left/Right/Subcortex (or volume gray ribbon if NIFTI)
subplot(6,1,6), imagesc(normimg,CLIM), colormap(gray); %colormap(bone2);
ax = subplot(6,1,6);
set(ax,'Units','points');
set(ax,'Position',[60 25 tp tp]); 
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
%colorbar('YTickMode','manual','YTick',colorticks,'YTickLabel',colortickszcell,'location','eastoutside','Ylim',[CLIM(1) CLIM(2)],'Units','points','FontSize',8); %Color bar refused to work with anything other than 9 ticks
colorbar('Units','pixels','Position',[60+tp+25 25 52 tp]); %Color bar refused to work with anything other than 9 ticks

% Save plot

print([step '_QC_Summary_Plot_z'],'-dpng','-r72'); %close; %%%
end
