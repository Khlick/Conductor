classdef Axopatch200B < symphonyui.builtin.devices.AxopatchDevice
  %AXOPATCHAMPLIFIER Wrapper for symphonyui.builtin...AxopatchDevice.
  
  properties
    deviceType = 'Amplifier';
  end
  
  properties (Dependent)
    hasOutputStream
    hasInputStream
  end
  
  methods
    
    function obj = Axopatch200B(name,varargin)
      ip = inputParser();
      ip.addRequired('daq');
      ip.addOptional('outputPort','ao0',@(x)any(regexp(x,'^ao\d')));
      ip.addOptional('scaledOutput','ai0',@(x)any(regexp(x,'^ai\d')));
      ip.addOptional('gainTelegraph','ai1',@(x)any(regexp(x,'^ai\d')));
      ip.addOptional('modeTelegraph','ai2',@(x)any(regexp(x,'^ai\d')));
      
      ip.parse(varargin{:});
      
      % call the superclass constructor
      obj = obj@symphonyui.builtin.devices.AxopatchDevice(name);
      
      % handle to the daq
      daq = ip.Results.daq;
      
      % bind the output port, typically 'ao0'
      obj.bindStream(...
        daq.getStream( ...
          ip.Results.outputPort ...
          ) ...
        );
      % bind the input port for recording from amp scaled out, typically 'ai0'
      obj.bindStream( ...
        daq.getStream( ...
          ip.Results.scaledOutput ...
          ), ...
        obj.SCALED_OUTPUT_STREAM_NAME ...
        );
      % bind the gain telegraph, typically 'ai1'
      obj.bindStream( ...
        daq.getStream( ...
          ip.Results.gainTelegraph ...
          ), ...
        obj.GAIN_TELEGRAPH_STREAM_NAME ...
        );
      % bind the mode telegraph, typically 'ai2'
      obj.bindStream( ...
        daq.getStream( ...
          ip.Results.modeTelegraph ...
          ), ...
        obj.MODE_TELEGRAPH_STREAM_NAME ...
        );
    end
    
    function tf = hasResource(obj,expression)
      resourceNames = obj.getResourceNames();
      if isempty(resourceNames)
        tf = false;
        return
      end
      tf = admin.utils.ValidStrings(expression,resourceNames,'-any');
    end
    
    function setResource(obj,name,value)
      
      existing = obj.getResourceNames();
      [tf,name] = admin.utils.ValidStrings(name,existing);
      if ~tf
        % name doesn't exist already, lets create it the usual way
        obj.addResource(char(name), value);
        return
      end
      % name exists, we need to remove it, then add it back with the new value
      successfulRemove = obj.removeResource(char(name));
      if ~successfulRemove
        error( ...
          'DEVICE:SETRESOURCE:UPDATEFAILED', ...
          'Could not update resources, "%s".', ...
          name ...
          );
      end
      obj.addResource(char(name),value);
      
    end
    
    function tf = get.hasInputStream(obj) %#ok<MANU>
      tf = true;
    end
    
    function tf = get.hasOutputStream(obj) %#ok<MANU>
      tf = true;
    end
    
  end
  
end

