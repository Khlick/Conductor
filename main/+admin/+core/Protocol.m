classdef (Abstract) Protocol < symphonyui.core.Protocol & dynamicprops
  %PROTOCOL A gobo to add common methods to symphonyui.core.Protocol
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
  %
  % Properties defined in symphonyui.core.Protocol
  %   numEpochsPrepared       % Number of epochs prepared by this protocol since prepareRun()
  %   numEpochsCompleted      % Number of epochs completed by this protocol since prepareRun()
  %   numIntervalsPrepared    % Number of intervals prepared by this protocol since prepareRun()
  %   numIntervalsCompleted   % Number of intervals completed by this protocol since prepareRun()
  
  %% Base Properties
  properties (Hidden)
    identifier
    displayName
  end
  
  properties
    % amp - The recording/stimulating amplifier.
    amp
    % numberOfAverages - The number of times to repeat the defined protocol.
    numberOfAverages = uint16(3)
    % delayBetweenEpochs - Duration to wait between each epoch in ms. May be a
    % vector, each protocol must handle usage.
    delayBetweenEpochs = 0.0
  end
  properties (Hidden)
    ampType
    numberOfAveragesType = symphonyui.core.PropertyType('uint16', 'scalar', [1 Inf])
    delayBetweenEpochsType = symphonyui.core.PropertyType('denserealdouble','row')
  end
  
  %% Base Methods
  methods
    
    function obj = Protocol()
      obj.figureHandlerManager = admin.core.FigureHandlerManager();
    end
    
    function d = getPropertyDescriptor(obj, name)
      % This method overrides
      % symphonyui.core.Protocol.getPropertyDescriptor(obj,name)
      %  function d = getPropertyDescriptor(obj, name)
      %      d = symphonyui.core.PropertyDescriptor.fromProperty(obj, name);
      %  end
      % This override is needed (at least for now) in order to have dynamic
      % properties added to the class which initialize with empty
      % meta.property().DefiningClass: [0x0 met.class]. Currently, there is
      % no way to set the readonly meta.class for prop.DefiningClass
      %%%
      
      mpo = findprop(obj, name);
      if isempty(mpo)
        error([name ' not found on obj']);
      end
      
      % check if the property is created dynamically (i.e. definingclass is
      % empty). Not sure if matlab will change this in the future, but up to
      % 2020a dynamic properties get defining class set to empty meta.class (see
      % https://www.mathworks.com/help/matlab/ref/meta.dynamicproperty-class.html)
      if ~isempty(mpo.DefiningClass)
        comment = uiextras.jide.helptext([class(obj) '.' mpo.Name]);
        % Removes "inherited from..." text
        if ~strcmpi(mpo.DefiningClass.Name, class(obj)) && numel(comment) >= 2
          comment(end-1:end) = [];
        end
      else
        comment = {mpo.Description};
      end
      
      % If theres a help text available, strip the beginning key off
      if iscell(comment) && ~isempty(comment{1})
        comment{1} = strtrim(regexprep(strtrim(comment{1}), ['^' mpo.Name ' -'], ''));
      end
      % set the comment into a string with new lines.
      comment = strjoin(comment, ' ');
      
      
      % build the description
      d = symphonyui.core.PropertyDescriptor(mpo.Name, obj.(mpo.Name), ...
        'description', comment, ...
        'isReadOnly', ...
        mpo.Constant || ...
        ~strcmp(mpo.SetAccess, 'public') || ...
        mpo.Dependent && isempty(mpo.SetMethod) ...
        );
      
      % if there is a hidden propertyType property, use it to set the
      % property type of the object.
      mto = findprop(obj, [name 'Type']);
      if ~isempty(mto) && mto.Hidden && isa(obj.(mto.Name), 'symphonyui.core.PropertyType')
        d.type = obj.(mto.Name);
      end
      
      % Define Category options
      %0 Id
      Identifiers = { ... %ID
        'identifier', 'displayName', 'id' ...
        };
      % 1 Recording Device Control
      RecordControl = { ... %Amp control
        'amp', 'holdingCommand', 'monitorStimulus', 'monitorBackground', ...
        'keepLedResponse', 'keepTemperatureResponse', 'monitorLed' ...
        };
      % 2 Stim
      StimControl = [ ... %Stim Control
        sprintfc('led%d', 1:9), ...
        sprintfc('led%dAsFamily', 1:9), ...
        sprintfc('led%dPulsesInFamily', 1:9), ...
        sprintfc('led%dAmplitude', 1:9), ...
        sprintfc('led%dAmplitudes', 1:9), ...
        sprintfc('led%dInitialAmplitude', 1:9), ...
        { ...
        'familyIncrement','familyMaxAmplitude','finalPulse', ...
        'finalRampAmplitude','firstLightAmplitude','firstPulse', ...
        'incrementPerPulse','initRampAmplitude', ...
        'led','lightAmplitude','lightAmplitudes', ...
        'oscillationCenter','phaseShift', ...
        'rampMaximum','rampMean','rampMinimum','rampTotalAmplitude', ...
        'stepAmplitudes','stepsAsFamily','stimAmplitudes', 'stimValues', ...
        'chirpAmplitude', 'chirpCenter', 'phaseShift', 'chirpMode', ...
        'frequencyInit', 'frequencyFinal', 'chirpIncreasing', ...
        'noiseMode', 'noiseContrast', 'noiseCenter', 'noiseBandwidth', ...
        'invertStimulus', 'randomizeNoiseFamily', 'resetNoiseRandomization', ...
        'pulseAmplitude', 'chirpQuadMode', 'chirpSymmetry' ...
        } ...
        ];
      % 3 Temporal Controls
      TemporalControl = { ... % Temporal Control
        'delayBetweenEpochs','interpulseInterval','interstepIntervals',     ...
        'led1Durations','preTime','rampDelay','sampleRate','stimDurations', ...
        'stimTime','tailTime','totalEpochTime','led1Delay','led1Duration',  ...
        'led1Tail','led2Delay','led2Duration','led2Tail', 'rampHold',       ...
        'stimulationFrequency', 'stimulationPeriod', 'duration',            ...
        'stimDelay', 'stimFollowDelay' ...
        };
      % 4 Repetition Control
      RepControl = { ...%Repetition Control
        'numberOfAverages','pulsesInFamily','familyFirst','familyAsLinear', ...
        'flashesInFamily', 'generateFamily', 'asFamily', 'numberInFamily'   ...
        };
      % 5 Background Control
      BgControl = [ ...%Background
        sprintfc('led%dBackground', 1:9), ...
        { ...
        'persistLedBackground', 'ignoreBackgroundInput', 'lightBackground', ...
        'holdPotentialOverride', 'overrideCommand', 'toggleIr','monitorBackground' ...
        } ...
        ];
      
      switch name
        case Identifiers
          d.category = '0. Identification';
        case RecordControl
          d.category = '1. Recording Control';
          %%%
        case StimControl
          d.category = '2. Stimulus Control';
          %%%
        case TemporalControl
          d.category = '3. Temporal Controls';
          %%%
        case RepControl
          d.category = '4. Repetition Control';
          %%%
        case BgControl
          d.category = '5. Background Control';
        otherwise % OTHER
          d.category = '6. Other';
          %%%
      end
      
    end
    
    function didSetRig(obj)
      import appbox.humanize;
      import appbox.capitalize;
      
      didSetRig@symphonyui.core.Protocol(obj);
      
      % Override to perform actions after this protocol's rig is set, e.g.
      % assign property values based on rig devices.
      classname = class(obj);
      splits = strsplit(classname,'.');
      obj.identifier = classname;
      obj.displayName = capitalize(humanize(splits{end}));
      
      % bind the amplifiers
      [obj.amp,obj.ampType] = obj.createAmplifiersNamesProperty();
      
      % determine if we have a temperature probe
      [hasTempMon,tempName] = obj.rigHasDeviceType('temperature');
      if hasTempMon
        % add dynamic properties for this led
        Ptype = obj.addprop('tempType');
        Ptype.Hidden = true;
        pTemp = obj.addprop('temp');
        pTemp.Description = 'Temperature monitor device, if present.';
        % set the values
        [obj.temp,obj.tempType] = obj.createDeviceNamesProperty(tempName{1});
        % create a logical value for showing the temperature plot
        showtmp = obj.addprop('showTemp');
        showtmp.Description = [ ...
          'Toggle to show the temperature probe for each epoch.',...
          ' If false, temperature will still be analyzed and the summary will ', ...
          'be added to each epoch for offline analysis.' ...
          ];
        obj.showTemp = false;
      end
      
    end
    
    function setProperty(obj, name, value)
      setProperty@symphonyui.core.Protocol(obj, name, value);
    end
    
    function prepareRun(obj)
      prepareRun@symphonyui.core.Protocol(obj);
      fprintf('%s ran at %s', ...
        class(obj), ...
        datestr(clock,'\nyyyymmdd_HH:MM:SS.FFF\n\n') ...
        );
      if isprop(obj,'showTemp') && obj.showTemp
        obj.showFigure( 'admin.figures.MeanResponse', ...
          obj.rig.getDevice(obj.temp), ...
          'instanceId', 'Temperature_Probe', ...
          'disableToolbar', true, ...
          'disableMenubar', true, ...
          'showEach', true, ...
          'sweepColor', admin.utils.getRainbowShades(1,1) ...
          );
      end
    end
    
    function prepareEpoch(obj,epoch)
      prepareEpoch@symphonyui.core.Protocol(obj,epoch);
      c = clock;
      epoch.addParameter('epochDateString', ...
        datestr(c, 'yyyymmmdd_HH:MM:SS.FFF'));
      for cnst = {'identifier', 'displayName'}
        try
          epoch.addParameter(cnst{1}, obj.(cnst{1}));
        catch
          % Print to console for log
          fprintf('%s has no property %s.\n', ...
            class(obj), cnst{1} ...
            );
        end
      end
      % find temperature monitor
      [tf,~] = obj.rigHasDeviceType('temperature');
      if tf
        epoch.addResponse(obj.rig.getDevice(obj.temp));
      end
    end
    
    function completeEpoch(obj, epoch)
      completeEpoch@symphonyui.core.Protocol(obj,epoch);
      
      %look for temperature
      [hasTempMon,~] = obj.rigHasDeviceType('temperature');
      if hasTempMon
        tempdevice = obj.rig.getDevice(obj.temp);
        if epoch.hasResponse(tempdevice)
          [responseData,units] = epoch.getResponse(tempdevice).getData;
          try
            crtc = tempdevice.getResource('conversion'); %converted for C
            crtu = tempdevice.getResource('conversion_units');
          catch
            crtc = 1;
            crtu = units;
          end
          
          epoch.addParameter('meanTemperature', mean(responseData.*crtc));
          epoch.addParameter('varTemperature', var(responseData.*crtc));
          epoch.addParameter('unitsTemperature', crtu);
          epoch.removeResponse(tempdevice);
        end
      end
      %look for amplifier holding potential (background/return)
      [hasAmp,~] = obj.rigHasDeviceType('amplifier');
      if hasAmp
        hAmp = obj.rig.getDevice(obj.amp);
        if hAmp.hasOutputStream()
          ampBg = hAmp.background;
          ampHold = sprintf('%2.3f %s', ...
            ampBg.quantity, ...
            ampBg.displayUnits ...
            );
          epoch.addParameter('amplifierHoldingPotential', ampHold);
        end
      end
    end
    
    function completeRun(obj)
      completeRun@symphonyui.core.Protocol(obj);
    end
    
    function didSetPersistor(obj)
      didSetPersistor@symphonyui.core.Protocol(obj);
      % Override to perform actions after this protocol's persistor is set,
      % e.g. assign property values based on
      % experiment entities. Note that persistor may be assigned as empty
      % is there is no persistor.
    end
    
    function p = getPreview(obj, panel)
      p = getPreview@symphonyui.core.Protocol(obj,panel);
      % Override to return a ProtocolPreview implementation that manages a
      % preview for this protocol, e.g.
      % StimuliPreview
    end
    
    function prepareInterval(obj, interval)
      prepareInterval@symphonyui.core.Protocol(obj,interval);
      % Override to perform actions before each interval is added to the epoch
      % queue. An interval is an epoch that
      % is not saved.
    end
    
    function controllerDidStartHardware(obj)
      controllerDidStartHardware@symphonyui.core.Protocol(obj);
      % Override to perform actions after the DAQ controller actually starts the
      % hardware, e.g. play a
      % synchronized visual stimulus from a disparate system
    end
    
    function tf = shouldContinuePreloadingEpochs(obj)
      tf = shouldContinuePreloadingEpochs@symphonyui.core.Protocol(obj);
      % Override to return true/false to indicate if this protocol should continue
      % preloading epochs
    end
    
    function tf = shouldWaitToContinuePreparingEpochs(obj)
      tf = shouldWaitToContinuePreparingEpochs@symphonyui.core.Protocol(obj);
      % Override to return true/false to indicate if this protocol should wait to
      % continue preparing epochs
    end
    
    function tf = shouldContinuePreparingEpochs(obj)
      tf = shouldContinuePreparingEpochs@symphonyui.core.Protocol(obj);
      % Override to return true/false to indicate if this protocol should continue
      % preparing epochs
    end
    
    function tf = shouldContinueRun(obj)
      tf = shouldContinueRun@symphonyui.core.Protocol(obj);
      % Override to return true/false to indicate if this protocol should
      % continue to run
    end
    
    function completeInterval(obj, interval)
      completeInterval@symphonyui.core.Protocol(obj,interval);
      % Override to perform actions after each interval is completed
    end
    
    function [tf, msg] = isValid(obj)
      % Override to return true/false to indicate if this protocol is valid and
      % should be able to run
      % By default, tf is true.
      [tf,msg] = isValid@symphonyui.core.Protocol(obj);
      
    end
    
  end
  
  methods (Access = protected)
    
    function [tf,devName] = rigHasDeviceName(obj,expression)
      % RIGHASDEVICEName Tries to locate device of given name, returns [tf,deviceName]
      names = cellfun(@(d)d.name,obj.rig.devices,'UniformOutput',false);
      [tf,devName] = admin.utils.ValidStrings(expression,names,'-any');
      if ~tf, devName = ''; end
    end
    
    function [tf,devName] = rigHasDeviceType(obj,expression)
      % RIGHASDEVICEType Tries to locate device of given type, returns [tf,deviceName]
      devices = obj.rig.devices;
      
      types = cellfun(@getDeviceType,devices,'UniformOutput',false);
      types = cat(1,types{:});
      [tf,idx] = admin.utils.ValidStrings(expression,types(:,1),'-any');
      if ~tf
        devName = {};
      else
        % get all matching names for type
        devName = types(strcmp(types(:,1),idx),2);
      end
      function type = getDeviceType(dev)
        try
          type = {dev.deviceType,dev.name};
        catch
          type = {'unspecified',dev.name};
        end
      end
    end
    
    function [value, type] = createAmplifiersNamesProperty(obj)
      % A convenience method for creating a property value/type combination that allows a device name to be
      % selected from a list of available devices in the rig with names matching the given expression
      
      % amps are input devices
      devices = obj.rig.getInputDevices();
      nameList = cell(1,numel(devices));
      for d = 1:numel(devices)
        if isa(devices{d},'admin.core.devices.Device')
          if ~strcmpi(devices{d}.deviceType,'Amplifier')
            continue;
          end
          nameList{d} = devices{d}.name;
        elseif isa(devices{d},'admin.devices.Axopatch200B')
          nameList{d} = devices{d}.name;
        elseif isa(devices{d}, 'symphonyui.builtin.devices.AxopatchDevice')
          nameList{d} = devices{d}.name;
        end
      end
      % drop unused slots
      nameList(cellfun(@isempty,nameList,'UniformOutput',true)) = [];
      if isempty(nameList)
        nameList = '(None}';
      end
      
      % set the values
      value = nameList{1};
      type = symphonyui.core.PropertyType('char', 'row', nameList);
    end
    
  end
end
