function PseudoTransmit_GroupAverage(myelinRCFile, avgPTFieldFile, ReferenceValOutFile)
    %asymmetry stuff is only for display, moved to phase 4 to simplify
    %"Orig Myelin"
    MyelinMap = cifti_read(myelinRCFile);
    
    AvgPTField = cifti_read(avgPTFieldFile);
    
    [leftmyelin leftroi] = cifti_struct_dense_extract_surface_data(MyelinMap, 'CORTEX_LEFT');
    [rightmyelin rightroi] = cifti_struct_dense_extract_surface_data(MyelinMap, 'CORTEX_RIGHT');
    leftPTF = cifti_struct_dense_extract_surface_data(AvgPTField, 'CORTEX_LEFT');
    rightPTF = cifti_struct_dense_extract_surface_data(AvgPTField, 'CORTEX_RIGHT');
    bothroi = leftroi & rightroi;
    
    [PseudoTransmitReference, ~, ~] = findPseudoTransmitRatioLR(leftmyelin(bothroi), rightmyelin(bothroi), leftPTF(bothroi), rightPTF(bothroi));
    dlmwrite(ReferenceValOutFile, PseudoTransmitReference, ' ');
end

function [refval slope intercept] = findPseudoTransmitRatioLR(leftmyelin, rightmyelin, leftPTF, rightPTF)
    lowguess = prctile([leftPTF; rightPTF], 5);
    highguess = prctile([leftPTF; rightPTF], 95);
    searchratio = 1 - 2 / (sqrt(5) + 1); % 1 - inverse of golden ratio
    currange = highguess - lowguess;
    points = [lowguess, lowguess + searchratio * currange, highguess - searchratio * currange, highguess];
    for i = 1:length(points)
        [vals(i) slope intercept] = ReferenceValueOptimze(points(i), leftmyelin, rightmyelin, leftPTF, rightPTF);
    end
    precision = 0.001;
    while points(4) - points(1) > precision
        if vals(2) < vals(3)
            points(3:4) = points(2:3); vals(3:4) = vals(2:3);
            currange = points(4) - points(1);
            points(2) = points(1) + searchratio * currange;
            [vals(2) slope intercept] = ReferenceValueOptimze(points(2), leftmyelin, rightmyelin, leftPTF, rightPTF);
        else
            points(1:2) = points(2:3); vals(1:2) = vals(2:3);
            currange = points(4) - points(1);
            points(3) = points(4) - searchratio * currange;
            [vals(3) slope intercept] = ReferenceValueOptimze(points(3), leftmyelin, rightmyelin, leftPTF, rightPTF);
        end
    end
    if vals(2) < vals(3)
        refval = points(2);
    else
        refval = points(3);
    end
end

function [cost slope intercept] = ReferenceValueOptimze(refval, leftmyelin, rightmyelin, leftPTF, rightPTF)
    leftPTFref = leftPTF ./ refval;
    rightPTFref = rightPTF ./ refval;
    lowguess = -1;
    highguess = 5;
    searchratio = 1 - 2 / (sqrt(5) + 1); % 1 - inverse of golden ratio
    currange = highguess - lowguess;
    points = [lowguess, lowguess + searchratio * currange, highguess - searchratio * currange, highguess];
    vals = mycost(points, leftmyelin, rightmyelin, leftPTFref, rightPTFref);
    precision = 0.001;
    while points(4) - points(1) > precision
        if vals(2) < vals(3)
            points(3:4) = points(2:3); vals(3:4) = vals(2:3);
            currange = points(4) - points(1);
            points(2) = points(1) + searchratio * currange;
            vals(2) = mycost(points(2), leftmyelin, rightmyelin, leftPTFref, rightPTFref);
        else
            points(1:2) = points(2:3); vals(1:2) = vals(2:3);
            currange = points(4) - points(1);
            points(3) = points(4) - searchratio * currange;
            vals(3) = mycost(points(3), leftmyelin, rightmyelin, leftPTFref, rightPTFref);
        end
    end
    if vals(2) < vals(3)
        slope = points(2);
        cost = vals(2);
    else
        slope = points(3);
        cost = vals(3);
    end
    intercept = 1 - slope;
end

function cost = mycost(points, leftmyelin, rightmyelin, leftPTF, rightPTF)
    for index = 1:length(points)
        slope = points(index);
        intercept = 1 - slope;
        
        leftmyelincorr = leftmyelin ./ (leftPTF .* slope + intercept);
        rightmyelincorr = rightmyelin ./ (rightPTF .* slope + intercept);

        %simplified for the group average purpose with fewer calls, parens, indices, etc
        leftcorrmean = mean(leftmyelincorr);
        rightcorrmean = mean(rightmyelincorr);
        cost(index) = abs((leftcorrmean - rightcorrmean) / ((leftcorrmean + rightcorrmean) / 2)) + ...
            abs(leftcorrmean - mean(leftmyelin) + rightcorrmean - mean(rightmyelin));
    end
end

