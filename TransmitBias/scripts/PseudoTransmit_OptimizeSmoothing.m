function PseudoTransmit_OptimizeSmoothing(OriginalMyelin, ScaledPseudoTransmit, LeftPial, LeftMidthick, LeftWhite, RightPial, RightMidthick, RightWhite, ThreshLower, ThreshUpper, SmoothLower, SmoothUpper, L_ROI, R_ROI, OutlierSmoothing, Dilation, GroupUncorrectedMyelin, MyelinTemplate, OutputTextFile)

    %to unify the argument list specification between compiled and interpreted, take all arguments as strings
    ThreshLower = str2double(ThreshLower);
    ThreshUpper = str2double(ThreshUpper);
    SmoothLower = str2double(SmoothLower);
    SmoothUpper = str2double(SmoothUpper);
    OutlierSmoothing = str2double(OutlierSmoothing);
    Dilation = str2double(Dilation);

    MyelinMap = cifti_read(OriginalMyelin); %Load Myelin
    [leftdata leftroi] = cifti_struct_dense_extract_surface_data(MyelinMap, 'CORTEX_LEFT');
    [rightdata rightroi] = cifti_struct_dense_extract_surface_data(MyelinMap, 'CORTEX_RIGHT');
    bothroi = leftroi & rightroi;
    Template = cifti_read(MyelinTemplate);
    GroupOrig = cifti_read(GroupUncorrectedMyelin);
    TemplateData = Template.cdata ./ mean(Template.cdata) .* mean(GroupOrig.cdata);
    clear Template GroupOrig;

    ScaledPT = mapvoltosurf(ScaledPseudoTransmit, OriginalMyelin, LeftPial, LeftMidthick, LeftWhite, L_ROI, RightPial, RightMidthick, RightWhite, R_ROI);
    %MFG: paper shows dropout areas have overflipping, expect them all to be over 1 once dilated out
    %input PseudoTransmit still has dropout, but the dropout areas will also be areas of overflipping once the dropouts are fixed (in the volume) by dilation, so count any dropout areas as above-1 flip ratio
    fracUnder = sum(ScaledPT.cdata(:) < ThreshLower) / prod(size(ScaledPT.cdata));
    %TSC: we do ReferenceValue scaling before matlab now
    fracOver = (sum(ScaledPT.cdata(:) > 1) / prod(size(ScaledPT.cdata))) + fracUnder; %store how many are expected to be beyond the ideal threshold
    clear ScaledPT;

    lowguess = ThreshLower;
    highguess = ThreshUpper;
    searchratio = 1 - 2 / (sqrt(5) + 1); % 1 - inverse of golden ratio
    currange = highguess - lowguess;
    points = [lowguess, lowguess + searchratio * currange, highguess - searchratio * currange, highguess];
    for i = 1:length(points)
        [vals(i) smooth(i) slope(i) correctionfac(i)] = SmoothOptimize(points(i), SmoothLower, SmoothUpper, OriginalMyelin, ScaledPseudoTransmit, LeftPial, LeftMidthick, LeftWhite, RightPial, RightMidthick, RightWhite, L_ROI, R_ROI, TemplateData, MyelinMap.cdata, leftdata, rightdata, bothroi, OutlierSmoothing, Dilation, fracOver);
    end
    precision = 0.01;
    while points(4) - points(1) > precision
        if vals(2) < vals(3)
            points(3:4) = points(2:3); vals(3:4) = vals(2:3); smooth(3:4) = smooth(2:3); slope(3:4) = slope(2:3);
            currange = points(4) - points(1);
            points(2) = points(1) + searchratio * currange;
            [vals(2) smooth(2) slope(2) correctionfac(2)] = SmoothOptimize(points(2), SmoothLower, SmoothUpper, OriginalMyelin, ScaledPseudoTransmit, LeftPial, LeftMidthick, LeftWhite, RightPial, RightMidthick, RightWhite, L_ROI, R_ROI, TemplateData, MyelinMap.cdata, leftdata, rightdata, bothroi, OutlierSmoothing, Dilation, fracOver);
        else
            points(1:2) = points(2:3); vals(1:2) = vals(2:3); smooth(1:2) = smooth(2:3); slope(1:2) = slope(2:3);
            currange = points(4) - points(1);
            points(3) = points(4) - searchratio * currange;
            [vals(3) smooth(3) slope(3) correctionfac(3)] = SmoothOptimize(points(3), SmoothLower, SmoothUpper, OriginalMyelin, ScaledPseudoTransmit, LeftPial, LeftMidthick, LeftWhite, RightPial, RightMidthick, RightWhite, L_ROI, R_ROI, TemplateData, MyelinMap.cdata, leftdata, rightdata, bothroi, OutlierSmoothing, Dilation, fracOver);
        end
    end
    if vals(2) < vals(3)
        bestthresh = points(2);
        bestsmooth = smooth(2);
        bestval = vals(2);
        bestslope = slope(2);
        bestcorrectionfac = correctionfac(2);
    else
        bestthresh = points(3);
        bestsmooth = smooth(3);
        bestval = vals(3);
        bestslope = slope(3);
        bestcorrectionfac = correctionfac(3);
    end
    
    Flag = 1; %probably unused
    dlmwrite(OutputTextFile, [bestthresh bestsmooth bestcorrectionfac bestslope bestval Flag], ',');
