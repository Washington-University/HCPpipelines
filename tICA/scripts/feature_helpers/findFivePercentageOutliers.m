function ret = findFivePercentageOutliers(flatdata)
    %isoutlier(..., 'percentiles', [5 95]) written to treat all values at once
    numelems = numel(flatdata);
    ret = false(size(flatdata));
    if numelems < 1
        return
    end
    numexclude = floor((numelems + 9) / 20); %in R2021a, isoutlier excludes 0 for 10, 2 for 11...
    [~, perm] = sort(flatdata(:));
    ret([1:numexclude (end - numexclude + 1):end]) = true;
    ret(perm) = ret; %un-sort the exclusion mask
end
