
%load data from groupsave saved files
%remove two-study-folder stuff

%tica runwise normalization
for i = 1:length(SubjFolderlist)
    Subjlist{i}
    TCSRunVarsAll(:, :, i) = single(zeros(sICAdim, RunsXNumTimePoints));
    if exist([SubjFolderlist{i} '/MNINonLinear/fsaverage_LR' LowResMesh 'k/' Subjlist{i} '.' OutString '_ts.' LowResMesh 'k_fs_LR.sdseries.nii'])
         RunStarts = [1];
         RunEnds = [0];
         TCSRunVarSub = [];
         r = 1;
         for j = 1:length(fMRINames)
             if exist([SubjFolderlist{i} '/MNINonLinear/Results/' fMRINames{j} '/' fMRINames{j} '_Atlas_MSMAll.dtseries.nii'], 'file')
                 [junk Val] = unix(['wb_command -file-information ' SubjFolderlist{i} '/MNINonLinear/Results/' fMRINames{j} '/' fMRINames{j} '_Atlas_MSMAll.dtseries.nii -only-number-of-maps']);
                 RunStarts = [RunStarts RunStarts(r) + str2num(Val)];
                 RunEnds = [RunEnds RunEnds(r) + str2num(Val)];
                 TCSRunVarSub = [TCSRunVarSub repmat(squeeze(std(TCSAll(:, RunStarts(r):RunEnds(r + 1), i), [], 2)), 1, RunEnds(r + 1) - RunStarts(r) + 1)];
                 r = r + 1;
             end
         end
         RunStarts = RunStarts(1:end - 1);
         RunEnds = RunEnds(2:end);
         TCSRunVarsAll(:, 1:length(TCSRunVarSub), i) = TCSRunVarSub;
    end
end

TCSFullRunVars = squeeze(reshape(TCSRunVarsAll, sICAdim, RunsXNumTimePoints * length(SubjFolderlist)));
%end tica runwise

nlfunc = 'tanh';
iterations = 100;
%splits = 10;
tICAdim = sICAdim;

