function output = brain_region_features(data, original_data, mask)
%generate cifti based spatial features according to different masks
%   Detailed explanation goes here

mean_data=mean(data);
std_data=std(data);
std_outlier_data=std_outlier(data);

if sum(original_data)==0
    region_data_1=0;
else
    region_data_1=sum(data)/sum(original_data);
end
%region_data_2=sum(data)/sum(mask.cdata);

output=[mean_data, std_data, std_outlier_data, region_data_1];
end

