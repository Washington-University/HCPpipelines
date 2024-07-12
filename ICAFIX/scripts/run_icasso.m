function run_icasso(Dim,concatfmri,concatfmrihp,ConcatFolder,vis,nICA,maxIter)
% run_icasso(Dim,concatfmri,concatfmrihp,ConcatFolder,vis,nICA,maxIter)
% This function performs icasso decomposition for hcp_fix_multi_run.sh
% It creates outputs in the style of MELODIC, so that FIX can be run
% afterwards. Most but not all of MELODIC's outputs are created.
% 
% All of this function's inputs are strings
%
% Required Inputs (variable names verbatim from hcp_fix_multi_run.sh):
%   Dim          : Data diminsionaliy estimate, typically Wishart-based
%   concatfmri   : File name of original 4d time series without extension
%   concatfmrihp : File name of high-passed 4d time series without extension
%   ConcatFolder : Directory which contains concatfmri
%
% Optional Inputs:
%   vis     : Whether to create and save icasso figures, see icasso.m 'basic' (default) or 'off'
%   nICA    : Number of ICA repetitions per icasso repetition, @ delimited string, (default = '100') 
%             The number of icasso repetitions is equal to the the number delimiters + 1
%   maxIter : Maximum number of iterations per ica fit (default = '1000')
%
% example inputs:
% Dim = '41';
% concatfmri = 'tfMRI_EMOTION_RL_LR';
% concatfmrihp = 'tfMRI_EMOTION_RL_LR_hp0';
% ConcatFolder = '/mnt/myelin/burke/HCPpipelines/dev_study/100307/MNINonLinear/Results/tfMRI_EMOTION_RL_LR_ICASSO';
% vis = 'basic';
% nICA = '2@2';
% maxIter = '1000';
% 
% Dim = str2double(Dim);
% nICA = cellfun(@str2double,regexp(nICA,'@','split'));
% maxIter = str2double(maxIter);

% Created 2024-06-05
% Burke Rosen

% ToDo:
% () Currently the vnts file and brainMaskFile paths and names are inferred from
%    ConcatFolder, concatfmrihp, and concatfmri. Maybe they should be their own 
%    arguments for flexibility.

%% parse parameters
if nargin < 4 || any(cellfun(@isempty,{Dim,concatfmri,concatfmrihp,ConcatFolder}))
  error('Dim, concatfmri, concatfmrihp, and ConcatFolder are required!')
end
Dim = str2double(Dim);
if nargin < 5 || isempty(vis) 
  vis = 'basic';
end
if ~ismember(vis,{'basic','off'})
  warning('vis must be ''basic'' or ''off'', reverting to ''basic''')
  vis = 'basic';
end
if nargin < 6 || isempty(nICA) 
  nICA = 100;
else
  nICA = cellfun(@str2double,regexp(nICA,'@','split'));
end
if nargin < 7 || isempty(maxIter) 
  maxIter = 1000;
else
  maxIter = str2double(maxIter);
end

%% check IO dependencies
% use imaging processing toolbox utilities, or if those are not available use FSL utilities 
function out = out2(fun);[~,out] = fun();end
function out = out3(fun);[~,~,out] = fun();end
if isempty(which('niftiread'))
  if isempty(which('read_avw'))
    error('neither niftiread nor read_avw on matlab path!')
  end
  infoNIFTI = @(fName) struct('ImageSize',out2(@() read_avw(fName))','PixelDimensions',out3(@() read_avw(fName))');
  readNIFTI = @(fName) read_avw(fName);
  writeNIFTI = @(img,fName,hdr) save_avw(img,fName,'f',hdr.PixelDimensions);
else
  readNIFTI = @(fName) niftiread(fName);
  infoNIFTI = @(fName) niftiinfo(fName);
  writeNIFTI = @(img,fName,hdr) niftiwrite(img,fName,hdr);
end

