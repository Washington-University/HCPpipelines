function functionhighpassandvariancenormalize(TR, hp, fmri, WBC, varargin)
%
% FUNCTIONHIGHPASSANDVARIANCENORMALIZE(TR, HP, FMRI, WBC, [REGSTRING], [VOLWISHARTOVERRIDE], [CIFTIWISHARTOVERRIDE], [ICADIMMODE])
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
%     HP<0: No highpass applied (demeaning only). No 'hp' string will be added as part of the file names.
%     HP>0: The full-width (2*sigma), in sec, to apply using 'fslmaths -bptf'.
%     HP='pd#': If HP is a string, in which the first two characters are 'pd', followed by an integer value,
%               then polynomial detrending is applied, with the order specified by the integer value 
%               embedded at the end of the string.
%               The output files will include the string '_hppd#'
%     HP=0: Gets interpreted as a linear (1st order) detrend
%           This is consistent with the convention in FIX of using HP=0 to specify a linear detrend.
%           The output file names will include the string '_hp0'.
% FMRI: The base string of the fmri time series (no extensions)
% WBC: wb_command (full path)
% [REGSTRING]: Additional registration-related string to add to output file names. OPTIONAL.
% [VOLWISHARTOVERRIDE]: Change the number of volume wisharts. OPTIONAL.
% [CIFTIWISHARTOVERRIDE]: Change the number of surface wisharts. OPTIONAL.
% [ICADIMMODE]: 'default' or 'fewtimepoints'. OPTIONAL.

% Note: HP='pd0' would be interpreted as a true 0th order detrend, which is 
% the same as demeaning. Mathematically, this is the same as the HP<0 condition,
% but the output files will be named differently (i.e., include '_hppd0'), and additional
% output files will be written relative to the HP<0 condition.

% Authors: M. Glasser and M. Harms

%% Defaults
dovol = true;
regstring = '';
pdflag = false;  % Polynomial detrend
pdstring = 'pd';  % Expected string at start of HP variable to request a "polynomial detrend"
volwishart = 2;  %Volume fits 2 distributions by default to deal with MNI transform
ciftiwishart = 3;  %CIFTI fits 3 distributions by default to deal with volume to CIFTI mapping
VN = 1; %first iteration uses 1 for dimensionality
iters = -1; %iterate until the average of the dimensionality history doesn't change much
VNhalfdim = false; %after loading the input, set VN to half the timepoints

%% Parse varargin
if length(varargin) >= 1 && ~isempty(varargin{1})
    dovol = false; %regname is only used for a new surface registration, so will never require redoing volume
    regstring = varargin{1}; %this has the underscore on the front already
    if ~ischar(regstring)
        error('%s: REGSTRING should be a string', mfilename());
    end
end

if length(varargin) >= 2
    if isdeployed()
        volwishart = str2double(varargin{2});
    else
        volwishart = varargin{2};
    end
end

if length(varargin) >= 3
    if isdeployed()
        ciftiwishart = str2double(varargin{3});
    else
        ciftiwishart = varargin{3};
    end
end

if length(varargin) >= 4
    switch varargin{4}
        case {'default', ''}
            %leave things alone
        case 'fewtimepoints'
            iters = 1;
            VNhalfdim = true;
        otherwise
            error(['unknown ICADIMMODE value: ' varargin{4}]);
    end
end

%% Allow for compiled matlab
if isdeployed()
    TR = str2double(TR);
end

% Check whether polynomial detrend is being requested for the high-pass filtering.
% Coincidentally deals with compiled matlab arguments
if ischar(hp)
    hp = lower(hp);
    if strncmp(hp,pdstring,numel(pdstring))
        pdflag = true;
        polydeg = str2double(hp(numel(pdstring)+1:end));  % different purposes should use a different variable name
        if (~isscalar(polydeg) || polydeg < 0 || polydeg ~= fix(polydeg))
            error('%s: Invalid specification for the order of the polynomial detrending', mfilename());
        end
    else
        hp = str2double(hp);
        if ~isscalar(hp) || isnan(hp)  % Allow for hp to be provided as a string that contains purely numeric elements
            error('%s: Invalid specification for the high-pass filter', mfilename());
        end
    end
