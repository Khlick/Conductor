classdef ThorlabsFilterWheel < admin.core.devices.FilterWheelDevice
  % thorlabsFilterWheel An interactive Thorlabs FW102c device for symphony.
  %   The basic mechanism of this device is to store configuration settings into
  %   a map and then communicate the setting to the device connected
  %   on the COM port.
  
  properties (Constant)
    WAIT_FOR_RESPONSE = 0.25 % seconds to wait for device
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
  
  methods
    %% Public
    
    function obj = ThorlabsFilterWheel(name,port,varargin)
      p = inputParser();
      p.KeepUnmatched = true;
      
      p.addRequired('Name',@ischar);
      p.addRequired('Port', @ischar);
      p.addParameter('Manufacturer','ThorLabs',@ischar);
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
      if ~isequal(p.Unmatched,struct())
        fn = fieldnames(p.Unmatched);
        for f = 1:numel(fn)
          inputs.(fn{f}) = p.Unmatched.(fn{f});
        end
      end
      
      % Set the terminator for ThorLabs FW102c to CR
      inputs.Terminator = 'CR';
      
      % create the object and connect to the device
      obj = obj@admin.core.devices.FilterWheelDevice(name,port,inputs);
      
      % silence output for startup
      vb = obj.verbose;
      obj.verbose = false;
      
      % For ThorLabs FW102C, we can query the device for it's current position
      % and the number of available positions. We must provide labels for the ND
      % filters in place. We also assume that we have only 1 wheel per device,
      % we can provide it a label if we want.
      
      %//for w = 1:numel(wheelLabels)
      w = 1; % only allow 1 wheel despite number of input labels
      
      pMap = containers.Map();% position level
      pMap('ID') = wheelLabels{w};

      % collect input and wheel position counts
      nQ = numel(posLabels{w});
      nP = obj.Count;

      % determine labels from input or generic 1:nP
      keys = string(1:nP);
      if nQ ~= nP
        labels = string(1:nP);
      else
        labels = posLabels{w};
      end
      % Store the label in the position
      for i = 1:nP
        pMap(keys(i)) = labels(i);
      end

      % store the map
      obj.filterMap(string(w)) = pMap;

      % update the bound devices array
      obj.pairedDevice_(w) = containers.Map('KeyType','char','ValueType','any');
      
      % store initial positions
      if init(w) > 0
        obj.current_ = containers.Map(["wheel","position"],{w,init(w)});
      else
        queryPos = str2double(obj.query("pos"));
        iter = 0;
        while queryPos < 0
          iter = iter+1;
          if iter > 20, error("Cannot Query Position"); end
          queryPos = str2double(obj.query("pos"));
          pause(obj.WAIT_FOR_RESPONSE);
        end
        obj.current_ = containers.Map(["wheel","position"],{w,queryPos});
      end
      
      % move if we need to
      obj.move();
      
      % flush the buffers
      obj.flush();
      pause(obj.WAIT_FOR_RESPONSE);
      
      % set the labels into a resource
      obj.updateLabelResource();
      
      % Turn verbose flag back to desired
      obj.verbose = vb;
    end
    
    function update(obj,position,wheel)
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
      % intercept close command to perform desired actions before killing
      % the object
      close@admin.core.devices.FilterWheelDevice(obj);
    end
    
  end
  
  methods
    %% GET/SET Methods
    
    function w = get.Wheel(obj)
      w = string(obj.current_("wheel"));
    end
    
    
    function set.Wheel(obj,w)
      % SET.WHEEL Set the current wheel. In thorlabs filter wheels, this isn't
      % implemented so just set the wheel to 1.
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
    
    
    function n = get.WheelCount(obj) %#ok
      % For ThorLabs Wheel controllers, we only have 1 wheel to operate.
      n = 1;
    end
    
    
    function set.Position(obj,pos)
      % SET.CURRENTPOSITION Move the wheel to this position.
      if ~obj.isReady, return; end
      % allow setting from label or position
      cPos = obj.current_("position");
      if isnumeric(pos)
        % set based on numeric position. Validate that pos is within acceptable
        % range.
        
        % if the current position is the same as the new position, do nothing
        if pos == cPos, return; end
        if pos < 1 || pos > obj.Count
          error("Invalid position. Expected to be on the interval [1,%d]",obj.Count);
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
      p = string(obj.current_("position"));
    end
    
    
    function n = get.Count(obj)
      % GET.COUNT return the number of positions
      pause(0.01);
      n = obj.query("pcount");
      n = str2double(regexprep(n,'[^\d]',''));
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
      % when query fw, need to read 2 times to find the correct output.
      % This assumes a valid query is entered.
      if ~obj.isReady, return; end
      qString = sprintf("%s?",qry);
      fprintf(obj.controller, qString);
      pause(obj.WAIT_FOR_RESPONSE);
      str = obj.read();
      str = regexprep(str,'[\n\r\W\D]+','');
      str = regexprep(str,[qry,'[?]'],'');
      % flush
      obj.flush();
    end
    
    
    function str = read(obj)
      str = blanks(18);
      idx = 0;
      % thorlabs returns '>' after succesful read/write. Need to skip last
      % byte read and allow flush to handle the channel.
      while obj.controller.BytesAvailable > 2
        incoming = fscanf(obj.controller);
        len = length(incoming);
        str(idx+(1:len)) = incoming;
        idx = idx+len;
        pause(0.01);
      end
      % trim leading and trailing blanks
      str = strtrim(str);
      % flush the controller
      obj.flush();
    end
    
    function move(obj)
      % MOVE Synchronizes the map position with the device. This is the main
      % communication method for controlling the position.
      if ~obj.isReady
        return;
      end
      fprintf(obj.controller,sprintf("pos=%d",obj.current_("position")));
      pause(obj.WAIT_FOR_RESPONSE);
      obj.flush();
    end
    
  end
  
end

