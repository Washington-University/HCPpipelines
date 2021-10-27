%% load MEG data (see NeuroImage 2004 paper)

load megdata

%% Estimation 

% Reduce dimension from 122 ordinal signals to 20
% Resample 25 times using random initial conditions and bootstrapping
% (use FastICA parameters: kurtosis as non-linearity,
% symmetric estimation approach

sR=icassoEst('both', megdata, 25, 'lastEig', 20, 'g', 'pow3', ...
             'approach', 'symm');

%% sR contains now estimates. Next 
%- dissimilarity measure between them is formed
%- estimates are clustered
%- a projection for the visualization is computed


%%% Default similarity measure, clustering and projection:

sR=icassoExp(sR);

%%% Visualization & returning results

disp('Launch Icasso visualization supposing 20 estimate-clusters.');
disp('Show demixing matrix rows.'); 
disp('Press any key...');
pause;

icassoShow(sR,'L',20,'estimate','demixing');

disp('Launch Icasso visualization supposing 20 estimate-clusters.');
disp('Show IC source estimates (default), reduce number of lines'); 
disp('Collect results.');
disp('Press any key...');
pause;

[iq,A,W,S]=icassoShow(sR,'L',20,'colorlimit',[.8 .9]);

%%% plot the "best two" estimate into figure 6

[tmp,i]=sort(-iq)

figure(6)
signalplot(S(i(1:2),:));

title(sprintf('(Centrotypes) of best two estimates (labels %d and %d)',i(1),i(2)));
       
%%% plot rows of W that belong to estimate-cluster number 2 (are
%%% around centrotype with label number 2')

% Find estimates that belong to cluster label=2 when L=20
%estimate-clusters are selected

L=20; label=2;

% Indices to the estimates in Icasso data struct
idx=find(sR.cluster.partition(L,:)==label)

% Find rows in the demixing matrix 
w=icassoGet(sR,'demixingmatrix',idx);

% Plot the signals
figure(7);
signalplot(w);
title(['Rows of W that belong to estimate-cluster number' num2str(label)]);

%% Plot estimates of S that belong to estimate-cluster number label=2
figure(8);
s=icassoGet(sR,'source',idx);
signalplot(s);
title(['Estimates that belong to estimate-cluster number' num2str(label)])


%% Next we compare the centrotype and mean (centroid) of an estimate-cluster

% Compute mean estimate for estimate cluster number label=2
% remember that the sign may change arbitrarily: function
% 'parallelize' takes care of this:

% compute mean of estimates
m=mean(parallelize(s',s(1,:)')');

% get the centrotype
index2centrotype=icassoIdx2Centrotype(sR,'index',idx);
c=icassoGet(sR,'source',index2centrotype);

figure(9)
plot(c);
title(['Centrotype of estimate-cluster' num2str(label)]);

figure(10);
plot(m);
title(['Mean of estimate-cluster ' num2str(label)])

