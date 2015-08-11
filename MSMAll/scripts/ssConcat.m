function [ output_args ] = ssConcat(txtfile,wbcommand,outputConcat,VN)
%This code demeans and concatinates timeseries on a single subject and expects to find these
%functions on the path:
%ciftiopen.m
%ciftisave.m
%demean.m
fid = fopen(txtfile);
txtfileArray = textscan(fid,'%s');

txtfileArray = txtfileArray{1,1};

for i=1:length(txtfileArray)
    dtseriesName = txtfileArray{i,1};
    dtseries = ciftiopen([dtseriesName '.dtseries.nii'],wbcommand);
    if strcmp(VN,'YES')
        vn = ciftiopen([dtseriesName '_vn.dscalar.nii'],wbcommand);
        bias = ciftiopen([dtseriesName '_bias.dscalar.nii'],wbcommand);
    end    
    grot=demean(double(dtseries.cdata)')'; 
    if i == 1
        if strcmp(VN,'YES')
            grot=grot.*repmat(bias.cdata,1,size(grot,2));
            grot=grot./repmat(max(vn.cdata,0.001),1,size(grot,2));
        end
        TCS=single(demean(grot')); clear grot;
    elseif i > 1
        if strcmp(VN,'YES')        
            grot=grot.*repmat(bias.cdata,1,size(grot,2));
            grot=grot./repmat(max(vn.cdata,0.001),1,size(grot,2));
        end    
        TCS=[TCS; single(demean(grot'))]; clear grot;
    end    
    
end

BO = dtseries;
BO.cdata = TCS';
ciftisave(BO,outputConcat,wbcommand);

end

