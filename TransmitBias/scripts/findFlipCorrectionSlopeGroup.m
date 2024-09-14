function [slope intercept] = findFlipCorrectionSlopeGroup(myelin, transmit, template)
    lowguess = -1;
    highguess = 5;
    searchratio = 1 - 2 / (sqrt(5) + 1); % 1 - inverse of golden ratio
    currange = highguess - lowguess;
    points = [lowguess, lowguess + searchratio * currange, highguess - searchratio * currange, highguess];
    vals = mycost2(points, myelin, transmit, template);
    precision = 0.001;
    while points(4) - points(1) > precision
        %disp(points);
        if vals(2) < vals(3)
            points(3:4) = points(2:3); vals(3:4) = vals(2:3);
            currange = points(4) - points(1);
            points(2) = points(1) + searchratio * currange;
            vals(2) = mycost2(points(2), myelin, transmit, template);
        else
            points(1:2) = points(2:3); vals(1:2) = vals(2:3);
            currange = points(4) - points(1);
            points(3) = points(4) - searchratio * currange;
            vals(3) = mycost2(points(3), myelin, transmit, template);
        end
    end
    if vals(2) < vals(3)
        slope = points(2);
    else
        slope = points(3);
    end
    intercept = 1 - slope;
end

function cost = mycost2(pointsin, myelin, transmit, template)
    for index = 1:length(pointsin)
        slope = pointsin(index);
        intercept = 1 - slope;
        
        corrmyelin = myelin ./ (transmit * slope + intercept);
        
        closetransmit = (transmit < 1.05) & (transmit >= 0.95); %TSC: was originally "round(transmit, 1) == 1"

        TemplateReference = median(template(closetransmit));
        SubjectReference = median(corrmyelin(closetransmit));
        Ratio = SubjectReference ./ TemplateReference;
        
        cost(index) = sum(abs((mean(corrmyelin ./ Ratio, 2) - template) ./ template));
    end
end

