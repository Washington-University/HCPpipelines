function output = sum_outlier(T)
%Afill = filloutliers(T,'spline');
%Afill = filloutliers(T,'next');
Afill = filloutliers(T,'spline','percentiles', [5,95]);

Afill(find(isnan(Afill)))=T(find(isnan(Afill)));
% original
output = sqrt(sum((T-Afill).^2));
% normalize version
%output = sqrt(sum((T-Afill).^2))./length(T);

end
