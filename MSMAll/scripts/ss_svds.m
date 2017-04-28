
function [u,s,v]=ss_svds(x,n);

if size(x,1) < size(x,2)

  if n < size(x,1)
    [u,d] = eigs(x*x',n);
  else
    [u,d] = eig(x*x'); u=fliplr(u); d=flipud(fliplr(d));
  end
  s = sqrt(abs(d));
  v = x' * (u * diag((1./diag(s)))); 

else

  if n < size(x,2)
    [v,d] = eigs(x'*x,n);
  else
    [v,d] = eig(x'*x); v=fliplr(v); d=flipud(fliplr(d));
  end
  s = sqrt(abs(d));
  u = x * (v * diag((1./diag(s)))); 

end

