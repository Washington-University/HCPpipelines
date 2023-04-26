function outstring = cifti_metadata_get(metadata, key)
    %function outstring = cifti_metadata_get(metadata, key)
    %   Get the value for a specified metadata key.
    %
    %   >> provenance = cifti_metadata_get(cifti.metadata, 'Provenance');
    outstring = '';
    %looping over length handles empty just fine
    for i = 1:length(metadata)
        if strcmp(metadata(i).key, key)
            outstring = metadata(i).value;
            return;
        end
    end
end