end

function ciftiout = mapvoltosurf(filename, ciftitemplate, LeftPial, LeftMidthick, LeftWhite, LeftVolROI, RightPial, RightMidthick, RightWhite, RightVolROI, dilatedist)
    mytemp = tempname();
    cleanupObj = onCleanup(@()(mydelete([mytemp '.L.func.gii'], [mytemp '.R.func.gii'], [mytemp '.dscalar.nii'], [mytemp '_2.dscalar.nii'])));
    
    mysystem(['wb_command -volume-to-surface-mapping ' filename ' ' LeftMidthick ' ' mytemp '.L.func.gii -ribbon-constrained ' LeftWhite ' ' LeftPial ' -volume-roi ' LeftVolROI]);
    mysystem(['wb_command -volume-to-surface-mapping ' filename ' ' RightMidthick ' ' mytemp '.R.func.gii -ribbon-constrained ' RightWhite ' ' RightPial ' -volume-roi ' RightVolROI]);
    mysystem(['wb_command -cifti-create-dense-from-template ' ciftitemplate ' ' mytemp '.dscalar.nii -metric CORTEX_LEFT ' mytemp '.L.func.gii -metric CORTEX_RIGHT ' mytemp '.R.func.gii']);
    mysystem(['wb_command -cifti-dilate ' mytemp '.dscalar.nii COLUMN 10 10 ' mytemp '_2.dscalar.nii -left-surface ' LeftMidthick ' -right-surface ' RightMidthick]);
    
    ciftiout = cifti_read([mytemp '_2.dscalar.nii']);
end

