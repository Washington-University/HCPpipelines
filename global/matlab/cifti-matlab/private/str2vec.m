function ret = str2vec(in)
    %dodge all the weirdness in str2num, or replace it with something more bulletproof if needed
    in(in == char(10) | in == char(13) | in == ';') = ' '; %try to prevent str2num from seeing any row separators, so that non-rectangular encodings don't cause errors
    ret = str2num(in)'; %#ok<ST2NM> %in case it goes rectangular anyway, text encoding is row-fast, while (:) converts with column-fast logic
    ret = ret(:)'; %reshape to row vector, for ease of looping
    if ~isreal(ret)
        error('cifti xml parsing only allows real numbers');%just so we don't have to test it all over the place, cifti never allows imaginary/complex in the XML
    end
end
