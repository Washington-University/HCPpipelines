function multiEchoCombine(tscPath,TE,refPath,sctPath,T2starMethod,weightMethod,fitNoiseFloor,NFnStd,nonlinAlgo)
% multiEchoCombine(tscPath,TE,refPath,sctPath,T2starMethod,weightMethod,fitNoiseFloor,NFnStd,nonlinAlgo)
% This function combines the echoes of a multi-echo image,
% following the procedure of Kundu et al. 2012 
% (https://doi.org/10.1016/j.neuroimage.2011.12.028),including T2*
% fitting. It writes three output images: The weighted combination of echoes, 
% as well as T2* and S0 images. 
% 
% Mandatory inputs:
% tscPath : full file path to 4d input timeseries image
%             (if echoes are concatenated in 4th dim, the mean of frames in
%              each echo will be used, if the 4th dim is the same size as TE
%              it will be used as is.)
% TE: text file listing of Echo TE's, in ms
%
% Optional inputs:
%   refPath : full file path to 4d reference image (e.g. SBref or average of echoes), 
%             if not supplied, the average across frames for each echo will be used
%             as the reference.
%   sctPath : full file path to 4d  image with 4th dim the same size as TE (e.g. SBref or Scout) to apply weights to, ignored if not supplied
%   T2starMethod  : Method for T2* Regression. Options:
%             'unweighted' : simple log-linear linear regression using all echoes
%                            [ vectorized ]
%             'weighted'   : log-linear linear regression, weighting echoes by inverse uncertainty (default)
%                            [ parfor loop over all voxels ]
%             'nonlinear'  : single exponential non-linear least-squares fit
%                            [ parfor loop over all voxels ]
%   weightMethod : Method for taking the weighted sum of echoes
%                  'Kundu' : Kundu et al. 2012 procedure (default)
%                  'Posse' : Possee et al. 1999 procedure
%   fitNoiseFloor : Flag to fit noisefloor using Gaussian mixture modeling (k = length(TE)+1)  
%                   and mask below mean+[NFnStd]*stdev threshold. (default = true)
%   NFnStd : # of stdevs above or below (negative) smallest mean of Gaussian mixture
%            (default = 0)
%   nonlinAlgo : algorithm for nonlinear fitting, 'Trust-Region' or 
%                'Levenberg-Marquardt' (default), see fitoptions
%
% Outputs: 
% <tscPath w/o extention>_CombEchoes.nii.gz  : 4d combined echo image where dim 4 has length = # frames per echo
% <tscPath w/o extention>_T2star.nii.gz      : 3d image of T2* values
% <tscPath w/o extention>_S0.nii.gz          : 3d image of S0 values
% <tscPath w/o extention>_EchoWeights.nii.gz : 4d image of weights for summation where dim 4 has length = # of echoes

%
% Additional details: 
% Echo voxels with greater intensity than the previous echo are excluded from regressions.
% Echo voxels below fitted noisefloor threshold are exluded from regressions.
% T2* and S0 of voxels with fewer than 2 non-exluded echoes are extrapolated
% Voxels with fitted T2* greater than that of deionized water are also extrapolated 
%   H2O T2* = 2240 ms, from Table 1 of Gatidis et al. 2013,https://doi.org/10.1002/mrm.24944
%   This theshold is the only correction that requires the units of TE to be ms.

% Created 2024-03-19
% Burke Rosen 

%% handle inputs, set defaults, and load data
if ~exist(tscPath,'file')
  error('%s does not exist!',tscPath)
end
if ~exist(TE,'file')
  error('%s does not exist!',TE)
end
TE=load(TE);
if ~isvector(TE) || ~isnumeric(TE)
  error('TE isn''t a numeric vector, check inputs!')
end
if size(TE,1) == 1; TE = TE';end
if nargin > 2 && ~exist(refPath,'file')
  error('%s does not exist!',refPath)
end
if nargin <2
  error('tscPath and TE must be supplied!')
end
if nargin < 4 || isempty(sctPath)
  sctPath = [];
  else
  if ~exist(sctPath,'file')
    error('%s does not exist!',sctPath)
  end
end
if nargin < 5 || isempty(T2starMethod)
  T2starMethod = 'weighted';
end
if nargin < 6 || isempty(weightMethod)
  weightMethod = 'Kundu';
end
if nargin < 7 || isempty(fitNoiseFloor)
  fitNoiseFloor = true;
end
if nargin < 8
  NFnStd = 0; 
end
if nargin < 9 || isempty(nonlinAlgo)
  nonlinAlgo = 'Levenberg-Marquardt'; 
end

% load data
I = niftiread(tscPath);
hdr = niftiinfo(tscPath);
if ~isempty(sctPath)
  S = niftiread(sctPath);
end

% get dims
sz = size(I);
nE = numel(TE);
framePerEcho = sz(4)/nE;

if mod(framePerEcho,1)
  error(['The number of frames in the image is a non-integer ' ...
         'multiple of the numbers of TE''s!'])
end

%% load or derive reference image 
if nargin < 3 || isempty(refPath)
  % average frames in each echo
  for iE = nE:-1:1
    Y(:,:,:,iE) = mean(I(:,:,:,(1:framePerEcho)+framePerEcho*(iE-1)),4);
  end
else
  Y = niftiread(refPath);
end

%% Create time matrix
X = arrayfun(@(x) repmat(x,sz(1:3)),TE,'uni',0);
X = cat(4,X{:}); % there is probably a smarter way to do this with a single repmat call

%% for each voxel, drop echo and subsequent echoes if intensity increases
% because that's physically impossible
difMsk = cat(4,zeros(sz(1),sz(2),sz(3)),diff(Y,1,4)) > 0;
for iE = 3:nE;difMsk(:,:,:,iE) = difMsk(:,:,:,iE) | difMsk(:,:,:,iE-1);end
[X(difMsk),Y(difMsk)] = deal(NaN);

%% fit noisefloor with Gaussian mixture model and threshold using it
if fitNoiseFloor
    % fit Gaussian mixture with k = number of echoes + 1
    k = nE + 1;
    Gdat = Y(Y > 0);
    opt = struct();
    opt.MaxIter = 1000;
    G = fitgmdist(Gdat,k,'Options',opt,...
      'start',discretize(Gdat,prctile(Gdat,0:100/k:100)));% initialize with even-split

    % remove values below threhsold from regressions 
    thresh = G.mu(1) + NFnStd .* sqrt(G.Sigma(1));% sqrt because fitgmdist's Sigma is (co)variance, not stdev
    noiseMsk = Y > 0 & Y < thresh;
    noiseMsk(:,:,:,1:2) = false;% never apply noisefloor to first two echos
    [X(noiseMsk),Y(noiseMsk)] = deal(NaN);

    % diagnostic figure for tuning 
%     figure(1);clf
%     set(gcf,'color','w')
%     histogram(Gdat,'FaceColor',[.5 .5 .5])
%     cMap = colormap('lines');
%     for iK = 1:k
%       line(G.mu(iK).*[1 1],ylim,'color',cMap(iK,:),'linewidth',2)
%       line((G.mu(iK) + NFnStd .* sqrt(G.Sigma(iK))).*[1 1],ylim,...
%         'color',cMap(iK,:),'linewidth',2,'linestyle',':')
%     end;box off;
end

%% fit T2* using log-linear regression
switch T2starMethod
  case {'unweighted','nonlinear'}
    % Do simple one variable + intercept linear regression
    % (if nonlinear fit is to be run, run this as initialization)
    Y = log(Y);
    N = sum(~isnan(X),4);
    sum_x = sum(X,4,'omitnan');
    sum_x_squared = sum(X.^2,4,'omitnan');
    sum_y = sum(Y,4,'omitnan');
    sum_xy = sum(X .* Y,4,'omitnan');
    R2 =  (N .* sum_xy - sum_x .* sum_y) ./ ...
          (N .* sum_x_squared - sum_x.^2);% slope (negative Relaxation time)
    S0 = (sum_y - R2 .* sum_x) ./ N;% intercept (initial signal intensity)
    S0 = exp(S0);% scaling parameter needs to be un-log'd
    R2 = -R2;% relaxation time should be expressed as positive
    T2star = 1./R2;% eq. 1 of Kundu et al.

    if strcmp(T2starMethod,'nonlinear')
      S0_lin = S0;
      T2star_lin = T2star;
    end
  case 'weighted'
    % Do weighted linear regression
    % Regression is weighted by uncertainty (stdev.) Uncertainty is the derivative 
    % of F(log(y)) = 1/y. Factor weights into x an y by taking square root. 
    
    W = 1./Y;
    X = cat(5,X.*sqrt(W),sqrt(W));%[TE ones(nE,1)];
    Y = log(Y).*sqrt(W);
    X = permute(X,[4 5 1:3]);% put operative dims first to avoid squeezing
    Y = permute(Y,[4 1:3]);
    
    %if isempty(gcp('nocreate'))
      %parpool(feature('numcores'));
    %end
    [R2,S0] = deal(zeros(sz(1:3)));
    sz1 = sz(1);sz2 = sz(2);sz3 = sz(3);%set for parfor
    for iD1 = 1:sz1
      for iD2 = 1:sz2 %parfor
        for iD3 = 1:sz3
          if isinf(Y(1,iD1,iD2,iD3));continue;end
          nanMsk = ~isnan(Y(:,iD1,iD2,iD3));
          b = pinv(X(nanMsk,:,iD1,iD2,iD3))*Y(nanMsk,iD1,iD2,iD3);
          R2(iD1,iD2,iD3) = b(1);
          S0(iD1,iD2,iD3) = b(2);
        end
      end
    end
    S0 = single(exp(S0));% scaling parameter needs to be un-log'd
    T2star = single(-1./R2);% eq. 1 of Kundu et al.
  otherwise
    error('Method must be unweighted, weighted, or nonlinear.')
end % switch

% do nonlinear fit, initialized by linear
if strcmp(T2starMethod,'nonlinear')
  Y = exp(Y); % undo log transform from log-linear initalization
  X = double(permute(X,[4 5 1:3]));% put operative dims first to avoid squeezing
  Y = double(permute(Y,[4 1:3]));% non-linear fit needs double

  [R2,S0] = deal(zeros(sz(1:3)));
  sz1 = sz(1);sz2 = sz(2);sz3 = sz(3);%set for parfor
  %if isempty(gcp('nocreate'));parpool(feature('numcores'));end
  for iD1 = 1:sz1
    for iD2 = 1:sz2 %parfor
      for iD3 = 1:sz3
        if isinf(Y(1,iD1,iD2,iD3)) || ...
           isnan(S0_lin(iD1,iD2,iD3)) || ...
           isnan(T2star_lin(iD1,iD2,iD3));continue;
        end
        nanMsk = ~isnan(Y(:,iD1,iD2,iD3));
        if sum(nanMsk) < 2;continue;end
        opt = fitoptions('exp1');
        opt.Algorithm = nonlinAlgo;
        opt.StartPoint = [S0_lin(iD1,iD2,iD3) -1./T2star_lin(iD1,iD2,iD3)];
        F = fit(X(nanMsk,:,iD1,iD2,iD3),Y(nanMsk,iD1,iD2,iD3),'exp1',opt);
        S0(iD1,iD2,iD3) = F.a;
        R2(iD1,iD2,iD3) = F.b;
      end
    end
  end
  T2star = single(-1./R2);% eq. 1 of Kundu et al.
  S0 = single(S0);
end %if

% if fitNoiseFloor and <2 echoes above threshold, or extrapolate those voxels
% T2star(sum(~isnan(X),4) < 2) = -1; % no longer needed as noisefloor only applied to echoes 3+

% if second echo greater than first, extrapolate those voxels
T2star(difMsk(:,:,:,2)) = -1;

% if T2* > than that of deionized water, extrapolate those voxels
h2oT2star = 2240; % (ms) from Table 1 of Gatidis et al. 2013, https://doi.org/10.1002/mrm.24944
T2star(T2star>h2oT2star) = -1;

% clean up non-brain voxels
S0(isnan(S0) | isinf(S0)) = 0;
T2star(isnan(T2star) | isinf(T2star)) = 0;

%% save out T2star S0
hdr3d = hdr;
hdr3d.ImageSize = hdr3d.ImageSize(1:3);
hdr3d.PixelDimensions = hdr3d.PixelDimensions(1:3);
T2starPath = strrep(tscPath,'.nii.gz','_T2star');
S0Path = strrep(tscPath,'.nii.gz','_S0');
niftiwrite(T2star,T2starPath,hdr3d,'Compressed',true)
niftiwrite(S0,S0Path,hdr3d,'Compressed',true)

%% Extrapolate voxels with negative T2* from T2* and S0
% and voxels with all echoes below noisefloor, if fitNoiseFloor
% and voxels with T2* greater than than that of deionized water
badVoxel = single(T2star < 0);
if ~isempty(find(badVoxel,1))% any(x,'all') syntax isn't present in 2017b
  bvPath = tempname;
  niftiwrite(badVoxel,bvPath,hdr3d,'Compressed',true)
  cmd = sprintf(...
    'wb_command -volume-dilate %s.nii.gz 5 WEIGHTED %s.nii.gz -bad-voxel-roi %s.nii.gz',...-grad-extrapolate
    T2starPath,T2starPath,bvPath);
  [~,~] = unix(cmd);
  cmd = sprintf(...
    'wb_command -volume-dilate %s.nii.gz 5 WEIGHTED %s.nii.gz -bad-voxel-roi %s.nii.gz',...-grad-extrapolate
    S0Path,S0Path,bvPath);
  [~,~] = unix(cmd);
  T2star = niftiread(T2starPath);
  delete([bvPath '.nii.gz'])
end
clear S0;

%% take the weighted sum of echoes
% eq. 6 of Kundu et al.
switch weightMethod
  case 'Kundu'
    for iE = nE:-1:1
      W(:,:,:,iE) = TE(iE) .* exp(-TE(iE) ./ T2star);
    end
    W = W ./ sum(W,4);
  case 'Posse'
    for iE = nE:-1:1
      W(:,:,:,iE) = TE(iE) .* exp(-TE(iE) ./ T2star) ./ T2star;
    end
  otherwise
    error('weightMethod must be Kundu or Posse')
end
% export weights
hdrW = hdr;
hdrW.ImageSize(4) = nE;
WeightsPath = strrep(tscPath,'.nii.gz','_EchoWeights');
niftiwrite(W,WeightsPath,hdrW,'Compressed',true)

%% apply weights and export results
if ~isempty(sctPath)
  % apply to SBRef
  S = sum(S.*W,4);
  S(isnan(S)) = 0;

  % save combined Scout / SBref
  hdr.ImageSize(4) = framePerEcho;
  niftiwrite(S,strrep(sctPath,'.nii.gz','_CombEchoes'),hdr3d,'Compressed',true)
end

% apply to timeseries
W = repelem(W,1,1,1,framePerEcho);
I = sum(reshape(I.*W,[sz(1:3) framePerEcho nE]),5);
I(isnan(I)) = 0;

% save combined timeseries
hdr.ImageSize(4) = framePerEcho;
niftiwrite(I,strrep(tscPath,'.nii.gz','_CombEchoes'),hdr,'Compressed',true)

end % EOF
