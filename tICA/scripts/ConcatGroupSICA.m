function ConcatGroupSICA(TCSListName, MapListName, VolMapListName, SpectraListName, InputStats, sICAdim, RunsXNumTimePoints, OutTCSName, OutTCSMaskName, OutAnnsubName, OutAvgTCSName, OutAbsAvgTCSName, OutAvgSpectraName, OutAvgMapsName, OutAvgVolMapsName)
    
    %if isdeployed()
        %better solution for compiled matlab: *require* all arguments to be strings, so we don't have to build the argument list twice in the script
    %end
    sICAdim = str2double(sICAdim);
    RunsXNumTimePoints = str2double(RunsXNumTimePoints);
    
    wbcommand = 'wb_command';
    
    TCSList = myreadtext(TCSListName);
    MapList = myreadtext(MapListName);
    VolMapList = myreadtext(VolMapListName);
    SpectraList = myreadtext(SpectraListName);

    sICAiq = load(InputStats);

    numsubj = length(TCSList);
    if length(MapList) ~= numsubj || length(VolMapList) ~= numsubj || length(SpectraList) ~= numsubj
        error('input lists are not the same length');
    end
    numgoodsubj = 0;
    numfullsubj = 0;

    SpectraSum = 0; % HACK: scalar zero plus matrix is a matrix
    sICAMapsSum = 0; % use double for summing lots of floats, for precision
    sICAVolMapsSum = 0;
    TCSSum = 0;
    TCSAbsSum = 0;

    TCSFull = zeros(sICAdim, RunsXNumTimePoints * numsubj, 'single');
    %keep mask file the same as old code so that existing results match new code
    TCSMask = zeros(sICAdim, RunsXNumTimePoints * numsubj, 'single');
    
    SpectraTemplate = [];
    TCSTemplate = [];

    for i = 1:numsubj
        %matt says keep the zeros from subjects without any data
        if exist(TCSList{i}, 'file')
            numgoodsubj = numgoodsubj + 1;
            
            sICAMapsSub = ciftiopen(MapList{i}, wbcommand);
            sICAVolMapsSub = ciftiopen(VolMapList{i}, wbcommand);
            TCSSub = ciftiopen(TCSList{i}, wbcommand);
            SpectraSub = ciftiopen(SpectraList{i}, wbcommand);
            
            sICAVolMapsSub.cdata(~isfinite(sICAVolMapsSub.cdata)) = 0;
            TCSPad = zeros(sICAdim, RunsXNumTimePoints, 'single');
            TCSPad(1:size(TCSSub.cdata, 1), 1:size(TCSSub.cdata, 2)) = TCSSub.cdata;
            subjstart = 1 + (i - 1) * RunsXNumTimePoints; %1-based indices, inclusive range...
            TCSFull(:, subjstart:(subjstart + RunsXNumTimePoints - 1)) = TCSPad;
            
            sICAMapsSum = sICAMapsSum + sICAMapsSub.cdata;
            sICAVolMapsSum = sICAVolMapsSum + sICAVolMapsSub.cdata;

            % check for full length
            if size(TCSSub.cdata, 2) == RunsXNumTimePoints
                numfullsubj = numfullsubj + 1;
                
                TCSMask(:, subjstart:(subjstart + RunsXNumTimePoints - 1)) = 1;
                
                SpectraSum = SpectraSum + SpectraSub.cdata;
                TCSSum = TCSSum + TCSPad;
                TCSAbsSum = TCSAbsSum + abs(TCSPad);
                
                if isempty(SpectraTemplate)
                    SpectraSub.cdata = [];
                    SpectraTemplate = SpectraSub;
                    TCSSub.cdata = [];
                    TCSTemplate = TCSSub;
                end
            end
        end
    end

    TCSFullConcat = TCSSub; % use the last good subject as a template
    TCSFullConcat.cdata = TCSFull;
    ciftisavereset(TCSFullConcat, OutTCSName, wbcommand);
    clear TCSFullConcat;

    TCSMaskConcat = TCSSub;
    TCSMaskConcat.cdata = TCSMask;
    ciftisavereset(TCSMaskConcat, OutTCSMaskName, wbcommand);
    clear TCSMaskConcat;

    %previously sICATSTDs
    sICATVARs = var(TCSFull, [], 2);
    sICAPercentVariances = (sICATVARs / sum(sICATVARs)) * 100;

    dlmwrite(OutAnnsubName, [round(sICAiq, 2) round(sICAPercentVariances, 2)], ',');
    clear TCSFull;

    %subjects with full TS
    TCSMean = TCSTemplate;
    TCSMean.cdata = TCSSum / numfullsubj;
    ciftisave(TCSMean, OutAvgTCSName, wbcommand);

    TCSAbsMean = TCSTemplate;
    TCSAbsMean.cdata = TCSAbsSum / numfullsubj;
    ciftisave(TCSAbsMean, OutAbsAvgTCSName, wbcommand);

    SpectraMean = SpectraTemplate;
    SpectraMean.cdata = SpectraSum / numfullsubj;
    ciftisave(SpectraMean, OutAvgSpectraName, wbcommand);

    %subjects with any data
    sICAMapsMean = sICAMapsSub;
    sICAMapsMean.cdata = sICAMapsSum / numgoodsubj;
    ciftisave(sICAMapsMean, OutAvgMapsName, wbcommand);

    sICAVolMapsMean = sICAVolMapsSub;
    sICAVolMapsMean.cdata = sICAVolMapsSum / numgoodsubj;
    ciftisave(sICAVolMapsMean, OutAvgVolMapsName, wbcommand);
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

