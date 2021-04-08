function k = xml_findstr(s,p,i,n)
%XML_FINDSTR Find one string within another
%   K = XML_FINDSTR(TEXT,PATTERN) returns the starting indices of any 
%   occurrences of the string PATTERN in the string TEXT.
%
%   K = XML_FINDSTR(TEXT,PATTERN,INDICE) returns the starting indices 
%   equal or greater than INDICE of occurrences of the string PATTERN
%   in the string TEXT. By default, INDICE equals to one.
%
%   K = XML_FINDSTR(TEXT,PATTERN,INDICE,NBOCCUR) returns the NBOCCUR 
%   starting indices equal or greater than INDICE of occurrences of
%   the string PATTERN in the string TEXT. By default, INDICE equals
%   to one and NBOCCUR equals to Inf.
%
%   Examples
%       s = 'How much wood would a woodchuck chuck?';
%       xml_findstr(s,' ') returns [4 9 14 20 22 32]
%       xml_findstr(s,' ',10) returns [14 20 22 32]
%       xml_findstr(s,' ',10,1) returns 14
%
%   See also STRFIND, FINDSTR


%warning('xml_findstr.c not compiled');

if nargin < 3, i = 1;   end
if nargin < 4, n = Inf; end

k = strfind(s(i:end),p) + i - 1;
if ~isempty(k), k = k(1:min(n,length(k))); end
