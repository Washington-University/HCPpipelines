function my_system(command)
    %like call_fsl, but without sourcing fslconf
    if ismac()
        ldsave = getenv('DYLD_LIBRARY_PATH');
        %this is just a guess at what matlab does on mac, based on using LD_PRELOAD on linux
        presave = getenv('DYLD_INSERT_LIBRARIES');
        macflatsave = getenv('DYLD_FORCE_FLAT_NAMESPACE');
    else
        ldsave = getenv('LD_LIBRARY_PATH');
        presave = getenv('LD_PRELOAD');
        macflatsave = '';
    end
    %restore it even if we are interrupted
    function cleanupFunc(ldsave, presave, macflatsave)
        if ismac()
            setenv('DYLD_LIBRARY_PATH', ldsave);
            setenv('DYLD_INSERT_LIBRARIES', presave);
            setenv('DYLD_FORCE_FLAT_NAMESPACE', macflatsave);
        else
            setenv('LD_LIBRARY_PATH', ldsave);
            setenv('LD_PRELOAD', presave);
        end
    end
    guardObj = onCleanup(@() cleanupFunc(ldsave, presave, macflatsave));
    if ismac()
        setenv('DYLD_LIBRARY_PATH');
        setenv('DYLD_INSERT_LIBRARIES');
        setenv('DYLD_FORCE_FLAT_NAMESPACE');
    else
        setenv('LD_LIBRARY_PATH');
        setenv('LD_PRELOAD');
    end
    if system(command) ~= 0
        error(['command failed: "' command '"']);
    end
end
