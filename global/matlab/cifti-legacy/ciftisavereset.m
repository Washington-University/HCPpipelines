function [ output_args ] = ciftisavereset(cifti,filename,wbcommand,verbose)

% CIFTISAVERESET(CIFTI,FILENAME,WBCOMMAND,VERBOSE)
%
% Save a CIFTI file as a GIFTI external binary and then convert it to CIFTI
% with appropriate "reset" option (determined from file extension)
% applied during the conversion.
%
% CIFTI is the cifti-formatted file in the Matlab workspace
% FILENAME is the string containing the file name to save as
% WBCOMMAND is string containing the Workbench command.  
%   (Necessary for the intermediate step of conversion to gifti.
%    Matlab must be able to find this when it executes a 'system' command).
% VERBOSE (optional; default is off): Set to 1 for more verbose output.

% Default is VERBOSE=0 (OFF)
if (nargin < 4) 
  verbose = 0;
end

tstart=tic;

% Do work
% Note that 'save' is an "overloaded" function for objects
% of class 'gifti', and as such its behavior is defined by the
% 'gifti' class implementation
save(cifti,[filename '.gii'],'ExternalFileBinary')

strlength=length(filename);
if strcmp('.dscalar.nii',filename(strlength-11:strlength))
  flag=' -reset-scalars';
elseif strcmp('.dtseries.nii',filename(strlength-12:strlength))
  flag=' -reset-timepoints 1 0';
elseif strcmp('.pscalar.nii',filename(strlength-11:strlength))
  flag=' -reset-scalars';
elseif strcmp('.ptseries.nii',filename(strlength-12:strlength))
  flag=' -reset-timepoints 1 0';
else
  flag='';
end

system([wbcommand ' -cifti-convert -from-gifti-ext ' filename '.gii ' filename ' ' flag]);

if (verbose)
  fprintf(1,'%s: Elapsed time is %.2f seconds\n',filename,toc(tstart));
end

% Cleanup
delete([filename '.gii'],[filename '.dat']);
