function updateColonyList(obj,~,~)
% locate the colony list
loc = fullfile(obj.rootFolder,'main','lib','ColonyList.csv');
listData = readtable(loc,'delimiter',',','Format','%s%s');

w = 360;
h = 840;

view = figure( ...
  'NumberTitle', 'off', ...
  'MenuBar', 'none', ...
  'Toolbar', 'none', ...
  'Color', [1,1,1], ...
  'HandleVisibility', 'off', ...
  'Visible', 'off', ...
  'DockControls', 'off', ...
  'Interruptible', 'off' ...
  );

for c = {'Uicontrol', 'Uitable', 'Uipanel', 'Uibuttongroup', 'Axes'}
  set(view, ['Default' c{1} 'FontName'], 'Times New Roman');
  set(view, ['Default' c{1} 'FontSize'], 12);
  set(view, ['Default' c{1} 'FontUnits'], 'pixels');
end

view.Name = "Edit ";
view.Position = appbox.screenCenter(w,h);

%main layout
layout = uix.VBox('Parent',view,'Spacing',3,'Padding',5);
layout.BackgroundColor = [1,1,1];

% table
colonyTable = uitable(layout, ...
  'units', 'pixels',  ...
  'Data', table2cell(listData), ...
  'ColumnEditable', [true,true], ...
  'ColumnFormat', {'char', 'char'}, ...
  'RowName', [], ...
  'ColumnName', listData.Properties.VariableNames ...
  );
colonyTable.ColumnWidth = {(w-10)*1/3,(w-11)*2/3};
colonyTable.CellEditCallback = @validateEntry;

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
moreButton.Tooltip = 'Add new genotype entry.';
moreButton.Callback = @(s,e)onAddRow(colonyTable);

% Create remove rig Button
lessButton = uicontrol(buttonGroup, ...
  'Style', 'pushbutton' ...
  );
minusIcon = double(imread(symphonyui.app.App.getResource('icons', 'remove.png'))) / 255;
minusIcon(minusIcon== uint8(0)) = nan;
minusIcon = minusIcon./ max(addIcon,[],3);
lessButton.CData = minusIcon;
lessButton.Tooltip = 'Remove last genotype entry.';
lessButton.Callback = @(s,e)onRemRow(colonyTable);


%padding
uix.Empty('Parent',buttonGroup);

% Create goButton
goButton = uicontrol(buttonGroup, ...
  'Style', 'pushbutton' ...
  );
goButton.FontWeight = 'bold';
goButton.String = 'Save';
goButton.Callback = @(s,e)onUpdateTable(colonyTable,loc);

closeButton = uicontrol(buttonGroup, ...
  'Style', 'pushbutton' ...
  );
closeButton.String = 'Close';
closeButton.Tooltip = 'Unsaved changes will be lost!';
closeButton.Callback = @(s,e)onCloseEditor(view);

% last spacer
uix.Empty('Parent',buttonGroup);

set(buttonGroup,'Widths', [-1,28,28,-1,86,86,-1]);
set(layout,'Heights',[-1,26]);

view.CloseRequestFcn = @(s,e)onCloseEditor(s);

view.Visible = 'on';
view.WindowStyle = 'modal';
uiwait(view);

  function onCloseEditor(view)
    uiresume(view);
    delete(view);
  end
  function onUpdateTable(src,loc)
    newData = src.Data;
    empties = cellfun(@isempty,newData);
    drops = all(empties,2);
    newData(drops,:) = [];
    empties(drops,:) = [];
    
    if any(empties,'all')
      warndlg('Please fill in empty fields and try again.');
      src.Data = newData;
      return
    end
    
    newTable = cell2table( ...
      newData, ...
      'VariableNames', src.ColumnName ...
      );
    writetable(newTable,loc,'Delimiter',',');
    fprintf('simulated writing table.\n');
    disp(newTable)
  end
  function onAddRow(src)
    src.Data = [src.Data;{'',''}];
  end
  function onRemRow(src)
    src.Data(end,:) = [];
  end
  function validateEntry(src,evt)
    if ~isempty(evt.NewData)
      return
    end
    idx = src.Data(evt.Indices(1),:);
    if all(cellfun(@isempty,idx,'UniformOutput',true))
      src.Data(evt.Indices(1),:) = [];
    end
  end
end