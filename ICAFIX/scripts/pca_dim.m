function prob=pca_dim(lambda,N);
% PCA_DIM   Automatic choice of dimensionality for PCA
%   
% Laplace approximation and subsequernt simplifications to the
% posterior probability of the Data being generated from hidden var's
% of dimensionality k

% Methods described in
%   Thomas Minka:
%                  Automatic choice of dimensionality for PCA
%   Implemented by Christian Beckmann, Bugfix by Alex Yang and Tim Coalson
   
   logLambda=log(lambda);
   d=length(lambda);
   k=[1:d];

   m=d*k-0.5*k.*(k+1);

   lgam=cumsum(gammaln((d-k+1)/2));

   l_prob_U=-log(2).*k+lgam-cumsum(((d-k+1)/2)*log(pi));

   tmp=fliplr(sum(lambda)-cumsum(lambda));
   tmp(1)=min(abs(2*tmp(2)-tmp(3)),0.9*tmp(2));
   tmp=fliplr(tmp);
   tmp2=fliplr(sum(logLambda)-cumsum(logLambda));
   tmp2(1)=tmp2(2);
   tmp2=fliplr(tmp2);
   
   tmp3=([tmp(1:d-1) tmp(d-1)])./([d-k(1:d-1) 1]);
 
   l_nu=-N/2*(d-k).*log(tmp3);
   l_nu(d)=0;
   
   a=lambda;
   b=tmp3;
  
   t1=triu((ones(d,1)*a)'-(ones(d,1)*a),1);
   t2=triu(((b.^(-1))'*ones(1,d))'-(ones(d,1)*(a.^(-1)))',1);
   t1(t1<=0)=1;
   t2(t2<=0)=1;
   t1=cumsum(sum(log(t1),2));
   t2=cumsum(sum(log(t2),2));
   %l_Az=0.5*(t1+t1)'; %typo t1+t1, 0.5 not present in melodic c++
   l_Az=(t1+t2)'; 


   l_lam=-(N/2)*cumsum(log(lambda));

   
   l_prob_DK = (l_prob_U + l_nu + l_Az + l_lam + (m+k)/2*log(2*pi) - k/2*log(N));
   l_BIC = (l_lam+l_nu-(m+k)/2*log(N));
   
 
% AIC and MDL
    
   llhood = [1./(d-k(1:d-1))].*tmp2(1:d-1)-log([1./(d-k(1:d-1))].* tmp(1:d-1));
   AIC = -2*N*(d-k(1:d-1)).*llhood + 2*(1+d.*k(1:d-1)+0.5*(k(1:d-1)-1)); 
   MDL = -N*(d-k(1:d-1)).*llhood + 0.5*(1+d.*k(1:d-1)+0.5*(k(1:d-1)-1))*log(N);



   
   l_prob_DK=(l_prob_DK-min(l_prob_DK))./(max(l_prob_DK)-min(l_prob_DK));
   l_BIC=(l_BIC-min(l_BIC))./(max(l_BIC)-min(l_BIC));
   AIC=1-((AIC-min(AIC))./(max(AIC)-min(AIC)));
   MDL=1-((MDL-min(MDL))./(max(MDL)-min(MDL)));
   
   
   prob.lap=l_prob_DK; 
   prob.BIC=l_BIC; 
   prob.AIC=AIC;
   prob.MDL=MDL;
   
   prob.eig=lambda;
   prob.leig=logLambda;
   
   prob.lML=llhood;
   
 
