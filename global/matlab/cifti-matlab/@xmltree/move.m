function tree = move(tree,uida, uidb)
% XMLTREE/MOVE Move (move a subtree inside a tree from A to B)
% 
% tree   - XMLTree object
% uida   - initial position of the subtree
% uidb   - parent of the final position of the subtree
%
% Move a subtree inside a tree from A to B.
% The tree parameter must be in input AND in output.
%
%  See also XMLTREE


p = tree.tree{uida}.parent;
tree.tree{p}.contents(find(tree.tree{p}.contents==uida)) = [];
tree.tree(uidb).contents = [tree.tree(uidb).contents uida];
