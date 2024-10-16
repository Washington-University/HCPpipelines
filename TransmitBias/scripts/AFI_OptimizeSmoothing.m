function AFI_OptimizeSmoothing(MyelinInput, AFIVolume, TRone, TRtwo, TargFlipAngle, LeftPial, LeftMidthick, LeftWhite, RightPial, RightMidthick, RightWhite, SmoothLower, SmoothUpper, LeftVolROI, RightVolROI, GroupCorrected, Output)
    
    %take all numbers as strings, for unified compiled/interpreted handling
    TRone = str2double(TRone);
    TRtwo = str2double(TRtwo);
    TargFlipAngle = str2double(TargFlipAngle);
    SmoothLower = str2double(SmoothLower);
    SmoothUpper = str2double(SmoothUpper);
    
    MyelinMaps = cifti_read(MyelinInput);
    leftdata = cifti_struct_dense_extract_surface_data(MyelinMaps, 'CORTEX_LEFT');
    rightdata = cifti_struct_dense_extract_surface_data(MyelinMaps, 'CORTEX_RIGHT');
    TemplateCifti = cifti_read(GroupCorrected);

    aficifti = mapvoltosurf(AFIVolume, MyelinInput, LeftPial, LeftMidthick, LeftWhite, RightPial, RightMidthick, RightWhite, LeftVolROI, RightVolROI);
    
    AFI = 180 / pi() * acos((TRtwo / TRone * aficifti.cdata(:, 2) ./ aficifti.cdata(:, 1) - 1) / (TRtwo / TRone - aficifti.cdata(:, 2) ./ aficifti.cdata(:, 1)));
    fracOver = sum(AFI(:) > TargFlipAngle) / prod(size(AFI)); %store how many are beyond the ideal threshold
    %unlike PT, we don't expect dropout issues
    clear AFI;

    %golden section search for smoothing level with the best correction result
    lowguess = SmoothLower;
    highguess = SmoothUpper;
    searchratio = 1 - 2 / (sqrt(5) + 1); % 1 - inverse of golden ratio
    currange = highguess - lowguess;
    points = [lowguess, lowguess + searchratio * currange, highguess - searchratio * currange, highguess];
    results = mycost(points, MyelinInput, AFIVolume, TRone, TRtwo, TargFlipAngle, LeftPial, LeftMidthick, LeftWhite, RightPial, RightMidthick, RightWhite, LeftVolROI, RightVolROI, TemplateCifti.cdata, MyelinMaps.cdata, leftdata, rightdata, fracOver);
    precision = 0.01;
    while points(4) - points(1) > precision
        if results(2).cost < results(3).cost
            points(3:4) = points(2:3); results(3:4) = results(2:3);
            currange = points(4) - points(1);
            points(2) = points(1) + searchratio * currange;
            results(2) = mycost(points(2), MyelinInput, AFIVolume, TRone, TRtwo, TargFlipAngle, LeftPial, LeftMidthick, LeftWhite, RightPial, RightMidthick, RightWhite, LeftVolROI, RightVolROI, TemplateCifti.cdata, MyelinMaps.cdata, leftdata, rightdata, fracOver);
        else
            points(1:2) = points(2:3); results(1:2) = results(2:3);
            currange = points(4) - points(1);
            points(3) = points(4) - searchratio * currange;
            results(3) = mycost(points(3), MyelinInput, AFIVolume, TRone, TRtwo, TargFlipAngle, LeftPial, LeftMidthick, LeftWhite, RightPial, RightMidthick, RightWhite, LeftVolROI, RightVolROI, TemplateCifti.cdata, MyelinMaps.cdata, leftdata, rightdata, fracOver);
        end
    end
    %pick the best of the final midpoints
    if results(2).cost < results(3).cost
        smooth = points(2);
        bestresult = results(2);
    else
        smooth = points(3);
        bestresult = results(3);
    end
    
    Flag = 1; %probably unused
    dlmwrite(Output, [smooth bestresult.correctionfac bestresult.slope bestresult.cost Flag], ',');
end

function ciftiout = mapvoltosurf(volname, ciftitemplatename, LeftPial, LeftMidthick, LeftWhite, RightPial, RightMidthick, RightWhite, LeftVolROI, RightVolROI)
    mytemp = tempname();
    cleanupObj = onCleanup(@()(mydelete([mytemp '.L.func.gii'], [mytemp '.R.func.gii'], [mytemp '.dscalar.nii'], [mytemp '_2.dscalar.nii'])));
    
    mysystem(['wb_command -volume-to-surface-mapping ' volname ' ' LeftMidthick ' ' mytemp '.L.func.gii -ribbon-constrained ' LeftWhite ' ' LeftPial ' -volume-roi ' LeftVolROI]);
    mysystem(['wb_command -volume-to-surface-mapping ' volname ' ' RightMidthick ' ' mytemp '.R.func.gii -ribbon-constrained ' RightWhite ' ' RightPial ' -volume-roi ' RightVolROI]);
    mysystem(['wb_command -cifti-create-dense-from-template ' ciftitemplatename ' ' mytemp '.dscalar.nii -metric CORTEX_LEFT ' mytemp '.L.func.gii -metric CORTEX_RIGHT ' mytemp '.R.func.gii']);
    mysystem(['wb_command -cifti-dilate ' mytemp '.dscalar.nii COLUMN 10 10 ' mytemp '_2.dscalar.nii -left-surface ' LeftMidthick ' -right-surface ' RightMidthick]);
    
    ciftiout = cifti_read([mytemp '_2.dscalar.nii']);
