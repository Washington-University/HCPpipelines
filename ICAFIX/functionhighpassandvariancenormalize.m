function [ output_args ] = functionhighpassandvariancenormalize(TR,hp,fmri,WBC,varargin)
%UNTITLED4 Summary of this function goes here
%   Detailed explanation goes here

regstring = '';
dovol = 1;
if length(varargin) > 0 && ~strcmp(varargin{1}, '')
    dovol = 0;%regname is only used for a new surface registration, so will never require redoing volume
    regstring = varargin{1};%this has the underscore on the front already
end

if hp>=0
    hpstring = ['_hp' num2str(hp)];
else
    hpstring = '';
end

if dovol > 0
    cts=single(read_avw([fmri '.nii.gz']));
    ctsX=size(cts,1); ctsY=size(cts,2); ctsZ=size(cts,3); ctsT=size(cts,4); 
    cts=reshape(cts,ctsX*ctsY*ctsZ,ctsT);
end

if hp>=0
    confounds=load([fmri hpstring '.ica/mc/prefiltered_func_data_mcf.par']);
    confounds=confounds(:,1:6);
    confounds=functionnormalise([confounds [zeros(1,size(confounds,2)); confounds(2:end,:)-confounds(1:end-1,:)] ]);
    confounds=functionnormalise([confounds confounds.*confounds]);

    BO=ciftiopen([fmri '_Atlas' regstring '.dtseries.nii'],WBC);
else
    if dovol > 0
        cts=demean(cts')';
    end
end

if hp==0
    if dovol > 0
        save_avw(reshape(confounds',size(confounds,2),1,1,size(confounds,1)),[fmri hpstring '.ica/mc/prefiltered_func_data_mcf_conf'],'f',[1 1 1 TR]);
        confounds=detrend(confounds);
        save_avw(reshape(confounds',size(confounds,2),1,1,size(confounds,1)),[fmri hpstring '.ica/mc/prefiltered_func_data_mcf_conf_hp'],'f',[1 1 1 TR]);
        
        cts=detrend(cts')';
        save_avw(reshape(cts,ctsX,ctsY,ctsZ,ctsT),[fmri hpstring '.nii.gz'],'f',[1 1 1 TR]);
		% Use -d flag in fslcpgeom even if not technically necessary to reduce possibility of mistakes when editing script
        call_fsl(['fslcpgeom ' fmri '.nii.gz ' fmri hpstring '.nii.gz -d']);
    end
    
    BO.cdata=detrend(BO.cdata')';
    ciftisave(BO,[fmri '_Atlas' regstring hpstring '.dtseries.nii'],WBC);
end
if hp>0
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
end

%Compute VN
if hp>=0
    if dovol > 0
        Outcts=icaDim(cts,0,1,2,2); %Volume fits two distributions to deal with processing interpolation and multiband
    end
    
    OutBO=icaDim(BO.cdata,0,1,2,3); %CIFTI fits three because of the effects of volume to CIFTI mapping and regularization
else
    if dovol > 0
        Outcts=icaDim(cts,0,1,2,3); %Volume fits three distributions to deal with processing interpolation and multiband and concatination effects
    end
end

%Save VN
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

%Apply VN and Save HP_VN TCS
% Note that NIFTI VN'ed TCS gets saved regardless of whether hp>=0
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

