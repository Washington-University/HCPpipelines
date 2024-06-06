function run_icasso(Dim,concatfmri,concatfmrihp,ConcatFolder,tr,vis,nICA,maxIter)
% run_icasso(Dim,concatfmri,concatfmrihp,ConcatFolder,vis,nICA,maxIter)
% This function performs icasso decomposition for hcp_fix_multi_run.sh
% It creates outputs in the style of MELODIC, so that FIX can be run
% afterwards. Most but not all of MELODIC's outputs are created.
% 
% All of this functions inputs are strings
%
% Required Inputs (variable names verbatim from hcp_fix_multi_run.sh):
%   Dim          : Data diminsionaliy estimate, typically Wishart-based
%   concatfmri   : File name of original 4d time series without extension
%   concatfmrihp : File name of high-passed 4d time series without extension
%   ConcatFolder : Directory which contains concatfmri
%   tr           : inverse sampling frequency of fMRI timeseries 
%
% Optional Inputs:
%   vis     : Whether to create and save icasso figures, see icasso.m 'basic' (default) or 'off'
%   nICA    : Number of ICA repetitions (default = '100')
%   maxIter : Maximum number of iterations per ica fit (default = '1000')
%
% example inputs:
% Dim = '41';
% concatfmri = 'tfMRI_EMOTION_RL_LR';
% concatfmrihp = 'tfMRI_EMOTION_RL_LR_hp0';
% ConcatFolder = '/mnt/myelin/burke/HCPpipelines/dev_study/100307/MNINonLinear/Results/tfMRI_EMOTION_RL_LR';
% tr = '0.72';
% vis = 'basic';
% nICA = 2;
% maxIter = 100;

% Created 2024-06-05
% Burke Rosen

% ToDo:
% () Currently the vnts file and brainMaskFile paths and names are inferred from
%    ConcatFolder, concatfmrihp, and concatfmri. Maybe they should be their own 
%    arguments for flexibility.
% () Spin off a stand alone melodic mixture modeling only matlab wrapper utility

%% parse parameters
if nargin < 5 || any(cellfun(@isempty,{Dim,concatfmri,concatfmrihp,ConcatFolder}))
  error('Dim, concatfmri, concatfmrihp, ConcatFolder, and tr are required!')
end
Dim = str2double(Dim);
tr = str2double(tr);
if nargin < 6 || isempty(vis) 
  vis = 'basic';
end
if ~ismember(vis,{'basic','off'})
  warning('vis must be ''basic'' or ''off'', reverting to ''basic''')
  vis = 'basic';
end
if nargin < 7 || isempty(nICA) 
  nICA = 100;
else
  nICA = str2double(nICA);
end
if nargin < 8 || isempty(maxIter) 
  maxIter = 1000;
else
  maxIter = str2double(maxIter);
end

%% parse paths
% inputs
vntsFile = sprintf('%s/%s_vnts.nii.gz',ConcatFolder,concatfmrihp);
brainMaskFile = sprintf('%s/%s_brain_mask.nii.gz',ConcatFolder,concatfmri);
if ~exist(vntsFile,'file');error('%s doesn''t exist!',vntsFile);end
if ~exist(brainMaskFile,'file');error('%s doesn''t exist!',brainMaskFile);end

% outputs
outDir = sprintf('%s/%s.ica/filtered_func_data.ica',ConcatFolder,concatfmrihp);
[~,~] = unix(['mkdir -p ' outDir]);

%% load data, reshape to 2d, and apply brain mask
vnts = double(niftiread(vntsFile));
brainMask = logical(niftiread(brainMaskFile));
volDim = size(vnts);
[vnts,mtxDim] = reshape4d2d(vnts,brainMask);

%% run icasso
% note: icasso fixes the randomization seed with rng('default')
[iq,A,~,~,~] = ...
  icasso('both',vnts',nICA,'approach','symm','g','pow3',...
  'lastEig',Dim,'numOfIC',Dim,'maxNumIterations',maxIter,'vis',vis); 
