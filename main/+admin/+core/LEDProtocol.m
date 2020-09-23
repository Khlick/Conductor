classdef (Abstract) LEDProtocol < admin.core.Protocol & dynamicprops
  %LEDPROTOCOL A middleman to add LED specific methods/actions for admin.core.Protocol
  % A Protocol is an acquisition routine that defines a sequence of experimental trials, called epochs. Each epoch may
  % present a set of stimuli and record a set of responses from devices in the current rig. A protocol may also define
  % online analysis to perform, typically through the use of FigureHandlers.
  %
  % To write a new protocol:
  %   1. Subclass Protocol
  %   2. Add properties to your subclass to define user-configurable values
  %   3. Override methods to define protocol behavior
  %
  % Protocol Methods:
  %   getPreview          - Override to return a ProtocolPreview implementation that manages a preview for this protocol
  %
  %   didSetRig           - Override to perform actions after this protocol's rig is set
  %   didSetPersistor     - Override to perform actions after this protocol's persistor is set
  %
  %   prepareRun          - Override to perform actions before the start of the first epoch
  %   prepareEpoch        - Override to perform actions before each epoch is added to the epoch queue
  %   prepareInterval     - Override to perform actions before each interval is added to the epoch queue
  %   completeEpoch       - Override to perform actions after each epoch is completed
  %   completeInterval    - Override to perform actions after each interval is completed
  %   completeRun         - Override to perform actions after the last epoch has completed
  %
  %   shouldContinuePreloadingEpochs      - Override to return true/false to indicate if this protocol should continue preloading epochs
  %   shouldWaitToContinuePreparingEpochs - Override to return true/false to indicate if this protocol should wait to continue preparing epochs
  %   shouldContinuePreparingEpochs       - Override to return true/false to indicate if this protocol should continue preparing epochs
  %   shouldContinueRun                   - Override to return true/false to indicate if this protocol should continue run
  %
  %   isValid             - Override to return true/false to indicate if this protocol is valid and should be able to run
  
  properties
    % IGNOREBACKGROUNDINPUT - Set to true to ignore values set in led#Background
    %and use the background value for led devices. Helpful when running
    %protocols on prolonged mean background.
    ignoreBackgroundInput = true
    % PERSISTLEDBACKGROUND - Default (true) behaviour is to leave background
    %values set by the protocol (or those set before the protocol). A value of
    %false will cause background levels for each led to be returned to 0.
    persistLedBackground = true
  end
  
  properties (Hidden)
    nLeds
  end
  
  methods
    
    function obj = LEDProtocol()
      obj = obj@admin.core.Protocol();
    end
    
    function didSetRig(obj)
      import symphonyui.core.PropertyType;
      
      % call the super to complete the construction
      didSetRig@admin.core.Protocol(obj);
      
      %detect and add LEDs
      ledDevs = obj.getLedDevices();
      ledNames = cellfun(@(v)v.name,ledDevs,'unif',0);
      nLEDs = numel(ledDevs);
      obj.nLeds = nLEDs;
      
      if nLEDs > 0
        % add a property set for each LED
        canMonitor = false(nLEDs,1);
        for d = 1:nLEDs
          
          % name the property
          lprop = sprintf('led%d',d);
          ltype = [lprop,'Type'];
          % add dynamic properties for this led
          Ptype = obj.addprop(ltype);
          Ptype.Hidden = true;
          
          ledProp = obj.addprop(lprop);
          ledProp.Description = sprintf( ...
            'Led%d available for stimulation or background light. ', ...
            d ...
            );
          ledPropBg = obj.addprop([lprop,'Background']);
          ledPropBg.Description = [ ...
            sprintf('Background (V) for Led%d.',d), ...
            ' This value is ignored if ignoreBackgroundInput is true.' ...
            ];
          % set the values
          [obj.(lprop),obj.(ltype)] = obj.createLedNamesProperty();
          % set led1 ... ledn to unique names of leds.
          obj.(lprop) = ledNames{d};
          % background values to 0 by default
          obj.([lprop,'Background']) = 0;
          % check for input streams
          canMonitor(d) = ledDevs{d}.hasInputStream();
        end
      else
        warning( ...
          'LEDPROTOCOL:NOLEDSFOUND', ...
          'No LEDs were located, consider using "%s" instead.', ...
          'admin.core.Protocol' ...
          );
      end
      % add property for monitoring stimulus led
      if any(canMonitor)
        monProp = obj.addprop('monitorStimulus');
        monProp.Description = 'Toggle recording from led1.';
        obj.monitorStimulus = false;
      end
      if sum(canMonitor) > 1
        monBg = obj.addprop('monitorBackground');
        monBg.Description = 'Toggle recording from led2.';
        obj.monitorBackground = false;
      end
      
      % if IR device available, add an IR control property
      [hasIR,~] = obj.rigHasDeviceName('IR');
      if hasIR
        irtogprop = obj.addprop('toggleIr');
        irtogprop.Description = [ ...
          'Allow protocol to toggle IR source off during recording. ', ...
          'If true, the IR source will turn on at the end of the protocol.' ...
          ];
        obj.toggleIr = true;
      end
    end
    
    function setProperty(obj, name, value)
      if ~contains(name,'_init') && ~isempty(regexp(name,'^led(?=[0-9]+$)','once'))
        % modify leds after they've been initialized
        reVal = obj.getProperty(name);% value before this new assignment
        if strcmp(reVal,value), return; end
        ledProps = properties(obj);
        ledProps = ledProps( ...
          cellfun( ...
          @(v)~isempty(regexp(v,'^led(?=[0-9]+$)','once')), ...
          ledProps, ...
          'uniformoutput', true ...
          ) ...
          );
        % get the other led values and whichever has value gets reVal
        ledProps = ledProps(~ismember(ledProps,name));
        ledVals = cellfun(@(v)obj.getProperty(v),ledProps,'unif',0);
        swapInd = ismember(ledVals, value);
        % set the other led property and then let this prop get set normal
        setProperty@admin.core.Protocol(obj, ledProps{swapInd}, reVal);
      end
      switch name
        case 'monitorStimulus'
          if value
            % if setting to true, make sure we have an available stream to
            % record from.
            device = obj.rig.getDevice(obj.led1);
            if ~device.hasInputStream()
              value = false;
              fprintf(2,'No input streams for %s (%s).\n',device.name,class(obj));
            end
          end
      end
        
      % remove '_init' from name if it there. This won't affect property
      % names that don't have '_init' in them.
      name = erase(name,'_init');
      setProperty@admin.core.Protocol(obj, name, value);
    end
    
    function prepareRun(obj)
      % PREPARERUN
      import symphonyui.core.Measurement;
      prepareRun@admin.core.Protocol(obj);
      % set LED backgrounds to supplied value if ignoreBackroundInput== false
      if ~obj.ignoreBackgroundInput
        p = sort(properties(obj));
        pLED = [ ...
          p(cellfun(@(x)~isempty(regexpi(x,'^led\d+(?!Background$)', 'once')),p,'unif',1)),...
          p(cellfun(@(x)~isempty(regexpi(x,'^led\d+Background$', 'once')),p,'unif',1)) ...
          ];
        if ~isempty(p)
          for d = 1:size(pLED,1)
            dName = pLED{d,1};
            device = obj.rig.getDevice(obj.(dName));
            value = obj.(pLED{d,2});
            try
              if ~device.canAcceptVoltage(value)
                error( ...
                  'PROTOCOL:PREPARERUN:MAXEXCEEDED', ...
                  '%0.3fV exceeds device range.', ...
                  value ...
                  );
              end
            catch x
              if strcmp(x.identifier,'PROTOCOL:PREPARERUN:MAXEXCEEDED')
                rethrow(x);
              end
              maxV = device.getResource('maximum');
              if ~(value <= maxV && value >= 0)
                error( ...
                  'PROTOCOL:PREPARERUN:MAXEXCEEDED', ...
                  '%0.3fV exceeds device range.', ...
                  value ...
                  );
              end
            end
            device.background = Measurement(value,device.background.displayUnits);
            device.applyBackground();
          end
        end
      end
      
      % if IR is controlled through ttl, then turn it off for recording
      [hasIR,IrName] = obj.rigHasDeviceName('IR');
      if hasIR && obj.toggleIr
        IRdev = obj.rig.getDevice(IrName{1});
        IRdev.background = Measurement(0,IRdev.background.displayUnits);
        IRdev.applyBackground();
      end
    end
    
    function completeRun(obj)
      import symphonyui.core.Measurement;
      
      completeRun@admin.core.Protocol(obj);
      % set LED backgrounds to 0 if persistLedBackgrounds == false
      if ~obj.persistLedBackground
        p = properties(obj);
        % set LED backgrounds to 0 if present.
        p = p(cellfun(@(x)~isempty(regexpi(x,'^led.*$', 'once')),p,'unif',1));
        if ~isempty(p)
          devices = obj.getLedDevices();
          bgMeasurement = Measurement(0,devices{1}.background.displayUnits);
          for d = 1:numel(devices)
            device = devices{d};
            device.background = bgMeasurement;
            device.applyBackground();
          end
        end
      end
      % if IR is controlled through ttl, then turn it on when done recording
      [hasIR,IrName] = obj.rigHasDeviceName('IR');
      if hasIR && obj.toggleIr
        IRdev = obj.rig.getDevice(IrName{1});
        IRdev.background = Measurement(1,IRdev.background.displayUnits);
        IRdev.applyBackground();
      end
    end
    
    function prepareEpoch(obj,epoch)
      prepareEpoch@admin.core.Protocol(obj,epoch);
      if isprop(obj,'monitorStimulus') && obj.monitorStimulus
        epoch.addResponse(obj.rig.getDevice(obj.led1));
      end
      if isprop(obj,'monitorBackground') && obj.monitorBackground
        epoch.addResponse(obj.rig.getDevice(obj.led2));
      end
    end
    
    function completeEpoch(obj, epoch)
      completeEpoch@admin.core.Protocol(obj,epoch);
    end
    
    function didSetPersistor(obj)
      didSetPersistor@admin.core.Protocol(obj);
      % Override to perform actions after this protocol's persistor is set, e.g. assign property values based on
      % experiment entities. Note that persistor may be assigned as empty is there is no persistor.
    end
    
    function p = getPreview(obj, panel)
      p = getPreview@admin.core.Protocol(obj,panel);
      % Override to return a ProtocolPreview implementation that manages a preview for this protocol, e.g.
      % StimuliPreview
    end
    
    function prepareInterval(obj, interval)
      prepareInterval@admin.core.Protocol(obj,interval);
      % Override to perform actions before each interval is added to the epoch queue. An interval is an epoch that
      % is not saved.
    end
    
    function controllerDidStartHardware(obj)
      controllerDidStartHardware@admin.core.Protocol(obj);
      % Override to perform actions after the DAQ controller actually starts the hardware, e.g. play a
      % synchronized visual stimulus from a disparate system
    end
    
    function tf = shouldContinuePreloadingEpochs(obj)
      tf = shouldContinuePreloadingEpochs@admin.core.Protocol(obj);
      % Override to return true/false to indicate if this protocol should continue preloading epochs
    end
    
    function tf = shouldWaitToContinuePreparingEpochs(obj)
      tf = shouldWaitToContinuePreparingEpochs@admin.core.Protocol(obj);
      % Override to return true/false to indicate if this protocol should wait to continue preparing epochs
    end
    
    function tf = shouldContinuePreparingEpochs(obj)
      tf = shouldContinuePreparingEpochs@admin.core.Protocol(obj);
      % Override to return true/false to indicate if this protocol should continue preparing epochs
    end
    
    function tf = shouldContinueRun(obj)
      tf = shouldContinueRun@admin.core.Protocol(obj);
      % Override to return true/false to indicate if this protocol should continue run
    end
    
    function completeInterval(obj, interval)
      completeInterval@admin.core.Protocol(obj,interval);
      % Override to perform actions after each interval is completed
    end
    
  end
  
  methods
    % Uncommon overrides
    
    function propObj = getPropertyDescriptor(handle,property)
      propObj = getPropertyDescriptor@admin.core.Protocol(handle,property);
    end
    
  end
  
  %% Helper methods specific for LED devices
  methods (Access = protected)
    
    function devices = getLedDevices(obj)
      [~,devNames] = obj.rigHasDeviceType('LED');
      n = numel(devNames);
      devices = cell(1,n);
      for d = 1:n
        devices{d} = obj.rig.getDevice(devNames{d});
      end
    end
    
    
    function [tf,msg] = validateAmplitudes(obj,ledName,voltages)
      % VALIDATEAMPLITUDES Validate that an led can accept any of the supplied voltages.
      led = obj.rig.getDevice(ledName);
      n = numel(voltages);
      tf = true(n,1);
      msg = cell(n,1);
      for a = 1:n
        ap = voltages(a);
        if isa(led,'admin.devices.LedDevice')
          tf(a) = led.canAcceptVoltage(ap);
        else
          try %#ok<TRYNC>
            maxV = led.getResource('maximum');
            tf(a) = (0 <= ap) && (ap <= maxV);
          end
        end
        if ~tf(a)
          msg{a} = sprintf('Amplitdues exceed allowed maximum on "%s"',led.name);
        end
      end
      
      msg(cellfun(@isempty,msg,'UniformOutput',true)) = [];
      if ~numel(msg)
        msg = '';
      else
        msg = strjoin(msg,'; ');
      end
      tf = ~any(~tf);
    end
    
    function [value, type] = createLedNamesProperty(obj)
      % A convenience method for creating a property value/type combination that allows a device name to be
      % selected from a list of available devices in the rig with names matching the given expression
      
      [~,names] = obj.rigHasDeviceType('LED');
      if isempty(names)
        names = {'(None)'};
      end
      value = names{1};
      type = symphonyui.core.PropertyType('char', 'row', names);
    end
  end
  
end

