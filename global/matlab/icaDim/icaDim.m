function [Out] = icaDim(Origdata, DEMDT, VN, Iterate, NDist)
%
% ICADIM(Origdata, DEMDT, VN, Iterate, NDist)
%
% Estimates the number of ica components that are not due to random noise,
%   and makes a standard deviation map of the random noise estimate
%
% DEMDT: 1 to detrend, 0 to only demean, -1 to do nothing, >1 to do nothing and also set the DOF to the specified value
% VN: mode/initial guess of # of non-random-noise components for variance normalization
% Iterate: mode/count for iterating the estimation
% NDist: number of wisharts to fit
%
% Iterate=-1 means iterate until the average of the dimensionality history doesn't change much
%   1 means single iteration
%   2-3 means wait for that many repeats of a dimensionality (not required to be consecutive)
%   >3 means exactly that many iterations
%
% VN=0 means don't variance normalize
%	otherwise, normalize by random noise stdev, estimated by excluding the current estimate of non-random components from the PCA
%%%%%%%%%%%%%%%%%%%%
% Matthew F. Glasser, Chad Donahue, Steve Smith, Christian Beckmann

%Variables
Out.VNDIM=VN; %initial Variance Normalization Dimensionality
lnb = 0.5; %Lower noise bound for Golden Section Search
stabThresh = Iterate; %How many iterations meeting dimThresh criterion (1 for single iteration, 2 for 2 coincidences of legacy converged results, 3 for 3 coincidences of legacy converged results, -1 for new converged results, >3 for fixed iterations)

if Iterate < 0
     stabThresh=0.25; %Difference in running average
     priordimavg=0;
end

if Iterate > 3
     stabThresh=Iterate; %Difference in running average
     priordimavg=0;
end

%%%%%%%%%%%%%%%%%%%%

NvoxOrig = size(Origdata,1);
Ntp = size(Origdata,2);

% Derive mask of non-zero voxels
% Note: Use 'range' to identify non-zero voxels (which is very memory efficient)
% rather than 'std' (which requires additional memory equal to the size of the input)
mask = range(Origdata,2) > 0;
useMask = ~all(mask(:)); %if the mask doesn't exclude anything, we won't actually use it

% Apply mask, if it is helpful
if useMask
    fprintf('icaDim: Non-empty voxels: %d (= %.2f%% of %d). Masking for memory efficiency.\n', sum(mask), 100*sum(mask)/NvoxOrig, NvoxOrig);
    data = Origdata(mask,:);
else
    fprintf('icaDim: No empty voxels -- not masking\n');
    data = Origdata;  % "copying" the input as-is doesn't use any memory
    clear mask;
end
clear Origdata;

Nmask = size(data,1);

Out.DOF=0;