[pcaE,pcaD] = fastica(vnts','only','pca');
[S_final,A_final,~] = ...
  fastica(vnts','initGuess',A,'approach','symm','g','pow3',...
  'lastEig',Dim,'numOfIC',Dim,'pcaE',pcaE,'pcaD',pcaD,...
  'displayMode','off','maxNumIterations',maxIter);
pcaD = diag(pcaD);
totVariance = sum(pcaD(end-Dim+1:end))./sum(pcaD);% proportion of total variance explained by first <Dim> components
S_final = S_final';

%% save icasso figures
if strcmp(vis,'basic')
  figH = findall(0,'type','figure');
  figH = figH(~contains({figH.Name},'centrotypes'));% the centrotypes figure isnt useful
  for iF = 1:numel(figH)
    figFile = sprintf('%s/%s.fig',outDir,strrep(strrep(strrep(figH(iF).Name,' ','_'),':',''),'Icasso','icasso'));
    savefig(figH(iF),figFile,'compact');
  end
  close all;
end

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
S_final4d = reshape2d4d(S_final,volDim,brainMask,mtxDim);
Z4d = reshape2d4d(Z,volDim,brainMask,mtxDim);

% save betas and z-score as 4-d nifti volumes
hdr = niftiinfo(vntsFile);
hdr.ImageSize(end) = Dim;
niftiwrite(single(S_final4d),sprintf('%s/melodic_oIC',outDir),hdr,'Compressed',true)
niftiwrite(single(Z4d),sprintf('%s/melodic_IC',outDir),hdr,'Compressed',true)

% save mixing matrices as tab-delimited text
dlmwrite(sprintf('%s/melodic_mix',outDir),A_final,'\t');
dlmwrite(sprintf('%s/melodic_unmix',outDir),W_final,'\t');

% save variance explained as tab-delimited text
ICstats = [tICAPercentVariances tICAPercentVariances * totVariance]; 
dlmwrite([outDir '/melodic_ICstats'],ICstats, 'delimiter', '\t');

% copy brainmask into melodic dir
copyfile(brainMaskFile,[outDir '/mask.nii.gz'])

% save pcaD and pcaE? Looks like FIX doesn't need them

%% calculate FTmix spectra
ts = struct();
ts.Nsubjects = 1;
ts.ts = A_final;
[ts.NtimepointsPerSubject,ts.Nnodes] = size(ts.ts);
ts_spectra = nets_spectra_sp(ts);

% save A_final and spectra as tab-delimited text
dlmwrite([outDir '/melodic_Tmodes'], ts.ts, 'delimiter', '\t'); 
dlmwrite([outDir '/melodic_FTmix'], ts_spectra, 'delimiter', '\t');

fid = fopen([outDir '/components.txt'],'w');
fprintf(fid,'%i: Signal\n',1:size(S_final,2));fclose(fid);
[~,~] = unix(['wb_command -cifti-create-scalar-series ' ...
  sprintf('%s/melodic_FTmix %s/melodic_FTmix.sdseries.nii -transpose -name-file %s/components.txt -series HERTZ 0 %f',...
  outDir,outDir,outDir,tr)]);% note: saving this file is the only thing tr is used for

%% Mixture modeling
% follows recipe from https://www.jiscmail.ac.uk/cgi-bin/webadmin?A2=fsl;6e85d498.1607
fprintf('performing melodic mixture modeling ...\n')
[~,~] = unix(sprintf('melodic -i %s/melodic_IC --ICs=%s/melodic_IC --mix=%s/melodic_mix -o %s --Oall --report -v --mmthresh=0.5',...
  outDir,outDir,outDir,outDir));

%ToDO make a mixture modeling matlab function that works on niftis of volume cifitis 
% reads output of melodic mixture modeling as matlab variables 
% % alternative more generalized recipe?
% % https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/MELODIC
% [~,~] = unix(sprintf('echo "1" > %s/grot.txt',outDir));(sprintf('echo "1" > %s/grot.txt',outDir));
% [~,out] = unix(sprintf('melodic -i %s/melodic_IC --ICs=%s/melodic_IC --mix=%s/grot.txt -o %s --Oall --report -v --mmthresh=0.5',...
%   outDir,outDir,outDir,outDir));


%% Helper subfunctions
function [mtx,mtxDim] = reshape4d2d(img,msk)
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

function img = reshape2d4d(mtx,imgDim,msk,mtxDim)
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