function outmap = cifti_diminfo_make_scalars(nummaps, namelist, metadatalist)
    %function outmap = cifti_diminfo_make_scalars(nummaps, namelist, metadatalist)
    %   Create a new scalars diminfo struct.
    %
    %   Only the nummaps argument is required.
    %   The namelist argument, if provided, may be a char vector if nummaps = 1,
    %   or a cell vector of char vectors.
    %   The metadatalist argument, if provided, must be a cell vector of
    %   struct vectors with the same structure as the metadata in a cifti struct.
    if ~isscalar(nummaps) || round(nummaps) ~= nummaps || ~isfinite(nummaps) || nummaps < 1
        error('number of maps must be a finite, positive integer')
    end
    outmap = struct('type', 'scalars', 'length', nummaps, 'maps', struct('name', cell(1, nummaps), 'metadata', cell(1, nummaps)));
    if nargin >= 2 && ~isempty(namelist)
        if ~iscell(namelist)
            if nummaps ~= 1
                error('namelist is not a cell array, and nummaps is not 1');
            end
        else
            if length(namelist) ~= nummaps
                error('namelist length and nummaps do not match');
            end
        end
    end
    if nargin >= 3 && ~isempty(metadatalist)
        if ~iscell(metadatalist)
            error('metadatalist must be a cell array');
        end
        if length(metadatalist) ~= nummaps
            error('metadatalist length and nummaps do not match');
        end
    end
    for i = 1:nummaps
        if nargin >= 2 && ~isempty(namelist)
            if ~iscell(namelist)
                outmap.maps(i).name = namelist;
            else
                outmap.maps(i).name = namelist{i};
            end
        else
            outmap.maps(i).name = '';
        end
        if nargin >= 3 && ~isempty(metadatalist)
            outmap.maps(i).metadata = metadatalist{i};
        end
    end
end
