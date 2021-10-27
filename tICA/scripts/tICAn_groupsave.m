
%remove two-study-folder stuff everywhere, maybe rework input reshaping

c = 1;
SubjFolderlist = {};
Subjlist = {};
StudyFolderNumber = [];
for i = 1:length(SubjlistOne)
    SubjFolderlist{c} = [StudyFolderOne '/' SubjlistOne{i}];
    Subjlist{c} = SubjlistOne{i};
    StudyFolderNumber = [StudyFolderNumber 1];
    c = c + 1;
end

LowResMesh = '32';
wbcommand = 'wb_command';
RegName = 'MSMAll';

%load data
s1 = 0;

m1 = 0;

TCSAll = single(zeros(sICAdim, RunsXNumTimePoints, length(SubjFolderlist)));
SpectraOne = [];
sICAMapsOne = [];
sICAVolMapsOne = [];
for i = 1:length(SubjFolderlist)
    Subjlist{i}
    if exist([SubjFolderlist{i} '/MNINonLinear/fsaverage_LR' LowResMesh 'k/' Subjlist{i} '.' OutString '_' RegName '_ts.' LowResMesh 'k_fs_LR.sdseries.nii'])
        sICAMapsSub = ciftiopen([SubjFolderlist{i} '/MNINonLinear/fsaverage_LR' LowResMesh 'k/' Subjlist{i} '.' OutString '_' RegName '.' LowResMesh 'k_fs_LR.dscalar.nii'], wbcommand);
        sICAVolMapsSub = ciftiopen([SubjFolderlist{i} '/MNINonLinear/fsaverage_LR' LowResMesh 'k/' Subjlist{i} '.' OutString '_' RegName '_vol.' LowResMesh 'k_fs_LR.dscalar.nii'], wbcommand);
        TCSSub = ciftiopen([SubjFolderlist{i} '/MNINonLinear/fsaverage_LR' LowResMesh 'k/' Subjlist{i} '.' OutString '_' RegName '_ts.' LowResMesh 'k_fs_LR.sdseries.nii'], wbcommand);
        SpectraSub = ciftiopen([SubjFolderlist{i} '/MNINonLinear/fsaverage_LR' LowResMesh 'k/' Subjlist{i} '.' OutString '_' RegName '_spectra.' LowResMesh 'k_fs_LR.sdseries.nii'], wbcommand);
        TCSAll(1:size(TCSSub.cdata, 1), 1:size(TCSSub.cdata, 2), i) = TCSSub.cdata;
        
        sICAVolMapsSub.cdata(isinf(sICAVolMapsSub.cdata) | isnan(sICAVolMapsSub.cdata)) = 0;
        
        if length(TCSSub.cdata) == RunsXNumTimePoints
            if isempty(SpectraOne)
                SpectraOne = SpectraSub;
                SpectraOne.cdata = SpectraSub.cdata * 0;
            end
            SpectraOne.cdata = SpectraOne.cdata + SpectraSub.cdata;
            s1 = s1 + 1;
        end
        if isempty(sICAMapsOne)
            sICAMapsOne = sICAMapsSub;
            sICAMapsOne.cdata = sICAMapsSub.cdata * 0;
            sICAVolMapsOne = sICAVolMapsSub;
            sICAVolMapsOne.cdata = sICAVolMapsSub.cdata * 0;
        end
        sICAMapsOne.cdata = sICAMapsOne.cdata + sICAMapsSub.cdata;
        sICAVolMapsOne.cdata = sICAVolMapsOne.cdata + sICAVolMapsSub.cdata;
        m1 = m1 + 1;

    end 
end

%TCSAll could be zero-padded in sICA, is zero-padded in concatenated timepoints, 3D in subjects
%collapse timepoints and subjects and save
%TCSMask isn't needed without multi-study-folder support

TCSFullConcat = TCSSub;
TCSFullConcat.cdata = reshape(TCSAll, sICAdim, RunsXNumTimePoints * length(SubjFolderlist)); %these did a squeeze too?

%group sica
ciftisavereset(TCSFullConcat, [OutputFolderOne '/sICA_TCS_' num2str(sICAdim) '.sdseries.nii'], wbcommand);

sICATSTDs = std(TCSFullConcat.cdata, [], 2);
sICAPercentVariances = ((sICATSTDs .^ 2) / sum(sICATSTDs .^ 2)) * 100;
sICAiq = load(InputStats);

dlmwrite([OutputFolderOne '/sICA_stats_' num2str(sICAdim) '.wb_annsub.csv'], [round(sICAiq, 2) round(sICAPercentVariances, 2)], ',');


TCSAVGOne = TCSSub;
TCSAVGOne.cdata = sum(TCSAll, 3) / s1; %wrong - across FULL TIMESERIES subjects
TCSABSAVGOne = TCSSub;
TCSABSAVGOne.cdata = sum(abs(TCSAll), 3) / s1;%

SpectraOne.cdata = SpectraOne.cdata / s1;%
sICAMapsOne.cdata = sICAMapsOne.cdata / m1;
sICAVolMapsOne.cdata = sICAVolMapsOne.cdata / m1;

ciftisavereset(TCSAVGOne, [OutputFolderOne '/sICA_AVGTCS_' num2str(sICAdim) '.sdseries.nii'], wbcommand);
ciftisavereset(TCSABSAVGOne, [OutputFolderOne '/sICA_ABSAVGTCS_' num2str(sICAdim) '.sdseries.nii'], wbcommand);

ciftisavereset(SpectraOne, [OutputFolderOne '/sICA_Spectra_' num2str(sICAdim) '.sdseries.nii'], wbcommand);
ciftisavereset(sICAMapsOne, [OutputFolderOne '/sICA_Maps_' num2str(sICAdim) '.dscalar.nii'], wbcommand);
ciftisavereset(sICAVolMapsOne, [OutputFolderOne '/sICA_VolMaps_' num2str(sICAdim) '.dscalar.nii'], wbcommand);

%end group sica

