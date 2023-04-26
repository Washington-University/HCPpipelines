function cifti_write_sdseries(data, filename, varargin)
    %function cifti_write_sdseries(data, filename, ...)
    %   Write a new sdseries cifti file from a 2D data matrix.
    %
    %   The cifti extension on the filename should always be '.sdseries.nii'.
    %
    %   To control the contents of the scalar and series diminfo, use 'start',
    %   'step', 'unit', 'namelist', and 'metadatalist' options, like:
    %
    %   cifti_write_sdseries(mydata, 'stuff.sdseries.nii', 'step', 0.72);
    %
    %   You can also specify any option pairs that cifti_write accepts.
    [options, template_varargs] = myargparse(varargin, {'stacklevel', 'disableprovenance', 'keepmetadata'}, true); %stacklevel is an implementation detail, don't add to help
    if isempty(options.stacklevel)
        options.stacklevel = 2; %note the '+ 1' in the cifti_write call, so that this function can be switched with cifti_write even in advanced situations
    end
    cifti_write(cifti_struct_create_sdseries(data, template_varargs{:}), filename, 'stacklevel', options.stacklevel + 1, 'disableprovenance', options.disableprovenance, 'keepmetadata', options.keepmetadata);
end
