function [Result] = Feta(eta,y,sig2);
%Implemented by Christian Beckmann
   
   if nargin<3
      sig2=1;
   end;
   
   bm=sig2*(1-sqrt(y))^2;
   bp=sig2*(1+sqrt(y))^2;
   
   Result=zeros(size(eta));

   teta=bm:1/1000:bp;
   feta=zeros(size(teta));
   feta=((2*pi*y*teta).^(-1)).*sqrt((teta-bm).*(bp-teta));
   
%   figure
%   plot(feta)
   tmp=(teta'*ones(1,size(eta,2)))./(ones(size(teta,2),1)*eta)<1;
%   imagesc(tmp);
%   colorbar;
   Result=sum((0.001*feta'*ones(1,size(eta,2))).*tmp);
  
