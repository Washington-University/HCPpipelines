function write_pulse(fname,mat,flag)
% WRITE_PULSE(fname,mat,flag)
%
%  write a matrix (mat) to a file in the binary format written by
%  write_binary_matrix() in miscmaths (FSL library)
%  if flag=0 use the standard format; if flag=1 use the hybrid
%   PMatrix format (from POSSUM)
%
%  See also: read_pulse (for binary matrices), save (for ascii matrices)

if (nargin<2),
  disp('??? Error using ==> write_pulse');
  disp('Not enough input arguments.');
  disp(' ');
  return
end

if (nargin==2),
  flag=0;
end

if ((flag~=1) && (flag~=0)) 
  flag=0;
end


magicnumber=42;
dummy=0;
[nrows ncols]=size(mat);

% open file and write contents (with native endian-ness)
fp=fopen(fname,'w');
fwrite(fp,magicnumber+flag,'uint32');
fwrite(fp,dummy,'uint32');
fwrite(fp,nrows,'uint32');
fwrite(fp,ncols,'uint32');
if (flag==0),
  fwrite(fp,mat,'double');
else
  fwrite(fp,mat(:,1),'double');
  fwrite(fp,mat(:,2:end),'float');
end
fclose(fp);
