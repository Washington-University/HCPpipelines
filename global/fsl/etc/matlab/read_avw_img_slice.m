function img = read_avw_img_slice(filename,slice);
%  [img] = READ_AVW_IMG_SLICE(filename,slice)
%
%  Read in one slice of Analyze (or nifti .img) file into either a 2D or 3D
%  array (depending on the header information).
%  The purpose is to allow reading big 4D volumes on slice at a time,
%  thereby reducing the risk of out-of-memory error. It will then
%  return a 3D volume where the third dimension corresponds to the
%  fourth dimension in the file (typically time).
%  Ouput coordinates for all dimensions start at 1 rather than 0
%  Note: automatically detects char, short, long or double formats
%  
%  See also: READ_AVW, READ_AVW_HDR, SAVE_AVW, SAVE_AVW_HDR, SAVE_AVW_IMG

fnimg=strcat(filename,'.img');

[dims,scales,bipp,endian,datatype] = read_avw_hdr(filename);
if slice<1 || slice>dims(3),
   error('Slice indexes outside volume');
end

bypp = bipp/8;
fp=fopen(fnimg,'r',endian);
fseek(fp,dims(1)*dims(2)*(slice-1)*bypp,'bof');
if (datatype==4),
   prec = sprintf('%d*short',dims(1)*dims(2));
elseif (datatype==2),
   prec = sprintf('%d*uint8',dims(1)*dims(2));
elseif (datatype==8),
   prec = sprintf('%d*int',dims(1)*dims(2));
elseif (datatype==64),
   prec = sprintf('%d*double',dims(1)*dims(2));
elseif (datatype==16),
   prec = sprintf('%d*float32',dims(1)*dims(2));
end
dat=fread(fp,prod(dims([1 2 4])),prec,dims(1)*dims(2)*(dims(3)-1)*bypp);
fclose(fp);

nvox = prod(dims([1 2 4]));
if length(dat)<nvox,
  error('Cannot open image as .img file does not contain as many voxels as the .hdr specifies');
end


if (dims(4)>1),
  img = reshape(dat,dims(1),dims(2),dims(4));
else
  img = reshape(dat,dims(1),dims(2));
end

clear dat;

%% DEFUNCT FLIPPING
%% flip y dimension to be consistent with MEDx
%img=flipdim(img,2);