sICAtcsvars = std(TCSFullConcat.cdata')';
TCSFullConcat.cdata = (TCSFullConcat.cdata ./ TCSFullRunVars) .* repmat(sICAtcsvars, 1, length(TCSFullRunVars)); %Making all runs contribute equally improves tICA decompositions
%TCSFullConcat.cdata = (TCSFullConcat.cdata ./ TCSFullRunVars); %Normalizing sICA timecourses makes sICA - like components, don't use
TCSFullConcat.cdata(isnan(TCSFullConcat.cdata)) = 0;

%For interactive reproducibility testing
%Letter = 'A';
%Letter = 'B';
%Letter = 'C';
Letter = '';

%This loop produces more reproducible and better tICA decompositions
for i = 1:6
    if i == 1
        IT = [num2str(i) Letter];
        [iq, A, W, normicasig, sR] = icasso('both', TCSFullConcat.cdata, iterations, 'approach', 'symm', 'g', nlfunc, 'lastEig', sICAdim, 'numOfIC', tICAdim, 'maxNumIterations', 1000); %x1
        %for j = 1:splits
        %  [iq, A, W, normicasig, sRs{j}] = icasso('both', TCSFullConcat.cdata, iterations/splits, 'approach', 'symm', 'g', nlfunc, 'lastEig', sICAdim, 'numOfIC', tICAdim, 'maxNumIterations', 1000, 'vis', 'none'); %x1
        %  sRs{j} = icassoCluster(sRs{j});
        %  sRs{j} = icassoProjection(sRs{j}, 'cca', 's2d', 'sqrtsim2dis', 'epochs', 75);
        %  [iq, A, W, normicasig] = icassoResult(sRs{j}, tICAdim);
        %  Measure(j) = sum(sum(abs(corrcoef(sICAMapsOne.cdata * (A ./ repmat(mean(sICAtcsvars), size(A, 1), size(A, 2)))))));
        %  As(:, :, j) = A;
        %end
        %[junk j] = min(Measure); %Pick the least correlated clustering solution to initialize
        %[iq, A, W, normicasig] = icassoShow(sRs{j}, 'L', tICAdim);
        %sR = sRs{j};
    elseif i > 5
        IT = ['F' Letter];
        [normicasig, A, W] = fastica(TCSFullConcat.cdata, 'initGuess', A, 'approach', 'symm', 'g', nlfunc, 'lastEig', sICAdim, 'numOfIC', tICAdim, 'displayMode', 'off', 'maxNumIterations', 1000); %x1
    else
        IT = [num2str(i) Letter];
        [iq, A, W, normicasig, sR] = icasso('bootstrap', TCSFullConcat.cdata, iterations, 'initGuess', A, 'approach', 'symm', 'g', nlfunc, 'lastEig', sICAdim, 'numOfIC', tICAdim, 'maxNumIterations', 1000); %x4
    end

    icasig = normicasig .* repmat(std(A ./ repmat(sICAtcsvars, 1, size(A, 2)))', 1, length(TCSFullConcat.cdata)); %Unormalize the icasig assuming sICAtcs with std = 1 (approximately undo the original variance normalization)
    
    
    %icasig = normicasig .* repmat(std(A)', 1, length(TCSFullConcat.cdata)); %Unormalize the icasig with sICAtcs of std = 1 (approximately undo the original variance normalization)
    
    %icasig = normicasig .* repmat(std(A ./ repmat(mean(sICAtcsvars), size(A, 1), size(A, 2)))', 1, length(TCSFullConcat.cdata)); %Unormalize the icasig keeping original variance normalization (not used as original variance normalization penalizes some components vs others)


    %newTCS = tICAtcs.cdata ./ repmat(std(tICAmix ./ repmat(sICAtcsvars, 1, size(tICAmix, 2)))', 1, length(TCSFullConcat.cdata));
    %newTCS = newTCS(kurtosis(var(tICAtcsAll, [], 2), [], 3) < 33, :);
    %newMix = TCSFullConcat.cdata * pinv(newTCS);
    %tICAdim = sum(kurtosis(var(tICAtcsAll, [], 2), [], 3) < 33);
    %[iq, A, W, normicasig, sR] = icasso('bootstrap', TCSFullConcat.cdata, iterations, 'initGuess', newMix, 'approach', 'symm', 'g', nlfunc, 'lastEig', sICAdim, 'numOfIC', tICAdim, 'maxNumIterations', 1000); %x4


    %%IT = '_2';
    %sRI = sR;
    %L = tICAdim; [iq, A, W, S] = icassoShow(sR, 'L', L, 'estimate', 'off'); 
    %A = A(:, 1:52);
    %[iq, A, W, S, sR] = icasso('bootstrap', TCSFullConcat.cdata, iterations, 'initGuess', A, 'approach', 'symm', 'g', nlfunc, 'lastEig', sICAdim, 'numOfIC', tICAdim, 'maxNumIterations', 1000);
    %[normicasig, A, W] = fastica(TCSFullConcat.cdata, 'initGuess', A, 'approach', 'symm', 'g', nlfunc, 'lastEig', sICAdim, 'numOfIC', tICAdim, 'displayMode', 'off', 'maxNumIterations', 1000);

    %IT = '_3';
    %sRII = sR;
    %L = tICAdim; [iq, A, W, S] = icassoShow(sR, 'L', L, 'estimate', 'off'); 
    %A = A(:, 1:55);
    %[iq, A, W, S, sR] = icasso('bootstrap', TCSFullConcat.cdata, iterations, 'initGuess', A, 'approach', 'symm', 'g', nlfunc, 'lastEig', sICAdim, 'numOfIC', tICAdim, 'maxNumIterations', 1000);
    %[normicasig, A, W] = fastica(TCSFullConcat.cdata, 'initGuess', A, 'approach', 'symm', 'g', nlfunc, 'lastEig', sICAdim, 'numOfIC', tICAdim, 'displayMode', 'off', 'maxNumIterations', 1000);

    %IT = '_4';
    %sRIII = sR;
    %L = tICAdim; [iq, A, W, S] = icassoShow(sR, 'L', L, 'estimate', 'off'); 
    %A = A(:, 1:57);
    %[iq, A, W, S, sR] = icasso('bootstrap', TCSFullConcat.cdata, iterations, 'initGuess', A, 'approach', 'symm', 'g', nlfunc, 'lastEig', sICAdim, 'numOfIC', tICAdim, 'maxNumIterations', 1000);
    %[normicasig, A, W] = fastica(TCSFullConcat.cdata, 'initGuess', A, 'approach', 'symm', 'g', nlfunc, 'lastEig', sICAdim, 'numOfIC', tICAdim, 'displayMode', 'off', 'maxNumIterations', 1000);

    %IT = '_5';
    %sRIV = sR;
    %L = tICAdim; [iq, A, W, S] = icassoShow(sR, 'L', L, 'estimate', 'off'); 
    %A = A(:, 1:56);
    %[iq, A, W, S, sR] = icasso('bootstrap', TCSFullConcat.cdata, iterations, 'initGuess', A, 'approach', 'symm', 'g', nlfunc, 'lastEig', sICAdim, 'numOfIC', tICAdim, 'maxNumIterations', 1000);
    %[normicasig, A, W] = fastica(TCSFullConcat.cdata, 'initGuess', A, 'approach', 'symm', 'g', nlfunc, 'lastEig', sICAdim, 'numOfIC', tICAdim, 'displayMode', 'off', 'maxNumIterations', 1000);

    %IT = '_6';
    %sRV = sR;
    %L = tICAdim; [iq, A, W, S] = icassoShow(sR, 'L', L, 'estimate', 'off'); 
    %A = A(:, 1:58);
    %[iq, A, W, S, sR] = icasso('bootstrap', TCSFullConcat.cdata, iterations, 'initGuess', A, 'approach', 'symm', 'g', nlfunc, 'lastEig', sICAdim, 'numOfIC', tICAdim, 'maxNumIterations', 1000);
    %[normicasig, A, W] = fastica(TCSFullConcat.cdata, 'initGuess', A, 'approach', 'symm', 'g', nlfunc, 'lastEig', sICAdim, 'numOfIC', tICAdim, 'displayMode', 'off', 'maxNumIterations', 1000);

    %sum(iq > 0.5)

    %tfMRI d76:   76-->48, 62-->46, 69-->45, 73-->46, 75-->47, 74-->48, 55-->45, 65-->47, 72-->43, 71-->47, 66-->43, 64-->48, 63-->47, 61-->48, 60-->45, 70-->45, 67-->47, 68-->45, 59-->45, 58-->46, 57-->44, 56-->
    %tfMRI d118: 118-->37, 78-->48, 63-->50, 57-->50, 54-->48, 60-->50, 71-->47, 55-->45, 65-->52, 64-->50, 66-->49, 62-->49, 61-->49, 59-->51, 58-->48, 67-->50, 68-->43, 69-->50, 70-->49, 72-->46, 73-->45, 56-->
    %rfMRI d97:   97-->57, 77-->61, 69-->59, 73-->58, 75-->61, 76-->60, 78-->57, 74-->60, 79-->61, 80-->58, 72-->59, 71-->57, 70-->58, 68-->59, 81-->62, 82-->58, 83-->57, 84-->58, 85-->59, 86-->57, 87-->58, 88-->
    %rfMRI d139: 139-->52, 96-->56, 76-->61, 69-->60, 73-->64, 72-->62, 74-->61, 75-->62, 71-->61, 70-->60, 77-->64, 78-->62, 79-->62, 80-->66, 81-->61, 82-->65, 83-->64, 84-->61, 85-->63, 86-->64, 87-->61, 88-->

    %tfMRI d76:   76-->48, 74-->48, 61-->48
    %tfMRI d118:  65-->52
    %rfMRI d97:   81-->62, 
    %rfMRI d139:  80-->66


    %tfMRI d76: 76 - 48 = 28 / 2 = 14 + 48 = abs(62 - 76) = 14 / 2 = 7 + 62 = abs(69 - 76) = 7 / 2 = 4 + 69 = abs(73 - 76) = 3 / 2 = 2 + 73 = 75 | 74 | 62 - 48 = 14 / 2 = 7 + 48 = 55 | 65 | 72 | 71 | 66 | 64 | 63 | 61 | 60 | 70 | 68 | 59 | 58 | 57 | 56
    %tfMRI d118: 118 - 37 = 81 / 2 = 41 + 37 = 78 - 48 = 30 / 2 = 15 + 48 = 63 - 50 = 13 / 2 = 7 + 50 = 57 - 50 = 7 / 2 = 4 + 54 = 54 | 63 - 57 = 6 / 2 = 3 + 57 = 60 | 78 - 63 = 15 / 2 = 8 + 63 = 71 | 55 | 65 | 64 | 66 | 62 | 61 | 59 | 58 | 67 | 69 | 70 | 72 | 73 | 56
    %rfMRI d97: 97 - 57 = 40 / 2 = 20 + 57 = 77 - 61 = 16 / 2 = 8 + 61 = abs(69 - 77) = 8 / 2 = 4 + 69 = abs(73 - 77) = 4 / 2 = 2 + 73 = 75 | 76 | 78 | 74 | 79 | 80 | 72 | 71 | 70 | 68 | 81 | 82 | 83 | 84 | 85 | 86 | 87 | 88
    %rfMRI d139: 139 - 52 = 87 / 2 = 44 + 52 = 96 - 56 = 40 / 2 = 20 + 56 = 76 - 61 = 15 / 2 = 8 + 61 = abs(69 - 76) = 7 / 2 = 4 + 69 = 73 | 72 | 74 | 71 | 70 | 77 | 78 | 79 | 80 | 81 | 82 | 83 | 84 | 85 | 86 | 87 | 88

    %Old:
    %rfMRI: 84 - - > 76
    %tfMRI: 70 - - > 58
    %tfMRIr: 58 - - > 53

    %tICAdim = 61
    %tICAdim = 65
    %tICAdim = 81
    %tICAdim = 80

    %Reproduce normicasig: std((TCSFullConcat.cdata' * W')', [], 2);
    %Reproduce sICAtcs: std((normicasig' * A')', [], 2);




    tICAtcs = TCSFullConcat;
    tICAtcs.cdata = icasig'; %time X temporal ica
    tICAmix = A; %spatial ica X temporal ica
    %tICAunmix = W; %temporal ica X spatial ica (W = pinv(A))

    tICAMapsOne = sICAMapsOne;
    tICAMapsOne.cdata = sICAMapsOne.cdata * (tICAmix ./ repmat(mean(sICAtcsvars), size(A, 1), size(A, 2))); %grayordinates X spatial ica * spatial ica X temporal ica (undo overall effect of variance normalization on mixing matrix)

    tICAVolMapsOne = sICAVolMapsOne;
    tICAVolMapsOne.cdata = sICAVolMapsOne.cdata * (tICAmix ./ repmat(mean(sICAtcsvars), size(A, 1), size(A, 2))); %voxels X spatial ica * spatial ica X temporal ica (undo overall effect of variance normalization on mixing matrix)

    if ~isempty(StudyFolderTwo)
        tICAMapsTwo = sICAMapsTwo;
        tICAMapsTwo.cdata = sICAMapsTwo.cdata * (tICAmix ./ repmat(mean(sICAtcsvars), size(A, 1), size(A, 2))); %grayordinates X spatial ica * spatial ica X temporal ica (undo overall effect of variance normalization on mixing matrix)

        tICAVolMapsTwo = sICAVolMapsTwo;
        tICAVolMapsTwo.cdata = sICAVolMapsTwo.cdata * (tICAmix ./ repmat(mean(sICAtcsvars), size(A, 1), size(A, 2))); %voxels X spatial ica * spatial ica X temporal ica (undo overall effect of variance normalization on mixing matrix)
    end

    pos = max(tICAMapsOne.cdata) > abs(min(tICAMapsOne.cdata));
    neg = max(tICAMapsOne.cdata) < abs(min(tICAMapsOne.cdata));
    all = pos + neg * -1;


    tICAmix = tICAmix .* repmat(sign(all), size(tICAmix, 1), 1);
    %tICAunmix = (tICAunmix' .* repmat(sign(all), size(tICAmix, 1), 1))';
    tICAtcs.cdata = tICAtcs.cdata .* repmat(sign(all), size(tICAtcs.cdata, 1), 1);
    tICAMapsOne.cdata = tICAMapsOne.cdata .* repmat(sign(all), size(tICAMapsOne.cdata, 1), 1);
    tICAVolMapsOne.cdata = tICAVolMapsOne.cdata .* repmat(sign(all), size(tICAVolMapsOne.cdata, 1), 1);

    if ~isempty(StudyFolderTwo)
        tICAMapsTwo.cdata = tICAMapsTwo.cdata .* repmat(sign(all), size(tICAMapsTwo.cdata, 1), 1);
        tICAVolMapsTwo.cdata = tICAVolMapsTwo.cdata .* repmat(sign(all), size(tICAVolMapsTwo.cdata, 1), 1);
    end

    %[SSTDs SIs] = sort(std(tICAMapsOne.cdata, [], 1), 'descend'); %Sort based on tICA spatial maps spatial standard deviations
    [TSTDs TIs] = sort(std(tICAtcs.cdata, [], 1), 'descend'); %Sort based on unnormalized tICA temporal standard deviations

    %Is = SIs;
    Is = TIs;

    tICAPercentVariances = (((TSTDs .^ 2) / sum(TSTDs .^ 2)) * 100)';

    tICAtcs.cdata(:, [1:1:length(Is)]) = single(tICAtcs.cdata(:, Is));  
    tICAmix(:, [1:1:length(Is)]) = single(tICAmix(:, Is));
    %tICAunmix([1:1:length(Is)], :) = single(tICAunmix(Is, :));
    tICAunmix = pinv(tICAmix);
    tICAMapsOne.cdata(:, [1:1:length(Is)]) = single(tICAMapsOne.cdata(:, Is));
    tICAVolMapsOne.cdata(:, [1:1:length(Is)]) = single(tICAVolMapsOne.cdata(:, Is));

    if ~isempty(StudyFolderTwo)
        tICAMapsTwo.cdata(:, [1:1:length(Is)]) = single(tICAMapsTwo.cdata(:, Is));
        tICAVolMapsTwo.cdata(:, [1:1:length(Is)]) = single(tICAVolMapsTwo.cdata(:, Is));
    end

    iqsort = iq(Is);

    ciftisavereset(tICAMapsOne, [OutputFolderOne '/tICA_Maps_' num2str(tICAdim) '_' nlfunc IT '.dscalar.nii'], wbcommand);
    ciftisavereset(tICAVolMapsOne, [OutputFolderOne '/tICA_VolMaps_' num2str(tICAdim) '_' nlfunc IT '.dscalar.nii'], wbcommand);

    if ~isempty(StudyFolderTwo)
        ciftisavereset(tICAMapsTwo, [OutputFolderTwo '/tICA_Maps_' num2str(tICAdim) '_' nlfunc IT '.dscalar.nii'], wbcommand);
        ciftisavereset(tICAVolMapsTwo, [OutputFolderTwo '/tICA_VolMaps_' num2str(tICAdim) '_' nlfunc IT '.dscalar.nii'], wbcommand);
    end

    dlmwrite([OutputFolderOne '/melodic_mix_' num2str(tICAdim) '_' nlfunc IT], tICAmix, '\t');
    dlmwrite([OutputFolderOne '/melodic_unmix_' num2str(tICAdim) '_' nlfunc IT], tICAunmix, '\t');
    dlmwrite([OutputFolderOne '/stats_' num2str(tICAdim) '_' nlfunc IT '.wb_annsub.csv'], [round(iqsort, 2) round(tICAPercentVariances, 2)], ',');

    figs = findall(0, 'type', 'figure');
    for f = 1:length(figs)
      savefig(figs(f), [OutputFolderOne '/Figure' num2str(f) '_' num2str(tICAdim) '_' nlfunc IT]);
    end
    save([OutputFolderOne '/iq_' num2str(tICAdim) '_' nlfunc IT], 'iq', '-v7.3');
    save([OutputFolderOne '/sR_' num2str(tICAdim) '_' nlfunc IT], 'sR', '-v7.3');

    tICAtcs.cdata = tICAtcs.cdata';

    ciftisavereset(tICAtcs, [OutputFolderOne '/tICA_TCS_' num2str(tICAdim) '_' nlfunc IT '.sdseries.nii'], wbcommand);

    tICAtcsAll = reshape(tICAtcs.cdata, tICAdim, RunsXNumTimePoints, length(SubjFolderlist));

    tICAtcsmeanOne = TCSAVGOne;
    tICAtcsmeanOne.cdata = sum(tICAtcsAll .* single(TCSMask(1:tICAdim, :, :) == 1), 3) / s1;
    tICAtcsabsmeanOne = TCSABSAVGOne;
    tICAtcsabsmeanOne.cdata = sum(abs(tICAtcsAll .* single(TCSMask(1:tICAdim, :, :) == 1)), 3) / s1;

    if ~isempty(StudyFolderTwo)
        tICAtcsmeanTwo = TCSAVGTwo;
        tICAtcsmeanTwo.cdata = sum(tICAtcsAll .* single(TCSMask(1:tICAdim, :, :) == 2), 3) / s2;
        tICAtcsabsmeanTwo = TCSABSAVGTwo;
        tICAtcsabsmeanTwo.cdata = sum(abs(tICAtcsAll .* single(TCSMask(1:tICAdim, :, :) == 2)), 3) / s2;
    end

    ciftisavereset(tICAtcsmeanOne, [OutputFolderOne '/tICA_AVGTCS_' num2str(tICAdim) '_' nlfunc IT '.sdseries.nii'], wbcommand);
    ciftisavereset(tICAtcsabsmeanOne, [OutputFolderOne '/tICA_ABSAVGTCS_' num2str(tICAdim) '_' nlfunc IT '.sdseries.nii'], wbcommand);

    if ~isempty(StudyFolderTwo)
        ciftisavereset(tICAtcsmeanTwo, [OutputFolderTwo '/tICA_AVGTCS_' num2str(tICAdim) '_' nlfunc IT '.sdseries.nii'], wbcommand);
        ciftisavereset(tICAtcsabsmeanTwo, [OutputFolderTwo '/tICA_ABSAVGTCS_' num2str(tICAdim) '_' nlfunc IT '.sdseries.nii'], wbcommand);
    end

    tICAspectraOne = SpectraOne;
    tICAspectranormOne = SpectraOne;
    ts.Nnodes = tICAdim;
    ts.Nsubjects = s1;
    ts.NtimepointsPerSubject = RunsXNumTimePoints;
    ts.ts = (((tICAtcs.cdata .* single(TCSMaskConcat.cdata(1:tICAdim, :) == 1)) ./ s1) .* length(SubjlistOne))'; %compensate for the zeros by ratio of s1 to all subs?
    tICAspectraOne.cdata = nets_spectra_sp(ts)';
    tICAspectranormOne.cdata = nets_spectra_sp(ts, [], 1)';

    if ~isempty(StudyFolderTwo)
        tICAspectraTwo = SpectraTwo;
        tICAspectranormTwo = SpectraTwo;
        ts.Nnodes = tICAdim;
        ts.Nsubjects = s2;
        ts.NtimepointsPerSubject = RunsXNumTimePoints;
        ts.ts = (((tICAtcs.cdata .* single(TCSMaskConcat.cdata(1:tICAdim, :) == 2)) ./ s1) .* length(SubjlistOne))';
        tICAspectraTwo.cdata = nets_spectra_sp(ts)';
        tICAspectranormTwo.cdata = nets_spectra_sp(ts, [], 1)';
    end

    ciftisavereset(tICAspectraOne, [OutputFolderOne '/tICA_Spectra_' num2str(tICAdim) '_' nlfunc IT '.sdseries.nii'], wbcommand);
    ciftisavereset(tICAspectranormOne, [OutputFolderOne '/tICA_Spectra_norm_' num2str(tICAdim) '_' nlfunc IT '.sdseries.nii'], wbcommand);

    if ~isempty(StudyFolderTwo)
        ciftisavereset(tICAspectraTwo, [OutputFolderTwo '/tICA_Spectra_' num2str(tICAdim) '_' nlfunc IT '.sdseries.nii'], wbcommand);
        ciftisavereset(tICAspectranormTwo, [OutputFolderTwo '/tICA_Spectra_norm_' num2str(tICAdim) '_' nlfunc IT '.sdseries.nii'], wbcommand);
    end

    close all; 

end

for i = 1:length(SubjFolderlist)
    Subjlist{i}
    if exist([SubjFolderlist{i} '/MNINonLinear/fsaverage_LR' LowResMesh 'k/' Subjlist{i} '.' OutString '_' RegName '_ts.' LowResMesh 'k_fs_LR.sdseries.nii'])
        sICATCS = ciftiopen([SubjFolderlist{i} '/MNINonLinear/fsaverage_LR' LowResMesh 'k/' Subjlist{i} '.' OutString '_' RegName '_ts.' LowResMesh 'k_fs_LR.sdseries.nii'], 'wb_command');
        sICASpectra = ciftiopen([SubjFolderlist{i} '/MNINonLinear/fsaverage_LR' LowResMesh 'k/' Subjlist{i} '.' OutString '_' RegName '_spectra.' LowResMesh 'k_fs_LR.sdseries.nii'], 'wb_command');
        tICATCS = sICATCS;
        %tICATCS.cdata = pinv(tICAmix) * sICATCS.cdata;
        tICATCS.cdata = squeeze(tICAtcsAll(:, std(tICAtcsAll(:, :, i), [], 1) > 0, i));
        tICASpectra = sICASpectra;
        ciftisave(tICATCS, [SubjFolderlist{i} '/MNINonLinear/fsaverage_LR' LowResMesh 'k/' Subjlist{i} '.' OutString '_tICA_' RegName '_ts.' LowResMesh 'k_fs_LR.sdseries.nii'], 'wb_command');
        ts.Nnodes = size(tICATCS.cdata, 1);
        ts.Nsubjects = 1;
        ts.ts = tICATCS.cdata';
        ts.NtimepointsPerSubject = size(tICATCS.cdata, 2);
        tICASpectra.cdata = nets_spectra_sp(ts)';
        ciftisave(tICASpectra, [SubjFolderlist{i} '/MNINonLinear/fsaverage_LR' LowResMesh 'k/' Subjlist{i} '.' OutString '_tICA_' RegName '_spectra.' LowResMesh 'k_fs_LR.sdseries.nii'], 'wb_command');
    end
end

