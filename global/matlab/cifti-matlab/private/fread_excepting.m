function outarray = fread_excepting(fid, sizeA, conversion, filename)
    [temparray, readcount] = fread(fid, prod(sizeA), conversion); %matlab's fread can't handle more than 2 dimensions
    if readcount ~= prod(sizeA)
        error(['file appears truncated: ' filename]);
    end
    outarray = reshape(temparray, sizeA); %seems fairly simple on the interpreted side, at least
end

