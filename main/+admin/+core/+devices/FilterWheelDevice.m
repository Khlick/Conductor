classdef FilterWheelDevice < symphonyui.core.Device
  % FILTERWHEELDEVICE Superclass for custom control of filter wheels
  
  events (NotifyAccess = protected)
    onBindPairedDevice
    onExternalTriggeredMove
  end
  
  properties (Constant,Hidden)
    MAX_ITER = 100
    BOUND_DEVICE_CONFIG_KEY = 'configName' % see bindPairedDevice
    BOUND_DEVICE_NAME_KEY = 'device'
    BOUND_RESOURCE_KEY = 'FilterWheel'
  end
  
  properties (Abstract = true, Dependent = true, SetAccess = protected)
    Wheel           % Current Wheel
    WheelId         % Current Wheel ID
    Position        % Current position in current wheel
    WheelCount      % Number of available wheels
    Count           % Number of available positions in current wheel
    Labels          % Access the labels in order of positions for current wheel
    Current         % Get the stored positions for attached wheels
    BoundDeviceName % Get the handle to the device bound to the active wheel
  end
  
  properties (Access = protected, SetObservable = true, AbortSet = false)
    current_
  end
  
  properties (SetAccess = protected)
    verbose
  end
  
  properties (Access = protected)
    cache
    controller
    filterMap % Map wheel / filter positions in nested maps.
    pairedDevice_ % Map of maps _("index") -> map(["ID","Device"])
    listeners
  end
  
  properties (Access = protected)
    open_ = false
  end
  
  properties
    deviceType = 'Filter Wheel';
  end
  
  properties (Dependent)
    isReady
    hasBoundDevice
  end
  
  methods
    
    function obj = FilterWheelDevice(name,port,varargin)
      import symphonyui.core.*;
      
      p = inputParser();
      p.KeepUnmatched = true;
      p.addRequired('Name', @ischar);
      p.addRequired('Port', @ischar);
      p.addParameter('Manufacturer', '', @ischar);
      p.addParameter('verbose', true, @islogical);
      p.parse(name,port,varargin{:});
      
      % Register the device with Symphony 2.x
      cobj = Symphony.Core.UnitConvertingExternalDevice( ...
        p.Results.Name, ...
        p.Results.Manufacturer, ...
        Symphony.Core.Measurement(0,Measurement.UNITLESS) ...
        );
      obj@symphonyui.core.Device(cobj);
      obj.cobj.MeasurementConversionTarget = Measurement.UNITLESS;
      
      % set the verbose flag
      obj.verbose = p.Results.verbose;
      
      % add the configuration to the
      % Configuration settings to be modified by interacting with the filter
      % wheel. These settings get stored with each epoch.
      obj.addConfigurationSetting('Position', '0', ...
        'type',symphonyui.core.PropertyType('char','row'));
      
      obj.addConfigurationSetting('ID', '0', ...
        'type',symphonyui.core.PropertyType('char','row'));
      
      obj.addConfigurationSetting('Current', '...', ...
        'type', symphonyui.core.PropertyType('char','row'));
      
      obj.addConfigurationSetting('Status', 'INITIALIZING', ...
        'type', symphonyui.core.PropertyType('char','row'));
      
      % connect to the device. Use unmachted inputs for customizing the serial
      % connection settings.
      try
        obj.connect(p.Results.Port,p.Unmatched);
        pause(0.1);
      catch x
        % allow the user to continue to run the setup, there will likely be
        % further errors/warnings at serial interfacing.
        warning( ...
          x.identifier, ...
          'Could not connect to filter wheel for reason: "%s"', ...
          x.message ...
          );
      end
      
      % Define empty map for filterMap. The filterMap functions as a map of the
      % attached device. The map should map a wheel number to map of that
      % wheel's ID, and positions. Preferrably, we should keep these as
      % one-index (i.e. avoid zero-indexing convention).
      % The best place to populate this map is in the constructor of the
      % concrete subclass
      obj.filterMap = containers.Map();
      
      % Make an empty map storing the current wheel and position
      obj.current_ = containers.Map({'wheel','position'}, {0,0});
      
      % add a listener to the current property to update the stoarge variable
      obj.listeners = struct();
      % listen to internal current wheel status changed
      obj.listeners.current = addlistener( ...
        obj, ...
        'current_','PostSet', ...
        @obj.didModifyCurrent ...
        );
      % listen for config settings changed
      obj.listeners.SetConfigurationSetting = addlistener( ...
        obj, ...
        'SetConfigurationSetting', ...
        @obj.didSetConfigurationSetting ...
        );
      %
      obj.listeners.pairedDevice = addlistener( ...
        obj, ...
        'onBindPairedDevice', ...
        @obj.didBindPairedDevice ...
        );
      % initialize pairedDevice options
      obj.listeners.pairedListeners = {};
      obj.pairedDevice_ = containers.Map('KeyType','double','ValueType','any');
      
      % empty the cache variable
      obj.cache = containers.Map();
    end
    
    function close(obj)
      if obj.isReady
        fclose(obj.controller);
        delete(obj.controller);
        lnames = fieldnames(obj.listeners);
        for i = 1:numel(lnames)
          if strcmp(lnames{i},'pairedListeners')
            cellfun(@delete,obj.listeners.(lnames{i}),'UniformOutput',false);
            continue
          end
          delete(obj.listeners.(lnames{i}));
        end
        obj.setConfigurationSetting('Status', 'CLOSED');
        obj.open_= false;
      end
    end
    
    
    function bindPairedDevice(obj,wheelIdx,device,configSettingName)
      % BINDPAIREDDEVICE Bind a device to the wheel status
      % Wheel position labels will get mapped to a supplied 'configSettingName'
      assert(numel(wheelIdx) == 1,'Can only bind 1 device at a time.');
      assert(numel(device) == 1,'Can only bind 1 device at a time.');
      assert(ismember(wheelIdx,1:obj.WheelCount),'Wheel index does not exist.');
      
      import admin.utils.filterWheelEvent;
      
      % make sure we are using our custom device
      if ~isa(device,'admin.core.devices.Device')
        error( ...
          'FILTERWHEELDEVICE:BINDPAIREDDEVICE:INVALIDDEVICE', ...
          'Bound device must be of type, "admin.core.devices.Device".' ...
          );
      end
      
      boundIdx = obj.hasBoundDevice();
      if boundIdx(wheelIdx)
        existingDevice = obj.getBoundDeviceAtIndex(wheelIdx);
        
        if isequal(device,existingDevice)
          % already bound, simply return
          return
        end
        % otherwise issue a warning and then remove the listeners for the device
        % being dropped
        warning( ...
          'FILTERWHEELDEVICE:BINDPAIREDDEVICE:DEVICEALREADYEXISTS', ...
          'Existing device will be lost by binding a new device.' ...
          );
        obj.removeBoundDeviceAtIndex(wheelIdx);
      end
      
      % set the device property and let the event listener handle parsing
      pdMap = obj.pairedDevice_(wheelIdx);
      pdMap(obj.BOUND_DEVICE_NAME_KEY) = device;
      pdMap(obj.BOUND_DEVICE_CONFIG_KEY) = configSettingName; %#ok<NASGU>
      
      pause(0.1);
      
      notify(obj, ...
        'onBindPairedDevice', ...
        filterWheelEvent(wheelIdx) ...
        );
    end
    
    
    function removeBoundDeviceAtIndex(obj,wheelIndex)
      % REMOVEBOUNDDEVICEATINDEX Remove bound device from specified wheel
      if (wheelIndex > obj.WheelCount) || (wheelIndex <= 0)
        error("Invalid wheel index.");
      end
      
      hasBound = obj.hasBoundDevice();
      if ~hasBound(wheelIndex)
        warning('No device bound at index %d.',wheelIndex);
        return
      end
      
      % handle to containers.Map for paired device
      deviceMap = obj.pairedDevice_(wheelIndex);
      
      % Remove bound listeners
      device = deviceMap(obj.BOUND_DEVICE_NAME_KEY);
      name = device.name;
      nLisn = numel(obj.listeners.pairedListeners);
      dropIdx = false(nLisn,1);
      
      for L = 1:numel(obj.listeners)
        lName = obj.listeners.pairedListeners{L}.Source.name;
        if strcmp(name,lName)
          dropIdx(L) = true;
          delete(obj.listeners.pairedListeners{L});
        end
      end
      % drop the deleted indices
      obj.listeners.pairedListeners(dropIdx) = [];
      
      % remove bound device resource
      device.removeResource(sprintf('%s_%d',obj.BOUND_RESOURCE_KEY,wheelIndex));
      
      % update the deviceMap object
      % since maps are handle class objects, we don't need to reassign the
      % changed map back to the pairedDevice_ map.
      deviceMap.remove({obj.BOUND_DEVICE_CONFIG_KEY,obj.BOUND_DEVICE_NAME_KEY});
    end
    
    %% Access
    
    function tf = get.isReady(obj)
      try
        status = obj.getConfigurationSetting('Status');
      catch x
        error( ...
          'FILTERWHEELDEVICE:COULDNOTGETSTATUS', ...
          'Could not find the status for this filter device for reason: "%s"', ...
          x.message ...
          );
      end
      tf = strcmp(status,'READY') && obj.open_;
    end
    
    
    function tf = get.hasBoundDevice(obj)
      % HASBOUNDDEVICE Returns logical (WheelCount) vector if device is bound
      %  Once initialized, obj.pairedDevice_ contains a containers.Map with
      %  double type keys (1:WheelCount). Each value contains a containers.Map
      %  with 'char' keytypes. We expect that a bound device has keys,
      %  obj.BOUND_DEVICE_NAME_KEY and obj.BOUND_DEVICE_CONFIG_KEY.
      
      tf = false(1,obj.WheelCount);
      
      for d = 1:obj.WheelCount
        % check if device exists
        boundMap = obj.pairedDevice_(d);
        tf(d) = logical(boundMap.Count);
      end
    end
    
       
    function device = getBoundDeviceAtIndex(obj,wheelIndex)
      % GETBOUNDDEVICEATINDEX Returns device bound at specified wheel index
      
      hasBound = obj.hasBoundDevice();
      if ~hasBound(wheelIndex)
        error('No device bound at index %d.',wheelIndex);
      end
      map = obj.pairedDevice_(wheelIndex);
      device = map(obj.BOUND_DEVICE_NAME_KEY);
    end
    
    
    function hLsn = getBoundDeviceListenersAtIndex(obj,wheelIndex)
      if (wheelIndex > obj.WheelCount) || (wheelIndex <= 0)
        error("Invalid wheel index.");
      end
      
      hasBound = obj.hasBoundDevice();
      if ~hasBound(wheelIndex)
        warning('No device bound at index %d.',wheelIndex);
        return
      end
      
      % handle to containers.Map for paired device
      deviceMap = obj.pairedDevice_(wheelIndex);
      
      % Remove bound listeners
      device = deviceMap(obj.BOUND_DEVICE_NAME_KEY);
      name = device.name;
      nLisn = numel(obj.listeners.pairedListeners);
      hLsn = cell(1,nLisn);
      
      dropIdx = true(nLisn,1);
      
      for L = 1:numel(obj.listeners)
        lsn = obj.listeners.pairedListeners{L};
        lsrc = lsn.Source;
        if iscell(lsrc), lsrc = lsrc{1}; end
        lName = lsrc.name;
        if strcmp(name,lName)
          dropIdx(L) = false;
          hLsn{L} = obj.listeners.pairedListeners{L};
        end
      end
      % drop the empty
      hLsn(dropIdx) = [];
    end
    
    
    function names = getBoundDeviceNames(obj)
      names = strings(1,obj.WheelCount);
      for d = 1:obj.WheelCount
        pdMap = obj.pairedDevice_(d);
        if pdMap.isKey(obj.BOUND_DEVICE_NAME_KEY)
          device = pdMap(obj.BOUND_DEVICE_NAME_KEY);
          names{d} = device.name;
        end
      end
    end
    
    
    function idx = getWheelIndexFromBoundDeviceName(obj,name)
      
      boundDevices = obj.getBoundDeviceNames(); %returns string object
      
      % validate and convert to string object
      [tf,name] = admin.utils.ValidStrings(name,boundDevices);
      if ~tf
        error('No device matches the name, "%s".',name);
      end
      idx = find(boundDevices == name,1,'first');
    end
        
    
    function idx = getWheelIndexFromLabel(obj,label)
      % GETWHEELINDEX Returns the index of the wheel queried by its label.
      if ~obj.isReady, return; end
      if ~obj.filterMap.Count, return; end
      for i = 1:obj.filterMap.Count
        pMap = obj.filterMap(string(i));
        id = pMap("ID");
        if strcmpi(label, id)
          idx = double(i);
          break
        end
      end
    end
    
    
    function idx = getPositionIndexFromLabel(obj,label)
      % GETWHEELINDEX Returns the index of the Label queried by its ID.
      if ~obj.isReady, return; end
      if ~obj.filterMap.Count, return; end
      wheel = obj.current_('wheel');
      pMap = obj.filterMap(string(wheel));
      for p = 1:(pMap.Count-1)
        mapLab = pMap(string(p));
        if strcmpi(mapLab,string(label))
          idx = double(p);
          break
        end
      end
    end
    
    
    function [tf,name] = hasResource(obj,expression)
      resourceNames = obj.getResourceNames();
      [tf,name] = admin.utils.ValidStrings(expression,resourceNames,'-any');
    end
    
    
    function setResource(obj,name,value)
      [tf,name] = obj.hasResource(name);
      name = char(name);
      if ~tf
        % name doesn't exist already, lets create it the usual way
        obj.addResource(name, value);
        return
      end
      % name exists, we need to remove it, then add it back with the new value
      successfulRemove = obj.removeResource(name);
      if ~successfulRemove
        error( ...
          'DEVICE:SETRESOURCE:UPDATEFAILED', ...
          'Could not update resources, "%s".', ...
          name ...
          );
      end
      obj.addResource(name,value);
      
    end
    
  end
  
  methods (Abstract)
    
    update(obj,position,wheel)
    
  end
  
  methods (Access = protected)
    
    function connect(obj,port,varargin)
      p = inputParser();
      p.KeepUnmatched = true;
      
      p.addRequired('Port', @ischar);
      p.addParameter('BaudRate', 115200, @(x)~mod(x,10));
      p.addParameter( ...
        'ByteOrder', 'littleEndian', ...
        @(x)ismember(x,{'littleEndian','bigEndian'}) ...
        );
      p.addParameter('DataBits', 8, @(x)any(x == (5:8)));
      p.addParameter( ...
        'Parity', 'none', ...
        @(x) any(string(x) == ["none","odd","even","mark","space"]) ...
        );
      p.addParameter('StopBits', 1, @(x)any(x == [1,1.5,2]));
      p.addParameter('Terminator', 'CR', @ischar);
      p.addParameter('Timeout', 1, @isnumeric);
      p.parse(port,varargin{:});
      
      % get parameters for serial()
      portName = p.Results.Port;
      params = rmfield(p.Results,'Port');
      if ~isempty(p.Unmatched)
        uFields = fieldnames(p.Unmatched);
        for f = 1:numel(uFields)
          fn = uFields{f};
          params.(fn) = p.Unmatched.(fn);
        end
      end
      
      
      % handle special case for 'dummy'
      if strcmpi(portName,'dummy')
        % controller for dummy wheel is a containers.map(). 
        obj.controller = getpref( ...
          'symphonyui', ...
          sprintf('wheel_controller_%s',matlab.lang.makeValidName(obj.name)), ...
          containers.Map('keytype','char','valuetype','any') ...
          );
        obj.setConfigurationSetting('Status', 'READY');
        obj.open_ = true;
        return; 
      end
        
      % check if the serial port is available
      sInfo = seriallist;
      if ~ismember(portName,sInfo)
        error( ...
          'Invalid serial port name, expected one of [%s]', ...
          strjoin(sInfo',', ') ...
          );
      end
      
      % create the serial object
      try
        obj.controller = serial(portName,params); %#ok<SERIAL>
        fopen(obj.controller);
        obj.flush();
        obj.setConfigurationSetting('Status', 'READY');
      catch er
        delete(obj.controller);
        obj.setConfigurationSetting('Status', 'FAILED');
        rethrow(er);
      end
      obj.open_ = true;
    end
    
    
    function flush(obj)
      if ~obj.isReady, return; end
      i = 0;
      while obj.controller.BytesAvailable
        i = i+1;
        if i > obj.MAX_ITER
          fprintf(2,"Trouble flushing buffers.\n");
          break;
        end
        flushinput(obj.controller);
        flushoutput(obj.controller);
      end
    end
    
    
    function storeConfigurations(obj)
      c = obj.current_;
      
      wheelIdx = c("wheel");
      id = obj.Labels{c("position")};
      
      % turn off listener for setting configurations when setting from
      % internally
      obj.listeners.SetConfigurationSetting.Enabled = false;
      pause(0.005);
      
      obj.setConfigurationSetting('Position',char(obj.Position));
      obj.setConfigurationSetting('ID',id);
      obj.setConfigurationSetting('Current', char(obj.Current));
      if obj.verbose
        fprintf( ...
          'Position %d ("%s") stored for %s. (%s)\n', ...
          c("position"), ...
          id, ...
          sprintf('%s > %s', obj.name, obj.WheelId), ...
          datestr(clock,'HH:MM:SS.FFF') ...
          );
      end
      
      % turn the listener back on
      obj.listeners.SetConfigurationSetting.Enabled = true;
      
      % if bound device is set turn off listener and update the configuration
      % TODO:
      %   Currently, (06/2020) if the configuration is changed external to
      %   the filterwheel method, i.e. device configuration in symphony or
      %   through a module, this procedure is redundant. It's ok because we can
      %   disable the filter wheel listeners for setConfigureationSetting on the
      %   device, but it would be better to have a mechanism which doesn't
      %   require that.
      
      hasBound = obj.hasBoundDevice();
      if ~hasBound(wheelIdx), return; end
      
      % disable listeners so we don't get recursion
      boundLsn = obj.getBoundDeviceListenersAtIndex(wheelIdx);
      for l = 1:numel(boundLsn)
        boundLsn{l}.Enabled = false;
      end
      pdMap = obj.pairedDevice_(wheelIdx);
      device = pdMap(obj.BOUND_DEVICE_NAME_KEY);
      configName = pdMap(obj.BOUND_DEVICE_CONFIG_KEY);
      
      device.setConfigurationSetting(configName,char(id));
      
      % enable the listeners
      for l = 1:numel(boundLsn)
        boundLsn{l}.Enabled = true;
      end
    end
    
    
    function updateBoundConfigurations(obj)
      wheelIdx = obj.current_("wheel");
      hasBound = obj.hasBoundDevice();
      if ~hasBound(wheelIdx), return; end
      
      % disable listeners so we don't get recursion
      boundLsn = obj.getBoundDeviceListenersAtIndex(wheelIdx);
      for l = 1:numel(boundLsn)
        boundLsn{l}.Enabled = false;
      end
      
      % get this bound device
      pdMap = obj.pairedDevice_(wheelIdx);
      device = pdMap(obj.BOUND_DEVICE_NAME_KEY);
      name = pdMap(obj.BOUND_DEVICE_CONFIG_KEY);
      
      % get the new position labels for this device
      posMap = obj.filterMap(string(wheelIdx));
      labs = strings(1,posMap.Count-1);
      for L = 1:(posMap.Count-1)
        labs(L) = posMap(string(L));
      end
      
      % get the active position for selected wheel
      posIdx = string(obj.cache(string(w)));
      activeLabel = posMap(posIdx);
      
      % use our custom method to set config, it will automatically update the
      % configuration to this new type
      device.addConfiguration(name, activeLabel, labs, false, false);
      
      % enable the listeners
      for l = 1:numel(boundLsn)
        boundLsn{l}.Enabled = true;
      end
    end
    
    
    function updateLabelResource(obj)
      % updateLabelResource Sets/updates the wheel and position labels into the
      % resources of the filter wheel
      % This mehtod requires the abstract properties to be defined
      for w = 1:obj.WheelCount
        map = obj.filterMap(string(w));
        id = map("ID");
        pcount = map.Count-1;
        labs = strings(1,pcount);
        for p = string(1:pcount)
          labs(double(p)) = map(p);
        end
        obj.setResource(sprintf('Wheel_%d_ID',w), id);
        obj.setResource(sprintf('Wheel_%d_Labels',w), labs);
      end
    end
    
  end
  
  methods (Abstract = true, Access = protected)
    
    move(obj)
    
    str = query(obj,qry)
    
  end
  
  methods (Access = protected)
    %% Callbacks
    
    function didModifyCurrent(obj,~,~)
      c = obj.current_;
      wheel = string(c("wheel"));
      obj.cache(wheel) = c("position");
      obj.storeConfigurations();
    end
    
    
    function didSetConfigurationSetting(obj,~,~)
      % DIDSETCONFIGURATIONSETTING Catches external events attempting to
      % modify the object's configurations.
      %
      % For now, we will simply set the correct configuration from the
      % object and return without incident.
      vb = obj.verbose;
      obj.verbose = false;
      obj.storeConfigurations();
      
      % check if status configuration was changed
      status = obj.getConfigurationSetting('Status');
      if ~strcmp(status,'READY') && obj.open_
        % turn off listener for setting configurations
        obj.listeners.SetConfigurationSetting.Enabled = false;
        obj.setConfigurationSetting('Status', 'READY');
        obj.listeners.SetConfigurationSetting.Enabled = true;
      end
      % turn reporting back on
      obj.verbose = vb;
    end
    
    
    function onDeviceSetConfiguration(obj,~,evt)
      % ONDEVICESETCONFIGURATION Catch device set configuration
      % Symphony sends CoreEventData object with the descriptor, 
      % symphonyui.core.PropertyDescriptor(), in evt.data.
      % The evt.Source will be the handle to the device
      
      descriptor = evt.data;
      device = evt.Source;
      configName = descriptor.name;
      dName = device.name;
      
      % determine wheel index and get the paired device map
      wheelIdx = obj.getWheelIndexFromBoundDeviceName(dName);
      pdMap = obj.pairedDevice_(wheelIdx);
      
      % determine if the event is associated with our filterwheel
      if ~strcmp(configName,pdMap(obj.BOUND_DEVICE_CONFIG_KEY))
        % we are not handling this event, exit
        return
      end
      
      % if we reach here, we need to handle the event.
      % Symphony will only allow the device to modify the config within the
      % domain we previously set. At binding the paired device, we set the
      % domain for the config to the position labels. We need to determine which
      % label corresponds to which position index, then we need to update the
      % wheel.
      
      wheelMap = obj.filterMap(string(wheelIdx));
      keys = wheelMap.keys();
      posIdx = [];
      for k = 1:double(wheelMap.Count)
        if strcmpi(descriptor.value,wheelMap(keys{k}))
          posIdx = k;
          break;
        end
      end
      
      obj.update(posIdx,wheelIdx);
      notify( ...
        obj, ...
        'onExternalTriggeredMove', ...
        admin.utils.filterWheelEvent( ...
          wheelIdx, ...
          'WheelName', wheelMap('ID'), ...
          'NewPosition',posIdx ...
          ) ...
        );
    end
    
    
    function didBindPairedDevice(obj,~,evt)
      % DIDBINDPAIREDDEVICE Updates the configuration setup
      % Expects event data to be admin.utils.filterWheelEvent
      
      % wheel index (double)
      w = evt.WheelIndex;
      
      % get the paired device information
      % For now, binding a device to multiple wheels will result in multiple
      % references being stored in the private property pairedDevice_. Since
      % they are references, this might be lower overhead than writing checks
      pdMap = obj.pairedDevice_(w);
      name = pdMap(obj.BOUND_DEVICE_CONFIG_KEY);
      device = pdMap(obj.BOUND_DEVICE_NAME_KEY);
      
      % get the wheel info at supplied index
      posMap = obj.filterMap(string(w));
      wheelId = posMap('ID');
      
      % use the labels as the 'domain' or 'options' for the config setting on
      % the newly bound device
      labs = strings(1,posMap.Count-1);
      for L = 1:(posMap.Count-1)
        labs(L) = posMap(string(L));
      end
      
      % get the active position for selected wheel
      posIdx = string(obj.cache(string(w)));
      activeLabel = posMap(posIdx);
      
      % use our custom method to set config, it will automatically update the
      % configuration to this new type
      device.addConfiguration( ...
        name, ...
        char(activeLabel), ...
        labs, ...
        true, ...
        false, ...
        'isRemovable', true, ...
        'isReadOnly', false, ...
        'description', sprintf('Configuration setting given from %s.',obj.name) ...
        );
      
      % add filterwheel id to the devices resource
      device.setResource( ...
        sprintf('%s_%d',obj.BOUND_RESOURCE_KEY,w),...
        sprintf('%s>%s',obj.name,wheelId) ...
        );
      
      % bind listeners to the device so that we can update this filter wheep
      obj.listeners.pairedListeners{end+1} = addlistener( ...
        device, ...
        'SetConfigurationSetting', ...
        @obj.onDeviceSetConfiguration ...
        );
    end
    
  end
  
end