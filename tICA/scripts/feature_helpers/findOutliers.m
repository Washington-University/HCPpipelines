function ret = findOutliers(data)
% must be 1d array
madOutliers=findScaledMADOutliers(data);
perOutliers=findFivePercentageOutliers(data);
ret=and(madOutliers, perOutliers);
end
