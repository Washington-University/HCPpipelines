function prepareICAs(dtseriesName,ICAs,wbcommand,ICAdtseries,NoiseICAs,Noise,Signal,ComponentList,hp,TR)

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
dtseries = ciftiopen([dtseriesName '.dtseries.nii'],wbcommand);
ICAs = load(ICAs, '-ascii');

if hp==0
  dtseries.cdata=detrend(dtseries.cdata')';
  ciftisave(dtseries,[dtseriesName '_dt.dtseries.nii'],wbcommand);
end
if hp>0
  dts_dimX=size(dtseries.cdata,1); dts_dimZnew=ceil(dts_dimX/100); dts_dimT=size(dtseries.cdata,2);
  
  % compute mean of dtseries data
  dts_mean=mean(dtseries.cdata,2);
  
  % remove (subtract out) the mean from the dtseries data
  dtseries.cdata=dtseries.cdata-repmat(dts_mean,1,size(dtseries.cdata,2));
  
  % save the dtseries with mean subtracted, to a "_fakeNIFTI" file to use as input to an 'fslmaths -bptf' command
  save_avw(reshape([dtseries.cdata ; zeros(100*dts_dimZnew-dts_dimX,dts_dimT)],10,10,dts_dimZnew,dts_dimT),[dtseriesName '_fakeNIFTI'],'f',[1 1 1 TR]);
  
  % call fslmaths -bptf on the "_fakeNIFTI" file - output goes back into the "_fakeNIFTI" file
  call_fsl(sprintf(['fslmaths ' dtseriesName '_fakeNIFTI -bptf %f -1 ' dtseriesName '_fakeNIFTI'], 0.5*hp/TR));
  
  % get the filtered data out of the "_fakeNIFTI" file and into the dtseries 
  grot=reshape(read_avw([dtseriesName '_fakeNIFTI']),100*dts_dimZnew,dts_dimT);
  dtseries.cdata=grot(1:dts_dimX,:);
  clear grot;
  
  % add the mean of the dtseries back in to the data
  dtseries.cdata=dtseries.cdata+repmat(dts_mean,1,size(dtseries.cdata,2));
  
  % remove the "_fakeNIFTI" file
  unix(['rm ' dtseriesName '_fakeNIFTI.nii.gz']);
  
  % save the highpass filtered (with mean included) data
  ciftisave(dtseries,[dtseriesName '_hp' num2str(hp) '.dtseries.nii'],wbcommand); 
end

ICA_dtseries = dtseries;
ICA_dtseries.cdata = (pinv([ones(length(ICAs),1) ICAs])*dtseries.cdata')';
ICA_dtseries.cdata = ICA_dtseries.cdata(:,2:size(ICA_dtseries.cdata,2));
ciftisavereset(ICA_dtseries,ICAdtseries,wbcommand);

NoiseICAs=load(NoiseICAs, '-ascii');

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

fprintf('%s - complete\n', func_name);
end

