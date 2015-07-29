function prepareICAs(dtseriesName,ICAs,wbcommand,ICAdtseries,NoiseICAs,Noise,Signal,ComponentList,hp,TR)

%UNTITLED2 Summary of this function goes here
%   Detailed explanation goes here
dtseries = ciftiopen([dtseriesName '.dtseries.nii'],wbcommand);
ICAs = load(ICAs);

% Convert input paramter strings to numerics as necessary and show input parameters
func_name='prepareICAs';
fprintf('%s - start\n', func_name);
fprintf('%s - dtseriesName: %s\n', func_name, dtseriesName);
fprintf('%s - ICAs: %s\n', func_name, ICAs);
fprintf('%s - wbcommand: %s\n', func_name, wbcommand);
fprintf('%s - ICAdtseries: %s\n', func_name, ICAdtseries);
fprintf('%s - NoiseICAs: %s\n', func_name, NoiseICAs);
fprintf('%s - Noise: %s\n', func_name, Noise);
fprintf('%s - Signal: %s\n', func_name, Signal);
fprintf('%s - ComponentList: %s\n', func_name, ComponentList);

if isdeployed
  fprintf('%s - hp: "%s"\n', func_name, hp);
  hp=str2double(hp);
end
fprintf('%s - hp: %d\n', func_name, hp);

if isdeployed
  fprintf('%s - TR: "%s"\n', func_name, TR);
  TR=str2double(TR);
end
fprintf('%s - TR: %d\n', func_name, TR);

%%%%  read and highpass CIFTI version of the data if it exists
if hp==0
  dtseries.cdata=detrend(dtseries.cdata')';
  ciftisave(dtseries,[dtseriesName '_dt.dtseries.nii'],wbcommand);
end
if hp>0
  BOdimX=size(dtseries.cdata,1);  BOdimZnew=ceil(BOdimX/100);  BOdimT=size(dtseries.cdata,2);
  save_avw(reshape([dtseries.cdata ; zeros(100*BOdimZnew-BOdimX,BOdimT)],10,10,BOdimZnew,BOdimT),[dtseriesName '_fakeNIFTI'],'f',[1 1 1 TR]);
  system(sprintf(['fslmaths ' dtseriesName '_fakeNIFTI -bptf %f -1 ' dtseriesName '_fakeNIFTI'],0.5*hp/TR));
  grot=reshape(read_avw([dtseriesName '_fakeNIFTI']),100*BOdimZnew,BOdimT);  dtseries.cdata=grot(1:BOdimX,:);  clear grot; unix(['rm ' dtseriesName '_fakeNIFTI.nii.gz']);
  ciftisave(dtseries,[dtseriesName '_hp' num2str(hp) '.dtseries.nii'],wbcommand); 
end



ICA_dtseries = dtseries;
ICA_dtseries.cdata = (pinv([ones(length(ICAs),1) ICAs])*dtseries.cdata')';
ICA_dtseries.cdata = ICA_dtseries.cdata(:,2:size(ICA_dtseries.cdata,2));
ciftisave(ICA_dtseries,ICAdtseries,wbcommand);

NoiseICAs=load(NoiseICAs);

Signalmat = [];
Noisemat = [];

for i = 1:size(ICA_dtseries.cdata,2)
    if [ ~ismember(i,NoiseICAs) ]
        Signalmat = [Signalmat i];
        unix(['echo ' num2str(i) ': Signal >> ' ComponentList]);
    elseif [ ismember(i,NoiseICAs) ]
        Noisemat = [Noisemat i];
        unix(['echo ' num2str(i) ': Noise >> ' ComponentList]);
    end
end

dlmwrite(Noise,Noisemat, 'delimiter', ' '); 
dlmwrite(Signal,Signalmat, 'delimiter', ' '); 


end

