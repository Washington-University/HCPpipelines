function MSMregression(inputspatialmaps,inputdtseries,inputweights,outputspatialmaps,outputweights,wbcommand,Method,Params,VN,nTPsForSpectra,BC)
%function [ output_args ] = MSMregression(inputspatialmaps,inputdtseries,inputweights,outputspatialmaps,outputweights,wbcommand,Method,Params,VN,nTPsForSpectra,BC)
%Perform MSM Regression
%functions on the path:
%ciftiopen.m
%ciftisave.m
%demean.m
%ss_svds.m

% edits by T.B. Brown to convert string parameters to numeric values
% as necessary and print debugging information. When used with compiled
  % Matlab, all parameters are passed in as strings

func_name='MSMregression';
fprintf('%s - start\n', func_name);
fprintf('%s - inputspatialmaps: %s\n', func_name, inputspatialmaps);


fprintf('%s - inputdtseries: %s\n', func_name, inputdtseries);
fprintf('%s - inputweights: %s\n', func_name, inputweights);
fprintf('%s - outputspatialmaps: %s\n', func_name, outputspatialmaps);
fprintf('%s - outputweights: %s\n', func_name, outputweights);
fprintf('%s - wbcommand: %s\n', func_name, wbcommand);
fprintf('%s - Method: %s\n', func_name, Method);
fprintf('%s - Params: %s\n', func_name, Params);
fprintf('%s - VN: %s\n', func_name, VN);

if isdeployed
    fprintf('%s - nTPsForSpectra: "%s"\n', func_name, nTPsForSpectra);
    nTPsForSpectra=str2double(nTPsForSpectra);
end
fprintf('%s - nTPsForSpectra: %d\n', func_name, nTPsForSpectra);

fprintf('%s - BC: %s\n', func_name, BC);

WRSmoothingSigma=14;

%Steve Smith Node Timeseries Code
% read group-ICA spatial maps
BO=ciftiopen(inputspatialmaps,wbcommand); OUTBO=BO; GM=BO.cdata; clear BO; GMorig=GM;
%GM=GM.*repmat(sign(mean(GM)),size(GM,1),1)./repmat(max(abs(GM)),size(GM,1),1);  % make all individual group maps have a positive peak, and of peak height=1
     % although Giles thinks we should use sign(prctile(GM,95)) instead of sign(mean(GM))

BO=ciftiopen(inputdtseries,wbcommand); %for all spatial regressions demean vertically (each spatial map) demean(BO.cdata)

if strcmp(VN,'YES')
    BO.cdata=normalise(BO.cdata,2);
end

if ~strcmp(BC,'NO')
    BC=ciftiopen(BC,wbcommand);
end


