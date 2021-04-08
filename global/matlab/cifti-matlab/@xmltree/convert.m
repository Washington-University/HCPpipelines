function s = convert(tree,uid,varargin)
% XMLTREE/CONVERT Convert an XML tree into a structure
% 
% tree     - XMLTree object
% uid      - uid of the root of the subtree, if provided.
%            Default is root
% s        - converted structure
%
% Convert an XMLTree into a structure, when possible.
% When several identical tags are present, a cell array is used.
% The root tag is not saved in the structure.
% If provided, only the structure corresponding to the subtree defined
% by the uid UID is returned.
%
% Example:
% xml = '<a><b>field1</b><c>field2</c><b>field3</b></a>';
% tree = convert(xmltree(xml));
% <=> tree = struct('b',{{'field1', 'field3'}},'c','field2')
%
%  See also XMLTREE


% Get the root uid of the output structure
if nargin == 1 || isempty(uid)
    % Get the root uid of the XML tree
    uid = root(tree);
end

% Get optional parameters
sub_options({'attributes',false,'str2num',false});
if nargin > 2
    sub_options(varargin);
end

% Build the output structure
s = struct();
s = sub_convert(tree,s,uid,{}); % {get(tree,root_uid,'name')}


%==========================================================================
function s = sub_convert(tree,s,uid,arg)
    type = get(tree,uid,'type');
    switch type
        case 'element'
            child = children(tree,uid);
            l = {};
            ll = {};
            for i=1:length(child)
                if isfield(tree,child(i),'name')
                    ll = [ll, get(tree,child(i),'name')];
                end
            end
            for i=1:length(child)
                if isfield(tree,child(i),'name')
                    name = get(tree,child(i),'name');
                    nboccur = sum(ismember(l,name));
                    nboccur2 = sum(ismember(ll,name));
                    l = [l, name];
                    if nboccur || nboccur2 > 1
                        arg2 = [arg, name, {{nboccur+1}}];
                    else
                        arg2 = [arg, name];
                    end
                else
                    arg2 = arg;
                end
                s = sub_convert(tree,s,child(i),arg2);
            end
            if isempty(child)
                s = sub_setfield(s,arg{:},'');
            end
            if sub_options('attributes')
                attrb = attributes(tree,'get',uid);
                if ~isempty(attrb)
                    arg2 = [arg, 'attributes'];
                    if ~isstruct(attrb), attrb = [attrb{:}]; end
                    try
                        % Saving attributes will work with <a t='q'><c>b</c></a>
                        % but not with <a t='q'>b</a>
                        s = sub_setfield(s,arg2{:},...
                            cell2struct({attrb.val},{attrb.key},2));
                    end
                end
            end
        case 'chardata'
            s = sub_setfield(s,arg{:},get(tree,uid,'value'));
            if sub_options('str2num')
                % Convert strings into their numerical equivalent when possible
                % e.g. string '3.14159' becomes double scalar 3.14159
                v = get(tree,uid,'value');
                cv = str2num(v);
                if isempty(cv)
                    s = sub_setfield(s,arg{:},v);
                else
                    s = sub_setfield(s,arg{:},cv);
                end
            end
        case 'cdata'
            s = sub_setfield(s,arg{:},get(tree,uid,'value'));
        case 'pi'
            % Processing instructions are ignored
            %PITarget = get(tree,uid,'target');
            %PIContent = get(tree,uid,'value');
        case 'comment'
            % Comments are ignored
        otherwise
            warning(sprintf('Type %s unknown : not saved',get(tree,uid,'type')));
    end
    
%==========================================================================
function s = sub_setfield(s,varargin)
% Same as setfield but using '{}' rather than '()'

subs = varargin(1:end-1);
types = repmat({'{}'},1,numel(subs));
types(cellfun(@ischar,subs)) = {'.'};
s = builtin('subsasgn', s, struct('type',types,'subs',subs), varargin{end});

%==========================================================================
function o = sub_options(opt)
persistent opts
if isempty(opts), opts = struct; end
if iscell(opt)
    for i=1:2:numel(opt)
        opts.(lower(opt{i})) = opt{i+1};
    end
else
    o = opts.(lower(opt));
end
