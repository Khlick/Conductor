function SetupSymphony()
% SETUPSYMPHONY Setup symphony to use our custom start/stop procedures.
% Keep this file in the custom package directory

import matlab.internal.apputil.AppUtil;

packageRoot = fileparts(mfilename('fullpath'));

% Locate Symphony and add it to the path
[importStatus,ME] = importSymphony();
if strcmp(importStatus,'FAILED')
  throw(ME);
end

% check for symphony preferences
symphonyPrefs = getpref('symphonyui');
if ~isempty(symphonyPrefs)
  response = questdlg( ...
    'Reset Symphony preferences? (reccommended)', ...
    'Reset Symphony', ...
    'Yes','No','Yes' ...
    );
  if strcmp(response,'Yes')
    if isfield(symphonyPrefs,'admin_startup_CustomStartup')
      symphonyPrefs = rmfield(symphonyPrefs,'admin_startup_CustomStartup');
      rmpref('symphonyui','admin_startup_CustomStartup');
    end
    pfields = fieldnames(symphonyPrefs);
    for f = pfields.'
      setpref('symphonyui',f{1},containers.Map());
    end
    symphonyPrefs = getpref('symphonyui');
  end
end

% import symphony settings and configure for our package
if ~isfield(symphonyPrefs,'symphonyui_app_Options')
  setpref('symphonyui','symphonyui_app_Options',containers.Map());
end
options = symphonyui.app.Options.getDefault();
options.startupFile = fullfile(packageRoot,'SymphonyStartup.m');
options.cleanupFile = fullfile(packageRoot,'SymphonyShutdown.m');
options.warnOnViewOnlyWithOpenFile = false;
options.searchPath = '';
options.searchPathExclude = 'admin\.core\.\w*Protocol;admin\.descriptions\.*;';
try %#ok<TRYNC>
  options.save();
end

% search for exisiting users
userDirs = dir(fileparts(packageRoot));
userDirs(~[userDirs.isdir]) = [];
userDirs = {userDirs.name}';
isValidUser = ~ismember(userDirs,'main');
isValidUser = isValidUser & ...
  cellfun( ...
    @isempty, ...
    regexp( userDirs, '^([^a-zA-z]|_)', 'once' ), ...
    'UniformOutput', true ...
  );
userDirs(~isValidUser) = [];

showUC = true;

if ~isempty(userDirs)
  response = questdlg( ...
    'User(s) found, but would you like to create a new user?', ...
    'Add User', ...
    'Yes','No', ...
    'No' ...
    );
  showUC = strcmp(response,'Yes');
end

% report
fprintf('The custom Symphony package was setup successfully.\n');
pause(1);
if showUC
  fprintf('Use the following dialog to create useres.\n');
  pause(1.2);
  % prompt for user creation
  admin.startup.CustomStartup.userCreator(fileparts(packageRoot));
end

end

