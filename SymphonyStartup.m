%% Custom startup file for Symphony2.x
% Prompts for user name from dropdown and then sets options accordingly.
% Options intended to be set:
%   searchPatch: [folder string] for protocol and rig setup files
%   fileDefaultLocation: [Fcn] User path for h5 save.
%%%%

rootPath = fileparts(mfilename('fullpath'));
% move to setup directory
cd(rootPath);

% add our custom common files to the matlab path
addpath(genpath(fullfile(rootPath,'main')));

% collect username and setup from user
%userInfo = admin.startup.object(rootPath);
userInfo = admin.startup.CustomStartup(rootPath);

% collect lab name
labName = userInfo.lab;
labFile = [labName,'.sy2'];
% if an older version of conductor was used, there will be a missing class in the
% file leading to class:destructorError. Let's turn that warning into an error
% temporariliy to catch it. If we catch it, it means 1) the files exists and 2) has
% the wrong startup object. So we will backup that file (*.bak) and move on creating
% a new one.
s = warning('error','MATLAB:class:DestructorError');
try
  cx = matfile(labFile,'Writable',true);
catch err
  %err = lasterror;
  % we are probably updating, let's backup the config file and create a new one.
  if strcmpi(err.identifier,'MATLAB:class:DestructorError')
    movefile(labFile,[labName,'.bak'],'f');
    cx = matfile(labFile,'Writable',true);
  end
end
warning(s);  

% rather than nesting if else, let's simply use try catch to get the startupData
% variable. 
try
  % load up-to-date startupData struct
  startupData = cx.startupData;
catch me
  % startupData not available, if acceptable exception caught, simply move on
  if ~ismember(me.identifier,{'MATLAB:MatFile:NoFile','MATLAB:MatFile:VariableNotInFile'})
    rethrow(me);
  end
  startupData = struct();
end

if ~isfield(startupData,userInfo.user)
  userStruct = struct(...
    'startupFile',mfilename('fullpath'),...
    'fileDefaultName',@()datestr(now,'yyyymmdd'),...
    'fileDefaultLocation', @()pwd,...
    'searchPath', '', ...
    'presets', struct() ...
    );
  %get save directory
  saveDir = uigetdir(...
    winqueryreg('HKEY_CURRENT_USER', ...
      'Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders',...
      'Desktop'),...
    'Choose save directory');
  userStruct.fileDefaultLocation = str2func(sprintf("@()'%s'",saveDir));
else
  userStruct = startupData.(userInfo.user);
end

%update search path based on selected rig
userStruct.searchPath = strjoin( ...
  { ...
    fullfile(rootPath,'main'); ... %shared
    fullfile(rootPath,userInfo.user,userInfo.setup) ... %private
  }, ...
  ';' ...
  );

% Set options
% options variable is loaded in the symphonyui main function before this startup
% script runs. Thus we have access to modify startup options as well as presets.
% Typically symphonyui will recall the last used options and presets, but we want to
% update the options and presets based on user and rig selection. Soon, preset banks
% will be available
%set options
options.fileDefaultLocation = userStruct.fileDefaultLocation;
options.searchPath = userStruct.searchPath;
%prevent admin Protocol and LEDProtocol from showing in available protocols
options.searchPathExclude = 'admin\.core\.\w*Protocol;admin\.descriptions\.*;'; 

% Presets
backupPresets = cellfun(@(x)presets.getProtocolPreset(x),...
  presets.getAvailableProtocolPresetNames,'unif',0);
%remove presets
cellfun(@(x)presets.removeProtocolPreset(x.name),backupPresets,'unif',0);
isFirstRun = userInfo.isFirstRun;
if ~isFirstRun && isfield(userStruct.presets, userInfo.setup)
  %set user based presets
  try
    cellfun( ...
      @(x)presets.addProtocolPreset(x), ...
      userStruct.presets.(userInfo.setup), ...
      'UniformOutput', 0 ...
      );
  catch
    cellfun(@(x)presets.addProtocolPreset(x),backupPresets,'unif',0);
    fprintf(2, ...
      [ ...
        '\nPresets failed to load, ', ...
        'using previous session protocol presets.\n' ...
      ]);
  end
else
  userInfo.completeFirstRun();
end

%save output
startupData.(userInfo.user) = userStruct;
userInfo.save();
cx.startupData = startupData;
cx.userInfo = userInfo;

% If previous version of conductor was used, let's remove main\+conductor folder to
% prefer the ./+conductor package.
contents = dir(fullfile(rootPath,'main','+*'));
contents(contains({contents.name},'admin')) = [];
if ~isempty(contents)
  rmdir(fullfile(contents.folder,contents.name),'s');
end

% change directory to the user / rig path and complete startup procedures
cd(fullfile(rootPath,userInfo.user,userInfo.setup));

pause(0.01);
