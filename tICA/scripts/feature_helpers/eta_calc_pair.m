function eta_matrix=eta_calc_pair(input_matrixa,input_matrixb)

m=size(input_matrixa,2);
n=size(input_matrixb,2);
zmapa=input_matrixa;
zmapb=input_matrixb;

% calculate the eta
eta_matrix=zeros(m,n,'single');
meanzmapa=mean(zmapa);
meanzmapb=mean(zmapb);

for i=1:m
    %i
    for j=1:n
        
            % mean correlation value over all locations in both images
            Mgrand  = (meanzmapa(i) + meanzmapb(j))/2;
            %
            % mean value matrix for each location in the 2 images
            Mwithin = (zmapa(:,i)+zmapb(:,j))/2;
            SSwithin = sum((zmapa(:,i)-Mwithin).^2) + sum((zmapb(:,j)-Mwithin).^2);
            SStot    = sum((zmapa(:,i)-Mgrand ).^2) + sum((zmapb(:,j)-Mgrand ).^2);
            %
            % N.B. SStot = SSwithin + SSbetween so eta can also be written as SSbetween/SStot
            eta_matrix(i,j) = 1 - SSwithin/SStot;
    end
end
end
