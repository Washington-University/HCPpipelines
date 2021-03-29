function metadata = cifti_metadata_set(metadata, key, value)
    %function metadata = cifti_metadata_set(metadata, key, newvalue)
    %   Set the value for a specified metadata key.
    %
    %   >> cifti.metadata = cifti_metadata_set(cifti.metadata, 'Provenance', 'I made this');
    
    if ~isstruct(metadata)
        metadata = struct('key', {}, 'value', {});
    end
    %looping over length handles empty just fine
    for i = 1:length(metadata)
        if strcmp(metadata(i).key, key)
            metadata(i).value = value;
            return;
        end
    end
    %not found, append it
    metadata = [metadata struct('key', key, 'value', value)];
end
