function save_avw_img(img,fname,vtype,endian);
%  SAVE_AVW_IMG(img,fname,vtype,endian)
%
%  Save an array (img) as an analyse file (only the .img) 
%   for either a 2D or 3D or 4D array (automatically determined)
% 
%  vtype is a single character string: 'b' (unsigned) byte, 's' short, 
%                                      'i' int, 'f' float, or 'd' double
%
%  The filename (fname) must be a basename (no extensions)
%
%  See also: SAVE_AVW, SAVE_AVW_HDR, SAVE_AVW_COMPLEX,
%            READ_AVW, READ_AVW_HDR, READ_AVW_IMG, READ_AVW_COMPLEX
%

% swap first and second argument in case save_avw_img convention is
% used
check=length(size(fname));
if(check~=2)
   tmp=img;
   img=fname;
   fname=tmp;
end

fnimg=strcat(fname,'.img');

% use endianness if specified
if (nargin==4),
  fp=fopen(fnimg,'w',endian);
else
  fp=fopen(fnimg,'w');
end
dims = size(img);

%% DEFUNCT
%% flip y dimension to be consistent with MEDx
%% dat=flipdim(img,2);

dat = img;
dat = reshape(dat,prod(dims),1);

switch vtype
  case 'd'
    vtype2='double';
  case 'f'
    vtype2='float';
  case 'i'
    vtype2='int32';
  case 's'
    vtype2='short';
  case 'b'
    vtype2='uchar';
end;

fwrite(fp,dat,vtype2);
fclose(fp);

