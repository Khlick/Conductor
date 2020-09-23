function S = getPackageStorage()
%GETPACKAGESTORAGE Load the contents of the package storage

% prevent a warning if Symphony is not currently on the path
wQry = warning('off','MATLAB:dispatcher:UnresolvedFunctionHandle');

root = admin.utils.getPackageRoot();
% locate the sy2 file if present
files = dir(fullfile(root,'*.sy2'));
try
  S = load(fullfile(root,files(1).name),'-mat');
catch x
  warning(wQry);
  rethrow(x);
end

end

