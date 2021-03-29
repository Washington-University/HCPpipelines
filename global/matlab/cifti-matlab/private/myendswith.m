function ret = myendswith(string, ending)
    %endsWith needs java, but we only need one string+pattern at a time...
    if length(ending) > length(string)
        ret = false;
    else
        ret = strcmp(string((end - length(ending) + 1):end), ending);
    end
end
