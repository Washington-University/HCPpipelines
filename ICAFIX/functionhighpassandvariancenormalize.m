function functionhighpassandvariancenormalize(TR,hp,fmri,WBC,varargin)
%
% FUNCTIONHIGHPASSANDVARIANCENORMALIZE(TR,HP,FMRI,WBC,[REGSTRING],[POLYDETREND])
% 
% This function:
% (1) Detrends / high-pass filters motion confounds, NIFTI (volume) and CIFTI files
% (2) Calls icaDim.m to estimate the dimensionalities of structured and unstructured noise,
%     and compute a spatial variance normalization map.
% It is written to support 'hcp_fix_multi_run', and is not intended as a general (stand-alone)
% function supporting detrending and variance normalization.
%
% TR: repetition time between frames, in sec
% HP: determines what high-pass filtering to apply to the motion confounds and data
%     HP<0: No highpass applied (demeaning only). No "hp" string will be added as part of the file names.
%     HP>0: If POLYDETREND flag is not set (see below), then HP specifies the full-width (2*sigma), in sec,
%           to apply using 'fslmaths -bptf'.
%           If POLYDETREND flag is set, then HP specifies the order of a polynomial detrending, 
%           and needs to be an integer.
%     HP=0: If POLYDETREND flag is not set, HP=0 gets interpreted as a linear (1st order) detrend
%           (this is consistent with the convention in FIX of using HP=0 to specify a linear detrend), 
%           but the output file names will be named consistent with a 1st order polynomial detrend.
%           [i.e., "_hppd1", rather than "_hp0"]
%           If POLYDETREND flag is set, HP=0 gets interpreted as a true 0th order detrend, which is 
%           the same as demeaning. Mathematically, this is the same as the HP<0 condition,
%           but the output file will be named differently (i.e., "_hppd0"), and additional
%           output files will be written.
% FMRI: The base string of the fmri time series (no extensions)
% WBC: wb_command (full path)
% [REGSTRING]: Additional registration-related string to add to output file names. OPTIONAL.
% [POLYDETREND]: Controls whether value of HP should be interpreted as specifying the order
%                for a polynomial detrend.  See above for how it impacts the interpretation of HP.
%                Values: true (or 1) or false (or 0).
%                OPTIONAL. (Default: false).
  
% Authors: M. Glasser and M. Harms

CIFTIMatlabReaderWriter=getenv('FSL_FIX_CIFTIRW');
addpath(CIFTIMatlabReaderWriter);

%% Defaults
dovol = 1;
regstring = '';
pdflag = false;  % Polynomial detrend

%% Parse varargin
if length(varargin) >= 1 && ~isempty(varargin{1})
  dovol = 0; %regname is only used for a new surface registration, so will never require redoing volume
  regstring = varargin{1}; %this has the underscore on the front already
  if ~ischar(regstring)
	error('REGSTRING should be a string');
  end
end
if length(varargin) >= 2 && ~isempty(varargin{2})
  pdflag = varargin{2};
end
if ischar(pdflag)
  if strcmp(lower(pdflag),'true')
	pdflag = true;
  elseif strcmp(lower(pdflag),'false')
	pdflag = false;
  else error('Invalid specification of POLYDETREND flag')
  end
end

%% Allow for compiled matlab
if (isdeployed)
  tr = str2num(tr);
  hp = str2num(hp);
end

if pdflag < 0
  error('Invalid specification of POLYDETREND flag')
end

%% Argument checking
if hp==0 && ~pdflag
  fprintf('hp=0 will be interpreted as polynomial detrending of order 1');
  pdflag=true;
  hp=1;
end
if pdflag
  if (~isscalar(hp) || hp < 0 || hp ~= fix(hp))
	error('hp must be a non-negative integer when requesting polynomial detrending');
  end
end
%% N.B. The above allows for users to specify hp=0, pdflag=true as their input, in which case
%% a polynomial detrend of order 0 (i.e., remove the mean) will be executed.
%% That isn't necessary, since demeaning is always performed, but would impact the manner
%% in which the files are named.

%% Set up the hp string to use in file names
if pdflag
  pdstring = 'pd';  % For "polynomial detrend"
else
  pdstring = '';
