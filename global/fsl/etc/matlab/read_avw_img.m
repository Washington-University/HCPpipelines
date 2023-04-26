function img = read_avw_img(filename);
%  [img] = READ_AVW_IMG(filename)
%
%  Read in an Analyze (or nifti .img) file into either a 3D or 4D
%   array (depending on the header information)
%  Ouput coordinates for all dimensions start at 1 rather than 0
%  Note: automatically detects char, short, long or double formats
%  
%  See also: READ_AVW, READ_AVW_HDR, SAVE_AVW, SAVE_AVW_HDR, SAVE_AVW_IMG

fnimg=strcat(filename,'.img');

[dims,scales,bpp,endian,datatype] = read_avw_hdr(filename);
fp=fopen(fnimg,'r',endian);
if (datatype==4),
  dat=fread(fp,'short');
elseif (datatype==2),
  dat=fread(fp,'uint8');
elseif (datatype==8),
  dat=fread(fp,'int');
elseif (datatype==64),
  dat=fread(fp,'double');
elseif (datatype==16),
   dat=fread(fp,'float32');
end
fclose(fp);

nvox = prod(dims);
if (length(dat)<nvox),
  error('Cannot open image as .img file does not contain as many voxels as the .hdr specifies');
elseif (length(dat)>nvox),
  disp('WARNING::truncating .img data as it contains more voxels than specified in the .hdr');
  dat = dat(1:nvox);
end


if (dims(4)>1),
  img = reshape(dat,dims(1),dims(2),dims(3),dims(4));
else
  img = reshape(dat,dims(1),dims(2),dims(3));
end

clear dat;

%% DEFUNCT FLIPPING
%% flip y dimension to be consistent with MEDx
%img=flipdim(img,2);
