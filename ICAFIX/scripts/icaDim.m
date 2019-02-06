function [Out] = icaDim(Origdata,DEMDT,VN,Iterate,NDist)
% Matthew F. Glasser, Chad Donahue, Steve Smith, Christian Beckmann

%%%%%%%%%%%%%%%%%%%%
%Variables
Out.VNDIM=VN; %Variance Normalization Dimensionality initially set to 1
lnb = 0.5; %Lower noise bound for Golden Section Search
stabThresh = Iterate; %How many iterations meeting dimThresh criterion (1 for VNDIM=1 results, 2 for converged results)

%%%%%%%%%%%%%%%%%%%%

%Remove Constant Timeseries and Detrend Data
if DEMDT==1
    data = Origdata(std(Origdata,[],2)>0,:);
    data_detrend = detrend(data')';
    data_trend = data - data_detrend;
elseif DEMDT==0
    data = Origdata(std(Origdata,[],2)>0,:);
    data_detrend = demean(data')';
    data_trend = single(zeros(size(data,1),size(data,2)));
elseif DEMDT==-1
    data = Origdata(std(Origdata,[],2)>0,:);
    data_detrend = data;
    data_trend = single(zeros(size(data,1),size(data,2)));
end

%Precompute PCA reconstruction
%octave doesn't have "rng", but it does accept "rand('twister', 0);" for matlab compatibility
rand('twister', 0);
[u,EigS,v]=nets_svds(data_detrend',0); %Eigenvalues of detrended data
Out.DOF=sum(diag(EigS)>(std(diag(EigS))*0.1)); %Compute degrees of freedom

c=1;
stabCount = 0;
while stabCount < stabThresh %Loop until dim output is stable
        
    c
    rand('twister', 0);
    %Variance normalization via PCA reconstruction: Isolate unstructured noise
    if VN~=0
      noise_unst = (u(:,Out.VNDIM(c):Out.DOF)*EigS(Out.VNDIM(c):Out.DOF,Out.VNDIM(c):Out.DOF)*v(:,Out.VNDIM(c):Out.DOF)')';
      Out.noise_unst_std = max(std(noise_unst,[],2),0.001);
      data_detrend_vn = data_detrend ./ repmat(Out.noise_unst_std,1,size(data_detrend,2));
    elseif VN==0
      data_detrend_vn = data_detrend;
      Out.noise_unst_std = single(ones(size(data_detrend,1),1));
    end
    if size(data_detrend_vn,1)<size(data_detrend_vn,2)
        if DEMDT~=-1
            d_pcaNorm=eig(cov(data_detrend_vn'));
        else
            d_pcaNorm=eig(data_detrend_vn*data_detrend_vn');
        end
    else
        if DEMDT~=-1
            d_pcaNorm=eig(cov(data_detrend_vn));
        else
            d_pcaNorm=eig(data_detrend_vn'*data_detrend_vn);
        end
    end
    Out.lambda_pcaNorm=flipud(d_pcaNorm);

    %Enable fitting multiple noise distributions
    DOF=Out.DOF;
    %DOF=sum(Out.lambda_pcaNorm>std(Out.lambda_pcaNorm)*0.1); %Recompute DOF because of demeaning in cov
    MaxX=length(data_detrend_vn); 
    if DEMDT==-1
        MaxX=1000000;
    end
    lambda=Out.lambda_pcaNorm;
    S=0;
    clear EN
    for i=1:NDist
        [x(i),en] = FitWishart(lnb,S,DOF,MaxX,lambda(1:DOF));
        lambda=lambda(1:DOF)-en(1:DOF); 
        en=[en;single(zeros(Out.DOF-length(en)+1,1))];
        EN(:,i)=en(1:Out.DOF);
        MaxX=x(i);
        DOF=min(find(lambda <= 0)); 
        lambda=[lambda(1:DOF);single(zeros(Out.DOF-DOF+1,1))];
        lambda=lambda(1:Out.DOF);
    end
      
    Out.EN=sum(EN,2); 
    %Out.x(c)=x(1);
    Out.x(c)=round(x(end));
    %DOF=round(Out.DOF);
    
    %MaxS=5;
    %DOF=Out.DOF;
    %MaxX=round(Out.x(c));
    %MaxX=length(data_detrend_vn);
    %lambda=Out.lambda_pcaNorm;
    %[Out.x(c),Out.EN,Out.s(c)] = SmoothEst(lnb,MaxS,DOF,MaxX,lambda);

    %[Out.x(c),Out.EN] = FitWishart(lnb,Out.s(c),DOF,MaxX,lambda(1:DOF));
    
    %Divide eigenvalues by null for adjusted output values
    Out.lambdaAdj = abs(Out.lambda_pcaNorm(1:DOF)./(Out.EN(1:DOF)));
    %Out.lambdaAdj(DOF:end)=1;
    
    %Normalize adjusted eigenvalues to 1 for input to laplacian
    %Out.lambdaAdj_norm = Out.lambdaAdj ./ max(Out.lambdaAdj);
    Out.pcaDim_lambdaAdj = pca_dim(Out.lambdaAdj',Out.x(c));
    
    %Maximum of laplacian is estimate of optimal dimensionality
    [~, Out.calcDim]=max(Out.pcaDim_lambdaAdj.lap(1:DOF));
    
    if VN~=1
      stabCount = 2;
    end
    
    %Next loop will use calculated dimensionality
    c=c+1;

    Out.VNDIM(c) = Out.calcDim;
    %manual display of Out fields, to make octave less verbose
    disp('Out =');
    disp(['   VNDIM: ' mat2str(Out.VNDIM)]);
    disp(['   DOF: ' mat2str(Out.DOF)]);
    disp(['   noise_unst_std: array of size ' mat2str(size(Out.noise_unst_std))]);
    disp(['   lambda_pcaNorm: array of size ' mat2str(size(Out.lambda_pcaNorm))]);
    disp(['   EN: array of size ' mat2str(size(Out.EN))]);
    disp(['   x: ' mat2str(Out.x)]);
    disp(['   lambdaAdj: array of size ' mat2str(size(Out.lambdaAdj))]);
    disp(['   pcaDim_lambdaAdj: struct']);
    disp(['   calcDim: ' mat2str(Out.calcDim)]);

    %Store dims in array, check number of occurances to prevent dim loops
    stabCount = sum(Out.VNDIM==Out.calcDim);
    
end %End while loop for dim calcs
rand('twister', 0);
if DEMDT~=-1
    [u,EigS,v]=nets_svds(demean(data_detrend_vn)',0);
else
    [u,EigS,v]=nets_svds(data_detrend_vn',0);
end    
u(isnan(u))=0; v(isnan(v))=0;
Out.EigSAdj=single(zeros(length(EigS),1));
Out.grot_one=diag(EigS(1:length(Out.EN),1:length(Out.EN)));
Out.grot_two=Out.grot_one.^2;
Out.grot_three=(Out.grot_two./max(Out.grot_two)).*max(Out.lambda_pcaNorm);
Out.grot_four=Out.grot_three-(Out.EN/median((Out.lambda_pcaNorm(1:Out.DOF)./max(Out.lambda_pcaNorm(1:Out.DOF)))./(diag(EigS(1:Out.DOF,1:Out.DOF).^2)./max(diag(EigS(1:Out.DOF,1:Out.DOF).^2)))));
Out.grot_five=(Out.grot_four./max(Out.lambda_pcaNorm)).*max(diag(EigS.^2));
firstOne = min(find(Out.grot_five <= 0));
Out.grot_six=Out.grot_five;
if ~length(firstOne)==0
    Out.grot_six(firstOne:end) = 0;
    Out.NewDOF=firstOne-1;
else
    Out.NewDOF=length(Out.grot_six);
end
%manual display of Out fields, to make octave less verbose
disp('Out =');
disp(['   VNDIM: ' mat2str(Out.VNDIM)]);
disp(['   DOF: ' mat2str(Out.DOF)]);
disp(['   noise_unst_std: array of size ' mat2str(size(Out.noise_unst_std))]);
disp(['   lambda_pcaNorm: array of size ' mat2str(size(Out.lambda_pcaNorm))]);
disp(['   EN: array of size ' mat2str(size(Out.EN))]);
disp(['   x: ' mat2str(Out.x)]);
disp(['   lambdaAdj: array of size ' mat2str(size(Out.lambdaAdj))]);
disp(['   pcaDim_lambdaAdj: struct']);
disp(['   calcDim: ' mat2str(Out.calcDim)]);
disp(['   EigSAdj: array of size ' mat2str(size(Out.EigSAdj))]);
disp(['   grot_one: array of size ' mat2str(size(Out.grot_one))]);
disp(['   grot_two: array of size ' mat2str(size(Out.grot_two))]);
disp(['   grot_three: array of size ' mat2str(size(Out.grot_three))]);
disp(['   grot_four: array of size ' mat2str(size(Out.grot_four))]);
disp(['   grot_five: array of size ' mat2str(size(Out.grot_five))]);
disp(['   grot_six: array of size ' mat2str(size(Out.grot_six))]);
disp(['   NewDOF: ' mat2str(Out.NewDOF)]);

Out.EigSAdj(1:length(Out.EN))=sqrt(Out.grot_six);

Out.data=single(zeros(size(Origdata,1),size(Origdata,2)));
if DEMDT~=-1
    Out.data(std(Origdata,[],2)>0,:)=data_trend + (((u*diag(Out.EigSAdj)*v')'+repmat(mean(data_detrend_vn),size(data_detrend_vn,1),1)) .* repmat(Out.noise_unst_std,1,size(data_detrend_vn,2)));
else
    Out.data(std(Origdata,[],2)>0,:)=data_trend + (((u*diag(Out.EigSAdj)*v')') .* repmat(Out.noise_unst_std,1,size(data_detrend_vn,2)));
end
temp=single(zeros(size(Origdata,1),1)); temp(std(Origdata,[],2)>0,:)=Out.noise_unst_std; Out.noise_unst_std=max(temp,0.001); clear temp;

end %End function

function [out] = lpdist(in)
    out=pdist(log(in));
end

function [x,EN] = FitWishart(lnb,S,DOF,MaxX,lambda) %FitWishart(lnb,step,DOF,MaxX,lambda)
    rand('twister', 0);
    EigDn1=round(DOF*lnb); %Isolate search to noise
    EigDn2=round(DOF-1); %Reqd for post MR+FIX deconcatinated tcs
    %EigDn2=round(DOF*0.75); %Reqd for post MR+FIX deconcatinated tcs
    
    a = DOF; %Lower bound for search range
    b = MaxX; %Upper bound for search range
    epsilon = 1; %Accuracy/stopping criterion
    iter = 500; %# iterations/secondary stopping criterion
    tau = double((sqrt(5)-1)/2); %Golden ratio (constant), 0.618...
    k = 1; %Iteration count
    
    %Initial section ranges to instantiate optimization
    x1 = a+(1-tau)*(b-a);
    x2 = a+tau*(b-a);
    %x1=a;
    %x2=b;
    
    %Calculate initial null spectra
    EN_x1 = iFeta([0:0.001:5],DOF,x1)'; %Call feta to calc null spectrum
    %EN_x1=flipud(eig(cov(Smooth(randn(round(x1),DOF),S))));
    EN_x1=EN_x1*median(lambda(EigDn1:EigDn2)./EN_x1(EigDn1:EigDn2)); %Remove offset between null & data
    f_x1 = lpdist([EN_x1(EigDn1:EigDn2)'; lambda(EigDn1:EigDn2)']); %Compute pairwise distance b/w null & data
  
    EN_x2 = iFeta([0:0.001:5],DOF,x2)';
    %EN_x2=flipud(eig(cov(Smooth(randn(round(x2),DOF),S))));
    EN_x2=EN_x2*median(lambda(EigDn1:EigDn2)./EN_x2(EigDn1:EigDn2));
    f_x2 = lpdist([EN_x2(EigDn1:EigDn2)'; lambda(EigDn1:EigDn2)']);
    
    while (abs(b-a)>epsilon) && (k<iter) %Loop until low error OR max iter met
        %k=k+1;
        rand('twister', 0);
        disp([num2str(a) ' ' num2str(x1) ' ' num2str(x2) ' ' num2str(b)]);
        %Check both terms for minimal pairwise distance and continue toward minimum
        if (f_x1<f_x2)
            b=x2;
            x2=x1;
            f_x2=f_x1;%don't recompute, this is the entire point of golden search
            EN_x2=EN_x1;
            x1=a+(1-tau)*(b-a);
            
            EN_x1 = iFeta([0:0.001:5],DOF,x1)';
            %EN_x1=flipud(eig(cov(Smooth(randn(round(x1),DOF),S))));
            EN_x1=EN_x1*median(lambda(EigDn1:EigDn2)./EN_x1(EigDn1:EigDn2));
            f_x1 = lpdist([EN_x1(EigDn1:EigDn2)'; lambda(EigDn1:EigDn2)']);
            
        else
            a=x1;
            x1=x2;
            f_x1=f_x2;
            EN_x1=EN_x2;
            x2=a+tau*(b-a);
            
            
            EN_x2 = iFeta([0:0.001:5],DOF,x2)';
            %EN_x2=flipud(eig(cov(Smooth(randn(round(x2),DOF),S))));
            EN_x2=EN_x2*median(lambda(EigDn1:EigDn2)./EN_x2(EigDn1:EigDn2));
            f_x2 = lpdist([EN_x2(EigDn1:EigDn2)'; lambda(EigDn1:EigDn2)']);
        end
        k = k+1;
    end
    
    %Compute null spectrum w/ optimal pairwise distance for output
    if (f_x1<f_x2)
        x = x1;
    else
        x = x2;
    end
    rand('twister', 0);
    %disp(randn(1,1));
    EN=flipud(eig(cov(Smooth(randn(round(x),DOF),S))));
    
    x=x/1+S;
    
    %Remove offset from null spectrum
    EN = EN*median(lambda(EigDn1:EigDn2) ./ EN(EigDn1:EigDn2));
end
  
function [x,EN,s] = SmoothEst(lnb,MaxS,DOF,MaxX,lambda)
    
    EigDn1=round(DOF*lnb); %Isolate search to noise
    EigDn2=round(DOF-1);
    
    M=randn(MaxX,DOF);
    
    a = 0; %Lower bound for search range
    b = MaxS; %Upper bound for search range
    epsilon = 0.01; %Accuracy/stopping criterion
    iter = 500; %# iterations/secondary stopping criterion
    tau = double((sqrt(5)-1)/2); %Golden ratio (constant), 0.618...
    k = 1; %Iteration count
    
    %Initial section ranges to instantiate optimization
    s1 = a+(1-tau)*(b-a);
    s2 = a+tau*(b-a);
    %x1=a;
    %x2=b;
    
    %Calculate initial null spectra
    %EN_x1 = iFeta([0:step:5],DOF,x1)'; %Call feta to calc null spectrum
    EN_s1=flipud(eig(cov(Smooth(M,s1/(2*sqrt(2*log(2))))))); 
    EN_s1=EN_s1*median(lambda(EigDn1:EigDn2)./EN_s1(EigDn1:EigDn2)); %Remove offset between null & data
    f_s1 = lpdist([EN_s1(EigDn1:EigDn2)'; lambda(EigDn1:EigDn2)']); %Compute pairwise distance b/w null & data
  
    %EN_x2 = iFeta([0:step:5],DOF,x2)';
    EN_s2=flipud(eig(cov(Smooth(M,s2/(2*sqrt(2*log(2)))))));
    EN_s2=EN_s2*median(lambda(EigDn1:EigDn2)./EN_s2(EigDn1:EigDn2));
    f_s2 = lpdist([EN_s2(EigDn1:EigDn2)'; lambda(EigDn1:EigDn2)']);
    
    while (abs(b-a)>epsilon) && (k<iter) %Loop until low error OR max iter met
        %k=k+1;
        disp([num2str(a) ' ' num2str(s1) ' ' num2str(s2) ' ' num2str(b)]);
        %Check both terms for minimal pairwise distance and continue toward minimum
        if (f_s1<f_s2)
            b=s2;
            s2=s1;
            f_s2=f_s1;%don't recompute, this is the entire point of golden search
            EN_s2=EN_s1;
            s1=a+(1-tau)*(b-a);
            
            %EN_x1 = iFeta([0:step:5],DOF,x1)';
            EN_s1=flipud(eig(cov(Smooth(M,s1/(2*sqrt(2*log(2))))))); 
            EN_s1=EN_s1*median(lambda(EigDn1:EigDn2)./EN_s1(EigDn1:EigDn2));
            f_s1 = lpdist([EN_s1(EigDn1:EigDn2)'; lambda(EigDn1:EigDn2)']);
            
        else
            a=s1;
            s1=s2;
            f_s1=f_s2;
            EN_s1=EN_s2;
            s2=a+tau*(b-a);
            
            
            %EN_x2 = iFeta([0:step:5],DOF,x2)';
            EN_s2=flipud(eig(cov(Smooth(M,s2))));
            EN_s2=EN_s2*median(lambda(EigDn1:EigDn2)./EN_s2(EigDn1:EigDn2));
            f_s2 = lpdist([EN_s2(EigDn1:EigDn2)'; lambda(EigDn1:EigDn2)']);
        end
        k = k+1;
    end
    
    %Compute null spectrum w/ optimal pairwise distance for output
    if (f_s1<f_s2)
        s = s1;
    else
        s = s2;
    end
    
    %EN = iFeta([0:step:5],DOF,x)';
    %EN=flipud(eig(cov(randn(round(x),DOF))));
    EN=flipud(eig(cov(Smooth(M,s/(2*sqrt(2*log(2)))))));
    x=MaxX/(1+s); %Number of resels
    %Remove offset from null spectrum
    EN = EN*median(lambda(EigDn1:EigDn2) ./ EN(EigDn1:EigDn2));
end

function [O] = Smooth(M,S)
if S==0
    O=M;
else
sigma = S/(2*sqrt(2*log(2)));
%sz = S*6;    % length of gaussFilter vector
%x = linspace(-sz / 2, sz / 2, sz);
%gaussFilter = exp(-x .^ 2 / (2 * sigma ^ 2));
%gaussFilter = gaussFilter / sum (gaussFilter); % normalize


width = round((6*sigma - 1)/2);
support = (-width:width);
gaussFilter = exp( -(support).^2 ./ (2*sigma^2) );
gaussFilter = gaussFilter/ sum(gaussFilter);

O=single(zeros(size(M,1),size(M,2)));

for i=1:size(M,2)
    op
    O(:,i) = conv (M(:,i), gaussFilter, 'same');
    %O(:,i) = filter (gaussFilter,1,M(:,i));
end
end
end
