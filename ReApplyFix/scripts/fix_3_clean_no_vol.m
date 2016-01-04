%
% fix_3_clean(fixlist,aggressive,domot,hp) - apply the FIX cleanup to filtered_func_data
%
% fixlist is a vector of which ICA components to remove (starting at 1 not 0)
%
% aggressive = 0 or 1 - this controls whether cleanup is aggressive (all variance in confounds) or not (only unique variance)
%
% mot = 0 or 1 - this controls whether to regress motion parameters out of the data (24 regressors)
%
% hp determines what highpass filtering had been applied to the data (and so will get applied to the motion confound parameters)
% hp=-1 no highpass
% hp=0 linear trend removal
% hp>0 the fullwidth (2*sigma) of the highpass, in seconds (not TRs)
%

function fix_3_clean(fixlist,aggressive,domot,hp)
if (isdeployed)
    aggressive = str2num(aggressive)
    domot = str2num(domot)
    hp = str2num(hp)
end
%%% setup the following variables for your site

CIFTI=getenv('FSL_FIX_CIFTIRW');
WBC=getenv('FSL_FIX_WBC');

func_name='fix_3_clean';
fprintf('%s - fixlist: "%s"\n', func_name, fixlist);
fprintf('%s - aggressive: %d\n', func_name, aggressive);
fprintf('%s - domot: %d\n', func_name, domot);
fprintf('%s - hp: %d\n', func_name, hp);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%  read set of bad components
DDremove=load(fixlist);

%%%%  find TR of data
[grot,TR]=call_fsl('fslval filtered_func_data pixdim4'); TR=str2num(TR)
fprintf('%s - After "fslval filtered_func_data pixdim4" - TR: %d\n', func_name, TR);

%%%%  read and highpass CIFTI version of the data if it exists
DObrainord=0;
if exist('Atlas.dtseries.nii','file') == 2
  DObrainord=1;
  path(path,CIFTI);
  BO=ciftiopen('Atlas.dtseries.nii',WBC);
  if hp==0
    BO.cdata=detrend(BO.cdata')';
  end
  if hp>0
    BOdimX=size(BO.cdata,1);  BOdimZnew=ceil(BOdimX/100);  BOdimT=size(BO.cdata,2);
    meanBO=mean(BO.cdata,2);
    BO.cdata=BO.cdata-repmat(meanBO,1,size(BO.cdata,2));
    save_avw(reshape([BO.cdata ; zeros(100*BOdimZnew-BOdimX,BOdimT)],10,10,BOdimZnew,BOdimT),'Atlas','f',[1 1 1 TR]);

%   call_fsl(sprintf('fslmaths Atlas -bptf %f -1 Atlas',0.5*hp/TR));
    cmd_str=sprintf('fslmaths Atlas -bptf %f -1 Atlas',0.5*hp/TR);
    fprintf('%s - About to execute: %s\n',func_name,cmd_str);
    system(cmd_str);

    grot=reshape(read_avw('Atlas'),100*BOdimZnew,BOdimT);  BO.cdata=grot(1:BOdimX,:);  clear grot; BO.cdata=BO.cdata+repmat(meanBO,1,size(BO.cdata,2));
    ciftisave(BO,'Atlas_hp_preclean.dtseries.nii',WBC); % save out noncleaned hp-filtered data for future reference, as brainordinates file
  end
end

%%%%  read NIFTI version of the data
%cts=read_avw('filtered_func_data');
%ctsX=size(cts,1); ctsY=size(cts,2); ctsZ=size(cts,3); ctsT=size(cts,4); 
%cts=reshape(cts,ctsX*ctsY*ctsZ,ctsT)';

%%%%  read and prepare motion confounds
confounds=[];
if domot == 1
  confounds = functionmotionconfounds(TR,hp);
end

%%%%  read ICA component timeseries
ICA=functionnormalise(load(sprintf('filtered_func_data.ica/melodic_mix')));

%%%%  do the cleanup
if aggressive == 1
  sprintf('aggressive cleanup')
  confounds=[confounds ICA(:,DDremove)];
  %cts = cts - (confounds * (pinv(confounds) * cts));
  if DObrainord == 1
    BO.cdata = BO.cdata - (confounds * (pinv(confounds) * BO.cdata'))';
  end
else
  sprintf('unaggressive cleanup')
  if domot == 1
    % aggressively regress out motion parameters from ICA and from data
    ICA = ICA - (confounds * (pinv(confounds) * ICA));
    %cts = cts - (confounds * (pinv(confounds) * cts));
    if DObrainord == 1
      BO.cdata = BO.cdata - (confounds * (pinv(confounds) * BO.cdata'))';
    end
  end
  %betaICA = pinv(ICA) * cts;                              % beta for ICA (good *and* bad)
  %cts = cts - (ICA(:,DDremove) * betaICA(DDremove,:));    % cleanup
  if DObrainord == 1
    betaICA = pinv(ICA) * BO.cdata';                                   % beta for ICA (good *and* bad)
    BO.cdata = BO.cdata - (ICA(:,DDremove) * betaICA(DDremove,:))';    % cleanup
  end
end

%%%% save cleaned data to file
%save_avw(reshape(cts',ctsX,ctsY,ctsZ,ctsT),'filtered_func_data_clean','f',[1 1 1 1]);
%call_fsl('fslcpgeom filtered_func_data filtered_func_data_clean');
if DObrainord == 1
  ciftisave(BO,'Atlas_clean.dtseries.nii',WBC);
end

