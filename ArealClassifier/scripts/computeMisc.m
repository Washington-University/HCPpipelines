function computeMisc(inputFile, outputMGTBetaName, outputStdName)
    inputArray = myreadtext(inputFile);
    %do everything in input space
    for i = 1:size(inputArray, 1)
        tempcii = ciftiopen([inputArray{i}], 'wb_command');
        tempnorm = demean(tempcii.cdata, 2);
        tempcii.cdata = [];
        if i == 1
            outTemplate = tempcii;
            inputConcat = tempnorm;
        else
            inputConcat = [inputConcat tempnorm]; %#ok<AGROW>
        end
        clear tempcii tempnorm;
    end
    
    mgt = demean(mean(inputConcat, 1))';
    mgtbeta = pinv(mgt) * inputConcat';
    outTemplate.cdata = mgtbeta';
    ciftisavereset(outTemplate, outputMGTBetaName, 'wb_command');
    system(['wb_command -set-map-names ' outputMGTBetaName ' -map 1 MGT_beta']);
    outTemplate.cdata = std(inputConcat, [], 2);
    ciftisavereset(outTemplate, outputStdName, 'wb_command');
    system(['wb_command -set-map-names ' outputStdName ' -map 1 stdev']);
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