end
if hp>=0
    hpstring = ['_hp' pdstring num2str(hp)];
else
    hpstring = '';
end

%% Load volume time series
if dovol > 0
    cts=single(read_avw([fmri '.nii.gz']));
    ctsX=size(cts,1); ctsY=size(cts,2); ctsZ=size(cts,3); ctsT=size(cts,4); 
    cts=reshape(cts,ctsX*ctsY*ctsZ,ctsT);
end

%% Load the motion confounds, and the CIFTI (if hp>=0) (don't need either if hp<0)
if hp>=0
    confounds=load([fmri hpstring '.ica/mc/prefiltered_func_data_mcf.par']);
    confounds=confounds(:,1:6);
    confounds=functionnormalise([confounds [zeros(1,size(confounds,2)); confounds(2:end,:)-confounds(1:end-1,:)] ]);
    confounds=functionnormalise([confounds confounds.*confounds]);

    BO=ciftiopen([fmri '_Atlas' regstring '.dtseries.nii'],WBC);
end

%% Apply hp filtering of the motion confounds, volume (if requested), and CIFTI
if pdflag  % polynomial detrend case
    if dovol > 0
        save_avw(reshape(confounds',size(confounds,2),1,1,size(confounds,1)),[fmri hpstring '.ica/mc/prefiltered_func_data_mcf_conf'],'f',[1 1 1 TR]);
        confounds=detrendpoly(confounds,hp);
        save_avw(reshape(confounds',size(confounds,2),1,1,size(confounds,1)),[fmri hpstring '.ica/mc/prefiltered_func_data_mcf_conf_hp'],'f',[1 1 1 TR]);
        
        cts=detrendpoly(cts',hp)';
        save_avw(reshape(cts,ctsX,ctsY,ctsZ,ctsT),[fmri hpstring '.nii.gz'],'f',[1 1 1 TR]);
		% Use -d flag in fslcpgeom (even if not technically necessary) to reduce possibility of mistakes when editing script
        call_fsl(['fslcpgeom ' fmri '.nii.gz ' fmri hpstring '.nii.gz -d']);
    end
    
    BO.cdata=detrendpoly(BO.cdata',hp)';
    ciftisave(BO,[fmri '_Atlas' regstring hpstring '.dtseries.nii'],WBC);

elseif hp>0  % "fslmaths -bptf" based filtering
    if dovol > 0
        save_avw(reshape(confounds',size(confounds,2),1,1,size(confounds,1)),[fmri hpstring '.ica/mc/prefiltered_func_data_mcf_conf'],'f',[1 1 1 TR]);
        call_fsl(sprintf(['fslmaths ' fmri hpstring '.ica/mc/prefiltered_func_data_mcf_conf -bptf %f -1 ' fmri hpstring '.ica/mc/prefiltered_func_data_mcf_conf_hp'],0.5*hp/TR));

        save_avw(reshape(cts,ctsX,ctsY,ctsZ,ctsT),[fmri hpstring '.nii.gz'],'f',[1 1 1 TR]);
        call_fsl(['fslmaths ' fmri hpstring '.nii.gz -bptf ' num2str(0.5*hp/TR) ' -1 ' fmri hpstring '.nii.gz']);
        cts=single(read_avw([fmri hpstring '.nii.gz']));
        cts=reshape(cts,ctsX*ctsY*ctsZ,ctsT);
        call_fsl(['fslcpgeom ' fmri '.nii.gz ' fmri hpstring '.nii.gz -d']);
    end
    
    BOdimX=size(BO.cdata,1);  BOdimZnew=ceil(BOdimX/100);  BOdimT=size(BO.cdata,2);
    save_avw(reshape([BO.cdata ; zeros(100*BOdimZnew-BOdimX,BOdimT)],10,10,BOdimZnew,BOdimT),'Atlas','f',[1 1 1 TR]);
    call_fsl(sprintf('fslmaths Atlas -bptf %f -1 Atlas',0.5*hp/TR));
    grot=reshape(single(read_avw('Atlas')),100*BOdimZnew,BOdimT);  BO.cdata=grot(1:BOdimX,:);  clear grot;
    call_fsl('rm Atlas.nii.gz');
    ciftisave(BO,[fmri '_Atlas' regstring hpstring '.dtseries.nii'],WBC);

elseif hp<0  % If no hp filtering, still need to at least demean the volumetric time series
    if dovol > 0
	    cts=demean(cts')';
    end

end


% NOTE: To interpret the logic of the following "Compute, Save, Apply" sections need to know that this function expects that: 
% (1) individual run time series will be passed in with hp requested
% (2) concatenated (multi-run) time series will be passed in with hp<0
%% [This is a bit of hack: would be cleaner if we disentangled the operation of this function from the specific needs of 'hcp_fix_multi_run'].

%% Compute VN map
if hp>=0
    if dovol > 0
        Outcts=icaDim(cts,0,1,2,2); %Volume fits two distributions to deal with processing interpolation and multiband
    end
    
    OutBO=icaDim(BO.cdata,0,1,2,3); %CIFTI fits three because of the effects of volume to CIFTI mapping and regularization
else
    if dovol > 0
        Outcts=icaDim(cts,0,1,2,3); %Volume fits three distributions to deal with processing interpolation and multiband and concatenation effects
    end
end

%% Save VN map
% (Only need these for the individual runs, which, per above, are expected to be passed in with hp requested).
if hp>=0
    if dovol > 0
	    fname=[fmri hpstring '_vn.nii.gz'];
        save_avw(reshape(Outcts.noise_unst_std,ctsX,ctsY,ctsZ,1),fname,'f',[1 1 1 1]);
		call_fsl(['fslcpgeom ' fmri '_mean.nii.gz ' fname ' -d']);
    end

    VN=BO;
    VN.cdata=OutBO.noise_unst_std;
	fname=[fmri '_Atlas' regstring hpstring '_vn.dscalar.nii'];
    disp(['saving ' fname]);
    ciftisavereset(VN,fname,WBC);    
end

%% Apply VN and Save HP_VN TCS
% Here, NIFTI VN'ed TCS gets saved regardless of whether hp>=0 (i.e., regardless of whether individual or concatenated run)
% But CIFTI version of TCS only saved if hp>0
if dovol > 0
    cts=cts./repmat(Outcts.noise_unst_std,1,ctsT);
	% Use '_vnts' (volume normalized time series) as the suffix for the volumetric VN'ed TCS
	fname=[fmri hpstring '_vnts.nii.gz'];
	save_avw(reshape(cts,ctsX,ctsY,ctsZ,ctsT),fname,'f',[1 1 1 1]); 
	% N.B. Version of 'fslcpgeom' in FSL 6.0.0 requires a patch because it doesn't copy both the qform and sform faithfully
	call_fsl(['fslcpgeom ' fmri '.nii.gz ' fname ' -d']); 
end
% For CIFTI, we can use the extension to distinguish between VN maps (.dscalar) and VN'ed time series (.dtseries)
if hp>=0
    BO.cdata=BO.cdata./repmat(OutBO.noise_unst_std,1,size(BO.cdata,2));
    ciftisave(BO,[fmri '_Atlas' regstring hpstring '_vn.dtseries.nii'],WBC); 
end

%Echo Dims
%TSC: add the regstring to the output filename to avoid overwriting
if hp>=0
    if dovol > 0
        dlmwrite([fmri regstring '_dims.txt'],[Outcts.calcDim OutBO.calcDim],'\t');
    else
        dlmwrite([fmri regstring '_dims.txt'],[OutBO.calcDim],'\t');
    end
else
    %TSC: this mode never gets called with a regstring
    dlmwrite([fmri '_dims.txt'],[Outcts.calcDim],'\t');
end

end


%% ----------------------------------------------

%% Polynomial detrending function
function Y = detrendpoly(X,p);
  
  % Check data, must be in column order
  [m, n] = size(X);
  if (m == 1)
	X = X';
	r=n;
  else
	r=m;
  end
  
  if (~isscalar(p) || p < 0 || p ~= fix(p))
	error('order of polynomial (p) must be a non-negative integer');
  end
  
  b = ((1 : r)' * ones (1, p + 1)) .^ (ones (r, 1) * (0 : p))
  Y = X - b * (b \ X);
  
end
  