%% parse paths
% inputs
vntsFile = sprintf('%s/%s_vnts.nii.gz',ConcatFolder,concatfmrihp);
brainMaskFile = sprintf('%s/%s_brain_mask.nii.gz',ConcatFolder,concatfmri);
if ~exist(vntsFile,'file');error('%s doesn''t exist!',vntsFile);end
if ~exist(brainMaskFile,'file');error('%s doesn''t exist!',brainMaskFile);end

% outputs
outDir = sprintf('%s/%s.ica/filtered_func_data.ica',ConcatFolder,concatfmrihp);
if ~mkdir(outDir);error('Unable to make output folder!');end

%% load data, reshape to 2d, and apply brain mask
vnts = double(readNIFTI(vntsFile));% fastica needs double
brainMask = logical(readNIFTI(brainMaskFile));
volDim = size(vnts);
[vnts,mtxDim] = maskAndSpatiallyFlatten(vnts,brainMask);

%% run icasso
% note: icasso fixes the randomization seed with rng('default')
vntsT = vnts';
[iq,A,~,~,~] = ...
  icasso('both',vntsT,nICA(1),'approach','symm','g','pow3',...
  'lastEig',Dim,'numOfIC',Dim,'maxNumIterations',maxIter,'vis',vis); 
if strcmp(vis,'basic'); printFigs(outDir,1);end
for iC = 2:numel(nICA)
  [iq,A,~,~,~] = ...
    icasso('bootstrap',vntsT,nICA(iC),'approach','symm','g','pow3','initGuess',A,...
    'lastEig',Dim,'numOfIC',Dim,'maxNumIterations',maxIter,'vis',vis); 
  if strcmp(vis,'basic'); printFigs(outDir,iC);end
end
[pcaE,pcaD] = fastica(vntsT,'only','pca');
[S_final,A_final,~] = ...
  fastica(vntsT,'initGuess',A,'approach','symm','g','pow3',...
  'lastEig',Dim,'numOfIC',Dim,'pcaE',pcaE,'pcaD',pcaD,...
  'displayMode','off','maxNumIterations',maxIter);
pcaD = diag(pcaD);
totVariance = sum(pcaD(end-Dim+1:end))./sum(pcaD);
  % proportion of total variance explained by first <Dim> components
clear vntsT
S_final = S_final';

%% set component sign and sort by variance explained
% set sign
maxSfinal = max(S_final);
absminSfinal = abs(min(S_final));
pos = maxSfinal > absminSfinal;
neg = maxSfinal < absminSfinal;
signAll = sign(pos + neg * -1);
S_final = S_final .* signAll;
A_final = A_final .* signAll;

% sort by variance explained
tVar = var(A_final);
tICAPercentVariances = tVar / sum(tVar) * 100;
[tICAPercentVariances,Is] = sort(tICAPercentVariances,'descend');
S_final = S_final(:,Is);
A_final = A_final(:,Is);
iq = iq(Is);

W_final = pinv(A_final);

