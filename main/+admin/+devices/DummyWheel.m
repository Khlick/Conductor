classdef DummyWheel < admin.core.devices.FilterWheelDevice
  %DummyWheel Filter wheel that behaves like a controlled wheel wihtout serial interface.
  
  properties (Constant)
    WAIT_FOR_RESPONSE = 0.001 % 1ms
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
  end
  
  properties (Access = private)
    eraseOnCleanup
  end
  
  methods
    
    function obj = DummyWheel(name,varargin)
      %DummyWheel Construct a dummy wheel to track an unconected filter wheel
      
      p = inputParser();
      p.KeepUnmatched = true;
      
      p.addRequired('Name',@ischar);
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
      p.addParameter('overwrite', false, ...
        @(x)validateattributes(x,{'logical'},{'scalar','nonempty'}) ...
        );
      p.addParameter('erase', false, ...
        @(x)validateattributes(x,{'logical'},{'scalar','nonempty'}) ...
        );
      
      p.addParameter('verbose', true, @islogical);
      
      p.parse(name,varargin{:});
      
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
      
      % collect overwrite
      doOverwrite = inputs.overwrite;
      inputs = rmfield(inputs,'overwrite');
      
      % determine if we should erase the preference on cleanup
      eoc = inputs.erase;
      inputs = rmfield(inputs,'erase');
      
      % merge inputs for the superclass
      if ~isempty(p.Unmatched)
        fn = fieldnames(p.Unmatched);
        for f = 1:numel(fn)
          inputs.(fn{f}) = p.Unmatched.(fn{f});
        end
      end
      
      % create the object and connect to the device
      obj = obj@admin.core.devices.FilterWheelDevice(name,'dummy',inputs);
      
      % set erase property
      obj.eraseOnCleanup = eoc;
      
      % Check if we are creating the wheel or parsing an existing wheel
      if ~obj.controller.Count || doOverwrite
        obj.populateDummy(wheelLabels,posLabels,init);
      else
        % set the cache from the controller to allow query on first run
        prev = obj.controller('storage');
        for w = 1:nWheels
          obj.cache(string(w)) = prev(w);
        end
      end
      
      % prevent startup spitting out values
      vb = obj.verbose;
      obj.verbose = false;
      
      % Construct Labels
      for w = 1:nWheels
        obj.Wheel = w; % activate the wheel on the device
        pMap = containers.Map();% position level
        pMap('ID') = wheelLabels{w};
        
        nP = numel(posLabels{w});
        keys = string(1:nP);
        labels = posLabels{w};
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
          qPos = double(obj.query("pos"));
          obj.current_ = containers.Map(["wheel","position"],{w,qPos});
        end
      end
      
      % move if we need to
      obj.move();
      
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
      % CLOSE Override superclass method to handle non-serial controller
      lnames = fieldnames(obj.listeners);
      for i = 1:numel(lnames)
        if strcmp(lnames{i},'pairedListeners')
          cellfun(@delete,obj.listeners.(lnames{i}),'UniformOutput',false);
          continue
        end
        delete(obj.listeners.(lnames{i}));
      end
      if obj.eraseOnCleanup
        try  %#ok<TRYNC>
          rmpref( ...
            'symphonyui', ...
            sprintf('wheel_controller_%s',matlab.lang.makeValidName(obj.name)) ...
            );
        end
      else
        setpref( ...
          'symphonyui', ...
          sprintf('wheel_controller_%s',matlab.lang.makeValidName(obj.name)), ...
          obj.controller ...
          );
      end
      obj.setConfigurationSetting('Status', 'CLOSED');
      obj.open_= false;
    end
    
  end
  
  methods
    %% GET/SET Methods
    
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
      n = double(obj.query('wcount'));
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
        if pos < 1 || pos > obj.Count
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
      obj.current_("position") = pos;
      
      % move the wheel
      obj.move();
      
    end
    
    
    function p = get.Position(obj)
      % GET.CURRENTPOSITION
      p = obj.query('pos'); %as string
      
    end
    
    
    function n = get.Count(obj)
      n = double(obj.query('count'));% subtract 1 for id
      
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
      s = strjoin(wheelstatus,'|');
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
    
    function flush(obj) %#ok<MANU>
      
      % DummyWheel HAS NO CONTROLLER TO FLUSH
      
    end
    
    
    function move(obj)
      % MOVE Synchronizes the map position with the device. This is the main
      % communication method for updating controller positions
      if ~obj.isReady, return; end
      stored = obj.controller('storage');
      stored(obj.current_("wheel")) = obj.current_("position");
      obj.controller('storage') = stored;
    end
    
    
    function command(obj,cmd,value) %#ok<INUSD>
      % COMMAND Dummy has no device to command. Use internal settings
      
    end
    
    
    function str = query(obj,qry)
      % dummy wheel controller is a stored map returns string object
      c = obj.current_;
      switch qry
        case 'count'
          wIdx = c("wheel");
          pCount = obj.controller('positionCount');
          str = string(pCount(wIdx));
        case 'wcount'
          str = string(obj.controller('wheelCount'));
        case 'pos'
          wIdx = c("wheel");
          storage = obj.controller('storage');
          str = string(storage(wIdx));
        otherwise
          str = "";
      end
    end
    
  end
  
  
  methods (Access = private)
    
    function populateDummy(obj,WheelLabels,PositionLabels,init)
      
      % verify that init is at least 1, in the case of -1 default
      fixInitIdx = init < 1;
      init(fixInitIdx) = 1;
      % build the dummy wheel map
      dum = containers.Map('keytype','char','valuetype','any');
      nWheels = numel(WheelLabels);
      dum('wheelCount') = nWheels;
      dum('positionCount') = cellfun(@numel,PositionLabels,'UniformOutput',true);
      dum('storage') = init;
      
      % save this wheel to prefs
      setpref( ...
        'symphonyui', ...
        sprintf('wheel_controller_%s',matlab.lang.makeValidName(obj.name)), ...
        dum ...
        );
      
      % update controller object
      obj.controller = dum;
      
      % set the cache from the storage
      for w = 1:nWheels
        obj.cache(string(w)) = init(w);
      end
      
    end
    
  end
  
end

