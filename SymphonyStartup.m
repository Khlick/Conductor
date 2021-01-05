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

if ~exist([labName,'.sy2'], 'file')
  startupData = struct();
else
  % handle upgrade case. this will be removed in the future
  try
    load([labName,'.sy2'],'-mat','startupData');
  catch
    S = load([labName,'.sy2'],'-mat');
    if isfield(S,'customStartup')
      startupData = S.customStartup;
    else
      startupData = struct();
    end
  end
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
save([labName,'.sy2'],'startupData','userInfo','-v7.3');

% remove main\+conductor
contents = dir(fullfile(rootPath,'main','+*'));
contents(contains({contents.name},'admin')) = [];
if ~isempty(contents)
  rmdir(fullfile(contents.folder,contents.name),'s');
end

cd(fullfile(rootPath,userInfo.user,userInfo.setup));