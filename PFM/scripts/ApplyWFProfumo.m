function ApplyWishartFilterProfumo(inputFiles, outputFiles, numWisharts)
    numWisharts = str2double(numWisharts);
    inList = strsplit(inputFiles, ',');
    outList = strsplit(outputFiles, ',');

    allData = [];
    tpCounts = [];
    for i = 1:length(inList)
        cii = ciftiopen(strtrim(inList{i}), 'wb_command');
        tpCounts(i) = size(cii.cdata, 2);
        allData = [allData cii.cdata];
    end

    Out = icaDim(allData, 0, 1, -1, numWisharts);

    startTP = 1;
    for i = 1:length(outList)
        endTP = startTP + tpCounts(i) - 1;
        cii = ciftiopen(strtrim(inList{i}), 'wb_command');
        cii.cdata = Out.data(:, startTP:endTP);
        ciftisave(cii, strtrim(outList{i}), 'wb_command');
        startTP = endTP + 1;
    end
end