function ex = prefixToExponent(prefix)
% PREFIXTOEXPONENT Returns base 10 exponent for case-sensitive prefix match.

map = admin.utils.unitMap();
target = find(ismember(map(:,1),prefix),1,'first');
if isempty(target)
  ex = 0;
else
  ex = map{target,2};
end

end