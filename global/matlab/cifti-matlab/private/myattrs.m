function attrs = myattrs(tree, varargin)
    uid = root(tree);
    if ~isempty(varargin)
        uid = varargin{1};
    end
    attrs = attributes(tree, 'get', uid);
    if ~iscell(attrs)
        attrs = {attrs}; % treat one attribute just like multiple attributes
    end
end
