function tree = setfilename(tree,filename)
% XMLTREE/SETFILENAME Set filename method
% FORMAT tree = setfilename(tree,filename)
% 
% tree     - XMLTree object
% filename - XML filename
%
% Set the filename linked to the XML tree as filename.
%
%  See also XMLTREE


tree.filename = filename;
