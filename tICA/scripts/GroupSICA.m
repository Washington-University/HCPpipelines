function GroupSICA(indata, indatavn, OutFolder, wfoutname, numWisharts, dimList, icadimIters, icadimOverride)
    
    %if isdeployed()
        %better solution for compiled matlab: *require* all arguments to be strings, so we don't have to build the argument list twice in the script
    %end
    numWisharts = str2double(numWisharts);
    dimList = str2num(dimList); %list, and str2double expects scalar
    icadimIters = str2double(icadimIters);
    icadimOverride = str2double(icadimOverride);
    
    cii = ciftiopen(indata, 'wb_command');
    vn = ciftiopen(indatavn, 'wb_command');
    Out = icaDim(cii.cdata, -1, 1, icadimIters, numWisharts);
    if icadimOverride > 0
        Out.calcDim = icadimOverride;
    end
    disp(['Out.calcDim (after possible override): ' num2str(Out.calcDim)]);
    [status, msg] = mkdir(OutFolder);
    if status == 0
    	error(['failed to create ' OutFolder ' because of ' msg]);
    end
    [fid, msg] = fopen([OutFolder '/most_recent_dim.txt'], 'w');
    if fid < 0
    	error(['failed to write to "' OutFolder '/most_recent_dim.txt" because of ' msg]);
    end
    byteswritten = fprintf(fid, '%i', Out.calcDim);
    fclose(fid);
    if byteswritten < 1
        error(['failed to write to "' OutFolder '/most_recent_dim.txt"']);
    end
    cii.cdata = [];
    newcii = cii;
    newcii.cdata = Out.data;
    ciftisave(newcii, wfoutname, 'wb_command');

    mkdir(OutFolder);
    
    for i = dimList(:)'
        myprocess(i, Out, vn, OutFolder, cii);
    end
    
    myprocess(Out.calcDim, Out, vn, OutFolder, cii);
end

function myprocess(ICAdim, Out, vn, OutFolder, cii)
    disp(['Out.data size: ' num2str(size(Out.data))]);
    disp(['ICAdim: ' num2str(ICAdim)]);
    [iq, A, W, S, sR] = icasso('both', Out.data', 100, 'approach', 'symm', 'g', 'pow3', 'lastEig', ICAdim, 'numOfIC', ICAdim, 'maxNumIterations', 1000); 
    [S_final, A_final, W_final] = fastica(Out.data', 'initGuess', A, 'approach', 'symm', 'g', 'pow3', 'lastEig', ICAdim, 'numOfIC', ICAdim, 'displayMode', 'off', 'maxNumIterations', 1000);

    tSTDs = std(A_final);
    pos = max(S_final') > abs(min(S_final'));
    neg = max(S_final') < abs(min(S_final'));
    All = pos + neg * -1;
    S_final = S_final' .* repmat(sign(All), size(S_final', 1), 1);
    [~, Is] = sort(tSTDs, 'descend');
    S_final(:, [1:1:length(Is)]) = single(S_final(:, Is));
    A_final = A_final .* repmat(sign(All), size(A_final, 1), 1);
    A_final(:, [1:1:length(Is)]) = single(A_final(:, Is));
    W_final = pinv(A_final);
    iq = iq(Is);
    new_cii = cii;
    new_cii.cdata = S_final;
    ciftisavereset(new_cii, [OutFolder '/melodic_oIC_' num2str(ICAdim) '.dscalar.nii'], 'wb_command');
    new_cii.cdata = S_final .* (repmat(vn.cdata, 1, ICAdim) ./ mean(vn.cdata));
    ciftisavereset(new_cii, [OutFolder '/melodic_oIC_' num2str(ICAdim) '_norm.dscalar.nii'], 'wb_command');

    dlmwrite([OutFolder '/melodic_mix_' num2str(ICAdim)], A_final, '\t');
    dlmwrite([OutFolder '/melodic_unmix_' num2str(ICAdim)], W_final, '\t');
    dlmwrite([OutFolder '/iq_' num2str(ICAdim) '.wb_annsub.csv'], round(iq, 2), ',');
    
    save([OutFolder '/iq_' num2str(ICAdim)], 'iq', '-v7.3');
    save([OutFolder '/sR_' num2str(ICAdim)], 'sR', '-v7.3');
    save([OutFolder '/Out_' num2str(ICAdim)], 'Out', '-v7.3');

    %TSC: this may be a problem for compiled, -nodisplay, or octave
    figs = findall(0, 'type', 'figure');
    for f = 1:length(figs)
        savefig(figs(f), [OutFolder '/Figure_' num2str(ICAdim) '_' num2str(f)]);
    end
    close all
end

