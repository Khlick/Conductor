classdef DeviceConfigurator < admin.core.modules.Module
  % DEVICECONFIGURATOR
  % General invocation is:
  % createUi -> willGo -> bind -> show -> (didGo)
  % General shutdown is:
  % willStop -> unbind -> close -> (didStop)
  
  properties (Constant)
    IGNORE_DEVICE_OUTPUT = ["oscilloscope","filter wheel"]
    IGNORE_CONFIGURABLE_DEVICE = "filter wheel"
    VERSION_= "2.0.1"
  end
  
  properties (Access = private)
    devices
    deviceListeners
  end
  
  % ui
  properties %(Access = private)
    mainLayout
    controlBlocks
  end
  
  properties (Hidden,Access = private)
    aes
  end
  
  properties (Dependent = true)
    deviceCount
    hasDevices
    backgroundDevices
    configurableDevices
    lightPathDevices
  end
  
  %% Construction
  methods
    
    function obj = DeviceConfigurator()
      obj = obj@admin.core.modules.Module();
    end
    
  end
  
  methods (Access = protected)
    % Bindings
    
    function willGo(obj)
      obj.devices = obj.configurationService.getDevices();
      % Populate the rest of the UI now that we have devices
      % Changing the order of the next few lines will change the order of
      % the presentaion.
      try
        obj.createBackgroundGrid();
        obj.createConfigurableDevicesConfiguration();
        obj.createLightPathConfiguration();
      catch me
        obj.log.debug(['Failed to populate entities for reason: ',me.message],me);
        obj.stop();
        return
      end
      
      % try to load the previously stored "settings" for this module
      try
        obj.loadSettings();
      catch x
        obj.log.debug(['Failed to load presenter settings: ' x.message], x);
      end
    end
    
    function bind(obj)
      % BIND Bind listeners to view and devices
      % Note: Super binds a close listener.
      bind@admin.core.modules.Module(obj);
      
      % Bind listeners to devices
      obj.bindDevices();
      
      % Bind listener to rig initialization to update components on new rig
      % initialization
      c = obj.configurationService;
      obj.addListener(c,'InitializedRig',@obj.onServiceInitializedRig);
      
    end
    
    function bindDevices(obj)
      % BINDDEVICES Add listeners to the current device list
      %   Here we split device listeners from main module listeners to
      %   allow for dynamic reloading rig components without killing the
      %   functionality of the module.
      
      % Add listener to background-settable devices. If the background is
      % set, we should update the property grid from the background values
      % rather than just accepting the entered value.
      bgDevs = obj.backgroundDevices;
      for d = 1:numel(bgDevs)
        obj.deviceListeners{end+1} = addlistener( ...
          bgDevs{d}, ...
          'background', 'PostSet', ...
          @(s,e)obj.updateBackgroundGrid() ...
          );
      end
      
      % Add listeners to the ND Devices so that we can alter them from
      % another part of the application and they will update here.
      lDevs = obj.configurableDevices;
      for d = 1:numel(lDevs)
        obj.deviceListeners{end + 1} = addlistener( ...
          lDevs{d}, ...
          'AddedConfigurationSetting', ...
          @(s,e)obj.updateConfigurableDevicesConfigurations() ...
          );
        obj.deviceListeners{end + 1} = addlistener( ...
          lDevs{d}, ...
          'SetConfigurationSetting', ...
          @(s,e)obj.updateConfigurableDevicesConfigurations() ...
          );
        obj.deviceListeners{end + 1} = addlistener( ...
          lDevs{d}, ...
          'RemovedConfigurationSetting', ...
          @(s,e)obj.updateConfigurableDevicesConfigurations() ...
          );
      end
      
      % Add listeners to the filter wheels
      fDevs = obj.lightPathDevices;
      for d = 1:numel(fDevs)
        obj.deviceListeners{end+1} = addlistener( ...
          fDevs{d}, ...
          'onExternalTriggeredMove', ...
          @obj.updateLightPathSelections ...
          );
      end
    end
    
    function willStop(obj)
      try
        obj.saveSettings();
      catch x
        obj.log.debug(['Failed to save presenter settings: ' x.message], x);
      end
    end
    
    function unbind(obj)
      unbind@admin.core.modules.Module(obj);
      % super kills all listeners in the obj.listeners property.
      obj.unbindDevices();
    end
    
    function unbindDevices(obj)
      while ~isempty(obj.deviceListeners)
        delete(obj.deviceListeners{end});
        obj.deviceListeners(end) = [];
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
        % do not try to load previous heights
        return
      end
      obj.mainLayout.Heights = hStored;
    end
    
    function saveSettings(obj)
      position = obj.view.position;
      obj.settings.Set('viewPosition', position);
      obj.settings.Set('heights', get(obj.mainLayout,'Heights'));
    end
    
  end
  
  %% Access
  
  methods
    
    function tf = get.hasDevices(obj)
      tf = ~isempty(obj.devices);
    end
    
    function n = get.deviceCount(obj)
      if ~obj.hasDevices
        n = 0;
        return
      end
      n = numel(obj.devices);
    end
    
    function devices = get.backgroundDevices(obj)
      if ~obj.hasDevices, return; end
      n = obj.deviceCount;
      isOutputDevices = true(n,1);
      for d = 1:n
        % determine if we should ignore a particular device based on
        % constant property or resource setting
        this = obj.devices{d};
        % check if has an output stream
        if isempty(this.getOutputStreams())
          isOutputDevices(d) = false;
          continue
        end
        % exclude any in the ignore list
        if isprop(this,'deviceType')
          isIgnored = contains( ...
            this.deviceType, ...
            obj.IGNORE_DEVICE_OUTPUT, ...
            'IgnoreCase',true ...
            );
        else
          isIgnored = contains( ...
            this.name, ...
            obj.IGNORE_DEVICE_OUTPUT, ...
            'IgnoreCase', true ...
            );
        end
        % verify
        if any(isIgnored)
          isOutputDevices(d) = false;
          continue
        end
        % check resources
        rNames = this.getResourceNames();
        if ismember('ignoreoutputcontrol',lower(rNames))
          isOutputDevices(d) = this.getResource('ignoreOutputControl');
        end
      end
      % collect devices
      devices = obj.devices(isOutputDevices);
    end
    
    function devices = get.configurableDevices(obj)
      % configurableDevices are devices with configuration settings unless excluded by IGNORE_CONFIGURABLE_DEVICE
      if ~obj.hasDevices, return; end
      n = obj.deviceCount;
      % assume all devices are configurable, then loop through and exclude
      % devices that don't have configurations or are in the exclude list
      isConfigurableDevices = true(n,1);
      for d = 1:n
        this = obj.devices{d};
        % check if has a configuration
        configs = this.getConfigurationSettingDescriptors();
        if isempty(configs)
          isConfigurableDevices(d) = false;
          continue
        end
        % exclude any in the ignore list
        if isprop(this,'deviceType')
          isIgnored = contains( ...
            this.deviceType, ...
            obj.IGNORE_CONFIGURABLE_DEVICE, ...
            'IgnoreCase',true ...
            );
        else
          isIgnored = contains( ...
            this.name, ...
            obj.IGNORE_CONFIGURABLE_DEVICE, ...
            'IgnoreCase', true ...
            );
        end
        % verify
        if any(isIgnored)
          isConfigurableDevices(d) = false;
          continue
        end
      end
      % collect the devices
      devices = obj.devices(isConfigurableDevices);
    end
    
    function devices = get.lightPathDevices(obj)
      % LIGHTPATHDEVICES are filter wheels (for now).
      if ~obj.hasDevices, return; end
      n = obj.deviceCount;
      isFW = false(n,1);
      for d = 1:n
        this = obj.devices{d};
        if isprop(this,'deviceType')
          isFW(d) = strcmpi(this.deviceType,'Filter Wheel');
        else
          isFW(d) = ~isempty( ...
            regexpi(this.name,'(filter)|(wheel)','once') ...
            );
        end
      end
      devices = obj.devices(isFW);
    end
  end
  
  %% UI Creation
  
  methods
    
    createUi(obj,fig)
    
  end
  
  methods (Access = protected)
    
    % Background configurations
    createBackgroundGrid(obj)
    populateBackgroundGrid(obj)
    updateBackgroundGrid(obj)
    
    % ConfigurableDevices and Other Configurations
    createConfigurableDevicesConfiguration(obj)
    populateConfigurableDevicesConfiguration(obj)
    updateConfigurableDevicesConfigurations(obj)
    
    % Filter wheels and Other light path devices
    createLightPathConfiguration(obj)
    populateLightPathConfiguration(obj)
    updateLightPathConfiguration(obj)
    updateLightPathSelections(obj,src,evt)
    
  end
  
  %% Service Interaction
  methods (Access = protected)
    
    function writeNote(obj,noteString)
      if obj.documentationService.hasOpenFile()
        % file exists, let's get experiment
        try
          experiment = obj.documentationService.getExperiment();
          experiment.addNote(noteString);
        catch
          %log?
        end
      end
    end
    
  end
  
  %% Callbacks
  
  methods (Access = protected)
    
    function onServiceInitializedRig(obj,~,~)
      obj.unbindDevices();
      obj.devices = obj.configurationService.getDevices();
      obj.updateBackgroundGrid();
      obj.updateConfigurableDevicesConfigurations();
      obj.updateLightPathConfiguration();
      obj.bindDevices();
    end
    
    function onSetBackground(obj,~,event)
      % ONSETBACKGROUND Sets the output device background value immediately.
      p = event.Property;
      device = obj.configurationService.getDevice(p.Name);
      
      background = device.background;
      device.background = symphonyui.core.Measurement(p.Value, ...
        device.background.displayUnits);
      try
        device.applyBackground();
      catch x
        device.background = background;
        obj.view.showError(x.message);
        return;
      end
    end
    
    function onDeviceConfigured(obj,~,event)
      % ONDEVICECONFIGURED Update any configuration for a device.
      p = event.Property;
      % get device from property category
      device = obj.configurationService.getDevice(p.Category);
      prev = device.getConfigurationSetting(p.Name);
      if isequal(prev,p.Value), return; end
      device.setConfigurationSetting(p.Name,p.Value);
      noteString = sprintf( ...
        'Setting %s config for "%s" to: %s', ...
        p.Name, device.name, strjoin(string(p.Value),', ') ...
        );
      obj.writeNote(noteString);
    end
    
    function onLightPathConfigured(obj,source,event)
      % identify the wheel object and wheel
      id = strsplit(source.Tag,'|');
      lpDevs = obj.lightPathDevices;
      % collect the object
      this = lpDevs{cellfun(@(d) strcmpi(d.name,id{1}), lpDevs)};
      % determine which wheel index is being altered
      wIdx = this.getWheelIndexFromLabel(id{2});
      % update this wheel
      this.update(event.NewValue,wIdx);
      obj.writeNote( ...
        sprintf('Updating device "%s" to: %s', this.name, this.Current) ...
        );
    end
    
  end
  
end
