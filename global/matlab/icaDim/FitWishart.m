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


%% ----------- Internal Helper Functions ------------ %%
function [out] = lpdist(in)
    out=pdist(log(in));
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