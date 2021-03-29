function [outdata, outsform1, outroi] = cifti_struct_dense_extract_volume_structure_data(cifti, structure, cropped, dimension)
    %function [outdata, outsform1, outroi] = cifti_struct_dense_extract_volume_structure_data(cifti, structure, cropped, dimension)
    %   Extract the data for one cifti volume structure, expanding it to volume frames.
    %   Voxels without data are given a value of zero, and outroi is a logical that is only
    %   true for voxels that have data.
    %
    %   The cropped argument is optional and defaults to false, returning a volume with
    %   the full original dimensions.
    %
    %   The dimension argument is optional except for dconn files (generally, use 2 for dconn).
    %   The cifti struct must have exactly 2 dimensions.
    if length(cifti.diminfo) < 2
        error('cifti struct must have 2 dimensions');
    end
    if length(cifti.diminfo) > 2
        error('this function only operates on 2D cifti, use cifti_diminfo_dense_get_volume_structure_info instead');
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
    volinfo = cifti_diminfo_dense_get_volume_structure_info(cifti.diminfo{dimension}, structure, cropped);
    outsform1 = volinfo.volsform1;
    assert(length(volinfo.voldims) == 3);
    indlist = cifti_vox2ind(volinfo.voldims, volinfo.voxlist1);
    outroi = false(volinfo.voldims);
    outroi(indlist) = true;
    outdata = zeros([volinfo.voldims otherlength], 'single');
    if otherlength == 1 %don't loop if we don't need to
        outdata(indlist) = cifti.cdata(volinfo.ciftilist);
    else
        tempframe = zeros(voldims, 'single');
        %need a dimension after the ind2sub result, so loop
        for i = 1:otherlength
            if dimension == 1
                tempframe(indlist) = cifti.cdata(volinfo.ciftilist, i);
            else
                tempframe(indlist) = cifti.cdata(i, volinfo.ciftilist);
            end
            outdata(:, :, :, i) = tempframe;
        end
    end
end
