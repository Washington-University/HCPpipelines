function [ output_args ] = TopographicRegression(inputdtseriestxt, inputvntxt, inputarea, inputareaIIName, inputaxisone, inputaxistwo, outputresultsName, outputregressorsName, wbcommand, outputaxisonecorrName, outputaxistwocorrName, numit, resultslocation, Distortion, BCname, NuisanceROIsName, DCONNFileName)

fid = fopen(inputdtseriestxt);
txtfileArray = textscan(fid,'%s');
txtfileArray = txtfileArray{1,1};
fclose(fid);

fid = fopen(inputvntxt);
vnfileArray = textscan(fid,'%s');
vnfileArray = vnfileArray{1,1};
fclose(fid);

if length(txtfileArray) ~= length(vnfileArray)
    error('dtseries and vn text files contain different numbers of files');
end

inputdtseries=[];
catvn=[];

for i=1:length(txtfileArray)
    dtseriesName = txtfileArray{i,1};
    vnName = vnfileArray{i,1};

    dtseries=ciftiopen(dtseriesName,wbcommand);
    vn=ciftiopen(vnName,wbcommand);
    %inputdtseries=[inputdtseries demean(dtseries.cdata')']; %Old code
    inputdtseries=[inputdtseries demean(dtseries.cdata,2)./(repmat(vn.cdata,1,size(dtseries.cdata,2)))]; %Variance Normalize
    catvn=[catvn vn.cdata]; %Concatinate VN files before averaging
                                        
end

%HACK section to work with bias corrected timeseries files that get variance normalized on loading before concatination
VN=vn;
VN.cdata=mean(catvn,2); %Mean VN file
BCname='NOTNONE'; %Always trigger the below BC clauses and make setting BCname do nothing
BC=vn;
BC.cdata=1./VN.cdata; %Create a BC file that will work with below code
%End HACK

STD=std(inputdtseries,[],2);

if ~strcmp(BCname,'NONE')
    %BC=ciftiopen(BCname,wbcommand);
    STDBC=STD./repmat(BC.cdata,1,size(STD,2));
end

if ~strcmp(NuisanceROIsName,'NONE')
    NuisanceROIs=ciftiopen(NuisanceROIsName,wbcommand);
    %NuisanceROIs=NuisanceROIs.cdata>0.05;
end



inputarea=ciftiopen(inputarea,wbcommand);

if ~strcmp(inputareaIIName,'NONE')
    inputareaII=ciftiopen(inputareaIIName,wbcommand);
end

if ~strcmp(DCONNFileName,'NONE')
    DCONNFile=ciftiopen(DCONNFileName,wbcommand);
end


inputaxisone=ciftiopen(inputaxisone,wbcommand);
inputaxistwo=ciftiopen(inputaxistwo,wbcommand);

DistWeights=ones(length(inputarea.cdata),1);
Distortion=ciftiopen(Distortion,wbcommand);
DistWeights(1:length(Distortion.cdata),1)=Distortion.cdata;
Weights=DistWeights;

outputresults=inputaxisone;
outputregressors=inputaxisone;
outmaxcorr=inputaxisone;

Area=inputarea;
All=Area;
All.cdata=single(ones(size(Area.cdata,1),1));
Left=All;
Right=All;
Left.cdata(29696+1:end)=0;
Right.cdata(1:29696)=0;
Right.cdata(29696+1+29716:end)=0;
LeftArea=Area;
RightArea=Area;
LeftArea.cdata=Area.cdata.*Left.cdata;
RightArea.cdata=Area.cdata.*Right.cdata;

if numit > 0
    runs=[0 numit];
else
    runs=0;
end

for i=runs

%Npolar=3;
%Npolar=4;
%Npolar=7;

Npolar=4;
Regressors(:,1)=cos((pi/2)*inputaxisone.cdata).*Area.cdata; %180
Regressors(:,2)=sin((pi/2)*inputaxisone.cdata).*Area.cdata; %180
Regressors(:,3)=cos((pi)*inputaxisone.cdata).*Area.cdata*-1; %90
Regressors(:,4)=sin((pi)*inputaxisone.cdata).*Area.cdata; %90
%use sine/cosine so that linear combinations can have a peak between the
%peaks of the regressors

%Regressors(:,1)=(((abs(inputaxisone.cdata./2)-1)*-1).*Area.cdata).*((RightArea.cdata*-1)+(LeftArea.cdata*1)); %360
%Regressors(:,1)=sin((pi/2).*(((((abs(inputaxisone.cdata)-1)*-1).*Area.cdata)).*Area.cdata)); %180
%Regressors(:,2)=sin((pi/2).*((abs((((abs(inputaxisone.cdata)-1)*-1).*Area.cdata))-1).*((RightArea.cdata*-1)+(LeftArea.cdata*1)).*Area.cdata)); %180
%Regressors(:,3)=sin((pi/2).*(((((abs((((abs(inputaxisone.cdata)-1)*-1).*Area.cdata))-1)*-1)*2)-1).*Area.cdata)); %90
%Regressors(:,5)=(((abs(sin((pi/2).*(((((abs((((abs(inputaxisone.cdata)-1)*-1).*Area.cdata))-1)*-1)*2)-1).*Area.cdata)))-1)*-1).*Area.cdata); %90 inv of above
%Regressors(:,4)=(cos((atan2(((((abs(inputaxisone.cdata)-1)*-1).*Area.cdata)),(abs((((abs(inputaxisone.cdata)-1)*-1).*Area.cdata))-1).*((RightArea.cdata*-1)+(LeftArea.cdata*1))))*4).*Area.cdata); %45
%Regressors(:,4)=abs(inputaxisone.cdata/2); %360
%Regressors(:,3)=(((abs(inputaxisone.cdata/2))-1)*-1).*Area.cdata; %360
%Regressors(:,6)=abs(sin((pi/2).*(((((abs(inputaxisone.cdata)-1)*-1).*Area.cdata)).*Area.cdata))); %180
%Regressors(:,4)=(((abs(sin((pi/2).*(((((abs(inputaxisone.cdata)-1)*-1).*Area.cdata)).*Area.cdata))))-1)*-1).*Area.cdata; %180

%Neccentricity=4;
%Neccentricity=3;
Neccentricity=1;
%Neccentricity=0;

%Regressors(:,Npolar+1)=sin((pi/2).*(((1-(inputaxistwo.cdata.*2)).*(inputaxistwo.cdata<(1/2))).*Area.cdata)); 
%Regressors(:,Npolar+2)=sin((pi/2).*(((1-((inputaxistwo.cdata-(1/2))*3)).*((inputaxistwo.cdata>(1/2)).*(inputaxistwo.cdata<(5/6))))+((inputaxistwo.cdata<(1/2)).*inputaxistwo.cdata.*2).*Area.cdata)); 
%Regressors(:,Npolar+3)=sin((pi/2).*(((((inputaxistwo.cdata-(1/2))*3).*(inputaxistwo.cdata>(1/2)).*(inputaxistwo.cdata<(5/6)))+((1-((inputaxistwo.cdata-(5/6))*6)).*(inputaxistwo.cdata>(5/6)))).*Area.cdata)); 
%Regressors(:,Npolar+4)=sin((pi/2).*((((inputaxistwo.cdata-(5/6))*6).*(inputaxistwo.cdata>(5/6))).*Area.cdata)); 
%Regressors(:,Npolar+1)=((sin((pi/2).*((((inputaxistwo.cdata-(5/6))*6).*(inputaxistwo.cdata>(5/6))).*Area.cdata)))<1).*Area.cdata; 
%Regressors(:,Npolar+2)=(sin((pi/2).*((((inputaxistwo.cdata-(5/6))*6).*(inputaxistwo.cdata>(5/6))).*Area.cdata)))==1; 
%Regressors(:,Npolar+1)=((((sin((pi/2).*((((inputaxistwo.cdata-(5/6))*6).*(inputaxistwo.cdata>(5/6))).*Area.cdata)))<1).*Area.cdata)*-1)+((sin((pi/2).*((((inputaxistwo.cdata-(5/6))*6).*(inputaxistwo.cdata>(5/6))).*Area.cdata)))==1); 

%Regressors(:,Npolar+1)=(((inputaxistwo.cdata)-(1/2)).*Area.cdata);
Regressors(:,Npolar+1)=((inputaxistwo.cdata*2)-1).*Area.cdata; 

NeccentricityNuisance=2;
Regressors(:,Npolar+Neccentricity+1)=(((inputaxistwo.cdata*2)-1).*Area.cdata).^2; 
Regressors(:,Npolar+Neccentricity+2)=(((inputaxistwo.cdata*2)-1).*Area.cdata).^3; 
%Regressors(:,Npolar+2)=((inputaxistwo.cdata-1)*-1).*Area.cdata; 


Narea=1;
%Narea=0;
%Narea=2;

Regressors(:,Npolar+Neccentricity+NeccentricityNuisance+1)=Area.cdata;
%Regressors(:,Npolar+Neccentricity+2)=NuisanceROIs;

NareaII=0;
Nnuisance=0;

if ~strcmp(NuisanceROIsName,'NONE')
    Regressors(:,Npolar+Neccentricity+NeccentricityNuisance+Narea+1:Npolar+Neccentricity+NeccentricityNuisance+Narea+Nnuisance+NareaII+size(NuisanceROIs.cdata,2))=NuisanceROIs.cdata;
    Nnuisance=Nnuisance+size(NuisanceROIs.cdata,2);
end

Nglobal=1;
Regressors(:,Npolar+Neccentricity+NeccentricityNuisance+Narea+Nnuisance+1)=single(ones(size(Area.cdata,1),size(Area.cdata,2)));

if ~strcmp(inputareaIIName,'NONE')
    Regressors(:,Npolar+Neccentricity+NeccentricityNuisance+Narea+Nnuisance+Nglobal+NareaII+1:Npolar+Neccentricity+NeccentricityNuisance+Narea+Nnuisance+Nglobal+NareaII+size(inputareaII.cdata,2))=inputareaII.cdata;
    NareaII=NareaII+size(inputareaII.cdata,2);
end


%if i>1
%    Regressors(:,Npolar+Neccentricity+Narea+Nnuisance+Nglobal+NareaII+1:Npolar+Neccentricity+Narea+Nnuisance+Nglobal+NareaII+size(ICAMaps,2))=ICAMaps(:,1:size(ICAMaps,2));
%end



range=[1:size(Regressors,2)];
size(Regressors(:,range),2)
rank(Regressors(:,range))
cond(Regressors(:,range))

%RegressorTCS=demean((pinv(demean(Regressors))*demean(inputdtseries))');
%OutMaps = ((pinv(RegressorTCS) * demean(inputdtseries')))';


DesignWeights=repmat(sqrt(Weights),1,size(Regressors,2));
DenseWeights=repmat(sqrt(Weights),1,size(inputdtseries,2));
%RegressorTCS=demean((pinv(demean(Regressors.*DesignWeights)) * (demean(inputdtseries).*DenseWeights))');
%RegressorTCS=demean((pinv(demean(Regressors.*DesignWeights)) * ((demean(inputdtseries)./repmat(STD,1,size(inputdtseries,2))).*DenseWeights))');
RegressorTCS=demean((pinv(Regressors.*DesignWeights) * ((demean(inputdtseries)./repmat(STD,1,size(inputdtseries,2))).*DenseWeights))');
OutMaps = ((pinv(RegressorTCS) * demean(inputdtseries')))';

if ~strcmp(BCname,'NONE')
    %OutMaps=((OutMaps.*repmat(STDBC,1,size(OutMaps,2)))./repmat(BC.cdata,1,size(OutMaps,2)))*100;
    OutMaps=(OutMaps./repmat(BC.cdata,1,size(OutMaps,2)))*100;
    OutMaps=(OutMaps./repmat(STDBC,1,size(OutMaps,2)))/100;
end

if i>0
%ReconTCS=(RegressorTCS(:,[1:Npolar+Neccentricity+Narea+Nnuisance+Nglobal+NareaII]) * (OutMaps(:,[1:Npolar+Neccentricity+Narea+Nnuisance+Nglobal+NareaII]))')';
%ReconTCS=(RegressorTCS(:,[1:Npolar+Neccentricity+Narea+Nnuisance+Nglobal+NareaII]) * (OutMaps(:,[1:Npolar+Neccentricity+Narea+Nnuisance+Nglobal+NareaII]).*repmat(STDBC,1,Npolar+Neccentricity+Narea+Nnuisance+Nglobal+NareaII).*repmat(BC.cdata,1,Npolar+Neccentricity+Narea+Nnuisance+Nglobal+NareaII))')';
%ReconTCS=(RegressorTCS(:,[1:Npolar+Neccentricity+Narea+Nnuisance+Nglobal]) * (OutMaps(:,[1:Npolar+Neccentricity+Narea+Nnuisance+Nglobal]).*repmat(STDBC,1,Npolar+Neccentricity+Narea+Nnuisance+Nglobal).*repmat(BC.cdata,1,Npolar+Neccentricity+Narea+Nnuisance+Nglobal))')';
ReconTCS=(RegressorTCS(:,[Npolar+Neccentricity+NeccentricityNuisance+Narea+Nnuisance+Nglobal+1:Npolar+Neccentricity+NeccentricityNuisance+Narea+Nnuisance+Nglobal+NareaII]) * (OutMaps(:,[Npolar+Neccentricity+NeccentricityNuisance+Narea+Nnuisance+Nglobal+1:Npolar+Neccentricity+NeccentricityNuisance+Narea+Nnuisance+Nglobal+NareaII]).*repmat(STDBC,1,NareaII).*repmat(BC.cdata,1,NareaII))')';
%RegTCS=inputdtseries-ReconTCS;
RegTCS=ReconTCS;

[icasig, A, W] = fastica(RegTCS','approach','symm','g','pow3','lastEig',i,'numOfIC',i,'displayMode','off');

icasigsigns=icasig'.*repmat(sign(mean(icasig')),size(icasig',1),1);

[SSTDs Is]=sort(std(icasigsigns,[],1));

for I=1:length(Is)
    ICAMaps(:,Is(I))=icasigsigns(:,I);
end

%ICAMaps=icasig';
    
%Regressors(:,Npolar+Neccentricity+Narea+Nnuisance+Nglobal+1:Npolar+Neccentricity+Narea+Nnuisance+Nglobal+size(ICAMaps,2))=ICAMaps(:,1:size(ICAMaps,2));
RegressorsTMP(:,1:Npolar+Neccentricity+NeccentricityNuisance+Narea+Nnuisance+Nglobal+size(ICAMaps,2))=[Regressors(:,1:Npolar+Neccentricity+NeccentricityNuisance+Narea+Nnuisance+Nglobal) ICAMaps(:,1:size(ICAMaps,2))];
Regressors=RegressorsTMP;
range=[1:size(Regressors,2)];
size(Regressors(:,range),2)
rank(Regressors(:,range))
cond(Regressors(:,range))

%RegressorTCS=demean((pinv(demean(Regressors))*demean(inputdtseries))');
%OutMaps = ((pinv(RegressorTCS) * inputdtseries'))';

DesignWeights=repmat(sqrt(Weights),1,size(Regressors,2));
DenseWeights=repmat(sqrt(Weights),1,size(inputdtseries,2));
%RegressorTCS=demean((pinv(demean(Regressors.*DesignWeights)) * (demean(inputdtseries).*DenseWeights))');
%RegressorTCS=demean((pinv(demean(Regressors.*DesignWeights)) * ((demean(inputdtseries)./repmat(STD,1,size(inputdtseries,2))).*DenseWeights))');
RegressorTCS=demean((pinv(Regressors.*DesignWeights) * ((demean(inputdtseries)./repmat(STD,1,size(inputdtseries,2))).*DenseWeights))');
OutMaps = ((pinv(RegressorTCS) * demean(inputdtseries')))';

if ~strcmp(BCname,'NONE')
     %OutMaps=((OutMaps.*repmat(STDBC,1,size(OutMaps,2)))./repmat(BC.cdata,1,size(OutMaps,2)))*100;
     OutMaps=(OutMaps./repmat(BC.cdata,1,size(OutMaps,2)))*100;
     OutMaps=(OutMaps./repmat(STDBC,1,size(OutMaps,2)))/100;
end

end

outputresults.cdata=OutMaps;
%outputregressors.cdata=demean(Regressors);
outputregressors.cdata=Regressors;

%ReconTCS=(RegressorTCS(:,[1:Npolar+Neccentricity+Narea+Nnuisance+Nglobal+NareaII]) * OutMaps(:,[1:Npolar+Neccentricity+Narea+Nnuisance+Nglobal+NareaII])')';
%ReconTCS=(RegressorTCS(:,[1:Npolar+Neccentricity]) * OutMaps(:,[1:Npolar+Neccentricity])')';
%ReconTCS=(RegressorTCS(:,[1:Npolar+Neccentricity]) * OutMaps(:,[1:Npolar+Neccentricity])')';
ReconTCS=(RegressorTCS(:,[1 2 3 4 5]) * OutMaps(:,[1 2 3 4 5])')';

outputaxisonecorr=inputaxisone;
outputaxistwocorr=inputaxistwo;
ind=find(inputarea.cdata>0);
[corr p]=paircorr_mod(ReconTCS',ReconTCS(inputarea.cdata>0,:)');
[outmaxr outmaxindcorr]=max(corr,[],2);
outputaxisonecorr.cdata=inputaxisone.cdata(ind(outmaxindcorr));
outputaxistwocorr.cdata=inputaxistwo.cdata(ind(outmaxindcorr));
outmaxcorr.cdata=outmaxr;

ciftisavereset(outputresults,[outputresultsName '_' num2str(i) '.dscalar.nii'],wbcommand);
ciftisavereset(outputregressors,[outputregressorsName '_' num2str(i) '.dscalar.nii'],wbcommand);
ciftisave(outputaxisonecorr,[outputaxisonecorrName '_' num2str(i) '.dscalar.nii'],wbcommand);
ciftisave(outputaxistwocorr,[outputaxistwocorrName '_' num2str(i) '.dscalar.nii'],wbcommand);
ciftisavereset(outmaxcorr,[outputresultsName 'maxcorr_' num2str(i) '.dscalar.nii'],wbcommand);

if ~strcmp(DCONNFileName,'NONE')
    DCONNFile.cdata=corr;
    ciftisave(DCONNFile,DCONNFileName,wbcommand);
end

unix([resultslocation '/' num2str(i) '.sh']);
end


end

