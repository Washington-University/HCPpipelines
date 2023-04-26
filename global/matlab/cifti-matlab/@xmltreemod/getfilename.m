function filename = getfilename(tree)
% XMLTREE/GETFILENAME Get filename method
% FORMAT filename = getfilename(tree)
% 
% tree     - XMLTree object
% filename - XML filename
%
% Return the filename of the XML tree if loaded from disk and an empty 
% string otherwise.
%
%  See also XMLTREE


filename = tree.filename;
