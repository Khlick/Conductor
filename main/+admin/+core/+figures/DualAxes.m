classdef (Abstract) DualAxes < admin.core.figures.FigureWrap
  
  properties (Access = protected)
    axesHandles
    axesLayout
    labelListeners
  end
  
  methods
    
    function createUi(obj)
      import uix.HBoxFlex;
      import uix.CardPanel;
      
      fig = obj.figureHandle;
      fig.Color = [1,1,1];
      fig.Visible = 'on';
      
      obj.axesLayout = HBoxFlex( ...
        'Parent', fig, ...
        'Padding', 0, ...
        'Spacing', 4, ...
        'BackgroundColor', fig.Color ...
        );
      
      % build axes
      obj.labelListeners = cell(1,2);
      obj.axesHandles = gobjects(1,2);
      for a = 1:2
        % creating a card panel to allow control over minimal whitespace when
        % labels are set/removed.
        axBox = CardPanel( ...
          'Parent', obj.axesLayout, ...
          'Padding', 26, ...
          'BackgroundColor', fig.Color ...
          );
        
        ax = axes( ...
          'Parent', axBox, ...
          'FontName', get(fig, 'DefaultUicontrolFontName'), ...
          'FontSize', get(fig, 'DefaultUicontrolFontSize')*0.85, ...
          'XTickMode', 'auto', ...
          'ActivePositionProperty', 'position' ...
          );
        lsn = struct();
        lsn.XLabel = addlistener( ...
          ax.XLabel,'String','PostSet', ...
          @obj.onLabelChanged ...
          );
        lsn.YLabel = addlistener( ...
          ax.YLabel,'String','PostSet', ...
          @obj.onLabelChanged ...
          );
        obj.labelListeners{a} = lsn;
        obj.axesHandles(a) = ax;
      end
      
      obj.axesLayout.Widths = [-2,-1];
    end
    
    
    function clear(obj)
      clear@admin.core.figures.FigureWrap(obj)
      nonempties = cellfun( ...
        @(v) isa(v,'struct'), ...
        obj.labelListeners, ...
        'UniformOutput',true ...
        );
      if any(nonempties)
        cellfun( ...
          @(v) structfun(@delete,v), ...
          obj.labelListeners(nonempties), ...
          'UniformOutput', false ...
          );
      end
      % ensure we have empty cells
      obj.labelListeners = cell(1,2);
    end
    
    function loadSettings(obj)
      % Overwrite to save custom settings
      
      % superclass stores/loads figure position
      loadSettings@admin.core.figures.FigureWrap(obj);
      
      % get the propertymap to store custom settings
      propMap = obj.settings.propertyMap;
      if ~isa(propMap,'containers.Map')
        propMap = containers.Map('KeyType', 'char', 'ValueType','any');
        obj.settings.propertyMap = propMap;
        obj.settings.save();
      end
      
      % load widths only if they're present, otherwise use the default [-2,-1].
      if propMap.isKey('Widths')
        obj.axesLayout.Widths = propMap('Widths');
      end
      
    end
    
    function saveSettings(obj)
      % SAVESETTINGS Save settings from custom layotus
      % See: saveSettings@admin.core.figures.FigureWrap
      % & symphonyui.core.FigureHandlerSettings.m
      
      % superclass stores/loads figure position
      saveSettings@admin.core.figures.FigureWrap(obj);
      
      % get the propertymap to store custom settings
      propMap = obj.settings.propertyMap;
      if ~isa(propMap,'containers.Map')
        propMap = containers.Map('KeyType', 'char', 'ValueType','any');
      end
      
      % store the widths of the layout
      propMap('Widths') = obj.axesLayout.Widths;
      obj.settings.propertyMap = propMap;
      obj.settings.save();
    end
    
  end
  
  methods (Static)
    
    function onLabelChanged(~,evt)
      
      ax = ancestor(evt.AffectedObject,'matlab.graphics.axis.Axes');
      axBox = ax.Parent;
      if isempty(ax.XLabel.String) && isempty(ax.YLabel.String)
        axBox.Padding = 26;
      elseif axBox.Padding ~= 36
        axBox.Padding = 36;
      end
      drawnow;
    end
    
  end
  
end