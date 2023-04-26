function indices = cifti_vox2ind(dims, voxlist1)
    %function indices = cifti_vox2ind(dims, voxlist1)
    %   Convert a list of 1-based voxel indices to linear indices.
    %   This function exists because matlab's sub2ind requires the
    %   subscripts for each dimension to be separate arguments.
    %   This is inconvenient for an N x 3 array of voxel indices, so
    %   this function is equivalent to:
    %
    %   >> sub2ind(dims, voxlist1(:, 1), voxlist1(:, 2), voxlist1(:, 3));
    if size(voxlist1, 1) ~= 3
        error('voxlist is the wrong shape, it needs to be N x 3');
    end
    if length(dims) ~= 3
        error('dims must be a vector of length 3');
    end
    indices = sub2ind(dims, voxlist1(1, :), voxlist1(2, :), voxlist1(3, :));
end
