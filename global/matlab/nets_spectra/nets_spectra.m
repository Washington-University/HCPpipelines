%
% nets_spectra - calculate and display spectrum for each node, averaged across subjects
% Steve Smith and Ludo Griffanti, 2013-2014
%
% [ts_spectra] = nets_spectra(ts); 
% [ts_spectra] = nets_spectra(ts,node_list); 
% [ts_spectra] = nets_spectra(ts,node_list,tailnorm); 
%
% node_list is optional, and is a vector listing the nodes to include
%
% tailnorm changes spectrum estimation to pwelch and scales spectra according to size of right-hand tail
%   - if using tailnorm and not node_list, use nets_spectra(ts,[],tailnorm)
%

function [ts_spectra] = nets_spectra(ts,varargin);   % produce subject-averaged spectra

N=ts.Nnodes;
nodelist=1:N;
if nargin>1 && length(varargin{1})>0
  nodelist=varargin{1};
  N=length(nodelist);
end

tailnorm=0;
if nargin==3
  tailnorm=varargin{2};  
end

ts_spectra=[];

for s=1:ts.Nsubjects
  grot=ts.ts((s-1)*ts.NtimepointsPerSubject+1:s*ts.NtimepointsPerSubject,nodelist);
  for ii=1:N
    if tailnorm==0
      blah=abs(fft(nets_demean(grot(:,ii)))); ts_spectra(:,ii,s)=blah(1:round(size(blah,1)/2));
    else
      blah=pwelch(grot(:,ii)); ts_spectra(:,ii,s)=blah(1:end-1,:);
    end
    %ts_spectra(:,ii,s)=smooth( pwelch(grot(:,ii)) ,10,'lowess');
  end
end

ts_spectra=mean(ts_spectra,3);

if tailnorm==1
  for i=1:N
    F_end=mean(ts_spectra(end-9:end,i));
    ts_spectra(:,i)=ts_spectra(:,i)/F_end;
  end
end

figure('Position',[10 10 1600 900]);

if tailnorm==0
  grot=ts_spectra ./ repmat(max(ts_spectra),size(ts_spectra,1),1);
  grotm=median(grot,2);
else
  grot=ts_spectra / max(ts_spectra(:));
  grotm=median(grot,2); grotm=grotm/max(grotm);
end

II=3;  I=ceil(N/II);  gap=0.03;  xw=(1-gap*(II+2))/(II+2);  yh=1-(2*gap);  iii=1;
for i=1:II
  subplot('position', [ gap*i+xw*(i-1) gap xw yh*min( (N-iii+1)/I, 1) ]);
  splurghy=repmat(iii:min(iii+I-1,N),size(grot,1),1);
  plot(splurghy,'color',[0.8 0.8 0.8]); hold on;
  plot(splurghy+repmat(grotm,1,size(splurghy,2)),'color',[0.6 0.6 0.6]); hold on;
  clear grotx;
  for ii=1:I
    if iii<=N
      grotx(:,ii)=grot(:,iii)+iii;
    end
    iii=iii+1;
  end
  plot(grotx); % grid on;
end

subplot('position', [ gap*(II+1)+xw*II gap 2*xw yh ]);
plot(grot); hold on;
plot(grotm,'k','LineWidth',3);

