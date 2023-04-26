function ciftisavereset(cifti, filename, varargin)
    %function ciftisavereset(cifti, filename, ...)
    %   Compatibility wrapper for cifti_write.
    periods = find(filename == '.', 2, 'last');
    if length(periods) < 2
        warning('ciftisavereset wrapper called with non-cifti file extension');
    else
        extension = filename(periods(1):end);
        %for familiarity, always overwrite the existing mapping even if the length is already right
        switch extension
            case {'.dscalar.nii', '.pscalar.nii'}
                cifti.diminfo{2} = cifti_diminfo_make_scalars(size(cifti.cdata, 2));
            case {'.dtseries.nii', '.ptseries.nii'}
                cifti.diminfo{2} = cifti_diminfo_make_series(size(cifti.cdata, 2));
            case '.sdseries.nii' %this case was not handled in the public version
                cifti.diminfo{1} = cifti_diminfo_make_scalars(size(cifti.cdata, 1));
                if size(cifti.cdata, 2) ~= cifti.diminfo{2}.length || ~strcmp(cifti.diminfo{2}.type, 'series')
                    warning(['resetting series dimension on sdseries file "' filename '"']); %this was not done in the original ciftisavereset
                    cifti.diminfo{2} = cifti_diminfo_make_series(size(cifti.cdata, 2)); %so don't do it except when needed, and give a warning
                end
            otherwise
                warning('ciftisavereset wrapper called with non-cifti file extension');
        end
    end
    tic;
    cifti_write(cifti, filename, 'stacklevel', 3);
    toc; %for familiarity, have them output a timing?  the original ciftisavereset printed 2 timings...
end
