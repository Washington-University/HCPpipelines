function ret = findScaledMADOutliers(data)
% Determine if an array contains values that are outside of three scaled MAD
    numElems = numel(data);
    if numElems < 1
        return
    end
    deviations = data - median(data);
    absDeviations = abs(deviations);
    mad = median(absDeviations);
    % Scale the MAD by -1/(sqrt(2)*erfcinv(3/2))
    % from https://www.mathworks.com/help/matlab/ref/isoutlier.html#bvolffm
    scaledMAD = 1.4826 * mad;
    threshold = 3 * scaledMAD;
    ret = absDeviations > threshold;
end
