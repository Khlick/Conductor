function root = getOpenSetupRoot()

root = '';

% prefer preference as it is faster than loading the storage file
try %#ok<TRYNC>
  map = admin.utils.getPreferenceMap();
  contents = string(ls( ...
    fullfile( ...
      admin.utils.getPackageRoot(), ...
      map('user'), ...
      map('setup') ...
      ) ...
    ));
  idx = find(contains(contents,'+'),1,'first');
  root = strtrim(regexprep(contents{idx},'+',''));
  return
end

% next attempt to locate and load the storage sy2 file for current user
try %#ok<TRYNC>
  status = admin.utils.getPackageStorage();
  if ~isfield(status,'userInfo')
    error('No open packge.');
  end
  ui = status.userInfo;
  contents = string(ls(fullfile(ui.rootFolder,ui.user,ui.setup)));
  idx = find(contains(contents,'+'),1,'first');
  root = strtrim(regexprep(contents{idx},'+',''));
end
end