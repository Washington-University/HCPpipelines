function metadata = cifti_metadata_remove(metadata, key)
    %function metadata = cifti_metadata_remove(metadata, key)
    %   Remove a metadata key and its value.
    %
    %   >> cifti.metadata = cifti_metadata_remove(cifti.metadata, 'Provenance');
    
    %looping over length handles empty just fine
    for i = 1:length(metadata)
        if strcmp(metadata(i).key, key)
            metadata(i) = [];
            return;
        end
    end
end
