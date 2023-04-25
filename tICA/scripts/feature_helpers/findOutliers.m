function isOutliers = findOutliers(data)
% must be 1d array
madOutliers=findScaledMADOutliers(data);
perOutliers=findFivePercentageOutliers(data);
isOutliers=and(madOutliers, perOutliers);
end
