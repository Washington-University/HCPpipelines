function RSNregression(InputFile, InputVNFile, Method, ParamsFile, OutputBeta, varargin)
    optional = myargparse(varargin, {'GroupMaps' 'tICAMM' 'VAWeightsName' 'VolInputFile' 'VolInputVNFile' 'VolCiftiTemplate' 'OldBias' 'OldVolBias' 'GoodBCFile' 'VolGoodBCFile' 'SpectraParams' 'OutputZ' 'OutputVolBeta' 'OutputVolZ' 'SurfString' 'ScaleFactor' 'WRSmoothingSigma' 'WF'});
    
    %InputFile - text file containing filenames of timeseries to concatenate
    %InputVNFile - text file containing filenames of the variance maps of each input
    %GroupMaps - file name of maps to use as a template
    %Method - string, 'weighted' or 'dual'
    %ParamsFile - text file containing parameters for the selected method - for weighted, it contains the filenames to low-dimensionality files to estimate the alignment quality with
    %VAWeightsName - filename of spatial weights to use (usually vertex areas normalized to mean 1, and 1s in all voxels)
    %OutputBeta - filename for output beta maps
    %
    %optional - specify like (..., 'WRSmoothingSigma', '5'):
    %VolInputFile - like InputFile, but volume data (.nii.gz)
    %VolInputVNFile - like InputVNFile, but volume data
    %VolCiftiTemplate - cifti dscalar file with a spatial mapping that includes all voxels to consider in the volume data
    %OldBias - for correcting old bias field method, give the old bias field name
    %OldVolBias - same as OldBias, but volume data
    %GoodBCFile - for correcting old bias field method, text file containing the new bias field for each input
    %VolGoodBCFile - same as GoodBCFile, but volume data
    %SpectraParams - string, <num>@<tsfile>@<spectrafile> - number of samples, and output filenames for spectra analysis
    %OutputZ - filename for output of (approximate) Z stat maps
    %OutputVolBeta - same as OutputBeta, but volume data
    %OutputVolZ - same as OutputZ, but volume data
    %SurfString - string, <leftsurf>@<rightsurf>, surfaces to use in weighted method for smoothing the alignment quality map
    %ScaleFactor - string representation of a number, multiply the input data by this factor before processing (to convert grand mean 10,000 data to % bold, use 0.01)
    %WRSmoothingSigma - string representation of a number, when using 'weighted' method, smooth the alignment quality map with this sigma (default 14, tuned for human data)
    %WF - number of Wishart Distributions for Wishart Filtering, set to zero to turn off (default)
    
    %if isdeployed()
        %all arguments are strings
    %end
    
    wbcommand = 'wb_command';
    ScaleFactor = 1;
    WF = 0;
    
    if ~strcmp(optional.WF, '')
        WF = str2double(optional.WF);
    end    
    
    if ~strcmp(optional.ScaleFactor, '')
        ScaleFactor = str2double(optional.ScaleFactor);
    end
    inputArray = myreadtext(InputFile);
    inputVNArray = myreadtext(InputVNFile);
    if size(inputArray, 1) ~= size(inputVNArray, 1)
        error('InputVNFile has different number of lines than InputFile');
    end
    doFixBC = false;
    if ~strcmp(optional.OldBias, '')
        doFixBC = true;
        goodBCArray = myreadtext(optional.GoodBCFile);
        if size(goodBCArray, 1) ~= size(inputArray, 1)
            error('GoodBCFile has different number of lines than InputFile');
        end
        oldBC = ciftiopen(optional.OldBias, wbcommand);
    end

    %tighten doVol detection to check if volume outputs are asked for?
    doVol = false;
    doVolFixBC = false;
    if ~strcmp(optional.VolCiftiTemplate, '')
        doVol = true;
        outVolTemplate = ciftiopen(optional.VolCiftiTemplate, wbcommand);
        outVolTemplate.cdata = [];
        if ~strcmp(optional.VolInputFile, '')
            volinputArray = myreadtext(optional.VolInputFile);
            volinputVNArray = myreadtext(optional.VolInputVNFile);
            if size(volinputArray, 1) ~= size(inputArray, 1)
                error('VolInputFile is not empty, but has different number of lines than InputFile');
            end
            if size(volinputArray, 1) ~= size(volinputVNArray, 1)
                error('VolInputVNFile has different number of lines than VolInputFile');
            end
            if ~strcmp(optional.OldVolBias, '')
                doVolFixBC = true;
                volGoodBCArray = myreadtext(optional.VolGoodBCFile);
                if size(volGoodBCArray, 1) ~= size(inputArray, 1)
                    error('VolGoodBCFile is not empty, different number of lines than InputFile');
                end
                %use /tmp to convert volume files to voxel cifti
                oldVolBC = open_vol_as_cifti(optional.OldVolBias, optional.VolCiftiTemplate, wbcommand);
            end
        end
    end
    
    %input parsing done, sanity checks go here
    if doVol && doFixBC ~= doVolFixBC
        if (doFixBC)
            warning('volume data is being processed, but old bias fixing mode was only requested for the cifti data');
        else
            warning('volume data is being processed, but old bias fixing mode was only requested for the volume data');
        end
    end
    
    %provide complete filenames in input lists
    for i = 1:size(inputArray, 1)
        tempcii = ciftiopen([inputArray{i}], wbcommand);
        tempvncii = ciftiopen([inputVNArray{i}], wbcommand);
        % can't use good BC to do the mean of VN properly, because it may not exist
        tempvncii.cdata = max(tempvncii.cdata / mean(tempvncii.cdata), 0.001);
        %VN file is really just variance of BC data - to restore to close to original variance, turn the variance back into non-bc space and take the mean
        tempnorm = ScaleFactor * demean(tempcii.cdata, 2) ./ repmat(tempvncii.cdata, 1, size(tempcii.cdata, 2));
        tempcii.cdata = [];
        % for output, make the vn data reference new BC space
        if doFixBC
            tempBCcifti = ciftiopen(goodBCArray{i}, wbcommand);
            tempvncii.cdata = tempvncii.cdata .* oldBC.cdata ./ tempBCcifti.cdata;
        end
        if i == 1
            outTemplate = tempcii;
            inputConcat = tempnorm;
            vnsum = tempvncii.cdata;
        else
            inputConcat = [inputConcat tempnorm]; %#ok<AGROW>
            vnsum = vnsum + tempvncii.cdata; % should this use weighted and/or geometric mean?  are there zeros?
        end
        clear tempcii tempnorm tempvncii tempBCcifti;
        if doVol
            tempvolcii = open_vol_as_cifti(volinputArray{i}, optional.VolCiftiTemplate, wbcommand);
            tempvolvncii = open_vol_as_cifti(volinputVNArray{i}, optional.VolCiftiTemplate, wbcommand);
            tempvolmask = std(tempvolcii.cdata, [], 2) ~= 0;
            tempvolvncii.cdata = max(tempvolvncii.cdata / mean(tempvolvncii.cdata(tempvolmask)), 0.001);
            tempvolnorm = ScaleFactor * demean(tempvolcii.cdata, 2) ./ repmat(tempvolvncii.cdata, 1, size(tempvolcii.cdata, 2));
            clear tempvolcii;
            if doVolFixBC
                tempvolBCcifti = open_vol_as_cifti(volGoodBCArray{i}, optional.VolCiftiTemplate, wbcommand);
                tempvolvncii.cdata = tempvolvncii.cdata .* oldVolBC.cdata ./ tempvolBCcifti.cdata;
            end
            if i == 1
                volInputConcat = tempvolnorm;
                vnvolsum = tempvolvncii.cdata;
            else
                volInputConcat = [volInputConcat tempvolnorm]; %#ok<AGROW>
                vnvolsum = vnvolsum + tempvolvncii.cdata;
            end
            clear tempvolnorm tempvolvncii tempvolBCcifti;
        end
    end
    
    vnmean = vnsum / size(inputArray, 1);
    clear vnsum;
    if doVol
        vnvolmean = vnvolsum / size(inputArray, 1);
        clear vnvolsum;
    end
    
    if strcmp(Method,'weighted') || strcmp(Method,'dual') || strcmp(Method,'tICA_weighted') 
        GroupMapcii = ciftiopen(optional.GroupMaps, wbcommand);
        weightscii = ciftiopen(optional.VAWeightsName, wbcommand); %normalized vertex areas, voxels are all 1s
        AreaWeights = weightscii.cdata;
    end
    switch Method
        case {'weighted', 'tICA_weighted'}
            if strcmp(optional.WRSmoothingSigma, '')
                error '"weighted" method requires WRSmoothingSigma to be specified'
            end
            WRSmoothingSigma = str2double(optional.WRSmoothingSigma);
            paramsArray = myreadtext(ParamsFile);
            if length(paramsArray) == 0
                error('"weighted" method needs at least one low dimensionality file to estimate weighting, use method "dual" to do only vertex area weighted regression');
            end
            surfArray = textscan(optional.SurfString, '%s', 'Delimiter', {'@'}); %left right
            surfArray = surfArray{1};
            for i = 1:length(paramsArray)
                LowDim = paramsArray{i};
                LowDim = ciftiopen(LowDim, wbcommand);
                %betaICAone = weightedDualRegression(LowDim.cdata, inputConcat, AreaWeights); 
                %betaICA = weightedDualRegression(betaICAone, inputConcat, AreaWeights); 
                betaICAone = weightedDualRegression(LowDim.cdata, inputConcat, AreaWeights, 0); %Always use WF=0
                betaICA = weightedDualRegression(betaICAone, inputConcat, AreaWeights, 0); %Always use WF=0
                for j = 1:length(betaICA)
                    var(j) = atanh(corr(betaICA(j, :)', LowDim.cdata(j, :)')); %#ok<AGROW>
                end
                corrs(:, i) = var'; %#ok<AGROW>
            end
            outTemplate.cdata = mean(corrs, 2);
            mytempfile = [tempname() '_tosmooth.dscalar.nii'];
            ciftisavereset(outTemplate, mytempfile, wbcommand);
            my_system([wbcommand ' -cifti-smoothing ' mytempfile ' ' num2str(WRSmoothingSigma) ' ' num2str(WRSmoothingSigma) ' COLUMN ' mytempfile ' -left-surface ' surfArray{1} ' -right-surface ' surfArray{2}]);
            AlignmentQualitySmoothcii = ciftiopen(mytempfile, wbcommand);
            delete(mytempfile);
            MEAN = mean(outTemplate.cdata);
            AlignmentQuality = repmat(MEAN, length(outTemplate.cdata), 1) + outTemplate.cdata - AlignmentQualitySmoothcii.cdata;
            ScaledAlignmentQuality = (AlignmentQuality .* (AlignmentQuality > 0)) .^ 3;
            
            %betaICAone = weightedDualRegression(GroupMapcii.cdata, inputConcat, AreaWeights .* ScaledAlignmentQuality);
            %[betaICA, NODEts] = weightedDualRegression(normalise(betaICAone), inputConcat, AreaWeights);
            betaICAone = weightedDualRegression(GroupMapcii.cdata, inputConcat, AreaWeights .* ScaledAlignmentQuality, 0); %Always use WF=0
            [betaICA, NODEts, inputConcat, DOF] = weightedDualRegression(normalise(betaICAone), inputConcat, AreaWeights, WF); %WF if requested only for the last spatial regression to avoid error propogation
            
            if strcmp(Method, "tICA_weighted") % based on tICA/scripts/ComputeGroupTICA.m but for one subject as a group
                NODEts=NODEts';
                thisStart = 1;
                TCSRunVarSub = [];
                for i = 1:size(inputArray, 1)
                    dtseriesName=[inputArray{i}];
                    if exist(dtseriesName, 'file')
                        runLengthStr = my_system(['wb_command -file-information -only-number-of-maps ' dtseriesName]);
                        disp(['runLengthStr ' runLengthStr])
                        runLength = str2double(runLengthStr);
                        nextStart = thisStart + runLength;
                        TCSRunVarSub = [TCSRunVarSub repmat(std(NODEts(:, thisStart:(nextStart - 1)), [], 2), 1, runLength)];
    
                        thisStart = nextStart;
                    end
                end
                
                sICAtcsvars = std(NODEts, [], 2);
                NODEts = (NODEts ./ TCSRunVarSub) .* repmat(sICAtcsvars, 1, size(TCSRunVarSub, 2)); %Making all runs contribute equally improves tICA decompositions
                NODEts(~isfinite(NODEts)) = 0;

                A = load(optional.tICAMM);

                if size(A,1) ~= size(NODEts,1)
                    error('Mixing matrix to be used does not match dimensions of the sICA components');
                end
                
                % unmix the sICA timeseries
                W = pinv(A);
                normicasig = W * NODEts;
                
                % normicasig has stdev = 1 (more or less), just like the fastica/icasso output, we want to multiply the (approximate) amplitudes from A into it
                % but, we also want to pretend that the input to tICA was normalized, so:
                % tICAinput = A * normicasig
                % pretendtICAinput = diag(1 / std(tICAinput)) * A * normicasig
                % ...assume normicasig doesn't change...
                % pretendA = diag(1 / std(tICAinput)) * A = A ./ repmat(std(tICAinput), ...)
                % then use std() to extract the approximate amplitudes from pretendA...sqrt(mean(x .^ 2)) might be better, but this was how we did it in tICA, so...
                icasig = normicasig .* repmat(std(A ./ repmat(sICAtcsvars, 1, size(A, 2)))', 1, size(NODEts, 2)); %Un-normalize the icasig assuming sICAtcs with std = 1 (approximately undo the original variance normalization)

                tICAtcs = single(icasig);
                % single regression
                NODEts = tICAtcs';
                %betaICA = ((pinv(normalise(NODEts)) * demean(inputConcat')))';
                [betaICA, inputConcat, DOF] = temporalRegression(inputConcat,NODEts,WF);
            end
        case 'dual'
            %[betaICA, NODEts] = weightedDualRegression(GroupMapcii.cdata, inputConcat, AreaWeights);
            [betaICA, NODEts, inputConcat, DOF] = weightedDualRegression(GroupMapcii.cdata, inputConcat, AreaWeights, WF);
        case 'single'
            SpectraArray = textscan(optional.SpectraParams, '%s', 'Delimiter', {'@'});
            InputSpectraTS = SpectraArray{1}{1};
            NODEts=ciftiopen(InputSpectraTS, wbcommand);
            NODEts=NODEts.cdata';
            %betaICA = ((pinv(normalise(NODEts)) * demean(inputConcat')))';
            [betaICA, inputConcat, DOF] = temporalRegression(inputConcat,NODEts,WF);
        otherwise
            error(['unrecognized method: "' Method '", use "weighted", "tICA_weighted", "dual", or "single"']);
    end
    
    NODEtsnorm = normalise(NODEts);
    
    %outputs
    %Save Timeseries and Spectra if Desired
    if ~strcmp(optional.SpectraParams, '') && ~strcmp(Method,'single') && ~strcmp(Method,'tICA_weighted')
        SpectraArray = textscan(optional.SpectraParams, '%s', 'Delimiter', {'@'});
        nTPsForSpectra = min(str2double(SpectraArray{1}{1}), size(NODEts, 1));
        OutputSpectraTS = SpectraArray{1}{2};
        OutputSpectraFile = SpectraArray{1}{3};
        if nTPsForSpectra > 0 && ~strcmp(OutputSpectraTS, '') && ~strcmp(OutputSpectraFile, '')
           ts.Nnodes = size(NODEts, 2);
           ts.Nsubjects = size(NODEts, 1) ./ nTPsForSpectra;
           ts.ts = NODEts;
           ts.NtimepointsPerSubject = nTPsForSpectra;
           [ts_spectra] = nets_spectra_sp(ts);
           dlmwrite(OutputSpectraTS, NODEts, 'delimiter', '\t');
           dlmwrite(OutputSpectraFile, ts_spectra, 'delimiter', '\t');
        end
    end
    %make sure we don't use the non-normalized timeseries anywhere else
    clear NODEts;
    if ~strcmp(OutputBeta, '')
        %multiply by average vn to get back to BC data
        outTemplate.cdata = betaICA .* repmat(vnmean, 1, size(betaICA, 2));
        ciftisavereset(outTemplate, OutputBeta, wbcommand);
    end
    %Normalize to input maps - optional, for msmall only (move to msmall script)
    %if ~strcmp(OutputNorm, '')
    %    TODO: isolate only the surface data ("Distortion" input is now 91k)
    %    GMmean = mean(GMorig(1:length(Distortion.cdata), :));
    %    GMstd = std(GMorig(1:length(Distortion.cdata), :));
    %    betaICAmean = mean(betaICA(1:length(Distortion.cdata), :));
    %    betaICAstd = std(betaICA(1:length(Distortion.cdata), :));
    %    OUTBO.cdata = ((((betaICA - repmat(betaICAmean, length(betaICA), 1)) ./ repmat(betaICAstd, length(betaICA), 1)) .* repmat(GMstd, length(betaICA), 1)) + repmat(GMmean, length(betaICA), 1));
    %    ciftisavereset(OUTBO, OutputNorm, wbcommand);
    %end
    %Z stat
    if ~strcmp(optional.OutputZ, '')
        %Convert to Z stat image
        if WF>0
            dof = DOF - size(NODEtsnorm, 2) - 1; %Approximate compensation for Wishart Filtering--Mixture modelling is more correct, but more complicated
        else
            dof = size(NODEtsnorm, 1) - size(NODEtsnorm, 2) - 1; %Approximate, does not include DOF lost from data cleanup
        end
        residuals = demean(inputConcat, 2) - betaICA * NODEtsnorm';
        pN = pinv(NODEtsnorm); dpN = diag(pN * pN')';
        t = double(betaICA ./ sqrt(sum(residuals .^ 2, 2) * dpN / dof));
        Z = zeros(size(t));
        Z(t > 0) = min(-norminv(tcdf(-t(t > 0), dof)), 38.5);
        Z(t < 0) = max(norminv(tcdf(t(t < 0), dof)), -38.5);
        Z(isnan(Z)) = 0;
        outTemplate.cdata = Z;
        ciftisavereset(outTemplate, optional.OutputZ, wbcommand);
    end
    
    %volume outputs
    if doVol
        %VolbetaICA = ((pinv(NODEtsnorm) * demean(volInputConcat')))';
        if WF == 0
          volWF=0;
        elseif WF == 1
          volWF=1
        elseif WF>1
          volWF=1; %Reduce volWF to 1
        end
        [VolbetaICA, volInputConcat, DOF] = temporalRegression(volInputConcat,NODEtsnorm,volWF); 
        if ~strcmp(optional.OutputVolBeta, '')
            %multiply by vn to get back to BC
            outVolTemplate.cdata = VolbetaICA .* repmat(vnvolmean, 1, size(VolbetaICA, 2));
            ciftisavereset(outVolTemplate, optional.OutputVolBeta, wbcommand);
        end
        if ~strcmp(optional.OutputVolZ, '')
            if WF>0
                dof = DOF - size(NODEtsnorm, 2) - 1; %Approximate compensation for Wishart Filtering--Mixture modelling is more correct, but more complicated
            else
                dof = size(NODEtsnorm, 1) - size(NODEtsnorm, 2) - 1; %Approximate, does not include DOF lost from data cleanup
            end
            residuals = demean(volInputConcat, 2) - VolbetaICA * NODEtsnorm';
            t = double(VolbetaICA ./ sqrt(sum(residuals .^ 2, 2) * dpN / dof));
            Z = zeros(size(t));
            Z(t > 0) = min(-norminv(tcdf(-t(t > 0), dof)), 38.5);
            Z(t < 0) = max(norminv(tcdf(t(t < 0), dof)), -38.5);
            Z(isnan(Z)) = 0;
            outVolTemplate.cdata = Z;
            ciftisavereset(outVolTemplate, optional.OutputVolZ, wbcommand);
        end
    end
end

function outstruct = myargparse(myvarargs, allowed)
    for i = 1:length(allowed)
        outstruct.(allowed{i}) = '';
    end
    for i = 1:2:length(myvarargs)
        if isfield(outstruct, myvarargs{i})
            outstruct.(myvarargs{i}) = myvarargs{i + 1};
        else
            error(['unknown optional parameter specified: "' myvarargs{i} '"']);
        end
    end
end

function lines = myreadtext(filename)
    fid = fopen(filename);
    if fid < 0
        error(['unable to open file ' filename]);
    end
    array = textscan(fid, '%s', 'Delimiter', {'\n'});
    fclose(fid);
    lines = array{1};
end

%function [betaMaps, mapTimeseries] = weightedDualRegression(SpatialMaps, Timeseries, Weights)
function [betaMaps, mapTimeseries, OutDenseTimeseries, DOF] = weightedDualRegression(SpatialMaps, Timeseries, Weights,WF)
    DesignWeights = repmat(sqrt(Weights), 1, size(SpatialMaps, 2));
    DenseWeights = repmat(sqrt(Weights), 1, size(Timeseries, 2));
    mapTimeseries = demean((pinv(demean(SpatialMaps .* DesignWeights)) * (demean(Timeseries .* DenseWeights)))');
    %betaMaps = ((pinv(normalise(mapTimeseries)) * demean(Timeseries')))';
    [betaMaps, OutDenseTimeseries, DOF] = temporalRegression(Timeseries,mapTimeseries,WF);
end

function [betaMaps, OutDenseTimeseries, DOF] = temporalRegression(DenseTimeseries,DesignTimeseries,WF)
    if WF>0
        Out=icaDim(DenseTimeseries,0,1,-1,WF); %demean only
        OutDenseTimeseries=Out.data;
        DOF=Out.NewDOF;
    else
        OutDenseTimeseries=DenseTimeseries;
        DOF=0; %This is junk so we can always set this output variable sometimes
    end
    betaMaps = ((pinv(normalise(DesignTimeseries)) * demean(OutDenseTimeseries')))';
end

function outstruct = open_vol_as_cifti(volName, ciftiTemplate, wbcommand)
    tempbase = tempname();
    %don't leave a temporary file around on error/interrupt
    function cleanupFunc(tempbase)
        system(['rm -f -- "' tempbase '.dscalar.nii"']);
    end
    guardObj = onCleanup(@() cleanupFunc(tempbase));
    my_system([wbcommand ' -cifti-create-dense-from-template "' ciftiTemplate '" "' tempbase '.dscalar.nii" -volume-all ' volName]);
    outstruct = ciftiopen([tempbase '.dscalar.nii'], wbcommand);
end

%like call_fsl, but without sourcing fslconf
function stdout=my_system(command)
    if ismac()
        ldsave = getenv('DYLD_LIBRARY_PATH');
    else
        ldsave = getenv('LD_LIBRARY_PATH');
    end
    %restore it even if we are interrupted
    function cleanupFunc(ldsave)
        if ismac()
            setenv('DYLD_LIBRARY_PATH', ldsave);
        else
            setenv('LD_LIBRARY_PATH', ldsave);
        end
    end
    guardObj = onCleanup(@() cleanupFunc(ldsave));
    if ismac()
        setenv('DYLD_LIBRARY_PATH');
    else
        setenv('LD_LIBRARY_PATH');
    end

    [exitStatus, stdout] = system(command);

    if exitStatus ~= 0
        error(['command failed: ' command]);
    end
end

