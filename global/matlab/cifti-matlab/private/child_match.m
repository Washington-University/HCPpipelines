function list = child_match(tree, uid, tag)
    mychildren = children(tree, uid);
    list = zeros(length(mychildren), 1); %allocate as many as there could possibly be, to avoid loop growing
    count = 0;
    for ch_uid = mychildren
        switch get(tree, ch_uid, 'type')
            case 'element'
                if strcmp(tag, get(tree, ch_uid, 'name'))
                    count = count + 1;
                    list(count) = ch_uid; %1-based indexing...
                end
        end
    end
    list = list(1:count); %trim the excess
end
