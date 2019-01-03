function x=normalise(x,dim)

% normalise(X) 
% Removes the Average or mean value and makes the std=1
%
% normalise(X,DIM)
% Removes the mean and makes the std=1 along the dimension DIM of X. 

if(nargin==1),
   dim = 1;
   if(size(x,1) > 1)
      dim = 1;
   elseif(size(x,2) > 1)
      dim = 2;
   end;
end;

dims = size(x);
dimsize = size(x,dim);
dimrep = ones(1,length(dims));
dimrep(dim) = dimsize;

x = x - repmat(mean(x,dim),dimrep);
x = x./repmat(std(x,0,dim),dimrep);