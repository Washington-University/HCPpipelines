function tICACleanData(InputFile, InputVNFile, OutputNamesFile, OutputVNNamesFile, Timeseries, NoiseList, varargin)
    optional = myargparse(varargin, {'VolInputFile' 'VolInputVNFile' 'VolCiftiTemplate' 'OldBias' 'OldVolBias' 'GoodBCFile' 'VolGoodBCFile' 'OutputVolNamesFile', 'OutputVolVNNamesFile'});
    
    %InputFile - text file containing filenames of timeseries to concatenate
    %InputVNFile - text file containing filenames of the variance maps of each input
    %Timeseries - sdseries file containing the temporal ICA component timecourses
    %NoiseList - text file containig the list of temporal ICA components to remove
    %OutputNamesFile - text file containing output filenames for cleaned runs
    %VolInputFile - like InputFile, but volume data (.nii.gz)
    %VolInputVNFile - like InputVNFile, but volume data
    %VolCiftiTemplate - cifti dscalar file with a spatial mapping that includes all voxels to consider in the volume data
    %OldBias - for correcting old bias field method, give the old bias field name
    %OldVolBias - same as OldBias, but volume data
    %GoodBCFile - for correcting old bias field method, text file containing the new bias field for each input
    %VolGoodBCFile - same as GoodBCFile, but volume data
    %OutputVolNamesFile - text file containing output nifti filenames for cleaned volume runs
    
    %if isdeployed()
        %all arguments are strings
    %end
    
    wbcommand = 'wb_command';
    inputArray = myreadtext(InputFile);
    inputVNArray = myreadtext(InputVNFile);
    if size(inputArray, 1) ~= size(inputVNArray, 1)
        error('InputVNFile has different number of lines than InputFile');
    end
    outputNamesArray = myreadtext(OutputNamesFile);
    if size(inputArray, 1) ~= size(outputNamesArray, 1)
        error('OutputNamesFile has different number of lines than InputFile');
    end
    outputVNNamesArray = myreadtext(OutputVNNamesFile);
    if size(inputArray, 1) ~= size(outputVNNamesArray, 1)
        error('OutputVNNamesFile has different number of lines than InputFile');
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
    OutputVolNamesArray = {};
    %detect only some of the volume arguments being specified and error?
    if ~strcmp(optional.VolCiftiTemplate, '') && ~strcmp(optional.OutputVolNamesFile, '') && ~strcmp(optional.OutputVolVNNamesFile, '')
        doVol = true;
        OutputVolNamesArray = myreadtext(optional.OutputVolNamesFile);
        if size(inputArray, 1) ~= size(OutputVolNamesArray, 1)
            error('OutputVolNamesFile has different number of lines than InputFile');
        end
        OutputVolVNNamesArray = myreadtext(optional.OutputVolVNNamesFile);
        if size(inputArray, 1) ~= size(OutputVolVNNamesArray, 1)
            error('OutputVolVNNamesFile has different number of lines than InputFile');
        end
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
    
    runStarts = ones(1, size(inputArray, 1) + 1); %extra element on the end to make separating code simpler
    
    SaveRunVN = []; %since we save these, we don't need to calculate the mean separately on the fly
    SaveRunVolVN = [];
    %provide complete filenames in input lists
    for i = 1:size(inputArray, 1)
        tempcii = ciftiopen([inputArray{i}], wbcommand);
        runStarts(i + 1) = runStarts(i) + size(tempcii.cdata, 2);
        tempvncii = ciftiopen([inputVNArray{i}], wbcommand);
        % can't use good BC to do the mean of VN properly, because it may not exist
        tempvncii.cdata = max(tempvncii.cdata, 0.001); 
        %VN file is really just stdev of BC data - to restore to close to original stdev, turn the stdev back into non-bc space and take the mean
        tempnorm = demean(tempcii.cdata, 2) ./ repmat(tempvncii.cdata, 1, size(tempcii.cdata, 2));
        tempcii.cdata = [];
        % for output, make the vn data reference new BC space
        if doFixBC
            tempBCcifti = ciftiopen(goodBCArray{i}, wbcommand);
            tempvncii.cdata = tempvncii.cdata .* oldBC.cdata ./ tempBCcifti.cdata;
        end
        if i == 1
            outTemplate = tempcii;
            inputConcat = tempnorm;
            SaveRunVN = tempvncii.cdata;
        else
            inputConcat = [inputConcat tempnorm]; %#ok<AGROW>
            SaveRunVN = [SaveRunVN tempvncii.cdata]; %#ok<AGROW>
        end
        clear tempcii tempnorm tempvncii tempBCcifti;
        if doVol
            tempvolcii = open_vol_as_cifti(volinputArray{i}, optional.VolCiftiTemplate, wbcommand);
            if size(tempvolcii.cdata, 2) ~= runStarts(i + 1) - runStarts(i)
                error(['volume timeseries "' volinputArray{i} '" has different length than the cifti version']);
            end
            tempvolvncii = open_vol_as_cifti(volinputVNArray{i}, optional.VolCiftiTemplate, wbcommand);
            tempvolvncii.cdata = max(tempvolvncii.cdata, 0.001); 
            tempvolnorm = demean(tempvolcii.cdata, 2) ./ repmat(tempvolvncii.cdata, 1, size(tempvolcii.cdata, 2));
            clear tempvolcii;
            if doVolFixBC
                tempvolBCcifti = open_vol_as_cifti(volGoodBCArray{i}, optional.VolCiftiTemplate, wbcommand);
                tempvolvncii.cdata = tempvolvncii.cdata .* oldVolBC.cdata ./ tempvolBCcifti.cdata;
            end
            if i == 1
                volInputConcat = tempvolnorm;
                SaveRunVolVN = tempvolvncii.cdata;
            else
                volInputConcat = [volInputConcat tempvolnorm]; %#ok<AGROW>
                SaveRunVolVN = [SaveRunVolVN tempvolvncii.cdata]; %#ok<AGROW>
            end
            clear tempvolnorm tempvolvncii tempvolBCcifti;
        end
    end
    
    vnmean = mean(SaveRunVN, 2); %should this use weighted and/or geometric mean?  are there zeros?
    if doVol
        vnvolmean = mean(SaveRunVolVN, 2);
    end
        
    inputConcat = inputConcat .* repmat(vnmean, 1, size(inputConcat, 2)); %Do correction in BC space because this is temporal regression
    tICAtcs = ciftiopen(Timeseries, wbcommand);
    tICAtcs.cdata = normalise(tICAtcs.cdata')';
    Noise = load(NoiseList);
    betaICA = ((pinv(tICAtcs.cdata') * demean(inputConcat')));
    cleanedData = inputConcat - (tICAtcs.cdata(Noise, :)' * betaICA(Noise, :))';
    %%split out by input runs
    for i = 1:size(inputArray, 1)
        outTemplate.cdata = cleanedData(:, runStarts(i):(runStarts(i + 1) - 1)); %see above, extra element on end of runStarts
        ciftisavereset(outTemplate, outputNamesArray{i}, wbcommand); %reset because concatenated runs may be different lengths
        %save out good-BC vn for each input
        outTemplate.cdata = SaveRunVN(:, i);
        ciftisavereset(outTemplate, outputVNNamesArray{i}, wbcommand);
    end
    
    %volume outputs
    if doVol
        volInputConcat = volInputConcat .* repmat(vnvolmean, 1, size(volInputConcat, 2));
        VolbetaICA = ((pinv(tICAtcs.cdata') * demean(volInputConcat')));
        cleanedVolData = volInputConcat - (tICAtcs.cdata(Noise, :)' * VolbetaICA(Noise, :))'; 
        %%split out by input runs
        for i = 1:size(inputArray, 1)
            %%convert back to NIFTI
            outVolTemplate.cdata = cleanedVolData(:, runStarts(i):(runStarts(i + 1) - 1));
            save_volcifti_as_nifti(outVolTemplate, OutputVolNamesArray{i}, wbcommand);
            my_system(['fslcpgeom "' inputArray{i} '" "' OutputVolNamesArray{i} '" -d']); %set timestep
            %save out good-BC vn for each input
            outVolTemplate.cdata = SaveRunVolVN(:, i);
            save_volcifti_as_nifti(outVolTemplate, OutputVolVNNamesArray{i}, wbcommand);
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

function outstruct = open_vol_as_cifti(volName, ciftiTemplate, wbcommand)
    %don't leave a temporary file around on error/interrupt
    function cleanupFunc(filename)
        system(['rm -f -- "' filename '"']);
    end
    myfile = [tempname() '.dscalar.nii'];
    guardObj = onCleanup(@() cleanupFunc(myfile));
    my_system([wbcommand ' -cifti-create-dense-from-template "' ciftiTemplate '" "' myfile '" -volume-all ' volName]);
    outstruct = ciftiopen(myfile, wbcommand);
end

function save_volcifti_as_nifti(cifti, outVolName, wbcommand)
    %don't leave a temporary file around on error/interrupt
    function cleanupFunc(filename)
        system(['rm -f -- "' filename '"']); %matlab's remove function has troublesome quirks, easier to avoid it than to fix them
    end
    myfile = [tempname() '.dscalar.nii'];
    guardObj = onCleanup(@() cleanupFunc(myfile));
    ciftisavereset(cifti, myfile, wbcommand); %reset because concatenated runs may be different lengths
    my_system([wbcommand ' -cifti-separate "' myfile '" COLUMN -volume-all "' outVolName '"']);
end

%like call_fsl, but without sourcing fslconf
function my_system(command)
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
    if system(command) ~= 0
        error(['command failed: ' command]);
    end
end

