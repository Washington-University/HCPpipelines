function AFI_GroupAverage(myelinFile, myelinAsymmOutFile, AFIFile, AFITargAngle, AFIAsymmOutFile, myelinCorrOutFile, myelinCorrAsymmOutFile, fitParamsOutFile)
    
    %take numbers as strings, for unified compiled/interpreted handling
    AFITargAngle = str2double(AFITargAngle);
    %Figure GROUP_MYELIN_AND_AFI
    
    %Orig Myelin, with receive corr if applicable
    MyelinMap = cifti_read(myelinFile);
    surfasymmnorm(MyelinMap, myelinAsymmOutFile, 'Group Myelin Asymmetry');
    
    OrigAFIRaw = cifti_read(AFIFile);
    OrigAFI = cifti_struct_create_from_template(OrigAFIRaw, OrigAFIRaw.cdata / AFITargAngle, 'dscalar');
    surfasymmnorm(OrigAFI, AFIAsymmOutFile, 'AFI Asymmetry');
    
    %Figure GROUP_ORIGINAL_AND_CORRECTED_MYELIN
    
    [leftmyelin leftroi] = cifti_struct_dense_extract_surface_data(MyelinMap, 'CORTEX_LEFT');
    [rightmyelin rightroi] = cifti_struct_dense_extract_surface_data(MyelinMap, 'CORTEX_RIGHT');
    bothroi = leftroi & rightroi;
    [leftMAFI leftroi2] = cifti_struct_dense_extract_surface_data(OrigAFI, 'CORTEX_LEFT');
    [rightMAFI rightroi2] = cifti_struct_dense_extract_surface_data(OrigAFI, 'CORTEX_RIGHT');
    if any(bothroi ~= (leftroi2 & rightroi2))
        error('myelin and AFI have different medial wall ROIs');
    end
    
    %GroupCorrected Myelin
    [globalslope globalintercept] = findFlipCorrectionSlopeLR(leftmyelin(bothroi), rightmyelin(bothroi), leftMAFI(bothroi), rightMAFI(bothroi));
    GCorrMyelinMaps = cifti_struct_create_from_template(MyelinMap, MyelinMap.cdata ./ (OrigAFI.cdata * globalslope + globalintercept), 'dscalar');
    cifti_write(GCorrMyelinMaps, myelinCorrOutFile);
    surfasymmnorm(GCorrMyelinMaps, myelinCorrAsymmOutFile, 'Group-Corrected Myelin Asymmetry');

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

