function ApplyWishartFilterProfumo(inputFiles, outputFiles, numWisharts, pfmDim)
    numWisharts = str2double(numWisharts);
    pfmDim = str2double(pfmDim);
    inList = strsplit(inputFiles, ',');
    outList = strsplit(outputFiles, ',');

    % Read and concatenate all runs
    allData = [];
    tpCounts = [];
    for i = 1:length(inList)
        cii = ciftiopen(strtrim(inList{i}), 'wb_command');
        tpCounts(i) = size(cii.cdata, 2);
        allData = [allData cii.cdata];
    end

    % Mask zero voxels
    mask = range(allData, 2) > 0;
    data = allData(mask, :);

    % Call shared Wishart filter
    [filteredData, ~, ~] = WishartFilter(data, pfmDim, numWisharts);

    % Unmask
    fullFiltered = zeros(size(allData), 'single');
    fullFiltered(mask, :) = filteredData;

    % Split and save each run
    startTP = 1;
    for i = 1:length(outList)
        endTP = startTP + tpCounts(i) - 1;
        cii = ciftiopen(strtrim(inList{i}), 'wb_command');
        cii.cdata = fullFiltered(:, startTP:endTP);
        ciftisave(cii, strtrim(outList{i}), 'wb_command');
        startTP = endTP + 1;
    end
end