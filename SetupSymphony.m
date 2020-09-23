function SetupSymphony()
% SETUPSYMPHONY Setup symphony to use our custom start/stop procedures.
% Keep this file in the custom package directory

import matlab.internal.apputil.AppUtil;

packageRoot = fileparts(mfilename('fullpath'));

% Locate Symphony and add it to the path
infos = AppUtil.getAllAppsInDefaultLocation;
if isempty(infos)
  error( ...
    "SETUPSYMPHONY:NOTINSTALLED", ...
    "Install Symphony available from '%s'", ...
    'https://symphony-das.github.io/' ...
    );
end

appIndex = AppUtil.findAppIDs( ...
  {infos.id}, ...
  'SymphonyAPP', ...
  false ...
  );
appInfo = infos(appIndex);

% make sure Symphony is installed
if isempty(appInfo)
  error( ...
    "SETUPSYMPHONY:NOTINSTALLED", ...
    "Install Symphony available from '%s'", ...
    'https://symphony-das.github.io/' ...
    );
end

% app location string
appinstalldir = appInfo.location;

% generate the file path
apppath = java.io.File(appinstalldir);

resourcesfolder = matlab.internal.ResourcesFolderUtils.FolderName; 
canonicalpathtocodedir = fullfile(char(apppath.getCanonicalPath()));
allpaths = AppUtil.genpath(canonicalpathtocodedir);

% do not allow resources or metadata folders to be added to the path
allpaths = strsplit(allpaths,pathsep);
allpaths(contains(allpaths,{resourcesfolder,'metadata'})) = [];

% append the package folder to the path
here = fullfile(packageRoot,'main');
pathsToAdd = strjoin([allpaths,{genpath(here)}],pathsep);

% add the app to the MATLAB path
addpath(pathsToAdd);

% check for symphony preferences
if ~isempty(getpref('symphonyui'))
  response = questdlg( ...
    'Reset Symphony preferences? (reccommended)', ...
    'Reset Symphony', ...
    'Yes','No','Yes' ...
    );
  if strcmp(response,'Yes')
    rmpref('symphonyui');
  end
end

% import symphony settings and configure for our package
options = symphonyui.app.Options.getDefault();
options.startupFile = fullfile(packageRoot,'SymphonyStartup.m');
options.cleanupFile = fullfile(packageRoot,'SymphonyShutdown.m');
options.warnOnViewOnlyWithOpenFile = false;
try %#ok<TRYNC>
  options.save();
end

% search for exisiting users
userDirs = dir(fileparts(here));
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
  admin.startup.CustomStartup.userCreator(fileparts(here));
end

% remove symphony from the path
rmpath(pathsToAdd);
end

