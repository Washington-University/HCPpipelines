function outarray = fread_excepting(fid, sizeA, conversion, filename)
    [outarray, readcount] = fread(fid, sizeA, conversion);
    if readcount ~= prod(sizeA)
        error(['file appears truncated: ' filename]);
    end
end
