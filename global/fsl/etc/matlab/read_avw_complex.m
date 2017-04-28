function [img,dims,scales,bpp,endian] = read_avw_complex(fname)
% [img, dims,scales,bpp,endian] = READ_AVW_COMPLEX(fname)
%
%  Read in a complex analyse file into either a 3D or 4D
%  array (depending on the header information)
%  Uses avwcomplex to make temporary files for reading
%  Ouput coordinates are in MEDx convention
%  except that all dimensions start at 1 rather than 0
%  Note: automatically detects char, short, long or double formats
%  Extracts the 4 dimensions (dims), 
%  4 scales (scales) and bytes per pixel (bpp) for voxels 
%  contained in the Analyse header file (fname)
%  Also returns endian = 'l' for little-endian or 'b' for big-endian
%
%  See also: READ_AVW_HDR, READ_AVW_IMG, SAVE_AVW, SAVE_AVW_HDR,
%            SAVE_AVW_IMG, SAVE_AVW_COMPLEX
%   

command=sprintf('${FSLDIR}/bin/fslcomplex -realcartesian %s %s %s',fname,[fname,'R'],[fname,'I']);
[status,output] = call_fsl(command);
if (status),
  error(output)
end

[imgr,dims,scales,bpp,endian]=read_avw([fname,'R']);
[imgi,dims,scales,bpp,endian]=read_avw([fname,'I']);

img = imgr + j * imgi;

% cross platform compatible deleting of files
delete([fname,'R','.hdr']);
delete([fname,'R','.img']);
delete([fname,'I','.hdr']);
delete([fname,'I','.img']);
