function cifti = ciftiopen(filename, varargin)
    %function cifti = ciftiopen(filename, ...)
    %   Compatibility wrapper for cifti_read.
    wbcmd = 'wb_command'; %don't require a second argument, default to whatever is on PATH
    if ~isempty(varargin)
        wbcmd = varargin{1}; %use the specified wb_command for conversion of cifti-1 to cifti-2 if needed
    end
    tic;
    cifti = cifti_read(filename, 'wbcmd', wbcmd);
    toc; %for familiarity, have them output a timing?  the original ciftiopen printed 2 timings...
end
