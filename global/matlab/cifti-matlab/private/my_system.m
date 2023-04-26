function my_system(command)
    %like call_fsl, but without sourcing fslconf
    if ismac()
        ldsave = getenv('DYLD_LIBRARY_PATH');
    else
        ldsave = getenv('LD_LIBRARY_PATH');
    end
    %restore it even if we are interrupted
    function cleanupFunc(ldsave)
        if ismac()
            setenv('DYLD_LIBRARY_PATH', ldsave);
        else
            setenv('LD_LIBRARY_PATH', ldsave);
        end
    end
    guardObj = onCleanup(@() cleanupFunc(ldsave));
    if ismac()
        setenv('DYLD_LIBRARY_PATH');
    else
        setenv('LD_LIBRARY_PATH');
    end
    if system(command) ~= 0
        error(['command failed: "' command '"']);
    end
end
