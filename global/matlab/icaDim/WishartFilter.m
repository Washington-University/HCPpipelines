function [filteredData, EN_all, noise_unst_std] = WishartFilter(data, vnDim, numWisharts)
% WISHARTFILTER  Apply Wishart filter to remove structured noise from data
%
%   [filteredData, EN_all, noise_unst_std] = WishartFilter(data, vnDim, numWisharts)
%
%   data:          voxels x timepoints matrix (masked, non-zero voxels only)
%   vnDim:         variance normalization cutoff (e.g. pfmDim or estimated dim)
%   numWisharts:   number of Wishart distributions to fit
%
%   filteredData:  filtered data, same size as input
%   EN_all:        estimated noise eigenspectrum
%   noise_unst_std: noise standard deviation per voxel
%
% Used by icaDim.m (for tICA dimensionality estimation)
% and ApplyWishartFilterProfumo.m (for PFM prefiltering)

    Ntp = size(data, 2);

    % SVD
    [u, EigS, v] = nets_svds(data', 0);
    DOF = sum(diag(EigS) > (std(diag(EigS)) * 0.1));
    u(isnan(u)) = 0;
    v(isnan(v)) = 0;

    % Variance normalization
    noise_unst = (u(:, vnDim:DOF) * EigS(vnDim:DOF, vnDim:DOF) * v(:, vnDim:DOF)')';
    noise_unst_std = max(std(noise_unst, [], 2), 0.001);
    clear noise_unst;
    data_vn = data ./ repmat(noise_unst_std, 1, Ntp);

    % Eigenvalues of VN data
    lambda = flipud(eig(cov(data_vn)));

    % Fit Wishart distributions
    lnb = 0.5;
    MaxX = size(data_vn, 1);
    origDOF = DOF;
    clear EN
    for i = 1:numWisharts
        [x, en] = FitWishart(lnb, 0, DOF, MaxX, lambda(1:DOF));
        lambda = lambda(1:DOF) - en(1:DOF);
        en_padded = zeros(origDOF, 1, 'single');
        en_padded(1:min(length(en), origDOF)) = en(1:min(length(en), origDOF));
        EN(:,i) = en_padded;
        MaxX = x;
        DOF = min(find(lambda <= 0));
        if isempty(DOF)
            break;
        end
        lambda = [lambda(1:DOF-1); zeros(origDOF - DOF + 1, 1, 'single')];
        lambda = lambda(1:origDOF);
    end
    EN_all = sum(EN, 2);

    % Adjust eigenvalues — subtract noise
    [u2, EigS2, v2] = nets_svds(data_vn', 0);
    clear data_vn;
    u2(isnan(u2)) = 0;
    v2(isnan(v2)) = 0;

    grot = diag(EigS2);
    grot_sq = grot.^2;
    grot_scaled = (grot_sq ./ max(grot_sq)) .* max(lambda);
    grot_adj = grot_scaled(1:length(EN_all)) - EN_all;
    firstZero = min(find(grot_adj <= 0));
    if ~isempty(firstZero)
        grot_adj(firstZero:end) = 0;
    end
    EigSAdj = zeros(length(grot), 1, 'single');
    EigSAdj(1:length(grot_adj)) = sqrt(max(grot_adj, 0));

    % Reconstruct filtered data
    filteredData = (u2 * diag(EigSAdj) * v2')';
    clear v2;
    filteredData = filteredData .* repmat(noise_unst_std, 1, Ntp);
end