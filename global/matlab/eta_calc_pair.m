function eta_matrix = eta_calc_pair(zmapa, zmapb)
    if length(size(zmapa)) > 2 || length(size(zmapb)) > 2 || size(zmapa, 1) <= 1 || size(zmapb, 1) <= 1
        error('inputs must be column vectors or 2D matrices');
    end
    
    m = size(zmapa, 2);
    n = size(zmapb, 2);
    eta_matrix = zeros(m, n, 'single');
    
    %precompute means
    meanzmapa = mean(zmapa, 1);
    meanzmapb = mean(zmapb, 1);

    for i = 1:m
        for j = 1:n
            % mean correlation value over all locations in both images
            Mgrand   = (meanzmapa(i) + meanzmapb(j)) / 2;
            %
            % mean value matrix for each location in the 2 images
            Mwithin  = (zmapa(:, i) + zmapb(:, j)) / 2;
            SSwithin = sum((zmapa(:, i) - Mwithin) .^ 2, 1) + sum((zmapb(:, j) - Mwithin, 1) .^ 2);
            SStot    = sum((zmapa(:, i) - Mgrand ) .^ 2, 1) + sum((zmapb(:, j) - Mgrand , 1) .^ 2);
            %
            % N.B. SStot = SSwithin + SSbetween so eta can also be written as SSbetween/SStot
            eta_matrix(i, j) = 1 - SSwithin / SStot;
        end
    end
end

