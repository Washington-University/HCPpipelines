function string = mygettext(tree, varargin)
    uid = root(tree);
    if ~isempty(varargin)
        uid = varargin{1};
    end
    string = '';
    mychildren = children(tree, uid);
    for ch_uid = mychildren
        switch get(tree, ch_uid, 'type')
            case {'chardata', 'cdata'}
                string = [string get(tree, ch_uid, 'value')];%#ok<AGROW>
        end
    end
end
