function populateUserSetups(obj)
% initialze a new map
obj.userMap = containers.Map();
% locate all user folders
rootContents = dir(obj.rootFolder);
users = regexp( ...
  {rootContents([rootContents.isdir]).name}', ...
  '(?<![^\.*])\w*', ...
  'match' ...
  );
users = [users{:}];
users(ismember(users,'main')) = [];

if isempty(users)
  % no users yet, so force open new user setup
  users = obj.createNewUsers();
end

% parse the user folder for setups
N = numel(users);
for u = 1:N
  usr = users{u};
  subs = regexp(...
    cellstr(ls(fullfile(obj.rootFolder,usr))), ...
    '(?<![^\.*])\w*', ...
    'match' ...
    );
  subs = [subs{:}];
  if isempty(subs)
    % no setups installed for this user, drop them from the list
    continue
  end
  obj.userMap(usr) = subs;
end

% update the ui
obj.updateUi();
end