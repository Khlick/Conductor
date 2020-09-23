classdef FigureWrap < symphonyui.core.FigureHandler
  
  properties (SetAccess = private)
    device
    sweepColor
    colorMapping
    storedSweepColor
  end
  
  properties (Abstract, Access = protected)
    axesHandles
  end
  
  properties (Access = protected)
    sweep
    sweeps
    storedSweep
    disableTitles
  end
  
  properties
    instanceId
  end
  
  methods
    
    % Required methods in subclasses
    %createUi(obj);
    
    function obj = FigureWrap(device,varargin)
      import appbox.setIconImage;
      
      co = get(groot, 'defaultAxesColorOrder');
      
      ip = inputParser();
      ip.addParameter('instanceId', '', @(x) ischar(x) || isempty(x));
      ip.addParameter('sweepColor', co(1,:), @(x)ischar(x) || isvector(x));
      ip.addParameter('colorMapping',co(1,:), @ismatrix);
      ip.addParameter('storedSweepColor',[1,1,1].*0.45,@(x)ischar(x) || isvector(x));
      ip.addParameter('storeSweepEnabled', false, @(x)islogical(x) && isscalar(x));
      ip.addParameter('disableToolbar', false, @(x)islogical(x) && isscalar(x));
      ip.addParameter('disableMenubar', false, @(x)islogical(x) && isscalar(x));
      ip.addParameter('disableTitles', false, @(x)islogical(x) && isscalar(x));
      ip.addParameter('backgroundColor', [1,1,1], @(x)ischar(x) || isvector(x));
      
      ip.parse(varargin{:});
      
      % construct this plot with a unique instanceId
      instanceId = ip.Results.instanceId;
      if isempty(instanceId)
        % ensure we send, at least, and empty char array in case [] or {}
        % present
        instanceId = '';
      end
      % call constructor
      obj = obj@symphonyui.core.FigureHandler(instanceId);
      % store the ID
      obj.instanceId = instanceId;
      
      % Convert the background to desired
      set(obj.figureHandle,'Color', ip.Results.backgroundColor);
      % bind the device
      obj.device = device;
      obj.sweepColor = ip.Results.sweepColor;
      obj.storedSweepColor = ip.Results.storedSweepColor;
      obj.colorMapping = ip.Results.colorMapping;
      obj.disableTitles = ip.Results.disableTitles;
      % create the UI
      obj.createUi();
      % incorporate the stored sweep function
      if ip.Results.storeSweepEnabled
        % add store and clear buttons
        toolbar = findall(obj.figureHandle, 'Type', 'uitoolbar');
        storeSweepButton = uipushtool( ...
          'Parent', toolbar, ...
          'TooltipString', 'Store Sweep', ...
          'Separator', 'on', ...
          'ClickedCallback', @obj.onSelectedStoreSweep ...
          );
        setIconImage(storeSweepButton, ...
          symphonyui.app.App.getResource('icons', 'sweep_store.png') ...
          );
        clearSweepsButton = uipushtool( ...
          'Parent', toolbar, ...
          'TooltipString', 'Clear Sweep', ...
          'ClickedCallback', @obj.onSelectedClearSweep);
        setIconImage(clearSweepsButton, ...
          symphonyui.app.App.getResource('icons', 'sweep_clear.png'));
        if strcmp(toolbar.Visible,'off')
          toolbar.Visible = 'on';
        end
      end
      % deal with the toolbars
      if ip.Results.disableToolbar
        obj.figureHandle.ToolBar = 'none';
      end
      if ip.Results.disableMenubar
        obj.figureHandle.MenuBar = 'none';
      end
    end
    
    
    function handleEpoch(obj,epoch)
      if ~epoch.hasResponse(obj.device)
        warning(['Epoch does not contain a response for ' obj.device.name]);
        return
      end
      
    end
    
    
    function clear(obj)
      for a = 1:numel(obj.axesHandles)
        delete(obj.axesHandles(a).Children);
      end
      obj.sweep = [];
      obj.sweeps = {};
    end
    
    
    function loadSettings(obj)
      % LOADSETTINGS Load stored settings
      % The settings superclass has get() and put() methods for storing
      % arbitrary values to this instance (instanceClass_instanceID)
      % However, the settings main class (FigureHandlerSettings) contains a
      % 'propertyMap' containers.Map() object which we can utilize for storing
      % configurations. However, when we acces the propertyMap, it will be empty
      % ([]) the first time we get it. Once we have called the saveSettings
      % method and stored the populated map, it will be a map until the
      % superclass method, reset(), is invoked. Or if an appropriate rmpref()
      % was used to clear all symphony preferences.
      loadSettings@symphonyui.core.FigureHandler(obj);
    end
    
    function saveSettings(obj)
      % SAVESETTINGS Store custom settings.
      % The settings superclass has get() and put() methods for storing
      % arbitrary values to this instance (instanceClass_instanceID)
      % However, the settings main class (FigureHandlerSettings) contains a
      % 'propertyMap' containers.Map() object which we can utilize for storing
      % configurations. However, when we acces the propertyMap, it will be empty
      % ([]) the first time we get it. Once we have called the saveSettings
      % method and stored the populated map, it will be a map until the
      % superclass method, reset(), is invoked. Or if an appropriate rmpref()
      % was used to clear all symphony preferences.
      saveSettings@symphonyui.core.FigureHandler(obj);
    end
    
  end
  
  methods (Access = protected)
    
    function onSelectedStoreSweep(obj, ~, ~)
      obj.onSelectedClearSweep([],[]);
      
      store = obj.sweeps;
      for i = 1:numel(obj.sweeps)
        store{i}.line = copyobj(obj.sweeps{i}.line, obj.axesHandle);
        set(store{i}.line, ...
          'Color', obj.storedSweepColor, ...
          'HandleVisibility', 'off');
      end
      obj.storedSweeps(store);
    end
    
    
    function onSelectedClearSweep(obj,~,~)
      stored = obj.storedSweeps();
      for i = 1:numel(stored)
        delete(stored{i}.line);
      end
      obj.storedSweeps([]);
    end
    
    
    function col = getColor(obj,sweepNum)
      colorIndex = mod(sweepNum-1,size(obj.colorMapping,1))+1;
      col = obj.colorMapping(colorIndex,:);
      % set the sweep color
      obj.sweepColor = col;
    end
    
    
    function [x,y,units] = getResponseData(obj,epoch)
      % get the response data from the epoch
      response = epoch.getResponse(obj.device);
      [quantities, units] = response.getData();
      sampleRate = response.sampleRate.quantityInBaseUnits;
      scaleFactor = 1;
      if obj.device.hasResource('conversion')
        scaleFactor = obj.device.getResource('conversion');
      end
      if obj.device.hasResource('conversion_units')
        units = obj.device.getResource('conversion_units');
      end
      if numel(quantities) > 0
        x = ((1:numel(quantities))-1) ./ sampleRate; %
        y = quantities.*scaleFactor;
      else
        x=[];
        y=[];
      end
    end
    
  end
  
  methods (Static)
    
    function sweeps = storedSweeps(sweeps)
      % Static method to persist sweeps
      persistent stored;
      if nargin > 0
        stored = sweeps;
      end
      sweeps = stored;
    end
    
  end
end