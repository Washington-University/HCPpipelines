function ss_tcs_stat = single_subject_tcs_features(ss_tcs_data)
%UNTITLED5 Summary of this function goes here
%   Detailed explanation goes here

ss_tcs_stat=zeros(1, 12);
var_all=zeros(1,8);
for j_order=1:8
    mdl=arima(j_order,0,0);
    estmdl=estimate(mdl,double(ss_tcs_data)','Display','off');
    residuals=infer(estmdl,double(ss_tcs_data)');
    var_all(j_order)=var(residuals);
end
ss_tcs_stat(1,1:2)=polyfit(1:8,var_all,1);
tmp=aryule(ss_tcs_data,1);
ss_tcs_stat(1,3)=tmp(2);
tmp=aryule(ss_tcs_data,2);
ss_tcs_stat(1,4:5)=tmp(2:3);
ss_tcs_stat(1,6:7)=var_all(1:2); 
% original
ss_tcs_stat(1,8)=max(abs(ss_tcs_data));
ss_tcs_stat(1,9)=mean(ss_tcs_data);
ss_tcs_stat(1,10)=std(ss_tcs_data);
ss_tcs_stat(1,11)=std_outlier(ss_tcs_data);
ss_tcs_stat(1,12)=kurtosis(ss_tcs_data);

end

