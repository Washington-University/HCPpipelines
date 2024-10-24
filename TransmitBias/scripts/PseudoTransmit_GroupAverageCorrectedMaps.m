function PseudoTransmit_GroupAverageCorrectedMaps(myelinRCFile, myelinAsymmOutFile, avgPTFieldFile, AvgPTFieldAsymmOutFile, GCorrMyelinOutFile, GCorrMyelinAsymmOutFile, ICorrMyelinFile, AvgICorrMyelinAsymmOutFile, IndCorrAllMyelinFile, VoltagesFile, PTStatsFile, rPTNormFile, CSFStatsFile, RegCorrMyelinOutFile, CovariatesOutFile)
    %these two asymmetry outputs were moved from first group script so that we don't need the function until now
    MyelinMap = cifti_read(myelinRCFile);
    surfasymmnorm(MyelinMap, myelinAsymmOutFile, 'Group Myelin Asymmetry');
    AvgPTField = cifti_read(avgPTFieldFile);
    surfasymmnorm(AvgPTField, AvgPTFieldAsymmOutFile, 'PseudoTransmit Asymmetry');
    
    [leftmyelin leftroi] = cifti_struct_dense_extract_surface_data(MyelinMap, 'CORTEX_LEFT');
    [rightmyelin rightroi] = cifti_struct_dense_extract_surface_data(MyelinMap, 'CORTEX_RIGHT');
    leftPTF = cifti_struct_dense_extract_surface_data(AvgPTField, 'CORTEX_LEFT');
    rightPTF = cifti_struct_dense_extract_surface_data(AvgPTField, 'CORTEX_RIGHT');
    bothroi = leftroi & rightroi;

    %was called findAFIRatioLR
    [globalslope globalintercept] = findFlipCorrectionSlopeLR(leftmyelin(bothroi), rightmyelin(bothroi), leftPTF(bothroi), rightPTF(bothroi));
    GCorrMyelin = cifti_struct_create_from_template(MyelinMap, MyelinMap.cdata ./ (AvgPTField.cdata * globalslope + globalintercept), 'dscalar');
    cifti_write(GCorrMyelin, GCorrMyelinOutFile);

    surfasymmnorm(GCorrMyelin, GCorrMyelinAsymmOutFile, 'Group-corrected Myelin Asymmetry');
    
    ICorrMyelin = cifti_read(ICorrMyelinFile);
    surfasymmnorm(ICorrMyelin, AvgICorrMyelinAsymmOutFile, 'Average Individual-corrected Myelin Asymmetry');

    IndCorrAllMyelinMaps = cifti_read(IndCorrAllMyelinFile); %All.IndPseudoCorr
    
    Voltages = load(VoltagesFile);
    PTStats = load(PTStatsFile);
    rptnorm = cifti_read(rPTNormFile);
    CSFRegressors = load(CSFStatsFile);

    Corr = [];
    for i = 1:size(CSFRegressors, 2)
        Corr(i) = corr(CSFRegressors(:, i), mean(IndCorrAllMyelinMaps.cdata, 1)');
    end

    [~, I] = max(Corr);
    BestCSFRegressor = CSFRegressors(:, I);
    
    AllRegressors = [Voltages mean(rptnorm.cdata(:, :))' PTStats(:, 1) PTStats(:, 2) PTStats(:, 3) PTStats(:, 4) BestCSFRegressor];
    dlmwrite(CovariatesOutFile, AllRegressors, ',');
    
    AllRegressorsNorm = normalise(AllRegressors)'; %prevent the regressors from soaking up any of the mean, could be just a demean
    betas = IndCorrAllMyelinMaps.cdata * pinv([ones(1, size(PTStats, 1)); AllRegressorsNorm]);
    cifti_write_from_template(IndCorrAllMyelinMaps, IndCorrAllMyelinMaps.cdata - betas(:, 2:end) * AllRegressorsNorm, RegCorrMyelinOutFile); %don't remove the mean from the data
end

%only need to save it, the result isn't used in this code
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

