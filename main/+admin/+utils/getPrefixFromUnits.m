function [varargout] = getPrefixFromUnits(units)
units = char(units);
map = admin.utils.unitMap();
% we expect that units are at least 1 character so we will only check the
% prefix if the number of characters is longer than 1
prefix = '';
suffix = units;
for u = 1:size(map,1)
  if startsWith(units,map{u,1},'ignorecase',false)
    prefix = map{u,1};
    suffix = regexprep(units,['^',prefix], '');
    % conver u to μ
    if strcmpi(prefix,'u'),prefix = char(956);end
    break
  end
end
varargout{1} = prefix;
if nargout > 1
  varargout{2} = suffix;
end
end