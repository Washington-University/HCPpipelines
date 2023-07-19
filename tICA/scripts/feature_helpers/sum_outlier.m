function output = sum_outlier(T)
%Afill = filloutliers(T,'spline');
%Afill = filloutliers(T,'next');
outliers=findOutliers(T);

Afill = filloutliers(T,'spline','OutlierLocations', outliers);
Afill(find(isnan(Afill)))=T(find(isnan(Afill)));
% original
output = sqrt(sum((T-Afill).^2));
% normalize version
%output = sqrt(sum((T-Afill).^2))./length(T);

end
