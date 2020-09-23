function success = userCreator(root)

RIG_TYPES = {'Empty','ERG','Slice','N/A'};

success = false;

w = 370;
h = 300;

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

container.Name = 'Create New User';
container.Position = appbox.screenCenter(w,h);

%main layout
layout = uix.VBox('Parent',container,'Spacing',3,'Padding',5);
layout.BackgroundColor = [1,1,1];

% top Label
text01 = uicontrol(layout,...
  'Style', 'text' ...
  );
text01.HorizontalAlignment = 'left';
text01.BackgroundColor = [1,1,1];
text01.FontName = 'Times New Roman';
text01.String = 'Enter a user name:';

% Create nameInput
inputName = uicontrol(layout,...
  'Style', 'edit' ...
  );
inputName.Callback = @validateUserEntry;

% table
rigTable = uitable(layout, ...
  'units', 'pixels',  ...
  'Data', {'rigName', 'id','Empty'}, ...
  'ColumnEditable', [true,true,true], ...
  'ColumnFormat', {'char', 'char', RIG_TYPES}, ...
  'RowName', [], ...
  'ColumnName', {'Rig Name', 'Rig ID', 'Type'} ...
  );
rigTable.ColumnWidth = {(w-10)*3.5/6,(w-11)*1/6,(w-11)*1.5/6};
rigTable.TooltipString = sprintf( ...
  '%s.\n%s.', ...
  'Rig Name: Give the rig configuraion a name', ...
  'Rig ID: Give a short 2-3 character identifier' ...
  );
rigTable.CellEditCallback = @validateRigEntry;

% Create buttons
buttonGroup = uix.HBox('Parent',layout,'Spacing', 5, 'Padding', 0);
buttonGroup.BackgroundColor = [1,1,1];

% padding
uix.Empty('Parent',buttonGroup);

% add subtract buttons
% Create add rig Button
moreButton = uicontrol(buttonGroup, ...
  'Style', 'pushbutton' ...
  );
addIcon = double(imread(symphonyui.app.App.getResource('icons', 'add.png'))) / 255;
addIcon(addIcon == uint8(0)) = nan;
addIcon = addIcon ./ max(addIcon,[],3);
moreButton.CData = addIcon;
moreButton.Tooltip = 'Add another rig for this user.';
moreButton.Callback = @(s,e)updateRigList(rigTable,'more');

% Create remove rig Button
lessButton = uicontrol(buttonGroup, ...
  'Style', 'pushbutton' ...
  );
minusIcon = double(imread(symphonyui.app.App.getResource('icons', 'remove.png'))) / 255;
minusIcon(minusIcon== uint8(0)) = nan;
minusIcon = minusIcon./ max(addIcon,[],3);
lessButton.CData = minusIcon;
lessButton.Tooltip = 'Remove last rig for this user.';
lessButton.Callback = @(s,e)updateRigList(rigTable,'less');
% on startup, lessButton is disabled
lessButton.Enable = 'off';


%padding
uix.Empty('Parent',buttonGroup);

% Create goButton
goButton = uicontrol(buttonGroup, ...
  'Style', 'pushbutton' ...
  );
goButton.FontWeight = 'bold';
goButton.String = 'Create';
goButton.Callback = @(s,e)doCreateUser();

closeButton = uicontrol(buttonGroup, ...
  'Style', 'pushbutton' ...
  );
closeButton.String = 'Close';
closeButton.Callback = @(s,e)doClose();

% last spacer
uix.Empty('Parent',buttonGroup);

set(buttonGroup,'Widths', [-1,28,28,-1,86,86,-1]);
set(layout,'Heights',[16,26,-1,26]);


container.Visible = 'on';

container.WindowStyle = 'modal';
uiwait(container);


