function fwrite_excepting(fid, data, type, filename)
    count = fwrite(fid, data, type);
    if count ~= numel(data)
        error(['failed to write data to file "' filename '"']);
    end
end
