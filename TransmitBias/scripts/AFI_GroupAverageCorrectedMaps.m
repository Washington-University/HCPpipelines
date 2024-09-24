function AFI_GroupAverageCorrectedMaps(AvgIndCorrMyelinFile, AvgIndCorrMyelinAsymmOutFile, IndCorrMyelinAllFile, GoodVoltagesFile, rAFIFile, AFIStatsFile, CSFStatsFile, RegressedMyelinOutFile, CovariatesOutFile)
    AvgICorrMyelinMap = cifti_read(AvgIndCorrMyelinFile);
    surfasymmnorm(AvgICorrMyelinMap, AvgIndCorrMyelinAsymmOutFile, 'Average Individual-corrected Myelin Asymmetry');
    clear AvgICorrMyelinMap;
    
    FWHM = load(AFIStatsFile);
    rAFI = cifti_read(rAFIFile);
    CSFRegressors = load(CSFStatsFile);
    
    IndCorrAllMyelinMaps = cifti_read(IndCorrMyelinAllFile); %Partial.All.MyelinMap_IndCorr
    
    GoodVoltages = load(GoodVoltagesFile);
    
    %selecting csf percentile to use
    Corr = zeros(1, size(CSFRegressors, 2));
    for i = 1:size(CSFRegressors, 2)
        Corr(i) = corr(CSFRegressors(:, i), mean(IndCorrAllMyelinMaps.cdata, 1)');
    end
    [~, maxind] = max(Corr);
    
    %save regressors
    regressors = [GoodVoltages mean(rAFI.cdata)' FWHM(:, 3) FWHM(:, 2) FWHM(:, 1) CSFRegressors(:, maxind)];
    dlmwrite(CovariatesOutFile, regressors, ',');
    
    %generate regressed myelin
    normregressors = normalise(regressors)'; %prevent the regressors from soaking up any of the mean, could be just a demean instead
    betas = IndCorrAllMyelinMaps.cdata * pinv([ones(1, size(FWHM, 1)); normregressors]); %include a constant term to model the mean for a more appropriate fit
    cifti_write_from_template(IndCorrAllMyelinMaps, IndCorrAllMyelinMaps.cdata - betas(:, 2:end) * normregressors, RegressedMyelinOutFile); %don't remove the mean from the data
end

function surfasymmnorm(CiftiIn, ciftiOutFile, varargin)
    [leftdata leftroi] = cifti_struct_dense_extract_surface_data(CiftiIn, 'CORTEX_LEFT');
    [rightdata rightroi] = cifti_struct_dense_extract_surface_data(CiftiIn, 'CORTEX_RIGHT');
    bothroi = leftroi & rightroi;
    output = zeros(size(leftdata), 'single'); %support multi map properly, though probably not needed
    output(bothroi, :) = (leftdata(bothroi, :) - rightdata(bothroi, :)) ./ ((leftdata(bothroi, :) + rightdata(bothroi, :)) / 2);
    CiftiOut = cifti_struct_dense_replace_surface_data(CiftiIn, output, 'CORTEX_LEFT');
    CiftiOut = cifti_struct_dense_replace_surface_data(CiftiOut, output, 'CORTEX_RIGHT');
    CiftiOut.diminfo{2} = cifti_diminfo_make_scalars(1, varargin{:});
    cifti_write(CiftiOut, ciftiOutFile);
end

