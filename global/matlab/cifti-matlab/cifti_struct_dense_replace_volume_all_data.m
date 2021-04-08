function cifti = cifti_struct_dense_replace_volume_all_data(cifti, data, cropped, dimension)
    %function cifti = cifti_struct_dense_replace_volume_all_data(cifti, newdata, cropped, dimension)
    %   Replace the data in all cifti volume structures, taking a 4D array as input.
    %   For a single-map cifti, the input can be 3D instead.
    %
    %   The cropped argument is optional and defaults to false, expecting a volume with
    %   the full original dimensions.
    %   The dimension argument is optional except for dconn files (generally, use 2 for dconn).
    %   The cifti struct must have exactly 2 dimensions.
    if length(cifti.diminfo) < 2
        error('cifti struct must have 2 dimensions');
    end
    if length(cifti.diminfo) > 2
        error('this function only operates on 2D cifti, use cifti_diminfo_dense_get_volume_all_info instead');
    end
    sanity_check_cdata(cifti);
    if nargin < 3
        cropped = false;
    end
    if nargin < 4
        dimension = [];
        for i = 1:2
            if strcmp(cifti.diminfo{i}.type, 'dense')
                dimension = [dimension i]; %#ok<AGROW>
            end
        end
        if isempty(dimension)
            error('cifti struct has no dense dimension');
        end
        if ~isscalar(dimension)
            error('dense by dense cifti (aka dconn) requires specifying the dimension argument');
        end
    end
    otherdim = 3 - dimension;
    otherlength = size(cifti.cdata, otherdim);
    volinfo = cifti_diminfo_dense_get_volume_all_info(cifti.diminfo{dimension}, cropped);
    indlist = cifti_vox2ind(volinfo.voldims, volinfo.voxlist1);
    datadims = size(data);
    if length(datadims) < 4
        if otherlength ~= 1 || length(datadims) < 3
            error('data must have 4 dimensions (or 3 for a single-map cifti)');
        end
        datadims = [datadims 1];
    end
    if datadims(1:3) ~= volinfo.voldims
        error('input data has the wrong volume dimensions, check the "cropped" argument');
    end
    if datadims(4) ~= otherlength
        error('input data has the wrong number of frames');
    end
    if otherlength == 1 %don't loop if we don't need to
        cifti.cdata(volinfo.ciftilist) = data(indlist);
    else
        %have a dimension that goes after the ind2sub result, so loop
        for i = 1:otherlength
            tempframe = data(:, :, :, i);
            if dimension == 1
                cifti.cdata(volinfo.ciftilist, i) = tempframe(indlist);
            else
                cifti.cdata(i, volinfo.ciftilist) = tempframe(indlist);
            end
        end
    end
end
