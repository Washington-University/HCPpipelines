function sR = melodicicasso(Dim,concatfmri,concatfmrihp,ConcatFolder,tr,nICA,bootMode,vis,seedOffset,nThreads)
% sR = melodicicasso(Dim,concatfmri,concatfmrihp,ConcatFolder,tr,nICA,bootMode,vis,seedOffset,maxIter)
% This function performs runs melodic ICA decomposition (without mixture modeling) many times
% with different seeds using the undocumenterd --seed option.It then clusters the results 
% with icasso (https://doi.org/10.1109/NNSP.2003.1318025),then uses the consensus decomposition 
% to warmstart a final melodic (with mixture modeling) using the undocumented --init_ica option.
% By default melodics are performed in parallel in a parfor loop.Interation outputs are saved to 
% temporary files which are then deleted. 
% 
% All of this function's inputs are strings
%
% Required Inputs (variable names verbatim from hcp_fix_multi_run.sh):
%   Dim          : Data diminsionaliy estimate, typically Wishart-based
%   concatfmri   : File name of original 4d time series without extension
%   concatfmrihp : File name of high-passed 4d time series without extension
%   ConcatFolder : Directory which contains concatfmri
%   tr           : Repetition time
%
% Optional Inputs:
%   nICA    : Number of melodic repetitions per icasso clustering, @ delimited string, (default = '100') 
%             The number of icasso clustering repetitions is equal to the
%             the number delimiters + 1. e.g. '100@100' will perform
%             2 rounds of icasso with 100 melodic runs in each. 
%   bootMode: Whether to randomize the inital conditions only, perfrom
%             bootstrapping, or both in the first level of icasso.
%             Subsequent levels are always bootstrapped. 'randinit' (default), 'boot' or 'both'
%   vis     : Whether to create and save icasso figures, see icasso.m 'basic' (default) or 'off'
%   seedOffset: for bootMode = 'randinit' or 'both', the seed is set to the iteration number, seedOffset
%               is added to this, which is useful for running melodicicasso multiple times with different initial 
%               conditions, it is recomended that if nonzero, seedOffest is greater than nICA of the 
%               first level (default = '0')
%   nThreads : Number of workers for parpool, (default = <total number of physical cores>) 
%              If pool is already running a new one is not created. if
%              nThreads = 1, serial loop used instead. 
%
% Outputs:
%   sR:Diagnostic infomation


% Dependencies:
% icasso, matlab imaging processing toolbox or FSL

% Created 2024-08-06
% Burke Rosen

% ToDo:
% () Currently the vnts file and brainMaskFile paths and names are inferred from
%    ConcatFolder, concatfmrihp, and concatfmri. Maybe they should be their own 
%    arguments for flexibility.

%% parse parameters
if nargin < 5 || any(cellfun(@isempty,{Dim,concatfmri,concatfmrihp,ConcatFolder}))
  error('Dim, concatfmri, concatfmrihp, ConcatFolder, and tr are required!')
end
Dim = str2double(Dim);
if nargin < 6 || isempty(nICA) 
  nICA = 100;
else
  nICA = cellfun(@str2double,regexp(nICA,'@','split'));
end
if nargin < 7 || isempty(bootMode) 
  bootMode = 'randinit';
end
if ~ismember(bootMode,{'randinit','boot','both'})
  warning('vis must be ''basic'' or ''off'', reverting to ''basic''')
  vis = 'basic';
end
if nargin < 8 || isempty(vis) 
  vis = 'basic';
end
if ~ismember(vis,{'basic','off'})
  warning('vis must be ''basic'' or ''off'', reverting to ''basic''')
  vis = 'basic';
end
if nargin < 9 || isempty(seedOffset) 
  seedOffset = 0;
else
  seedOffset=str2double(seedOffset);
end
if nargin < 10 || isempty(nThreads) 
  nThreads = feature('numcores');
else
  nThreads = str2double(nThreads);
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
  writeNIFTI = @(img,fName,hdr) niftiwrite(img,fName,hdr,'Compressed',true);
end

%% parse paths
warning('off','MATLAB:MKDIR:DirectoryExists')
% inputs
vntsFile = sprintf('%s/%s_vnts.nii.gz',ConcatFolder,concatfmrihp);
brainMaskFile = sprintf('%s/%s_brain_mask.nii.gz',ConcatFolder,concatfmri);
if ~exist(vntsFile,'file');error('%s doesn''t exist!',vntsFile);end
if ~exist(brainMaskFile,'file');error('%s doesn''t exist!',brainMaskFile);end

% outputs
outDir = sprintf('%s/%s.ica/filtered_func_data.ica',ConcatFolder,concatfmrihp);
if ~mkdir(outDir);error('Unable to make output folder!');end
warning('on','MATLAB:MKDIR:DirectoryExists')

%% load data
vnts = double(readNIFTI(vntsFile));% icasso expects double
hdr = infoNIFTI(vntsFile);
imSz = size(vnts);
brainMask = logical(readNIFTI(brainMaskFile));
[vnts,mtxDim] = maskAndSpatiallyFlatten(vnts,brainMask);
N = size(vnts,1);

%% run pre-icasso melodics
init_ica = [];
nL = numel(nICA);
for iL = 1:nL
  nI = nICA(iL);
  nSteps = zeros(nI,1);
%   tmpDir = tempname;
  tmpDir = [outDir '/tmp_melodics'];
  mkdir(tmpDir);
  [A,W] = deal(cell(1,nI));
  if strcmp(bootMode,'randinit')
    bootIdx = repmat((1:N)',[1 nI]);fprintf('Running with randinit only (no bootstrapping)\n'); % no bootstrapping
  else
    bootIdx = round(rand(N,nI).*N + 0.5);fprintf('Running with bootstrapping\n'); % prepare bootstraps (resampling with replacement)
  end

  % run parfor over melodics
  if nThreads > 1
    if isempty(gcp('nocreate'));parpool(nThreads);end
    fprintf('Level %i: runing %i melodics in parallel with %i cores:\n',iL,nI,feature('numcores'))
    parfor iI = 1:nI
      meloDir = sprintf('%s/%i',tmpDir,iI);
      mkdir(meloDir);
      bootFile = sprintf('%s/melodic_boot_vnts',meloDir);
      X = zeros(mtxDim,'single');
      X(brainMask,:) = single(vnts(bootIdx(:,iI),:));% consider cell array of vnts instead of broadcast variable
      X = reshape(X,imSz);% unmaskAndSpatiallyInflate subfunction unavailable in parfor
      try % writeNIFTI anon. function unavailable in parfor so use try catch instead
        niftiwrite(X,bootFile,hdr,'Compressed',true);
      catch
        save_avw(X,bootFile,'f',hdr.PixelDimensions)
      end
  
      if iL == 1
        if strcmp(bootMode,'boot')
          seed = 1;% use the same initialization for each run
        else
          seed = iI + seedOffset;
        end
        cmd = sprintf(...
          'melodic -i %s -o %s --nobet --vn --dim="%i" --no_mm --seed="%i" -m %s -v --debug',...
            bootFile,meloDir,Dim,seed,brainMaskFile);
      else
        cmd = sprintf(...
          'melodic -i %s -o %s --nobet --vn --dim="%i" --no_mm --init_ica="%s" -m %s -v --debug',...
            bootFile,meloDir,Dim,init_ica,brainMaskFile);
      end
      
      tic;[stat,out] = system(cmd);
      nSteps(iI) = cellfun(@str2num,(regexp(fileread([meloDir '/log.txt']),'(?<=after)(.*?)(?=steps)','match')));
      if ~stat
        fprintf('finished melodic %.3i/%.3i with %.3i steps. ',iI,nI,nSteps(iI));toc
      else
        error(' melodic %.3i/%.3i failed!\n\n%s',iI,nI,out)
      end
      A{iI} = load([meloDir '/melodic_mix'],'-ascii');
      W{iI} = pinv(A{iI});
    end %parfor iI 
  else
    fprintf('Level %i: runing %i melodics as single threaded serial loop with %i cores:\n',iL,nI)
    for iI = 1:nI
      meloDir = sprintf('%s/%i',tmpDir,iI);
      mkdir(meloDir);
      bootFile = sprintf('%s/melodic_boot_vnts',meloDir);
      X = unmaskAndSpatiallyInflate(X,imSz,brainMask,mtxDim);
      writeNIFTI(X,bootFile,hdr)
  
      if iL == 1
        if strcmp(bootMode,'boot')
          seed = 1;% use the same initialization for each run
        else
          seed = iI + seedOffset;
        end
        cmd = sprintf(...
          'melodic -i %s -o %s --nobet --vn --dim="%i" --no_mm --seed="%i" -m %s -v --debug',...
            bootFile,meloDir,Dim,seed,brainMaskFile);
      else
        cmd = sprintf(...
          'melodic -i %s -o %s --nobet --vn --dim="%i" --no_mm --init_ica="%s" -m %s -v --debug',...
            bootFile,meloDir,Dim,init_ica,brainMaskFile);
      end
      
      tic;[stat,out] = system(cmd);
      nSteps(iI) = cellfun(@str2num,(regexp(fileread([meloDir '/log.txt']),'(?<=after)(.*?)(?=steps)','match')));
      if ~stat
        fprintf('finished melodic %.3i/%.3i with %.3i steps. ',iI,nI,nSteps(iI));toc
      else
        error(' melodic %.3i/%.3i failed!\n\n%s',iI,nI,out)
      end
      A{iI} = load([meloDir '/melodic_mix'],'-ascii');
      W{iI} = pinv(A{iI});
    end % for iI 
  end

  fprintf('level %i: %3.1f steps on average\n',iL,mean(nSteps));
  if iL == 1
    % run melodic once on original non-resampled data just to get whitening matix
    % (there doesn't seem to be a way to turn off ica, so using a big epsilon is the best I can do)
    fprintf('calculating whitening/dewhitening matrices ...\n')
    meloDir = sprintf('%s/white',tmpDir);
    mkdir(meloDir);
    cmd = sprintf(...
            'melodic -i %s -o %s --Owhite --nobet --vn --dim="%i" --no_mm --eps=0.01 -m %s -v --debug',...
          vntsFile,meloDir,Dim,brainMaskFile);
    [stat,out] = system(cmd);
    if stat;error(' melodic whitening failed!\n\n%s',out);end
    whiteningMatrix = load([meloDir '/melodic_white'],'-ascii');

    % populate common sR
    sR = struct();
    for iiL = nL:-1:1
      sR(iiL).signal = vnts';
      sR(iiL).whiteningMatrix = whiteningMatrix;
      sR(iiL).dewhiteningMatrix = pinv(whiteningMatrix);

    end
  end %if iL == 1

  % populate level-specific sR
  sR(iL).index = sortrows(combvec(1:nI,1:Dim)');
  sR(iL).A = A;
  sR(iL).W = W;
  sR(iL).nSteps = nSteps;
  
  rmdir(tmpDir,'s');% clean up temp files

  %% run icasso clustering
  sR(nL).cluster = [];
  sR(nL).projection = [];

  L = mean(icassoGet(sR(iL),'numOfIC'));
  switch vis
   case 'basic'
    sR(iL) = icassoExp(sR(iL));
    [Iq,A,W,S] = icassoShow(sR(iL),'L',L);
   case 'off'
    sR(iL) = icassoCluster(sR(iL));
    [Iq,A,W,S] = icassoResult(sR(iL),L);
   otherwise
    error('Option ''vis'' must be ''basic'' or ''off''.');
  end
  sR(iL).distFromOrth = norm(eye(Dim) - S*S','fro'); 

  % save figures
  printFigs(outDir,iL)

  % save icasso's A as a paradigm file to be used as initalization for next level or final melodic
  init_ica = [outDir '/icasso_A.mat'];
  dlmwrite(init_ica, A, '\t');
  [~,~] = system(sprintf('Text2Vest %s %s',init_ica,init_ica),'-echo');
end %for iL

% save sR for diagnostics
save([outDir '/icasso_sR.mat'],'sR','-v7.3')

%% run melodic one more time (with mixture modeling), initialized by icasso's consensus A 
fprintf('performing melodic with icasso warmstart ...\n')
cmd = sprintf(...
  'melodic -i %s -o %s --Oall --nobet --report --tr="%s" --vn --dim="%i" -m "%s" --init_ica="%s" -v --debug',...
  vntsFile,outDir,tr,Dim,brainMaskFile,init_ica);
[stat,out] = system(cmd,'-echo');
if ~stat
  fprintf('melodic with icasso warmstart completed...\n')
else
  error('melodic with icasso warmstart failed!');
end

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
    img = zeros(mtxDim,'like',mtx);
    img(msk,:) = mtx;
  else
    img = mtx;
  end
  img = reshape(img,imgDim);
end

end %EOF