end

function retstr = mycost(pointsin, MyelinInput, AFIVolume, TRone, TRtwo, TargFlipAngle, LeftPial, LeftMidthick, LeftWhite, RightPial, RightMidthick, RightWhite, LeftVolROI, RightVolROI, Template, MyelinMaps, leftdata, rightdata, fracOver)
    mytemp = tempname;
    cleanupObj = onCleanup(@()(mydelete([mytemp '.Lsmooth.nii.gz'], [mytemp '.Rsmooth.nii.gz'], [mytemp '.nii.gz'])));
    retstr = struct('cost', cell(1, length(pointsin)), 'correctionfac', cell(1, length(pointsin)), 'slope', cell(1, length(pointsin)));
    for index = 1:length(pointsin)
        smooth = pointsin(index);
        
        %Smooth data within ROIs - ignore hindbrain ROI, we are only testing cortical asymmetry
        mysystem(['wb_command -volume-smoothing ' AFIVolume ' ' num2str(smooth) ' ' mytemp '.Lsmooth.nii.gz -fwhm -roi ' LeftVolROI ' -fix-zeros']);
        mysystem(['wb_command -volume-smoothing ' AFIVolume ' ' num2str(smooth) ' ' mytemp '.Rsmooth.nii.gz -fwhm -roi ' RightVolROI ' -fix-zeros']);
        mysystem(['wb_command -volume-math "LEFT + RIGHT" ' mytemp '.nii.gz -var LEFT ' mytemp '.Lsmooth.nii.gz -var RIGHT ' mytemp '.Rsmooth.nii.gz']);
        
        smoothmaps = mapvoltosurf([mytemp '.nii.gz'], MyelinInput, LeftPial, LeftMidthick, LeftWhite, RightPial, RightMidthick, RightWhite, LeftVolROI, RightVolROI);
        
        SAFI = 180 / pi() * acos((TRtwo / TRone .* smoothmaps.cdata(:, 2) ./ smoothmaps.cdata(:, 1) - 1) ./ (TRtwo / TRone - smoothmaps.cdata(:, 2) ./ smoothmaps.cdata(:, 1)));
        SAFI = SAFI ./ TargFlipAngle;
        
        %adjustment for smoothing changing the mean AFI value - modify the original maps and recompute
        %AFI is a function of the ratio of the two maps, so we can fix it by modifying just the numerator (second map)
        [~, sortperm] = sort(SAFI, 'descend');
        fixindex = sortperm(round(fracOver * length(SAFI))); %make this index work out to be the target flip angle
        TRratio = TRtwo / TRone;
        desiredratio = (1 + TRratio * cos(TargFlipAngle * pi() / 180)) / (TRratio + cos(TargFlipAngle * pi() / 180)); %compute desired ratio for given flip angle and TRs
        retstr(index).correctionfac = desiredratio / (smoothmaps.cdata(fixindex, 2) ./ (smoothmaps.cdata(fixindex, 1))); %scaling factor (scalar)
        
        %fix scaling by modifying the second map
        smoothmaps.cdata(:, 2) = retstr(index).correctionfac .* smoothmaps.cdata(:, 2);
        
        %redo flip angle computation
        SAFI = 180 / pi() * acos((TRtwo / TRone .* smoothmaps.cdata(:, 2) ./ smoothmaps.cdata(:, 1) - 1) ./ (TRtwo / TRone - smoothmaps.cdata(:, 2) ./ smoothmaps.cdata(:, 1)));
        SAFI = SAFI ./ TargFlipAngle;
        
        [retstr(index).slope intercept] = findFlipCorrectionSlopeGroup(MyelinMaps, SAFI, Template);

        corrmyelin = MyelinMaps ./ (SAFI .* retstr(index).slope + intercept);

        TemplateReference = median(Template(round(SAFI, 1) == 1));
        SubjectReference = median(corrmyelin(round(SAFI, 1) == 1));
        Ratio = SubjectReference ./ TemplateReference;
        retstr(index).cost = sum(abs((mean(corrmyelin ./ Ratio, 2) - Template) ./ Template));
    end
end

%borrow some workarounds for matlab's dumb API from cifti-matlab private
%could put these into pipelines global
function mysystem(command)
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

