function ApplyClassifier(InputDense, InputDenseGrad, Subject, TrainedFolder, InputDilROIs, AreaNamesFile, InputFeatureTypes, OutputFolder)
    %InputDense - filename of features dscalar
    %InputDenseGrad - ditto for gradients, only used for gradient output
    %AreaNamesFile - text file of area names (which include L_ or R_)
    %InputFeatureTypes - text file that has integers denoting types of input feature maps, visuotopic are last and highest numbered
    
    wbcommand = 'wb_command';
    FeatureCategories = load(InputFeatureTypes);
    FirstVisuotopicFeature = max(FeatureCategories);
    
    DilROIs = ciftiopen(InputDilROIs, wbcommand);
    AreaNames = myreadtext(AreaNamesFile);
    numAreas = length(AreaNames);
    
    data = ciftiopen(InputDense, wbcommand);
    numOrdinates = size(data.cdata, 1);
    
    grad = ciftiopen(InputDenseGrad, wbcommand);
    
    %save feature names
    featurenamefile = tempname();
    system([wbcommand ' -file-information -only-map-names ' InputDense ' > ' featurenamefile]);
    
    %normalize data
    mean_features = mean(data.cdata, 1);
    std_features_raw = std(data.cdata, [], 1);
    std_features = zeros(size(std_features_raw), 'single');%preallocate
    for f = 1:max(FeatureCategories)
        mask = (FeatureCategories == f);
        std_features(:, mask) = median(std_features_raw(:, mask));
    end
    normdata = (data.cdata - repmat(mean_features, numOrdinates, 1)) ./ repmat(std_features, numOrdinates, 1);
    normgrad = grad.cdata ./ repmat(std_features, numOrdinates, 1);
    
    Out = data;
    Out.cdata = [];
    
    for area = 1:numAreas
        AreaName = AreaNames{area};
        DilROI = DilROIs.cdata(:, area);
        roibool = (DilROI == 1);
        
        Var=load([TrainedFolder '/' num2str(area) '_' AreaName '.mat'], 'weights1', 'out_weights1');
        weights1=Var.weights1;
        out_weights1=Var.out_weights1;

        roi_in = normdata(roibool, :);
        roi_grad = normgrad(roibool, :);
        
        %V1 should not use the visuotopic features that are derived from a template for V1
        if area == 1
            roi_in = roi_in(:, FeatureCategories < FirstVisuotopicFeature);
            roi_grad = roi_grad(:, FeatureCategories < FirstVisuotopicFeature);
        end
        
        input = [ones(size(roi_in, 1), 1), roi_in]; %append a bias term to all inputs

        a = 1;
        b = 1/10;
        V1 = input * weights1; %(features x num_hid_nodes matrix):
        y = a * tanh(b * V1); %y values for hidden layer
        y(:, 1) = 1; %apply bias term
        %derivatives
        dydV1 = a * b * sech(b * V1).^2;%dydi = space x hidden, just the derivatives of the nonlinear function at the values used
        dydV1(:, 1) = 0; %bias term's derivative is zero
        %dydx = repmat(dydV1,1,1,size(input, 2)) .* permute(repmat(weights1, 1, 1, size(input, 1)), [3, 2, 1]);%old code for derivative of each hidden output for each feature
        
        V3 = y * out_weights1; %(num_hid_nodes x num_out_nodes matrix)
        output = 1 ./ (1 + exp(-a * V3));
        %derivatives
        doutdV3 = a * exp(a * V3) ./ (exp(a * V3) + 1).^2; %doutdV3 = space x class, just the derivative of the output function
        
        %we only care about the first class, the second was just trained on the inverse ROI
        %if we don't need the derivatives of each hidden neuron for each feature, we can track only the derivative of the output class
        doutdy = doutdV3(:, 1) * out_weights1(:, 1)';%space x hidden, derivative of only the area class in terms of hidden output
        doutdV1 = doutdy .* dydV1;%multiply by derivatives of hidden nonlinear function at the known values
        doutdx = doutdV1 * weights1';%note: first "feature" here is the constant term
        
        Out.cdata = zeros(numOrdinates, 1);
        Out.cdata(roibool) = output(:, 1);
        ciftisavereset(Out, [OutputFolder '/' num2str(area) '_' AreaName '_final_area.dscalar.nii'], wbcommand);
        system([wbcommand ' -set-map-names ' OutputFolder '/' num2str(area) '_' AreaName '_final_area.dscalar.nii -map 1 ' Subject '_' AreaName]);
        
        %TODO: use the gradients of the features (vectors? normalization?)
        %vectors would just give "helpful" or "harmful", but what we probably want is "increase means area" vs "decrease means area"
        %but multiplying by feature gradient additionally weights by where there was change (regardless of direction)
        %could use dot product, then absolute value, then multiply with feature derivatives
        %however, defining "towards area" is problematic (group definition, or else deal with missing individual area)
        Out.cdata = zeros(numOrdinates, size(roi_grad, 2));
        Out.cdata(roibool, :) = doutdx(:, 2:end) .* roi_grad;
        ciftisavereset(Out, [OutputFolder '/' num2str(area) '_' AreaName '_FeatureDerivativesGrad.dscalar.nii'], wbcommand);
        if area == 1
            %V1 has features excluded from the end
            v1featurenamefile = tempname();
            system(['head -n' num2str(size(roi_in, 2)) ' ' featurenamefile ' > ' v1featurenamefile]);
            system([wbcommand ' -set-map-names -name-file ' v1featurenamefile ' ' OutputFolder '/' num2str(area) '_' AreaName '_FeatureDerivativesGrad.dscalar.nii']);
            delete(v1featurenamefile);
        else
            system([wbcommand ' -set-map-names -name-file ' featurenamefile ' ' OutputFolder '/' num2str(area) '_' AreaName '_FeatureDerivativesGrad.dscalar.nii']);
        end
    end
    delete(featurenamefile);
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

