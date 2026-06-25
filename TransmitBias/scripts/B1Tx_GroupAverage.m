function B1Tx_GroupAverage(myelinFile, myelinAsymmOutFile, phaseFile, phaseAsymmOutFile, myelinCorrOutFile, myelinCorrAsymmOutFile, fitParamsOutFile)
    
    %Orig Myelin, with receive corr if applicable
    MyelinMap = cifti_read(myelinFile);
    surfasymmnorm(MyelinMap, myelinAsymmOutFile, 'Group Myelin Asymmetry');
    
    %already-divided phase, which means it is flip angle ratio
    B1TxPhase = cifti_read(phaseFile);
    surfasymmnorm(B1TxPhase, phaseAsymmOutFile, 'Group B1Tx Phase Asymmetry');
    
    [leftmyelin leftroi] = cifti_struct_dense_extract_surface_data(MyelinMap, 'CORTEX_LEFT');
    [rightmyelin rightroi] = cifti_struct_dense_extract_surface_data(MyelinMap, 'CORTEX_RIGHT');
    bothroi = leftroi & rightroi;
    [leftPhase leftroi2] = cifti_struct_dense_extract_surface_data(B1TxPhase, 'CORTEX_LEFT');
    [rightPhase rightroi2] = cifti_struct_dense_extract_surface_data(B1TxPhase, 'CORTEX_RIGHT');
    if any(bothroi ~= (leftroi2 & rightroi2))
        error('myelin and B1Tx phase have different medial wall ROIs');
    end
    
    %GroupCorrected Myelin
    [globalslope globalintercept] = findFlipCorrectionSlopeLR(leftmyelin(bothroi), rightmyelin(bothroi), leftPhase(bothroi), rightPhase(bothroi));
    GCorrMyelinMap = cifti_struct_create_from_template(MyelinMap, MyelinMap.cdata ./ (B1TxPhase.cdata * globalslope + globalintercept), 'dscalar');
    cifti_write(GCorrMyelinMap, myelinCorrOutFile);
    surfasymmnorm(GCorrMyelinMap, myelinCorrAsymmOutFile, 'Group-Corrected Myelin Asymmetry');

    dlmwrite(fitParamsOutFile, [globalslope globalintercept], ' ');
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

