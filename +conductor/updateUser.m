function updateUser()
% UPDATEUSER Update a user setup from the packaged templates.
% Modified files, rigs, sources, protocols are overwritten but any file with an
% unmatched name are left unmodified.

conductor.import();
% Load Symphony and the package into the path
import matlab.internal.apputil.AppUtil

packageRoot = admin.utils.getPackageRoot();
[~,lab,~] = fileparts(packageRoot);

% Locate Symphony and add it to the path
if isempty(which('Symphony.Core.SymphonyFramework')) 
  importSymphony();
end

% append the package folder to the path
here = fullfile(packageRoot,'main');
pathsToAdd = genpath(here);

% add the app to the MATLAB path
addpath(pathsToAdd);

% get the templates for rig types
templateLoc = fullfile(packageRoot,'main','lib','templates');
templates = dir(fullfile(templateLoc,'*.zip'));
templateNames = [{'N/C'};regexprep({templates.name}','\.zip','')]';

% find the users
[uMap,users] = getUserMap();

if isempty(users)
  error("No users installed!");
end

% resources for figure
userIcon = fullfile(packageRoot,'main','lib','icons','user.png');
firstUser = users{1};
firstSetup = uMap(firstUser);


%% UI

w = 530;
h = 220;

container = figure( ...
  'NumberTitle', 'off', ...
  'MenuBar', 'none', ...
  'Toolbar', 'none', ...
  'Color', [1,1,1], ...
  'HandleVisibility', 'off', ...
  'Visible', 'off', ...
  'DockControls', 'off', ...
  'Interruptible', 'off' ...
  );

container.CloseRequestFcn = @(s,e)doClose();
for c = {'Uicontrol', 'Uitable', 'Uipanel', 'Uibuttongroup', 'Axes'}
  set(container, ['Default' c{1} 'FontName'], 'Times New Roman');
  set(container, ['Default' c{1} 'FontSize'], 12);
  set(container, ['Default' c{1} 'FontUnits'], 'pixels');
end

container.Name = 'Update User Setups';
container.Position = appbox.screenCenter(w,h);

cu = onCleanup(@()delete(container));

%main layout
layout = uix.HBox('Parent',container,'Spacing',3,'Padding',5);
layout.BackgroundColor = [1,1,1];

% create the user selection tree
setupTree = uiextras.jTree.Tree( ...
  'Parent', layout, ...
  'FontName', get(container, 'DefaultUicontrolFontName'), ...
  'FontSize', get(container, 'DefaultUicontrolFontSize')*1.5, ...
  'BorderType', 'none', ...
  'SelectionType', 'single', ...
  'SelectionChangeFcn', @updateUserSelection ...
  );
root = setupTree.Root;
root.Name = lab;
root.setIcon(symphonyui.app.App.getResource('icons', 'folder.png'));

for uu = 1:numel(users)
  ur = users{uu};
  % build user node
  uN = uiextras.jTree.TreeNode('Parent', root, 'Name', ur);
  uN.setIcon(userIcon);
  setupTree.expandNode(uN);
end
setupTree.SelectedNodes = root.Children(strcmpi({root.Children.Name},firstUser));

% create the control layout
controlLayout = uix.VBox('Parent', layout, 'Spacing', 5, 'Padding', 0);

rigTable = uitable( ...
  controlLayout, ...
  'units', 'pixels',  ...
  'Data', {'name','N/C'}, ...
  'ColumnEditable', [false,true], ...
  'ColumnFormat', {'char', templateNames}, ...
  'RowName', [], ...
  'ColumnName', {'Rig Name', 'Update Type'} ...
  );
rigTable.Data = [firstSetup(:),admin.utils.rep({'N/C'},numel(firstSetup))];
rigTable.TooltipString = sprintf( ...
  '%s.\n%s.', ...
  'Rig Name: Rig configuraion a name', ...
  'Update Type: Which template to use to update contents' ...
  );

% Create buttons
buttonGroup = uix.HButtonBox('Parent',controlLayout,'Spacing', 5, 'Padding', 0);
buttonGroup.BackgroundColor = [1,1,1];

updateBut = uicontrol('Parent', buttonGroup, 'String', 'Update');
updateBut.Callback = @(s,e)doUpdate();

doneBut = uicontrol('Parent', buttonGroup, 'String', 'Done');
doneBut.Callback = @(s,e)doClose();

set(controlLayout,'Heights', [-1,26]);
set(layout,'Widths', [180,-1]);

rigTable.ColumnWidth = {rigTable.Position(3)-87,85};

container.SizeChangedFcn = @onSizeChanged;
container.Visible = 'on';
drawnow();

uiwait(container);

%% Callbacks
  function doUpdate()
    % unzip selected template for each rig
    u = setupTree.SelectedNodes.Name;
    d = rigTable.Data;
    upath = fullfile(packageRoot,u);
    for st = 1:size(d,1)
      if strcmp(d{st,2},'N/C')
        continue
      end
      % get the package id
      spath = fullfile(upath,d{st,1});
      id = dir(spath);
      dest = fullfile(spath,id(startsWith({id.name},'+')).name);
      src = fullfile(templateLoc,sprintf('%s.zip',d{st,2}));
      try
        unzip(src,dest);
      catch ME
        warning('CONDUCTOR:UPDATEUSER',"Could not update for reason: '%s'",ME.message);
        return
      end
      pause(0.01);
      uiwait(msgbox(sprintf('Updated: %s > %s',u, d{st,1}),'Success'));
    end
  end

  function doClose()
    uiresume(container);
    delete(container);
  end

  function updateUserSelection(src,evt)
    node = evt.Nodes;
    if strcmp(node.Name,lab)
      
      % root was selected, force to first user
      src.SelectedNodes = node.Children(1);
    
    end
    
    newNode = src.SelectedNodes;
    
    % update the setups table from the new user selection
    st = uMap(newNode.Name);
    rigTable.Data = [st(:),admin.utils.rep({'N/C'},numel(st))];
  end

  function [userMap,users] = getUserMap()
    userMap = containers.Map();
    rootContents = dir(packageRoot);
    users = regexp( ...
      {rootContents([rootContents.isdir]).name}', ...
      '(?<![^\.*])\w*', ...
      'match' ...
      );
    users = [users{:}];
    users(ismember(users,'main')) = [];
    
    % parse the user folder for setups
    N = numel(users);
    for u = 1:N
      usr = users{u};
      subs = regexp(...
        cellstr(ls(fullfile(packageRoot,usr))), ...
        '(?<![^\.*])\w*', ...
        'match' ...
        );
      subs = [subs{:}];
      if isempty(subs)
        % no setups installed for this user, drop them from the list
        continue
      end
      userMap(usr) = subs;
    end
  end

  function onSizeChanged(src,evt)
    drawnow('limitrate');
    rigTable.ColumnWidth = {rigTable.Position(3)-87,85};
  end
end

