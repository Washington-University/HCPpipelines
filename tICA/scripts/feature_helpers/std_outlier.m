function outlier_stat = std_outlier(data)
%UNTITLED3 Summary of this function goes here
%   Detailed explanation goes here

data_reshape=reshape(data,[],1);
[data_length,~]=size(data_reshape);
isoutlier_stat=find(isoutlier(data_reshape, 'percentiles', [5,95])==1);
if isempty(isoutlier_stat)
    %outlier_stat=1; %original
    outlier_stat=0;
else
    std_all=std(data_reshape);
    std_exclude_outlier=std(data_reshape(setdiff([1:data_length], isoutlier_stat),1));
    %outlier_stat=std_exclude_outlier/std_all; %original
    outlier_stat=1-std_exclude_outlier/std_all;
end
end