end

%write out the hpstring logic explicitly, rather than tracing a bunch of code paths
%must NOT be moved below the hp == 0 check below
if pdflag
    %explicit polynomial detrending can say whatever
    hpstring = ['_hp' pdstring num2str(polydeg)];
else
    if hp < 0
        %negatives mean skip hp, don't put it in the filename
        hpstring = '';
    else
        %hp='0' ends up here
        hpstring = ['_hp' num2str(hp)];
    end
end

%special case hp=0 to do linear detrend
if ~pdflag && hp == 0
    warning('%s: hp=0 will be interpreted as polynomial detrending of order 1', mfilename());
    pdflag = true;
    polydeg = 1;
end

% NOTE: To interpret the logic of the following "Compute, Save, Apply" sections need to know that this function expects that: 
% (1) individual run time series will be passed in with hp requested
% (2) concatenated (multi-run) time series will be passed in with hp<0
%% [This is a bit of hack: would be cleaner if we disentangled the operation of this function from the specific needs of 'hcp_fix_multi_run'].

%TSC: so, let's make a new variable that actually conveys some understanding of the logic
%HACK: assume hp < 0 is equivalent to concatenated input
%Note that concatenated input (hp < 0) does not save out any VN estimates [for either NIFTI (volume) or CIFTI].
singlerun = pdflag || (hp >= 0);

