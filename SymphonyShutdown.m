function SymphonyShutdown()

userInfo = [];
startupData = [];

fpath = fileparts(mfilename('fullpath'));
files = dir(fullfile(fpath,'*.sy2'));
for f = 1:numel(files)
  try %#ok<TRYNC>
    S = load(fullfile(fpath,files(f).name),'-mat');
    if ismember('userInfo',fieldnames(S))
      userInfo = S.userInfo;
      startupData = S.startupData;
      break
    end
  end
end

if isempty(userInfo)
  fprintf('\nUnable to locate current user.\n');
  fprintf('Symphony is shutting down!\n\n');
  diary('off');
  return;
end

userStruct = startupData.(userInfo.user);

if strcmp(questdlg('Save current presets?', 'Ssve presets', 'Yes', 'No', 'Yes'),'Yes')
  
  presets = symphonyui.app.Presets.getDefault();
  names = presets.getAvailableProtocolPresetNames;
  
  userStruct.presets.(userInfo.setup) = cellfun( ...
    @(x) presets.getProtocolPreset(x), ...
    names, ...
    'UniformOutput', false ...
    );
  
  fprintf('Presets saved for:\n  User:% 25s\n  Setup:% 24s\n', ...
    userInfo.user, userInfo.setup ...
    );
end

% update save directory and naming scheme if changed in app options
options = symphonyui.app.Options.getDefault();

userStruct.fileDefaultLocation = options.fileDefaultLocation;
userStruct.fileDefaultName = options.fileDefaultName;

% now save the startupData variable without the userInfo variable.
startupData.(userInfo.user) = userStruct;
save(fullfile(fpath,files(1).name),'startupData','-mat');

fprintf('\nSymphony 2 is shutting down!\n\n');

diary('off');

end