%Remove Constant Timeseries and Detrend Data
% Reuse 'data' variable for memory efficiency
if DEMDT==1
    % In this case, preserve the trend for adding back later
    data_detrend = detrend(data')';
    data_trend = data - data_detrend; 
	  data = data_detrend;
	  clear data_detrend;
elseif DEMDT==0
	% In this case, preserve the mean (over time) for adding back later
    data_mean = mean(data')';
    data = demean(data')';
elseif DEMDT==-1
    % No demeaning or detrending; no additional prep necessary
elseif DEMDT>1
    Out.DOF=DEMDT; %Set DOF for a partial concat of an MRI+FIX run by subtracting the near zero DOF for the full MR+FIX run
end

%Precompute PCA reconstruction
%octave doesn't have "rng", but it does accept "rand('twister', 0);" for matlab compatibility

% previous regressions will remove degrees of freedom (DOF), putting zeros on the end of our eigenvalues
% but, we use the end of the eigenvalues to estimate the wishart distribution, so we need to detect and exclude those zeroes
% due to rounding error, they won't be exactly zero, so exclude all "zeroish" components, thresholding at 10% of the stdev of all eigenvalues seems to work
[u,EigS,v]=nets_svds(data',0); %Eigenvalues of data
if Out.DOF==0
    Out.DOF=sum(diag(EigS)>(std(diag(EigS))*0.1)); %Compute degrees of freedom
end

u(isnan(u))=0; v(isnan(v))=0;

c=1;
stabCount = 0;
while stabCount < stabThresh 
% Loop until dim output is stable
% Note: within the while loop, 'data_vn' gets reused, but 'data' stays
% constant (albeit, possibly demeaned and/or detrended previously, per above)

    c
    clear data_vn;
    %Variance normalization via PCA reconstruction: Isolate unstructured noise
    if VN~=0
      noise_unst = (u(:,Out.VNDIM(c):Out.DOF)*EigS(Out.VNDIM(c):Out.DOF,Out.VNDIM(c):Out.DOF)*v(:,Out.VNDIM(c):Out.DOF)')';
      Out.noise_unst_std = max(std(noise_unst,[],2),0.001); clear noise_unst;
      data_vn = data ./ repmat(Out.noise_unst_std,1,Ntp);
    elseif VN==0
      data_vn = data;
      Out.noise_unst_std = ones(Nmask,1,'single');
    end
    if size(data_vn,1)<size(data_vn,2)
        if DEMDT~=-1
            d_pcaNorm=eig(cov(data_vn'));
        else
            d_pcaNorm=eig(data_vn*data_vn');
        end
    else
        if DEMDT~=-1
            d_pcaNorm=eig(cov(data_vn));
        else
            d_pcaNorm=eig(data_vn'*data_vn);
        end
    end
    Out.lambda_pcaNorm=flipud(d_pcaNorm);

    %Enable fitting multiple noise distributions
    DOF=Out.DOF;
    %DOF=sum(Out.lambda_pcaNorm>std(Out.lambda_pcaNorm)*0.1); %Recompute DOF because of demeaning in cov
    MaxX=length(data_vn); 
    if DEMDT==-1
        MaxX=2000000;
    end
    lambda=Out.lambda_pcaNorm;
    S=0;
    clear EN
    for i=1:NDist
        [x(i),en] = FitWishart(lnb,S,DOF,MaxX,lambda(1:DOF));
        lambda=lambda(1:DOF)-en(1:DOF); 
        en=[en; zeros(Out.DOF-length(en)+1,1,'single')];
        EN(:,i)=en(1:Out.DOF);
        MaxX=x(i);
        DOF=min(find(lambda <= 0)); 
        lambda=[lambda(1:DOF-1); zeros(Out.DOF-DOF+1,1,'single')];
        lambda=lambda(1:Out.DOF);
    end
      
    Out.EN=sum(EN,2); 
    %Out.x(c)=x(1);
    %Out.x(c)=round(x(end));
    %DOF=round(Out.DOF);
    if NDist>1
       %Out.x(c)=round(x(1)-sum(x(2:end))); %Fit is not as steep as data, so subtract additional spatial DOFs
       %Best fit Wishart to entire multi-piece Wishart 
       [x,en] = FitWishart(0.01,S,Out.DOF,x(1),Out.EN);
       Out.x(c) = x;
    else
       Out.x(c)=round(x(1)); 
    end
    %MaxS=5;
    %DOF=Out.DOF;
    %MaxX=round(Out.x(c));
    %MaxX=length(data_vn);
    %lambda=Out.lambda_pcaNorm;
    %[Out.x(c),Out.EN,Out.s(c)] = SmoothEst(lnb,MaxS,DOF,MaxX,lambda);

    %[Out.x(c),Out.EN] = FitWishart(lnb,Out.s(c),DOF,MaxX,lambda(1:DOF));
    
    %Divide eigenvalues by null for adjusted output values
    Out.lambdaAdj = Out.lambda_pcaNorm(1:DOF)./(Out.EN(1:DOF));
    %Out.lambdaAdj(DOF:end)=1;
    n=DOF-1;
    tmp=ones(Out.DOF,1);
    tmp(1:n)=Out.lambdaAdj(1:n);
    Out.lambdaAdj=tmp;
    %Normalize adjusted eigenvalues to 1 for input to laplacian
    %Out.lambdaAdj_norm = Out.lambdaAdj ./ max(Out.lambdaAdj);

    Out.pcaDim_lambdaAdj = pca_dim(Out.lambdaAdj',Out.x(c));
    
    %Maximum of laplacian is estimate of optimal dimensionality
    [~, Out.calcDim]=max(Out.pcaDim_lambdaAdj.lap(1:DOF));
    
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
    if Iterate < 0 
        if c>3
            diffdimavg = abs(priordimavg-mean(Out.VNDIM(4:end)));
            if diffdimavg < stabThresh
                stabCount = 1;
            else
                stabCount = 0;
            end
            priordimavg = mean(Out.VNDIM(4:end));
            disp(['   dimavg: ' mat2str(priordimavg)]);
        else
            stabCount = 0;
        end
    end

    if Iterate > 3
        stabCount=c;
        priordimavg = mean(Out.VNDIM(4:end));
        disp(['   dimavg: ' mat2str(priordimavg)]);
    end
end %End while loop for dim calcs

% Outside the while loop, no longer need 'data'
clear data;

if Iterate < 0 
    Out.calcDim=round(priordimavg);
end
if Iterate > 3 
    Out.calcDim=round(mean(Out.VNDIM(4:end)));
end

[u,EigS,v]=nets_svds(data_vn',0);
clear data_vn;

u(isnan(u))=0; v(isnan(v))=0;
Out.EigSAdj=zeros(length(EigS),1,'single');
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
disp(['   Out.DOF: ' mat2str(Out.DOF)]);
disp(['   DOF: ' mat2str(DOF)]);
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

% Form the masked voxel version of the output data
tmp = (u*diag(Out.EigSAdj)*v')'; clear v;
tmp = tmp .* repmat(Out.noise_unst_std,1,Ntp);
if DEMDT==1
    % Add the trend back in
	tmp = tmp + data_trend;
	clear data_trend;
elseif DEMDT==0
    % Add the mean back in
	tmp = tmp + repmat(data_mean,1,Ntp);
elseif DEMDT==-1
    % No demeaning or detrending performed; nothing to add back in
end

% Create the fully-formed (non-masked) version of the output data
if useMask
    Out.data = zeros(NvoxOrig,Ntp,'single');
    Out.data(mask,:) = tmp;
else
    Out.data = tmp;
end
clear tmp;

% Create fully-formed (non-masked) version of Out.noise_unst_std, 
% and make sure its value is at least 0.001
if useMask
    temp = zeros(NvoxOrig,1,'single');
    temp(mask,:) = Out.noise_unst_std;
else
    temp = Out.noise_unst_std;
end
Out.noise_unst_std=max(temp,0.001);
clear temp;

end %End main function


%% ----------- Internal Helper Functions ------------ %%

function [out] = lpdist(in)
    out=pdist(log(in));
end

function [x,EN] = FitWishart(lnb,S,DOF,MaxX,lambda) %FitWishart(lnb,step,DOF,MaxX,lambda)
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
    
    disp(['golden search initial range: ' num2str(a) ' to ' num2str(b)]);
    
    while (abs(b-a)>epsilon) && (k<iter) %Loop until low error OR max iter met
        %k=k+1;
        
        %previous search progress code, very noisy
        %disp([num2str(a) ' ' num2str(x1) ' ' num2str(x2) ' ' num2str(b)]);
        
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
    
    disp(['golden search result: ' num2str(x)]);
    
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
    
    disp(['golden search initial range: ' num2str(a) ' to ' num2str(b)]);
    
    while (abs(b-a)>epsilon) && (k<iter) %Loop until low error OR max iter met
        %k=k+1;
        
        %previous search progress code, very noisy
        %disp([num2str(a) ' ' num2str(s1) ' ' num2str(s2) ' ' num2str(b)]);
        
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
    
    disp(['golden search result: ' num2str(s)]);
    
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

	O=zeros(size(M,1),size(M,2),'single');

	for i=1:size(M,2)
	  op
	  O(:,i) = conv (M(:,i), gaussFilter, 'same');
	  %O(:,i) = filter (gaussFilter,1,M(:,i));
	end
  end
end
