function WishartFilter(inputFiles, outputFiles, numWisharts, pfmDim)
    numWisharts = str2double(numWisharts);
    pfmDim = str2double(pfmDim);
    inList = strsplit(inputFiles, ',');
    outList = strsplit(outputFiles, ',');
    
    allData = [];
    tpCounts = [];
    for i = 1:length(inList)
        cii = ciftiopen(strtrim(inList{i}), 'wb_command');
        tpCounts(i) = size(cii.cdata, 2);
        allData = [allData cii.cdata];
    end
    
    Ntp = size(allData, 2);
    
    mask = range(allData, 2) > 0;
    data = allData(mask, :);
    
    [u, EigS, v] = nets_svds(data', 0);
    DOF = sum(diag(EigS) > (std(diag(EigS)) * 0.1));
    u(isnan(u)) = 0;
    v(isnan(v)) = 0;
    
    noise_unst = (u(:, pfmDim:DOF) * EigS(pfmDim:DOF, pfmDim:DOF) * v(:, pfmDim:DOF)')';
    noise_unst_std = max(std(noise_unst, [], 2), 0.001);
    clear noise_unst;
    data_vn = data ./ repmat(noise_unst_std, 1, Ntp);
    
    lambda = flipud(eig(cov(data_vn)));
    
    lnb = 0.5;
    MaxX = size(data_vn, 1);
    origDOF = DOF;
    clear EN
    for i = 1:numWisharts
        [x, en] = FitWishart(lnb, 0, DOF, MaxX, lambda(1:DOF));
        lambda = lambda(1:DOF) - en(1:DOF);
        en_padded = zeros(origDOF, 1, 'single');
        en_padded(1:min(length(en), origDOF)) = en(1:min(length(en), origDOF));
        EN(:,i) = en_padded;
        MaxX = x;
        DOF = min(find(lambda <= 0));
        if isempty(DOF)
            break;
        end
        lambda = [lambda(1:DOF-1); zeros(origDOF - DOF + 1, 1, 'single')];
        lambda = lambda(1:origDOF);
    end
    EN_all = sum(EN, 2);

    [u2, EigS2, v2] = nets_svds(data_vn', 0);
    u2(isnan(u2)) = 0;
    v2(isnan(v2)) = 0;
    
    grot = diag(EigS2);
    grot_sq = grot.^2;
    grot_scaled = (grot_sq ./ max(grot_sq)) .* max(lambda);
    grot_adj = grot_scaled(1:length(EN_all)) - EN_all;
    firstZero = min(find(grot_adj <= 0));
    if ~isempty(firstZero)
        grot_adj(firstZero:end) = 0;
    end
    EigSAdj = zeros(length(grot), 1, 'single');
    EigSAdj(1:length(grot_adj)) = sqrt(max(grot_adj, 0));
    
    filtered = (u2 * diag(EigSAdj) * v2')';
    filtered = filtered .* repmat(noise_unst_std, 1, Ntp);
    
    fullFiltered = zeros(size(allData), 'single');
    fullFiltered(mask, :) = filtered;
    
    startTP = 1;
    for i = 1:length(outList)
        endTP = startTP + tpCounts(i) - 1;
        cii = ciftiopen(strtrim(inList{i}), 'wb_command');
        cii.cdata = fullFiltered(:, startTP:endTP);
        ciftisave(cii, strtrim(outList{i}), 'wb_command');
        startTP = endTP + 1;
    end
end

%% ----------- Internal Helper Functions(From icaDim.m) ------------ %%

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
