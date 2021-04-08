function cifti = cifti_struct_create_from_template(ciftitemplate, data, type, varargin)
    %function cifti = cifti_struct_create_from_template(ciftitemplate, newdata, type, ...)
    %   Create a new cifti struct using an existing cifti as a template for the dense or
    %   parcels dimension.
    %
    %   The 'type' argument must be one of 'dtseries', 'dscalar', 'dconn', 'ptseries',
    %   'pscalar', or 'pconn'.
    %
    %   If the template has more than one mapping of the necessary type (dconn or pconn),
    %   you must provide additional arguments of ", 'dimension', 2" or similar to select
    %   the dimension to copy the diminfo from.
    %
    %   If the 'type' argument is 'dscalar' or 'pscalar', there are additional options
    %   'namelist' and 'metadatalist' to set the contents of the scalar map.
    %
    %   If the 'type' argument is 'dtseries' or 'ptseries', there are additional options
    %   'start', 'step', and 'unit' to set the contents of the series map.
    if length(size(data)) ~= 2
        error('input data must be a 2D matrix');
    end
    %myargparse rejects unrecognized options, so first figure out what type we need for the other dimension
    switch type
        case 'dconn'
            needtype = 'dense';
            othertype = 'copy';
        case 'dtseries'
            needtype = 'dense';
            othertype = 'series';
        case 'dscalar'
            needtype = 'dense';
            othertype = 'scalars';
        case 'pconn'
            needtype = 'parcels';
            othertype = 'copy';
        case 'ptseries'
            needtype = 'parcels';
            othertype = 'series';
        case 'pscalar'
            needtype = 'parcels';
            othertype = 'scalars';
        otherwise
            error('cifti:extension', ['invalid cifti type requested: ' type]); %tell write_from_template the filename was the problem
    end
    switch othertype
        case 'copy'
            if size(data, 1) ~= size(data, 2)
                error('this function can only make a square dconn or pconn, an asymmetric dconn or pconn must be made manually by setting cifti.cdata and cifti.diminfo');
            end
            options = myargparse(varargin, {'dimension'});
        case 'series'
            options = myargparse(varargin, {'dimension', 'start', 'step', 'unit'});
        case 'scalars'
            options = myargparse(varargin, {'dimension', 'namelist', 'metadatalist'});
        otherwise
            error('internal error, tell the developers what you tried to do');
    end
    if isempty(options.dimension)
        options.dimension = [];
        for i = 1:length(ciftitemplate.diminfo)
            if strcmp(ciftitemplate.diminfo{i}.type, needtype)
                options.dimension = [options.dimension i];
            end
        end
        if isempty(options.dimension)
            if strcmp(needtype, 'dense')
                error('template cifti has no dense dimension');
            else
                error('template cifti has no parcels dimension');
            end
        end
        if ~isscalar(options.dimension)
            if strcmp(needtype, 'dense')
                error('template cifti has more than one dense dimension, you must specify the dimension to use');
            else
                error('template cifti has more than one parcels dimension, you must specify the dimension to use');
            end
        end
    end
    if ~strcmp(ciftitemplate.diminfo{options.dimension}.type, needtype)
        if strcmp(needtype, 'dense')
            error('selected dimension of template cifti file is not dense');
        else
            error('selected dimension of template cifti file is not parcels');
        end
    end
    templateinfo = ciftitemplate.diminfo{options.dimension};
    if size(data, 1) ~= templateinfo.length
        if size(data, 2) == templateinfo.length
            warning('input data is transposed, this could cause an undetected error when run on different data'); %accept transposed, but warn
            cifti.cdata = data';
        else
            error('input data does not have a dimension length matching the dense diminfo');
        end
    else
        cifti.cdata = data;
    end
    %diminfo_make accepts any isempty() value as "use default", myargparse sets things to '' if not specified
    switch othertype
        case 'copy'
            otherinfo = templateinfo;
        case 'series'
            otherinfo = cifti_diminfo_make_series(size(cifti.cdata, 2), options.start, options.step, options.unit);
        case 'scalars'
            otherinfo = cifti_diminfo_make_scalars(size(cifti.cdata, 2), options.namelist, options.metadatalist);
        otherwise
            error('internal error, tell the developers what you tried to do');
    end
    cifti.metadata = ciftitemplate.metadata;
    cifti.diminfo = {templateinfo otherinfo};
end
