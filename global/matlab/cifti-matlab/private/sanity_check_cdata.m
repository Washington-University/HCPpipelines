function sanity_check_cdata(cifti)
    %
    
    %this calls cifti_diminfo_length, but that seems to work even without being on path
    if ~isfield(cifti, 'cdata')
        error('cifti structure is missing cdata field');
    end
    if ~isfield(cifti, 'diminfo')
        error('cifti structure is missing diminfo field');
    end
    if ~isvector(cifti.diminfo) || ~iscell(cifti.diminfo)
        error('cifti diminfo field is not a cell vector');
    end
    if length(cifti.diminfo) < 2 || length(cifti.diminfo) > 3
        error('cifti-2 only supports 2 or 3 dimensions'); %cifti_write currently relies on this being an error
    end
    dims_xml = zeros(1, length(cifti.diminfo));
    for i = 1:length(cifti.diminfo)
        dims_xml(i) = cifti_diminfo_length(cifti.diminfo{i});
    end
    matlab_dims_xml = ambiguate_dims(dims_xml); %drop trailing singular 3rd dimension, because matlab...
    if ndims(cifti.cdata) ~= length(matlab_dims_xml)
        error('number of cdata dimensions does not match diminfo field');
    end
    if any(matlab_dims_xml ~= size(cifti.cdata))
        error('dimension length mismatch between cifti cdata and diminfo fields');
    end
end

