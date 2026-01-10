function PFMNotesGroup(StudyFolder, SubjListRaw, GroupAverageName, OutputfMRIName, PFMdimStr, OutputPrefix, RegString, LowResMesh, RunsXNumTimePointsStr, CIFTIVerticesStr, CIFTIVolumeStr, PFMFolder)
    
    % Parse string inputs
    Subjlist = strsplit(SubjListRaw, '@');
    PFMdim = str2double(PFMdimStr);
    RunsXNumTimePoints = str2double(RunsXNumTimePointsStr);
    CIFTI = str2double(CIFTIVerticesStr);
    CIFTIVol = str2double(CIFTIVolumeStr);
    
    wbcommand = 'wb_command';
    
    c = 1;
    SubjFolderlist = {};
    StudyFolderNumber = [];
    for i = 1:length(Subjlist)
        SubjFolderlist{c} = [StudyFolder '/' Subjlist{i}];
        StudyFolderNumber = [StudyFolderNumber 1];
        c = c + 1;
    end

    for i = 1:length(Subjlist)
        if ~isfile([StudyFolder '/' Subjlist{i} '/MNINonLinear/fsaverage_LR' LowResMesh 'k/' Subjlist{i} '.' OutputPrefix '_DR' RegString '.' LowResMesh 'k_fs_LR.dscalar.nii'])
            Subjlist{i}
        end
    end

    s1 = 0;
    m1 = 0;
    TCSMask = zeros(PFMdim, RunsXNumTimePoints, length(SubjFolderlist), 'single');
    TCSAll = zeros(PFMdim, RunsXNumTimePoints, length(SubjFolderlist), 'single');
    SpectraOne = [];
    PFMMapsOne = [];
    PFMVolMapsOne = [];
    
    for i = 1:length(SubjFolderlist)
        Subjlist{i}
        if exist([SubjFolderlist{i} '/MNINonLinear/fsaverage_LR' LowResMesh 'k/' Subjlist{i} '.' OutputPrefix RegString '_ts.' LowResMesh 'k_fs_LR.sdseries.nii'])
            PFMMapsSub = ciftiopen([SubjFolderlist{i} '/MNINonLinear/fsaverage_LR' LowResMesh 'k/' Subjlist{i} '.' OutputPrefix '_DR' RegString '.' LowResMesh 'k_fs_LR.dscalar.nii'], wbcommand);
            PFMVolMapsSub = ciftiopen([SubjFolderlist{i} '/MNINonLinear/fsaverage_LR' LowResMesh 'k/' Subjlist{i} '.' OutputPrefix '_DR' RegString '_vol.' LowResMesh 'k_fs_LR.dscalar.nii'], wbcommand);
            TCSSub = ciftiopen([SubjFolderlist{i} '/MNINonLinear/fsaverage_LR' LowResMesh 'k/' Subjlist{i} '.' OutputPrefix RegString '_ts.' LowResMesh 'k_fs_LR.sdseries.nii'], wbcommand);
            SpectraSub = ciftiopen([SubjFolderlist{i} '/MNINonLinear/fsaverage_LR' LowResMesh 'k/' Subjlist{i} '.' OutputPrefix RegString '_spectra.' LowResMesh 'k_fs_LR.sdseries.nii'], wbcommand);
            TCSAll(1:size(TCSSub.cdata,1), 1:size(TCSSub.cdata,2), i) = TCSSub.cdata;
            
            PFMVolMapsSub.cdata(isinf(PFMVolMapsSub.cdata)) = NaN;
            PFMVolMapsSub.cdata(isnan(PFMVolMapsSub.cdata)) = 0;
            
            RANK(i) = rank(TCSSub.cdata);
            COND(i) = cond(TCSSub.cdata);
            
            if StudyFolderNumber(i) == 1
                if length(TCSSub.cdata) == RunsXNumTimePoints
                    TCSMask(:, :, i) = repmat(1, PFMdim, RunsXNumTimePoints, 1);
                    if isempty(SpectraOne)
                        SpectraOne = SpectraSub;
                        SpectraOne.cdata = SpectraSub.cdata * 0;
                    end
                    SpectraOne.cdata = SpectraOne.cdata + SpectraSub.cdata;
                    s1 = s1 + 1;
                end
                if isempty(PFMMapsOne)
                    PFMMapsOne = PFMMapsSub;
                    PFMMapsOne.cdata = PFMMapsSub.cdata * 0;
                    PFMVolMapsOne = PFMVolMapsSub;
                    PFMVolMapsOne.cdata = PFMVolMapsSub.cdata * 0;
                end
                PFMMapsOne.cdata = PFMMapsOne.cdata + PFMMapsSub.cdata;
                PFMVolMapsOne.cdata = PFMVolMapsOne.cdata + PFMVolMapsSub.cdata;
                m1 = m1 + 1;
            end
        end 
    end

    TCSMaskConcat = TCSSub;
    TCSMaskConcat.cdata = squeeze(reshape(TCSMask, PFMdim, RunsXNumTimePoints * length(SubjFolderlist)));
    TCSFullConcat = TCSSub;
    TCSFullConcat.cdata = squeeze(reshape(TCSAll, PFMdim, RunsXNumTimePoints * length(SubjFolderlist)));
    ciftisavereset(TCSMaskConcat, [PFMFolder '/PFM_TCSMASK_' num2str(PFMdim) '.sdseries.nii'], wbcommand);
    ciftisavereset(TCSFullConcat, [PFMFolder '/PFM_TCS_' num2str(PFMdim) '.sdseries.nii'], wbcommand);

    PFMTSTDs = std(TCSFullConcat.cdata, [], 2);
    PFMPercentVariances = (((PFMTSTDs .^ 2) / sum(PFMTSTDs .^ 2)) * 100);
    dlmwrite([PFMFolder '/PFM_stats_' num2str(PFMdim) '.wb_annsub.csv'], [round(PFMPercentVariances, 2)], ',');

    TCSAVGOne = TCSSub;
    TCSAVGOne.cdata = sum(TCSAll .* single(TCSMask == 1), 3) / s1;
    TCSABSAVGOne = TCSSub;
    TCSABSAVGOne.cdata = sum(abs(TCSAll .* single(TCSMask == 1)), 3) / s1;

    SpectraOne.cdata = SpectraOne.cdata / s1;
    PFMMapsOne.cdata = PFMMapsOne.cdata / m1;
    PFMVolMapsOne.cdata = PFMVolMapsOne.cdata / m1;

    ciftisavereset(TCSAVGOne, [PFMFolder '/PFM_AVGTCS_' num2str(PFMdim) '.sdseries.nii'], wbcommand);
    ciftisavereset(TCSABSAVGOne, [PFMFolder '/PFM_ABSAVGTCS_' num2str(PFMdim) '.sdseries.nii'], wbcommand);

    ciftisavereset(SpectraOne, [PFMFolder '/PFM_Spectra_' num2str(PFMdim) '.sdseries.nii'], wbcommand);
    ciftisavereset(PFMMapsOne, [PFMFolder '/PFM_Maps_' num2str(PFMdim) '.dscalar.nii'], wbcommand);
    ciftisavereset(PFMVolMapsOne, [PFMFolder '/PFM_VolMaps_' num2str(PFMdim) '.dscalar.nii'], wbcommand);
end