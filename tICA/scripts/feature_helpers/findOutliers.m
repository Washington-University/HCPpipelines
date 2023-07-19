function ret = findOutliers(data)
% must be 1d array
% outlier detection: identify data that do not pass the MAD-based test, while ensuring that it never detects more than 5% of the highest or lowest values.
madOutliers=findScaledMADOutliers(data);
perOutliers=findFivePercentageOutliers(data);
ret=and(madOutliers, perOutliers);
end
