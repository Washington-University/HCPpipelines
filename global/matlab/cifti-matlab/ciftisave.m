function ciftisave(cifti, filename, varargin)
    %function ciftisave(cifti, filename, ...)
    %   Compatibility wrapper for cifti_write.
    if ~isfield(cifti, 'diminfo')
        error('cifti structure has no diminfo field, maybe use the old ciftisave code instead?');
    end
    tic;
    try
        cifti_write(cifti, filename, 'stacklevel', 3);
    catch e
        if length(size(cifti.cdata)) ~= length(cifti.diminfo)
            rethrow(e); %ciftisavereset can't handle that
        end
        for i = 1:length(cifti.diminfo)
            if size(cifti.cdata, i) ~= cifti.diminfo{i}.length
                error('data size disagrees with diminfo lengths, did you mean to use ciftisavereset?');
            end
        end
        rethrow(e);
    end
    toc; %for familiarity, have them output a timing?  the original ciftisave printed 2 timings...
end
