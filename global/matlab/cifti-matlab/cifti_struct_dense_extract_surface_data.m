function [outdata, outroi] = cifti_struct_dense_extract_surface_data(cifti, structure, dimension)
    %function [outdata, outroi] = cifti_struct_dense_extract_surface_data(cifti, structure, dimension)
    %   Extract the data for one cifti surface structure, expanding it to the full number of vertices.
    %   Vertices without data are given a value of 0, and outroi is a logical that is only
    %   true for vertices that have data.
    %
    %   The dimension argument is optional except for dconn files (generally, use 2 for dconn).
    %   The cifti struct must have exactly 2 dimensions.
    if length(cifti.diminfo) < 2
        error('cifti struct must have 2 dimensions');
    end
    if length(cifti.diminfo) > 2
        error('this function only operates on 2D cifti, use cifti_diminfo_dense_get_surface_info instead');
    end
    sanity_check_cdata(cifti);
    if nargin < 3
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
    surfinfo = cifti_diminfo_dense_get_surface_info(cifti.diminfo{dimension}, structure);
    outroi = false(surfinfo.numverts, 1);
    outroi(surfinfo.vertlist1) = true;
    outdata = zeros(surfinfo.numverts, size(cifti.cdata, otherdim), 'single');
    if dimension == 1
        outdata(surfinfo.vertlist1, :) = cifti.cdata(surfinfo.ciftilist, :);
    else
        outdata(surfinfo.vertlist1, :) = cifti.cdata(:, surfinfo.ciftilist)';
    end
end
