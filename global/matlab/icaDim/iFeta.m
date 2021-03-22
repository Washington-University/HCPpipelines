function [Result] = iFeta(eta,d1,d2);
%Implemented by Christian Beckmann   
  res = d1*(1-Feta(eta,d1/d2));
 
  Result = zeros(1,d1);
  
  for k= 1 : d1;
     %Result(k) = eta(max(find(res>=k)));
     Result(k) = eta(find(res>=k,1,'last'));
  end;
  
