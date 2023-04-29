function ComputeDVARSandGS(StudyFolder,Subjlist, hp, MRFixConcatName, fMRINames, RegString, ProcString, RecleanMode)
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here
wbcommand='wb_command';
if strcmp(RecleanMode,"YES")
    rclean=1;
elseif strcmp(RecleanMode,"NO")
    rclean=0;
else
    error("RecleanMode specified as wrong state");
end

for i=1:length(Subjlist)
    %i
    SubjFolder=[StudyFolder '/' Subjlist{i}];
    if ~strcmp(MRFixConcatName,'')
         RunStarts=[1];
         RunEnds=[0];
         r=1;
         for j=1:length(fMRINames)
             if exist([SubjFolder '/MNINonLinear/Results/' fMRINames{j} '/' fMRINames{j} '_Atlas' RegString '.dtseries.nii'],'file')
                 [~, Val]=unix(['wb_command -file-information ' SubjFolder '/MNINonLinear/Results/' fMRINames{j} '/' fMRINames{j} '_Atlas' RegString '.dtseries.nii -only-number-of-maps']);
                 RunStarts=[RunStarts RunStarts(r)+str2num(Val)];
                 RunEnds=[RunEnds RunEnds(r) + str2num(Val)];
                 r=r+1;
             end
         end
         RunStarts=RunStarts(1:end-1);
         RunEnds=RunEnds(2:end);
         OrigfMRINames=fMRINames; fMRINames={}; fMRINames{1}=MRFixConcatName;
    else
        RunStarts=[1];
    end
    for j=1:length(fMRINames)
        if exist([SubjFolder '/MNINonLinear/Results/' fMRINames{j} '/' fMRINames{j} '_hp' hp '.ica/Signal.txt'],'file')
            sICA=load([SubjFolder '/MNINonLinear/Results/' fMRINames{j} '/' fMRINames{j} '_hp' hp '.ica/filtered_func_data.ica/melodic_mix']);
            %sICA_table=readtable([SubjFolder '/MNINonLinear/Results/' fMRINames{j} '/' fMRINames{j} '_hp' hp '.ica/filtered_func_data.ica/melodic_mix']);
            %sICA=sICA_table{:,:};
            %sICA(find(isnan(sICA)))=0;
            if rclean==1
                Signal=load([SubjFolder '/MNINonLinear/Results/' fMRINames{j} '/' fMRINames{j} '_hp' hp '.ica/ReCleanSignal.txt']);
            else
                Signal=load([SubjFolder '/MNINonLinear/Results/' fMRINames{j} '/' fMRINames{j} '_hp' hp '.ica/Signal.txt']);
            end
            file_name=[SubjFolder '/MNINonLinear/Results/' fMRINames{j} '/' fMRINames{j} '_Atlas' RegString ProcString '.dtseries.nii'];
            CIFTIDenseTimeSeries=ciftiopen(file_name,wbcommand);
            TR = CIFTIDenseTimeSeries.diminfo{2}.seriesStep;
            CIFTIDenseTimeSeries.cdata=demean(CIFTIDenseTimeSeries.cdata,2);
            BetaICA=pinv(normalise(sICA(:,Signal)))*CIFTIDenseTimeSeries.cdata';
            CIFTIDenseTimeSeriesSignalsICA=(sICA(:,Signal)*BetaICA)';
            CIFTIDenseTimeseriesUnstructuredNoise=CIFTIDenseTimeSeries.cdata-CIFTIDenseTimeSeriesSignalsICA;

            GS=mean(CIFTIDenseTimeSeries.cdata)';
            GSsICA=mean(CIFTIDenseTimeSeriesSignalsICA)';
            GSUnstruct=mean(CIFTIDenseTimeseriesUnstructuredNoise)';

            DVARS=[0;rms(diff(transpose(CIFTIDenseTimeSeries.cdata)),2)]; 
            DVARSsICA=[0;rms(diff(transpose(CIFTIDenseTimeSeriesSignalsICA)),2)]; 
            DVARSUnstruct=[0;rms(diff(transpose(CIFTIDenseTimeseriesUnstructuredNoise)),2)]; 

            cDVARS=[0;rms(diff(transpose(CIFTIDenseTimeSeries.cdata(1:59412,:))),2)]; 
            cDVARSsICA=[0;rms(diff(transpose(CIFTIDenseTimeSeriesSignalsICA(1:59412,:))),2)]; 
            cDVARSUnstruct=[0;rms(diff(transpose(CIFTIDenseTimeseriesUnstructuredNoise(1:59412,:))),2)]; 

            if ~strcmp(MRFixConcatName,'')
                MedianDV=[0 0 0 0 0 0];
                for k=1:length(RunStarts)
                    MedianDV(1)=MedianDV(1) + median(DVARS(RunStarts(k):RunEnds(k)));
                    MedianDV(2)=MedianDV(2) + median(DVARSsICA(RunStarts(k):RunEnds(k)));
                    MedianDV(3)=MedianDV(3) + median(DVARSUnstruct(RunStarts(k):RunEnds(k)));
                    MedianDV(4)=MedianDV(4) + median(cDVARS(RunStarts(k):RunEnds(k)));
                    MedianDV(5)=MedianDV(5) + median(cDVARSsICA(RunStarts(k):RunEnds(k)));
                    MedianDV(6)=MedianDV(6) + median(cDVARSUnstruct(RunStarts(k):RunEnds(k)));
                    DVARS(RunStarts(k):RunEnds(k))=DVARS(RunStarts(k):RunEnds(k))-median(DVARS(RunStarts(k):RunEnds(k)));
                    DVARSsICA(RunStarts(k):RunEnds(k))=DVARSsICA(RunStarts(k):RunEnds(k))-median(DVARSsICA(RunStarts(k):RunEnds(k)));
                    DVARSUnstruct(RunStarts(k):RunEnds(k))=DVARSUnstruct(RunStarts(k):RunEnds(k))-median(DVARSUnstruct(RunStarts(k):RunEnds(k)));
                    cDVARS(RunStarts(k):RunEnds(k))=cDVARS(RunStarts(k):RunEnds(k))-median(cDVARS(RunStarts(k):RunEnds(k)));
                    cDVARSsICA(RunStarts(k):RunEnds(k))=cDVARSsICA(RunStarts(k):RunEnds(k))-median(cDVARSsICA(RunStarts(k):RunEnds(k)));
                    cDVARSUnstruct(RunStarts(k):RunEnds(k))=cDVARSUnstruct(RunStarts(k):RunEnds(k))-median(cDVARSUnstruct(RunStarts(k):RunEnds(k)));
                end
                MedianDV=MedianDV./length(RunStarts);
            else
                MedianDV(1)=median(DVARS);
                MedianDV(2)=median(DVARSsICA);
                MedianDV(3)=median(DVARSUnstruct);
                MedianDV(4)=median(cDVARS);
                MedianDV(5)=median(cDVARSsICA);
                MedianDV(6)=median(cDVARSUnstruct);
                DVARS=DVARS-median(DVARS);
                DVARSsICA=DVARSsICA-median(DVARSsICA);
                DVARSUnstruct=DVARSUnstruct-median(DVARSUnstruct);
                cDVARS=cDVARS-median(cDVARS);
                cDVARSsICA=cDVARSsICA-median(cDVARSsICA);
                cDVARSUnstruct=cDVARSUnstruct-median(cDVARSUnstruct);
            end

            DVARS(RunStarts)=0;
            DVARSsICA(RunStarts)=0;
            DVARSUnstruct(RunStarts)=0;
            cDVARS(RunStarts)=0;
            cDVARSsICA(RunStarts)=0;
            cDVARSUnstruct(RunStarts)=0;

            CIFTIGS=cifti_struct_create_sdseries([GS GSsICA GSUnstruct]','step',TR,'namelist',{'GS';'GSsICA';'GSUnstruct'});
            CIFTIDVARS=cifti_struct_create_sdseries([DVARS DVARSsICA DVARSUnstruct cDVARS cDVARSsICA cDVARSUnstruct]','step',TR,'namelist',{'DVARS';'DVARSsICA';'DVARSUnstruct';'CorticalDVARS';'CorticalDVARSsICA';'CorticalDVARSUnstruct'});
            %CIFTIGS=cifti_struct_create_sdseries([GS(1:size(a,2)) GSsICA(1:size(a,2)) GSUnstruct(1:size(a,2))]','step',TR,'namelist',{'GS';'GSsICA';'GSUnstruct'});
            %CIFTIDVARS=cifti_struct_create_sdseries([DVARS(1:size(a,2)) DVARSsICA(1:size(a,2)) DVARSUnstruct(1:size(a,2)) cDVARS(1:size(a,2)) cDVARSsICA(1:size(a,2)) cDVARSUnstruct(1:size(a,2))]','step',TR,'namelist',{'DVARS';'DVARSsICA';'DVARSUnstruct';'CorticalDVARS';'CorticalDVARSsICA';'CorticalDVARSUnstruct'});

            ciftisave(CIFTIGS,[SubjFolder '/MNINonLinear/Results/' fMRINames{j} '/' fMRINames{j} '_Atlas' RegString ProcString '_GS.sdseries.nii'],'wb_command');
            ciftisave(CIFTIDVARS,[SubjFolder '/MNINonLinear/Results/' fMRINames{j} '/' fMRINames{j} '_Atlas' RegString ProcString '_DVARS.sdseries.nii'],'wb_command');

            dlmwrite([SubjFolder '/MNINonLinear/Results/' fMRINames{j} '/' fMRINames{j} '_Atlas' RegString ProcString '_DVARS_Medians.txt'],MedianDV,'\t');

            %unix(['rm ' SubjFolder '/MNINonLinear/Results/' fMRINames{j} '/' fMRINames{j} '_Atlas_hp' hp '_clean_rclean_GS.sdseries.nii']);
            %unix(['rm ' SubjFolder '/MNINonLinear/Results/' fMRINames{j} '/' fMRINames{j} '_Atlas_hp' hp '_clean_rclean_DVARS.sdseries.nii']);
        end
    end
    if ~strcmp(MRFixConcatName,'')
        fMRINames=OrigfMRINames;
    end
    %c=c+1;
end


end

