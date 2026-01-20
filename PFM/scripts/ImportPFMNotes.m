function ImportPFMNotes(StudyFolder, SubjListRaw, fMRIListRaw, ConcatName, fMRIProcSTRING, OutputfMRIName, OutputSTRING, OutputPrefix, RegString, LowResMesh, TR, PFMFolder)
    
    Subjlist = strsplit(SubjListRaw, '@');
    fMRINames = strsplit(fMRIListRaw, '@');
    TR = str2double(TR);
    wbcommand = 'wb_command';
    
    for s = 1:length(Subjlist)
        s
        subfMRINames = {};
        if ~strcmp(ConcatName, '')
            if exist([StudyFolder '/' Subjlist{s} '/MNINonLinear/Results/' ConcatName '/' ConcatName fMRIProcSTRING '.dtseries.nii'])
                c = 1;
                for r = 1:length(fMRINames)
                    if exist([StudyFolder '/' Subjlist{s} '/MNINonLinear/Results/' fMRINames{r} '/' fMRINames{r} fMRIProcSTRING '.dtseries.nii'])
                        subfMRINames{c} = fMRINames{r};
                        c = c + 1;
                    end
                end            
            end
        else
            c = 1;
            for r = 1:length(fMRINames)
                if exist([StudyFolder '/' Subjlist{s} '/MNINonLinear/Results/' fMRINames{r} '/' fMRINames{r} fMRIProcSTRING '.dtseries.nii'])
                    subfMRINames{c} = fMRINames{r};
                    c = c + 1;
                end
            end                    
        end
        
        if length(subfMRINames) ~= 0
            origTCS = [];
            TCS = [];
            for r = 1:length(subfMRINames)
                runTCS = load([PFMFolder '/Results.ppp/TimeCourses/sub-' Subjlist{s} '_run-' subfMRINames{r} '.csv']);
                runAmp = load([PFMFolder '/Results.ppp/Amplitudes/sub-' Subjlist{s} '_run-' subfMRINames{r} '.csv']);

                origTCS = [origTCS ; runTCS];
                TCS = [TCS ; runTCS .* repmat(runAmp', length(runTCS), 1)];
            end
            
            % sICATCS = ciftiopen([StudyFolder '/' Subjlist{s} '/MNINonLinear/fsaverage_LR' LowResMesh 'k/' Subjlist{s} '.' OutputfMRIName OutputSTRING RegString '_ts.' LowResMesh 'k_fs_LR.sdseries.nii'], wbcommand);
            % sICASpectra = ciftiopen([StudyFolder '/' Subjlist{s} '/MNINonLinear/fsaverage_LR' LowResMesh 'k/' Subjlist{s} '.' OutputfMRIName OutputSTRING RegString '_spectra.' LowResMesh 'k_fs_LR.sdseries.nii'], wbcommand);
     
            PFMTCSorig = cifti_struct_create_sdseries(origTCS','step',TR);
            % PFMTCSorig.diminfo{1,2} = sICATCS.diminfo{1,2};
            ts.Nnodes = size(origTCS, 2);
            ts.Nsubjects = 1;
            ts.ts = origTCS;
            ts.NtimepointsPerSubject = size(origTCS, 1);
            PFMSpectraorig = cifti_struct_create_sdseries(nets_spectra_sp(ts)','step',1/TR);
            % PFMSpectraorig.diminfo{1,2} = sICASpectra.diminfo{1,2};
             
            PFMTCS = cifti_struct_create_sdseries(TCS');
            % PFMTCS.diminfo{1,2} = sICATCS.diminfo{1,2};       
            ts.Nnodes = size(TCS, 2);
            ts.Nsubjects = 1;
            ts.ts = TCS;
            ts.NtimepointsPerSubject = size(TCS, 1);
            PFMSpectra = cifti_struct_create_sdseries(nets_spectra_sp(ts)','step',1/TR);
            % PFMSpectra.diminfo{1,2} = sICASpectra.diminfo{1,2};

            ciftisave(PFMTCSorig, [StudyFolder '/' Subjlist{s} '/MNINonLinear/fsaverage_LR' LowResMesh 'k/' Subjlist{s} '.' OutputPrefix RegString '_ts_orig.' LowResMesh 'k_fs_LR.sdseries.nii'], wbcommand);
            ciftisave(PFMSpectraorig, [StudyFolder '/' Subjlist{s} '/MNINonLinear/fsaverage_LR' LowResMesh 'k/' Subjlist{s} '.' OutputPrefix RegString '_spectra_orig.' LowResMesh 'k_fs_LR.sdseries.nii'], wbcommand);

            ciftisave(PFMTCS, [StudyFolder '/' Subjlist{s} '/MNINonLinear/fsaverage_LR' LowResMesh 'k/' Subjlist{s} '.' OutputPrefix RegString '_ts.' LowResMesh 'k_fs_LR.sdseries.nii'], wbcommand);
            ciftisave(PFMSpectra, [StudyFolder '/' Subjlist{s} '/MNINonLinear/fsaverage_LR' LowResMesh 'k/' Subjlist{s} '.' OutputPrefix RegString '_spectra.' LowResMesh 'k_fs_LR.sdseries.nii'], wbcommand);

            copyfile([PFMFolder '/Results.ppp/Maps/sub-' Subjlist{s} '.dscalar.nii'], [StudyFolder '/' Subjlist{s} '/MNINonLinear/fsaverage_LR' LowResMesh 'k/' Subjlist{s} '.' OutputPrefix RegString '_origmaps.' LowResMesh 'k_fs_LR.dscalar.nii']);
        end
    end
end