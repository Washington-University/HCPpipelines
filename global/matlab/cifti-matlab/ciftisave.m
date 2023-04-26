function ciftisave(cifti, filename, varargin)
    %function ciftisave(cifti, filename, ...)
    %   Compatibility wrapper for cifti_write.
    if ~isfield(cifti, 'diminfo')
        error('cifti structure has no diminfo field, maybe use the old ciftisave code instead?');
    end
    tic;
    if length(size(cifti.cdata)) ~= length(cifti.diminfo)
        error('number of cdata dimensions does not match diminfo field'); %to emulate cifti-legacy series behavior, we need to loop over the dimensions, so we need to check this first
    end
    serieswarn = false;
    for i = 1:length(cifti.diminfo)
        if strcmp(cifti.diminfo{i}.type, 'series') && size(cifti.cdata, i) ~= cifti.diminfo{i}.length
            serieswarn = true; %HACK: cifti-legacy silently reset the length for series mappings, emulate it but give a warning if it works
            cifti.diminfo{i}.length = size(cifti.cdata, i);
        end
    end
    try
        cifti_write(cifti, filename, 'stacklevel', 3);
    catch e
        %we checked for nonmatching number of dimensions earlier
        for i = 1:length(cifti.diminfo)
            if size(cifti.cdata, i) ~= cifti.diminfo{i}.length
                error('data size disagrees with diminfo lengths, did you mean to use ciftisavereset?');
            end
        end
        rethrow(e);
    end
    if serieswarn
        warning('fixed incorrect series length to emulate cifti-legacy behavior - to suppress this warning, set the .length of the series diminfo, or use ciftisavereset or cifti_write_from_template instead');
    end
    toc; %for familiarity, have them output a timing?  the original ciftisave printed 2 timings...
end
