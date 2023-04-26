function [img,dims,scales,bpp,endian] = read_avw(fname)
% [img, dims,scales,bpp,endian] = READ_AVW(fname)
%
%  Read in an Analyze or nifti file into either a 3D or 4D
%  array (depending on the header information)
%  fname is the filename (must be inside single quotes)
%  Note: automatically detects - unsigned char, short, long, float
%         double and complex formats
%  Extracts the 4 dimensions (dims), 
%  4 scales (scales) and bits per pixel (bpp) for voxels 
%  contained in the Analyze or nifti header file (fname)
%  Also returns endian = 'l' for little-endian or 'b' for big-endian
%
%  See also: SAVE_AVW

% remove extension if it exists



%% convert to uncompressed nifti pair (using FSL)
tmpname = tempname;

command = sprintf('FSLOUTPUTTYPE=NIFTI_PAIR; export FSLOUTPUTTYPE; $FSLDIR/bin/fslmaths %s %s', fname, tmpname);
[status,output]=call_fsl(command);

if (status),
  error(output)
end
  [dims,scales,bpp,endian,datatype]= read_avw_hdr(tmpname);
  if (datatype==32),
    % complex type
    img=read_avw_complex(tmpname);
  else
    img=read_avw_img(tmpname);
  end
  
% cross platform compatible deleting of files
delete([tmpname,'.hdr']);
delete([tmpname,'.img']);
