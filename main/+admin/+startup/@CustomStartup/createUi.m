function createUi(obj)

if ~isempty(obj.view) && obj.view.isvalid
  figure(obj.view);
  drawnow();
end

view = figure( ...
  'NumberTitle', 'off', ...
  'MenuBar', 'none', ...
  'Toolbar', 'none', ...
  'Color', [1,1,1], ...
  'HandleVisibility', 'off', ...
  'Visible', 'on', ...
  'DockControls', 'off', ...
  'Interruptible', 'off' ...
  );

view.CloseRequestFcn = @(s,e)notify(obj, 'Close');

for c = {'Uicontrol', 'Uitable', 'Uipanel', 'Uibuttongroup', 'Axes'}
  set(view, ['Default' c{1} 'FontName'], 'Times New Roman');
  set(view, ['Default' c{1} 'FontSize'], 12);
  set(view, ['Default' c{1} 'FontUnits'], 'pixels');
end

view.Name = "Select User Setup";
view.Position = appbox.screenCenter(320,286);

% setup menus
editMenu = uimenu(view,'Text','Edit');
uimenu(editMenu,'Text','Add &User...','MenuSelectedFcn', @(s,e)obj.createNewUsers());
uimenu(editMenu,'Text','Change &Lab Name','MenuSelectedFcn',@(s,e)obj.changeLabName());
uimenu(editMenu,'Text','Re&fresh Users','MenuSelectedFcn',@(s,e)obj.populateUserSetups())
uimenu(editMenu,'Text', '&Reset','Separator', 'on', 'MenuSelectedFcn', @(s,e)obj.reset());

%main layout
layout = uix.VBox('Parent',view,'Spacing',3,'Padding',5);
layout.BackgroundColor = [1,1,1];

% create the user selection tree
setupTree = uiextras.jTree.Tree( ...
  'Parent', layout, ...
  'FontName', get(view, 'DefaultUicontrolFontName'), ...
  'FontSize', get(view, 'DefaultUicontrolFontSize')*1.5, ...
  'BorderType', 'none', ...
  'SelectionType', 'single', ...
  'SelectionChangeFcn', @obj.updateUserSelection ...
  );
root = setupTree.Root;
root.setIcon(symphonyui.app.App.getResource('icons', 'folder.png'));

button = uicontrol( ...
  'style', 'pushbutton', ...
  'Parent', layout, ...
  'String', 'Continue', ...
  'Tag', 'goButton' ...
  );
button.Enable = 'off';
button.Callback = @(s,e)notify(obj,'Close');

set(layout, 'Heights', [-1,28]);
drawnow();

% store handles
obj.view = view;
obj.uiMap('tree') = setupTree;
obj.uiMap('button') = button;
end

