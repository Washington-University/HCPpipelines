function [surflist, vollist] = cifti_diminfo_dense_get_structures(diminfo)
    %function [surflist, vollist] = cifti_diminfo_dense_get_structures(diminfo)
    %   Get the names of all the structures used in the dense mapping.
    %
    %   The diminfo argument should usually be "cifti.diminfo{1}".
    if ~isstruct(diminfo) || ~strcmp(diminfo.type, 'dense')
        error('this function must be called on a diminfo element with type "dense"');
    end
    surflist = {};
    vollist = {};
    for i = 1:length(diminfo.models)
        switch diminfo.models{i}.type
            case 'surf'
                surflist = [surflist {diminfo.models{i}.struct}]; %#ok<AGROW>
            case 'vox'
                vollist = [vollist {diminfo.models{i}.struct}]; %#ok<AGROW>
            otherwise
                error(['model with unrecognized type "' diminfo.models{i}.type '"']);
        end
    end
end
