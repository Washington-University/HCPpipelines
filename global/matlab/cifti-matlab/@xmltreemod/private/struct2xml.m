function tree = struct2xml(s,rootname)
% STRUCT2XML Convert a structure to an XML tree object
% FORMAT tree = struct2xml(s,rootname)
%
% Convert the structure S into an XML representation TREE (an XMLTree
% object) with ROOTNAME as the root tag, if provided. Only conventional
% objects (char, numeric) are accepted in S's fields.
%
% Example
%    report = struct('name','John','marks',...
%                    struct('maths',17,'physics',12));
%    tree = struct2xml(report);
%    save(tree,'report.xml');
%
% See also XMLTREE


% Define root tag
if nargin == 1
	rootname = inputname(1);
end
if isempty(rootname)
    rootname = 'root';
end

% Create an empty XML tree
tree = xmltreemod;

% Root element is the input argument name
tree = set(tree,root(tree),'name',rootname);

% Recursively walk inside the structure
tree = sub_struct2xml(tree,s,root(tree));


%==========================================================================
function tree = sub_struct2xml(tree,s,uid)

switch class(s)
    case 'struct'
        for k=1:length(s)
            names = fieldnames(s(k));
            names(cellfun(@(x) isequal(x,'attributes'),names)) = [];
            if isfield(s(k),'attributes')
                fn = fieldnames(s(k).attributes);
                for i=1:numel(fn)
                    tree = attributes(tree,'add',uid,fn{i},s(k).attributes.(fn{i}));
                end
            end
            for i=1:numel(names)
                if iscell(s(k).(names{i}))
                    for j=1:numel(s(k).(names{i}))
                        [tree, uid2] = add(tree,uid,'element',names{i});
                        tree = sub_struct2xml(tree,getfield(s(k),names{i},{j}),uid2);
                    end
                else
                    [tree, uid2] = add(tree,uid,'element',names{i});
                    tree = sub_struct2xml(tree,s(k).(names{i}),uid2);
                end
            end
        end
    case 'char'
        tree = add(tree,uid,'chardata',s); %need to handle char arrays...
    case 'cell'
        % if a cell is present here, it comes from: getfield(s(k),names{i},{j})
        tree = sub_struct2xml(tree,s{1},uid);
    case {'double','single','int8','uint8','int16','uint16','int32','uint32','int64','uint64'}
        tree = add(tree,uid,'chardata',sub_num2str(s));
    otherwise
        error('[STRUCT2XML] Cannot convert from %s to char.',class(s));
end


%==========================================================================
function s = sub_num2str(n)  % to be improved for ND arrays
[N,P] = size(n);

if N>1 || P>1
    s = '[';
    w = ones(1,P);w(P)=0;
    v = ones(N,1);v(N)=0;
    for k=1:N
        for i=1:P
            s = [s num2str(n(k,i)) repmat(',',1,w(i))];
        end
        s = [s repmat(';',1,v(k))];
    end
    s = [s ']'];
else
    s = num2str(n);
end
