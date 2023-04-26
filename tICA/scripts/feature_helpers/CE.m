function ce = CE(T)
%This function calculator is an estimate for a time series complexity [1] (A more complex time series has more peaks, valleys etc.).
%   References [1] c, Gustavo EAPA, et al (2014). c. Data Mining and Knowledge Discovery 28.3 (2014): 634-669.
% original
ce = sqrt(sum(diff(T).^2));
% 
%ce = sqrt(sum(diff(T).^2))./max(T); %original
%ce = sqrt(sum(diff(T).^2))./max(T)./length(T);

end

