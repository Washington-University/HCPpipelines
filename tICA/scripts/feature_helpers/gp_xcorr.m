function [stat,xcorr_m]  = gp_xcorr(AllData,tICAData, lagdices)
%UNTITLED6 Summary of this function goes here
%   Detailed explanation goes here
xcorr_m=zeros(lagdices*2+1,size(AllData,1));
for j_parcels=1:size(AllData,1)
    [xcorr_m(:,j_parcels), ~] = xcorr(normalise(AllData(j_parcels,:)'),normalise(tICAData(j_parcels,:)'),'coeff',lagdices);
end
stat=abs(2*eta_calc_pair(reshape(xcorr_m,[],1), reshape(flip(xcorr_m,1),[],1))-1);
%tmp_corrcoef=corrcoef(tmp_acor, flip(tmp_acor,1));
%output=tmp_corrcoef(1,2);
end

