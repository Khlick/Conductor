function [institute,lab] = promptForLab()
import appbox.screenCenter;

lab = '';
institute = '';

container = figure( ...
  'NumberTitle', 'off', ...
  'MenuBar', 'none', ...
  'Toolbar', 'none', ...
  'HandleVisibility', 'off', ...
  'Visible', 'off', ...
  'DockControls', 'off', ...
  'Interruptible', 'off', ...
  'Name', 'Setup', ...
  'Position', screenCenter(320, 100),...
  'Color', [1,1,1]);
set(container, 'DefaultUicontrolFontName', 'Times New Roman');
set(container, 'DefaultUicontrolFontSize', 12);
set(container, 'DefaultUIControlBackgroundColor', [1,1,1]);
set(container, 'DefaultFigureColor', [1,1,1]);


layout = uix.VBox( ...
  'Parent', container, ...
  'Spacing', 3, ...
  'Padding', 5 ...
  );
layout.BackgroundColor = [1,1,1];
uix.Empty('Parent', layout);
% enter institution

institutionLayout = uix.HBox( ...
  'Parent', layout, ...
  'Spacing', 5, ...
  'Padding', 0 ...
  );
institutionLayout.BackgroundColor = [1,1,1];

institutionText = uicontrol( ...
  institutionLayout,...
  'Style', 'text', ...
  'units', 'pixels' ...
  );
institutionText.HorizontalAlignment = 'right';
institutionText.FontName = 'Times New Roman';
institutionText.String = 'Institution:';

institutionEdit = uicontrol( ...
  institutionLayout,...
  'Style', 'edit', ...
  'units', 'pixels' ...
  );
institutionEdit.Tag = 'institution';
uix.Empty('Parent',institutionLayout);
institutionLayout.Widths = [65,-1,65];

labLayout = uix.HBox( ...
  'Parent', layout, ...
  'Spacing', 5, ...
  'Padding', 0 ...
  );
labLayout.BackgroundColor = [1,1,1];

labText = uicontrol( ...
  labLayout,...
  'Style', 'text', ...
  'units', 'pixels' ...
  );
labText.HorizontalAlignment = 'right';
labText.FontName = 'Times New Roman';
labText.String = 'Lab:';

% Create userDropdown
labEdit = uicontrol( ...
  labLayout,...
  'Style', 'edit', ...
  'units', 'pixels' ...
  );
labEdit.Tag = 'lab';
uix.Empty('Parent',labLayout);
labLayout.Widths = [65,-1,65];

% Create goButton
buttonLayout = uix.HBox( ...
  'Parent', layout, ...
  'Spacing', 5, ...
  'Padding', 0 ...
  );
buttonLayout.BackgroundColor = [1,1,1];
uix.Empty('Parent',buttonLayout);

goButton = uicontrol( ...
  buttonLayout, ...
  'Style', 'pushbutton', ...
  'units', 'pixels' ...
  );
goButton.FontWeight = 'bold';
goButton.String = 'Save';
uix.Empty('Parent',buttonLayout);

buttonLayout.Widths = [-1,100,-1];

uix.Empty('Parent', layout);
layout.Heights = [-1,26,26,30,-1];


% setup callbacks
labEdit.Callback = @validateName;
institutionEdit.Callback = @validateName;

goButton.Callback = @(s,e)assignLabName(container);
container.CloseRequestFcn = @(s,e)assignLabName(container);
container.Visible = 'on';
drawnow();
pause(0.05);
uicontrol(institutionEdit);

container.WindowStyle = 'modal';
uiwait(container);

  function assignLabName(fig)
    import admin.utils.camelizer;
    import matlab.lang.makeValidName;
    lEdit = findobj(fig,'Tag','lab');
    iEdit = findobj(fig,'Tag','institution');
    % institution
    value = iEdit.String;
    if isempty(value)
      warndlg('Institution cannot be empty.');
      return
    end
    institute = makeValidName(camelizer(value));
    % lab
    value = lEdit.String;
    if isempty(value)
      warndlg('Lab name cannot be empty.');
      return
    end
    lab = makeValidName(camelizer(value));
    % resume
    uiresume(fig);
    delete(fig); 
  end

  function validateName(s,~)
    if ~isvalid(s), return; end
    import admin.utils.camelizer;
    import matlab.lang.makeValidName;
    s.String = makeValidName(camelizer(s.String));
  end

end

