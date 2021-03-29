function outlength = cifti_diminfo_length(diminfo)
    %recompute length from diminfo contents, in case .length is wrong
    switch diminfo.type
        case 'dense'
            modelends = zeros(length(diminfo.models), 1);
            for i = 1:length(diminfo.models)
                modelends(i) = diminfo.models{i}.start + diminfo.models{i}.count - 1; %NOTE: 1-based cifti indices
            end
            outlength = max(modelends); %TODO: check for gaps and overlap?
        case 'parcels'
            outlength = length(diminfo.parcels);
        case 'series'
            outlength = diminfo.length;
        case {'scalars', 'labels'}
            outlength = length(diminfo.maps);
        otherwise
            error(['unknown diminfo type "' diminfo.type '"']);
    end
end
