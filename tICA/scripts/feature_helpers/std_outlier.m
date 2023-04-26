function outlier_stat = std_outlier(data)
    %UNTITLED3 Summary of this function goes here
    %   Detailed explanation goes here

    data_reshape=reshape(data,[],1);
    [data_length,~]=size(data_reshape);
    if any(isnan(data_reshape))
        error('found NaN in std_outlier');
    end
    isoutlier_stat = myoutliers(data_reshape); %TODO: test me
    if isempty(isoutlier_stat)
        %outlier_stat=1; %original
        outlier_stat=0;
    else
        std_all=std(data_reshape);
        std_exclude_outlier=std(data_reshape(~isoutlier_stat));
        %outlier_stat=std_exclude_outlier/std_all; %original
        outlier_stat=1-std_exclude_outlier/std_all;
    end
end

%isoutlier(..., 'percentiles', [5 95]) written to treat all values at once
function ret = myoutliers(flatdata)
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

