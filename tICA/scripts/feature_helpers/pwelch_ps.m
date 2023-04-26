function [ts_spectra] = pwelch_ps(ts)
%pwelch spectrum estimation for a single timeseries
grot=ts';
blah=pwelch(grot,[],[],length(grot));
ts_spectra=[];
ts_spectra(:,1)=blah(1:end-1,:);
F_end=mean(ts_spectra(end-9:end,1));
ts_spectra(:,1)=ts_spectra(:,1)/F_end;
end

