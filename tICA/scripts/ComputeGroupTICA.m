function ComputeGroupTICA(StudyFolder, SubjListName, TCSListName, SpectraListName, fMRIListName, sICAdim, RunsXNumTimePoints, TCSConcatName, TCSMaskName, AvgTCSName, sICAAvgSpectraName, sICAMapsAvgName, sICAVolMapsAvgName, OutputFolder, OutString, RegName, LowResMesh, tICAmode, tICAMM)
    
    %% handle arguments and set filepath parts
    %if isdeployed()
        %better solution for compiled matlab: *require* all arguments to be strings, so we don't have to build the argument list twice in the script
    %end
    sICAdim = str2double(sICAdim);
    RunsXNumTimePoints = str2double(RunsXNumTimePoints);
    
%     wbcommand = 'wb_command'; 
    
    %naming conventions inside OutputFolder, probably don't need to be changeable
    tICAMapsNamePart = 'tICA_Maps';
    tICAVolMapsNamePart = 'tICA_VolMaps';
    tICAmixNamePart = 'melodic_mix';
    tICAunmixNamePart = 'melodic_unmix';
    statsNamePart = 'stats';
    figsNamePart = 'Figure';
    iqNamePart = 'iq';
    sRNamePart = 'sR';
    tICAtcsNamePart = 'tICA_TCS';
    tICAtcsmeanNamePart = 'tICA_AVGTCS';
    tICAtcsabsmeanNamePart = 'tICA_ABSAVGTCS';
    tICAspectraNamePart = 'tICA_Spectra';
    tICAspectranormNamePart = 'tICA_Spectra_norm';
    
    RegString = '';
    if ~isempty(RegName)
        RegString = ['_' RegName];
    end
    
    %% load data
    TCSList = myreadtext(TCSListName);
    %MapList = myreadtext(MapListName);
    %VolMapList = myreadtext(VolMapListName);
    SpectraList = myreadtext(SpectraListName);
    SubjectList = myreadtext(SubjListName);
    fMRIList = myreadtext(fMRIListName);
    
    TCSFullConcat = cifti_read(TCSConcatName);
    TCSMaskConcat = cifti_read(TCSMaskName);
    AvgTCS = cifti_read(AvgTCSName);%only used as a template, and only because cifti-legacy doesn't handle reset of sdseries
    sICAAvgSpectra = cifti_read(sICAAvgSpectraName);
    sICAMaps = cifti_read(sICAMapsAvgName);
    sICAVolMaps = cifti_read(sICAVolMapsAvgName);

    if ~strcmp(tICAMM,'')
        tICAMM = load(tICAMM);
    end

    numsubj = length(TCSList);
    if length(SubjectList) ~= numsubj || length(SpectraList) ~= numsubj
        error('input lists are not the same length');
    end
    
    TCSMask = reshape(TCSMaskConcat.cdata, [sICAdim, RunsXNumTimePoints, numsubj]);

    %% optionally, filter Group sICA components to hand picked list before running tICA
    handSigFile = [OutputFolder '/../sICA/HandSignal.txt'];% assumes OutputFolder and /sICA are always in the same parent dir
    if exist(handSigFile,'file')
        sigIdx = load(handSigFile,'-ascii');
        tICAdim = numel(sigIdx);
        TCSFullConcat = filterCifti(TCSFullConcat,1,sigIdx);
        TCSMaskConcat = filterCifti(TCSMaskConcat,1,sigIdx);
        AvgTCS = filterCifti(AvgTCS,1,sigIdx);
        sICAAvgSpectra = filterCifti(sICAAvgSpectra,1,sigIdx);
        sICAMaps = filterCifti(sICAMaps,2,sigIdx);
        sICAVolMaps = filterCifti(sICAVolMaps,2,sigIdx);
        TCSMask = TCSMask(sigIdx,:,:);
        if ~isempty(tICAMM) && ~all(size(tICAMM) == tICAdim)
            error('tICAMM dimensionaily doesn''t match sICA dimensionality post HandSignal.txt filtering')
        end
    else
      tICAdim = sICAdim;
      sigIdx = 1:sICAdim;
    end

    %% perform runwise normalization
    numfullsubj = 0;
    TCSFullRunVars = single(zeros(tICAdim, RunsXNumTimePoints * numsubj));
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
    sICAtcsvars = std(TCSFullConcat.cdata, [], 2);
    TCSFullConcat.cdata = (TCSFullConcat.cdata ./ TCSFullRunVars) .* repmat(sICAtcsvars, 1, size(TCSFullRunVars, 2)); %Making all runs contribute equally improves tICA decompositions
    TCSFullConcat.cdata(~isfinite(TCSFullConcat.cdata)) = 0;
    %end tica runwise normalization

    %% set up tICA loop
    nlfunc = 'tanh';
    iterations = 100;

    %This loop produces more reproducible and better tICA decompositions
    if strcmp(tICAmode,'ESTIMATE')
        ITERATIONS=[1:6];
    elseif strcmp(tICAmode,'INITIALIZE')
        ITERATIONS=[2:6];
        A = tICAMM;
        if size(tICAMM,1) ~= size(TCSFullConcat.cdata,1)
            error('Initialization mixing matrix does not match dimensions of the sICA components');
        end
    elseif strcmp(tICAmode,'USE')
        ITERATIONS=[0];
        A = tICAMM;
        if size(tICAMM,1) ~= size(TCSFullConcat.cdata,1)
            error('Mixing matrix to be used does not match dimensions of the sICA components');
        end
    else
        error('tICAmode not recognized');
    end
    
    %% run tICA loop
    %We do different types of icasso, etc in different modes/iterations, but we do things in between all iterations, and save out some files the same way each time
    %So, rely on iteration number as a mode switch, even though it is ugly
    for i = ITERATIONS
        if  i == 0
            IT = ['F'];
            W = pinv(A);
            normicasig = W * TCSFullConcat.cdata;
        elseif i == 1
            IT = [num2str(i)];
            fprintf('\nsICAdim: %i\n', sICAdim);
            fprintf('tICAdim: %i\n', tICAdim);
            [iq, A, W, normicasig, sR] = icasso('both', TCSFullConcat.cdata, iterations, 'approach', 'symm', 'g', nlfunc, 'lastEig', tICAdim, 'numOfIC', tICAdim, 'maxNumIterations', 1000); %x1
        elseif i > 5
            IT = ['F'];
            [normicasig, A, W] = fastica(TCSFullConcat.cdata, 'initGuess', A, 'approach', 'symm', 'g', nlfunc, 'lastEig', tICAdim, 'numOfIC', tICAdim, 'displayMode', 'off', 'maxNumIterations', 1000); %x1
        else
            IT = [num2str(i)];
            [iq, A, W, normicasig, sR] = icasso('bootstrap', TCSFullConcat.cdata, iterations, 'initGuess', A, 'approach', 'symm', 'g', nlfunc, 'lastEig', tICAdim, 'numOfIC', tICAdim, 'maxNumIterations', 1000); %x4
        end

        % normicasig has stdev = 1, we want to multiply the (approximate) amplitudes from A into it
        % but, we also want to pretend that the input to tICA was normalized, so:
        % tICAinput = A * normicasig
        % pretendtICAinput = diag(1 / std(tICAinput)) * A * normicasig
        % ...assume normicasig doesn't change...
        % pretendA = diag(1 / std(tICAinput)) * A = A ./ repmat(std(tICAinput), ...)
        % then use std() to extract the approximate amplitudes from pretendA...sqrt(mean(x .^ 2)) might be better, but this was how we did it originally, so...
        icasig = normicasig .* repmat(std(A ./ repmat(sICAtcsvars, 1, size(A, 2)))', 1, size(TCSFullConcat.cdata, 2)); %Unormalize the icasig assuming sICAtcs with std = 1 (approximately undo the original variance normalization)
        

        tICAtcs = TCSFullConcat;
        tICAtcs.cdata = icasig'; %time X temporal ica
        tICAmix = A; %spatial ica X temporal ica

        tICAMaps = sICAMaps;
        tICAMaps.cdata = sICAMaps.cdata * (tICAmix ./ repmat(mean(sICAtcsvars), size(A, 1), size(A, 2))); %grayordinates X spatial ica * spatial ica X temporal ica (undo overall effect of variance normalization on mixing matrix)

        tICAVolMaps = sICAVolMaps;
        tICAVolMaps.cdata = sICAVolMaps.cdata * (tICAmix ./ repmat(mean(sICAtcsvars), size(A, 1), size(A, 2))); %voxels X spatial ica * spatial ica X temporal ica (undo overall effect of variance normalization on mixing matrix)

        if ~strcmp(tICAmode,'USE')
            %pos = max(tICAMaps.cdata) > abs(min(tICAMaps.cdata));
            neg = max(tICAMaps.cdata) < abs(min(tICAMaps.cdata));
            %pos = ~neg;
            %all = single(pos) - neg; %TSC: don't name a variable 'all', it is a special value to 'clear'

            negList = find(neg);
            tICAmix(:, negList) = -tICAmix(:, negList);
            %tICAunmix(negList, :) = -tICAunmix(negList, :);
            tICAtcs.cdata(:, negList) = -tICAtcs.cdata(:, negList);
            tICAMaps.cdata(:, negList) = -tICAMaps.cdata(:, negList);
            tICAVolMaps.cdata(:, negList) = -tICAVolMaps.cdata(:, negList);
        
            %tICAmix = tICAmix .* repmat(sign(all), size(tICAmix, 1), 1);
            %%tICAunmix = (tICAunmix' .* repmat(sign(all), size(tICAmix, 1), 1))';
            %tICAtcs.cdata = tICAtcs.cdata .* repmat(sign(all), size(tICAtcs.cdata, 1), 1);
            %tICAMaps.cdata = tICAMaps.cdata .* repmat(sign(all), size(tICAMaps.cdata, 1), 1);
            %tICAVolMaps.cdata = tICAVolMaps.cdata .* repmat(sign(all), size(tICAVolMaps.cdata, 1), 1);

           [TSTDs, TIs] = sort(std(tICAtcs.cdata, [], 1), 'descend'); %Sort based on unnormalized tICA temporal standard deviations
        else
            TSTDs = std(tICAtcs.cdata, [], 1); %unnormalized tICA temporal standard deviations
            TIs = [1:1:length(TSTDs)];
        end
        
        Is = TIs;

        tICAPercentVariances = (((TSTDs .^ 2) / sum(TSTDs .^ 2)) * 100)';

        tICAtcs.cdata(:, [1:1:length(Is)]) = single(tICAtcs.cdata(:, Is));
        tICAmix(:, [1:1:length(Is)]) = single(tICAmix(:, Is));
        tICAunmix = pinv(tICAmix);
        tICAMaps.cdata(:, [1:1:length(Is)]) = single(tICAMaps.cdata(:, Is));
        tICAVolMaps.cdata(:, [1:1:length(Is)]) = single(tICAVolMaps.cdata(:, Is));

        
        nameParamPart = ['_' num2str(tICAdim) '_' nlfunc IT];
        cifti_write(tICAMaps, [OutputFolder '/' tICAMapsNamePart nameParamPart '.dscalar.nii']);
        cifti_write(tICAVolMaps, [OutputFolder '/' tICAVolMapsNamePart nameParamPart '.dscalar.nii']);

        dlmwrite([OutputFolder '/' tICAmixNamePart nameParamPart], tICAmix, '\t');
        dlmwrite([OutputFolder '/' tICAunmixNamePart nameParamPart], tICAunmix, '\t');

        if  i ~= 0
            iqsort = iq(Is);
            dlmwrite([OutputFolder '/' statsNamePart nameParamPart '.wb_annsub.csv'], [round(iqsort, 2) round(tICAPercentVariances, 2)], ',');
            save([OutputFolder '/' iqNamePart nameParamPart], 'iq', '-v7.3');
            save([OutputFolder '/' sRNamePart nameParamPart], 'sR', '-v7.3');
            figs = findall(0, 'type', 'figure');
            try
                for f = 1:length(figs)
                    savefig(figs(f), [OutputFolder '/' figsNamePart num2str(f) '_' nameParamPart]);
                end
            catch
                warning('failed to save all figures, please check that matlab is set to use .mat v7.3 format by default, in MATLAB -> General -> MAT-Files');
            end
            close all;

        end

        tICAtcs.cdata = tICAtcs.cdata';

        cifti_write(tICAtcs, [OutputFolder '/' tICAtcsNamePart nameParamPart '.sdseries.nii']);

        tICAtcsAll = reshape(tICAtcs.cdata, tICAdim, RunsXNumTimePoints, numsubj);

        tICAtcsmean = AvgTCS;
        tICAtcsmean.cdata = sum(tICAtcsAll .* single(TCSMask(1:tICAdim, :, :) == 1), 3) / numfullsubj;
        tICAtcsabsmean = AvgTCS;
        tICAtcsabsmean.cdata = sum(abs(tICAtcsAll .* single(TCSMask(1:tICAdim, :, :) == 1)), 3) / numfullsubj;

        cifti_write(tICAtcsmean, [OutputFolder '/' tICAtcsmeanNamePart nameParamPart '.sdseries.nii']);
        cifti_write(tICAtcsabsmean, [OutputFolder '/' tICAtcsabsmeanNamePart nameParamPart '.sdseries.nii']);

        tICAspectra = sICAAvgSpectra;
        tICAspectranorm = sICAAvgSpectra;
        ts.Nnodes = tICAdim;
        ts.Nsubjects = numfullsubj;
        ts.NtimepointsPerSubject = RunsXNumTimePoints;
        ts.ts = (((tICAtcs.cdata .* single(TCSMaskConcat.cdata(1:tICAdim, :) == 1)) ./ numfullsubj) .* numsubj)'; %compensate for the zeros by ratio of full-data subjects to all subjects?
        tICAspectra.cdata = nets_spectra_sp(ts)';
        tICAspectranorm.cdata = nets_spectra_sp(ts, [], 1)';

        cifti_write(tICAspectra, [OutputFolder '/' tICAspectraNamePart nameParamPart '.sdseries.nii']);
        cifti_write(tICAspectranorm, [OutputFolder '/' tICAspectranormNamePart nameParamPart '.sdseries.nii']);

    end % for i = ITERATIONS

    %% package and save outputs
    for i = 1:numsubj
        if exist(TCSList{i}, 'file')
            sICATCS = cifti_read(TCSList{i});
            sICASpectra = cifti_read(SpectraList{i});
            tICATCS = sICATCS;
            %tICATCS.cdata = pinv(tICAmix) * sICATCS.cdata;
            tICATCS.cdata = squeeze(tICAtcsAll(:, std(tICAtcsAll(:, :, i), [], 1) > 0, i));
            tICASpectra = sICASpectra;
            SubjFolder = [StudyFolder '/' SubjectList{i} '/'];

            tICATCS.diminfo{1}.length = tICAdim;
            tICATCS.diminfo{1}.maps = tICATCS.diminfo{1}.maps(sigIdx);
            tICATCS.diminfo{2}.length = size(tICATCS.cdata,2);
            cifti_write(tICATCS, [SubjFolder 'MNINonLinear/fsaverage_LR' LowResMesh 'k/' SubjectList{i} '.' OutString '_tICA' RegString '_ts.' LowResMesh 'k_fs_LR.sdseries.nii']);%FIXME: how to deal with subject ID in this filename without hardcoding conventions?

            ts.Nnodes = size(tICATCS.cdata, 1);
            ts.Nsubjects = 1;
            ts.ts = tICATCS.cdata';
            ts.NtimepointsPerSubject = size(tICATCS.cdata, 2);
            tICASpectra.cdata = nets_spectra_sp(ts)';


            tICASpectra.diminfo{1}.length = tICAdim;
            tICASpectra.diminfo{1}.maps = tICASpectra.diminfo{1}.maps(sigIdx);
            tICASpectra.diminfo{2}.length = size(tICASpectra.cdata,2);
            cifti_write(tICASpectra, [SubjFolder '/MNINonLinear/fsaverage_LR' LowResMesh 'k/' SubjectList{i} '.' OutString '_tICA' RegString '_spectra.' LowResMesh 'k_fs_LR.sdseries.nii']);%FIXME
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

function C = filterCifti(C,dimIdx,filtIdx)
    % subselect from one dim of cifti
    C.diminfo{dimIdx}.length = numel(filtIdx);
    C.diminfo{dimIdx}.maps = C.diminfo{dimIdx}.maps(filtIdx);
    idx = repmat({':'}, 1, ndims(C.cdata));
    idx{dimIdx} = filtIdx;
    C.cdata = C.cdata(idx{:});
end
