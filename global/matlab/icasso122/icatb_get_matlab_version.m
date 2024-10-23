function matlab_version = icatb_get_matlab_version
% Get matlab version

matlab_version = version('-release');

[startInd, endInd] = regexpi(matlab_version, '\d+');

if ~isempty(startInd)
    matlab_version = matlab_version(startInd:endInd);
end

matlab_version = str2num(matlab_version);