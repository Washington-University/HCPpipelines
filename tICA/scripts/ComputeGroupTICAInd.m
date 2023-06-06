function ComputeGroupTICAInd(StudyFolder, SubjListName, TCSListName, SpectraListName, fMRIListName, sICAdim, RunsXNumTimePoints, OutputFolder, OutString, RegName, LowResMesh, tICAmode, tICAMM, sICAtcsvarsFile)
    
    %if isdeployed()
        %better solution for compiled matlab: *require* all arguments to be strings, so we don't have to build the argument list twice in the script
    %end
    sICAdim = str2double(sICAdim);
    RunsXNumTimePoints = str2double(RunsXNumTimePoints);
    
    wbcommand = 'wb_command';
    
    %naming conventions inside OutputFolder, probably don't need to be changeable
    tICAmixNamePart = 'melodic_mix';
    tICAunmixNamePart = 'melodic_unmix';
    statsNamePart = 'stats';
    figsNamePart = 'Figure';
    iqNamePart = 'iq';
    sRNamePart = 'sR';
    tICAtcsNamePart = 'tICA_TCS';
    
    RegString = '';
    if ~isempty(RegName)
        RegString = ['_' RegName];
    end
    
    TCSList = myreadtext(TCSListName);
    %MapList = myreadtext(MapListName);
    %VolMapList = myreadtext(VolMapListName);
    SpectraList = myreadtext(SpectraListName);
    SubjectList = myreadtext(SubjListName);
    fMRIList = myreadtext(fMRIListName);
    
    %TCSFullConcat = ciftiopen(TCSConcatName, wbcommand);
	% pad the individual sICA timeseries to RunsXNumTimePoints
    TCSSub=ciftiopen(TCSList{1}, wbcommand);
    TCSPad = zeros(sICAdim, RunsXNumTimePoints, 'single');
    TCSPad(1:size(TCSSub.cdata, 1), 1:size(TCSSub.cdata, 2)) = TCSSub.cdata;
    TCSFullConcat=TCSSub;
    TCSFullConcat.cdata=TCSPad;
    
    tICAMM=load(tICAMM);

    numsubj = length(TCSList);
    if length(SubjectList) ~= numsubj || length(SpectraList) ~= numsubj
        error('input lists are not the same length');
    end

	if numsubj ~= 1
		error('this file can only accept one subject at a time in a USE mode');
	end

    numfullsubj = 0;

    %tica runwise normalization
    TCSFullRunVars = single(zeros(sICAdim, RunsXNumTimePoints * numsubj));
    for i = 1:numsubj
        if exist(TCSList{i}, 'file')
            subjBaseInd = (i - 1) * RunsXNumTimePoints + 1;
            thisStart = subjBaseInd;
            TCSRunVarSub = [];
            SubjFolder = [StudyFolder '/' SubjectList{i} '/'];
            for j = 1:length(fMRIList)
                dtseriesName = [SubjFolder fMRIList{j}];
                if exist(dtseriesName, 'file')
                    [~, runLengthStr] = system(['wb_command -file-information -only-number-of-maps ' dtseriesName]);
                    runLength = str2double(runLengthStr);
                    nextStart = thisStart + runLength;
                    TCSRunVarSub = [TCSRunVarSub repmat(std(TCSFullConcat.cdata(:, thisStart:(nextStart - 1)), [], 2), 1, runLength)];

                    thisStart = nextStart;
                end
            end
            if size(TCSRunVarSub, 2) == RunsXNumTimePoints
                numfullsubj = numfullsubj + 1;
            end
            TCSFullRunVars(:, subjBaseInd - 1 + (1:size(TCSRunVarSub, 2))) = TCSRunVarSub;
        end
    end
    %end tica runwise normalization

    nlfunc = 'tanh';
    iterations = 100;
    tICAdim = sICAdim;

    sICAtcsvars = load(sICAtcsvarsFile);
    sICAtcsvars = sICAtcsvars.sICAtcsvars; 
    TCSFullConcat.cdata = (TCSFullConcat.cdata ./ TCSFullRunVars) .* repmat(sICAtcsvars, 1, size(TCSFullRunVars, 2)); %Making all runs contribute equally improves tICA decompositions
    TCSFullConcat.cdata(~isfinite(TCSFullConcat.cdata)) = 0;

    %This loop produces more reproducible and better tICA decompositions
    if strcmp(tICAmode,'USE')
        A = tICAMM;
        if size(tICAMM,1) ~= size(TCSFullConcat.cdata,1)
            error('Mixing matrix to be used does not match dimensions of the sICA components');
        end
    else
        error('tICAmode not recognized');
    end
    
    %We do different types of icasso, etc in different modes/iterations, but we do things in between all iterations, and save out some files the same way each time
    %So, rely on iteration number as a mode switch, even though it is ugly

    IT = ['F'];
    W = pinv(A);
    normicasig = W * TCSFullConcat.cdata;

    icasig = normicasig .* repmat(std(A ./ repmat(sICAtcsvars, 1, size(A, 2)))', 1, size(TCSFullConcat.cdata, 2)); %Unormalize the icasig assuming sICAtcs with std = 1 (approximately undo the original variance normalization)
    
    tICAtcs = TCSFullConcat;
    tICAtcs.cdata = icasig'; %time X temporal ica
	tICAtcs.cdata = tICAtcs.cdata';
	%tICAtcs.cdata = single(tICAtcs.cdata);
    tICAtcsAll = reshape(tICAtcs.cdata, tICAdim, RunsXNumTimePoints, numsubj);
    
    for i = 1:numsubj
        if exist(TCSList{i}, 'file')
            sICATCS = ciftiopen(TCSList{i}, 'wb_command');
            sICASpectra = ciftiopen(SpectraList{i}, 'wb_command');
            tICATCS = sICATCS;
            %tICATCS.cdata = pinv(tICAmix) * sICATCS.cdata;
            tICATCS.cdata = squeeze(tICAtcsAll(:, std(tICAtcsAll(:, :, i), [], 1) > 0, i));
            tICASpectra = sICASpectra;
            SubjFolder = [StudyFolder '/' SubjectList{i} '/'];
            %FIXME: how to deal with subject ID in this filename without hardcoding conventions?
            ciftisave(tICATCS, [SubjFolder 'MNINonLinear/fsaverage_LR' LowResMesh 'k/' SubjectList{i} '.' OutString '_tICA' RegString '_ts2.' LowResMesh 'k_fs_LR.sdseries.nii'], 'wb_command');
            ts.Nnodes = size(tICATCS.cdata, 1);
            ts.Nsubjects = 1;
            ts.ts = tICATCS.cdata';
            ts.NtimepointsPerSubject = size(tICATCS.cdata, 2);
            tICASpectra.cdata = nets_spectra_sp(ts)';
            %FIXME
            ciftisave(tICASpectra, [SubjFolder '/MNINonLinear/fsaverage_LR' LowResMesh 'k/' SubjectList{i} '.' OutString '_tICA' RegString '_spectra2.' LowResMesh 'k_fs_LR.sdseries.nii'], 'wb_command');
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

