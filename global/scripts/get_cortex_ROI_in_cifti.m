function [ROI_OUT_CIFTI, NonROI_CIFTI]  = get_cortex_ROI_in_cifti(ROI_label, cifti_parcellation, cifti_space_out)
    CORTEX_LEFT=cifti_struct_dense_extract_surface_data(cifti_parcellation,'CORTEX_LEFT',1);
    CORTEX_RIGHT=cifti_struct_dense_extract_surface_data(cifti_parcellation,'CORTEX_RIGHT',1);
        
    ROI_CORTEX_LEFT=single(zeros(length(CORTEX_LEFT),1));
    ROI_CORTEX_RIGHT=single(zeros(length(CORTEX_RIGHT),1));
    
    for i=ROI_label
        ROI_CORTEX_LEFT(CORTEX_LEFT==i)=1;
        ROI_CORTEX_RIGHT(CORTEX_RIGHT==i)=1;
    end
    NonROI_CORTEX_LEFT=1-ROI_CORTEX_LEFT;
    NonROI_CORTEX_RIGHT=1-ROI_CORTEX_RIGHT;
    
    cifti_space_out.cdata=zeros(size(cifti_space_out.cdata, 1), 1, "single");

    ROI_OUT_CIFTI=cifti_space_out; % a zero template
    ROI_OUT_CIFTI=cifti_struct_dense_replace_surface_data(ROI_OUT_CIFTI,ROI_CORTEX_LEFT,'CORTEX_LEFT',1);
    ROI_OUT_CIFTI=cifti_struct_dense_replace_surface_data(ROI_OUT_CIFTI,ROI_CORTEX_RIGHT,'CORTEX_RIGHT',1);
    
    NonROI_CIFTI=cifti_space_out; % a zero template
    NonROI_CIFTI=cifti_struct_dense_replace_surface_data(NonROI_CIFTI,NonROI_CORTEX_LEFT,'CORTEX_LEFT',1);
    NonROI_CIFTI=cifti_struct_dense_replace_surface_data(NonROI_CIFTI,NonROI_CORTEX_RIGHT,'CORTEX_RIGHT',1);
    
end

