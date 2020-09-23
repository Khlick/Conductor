classdef MeanResponse < admin.core.figures.SingleAxes
  
  properties (Access = protected)
    showEach
    groupBy
  end
  
  properties (SetObservable=true,Access=protected)
    titleString = ''
  end
  
  methods
    
    function obj = MeanResponse(device,varargin)
      ip = inputParser();
      ip.KeepUnmatched = true;
      ip.addParameter('groupBy', {}, @iscellstr);
      ip.addParameter('showEach', false, @islogical);
      
      ip.parse(varargin{:});
      
      superOpts = ip.Unmatched;
      
      % override anything silly
      superOpts.disableToolbar = false;
      superOpts.disableMenubar = false;
      
      % create the figure
      obj = obj@admin.core.figures.SingleAxes(device,superOpts);
      
      obj.showEach = ip.Results.showEach;
      obj.groupBy = ip.Results.groupBy;
      
      % if any epochs persisted since last call, bring them up now
      stored = admin.core.figures.FigureWrap.storedSweeps();
      for i = 1:numel(stored)
        stored{i}.line = line(stored{i}.x, stored{i}.y, ...
          'Parent', obj.axesHandles, ...
          'Color', obj.storedSweepColor, ...
          'HandleVisibility', 'off' ...
          );
      end
      admin.core.figures.FigureWrap.storedSweeps(stored);
      
      % clear the sweeps property
      obj.sweeps = {};
      
      % Name the figure
      obj.figureHandle.Name = sprintf('%s Mean Response',device.name);
      
      % Set YLabel to '' for detecting set in the bottom
      obj.axesHandles.YLabel.String = '';
      
      %construct a listener for post set on title string
      addlistener(obj,'titleString','PostSet',@(s,e)obj.setTitle());
    end
    
    
    function handleEpoch(obj,epoch)
      handleEpoch@admin.core.figures.SingleAxes(obj,epoch);
      
      % get the data from the epoch for the bound device
      [x,y,units] = obj.getResponseData(epoch);
      
      % check that we have data
      if isempty(x), return; end
      x = x(:);
      y = y(:);
      
      % collect parameters for grouping
      % here we build a map for each parameter name to 
      % store the lines within
      p = epoch.parameters;
      if isempty(obj.groupBy) && isnumeric(obj.groupBy)
        parameters = p;
      else
        parameters = containers.Map();
        for i = 1:length(obj.groupBy)
          key = obj.groupBy{i};
          parameters(key) = p(key);
        end
      end
      
      % create the title string
      if isempty(obj.titleString)
        if isempty(parameters)
          t = 'None';
        else
          t = strjoin(parameters.keys, ', ');
        end
        obj.titleString = sprintf('%s Mean Response (%s)',obj.device.name,t);
      end
      
      % get the sweep index
      sweepIndex = [];
      if ~isempty(obj.sweeps)
        for i = 1:numel(obj.sweeps)
          if isequal(obj.sweeps{i}.parameters, parameters)
            sweepIndex = i;
            break;
          end
        end
      end
      
      % build the sweep data and plot
      if isempty(sweepIndex)
        % new group member of groupby, need to initialize the sweep data
        sweep.parameters = parameters;
        sweep.x = x;
        sweep.y = y;
        % set sweep count as a vector in case we want to average
        % different lengths
        sweep.count = ones(numel(y),1);
        sweep.line = line( ...
          obj.axesHandles, ...
          sweep.x, sweep.y, ...
          'Color', obj.getColor(length(obj.sweeps)+1) ...
          );
        % 
        if obj.showEach
          sweep.childLines{1} = line(sweep.x, sweep.y, ...
            'Parent', obj.axesHandles, ...
            'Color', brighten(obj.sweepColor,0.8) ...
            );
          % keep the original traces on the bottom
          uistack(sweep.childLines{1},'bottom');
        end
        obj.sweeps{end + 1} = sweep;
      else
        % already exists, need to update the mean line by weighting the averaged
        % line by the number of sweep: (Y*w + y) / (w+1)
        sweep = obj.sweeps{sweepIndex};
        % determine if we are trying to average different lengths
        % if y is longer, copy the new data into the x,y sweep vars.
        % if y is shorter, use a shorter index
        nNew = numel(y);
        nExist = numel(sweep.y);
        if nNew > nExist
          % expand the sweep if the new epoch is longer.
          newLength = nNew - nExist;
          sweep.y(nExist + (1:newLength)) = y(nExist + (1:newLength));
          sweep.x = x;
          % expand the counter for the new region
          sweep.count(nExist + (1:newLength)) = 1;
        end
        inds = 1:nNew;
        sweep.y(inds) = ( ...
            sweep.y(inds) .* sweep.count(inds) + y ...
          ) ./ ( ...
            sweep.count(inds) + 1 ...
          );
        sweep.count = sweep.count + 1;
        
        if obj.showEach
          % if showing children lines, we need to plot the new data in grey
          sweep.childLines{end +1} = line( ...
            x, y, ...
            'Parent', obj.axesHandles, ...
            'Color', brighten(sweep.line.Color,0.8) ...
            );
          % keep the original traces on the bottom
          uistack(sweep.childLines{end}, 'bottom');
        end
        set(sweep.line, 'XData', sweep.x, 'YData', sweep.y);
        %always set the line modified to the top of the graphics stack
        uistack(sweep.line,'top');
        obj.sweeps{sweepIndex} = sweep;
      end
      
      % finally set the axes units
      if isempty(obj.axesHandles.YLabel.String)
        obj.axesHandles.YLabel.String = sprintf('Response (%s)', units);
      end
    end
    
  end
  
  methods (Access=protected)
    
    function setTitle(obj)
      if obj.figureHandle.isvalid && ~obj.disableTitles
        obj.axesHandles.Title.String = obj.titleString;
      end
    end
    
  end
  
end