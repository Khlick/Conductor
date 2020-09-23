classdef ArduinoFilterWheel < admin.core.devices.FilterWheelDevice
  % FILTERWHEEL A custom arduino based filter wheel created by Khris Griffis(2018-2019).
  %   This object is for use with Symphony version 2.x via the custom
  % DeviceConfigurator module (Sampath Lab, 2019). Also developed by Khris
  % Griffis.
  %
  % The current version of this device operates via a serial interface
  % similar to that of the thorlabs FW102C but differs in that 1 device may have
  % any number of associated filter wheels. For example, the one controller for
  % the FN-1 scope controls both upper and lower filter turrets.
  % All configurable components are handled through the appropriate Symphony
  % callbacks and interfaced here.
  %
  % see also: admin.core.devices.FilterWheelDevice
  
  properties (Constant)
    WAIT_FOR_RESPONSE = 0.50 % 500ms
  end
  
  properties (Dependent = true, SetAccess = protected) % abstract in super
    Wheel           % Current Wheel
    WheelId         % Current Wheel ID
    Position        % Current position in current wheel
    WheelCount      % Number of available wheels
    Count           % Number of available positions in current wheel
    Labels          % Access the labels in order of positions for current wheel
    Current         % Get the stored positions for attached wheels
    BoundDeviceName % Get the handle to the device bound to the active wheel
    Speed           % Get/Set the current speed in rpm
  end
  
  methods
    
    function obj = ArduinoFilterWheel(name,port,varargin)
      p = inputParser();
      p.KeepUnmatched = true;
      
      p.addRequired('Name',@ischar);
      p.addRequired('Port', @ischar);
      p.addParameter('Manufacturer','',@ischar);
      p.addParameter('WheelLabels',{''}, ...
        @(x)validateattributes(x,{'cell','string'},{'2d'}) ...
        );
      p.addParameter('PositionLabels',{{}}, ...
        @(x)validateattributes(x,{'cell'},{'2d'}) ...
        );
      p.addParameter('initialPosition', -1, ...
        @(x)validateattributes(x,{'numeric'},{'vector','nonempty'}) ...
        );
      
      p.addParameter('verbose', true, @islogical);
      
      p.parse(name,port,varargin{:});
      
      inputs = p.Results;
      
      % collect wheel labels
      wheelLabels = string(inputs.WheelLabels);
      if any(wheelLabels == "")
        eIdx = find(wheelLabels == "");
        for ee = 1:numel(eIdx)
          wheelLabels(eIdx(ee)) = string(eIdx(ee));
        end
      end
      inputs = rmfield(inputs,'WheelLabels');
      
      nWheels = numel(wheelLabels);
      
      % expecting positions to be a cell array of strings, each cell corresponds
      % to a wheel.
      if numel(inputs.PositionLabels) ~= nWheels
        error("Position labels expected to be cell array with %d slots.",nWheels);
      end
      
      posLabels = inputs.PositionLabels;
      % convert labels to strings (in case numeric was supplied)
      posLabels = cellfun(@string,posLabels,'UniformOutput',0);
      inputs = rmfield(inputs,'PositionLabels');
      
      % collect initial positions
      init = inputs.initialPosition;
      if numel(init) ~= nWheels
        init(end+(1:(nWheels-numel(init)))) = init(end);
      end
      inputs = rmfield(inputs,'initialPosition');
      
      % collect name
      name = inputs.Name;
      inputs = rmfield(inputs,'Name');
      
      % collect port
      port = inputs.Port;
      inputs = rmfield(inputs,'Port');
      
      % merge inputs for the superclass
      if ~isempty(p.Unmatched)
        fn = fieldnames(p.Unmatched);
        for f = 1:numel(fn)
          inputs.(fn{f}) = p.Unmatched.(fn{f});
        end
      end
      
      % set the terminator for the arduino to LF
      inputs.Terminator = 'LF';
      
      % create the object and connect to the device
      obj = obj@admin.core.devices.FilterWheelDevice(name,port,inputs);
      
      % Arduino wheel returns serial "ok" once initialized
      status = obj.read();
      iter = 0;
      while ~strcmpi(status,'ok')
        if iter > obj.MAX_ITER
          obj.close();
          error("Could not initialize filter wheel");
        end
        status = obj.read();
        pause(obj.WAIT_FOR_RESPONSE);
        iter = iter+1;
      end
      
      % prevent startup spitting out values
      vb = obj.verbose;
      obj.verbose = false;
      
      % validate that the serial interface has the same number of wheel as we
      % are attempting to initialize
      deviceWheelCount = str2double(obj.query('wcount'));
      if numel(wheelLabels) > deviceWheelCount
        error( ...
          'Device can only handle %d wheels, you provided %d.', ...
          deviceWheelCount, ...
          nWheels ...
          );
      end
      
      % Construct Labels
      for w = 1:nWheels
        obj.command('wheel',w); % activate the wheel on the device
        pMap = containers.Map();% position level
        pMap('ID') = wheelLabels{w};
        
        nQ = numel(posLabels{w});
        nP = str2double(obj.query("count"));% query the device
        keys = string(1:nP);
        if nQ ~= nP
          labels = string(1:nP);
        else
          labels = posLabels{w};
        end
        for i = 1:nP
          pMap(keys(i)) = labels(i);
        end
        
        % store map
        obj.filterMap(string(w)) = pMap;
        
        % update the bound device array
        obj.pairedDevice_(w) = containers.Map('KeyType','char','ValueType','any');
        
        % store initial positions
        if init(w) > 0
          obj.current_ = containers.Map(["wheel","position"],{w,init(w)});
        else
          qPos = obj.query("pos");
          pause(obj.WAIT_FOR_RESPONSE);
          qPos = str2double(regexprep(qPos,'[^\d]',''));
          obj.current_ = containers.Map(["wheel","position"],{w,qPos});
        end
      end
      
      % move if we need to
      obj.move();
      
      % flush the buffers
      obj.flush();
      pause(obj.WAIT_FOR_RESPONSE);
      
      % set the labels into a resource
      obj.updateLabelResource();
      
      % reset verbose to desired
      obj.verbose = vb;
    end
    
    function update(obj,position,wheel)
      % UPDATE To activate wheel only, set position to [] (empty)
      if ~obj.isReady, return; end
      if nargin < 3, wheel = obj.current_("wheel"); end
      obj.Wheel = wheel;
      % if we only want to activate a wheel, then we can enter an empty
      % array for position. This causes position to be retrieved and
      % prevents the device from moving.
      if isempty(position), position = obj.current_("position"); end
      obj.Position = position;
    end
    
    function close(obj)
      if obj.isReady
        fprintf(obj.controller,'save;');
        pause(obj.WAIT_FOR_RESPONSE);
      end
      
      % Call close at the superclass
      close@admin.core.devices.FilterWheelDevice(obj);
    end
    
  end
  
  methods
    %% GET/SET Methods
    function do(obj,name,val)
      obj.command(name,val);
    end
    
    function w = get.Wheel(obj)
      w = string(obj.current_("wheel"));
    end
    
    
    function set.Wheel(obj,w)
      % SET.WHEEL Set the current wheel.
      if ~obj.isReady, return; end
      if w > obj.WheelCount, w = obj.WheelCount; end
      if w < 1, w = 1; end
      
      curWheel = obj.current_("wheel");
      if w == curWheel, return; end
      
      % changing wheel. get the stored values for desired wheel.
      % Prevent from displaying new setting as we are only activating the
      % wheel and not moving
      vb = obj.verbose;
      obj.verbose = false;
      cur = obj.current_;
      cur("wheel") = w;
      cur("position") = obj.cache(string(w));
      obj.current_ = cur;
      % activate the wheel on the device
      obj.command('wheel',w);
      obj.verbose = vb;
    end
    
    
    function L = get.WheelId(obj)
      wheel = obj.filterMap(obj.Wheel);
      L = wheel("ID");
    end
    
    
    function set.WheelId(obj,L)
      wheel = obj.filterMap(obj.Wheel);
      wheel("ID") = string(L);
      obj.filterMap(obj.Wheel) = wheel;
      obj.updateLabelResource();
    end
    
    
    function n = get.WheelCount(obj)
      n = double(obj.filterMap.Count);
    end
    
    
    function set.Position(obj,pos)
      % SET.CURRENTPOSITION Move the active wheel to this position.
      if ~obj.isReady, return; end
      % allow setting from label or position
      cPos = obj.current_("position");
      if isnumeric(pos)
        % set based on numeric position. Validate that pos is within acceptable
        % range.
        
        % if the current position is the same as the new position, do nothing
        if pos == cPos, return; end
        if (pos < 1) || (pos > obj.Count)
          error("Invalid position. Expected to be on interval [1,%d]",obj.Count);
        end
      else
        % pos is, potentially, a label. Validate that the label is the same as
        % is defined in the filter map
        lab = string(pos); % cast to string for ease of operations
        
        % make a label
        lab = validatestring(lab,obj.Labels);
        
        % empty the pos var
        pos = obj.getPositionIndexFromLabel(lab);
        
        % if the current position is the same as the new position, do nothing
        if pos == cPos, return; end
      end
      
      % set and store the current position
      cur = obj.current_;
      cur("position") = pos;
      obj.current_ = cur;
      
      % move the wheel
      obj.move();
      
    end
    
    
    function p = get.Position(obj)
      % GET.CURRENTPOSITION
      p = string(obj.current_("position"));
      
    end
    
    
    function n = get.Count(obj)
      wheel = obj.filterMap(obj.Wheel);
      n = double(wheel.Count - 1);% subtract 1 for id
      
    end
    
    
    function labs = get.Labels(obj)
      % GET.LABELS Collect labels from current wheel
      wIdx = obj.Wheel;
      pMap = obj.filterMap(wIdx);
      labs = strings(1,pMap.Count-1);
      for L = 1:(pMap.Count-1)
        labs(L) = pMap(string(L));
      end
      
    end
    
    
    function set.Labels(obj,labs)
      % SET.LABELS Sets new labels for current wheel.
      wIdx = obj.Wheel;
      pMap = obj.filterMap(wIdx);
      labs = string(labs);
      N = pMap.Count-1;
      if numel(labs) ~= N
        error('Expected %d labels.', N);
      end
      % we expect that the labels are provided in order of positions.
      for n = 1:N
        obj.filterMap(string(n)) = labs(n);
      end
      % When setting labels, let's replace configurations
      obj.updateBoundConfigurations();
      obj.storeConfigurations();
      obj.updateLabelResource();
    end
    
    
    function s = get.Current(obj)
      % GET.Current Collect the status string for updating status config.
      ch = obj.cache;
      nW = obj.WheelCount;
      wheelstatus = cell(1,nW);
      for w = 1:nW
        idx = string(w);
        pdx = string(ch(idx));
        map = obj.filterMap(idx);
        
        wheelstatus{w} = sprintf('%s,%s',map("ID"),map(pdx));
      end
      s = strjoin(wheelstatus, '|');
      
    end
    
    
    function set.Speed(obj,rpm)
      if rpm < 10, rpm = 10; end
      obj.command("speed",fix(rpm));
      
    end
    
    
    function sp = get.Speed(obj)
      sp = obj.query("speed");
      sp = str2double(regexprep(sp,'[^\d]',''));
      
    end
    
    
    function name = get.BoundDeviceName(obj)
      name = '';
      if ~any(obj.hasBoundDevice), return; end
      w = obj.current_("wheel");
      device = obj.getBoundDeviceAtIndex(w);
      name = device.name;
    end
    
  end
  
  methods (Access = protected)
    %% Internal Usage (abstracts from super)
    
    function str = query(obj,qry)
      if ~obj.isReady, return; end
      qString = sprintf("%s?",qry);
      fprintf(obj.controller, qString);
      pause(obj.WAIT_FOR_RESPONSE);
      str = obj.read();
      % flush
      obj.flush();
    end
    
    
    function command(obj,cmd,value)
      if ~obj.isReady, return; end
      if value < 0
        drc = '-';
      else
        drc = '';
      end
      qString = sprintf("%s=%s%d;",cmd,drc,abs(value));
      fprintf(obj.controller,qString);
    end
    
    
    function str = read(obj)
      str = blanks(18);
      idx = 0;
      while obj.controller.BytesAvailable
        incoming = fscanf(obj.controller);
        len = length(incoming);
        str(idx+(1:len)) = incoming;
        idx = idx+len;
      end
      % trim leading and trailing blanks
      str = strtrim(str);
      
      % flush the controller
      obj.flush();
    end
    
    
    function move(obj)
      % MOVE Synchronizes the map position with the device. This is the main
      % communication method for controlling the position.
      if ~obj.isReady, return; end
      fprintf( ...
        obj.controller, ...
        sprintf( ...
          "pos=%d;", ...
          obj.current_("position") ...
          ) ...
        );
      obj.flush();
      
    end
    
  end
  
end

