function MIGP(StudyFolder, Subjlist, fMRINames, ProcSTRING, dPCAinternal, dPCAout, outputPCA)

    wbcommand = 'wb_command';
    Subjlist = myreadtext(Subjlist);

    vnsum = [];
    c = 1;
    for s = 1:length(Subjlist)
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
                grot = [grot demean(dtseries.cdata, 2) ./ repmat(max(vn.cdata, 0.001), 1, size(dtseries.cdata, 2))];
                vnsum = vnsum + vn.cdata;
                c = c + 1;
            end
        end
        if s == 1
            W = double(grot)'; clear grot;
        elseif s > 1
            W = [W; double(grot)']; clear grot;
            [uu, dd] = eigs(W * W', min(dPCAinternal, size(W, 1) - 1)); % reduce W to dPCAinternal eigenvectors
            W = uu' * W;
            clear uu dd;
        end
    end

    BO = dtseries;
    BO.cdata = single(W(1:min(dPCAout, size(W, 1) - 1), :)');
    ciftisavereset(BO, [outputPCA '_PCA.dtseries.nii'], wbcommand);
    VNMean = vn;
    VNMean.cdata = vnsum ./ c;
    ciftisavereset(VNMean, [outputPCA '_meanvn.dscalar.nii'], wbcommand);

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

