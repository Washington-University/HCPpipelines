function [slope intercept] = findFlipCorrectionSlopeLR(leftmyelin, rightmyelin, leftFlipFraction, rightFlipFraction)
    lowguess = -1;
    highguess = 5;
    searchratio = 1 - 2 / (sqrt(5) + 1); % 1 - inverse of golden ratio
    currange = highguess - lowguess;
    points = [lowguess, lowguess + searchratio * currange, highguess - searchratio * currange, highguess];
    vals = mycost(points, leftmyelin, rightmyelin, leftFlipFraction, rightFlipFraction); %more arguments go here
    precision = 0.001;
    while points(4) - points(1) > precision
        %disp(points);
        if vals(2) < vals(3)
            points(3:4) = points(2:3); vals(3:4) = vals(2:3);
            currange = points(4) - points(1);
            points(2) = points(1) + searchratio * currange;
            vals(2) = mycost(points(2), leftmyelin, rightmyelin, leftFlipFraction, rightFlipFraction); %more arguments go here
        else
            points(1:2) = points(2:3); vals(1:2) = vals(2:3);
            currange = points(4) - points(1);
            points(3) = points(4) - searchratio * currange;
            vals(3) = mycost(points(3), leftmyelin, rightmyelin, leftFlipFraction, rightFlipFraction); %more arguments go here
        end
    end
    if vals(2) < vals(3)
        slope = points(2);
    else
        slope = points(3);
    end
    intercept = 1 - slope;
end

function cost = mycost(points, leftmyelin, rightmyelin, leftFlipFraction, rightFlipFraction)
    for index = 1:length(points)
        slope = points(index);
        intercept = 1 - slope;
        
        leftmyelincorr = leftmyelin ./ (leftFlipFraction * slope + intercept);
        rightmyelincorr = rightmyelin ./ (rightFlipFraction * slope + intercept);
        cost(index) = sum(abs((mean(leftmyelincorr, 2) - mean(rightmyelincorr, 2)) ./ ((mean(leftmyelincorr, 2) + mean(rightmyelincorr, 2))/2)));
    end
end