function [val smooth slope correctionfac] = SmoothOptimize(thresh, SmoothLower, SmoothUpper, OriginalMyelin, ScaledPseudoTransmit, LeftPial, LeftMidthick, LeftWhite, RightPial, RightMidthick, RightWhite, L_ROI, R_ROI, Template, SMyelinMaps, leftdata, rightdata, bothroi, OutlierSmoothing, Dilation, fracOver)

    PseudoTransmitThreshold = thresh;

    tmpname = tempname();
    cleanupObj = onCleanup(@()(mydelete([tmpname '.L.nii.gz'], [tmpname '.R.nii.gz'], [tmpname '.threshbin.nii.gz'], [tmpname '.islandmask.nii.gz'], [tmpname '.smooth.nii.gz'], [tmpname '.diff.nii.gz'], [tmpname '.nooutliers.nii.gz'], [tmpname '.badvox.nii.gz'], [tmpname '.Lbad.nii.gz'], [tmpname '.Rbad.nii.gz'])));

    %threshold and remove islands
    %bash script repeats some of this, but maybe not enough for the matlab to actually apply it to an output file
    mysystem(['wb_command -volume-math "data >= ' num2str(PseudoTransmitThreshold) '" ' tmpname '.threshbin.nii.gz -var data ' ScaledPseudoTransmit]);
    mysystem(['wb_command -volume-remove-islands ' tmpname '.threshbin.nii.gz ' tmpname '.islandmask.nii.gz']);

    %smooth and subtract to find local outliers
    mysystem(['wb_command -volume-smoothing ' ScaledPseudoTransmit ' -fwhm ' num2str(OutlierSmoothing) ' ' tmpname '.smooth.nii.gz -roi ' tmpname '.islandmask.nii.gz']);
    mysystem(['wb_command -volume-math "Mask * (Data - Mean)" ' tmpname '.diff.nii.gz -var Data ' ScaledPseudoTransmit ' -var Mean ' tmpname '.smooth.nii.gz -var Mask ' tmpname '.islandmask.nii.gz']);
    stdev = strtrim(mysystem(['wb_command -volume-stats ' tmpname '.diff.nii.gz -reduce STDEV -roi ' tmpname '.islandmask.nii.gz']));
    mysystem(['wb_command -volume-math "abs(diff) > 2 * ' stdev '" ' tmpname '.badvox.nii.gz -var diff ' tmpname '.diff.nii.gz']);
    mysystem(['wb_command -volume-math "(! Bad) * islandmask * Data" ' tmpname '.nooutliers.nii.gz -var Data ' ScaledPseudoTransmit ' -var Bad ' tmpname '.badvox.nii.gz -var islandmask ' tmpname '.islandmask.nii.gz']);
    
    mysystem(['wb_command -volume-math "ROI && (Bad || (! islandmask))" ' tmpname '.Lbad.nii.gz -var ROI ' L_ROI ' -var Bad ' tmpname '.badvox.nii.gz -var islandmask ' tmpname '.islandmask.nii.gz']);
    mysystem(['wb_command -volume-math "ROI && (Bad || (! islandmask))" ' tmpname '.Rbad.nii.gz -var ROI ' R_ROI ' -var Bad ' tmpname '.badvox.nii.gz -var islandmask ' tmpname '.islandmask.nii.gz']);

    %exponent 2, probably because of a rim of dropout around thresholded parts
    %"nooutliers" has already masked out below threshold, islands, and badvox
    %next step inside the next function is smooth with fix zeros using the left/right ROI, so it doesn't matter that these contain some other-hemisphere data (from volume dilate's "copy if not replaced" logic)
    mysystem(['wb_command -volume-dilate ' tmpname '.nooutliers.nii.gz ' num2str(Dilation) ' WEIGHTED ' tmpname '.L.nii.gz -grad-extrapolate -exponent 2 -data-roi ' L_ROI ' -bad-voxel-roi ' tmpname '.Lbad.nii.gz']);
    mysystem(['wb_command -volume-dilate ' tmpname '.nooutliers.nii.gz ' num2str(Dilation) ' WEIGHTED ' tmpname '.R.nii.gz -grad-extrapolate -exponent 2 -data-roi ' R_ROI ' -bad-voxel-roi ' tmpname '.Rbad.nii.gz']);

    lowguess = SmoothLower;
    highguess = SmoothUpper;
    searchratio = 1 - 2 / (sqrt(5) + 1); % 1 - inverse of golden ratio
    currange = highguess - lowguess;
    points = [lowguess, lowguess + searchratio * currange, highguess - searchratio * currange, highguess];
    for i = 1:length(points)
        [vals(i) slope(i) correctionfac(i)] = mycost(points(i), thresh, OriginalMyelin, ScaledPseudoTransmit, LeftPial, LeftMidthick, LeftWhite, RightPial, RightMidthick, RightWhite, L_ROI, R_ROI, Template, SMyelinMaps, leftdata, rightdata, bothroi, tmpname, fracOver);
    end
    precision = 0.1; 
    while points(4) - points(1) > precision
        if vals(2) < vals(3)
            points(3:4) = points(2:3); vals(3:4) = vals(2:3); slope(3:4) = slope(2:3);
            currange = points(4) - points(1);
            points(2) = points(1) + searchratio * currange;
            [vals(2) slope(2) correctionfac(2)] = mycost(points(2), thresh, OriginalMyelin, ScaledPseudoTransmit, LeftPial, LeftMidthick, LeftWhite, RightPial, RightMidthick, RightWhite, L_ROI, R_ROI, Template, SMyelinMaps, leftdata, rightdata, bothroi, tmpname, fracOver);
        else
            points(1:2) = points(2:3); vals(1:2) = vals(2:3); slope(1:2) = slope(2:3);
            currange = points(4) - points(1);
            points(3) = points(4) - searchratio * currange;
            [vals(3) slope(3) correctionfac(3)] = mycost(points(3), thresh, OriginalMyelin, ScaledPseudoTransmit, LeftPial, LeftMidthick, LeftWhite, RightPial, RightMidthick, RightWhite, L_ROI, R_ROI, Template, SMyelinMaps, leftdata, rightdata, bothroi, tmpname, fracOver);
        end
    end
    if vals(2) < vals(3)
        smooth = points(2);
        val = vals(2);
        slope = slope(2);
        correctionfac = correctionfac(2);
    else
        smooth = points(3);
        val = vals(3);
        slope = slope(3);
        correctionfac = correctionfac(3);
    end
end

