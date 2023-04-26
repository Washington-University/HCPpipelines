function cifti_write_from_template(ciftitemplate, data, filename, varargin)
    %function cifti_write_from_template(ciftitemplate, newdata, filename, ...)
    %   Use a template cifti struct with a dense or parcels diminfo and a new data
    %   matrix to write a new cifti file.  The file extension is used to figure out
    %   what type of diminfo belongs on the other dimension.
    %
    %   The cifti extension on the filename must be one of '.dtseries.nii', '.dscalar.nii',
    %   '.dconn.nii', '.ptseries.nii', '.pscalar.nii', or '.pconn.nii'.
    %
    %   If the 'ciftitemplate' cifti struct has more than one mapping of the necessary type
    %   (dconn or pconn), you must provide additional arguments of ", 'dimension', 2" or
    %   similar to select the dimension to copy the diminfo from.
    %
    %   If the filename indicates a dscalar or pscalar, there are additional options
    %   'namelist' and 'metadatalist' to set the contents of the scalar map.
    %
    %   If the filename indicates a dtseries or ptseries, there are additional options
    %   'start', 'step', and 'unit' to set the contents of the series map.
    %
    %   You can also specify any option pairs that cifti_write accepts.
    [options, template_varargs] = myargparse(varargin, {'stacklevel', 'disableprovenance', 'keepmetadata'}, true); %stacklevel is an implementation detail, don't add to help
    if isempty(options.stacklevel)
        options.stacklevel = 2; %note the '+ 1' in the cifti_write call, so that this function can be switched with cifti_write even in advanced situations
    end
    periods = find(filename == '.', 2, 'last');
    if length(periods) < 2 || length(filename) < 6 || ~myendswith(filename, '.nii')
        error(['cifti file name "' filename '" does not end in a known cifti extension']);
    end
    filetype = filename((periods(1) + 1):(periods(2) - 1));
    try
        cifti_write(cifti_struct_create_from_template(ciftitemplate, data, filetype, template_varargs{:}), filename, 'stacklevel', options.stacklevel + 1, 'disableprovenance', options.disableprovenance, 'keepmetadata', options.keepmetadata);
    catch excinfo
        if strcmp(excinfo.identifier, 'cifti:extension')
            error(['cifti file name "' filename '" uses a cifti extension that is not supported by this function']);
        end
        rethrow(excinfo);
    end
end
