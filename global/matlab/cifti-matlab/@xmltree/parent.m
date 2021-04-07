function p = parent(tree,uid)
% XMLTREE/PARENT Parent Method
% FORMAT uid = parent(tree,uid)
% 
% tree   - XMLTree object
% uid    - UID of the lonely child
% p      - UID of the parent ([] if root is the child)
%
% Return the uid of the parent of a node.
%
%  See also XMLTREE


p = tree.tree{uid}.parent;
