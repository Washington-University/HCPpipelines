function varargout = save_string(tree, formatting)
    % XMLTREE/SAVE Save an XML tree in an XML file
    % FORMAT varargout = save(tree,formatting)
    %
    % tree       - XMLTree
    % formatting - 1 for indenting of tags, 0 for no formatting
    % varargout  - XML string
    %__________________________________________________________________________
    %
    % Convert an XML tree into a well-formed XML string and write it into
    % a file or return it as a string if no filename is provided.
    %__________________________________________________________________________
    % Copyright (C) 2002-2011  http://www.artefact.tk/

    % Guillaume Flandin
    % $Id: save.m 4460 2011-09-05 14:52:16Z guillaume $

    % edited 2020 by Tim S Coalson to reduce formatting whitespace problems, enable no-formatting

    %error(nargchk(1,2,nargin));

    prolog = '<?xml version="1.0" ?>\n';

    order = 0;
    if nargin > 1
        switch formatting
            case 0
                order = -1;
        end
    end
    %- Return the XML tree as a string
    varargout{1} = [sprintf(prolog) ...
        print_subtree(tree, root(tree), order)];
end

%TSC: rewrite from scratch to only recurse on element, so we can check the types of children
function xmlstr = print_subtree(tree, uid, order)
    assert(strcmp(tree.tree{uid}.type, 'element'));
    if nargin < 3, order = 0; end
    indentstr = '';
    closeindentstr = '';
    if order < 0 %TSC feature: use order = -1 to suppress all formatting whitespace
        neworder = order;
    else
        neworder = order + 1;
        indentstr = [char(10) blanks(3 * neworder)];
        closeindentstr = [char(10) blanks(3 * order)];
    end
    %make contents of tag first, then decide what formatting to do after we know whether there are any tag-like children
    contents = '';
    allchildrentext = true;
    for child_uid = tree.tree{uid}.contents
        switch tree.tree{child_uid}.type
            case 'element'
                allchildrentext = false;
                contents = [contents indentstr print_subtree(tree, child_uid, neworder)]; %#ok<AGROW> %sprintf shouldn't be any faster, matlab just doesn't recognize it as being the same issue
            case 'chardata'
                contents = [contents entity(tree.tree{child_uid}.value)]; %#ok<AGROW>
            case 'cdata'
                contents = [contents cdata(tree.tree{child_uid}.value)]; %#ok<AGROW>
            case 'pi'
                allchildrentext = false;
                contents = [contents indentstr '<?' tree.tree{child_uid}.target ' ' tree.tree{child_uid}.value '?>']; %#ok<AGROW>
            case 'comment'
                allchildrentext = false;
                contents = [contents indentstr '<!-- '  tree.tree{child_uid}.value ' -->']; %#ok<AGROW>
            otherwise
                warning('Type %s unknown: not saved', tree.tree{child_uid}.type);
        end
    end
    tagstr = ['<' tree.tree{uid}.name];
    for i = 1:length(tree.tree{uid}.attributes)
        tagstr = [tagstr ' ' tree.tree{uid}.attributes{i}.key '="' entity(tree.tree{uid}.attributes{i}.val) '"']; %#ok<AGROW>
    end
    %tagstr isn't quite finished, but build xmlstr directly with it to save a little time
    if isempty(tree.tree{uid}.contents)
        xmlstr = [tagstr '/>'];
    else
        if allchildrentext
            xmlstr = [tagstr '>' contents '</' tree.tree{uid}.name '>'];
        else
            xmlstr = [tagstr '>' contents closeindentstr '</' tree.tree{uid}.name '>'];
        end
    end
end

%==========================================================================
function str = entity(str)
    % TSC: avoid cellstr
    str = strrep(str, '&',  '&amp;' );
    str = strrep(str, '<',  '&lt;'  );
    str = strrep(str, '>',  '&gt;'  );
    str = strrep(str, '"',  '&quot;');
    str = strrep(str, '''', '&apos;');
end

%CDATA can't contain the string "]]>", have to write multiple cdata elements despite being in the tree as one
function str = cdata(instr)
    str = ['<!CDATA[' strrep(instr, ']]>', ']]]]><!CDATA[>')];
end
