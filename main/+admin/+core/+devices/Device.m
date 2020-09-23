classdef Device < symphonyui.core.Device
  % Represents a generic device, based on UnitConvertingDevice
  
  properties
    deviceType
    measurementConversionTarget
  end
  
  properties (Dependent, Hidden)
    hasOutputStream
    hasInputStream
  end
  
  methods
    
    function obj = Device(name,conversionTarget,varargin)
      %Device Generic device type with a few convenience methods and properties
      import admin.core.devices.Device;
      import Symphony.Core.Measurement;
      
      ip = inputParser();
      ip.addRequired('conversionTarget', ...
        @(x) ischar(x) || isa(x,'Symphony.Core.Measurement') ...
        );
      ip.addRequired('daq', @(x)isa(x,'symphonyui.core.DaqController'));
      ip.addParameter('inputStream','',@(x)isempty(x) || any(regexp(x,'^ai\d')));
      ip.addParameter('outputStream','',@(x)isempty(x) || any(regexp(x,'^ao\d')));
      ip.addParameter('digitalStream','',@(x)isempty(x) || any(regexp(x,'^d[io]port\d')));
      ip.addParameter('type', 'Unspecified', @ischar);
      ip.addParameter('bitPosition', 15, @(x) isscalar(x) && ((x>=0) && (x<=15)));
      ip.addParameter('inputStreamName','',@ischar);
      ip.addParameter('outputStreamName','',@ischar);
      ip.addParameter('digitalStreamName','',@ischar);
      ip.addParameter('manufacturer', 'Unspecified');
      ip.addParameter('description', '', @ischar);
      ip.parse(conversionTarget,varargin{:});
      
      % make sure we have at least 1 stream
      hasIO = structfun( ...
        @(v)~isempty(v), ...
        admin.utils.fastKeepField( ...
          ip.Results, ...
          {'inputStream','outputStream','digitalStream'} ...
          ), ...
        'UniformOutput', true ...
        );
      if ~any(hasIO)
        error('ADMINCOREDEVICE:STREAMREQUIRED','Valid stream required.');
      end
      
      % Determine the measurement conversion
      if isempty(ip.Results.conversionTarget)
        cMeasure = Meaurement(0,char(Measurement.UNITLESS));
      elseif isa(ip.Results.conversionTarget,'Symphony.Core.Measurement')
        cMeasure = ip.Results.conversionTarget;
      else
        % assuming a character vector
        % convert units prefix, For some reason this causes Symphoy to fail on
        % conversion at recording. So we need to figure out a different way to do
        % this.
        [prefix,unit] = admin.utils.getPrefixFromUnits(conversionTarget);
        % exponent is base ten conversion between from V to target so we need to
        % determine the SI unit, e.g. u is 10^-6;
        exponent = admin.utils.prefixToExponent(prefix);
        cMeasure = Measurement(0,exponent,unit);
      end
      
      % construct the core object
      cobj = Symphony.Core.UnitConvertingExternalDevice( ...
        name, ...
        ip.Results.manufacturer, ...
        cMeasure ...
        );
      obj = obj@symphonyui.core.Device(cobj);
      
      obj.measurementConversionTarget = unit;
      obj.deviceType = ip.Results.type;
      
      % add the description as a resource
      obj.addResource('descrpition', ip.Results.description);
      % add the device type to the resource list
      obj.addResource('deviceType', obj.deviceType);
      % add the device conversion resources
      obj.addResource('conversion', 10^(-exponent));
      obj.addResource('conversion_units', [prefix,unit]);
      
      
      daq = ip.Results.daq;
      if ~isempty(ip.Results.inputStream)
        inputStream = daq.getStream(ip.Results.inputStream);
        iName = ip.Results.inputStreamName;
        if isempty(iName)
          obj.bindStream(inputStream);
        else
          obj.bindStream(inputStream,iName);
        end
      end
      if ~isempty(ip.Results.outputStream)
        outputStream = daq.getStream(ip.Results.outputStream);
        oName = ip.Results.outputStreamName;
        if isempty(oName)
          obj.bindStream(outputStream);
        else
          obj.bindStream(outputStream,oName);
        end
      end
      if ~isempty(ip.Results.digitalStream)
        digitalStream = daq.getStream(ip.Results.digitalStream);
        
        obj.bindStream(digitalStream);
        digitalStream.setBitPosition(obj,ip.Results.bitPosition);
      end
      
    end
    
    
    function t = get.measurementConversionTarget(obj)
      t = char(obj.cobj.MeasurementConversionTarget);
    end
    
    
    function set.measurementConversionTarget(obj, t)
      obj.cobj.MeasurementConversionTarget = t;
    end
    
    
    function addConfiguration(obj, name, value, options, allowMultiple, allowEdit, varargin)
      % ADDCONFIGURATION A wrapper to add configurations to the core object
      if nargin < 6, allowEdit = false; end
      if nargin < 5, allowMultiple = false; end
      if nargin < 4, options = {}; end
      
      import uiextras.jide.PropertyType;
      
      % manually detect strings
      % value
      if isstring(value)
        value = cellstr(value);
      end
      % options
      if isstring(options)
        options = cellstr(options);
      end
      
      % autodiscover property type
      type = PropertyType.AutoDiscoverType(value);
      
      % autodiscover shape
      shape = PropertyType.AutoDiscoverShape(value);
      
      % modify shape if we don't want scalar entry
      if allowMultiple && ~strcmp(shape,'row')
        shape = 'row';
      end
      
      % modify domain if it is a cellstr and we want to be able to edit it
      % autodiscover domain shape
      if allowEdit && iscellstr(options) && ~any(contains(options,'...'))
        options{end+1} = '...';
      end
      
      % construct java type
      propType = PropertyType(type,shape,options);
      
      % check if the configuration exists
      if obj.hasConfigurationSetting(name)
        obj.removeConfigurationSetting(name);
      end
      
      % add the property to the device configuration
      obj.addConfigurationSetting( ...
        name, ...
        value, ...
        'type',symphonyui.core.PropertyType(propType), ...
        varargin{:} ...
        );
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
    
    function tf = get.hasInputStream(obj)
      s = obj.cellArrayFromEnumerable( ...
        obj.cobj.InputStreams, ...
        @symphonyui.core.DaqStream ...
        );
      tf = any(~cellfun(@isempty,s,'UniformOutput',true));
    end
    
    function tf = get.hasOutputStream(obj)
      s = obj.cellArrayFromEnumerable( ...
        obj.cobj.OutputStreams, ...
        @symphonyui.core.DaqStream ...
        );
      tf = any(~cellfun(@isempty,s,'UniformOutput',true));
    end
    
  end
  
end

