function [m] = read_pulse(fname)
% [m] = READ_PULSE(fname)
%
%  Reads a matrix from a file in the binary format written by
%  write_binary_matrix() in miscmaths (FSL library)
%
%  See also: write_pulse (for binary matrices), load (for ascii matrices)

if (nargin<1),
  disp('??? Error using ==> read_pulse');
  disp('Not enough input arguments.');
  disp(' ');
  return
end

magicnumber=42;

% open file in big-endian
endian='b';
fid=fopen(fname,'r','b');
testval = fread(fid,1,'uint32');
% check if this gives the correct magic number
if ((testval~=magicnumber) && (testval~=(magicnumber+1))),
  fclose(fid);
  % otherwise try little-endian
  fid=fopen(fname,'r','l');
  endian='l';
  testval = fread(fid,1,'uint32');
  if ((testval~=magicnumber) && (testval~=(magicnumber+1))),
    disp('Can not read this file format');
    return;
  end
end

	% ditch the padding
  dummy=fread(fid,1,'uint32');
	% read the number of rows and columns
  nrows=fread(fid,1,'uint32');
  ncols=fread(fid,1,'uint32');
  if (testval==magicnumber),
    m=fread(fid,nrows*ncols,'double');
    m=reshape(m,nrows,ncols);
  end
  if (testval==(magicnumber+1)),
    time=fread(fid,nrows,'double');
    mvals=fread(fid,nrows*(ncols-1),'float');
    mvals=reshape(mvals,nrows,ncols-1);
    m=zeros(nrows,ncols);
    m(:,1)=time;
    m(:,2:end)=mvals;
  end
  fclose(fid);
return;

