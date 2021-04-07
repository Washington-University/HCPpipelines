function display(tree)
% XMLTREE/DISPLAY Command window display of an XMLTree
% FORMAT display(tree)
% 
% tree - XMLTree object
%
% This method is called when the semicolon is not used to terminate a
% statement which returns an XMLTree.
%
%  See also XMLTREE


disp(' ');
disp([inputname(1),' = ']);
disp(' ');
for i=1:numel(tree)
    disp([blanks(length(inputname(1))+3) char(tree(i))]);
end
disp(' ');