%% Load the motion confounds, and the CIFTI (if single run) (don't need either if MR FIX)
if singlerun
    confounds=load([fmri hpstring '.ica/mc/prefiltered_func_data_mcf.par']);
    confounds=confounds(:,1:6);
    %% normalise function is in $HCPPIPEDIR/global/matlab/normalise.m
    confounds=normalise([confounds [zeros(1,size(confounds,2)); confounds(2:end,:)-confounds(1:end-1,:)] ]);
    confounds=normalise([confounds confounds.*confounds]);

    BO=ciftiopen([fmri '_Atlas' regstring '.dtseries.nii'],WBC);
end

%% Apply hp filtering of the motion confounds, volume (if requested), and CIFTI
if pdflag  % polynomial detrend case, assumes single run
    if dovol
        % Save and filter confounds, as a NIFTI, as expected by FIX
        save_avw(reshape(confounds',size(confounds,2),1,1,size(confounds,1)),[fmri hpstring '.ica/mc/prefiltered_func_data_mcf_conf'],'f',[1 1 1 TR]);
        confounds=detrendpoly(confounds, polydeg);
        save_avw(reshape(confounds',size(confounds,2),1,1,size(confounds,1)),[fmri hpstring '.ica/mc/prefiltered_func_data_mcf_conf_hp'],'f',[1 1 1 TR]);

        % Load volume time series and reduce to just the non-zero voxels (for memory efficiency)
        % Note: Use 'range' to identify non-zero voxels (which is very memory efficient)
        % rather than 'std' (which requires additional memory equal to the size of the input)
        ctsfull=single(read_avw([fmri '.nii.gz']));
        ctsX=size(ctsfull,1); ctsY=size(ctsfull,2); ctsZ=size(ctsfull,3); ctsT=size(ctsfull,4); 
        ctsfull=reshape(ctsfull,ctsX*ctsY*ctsZ,ctsT);
        ctsmask=range(ctsfull, 2) > 0;
        fprintf('Non-empty voxels: %d (= %.2f%% of %d)\n', sum(ctsmask), 100*sum(ctsmask)/size(ctsfull,1), size(ctsfull,1));
        cts=ctsfull(ctsmask,:); 
        clear ctsfull;

        % Polynomial detrend
        cts=detrendpoly(cts', polydeg)';

        % Write out result, restoring to original size
        ctsfull=zeros(ctsX*ctsY*ctsZ,ctsT, 'single');
        ctsfull(ctsmask,:)=cts;
        save_avw(reshape(ctsfull,ctsX,ctsY,ctsZ,ctsT),[fmri hpstring '.nii.gz'],'f',[1 1 1 TR]); 
        clear ctsfull;
        % Use -d flag in fslcpgeom (even if not technically necessary) to reduce possibility of mistakes when editing script
        call_fsl(['fslcpgeom ' fmri '.nii.gz ' fmri hpstring '.nii.gz -d']);
    end
    
    BO.cdata=detrendpoly(BO.cdata', polydeg)';
    ciftisave(BO,[fmri '_Atlas' regstring hpstring '.dtseries.nii'],WBC);

elseif hp > 0  % "fslmaths -bptf" based filtering, assumes single run
    if dovol
        % Save and filter confounds, as a NIFTI, as expected by FIX
        save_avw(reshape(confounds',size(confounds,2),1,1,size(confounds,1)),[fmri hpstring '.ica/mc/prefiltered_func_data_mcf_conf'],'f',[1 1 1 TR]);
        call_fsl(sprintf(['fslmaths ' fmri hpstring '.ica/mc/prefiltered_func_data_mcf_conf -bptf %f -1 ' fmri hpstring '.ica/mc/prefiltered_func_data_mcf_conf_hp'],0.5*hp/TR));

        % bptf filtering; no masking here, so this is probably memory inefficient
        call_fsl(['fslmaths ' fmri '.nii.gz -bptf ' num2str(0.5*hp/TR) ' -1 ' fmri hpstring '.nii.gz']);
        call_fsl(['fslcpgeom ' fmri '.nii.gz ' fmri hpstring '.nii.gz -d']);
        
        % Load in result and reduce to just the non-zero voxels (for memory efficiency going forward)
        ctsfull=single(read_avw([fmri hpstring '.nii.gz']));
        ctsX=size(ctsfull,1); ctsY=size(ctsfull,2); ctsZ=size(ctsfull,3); ctsT=size(ctsfull,4);
        ctsfull=reshape(ctsfull,ctsX*ctsY*ctsZ,ctsT);
        ctsmask=range(ctsfull, 2) > 0;
        fprintf('Non-empty voxels: %d (= %.2f%% of %d)\n', sum(ctsmask), 100*sum(ctsmask)/size(ctsfull,1), size(ctsfull,1));
        cts=ctsfull(ctsmask,:); 
        clear ctsfull;
    end
    
    BOdimX=size(BO.cdata,1);  BOdimZnew=ceil(BOdimX/100);  BOdimT=size(BO.cdata,2);
    save_avw(reshape([BO.cdata ; zeros(100*BOdimZnew-BOdimX,BOdimT)],10,10,BOdimZnew,BOdimT),'Atlas','f',[1 1 1 TR]);
    call_fsl(sprintf('fslmaths Atlas -bptf %f -1 Atlas',0.5*hp/TR));
    grot=reshape(single(read_avw('Atlas')),100*BOdimZnew,BOdimT);  BO.cdata=grot(1:BOdimX,:);  clear grot;
    ciftisave(BO,[fmri '_Atlas' regstring hpstring '.dtseries.nii'],WBC);
    delete('Atlas.nii.gz');

elseif hp < 0  % If no hp filtering, still need to at least demean the volumetric time series, note the above code assumes concatenated input in this condition, so the cifti and motion parameters aren't loaded
    if dovol

        % Load volume time series and reduce to just the non-zero voxels (for memory efficiency)
        ctsfull=single(read_avw([fmri '.nii.gz']));
        ctsX=size(ctsfull,1); ctsY=size(ctsfull,2); ctsZ=size(ctsfull,3); ctsT=size(ctsfull,4);
        ctsfull=reshape(ctsfull,ctsX*ctsY*ctsZ,ctsT);
        ctsmask=range(ctsfull, 2) > 0;
        fprintf('Non-empty voxels: %d (= %.2f%% of %d)\n', sum(ctsmask), 100*sum(ctsmask)/size(ctsfull,1), size(ctsfull,1));
        cts=ctsfull(ctsmask,:);
        clear ctsfull;
        
        cts=demean(cts')';
    end

end

if VNhalfdim
    if dovol
        VN = ceil(size(cts, 2) / 2);
    else
        VN = ceil(size(B0.cdata, 2) / 2);
    end
end

%% Compute VN map
if singlerun
    if dovol
        Outcts = icaDim(cts, 0, VN, iters, volwishart); 
    end
    
    OutBO = icaDim(BO.cdata, 0, VN, iters, ciftiwishart);
else
    %concatenated input
    if dovol
        Outcts = icaDim(cts, 0, VN, iters, volwishart);
    end
end

%% Save VN map
% (Only need these for the individual runs, which, per above, are expected to be passed in with hp requested).
if singlerun
    if dovol
        fname=[fmri hpstring '_vn.nii.gz'];
        vnfull=zeros(ctsX*ctsY*ctsZ,1, 'single');
        vnfull(ctsmask)=Outcts.noise_unst_std;
          
        save_avw(reshape(vnfull,ctsX,ctsY,ctsZ,1),fname,'f',[1 1 1 1]); 
        clear vnfull;
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
if dovol
    cts=cts./repmat(Outcts.noise_unst_std,1,ctsT);
    % Use '_vnts' (volume normalized time series) as the suffix for the volumetric VN'ed TCS
    fname=[fmri hpstring '_vnts.nii.gz'];
    ctsfull=zeros(ctsX*ctsY*ctsZ,ctsT, 'single');
    ctsfull(ctsmask,:)=cts;
    save_avw(reshape(ctsfull,ctsX,ctsY,ctsZ,ctsT),fname,'f',[1 1 1 1]);
    clear ctsfull;
    % N.B. Version of 'fslcpgeom' in FSL 6.0.0 requires a patch because it doesn't copy both the qform and sform faithfully
    call_fsl(['fslcpgeom ' fmri '.nii.gz ' fname ' -d']); 
end
% For CIFTI, we can use the extension to distinguish between VN maps (.dscalar) and VN'ed time series (.dtseries)
if singlerun
    BO.cdata=BO.cdata./repmat(OutBO.noise_unst_std,1,size(BO.cdata,2));
    ciftisave(BO,[fmri '_Atlas' regstring hpstring '_vn.dtseries.nii'],WBC); 
end

%Echo Dims
%TSC: add the regstring to the output filename to avoid overwriting
if singlerun
    if dovol
        dlmwrite([fmri regstring '_dims.txt'],[Outcts.calcDim OutBO.calcDim],'\t');
    else
        dlmwrite([fmri regstring '_dims.txt'],[OutBO.calcDim],'\t');
    end
else
    %concatenated input
    %TSC: this mode never gets called with a regstring
    dlmwrite([fmri '_dims.txt'],[Outcts.calcDim],'\t');
end

end


%% ----------------------------------------------

%% Polynomial detrending function
function Y = detrendpoly(X,p);

    % X: Input data (column major order)
    % p: Order of polynomial to remove
    % Y: Detrended output
      
    % Need to define a function to accomplish this, because MATLAB's own DETREND
    % is only capable of removing a *linear* trend (i.e., "p=1" only), until r2022b(?)
  
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

    % 5/1/2019 -- Construct the "Vandermonde matrix" (V) scaled to a maximum of 1, for better numerical properties.
    % Note that Octave's DETREND function supports arbitrary polynomial orders, but computes V by taking powers
    % of [1:r] (rather than [1:r]/r), which is not numerically robust as p increases.

    V = ([1 : r]'/r * ones (1, p + 1)) .^ (ones (r, 1) * [0 : p]);  % "Vandermonde" design matrix

    % Cast design matrix to 'single' if the input is also 'single' (which CIFTI will be)
    if strcmp(class(X),'single')
        V = single(V);
    end

    % Use mldivide ('\') as the linear solver, as it has the nice property of generating a warning
    % if the solution is rank deficient (in MATLAB at least; Octave doesn't appear to generate a similar warning).
    % [In contrast, PINV does NOT generate a warning if the singular values are less than its internal tolerance].
    % Note that even with the scaling of the Vandermonde matrix to a maximum of 1, rank deficiency starts
    % becoming a problem at p=6 for data of class 'single' and 1200 time points.
    % Rather than explicitly restricting the allowed order here, we'll code a restriction into the calling scripts.

    Y = X - V * (V \ X);  % Remove polynomial fit

end
  
