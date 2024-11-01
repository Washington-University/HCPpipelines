function fix_3_clean(fixlist,aggressive,domot,hp,WBC,DOvol)
% fix_3_clean(fixlist,aggressive,domot,hp,WBC,[DOvol]) - CIFTI processing only (do not process volumetric data)
%
% fixlist is a vector of which ICA components to remove (starting at 1 not 0)
%
% aggressive = 0 or 1 - this controls whether cleanup is aggressive (all variance in confounds) or not (only unique variance)
%
% mot = 0 or 1 - this controls whether to regress motion parameters out of the data (24 regressors)
%
% WBC = wb_command (full path)
%
% doVol = 1 (default) or 0 - When doVol == 0, do CIFTI processing only (do not process volumetric data)
% 
% hp determines what highpass filtering had been applied to the data (and so will get applied to the motion confound parameters)
% hp=-1 no highpass
% hp=0 linear trend removal
% hp>0 the fullwidth (2*sigma) of the highpass, in seconds (not TRs)
%
% modified from fix_3_clean.m in fix1.06.15


  if (isdeployed)
      aggressive = str2double(aggressive);
      domot = str2double(domot);
      hp = str2double(hp);
  end
  
  %% %%  read set of bad components
  %TSC: do this before the cd() - somehow interpreted matlab allowed it after, but compiled didn't, and 'which' said not found in interpreted, so I have no idea what it previously loaded while testing...
  DDremove=load(fixlist);
  
  %% %% setup the following variables for your site
  curDir = pwd;
  if ~isempty(fileparts(fixlist));cd(fileparts(fixlist));end

  % CIFTI=getenv('FSL_FIX_CIFTIRW');
  % WBC=getenv('FSL_FIX_WBC');
  
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  
%   DOvol=1;
%   if isdeployed
%     if ~isempty(varargin) && str2double(varargin{1}) == 0
%       DOvol=0;
%     end
%   else
%     if ~isempty(varargin) && varargin{1} == 0
%       DOvol=0;
%     end
%   end
  if nargin < 6 || isempty(DOvol)
    DOvol = 1;
  end

  
  %% %% report parameters
  fprintf('aggressive = %d\n',aggressive)
  fprintf('domot = %d\n',domot)
  fprintf('hp = %f\n',hp)
  fprintf('DOvol = %d\n',DOvol)
  
  %% %%  find TR of data
  [~,TR]=call_fsl('fslval filtered_func_data pixdim4'); 
  TR=str2double(TR);
  fprintf('TR = %f\n',TR)
  
  %% %%  read and highpass CIFTI version of the data if it exists
  DObrainord=0;
  if exist('Atlas.dtseries.nii','file') == 2
    DObrainord=1;
  %   if (~isdeployed)
  %     path(path,CIFTI);
  %   end
    BO=ciftiopen('Atlas.dtseries.nii',WBC);
    if hp==0
      meanBO=mean(BO.cdata,2);
      BO.cdata=detrend(BO.cdata')';  BO.cdata=BO.cdata+repmat(meanBO,1,size(BO.cdata,2));
    end
    if hp>0
      BOdimX=size(BO.cdata,1);  BOdimZnew=ceil(BOdimX/100);  BOdimT=size(BO.cdata,2);
      meanBO=mean(BO.cdata,2);  BO.cdata=BO.cdata-repmat(meanBO,1,size(BO.cdata,2));
      save_avw(reshape([BO.cdata ; zeros(100*BOdimZnew-BOdimX,BOdimT)],10,10,BOdimZnew,BOdimT),'Atlas','f',[1 1 1 TR]);
      BO.cdata = [];
      call_fsl(sprintf('fslmaths Atlas -bptf %f -1 Atlas',0.5*hp/TR));
      grot=reshape(read_avw('Atlas'),100*BOdimZnew,BOdimT);
      BO.cdata=grot(1:BOdimX,:); clear grot;
      BO.cdata=BO.cdata+repmat(meanBO,1,size(BO.cdata,2));
      ciftisave(BO,'Atlas_hp_preclean.dtseries.nii',WBC); % save out noncleaned hp-filtered data for future reference, as brainordinates file
    end
  end
  
  %% %%  read NIFTI version of the data, reducing to just the non-zero voxels (for memory efficiency)
  if DOvol
    ctsfull=read_avw('filtered_func_data');
    ctsX=size(ctsfull,1); ctsY=size(ctsfull,2); ctsZ=size(ctsfull,3); ctsT=size(ctsfull,4); 
    % Note: reshape is a "memory-free" operation, but transpose isn't. So wait to transpose until after masking.
    ctsfull=reshape(ctsfull,ctsX*ctsY*ctsZ,ctsT);
    % Note: Use 'range' to identify non-zero voxels (which is very memory efficient)
    % rather than 'std' (which requires additional memory equal to the size of the input)
    ctsmask = range(ctsfull, 2) > 0;
    cts=ctsfull(ctsmask,:)';  % Note: after transpose, cts has dimensions of [time space]
    clear ctsfull;
  end
  
  %% %%  read and prepare motion confounds
  confounds=[];
  if domot == 1
    confounds = functionmotionconfounds(TR,hp);
  end
  
  %% %%  read ICA component timeseries
  ICA = functionnormalise(load('filtered_func_data.ica/melodic_mix'));
  
  %% %%  do the cleanup
  if aggressive == 1
    fprintf('aggressive cleanup')
    confounds=[confounds ICA(:,DDremove)];
    if DOvol
      % This regression peaks at a memory of > 2x (seemingly ~ 2.5x) the size of cts
      cts = cts - (confounds * (pinv(confounds,1e-6) * cts));
    end
    if DObrainord
      BO.cdata = BO.cdata - (confounds * (pinv(confounds,1e-6) * BO.cdata'))';
    end
  else
    fprintf('unaggressive cleanup')
    if domot == 1
      % aggressively regress out motion parameters from ICA and from data
      ICA = ICA - (confounds * (pinv(confounds,1e-6) * ICA));
      if DOvol
        cts = cts - (confounds * (pinv(confounds,1e-6) * cts));
      end
      if DObrainord
        BO.cdata = BO.cdata - (confounds * (pinv(confounds,1e-6) * BO.cdata'))';
      end
    end
    if DOvol
      betaICA = pinv(ICA,1e-6) * cts;                         % beta for ICA (good *and* bad)
      cts = cts - (ICA(:,DDremove) * betaICA(DDremove,:));    % cleanup
    end
    if DObrainord
      betaICA = pinv(ICA,1e-6) * BO.cdata';                              % beta for ICA (good *and* bad)
      BO.cdata = BO.cdata - (ICA(:,DDremove) * betaICA(DDremove,:))';    % cleanup
    end
  end
  
  %% %% save cleaned data to file
  if DOvol
    ctsfull=zeros(ctsX*ctsY*ctsZ,ctsT,class(cts));
    ctsfull(ctsmask,:)=cts';
    save_avw(reshape(ctsfull,ctsX,ctsY,ctsZ,ctsT),'filtered_func_data_clean','f',[1 1 1 1]);
    clear ctsfull;
    call_fsl('fslcpgeom filtered_func_data filtered_func_data_clean');
  end
  if DObrainord
    ciftisave(BO,'Atlas_clean.dtseries.nii',WBC);
  end
  
  %% %% compute variance normalization field and save to file
  DDSignal=setdiff(1:1:size(ICA,2),DDremove); % select signal components
  if DOvol
    betaICA = pinv(ICA(:,DDSignal),1e-6) * cts; % beta for ICA (good, bad already removed)
    cts = cts - (ICA(:,DDSignal) * betaICA);    % remove signal components to compute unstructured noise timeseries
    cts = std(cts);                             % compute variance normalization map
    vnfull=zeros(ctsX*ctsY*ctsZ,1,class(cts));
    vnfull(ctsmask)=cts';
    save_avw(reshape(vnfull,ctsX,ctsY,ctsZ),'filtered_func_data_clean_vn','f',[1 1 1 1]);
    call_fsl('fslcpgeom filtered_func_data filtered_func_data_clean_vn -d');
  end
  if DObrainord
    betaICA = pinv(ICA(:,DDSignal),1e-6) * BO.cdata';      % beta for ICA (good, bad already removed)
    BO.cdata = BO.cdata - (ICA(:,DDSignal) * betaICA)';    % remove signal components to compute unstructured noise timeseries
    BO.cdata = std(BO.cdata,[],2);                         % compute variance normalization map
    ciftisavereset(BO,'Atlas_clean_vn.dscalar.nii',WBC);
  end
  
  %% %% compute movement regressors with noise components removed
  if domot == 0
    confounds = functionmotionconfounds(TR,hp);
    if aggressive == 1
      % aggressively regress out noise ICA components from movement regressors
      betaconfounds = pinv(ICA(:,DDremove),1e-6) * confounds;                              % beta for confounds (bad only)
      confounds = confounds - (ICA(:,DDremove) * betaconfounds);    % cleanup
    else
      % non-aggressively regress out noise ICA components from movement regressors
      betaconfounds = pinv(ICA,1e-6) * confounds;                              % beta for confounds (good *and* bad)
      confounds = confounds - (ICA(:,DDremove) * betaconfounds(DDremove,:));    % cleanup
    end
    save_avw(reshape(confounds',size(confounds,2),1,1,size(confounds,1)),'mc/prefiltered_func_data_mcf_conf_hp_clean','f',[1 1 1 TR]);
  end
  cd(curDir);
  fprintf('\n')
  
  %% subfunctions
  function x = functionnormalise(x,dim)
    % normalise(X) 
    % Removes the Average or mean value and makes the std=1
    %
    % normalise(X,DIM)
    % Removes the mean and makes the std=1 along the dimension DIM of X. 
    
    if(nargin==1)
       dim = 1;
       if(size(x,1) > 1)
          dim = 1;
       elseif(size(x,2) > 1)
          dim = 2;
       end
    end
    dims = size(x);
    dimsize = size(x,dim);
    dimrep = ones(1,length(dims));
    dimrep(dim) = dimsize;
    
    x = x - repmat(mean(x,dim),dimrep);
    x = x./repmat(max(std(x,0,dim),0.00001),dimrep);
  end
  
  function confounds = functionmotionconfounds(TR, hp)
    [~,grotb]=call_fsl('imtest mc/prefiltered_func_data_mcf_conf_hp');
    if isequal(str2double(grotb),1)
      confounds=read_avw('mc/prefiltered_func_data_mcf_conf_hp');
      confounds=functionnormalise(reshape(confounds,size(confounds,1),size(confounds,4))');
    else
      confounds=load('mc/prefiltered_func_data_mcf.par');
      confounds=confounds(:,1:6);
      %confounds=functionnormalise(confounds(:,std(confounds)>0.000001)); % remove empty columns
      confounds=functionnormalise([confounds [zeros(1,size(confounds,2)); confounds(2:end,:)-confounds(1:end-1,:)] ]);
      confounds=functionnormalise([confounds confounds.*confounds]);
      if hp==0
        confounds=detrend(confounds);
      end
      if hp>0
        save_avw(reshape(confounds',size(confounds,2),1,1,size(confounds,1)),'mc/prefiltered_func_data_mcf_conf','f',[1 1 1 TR]);
        call_fsl(sprintf('fslmaths mc/prefiltered_func_data_mcf_conf -bptf %f -1 mc/prefiltered_func_data_mcf_conf_hp',0.5*hp/TR));
        confounds=functionnormalise(reshape(read_avw('mc/prefiltered_func_data_mcf_conf_hp'),size(confounds,2),size(confounds,1))');
      end
    end
  end
end %EOF