function [cost slope correctionfac] = mycost(smooth, thresh, OriginalMyelin, ScaledPseudoTransmit, LeftPial, LeftMidthick, LeftWhite, RightPial, RightMidthick, RightWhite, L_ROI, R_ROI, Template, SMyelinMaps, leftdata, rightdata, bothroi, tmpname, fracOver)
    
    cleanupObj = onCleanup(@()(mydelete([tmpname '.Lsmooth.nii.gz'], [tmpname '.Rsmooth.nii.gz'], [tmpname '.LRsmooth.nii.gz'], [tmpname '.L.func.gii'], [tmpname '.R.func.gii'], [tmpname '.dscalar.nii'])));
        
    mysystem(['wb_command -volume-smoothing ' tmpname '.L.nii.gz ' num2str(smooth) ' ' tmpname '.Lsmooth.nii.gz -fwhm -roi ' L_ROI ' -fix-zeros']); %Smooth data
    mysystem(['wb_command -volume-smoothing ' tmpname '.R.nii.gz ' num2str(smooth) ' ' tmpname '.Rsmooth.nii.gz -fwhm -roi ' R_ROI ' -fix-zeros']);
    mysystem(['wb_command -volume-math "LEFT + RIGHT" ' tmpname '.LRsmooth.nii.gz -var LEFT ' tmpname '.Lsmooth.nii.gz -var RIGHT ' tmpname '.Rsmooth.nii.gz']);

    SPseudoTransmit = mapvoltosurf([tmpname '.LRsmooth.nii.gz'], OriginalMyelin, LeftPial, LeftMidthick, LeftWhite, L_ROI, RightPial, RightMidthick, RightWhite, R_ROI);

    %adjustment for smoothing changing the mean PT value
    [~, sortperm] = sort(SPseudoTransmit.cdata, 'descend');
    fixindex = sortperm(round(fracOver * length(SPseudoTransmit.cdata))); %this is the index into the sorted data that used to be equal to 1, make it equal 1 again
    correctionfac = 1 / SPseudoTransmit.cdata(fixindex);
    SPseudoTransmit.cdata = correctionfac .* SPseudoTransmit.cdata;

    leftSPseudoTransmit = cifti_struct_dense_extract_surface_data(SPseudoTransmit, 'CORTEX_LEFT');
    rightSPseudoTransmit = cifti_struct_dense_extract_surface_data(SPseudoTransmit, 'CORTEX_RIGHT');

    %type "T" part of original code
    SPseudoTransmit = SPseudoTransmit.cdata;
    
    [slope intercept] = findFlipCorrectionSlopeGroup(SMyelinMaps, SPseudoTransmit, Template);

    corrmyelin = SMyelinMaps ./ (SPseudoTransmit * slope + intercept);

    TemplateReference = median(Template(round(SPseudoTransmit, 1) == 1));
    SubjectReference = median(corrmyelin(round(SPseudoTransmit, 1) == 1));
    Ratio = SubjectReference ./ TemplateReference;
    cost = sum(abs((mean(corrmyelin ./ Ratio, 2) - Template) ./ Template));

end

%borrow some workarounds for matlab's dumb API from cifti-matlab private
%could put these into pipelines global
function stdout = mysystem(command)
    %like call_fsl, but without sourcing fslconf
    if ismac()
        ldsave = getenv('DYLD_LIBRARY_PATH');
        %this is just a guess at what matlab does on mac, based on using LD_PRELOAD on linux
        presave = getenv('DYLD_INSERT_LIBRARIES');
        macflatsave = getenv('DYLD_FORCE_FLAT_NAMESPACE');
    else
        ldsave = getenv('LD_LIBRARY_PATH');
        presave = getenv('LD_PRELOAD');
        macflatsave = '';
    end
    %restore it even if we are interrupted
    function cleanupFunc(ldsave, presave, macflatsave)
        if ismac()
            setenv('DYLD_LIBRARY_PATH', ldsave);
            setenv('DYLD_INSERT_LIBRARIES', presave);
            setenv('DYLD_FORCE_FLAT_NAMESPACE', macflatsave);
        else
            setenv('LD_LIBRARY_PATH', ldsave);
            setenv('LD_PRELOAD', presave);
        end
    end
    guardObj = onCleanup(@() cleanupFunc(ldsave, presave, macflatsave));
    if ismac()
        setenv('DYLD_LIBRARY_PATH');
        setenv('DYLD_INSERT_LIBRARIES');
        setenv('DYLD_FORCE_FLAT_NAMESPACE');
    else
        setenv('LD_LIBRARY_PATH');
        setenv('LD_PRELOAD');
    end
    if nargout > 0
        [status, stdout] = system(command);
    else
        status = system(command);
    end
    if status ~= 0
        error(['command failed: "' command '"']);
    end
end

function mydelete(varargin)
    %fix matlab's "error if doesn't exist" and braindead "send to recycling based on preference" misfeatures
    recstatus = recycle();
    cleanupObj = onCleanup(@()(recycle(recstatus)));
    recycle('off');
    for i = 1:nargin
        if exist(varargin{i}, 'file')
            delete(varargin{i});
        end
    end
end

