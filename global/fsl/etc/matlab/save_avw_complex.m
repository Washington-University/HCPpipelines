function save_avw_complex(img,fname,vsize)
% SAVE_AVW_COMPLEX(img,fname,vsize) 
%
%  Create and save an analyse header (.hdr) and image (.img) file
%   for either a 2D or 3D or 4D array (automatically determined).
%  Only for use with complex data.  (uses avwcomplex)
%
%  vsize is a vector [x y z tr] containing the voxel sizes in mm and
%  the tr in seconds  (defaults: [1 1 1 3])
%
%  See also: SAVE_AVW, SAVE_AVW_HDR, SAVE_AVW_IMG, 
%            READ_AVW_COMPLEX, READ_AVW, READ_AVW_HDR, READ_AVW_IMG
%

save_avw(real(img),[fname,'R'],'f',vsize);
save_avw(imag(img),[fname,'I'],'f',vsize);
command=sprintf('$FSLDIR/bin/fslcomplex -complex %s %s %s',[fname,'R'],[fname,'I'],fname);
[status,output]=call_fsl(command);
if (status),
  error(output)
end
% cross platform compatible deleting of files
delete([fname,'R','.hdr']);
delete([fname,'R','.img']);
delete([fname,'I','.hdr']);
delete([fname,'I','.img']);
