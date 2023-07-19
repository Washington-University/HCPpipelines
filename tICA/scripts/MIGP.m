function MIGP(StudyFolder, Subjlist, fMRINamesRaw, ProcSTRING, dPCAinternal, dPCAout, outputPCA, checkpointFile)
    
    %if isdeployed()
        %better solution for compiled matlab: *require* all arguments to be strings, so we don't have to build the argument list twice in the script
    %end
    dPCAinternal = str2double(dPCAinternal);
    dPCAout = str2double(dPCAout);
    
    wbcommand = 'wb_command';
    Subjlist = myreadtext(Subjlist);
    
    fMRINames = strsplit(fMRINamesRaw, '@');
    
    vnsum = [];
    c = 1;
    
    start = 1;
    if ~strcmp(checkpointFile, '')
        if exist(checkpointFile, 'file')
            prevstate = load(checkpointFile);
            if ~strcmp(prevstate.StudyFolder, StudyFolder)
                error('checkpoint file used a different StudyFolder, please relaunch with the original arguments or use a different checkpoint file');
            end
            if ~all(strcmp(prevstate.Subjlist, Subjlist))
                error('checkpoint file used a different subject list, please relaunch with the original arguments or use a different checkpoint file');
            end
            if ~all(strcmp(prevstate.fMRINames, fMRINames))
                error('checkpoint file used a different fMRINames list, please relaunch with the original arguments or use a different checkpoint file');
            end
            if ~strcmp(prevstate.ProcSTRING, ProcSTRING)
                error('checkpoint file used a different ProcSTRING, please relaunch with the original arguments or use a different checkpoint file');
            end
            if prevstate.dPCAinternal ~= dPCAinternal
                error('checkpoint file used a different dPCAinternal, please relaunch with the original arguments or use a different checkpoint file');
            end
            %don't check dPCAout, it isn't used until the entire process is completely done
            disp(['NOTICE: resuming computation from checkpoint file "' checkpointFile '"']);
            start = prevstate.s + 1;
            W = prevstate.W;
            vnsum = prevstate.vnsum;
            vn = prevstate.vn; %just so that it will still work to resume from after the final subject without loading vn from a subject
            clear prevstate;
        end
    end
    
    for s = start:length(Subjlist)
        s
        grot = [];
        for f = 1:length(fMRINames)
            dtseriesname = [StudyFolder '/' Subjlist{s} '/MNINonLinear/Results/' fMRINames{f} '/' fMRINames{f} ProcSTRING '.dtseries.nii'];
            vnname = [StudyFolder '/' Subjlist{s} '/MNINonLinear/Results/' fMRINames{f} '/' fMRINames{f} ProcSTRING '_vn.dscalar.nii'];
            if exist(dtseriesname, 'file')
                vn = ciftiopen(vnname, wbcommand);
                if isempty(vnsum)
                    vnsum = vn.cdata * 0;
                end
                dtseries = ciftiopen(dtseriesname, wbcommand);
                %FIXME: tICA cleanup appears to regress out dilated locations (from FoV issues), for now repurpose this divide-by-zero prevention to act like a stdev threshold
                %presumably the input data will always be scaled to grand mean 10,000
                grot = [grot demean(dtseries.cdata, 2) ./ repmat(max(vn.cdata, 10), 1, size(dtseries.cdata, 2))];
                vnsum = vnsum + vn.cdata;
                c = c + 1;
            else
                warning(['fmri run "' dtseriesname '" not found']);
            end
        end
        if s == 1
            W = double(grot)'; clear grot;
        elseif s > 1
            W = [W; double(grot)']; clear grot;
            [uu, ~] = eigs(W * W', min(dPCAinternal, size(W, 1) - 1)); % reduce W to dPCAinternal eigenvectors
            W = uu' * W;
            clear uu;
        end
        
        if ~strcmp(checkpointFile, '')
            try
                [filepath, ~, ~] = fileparts(checkpointFile);
                safefile = [tempname(filepath) '.mat']; %save would add .mat, but movefile doesn't
                %also save all the arguments that change the contents of the outputs, for sanity checking and provenance
                save(safefile, 'W', 'vnsum', 'vn', 's', 'StudyFolder', 'Subjlist', 'fMRINames', 'ProcSTRING', 'dPCAinternal', 'dPCAout', '-v7.3');
                status = movefile(safefile, checkpointFile, 'f');
                if status == 0
                    warning('failed to move checkpoint file from temp name to final name');
                end
            catch
                warning('failed to save to checkpoint file');
            end
        end
    end

    BO = dtseries;
    BO.cdata = single(W(1:min(dPCAout, size(W, 1) - 1), :)');
    ciftisavereset(BO, [outputPCA '_PCA.dtseries.nii'], wbcommand);
    VNMean = vn;
    VNMean.cdata = vnsum ./ c;
    ciftisavereset(VNMean, [outputPCA '_meanvn.dscalar.nii'], wbcommand);
    
    if ~strcmp(checkpointFile, '')
        mydelete(checkpointFile);
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

function mydelete(filename)
    %fix matlab's "error if doesn't exist" and braindead "send to recycling based on preference" misfeatures
    if exist(filename, 'file')
        recstatus = recycle();
        cleanupObj = onCleanup(@()(recycle(recstatus)));
        recycle('off');
        delete(filename);
    end
end

