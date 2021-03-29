function cifti = cifti_struct_create_sdseries(data, varargin)
    %function cifti = cifti_struct_create_sdseries(data, ...)
    %   Construct an sdseries cifti struct around the 2D data matrix.
    %
    %   To control the contents of the scalar and series diminfo, use 'start',
    %   'step', 'unit', 'namelist', and 'metadatalist' options, like:
    %
    %   newcifti = cifti_struct_create_sdseries(mydata, 'step', 0.72);
    options = myargparse(varargin, {'start', 'step', 'unit', 'namelist', 'metadatalist'});
    if length(size(data)) ~= 2
        error('input data must be a 2D matrix');
    end
    if isempty(options.start)
        options.start = 0;
    end
    if isempty(options.step)
        options.step = 1;
    end
    if isempty(options.unit)
        options.unit = 'SECOND'; %let make_series sanity check whatever the user gave
    end
    cifti = struct('cdata', data, 'metadata', {{}}, 'diminfo', {cell(1, 2)});
    cifti.diminfo{1} = cifti_diminfo_make_scalars(size(data, 1), options.namelist, options.metadatalist);
    cifti.diminfo{2} = cifti_diminfo_make_series(size(data, 2), options.start, options.step, options.unit);
end
