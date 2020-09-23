classdef NoteScribe < admin.core.modules.Module
  
  properties (Access = private)
    mainLayout
    bodyLayout
    buttonLayout
    titleText
    statusText
    noteInput
    markButton
  end
  
  %% Construction
  
  methods
    
    function obj = NoteScribe()
      obj = obj@admin.core.modules.Module();
    end
    
  end
  
  methods (Access = protected)
    % Bindings
    
    function willGo(obj)
      try
        obj.loadSettings();
      catch x
        obj.log.debug(['Failed to load presenter settings: ' x.message], x);
      end
    end
    
    function willStop(obj)
      try
        obj.saveSettings();
      catch x
        obj.log.debug(['Failed to save presenter settings: ' x.message], x);
      end
    end

    function loadSettings(obj)
      % load previous position
      position = obj.view.position;
      obj.view.position = obj.settings.Get('viewPosition',position);
      
      % load the previous layout of the flex box
      h = get(obj.mainLayout,'Heights');
      hStored = obj.settings.Get('heights',h);
      if numel(h) ~= numel(hStored)
        hStored((numel(h)+1):end) = [];
      end
      obj.mainLayout.Heights = hStored;
    end

    function saveSettings(obj)
      position = obj.view.position;
      obj.settings.Set('viewPosition', position);
      obj.settings.Set('heights', get(obj.mainLayout,'Heights'));
    end
    
  end
  
  %% UI Creation
  
  methods
    
    createUi(obj,fig)
    
  end
  
  %% Service Interaction
  
  methods (Access = protected)
    
    function saveNote(obj)
      noteString = obj.noteInput.String;
      if isempty(noteString), return; end
      wrappedNote = char(join(cellstr(noteString),'\n'));
      % on update, let's send a string to the experimnet's notes slot
      if obj.documentationService.hasOpenFile()
        % file exists, let's get experiment
        try
          experiment = obj.documentationService.getExperiment();
          experiment.addNote(wrappedNote);
          % this is the success case, set the status string accordingly
          curTime = strtrim(datestr(clock,'HH:MM:SSAM'));
          obj.statusText.String = sprintf( ...
            'Last note saved @ %s', ...
            curTime ...
            );
        catch
          fprintf(2, ...
            'Could not save this note. Here is the log: \n"%s"\n\n', ...
            sprintf(wrappedNote) ...
            );
        end
      else
        fprintf('No open file, note not saved.\n');
      end
      obj.noteInput.String = '';
    end
    
  end
  
  %% Callbacks
  
  methods (Access = protected)
    
    function keyCapture(obj,~,evt)
      capt = evt.data;
      if length(capt.Modifier) == 1 && strcmpi(capt.Modifier,'control')
        if strcmpi(capt.Key,'return')
          import java.awt.Robot;
          import java.awt.event.KeyEvent;
          robot = Robot;
          pState = pause('on');
          if ismember('control',get(obj.view.getFigureHandle,'currentModifier'))
            % release control
            robot.keyRelease(KeyEvent.VK_CONTROL);
          end
          pause(0.01);
          % the string will be stored if we hit escape
          % pressing enter would just add a new line to the box
          robot.keyPress(KeyEvent.VK_ESCAPE)
          pause(0.01);
          robot.keyRelease(KeyEvent.VK_ESCAPE)
          pause(0.01);
          pause(pState);
          % now save the string
          obj.saveNote();
        end
      end
    end
    
  end
  
end