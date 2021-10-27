function pks_all = gp_match(AllData, tICAData, factor)
%UNTITLED7 Summary of this function goes here
%   Detailed explanation goes here
pks_all=zeros(1,12);
[~,time_dim]=size(AllData);
% similarity=dot(tICAData,AllData)';
% for j=1:time_dim
%     similarity(j,1)=similarity(j,1)/norm(tICAData(:,j))/norm(AllData(:,j));
% end
similarity=zeros(time_dim,1);
for j=1:time_dim
   similarity(j,1)=abs(2*eta_calc_pair(tICAData(:,j),AllData(:,j))-1);
end

%black_stripe_index=(2./(1+exp(mean(tICAData,1)))-1).*(1./(1+exp(mean(AllData,1)))).*similarity';
%original
black_stripe_index=(2./(1+exp(mean(tICAData,1)))-1).*(2./(1+exp(mean(AllData,1)))-1).*similarity';

[pks0,~,w0]=findpeaks(double(black_stripe_index),'MinPeakHeight',0.05*factor,...
'MinPeakDistance',100);
[pks1,~,w1]=findpeaks(double(black_stripe_index),'MinPeakHeight',0.1*factor,...
                                    'MinPeakDistance',100);
[pks2,~,w2]=findpeaks(double(black_stripe_index),'MinPeakHeight',0.2*factor,...
    'MinPeakDistance',100);
[pks3,~,w3]=findpeaks(double(black_stripe_index),'MinPeakHeight',0.3*factor,...
'MinPeakDistance',100);
if isempty(pks0)
    pks_all(1,1)=0;
    pks_all(1,2)=0;
    pks_all(1,3)=0;
else
    pks_all(1,1)=mean(pks0);
    pks_all(1,2)=sum(pks0.*w0);
    pks_all(1,3)=mean(pks0.*w0);
end
if isempty(pks1)
    pks_all(1,4)=0;
    pks_all(1,5)=0;
    pks_all(1,6)=0;
else
    pks_all(1,4)=mean(pks1);
    pks_all(1,5)=sum(pks1.*w1);
    pks_all(1,6)=mean(pks1.*w1);
end
if isempty(pks2)
    pks_all(1,7)=0;
    pks_all(1,8)=0;
    pks_all(1,9)=0; 
else
    pks_all(1,7)=mean(pks2);
    pks_all(1,8)=sum(pks2.*w2);
    pks_all(1,9)=mean(pks2.*w2);
end
if isempty(pks3)
    pks_all(1,10)=0;
    pks_all(1,11)=0;
    pks_all(1,12)=0;
else
    pks_all(1,10)=mean(pks3);
    pks_all(1,11)=sum(pks3.*w3);
    pks_all(1,12)=mean(pks3.*w3);
end

end