%% calculate single-regression z-stats
NODEtsnorm = normalise(A_final);% z-score
pN = pinv(NODEtsnorm); dpN = diag(pN * pN')';
dof = size(NODEtsnorm,1) - size(NODEtsnorm,2) - 1;
residuals = demean(vnts, 2) - S_final * NODEtsnorm';
t = double(S_final ./ sqrt(sum(residuals .^ 2, 2) * dpN / dof));
Z = zeros(size(t));
Z(t > 0) = min(-norminv(tcdf(-t(t > 0), dof)),  38.5);
Z(t < 0) = max( norminv(tcdf( t(t < 0), dof)), -38.5);
Z(isnan(Z)) = 0;

%% save icasso outputs to match melodic
% reshape betas (S_final) and z-scores back to 4-d
mtxDim = [mtxDim(1) Dim];
volDim = [volDim(1:3) Dim];
S_final4d = unmaskAndSpatiallyInflate(S_final,volDim,brainMask,mtxDim);
Z4d = unmaskAndSpatiallyInflate(Z,volDim,brainMask,mtxDim);

% save betas and z-score as 4-d nifti volumes
hdr = infoNIFTI(vntsFile);
hdr.ImageSize(end) = Dim;
writeNIFTI(single(S_final4d),sprintf('%s/melodic_oIC',outDir),hdr)
writeNIFTI(single(Z4d),sprintf('%s/melodic_IC',outDir),hdr)

% save mixing matrices as tab-delimited text
dlmwrite(sprintf('%s/melodic_unmix', outDir), W_final, '\t');
dlmwrite(sprintf('%s/melodic_mix',   outDir), A_final, '\t');
copyfile(sprintf('%s/melodic_mix',   outDir), sprintf('%s/melodic_Tmodes', outDir));% mix and Tmodes are the same

% save variance explained as tab-delimited text
ICstats = [tICAPercentVariances tICAPercentVariances * totVariance]; 
dlmwrite([outDir '/melodic_ICstats'], ICstats, 'delimiter', '\t');

% copy brainmask into melodic dir
copyfile(brainMaskFile,[outDir '/mask.nii.gz'])

% save pcaD and pcaE? Looks like FIX doesn't need them

%% calculate and save FTmix spectra
ts = struct();
ts.Nsubjects = 1;
ts.ts = A_final;
[ts.NtimepointsPerSubject,ts.Nnodes] = size(ts.ts);
ts_spectra = nets_spectra_sp(ts);
dlmwrite([outDir '/melodic_FTmix'], ts_spectra, 'delimiter', '\t');
fid = fopen([outDir '/components.txt'],'w');
fprintf(fid,'%i: Signal\n',1:size(S_final,2));fclose(fid);

% FTmix.sdseries.nii aren't need by FIX, so don't produce them
% [~,~] = system(['wb_command -cifti-create-scalar-series ' ...
%   sprintf('%s/melodic_FTmix %s/melodic_FTmix.sdseries.nii -transpose -name-file %s/components.txt -series HERTZ 0 %f',...
%   outDir,outDir,outDir,tr)]);

%% Mixture modeling
fprintf('performing melodic mixture modeling ...\n')
mixtureModel([outDir '/melodic_IC.nii.gz']);% overwrites in-place without saving full report

%% Helper subfunctions
function printFigs(outD,lvl)
  figH = findall(0,'type','figure');
  figH = figH(~contains({figH.Name},'centrotypes'));% the centrotypes figure isn't useful
  for iF = 1:numel(figH)
    figFile = sprintf('%s/%s_%i.fig',...
      outD,strrep(strrep(strrep(figH(iF).Name,' ','_'),':',''),'Icasso','icasso'),lvl);
    try
      savefig(figH(iF),figFile,'compact');
    catch 
      warning('Could not save icasso figures.')
    end
  end
  close all;
end

end
function [mtx,mtxDim] = maskAndSpatiallyFlatten(img,msk)
  % reshapes 4d img into 2d matrix where the first 3 dims are put into the 1st dim
  % second arg msk is 3d logical volume
  % second output is size before mask is applied

  imgDim = size(img);
  mtx = reshape(img,prod(imgDim(1:3)),imgDim(4));
  mtxDim = size(mtx);%
  if nargin == 2
    mtx = mtx(logical(msk(:)),:);
  end
end

function img = unmaskAndSpatiallyInflate(mtx,imgDim,msk,mtxDim)
  % reshapes 2d mtx into 4d matrix where the first 1 dim are put into the
  % 1st 3 dims using the dimensions supplied in imgDim
  % if a msk is supplied then the size of the 2d mtx before the mask was
  % applied is needed

  if nargin > 2
    img = zeros(mtxDim);
    img(msk,:) = mtx;
  else
    img = mtx;
  end
  img = reshape(img,imgDim);
end

end %EOF