%% Callbacks
  function validateUserEntry(src,~)
    import admin.startup.CustomStartup;
    if isempty(src.String)
      rigTable.Data = {'rigName', 'id', 'Empty'};
      return 
    end
    
    [uMap,userList] = getUserMap();
    
    newUser = admin.utils.camelizer(src.String);
    try
      newUser = validatestring(lower(newUser),userList);
      existingUser = true;
    catch
      existingUser = false;
    end
    src.String = newUser;
    % update table if existing user
    if existingUser
      existingRigs = uMap(newUser);
      rigIDs = cellfun( ...
        @(loc) CustomStartup.getRigID(loc), ...
        fullfile(root,newUser,existingRigs), ...
        'UniformOutput', false ...
        );
      existingRigs{end+1} = sprintf('rigName%d',length(existingRigs)+1);
      rigIDs{end+1} = 'id';
      rigTable.Data = [ ...
        existingRigs(:), ...
        rigIDs(:), ...
        admin.utils.rep({'N/A';'Empty'},1,[numel(rigIDs)-1,1]) ...
        ];
    else
      rigTable.Data = {'rigName', 'id', 'Empty'};
    end
    
    % update minus button
    if size(rigTable.Data,1) > 1
      lessButton.Enable = 'on';
    else
      lessButton.Enable = 'off';
    end
    drawnow('nocallbacks');
  end

  function validateRigEntry(src,evt)
    % check if the cell edited belongs to an existing setup, if so,
    % revert data. If not, validate the entry.
    [uMap,userList] = getUserMap();
    
    usr = inputName.String;
    % exists?
    try
      usr = validatestring(lower(usr),userList);
      setups = uMap(usr);
    catch
      setups = {};
    end
    % check if we can remove this entry
    % collect previous data table
    pDat = src.Data;
    pDat{evt.Indices(1),evt.Indices(2)} = evt.PreviousData;

    if ~ismember(pDat{evt.Indices(1),1},setups)
      % if the new entry is empty, delete the row from the table
      if isempty(evt.NewData)
        % can delete
        src.Data(evt.Indices(1),:) = [];
        if size(src.Data,1) > 1
          lessButton.Enable = 'on';
        else
          lessButton.Enable = 'off';
        end
        return;
      end
      % Now check which index we are editing and camelize or lower and
      % strip whitespace
      switch evt.Indices(2)
        case 1
          % validate name
          newRig = admin.utils.camelizer(evt.NewData);
          % collect the unedited entries
          sDat = src.Data;
          sDat(evt.Indices(1),:) = [];
          if ismember(newRig,setups) || ismember(newRig,sDat)
            % is a member of existing setups, we cannot change these
            src.Data{evt.Indices(1),evt.Indices(2)} = evt.PreviousData;
          else
            % ok to change
            src.Data{evt.Indices(1),1} = newRig;
          end
        case 2
          % validate id
          id = src.Data{evt.Indices(1),2};
          newID = lower(admin.utils.camelizer(id));
          newID = regexprep( ...
            newID, ...
            '[\d\s_$|.*+?-]', ...
            '' ...
            );
          src.Data{evt.Indices(1),2} = newID;
        case 3
          % disallow N/A on new rigs
          if strcmp(evt.NewData,'N/A')
            src.Data{evt.Indices(1),evt.Indices(2)} = 'Empty';
          end
      end
    else
      % cannot edit/delete this entry, so revert
      src.Data{evt.Indices(1),evt.Indices(2)} = evt.PreviousData;
    end
  end

  function updateRigList(hTable,type)
    if strcmp(type,'more')
      % append a row
      nExist = size(hTable.Data,1) + 1;
      hTable.Data(end+1,:) = { ...
        sprintf('rigName%d',nExist), ...
        'id', ...
        'Empty'
        };
    else
      % remove last row if not existing
      [uMap,userList] = getUserMap();
      
      tableData = hTable.Data;
      dropRig = tableData{end,1};
      usr = inputName.String;
      % exists?
      try
        usr = validatestring(lower(usr),userList);
        setups = uMap(usr);
      catch
        setups = {};
      end
      if ~ismember(dropRig,setups)
        % can drop this rig
        hTable.Data(end,:) = [];
      else
        warning('Cannot delete established rigs. Delete the folders manually.');
      end
      nExist = size(hTable.Data,1);
    end
    % set button enable
    if nExist > 1
      lessButton.Enable = 'on';
    else
      lessButton.Enable = 'off';
    end
  end

  function doClose()
    uiresume(container);
    delete(container);
  end

  function doCreateUser()
    import admin.utils.getPackageRoot;
    
    [uMap,userList] = getUserMap();
    
    usr = inputName.String;
    if isempty(usr)
      error('Enter valid user name');
    end
    
    userRoot = fullfile(root,usr);
    newRigs = rigTable.Data;
    
    % Determine if we have new setups
    try
      usr = validatestring(lower(usr),userList);
      setups = uMap(usr);
    catch
      setups = {};
    end
    newRigs(ismember(newRigs,setups),:) = [];
    if isempty(newRigs)
      warning('No new rigs to add.');
      return
    end
    
    % create User folder
    [ok,msg] = mkdir(userRoot);
    if ~ok
      error('Could not create user: "%s" because "%s"..', usr,msg); 
    end
    
    % location of the basic user package zip file
    for r = 1:size(newRigs,1)
      % create the rig root directory
      thisLocation = fullfile(userRoot,newRigs{r,1},['+',newRigs{r,2}]);
      [ok,msg] = mkdir(thisLocation);
      if ~ok
        warning('Could not create rig because: "%s".',msg);
        success = false;
        continue
      end
      zLoc = fullfile( ...
        getPackageRoot(), ...
        'main','lib','templates', ...
        [newRigs{r,3},'.zip'] ...
        );
      try
        unzip(zLoc,thisLocation);
        pause(0.1);
        success = true;
      catch x
        warning( ...
          x.identifier, ...
          'Could not install user package because:\n"%s"', ...
          x.message ...
          );
        success = false;
      end
    end
    if success
      % merge existing and new rigs into the user entry in the userMap
      validateUserEntry(inputName,[]);
    end
  end

  function [userMap,users] = getUserMap()
    userMap = containers.Map();
    rootContents = dir(root);
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
        cellstr(ls(fullfile(root,usr))), ...
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

end