if strcmp(Method(1:2),'DR')
  NODEts=demean((pinv(demean(GM))*demean(BO.cdata))');
end

if strcmp(Method(1:2),'ER')
  NODEts=zeros(size(BO.cdata,2),size(GM,2));
  for jj=1:size(GM,2)
      jj
    GMi=demean(GM(:,setdiff(1:size(GM,2),jj)));     % extract all the group spatial maps except the one in question
    pGMi=pinv(GMi);
    GMj=GM(:,jj)-GMi*(pGMi*demean(GM(:,jj)));       % regress all N-1 maps out of the 1 map
    grotd=demean(demean(BO.cdata)-GMi*(pGMi*demean(BO.cdata)),2);           % regress all N-1 maps out of the timeseries data
    grotdSTD=max(std(grotd,[],2),eps);              % estimate temporal-STD for normalisation
    [uu,ss,vv]=ss_svds( double(repmat(GMj./grotdSTD,1,size(grotd,2)) .* grotd) ,1);
    %if jj==25
    %    break
    %end
    vv= sign(mean(uu(GMj>.5))) * prctile( abs(uu(GMj>.5)).*grotdSTD(GMj>.5) , 50) * ss * vv;
    NODEts(:,jj)=vv;
  end
  NODEts=demean(NODEts);
end
%End Steve Smith Node Timeseries Code

if strcmp(Method(1:2),'WR')
    fid = fopen(Params);
    txtfileArray = textscan(fid,'%s');
    txtfileArray = txtfileArray{1,1};
    Distortion=txtfileArray{1,1};
    DistWeights=ones(length(GM),1);
    Distortion=ciftiopen(Distortion,wbcommand); %These are vertex areas now, but they say how much of the surface area each vertex represents.  The vertex areas are normalized so that the average vertex area is one.  Voxels are treated as 1
    DistWeights(1:length(Distortion.cdata),1)=Distortion.cdata;
    
    if length(txtfileArray)>1
        Weights=DistWeights;
        OrigGM=GM; %High dimensional group spatial maps were loaded in earlier
        for i=4:length(txtfileArray)
            LowDim=txtfileArray{i,1};
            LowDim
            LowDim=ciftiopen(LowDim,wbcommand);
            GM=LowDim.cdata;
            DesignWeights=repmat(sqrt(Weights),1,size(GM,2));
            DenseWeights=repmat(sqrt(Weights),1,size(BO.cdata,2));
            NODEts=demean((pinv(demean(GM.*DesignWeights)) * (demean(BO.cdata).*DenseWeights))');
            betaICA = ((pinv(NODEts) * demean(BO.cdata')))';
            NODEts=demean((pinv(demean(betaICA.*DesignWeights)) * (demean(BO.cdata).*DenseWeights))');
            betaICA = ((pinv(NODEts) * demean(BO.cdata')))';        
            for j=1:length(betaICA)
                var(j)=atanh(corr(betaICA(j,:)',GM(j,:)'));
            end
            corrs(:,i)=var';
        end
        SpatialWeightscii=BO;
        SpatialWeightscii.cdata=mean(corrs,2);
        ciftisavereset(SpatialWeightscii,outputspatialmaps,wbcommand); 
        unix([wbcommand ' -cifti-smoothing ' outputspatialmaps ' ' num2str(WRSmoothingSigma) ' ' num2str(WRSmoothingSigma) ' COLUMN ' outputspatialmaps ' -left-surface ' txtfileArray{2,1} ' -right-surface ' txtfileArray{3,1}]);
        SpatialWeightsSmoothcii=ciftiopen(outputspatialmaps,wbcommand);
        MEAN=mean(SpatialWeightscii.cdata);
        SpatialWeights=repmat(MEAN,length(SpatialWeightscii.cdata),1)+SpatialWeightscii.cdata-SpatialWeightsSmoothcii.cdata;
        ScaledSpatialWeights=(SpatialWeights.*(SpatialWeights>0)).^3;
        Weights=DistWeights.*ScaledSpatialWeights;
        GM=OrigGM; %Run high dimensional weighted regression with both distortion and misalignments
    else
        Weights=DistWeights;
    end
    
    DesignWeights=repmat(sqrt(Weights),1,size(GM,2));
    DenseWeights=repmat(sqrt(Weights),1,size(BO.cdata,2));
    NODEts=demean((pinv(demean(GM.*DesignWeights)) * (demean(BO.cdata).*DenseWeights))');
    betaICA = ((pinv(NODEts) * demean(BO.cdata')))';
    
    if length(txtfileArray)>1
        GM=betaICA; %Use individual subject maps in weighted dual regression with only distortion as weighting
        Weights=DistWeights;
        DesignWeights=repmat(sqrt(Weights),1,size(GM,2));
        DenseWeights=repmat(sqrt(Weights),1,size(BO.cdata,2));
        NODEts=demean((pinv(demean(GM.*DesignWeights)) * (demean(BO.cdata).*DenseWeights))');
    end    
end

%Save Timeseries and Spectra if Desired
if nTPsForSpectra > 0
   ts.Nnodes=size(NODEts,2);
   ts.Nsubjects=size(NODEts,1)./nTPsForSpectra;
   ts.ts=NODEts;
   ts.NtimepointsPerSubject=nTPsForSpectra;
   [ts_spectra] = nets_spectra(ts);
   dlmwrite([outputspatialmaps '_ts.txt'],NODEts,'delimiter','\t');
   dlmwrite([outputspatialmaps '_spectra.txt'],ts_spectra,'delimiter','\t');
end

%Second Stage of Dual Regression

betaICA = ((pinv(NODEts) * demean(BO.cdata')))';
OUTBO.cdata = betaICA;

if (length(Method) > 2) && strcmp(Method(3),'Z')
    %Convert to Z stat image
    dof=size(NODEts,1)-size(NODEts,2)-1;
    residuals=demean(BO.cdata,2)-betaICA*NODEts';
    pN=pinv(NODEts); dpN=diag(pN*pN')';
    t = betaICA ./ sqrt(sum(residuals.^2,2)*dpN/dof);
    Z = zeros(size(t));
    Z(t>0) = -norminv(tcdf(-t(t>0),dof));
    Z(t<0) = norminv(tcdf(t(t<0),dof));
    OUTBO.cdata = Z;
end

if (length(Method) > 2) && strcmp(Method(3),'N')
    %Normalize to input maps
    GMmean=mean(GMorig(1:length(Distortion.cdata),:));
    GMstd=std(GMorig(1:length(Distortion.cdata),:));
    betaICAmean=mean(betaICA(1:length(Distortion.cdata),:));
    betaICAstd=std(betaICA(1:length(Distortion.cdata),:));
    OUTBO.cdata = ((((betaICA-repmat(betaICAmean,length(betaICA),1))./repmat(betaICAstd,length(betaICA),1)).*repmat(GMstd,length(betaICA),1))+repmat(GMmean,length(betaICA),1));
end

ciftisave(OUTBO,[outputspatialmaps '.dscalar.nii'],wbcommand); 

if ~strcmp(BC,'NO')
    OUTBO.cdata=(OUTBO.cdata./repmat(BC.cdata,1,size(OUTBO.cdata,2)))*100;
    ciftisave(OUTBO,[outputspatialmaps '_norm.dscalar.nii'],wbcommand); 
end

if ~strcmp(inputweights,'NONE')
  weights=load(inputweights);
  for i=1:size(OUTBO.cdata,2)
      if ismember(i,weights)
          binaryweights(i)=1;
      else
          binaryweights(i)=0;
      end
  end

  OUTBO.cdata=repmat(binaryweights,size(OUTBO.cdata,1),1);

  ciftisave(OUTBO,outputweights,wbcommand); 

end
end
