function outlier_stat = std_outlier(data)
    %UNTITLED3 Summary of this function goes here
    %   Detailed explanation goes here

    data_reshape=reshape(data,[],1);
    [data_length,~]=size(data_reshape);
    if any(isnan(data_reshape))
        error('found NaN in std_outlier');
    end
    isoutlier_stat = findOutliers(data_reshape); %TODO: test me
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
