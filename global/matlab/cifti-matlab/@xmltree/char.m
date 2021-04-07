function s = char(tree)
% XMLTREE/CHAR Converter function from XMLTree to a description string
% FORMAT s = char(tree)
%
% tree - XMLTree object
% s    - a description string of an XMLTree
%
% Return a string describing the XMLTree:
%               'XMLTree object (x nodes) [filename]'
%
%  See also XMLTREE


s = sprintf('XMLTree object (%d nodes) [%s]',length(tree),getfilename(tree));
