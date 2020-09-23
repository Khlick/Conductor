classdef MeanResponseWithHistogram < admin.core.figures.DualAxes
  
  properties (Access = protected)
    showEach
    groupBy
    binMethod
  end
  
  properties (SetObservable=true,Access=protected)
    titleString = ''
  end
  
  methods
    
    
    function obj = MeanResponseWithHistogram(device,varargin)
      ip = inputParser();
      ip.KeepUnmatched = true;
      ip.addParameter('groupBy', {}, @iscellstr);
      ip.addParameter('showEach', false, @islogical);
      ip.addParameter('method', 'fd', ...
        @(x)admin.utils.ValidStrings(x,{'fd','sturges','auto','scott','sqrt'}) ...
        );
      ip.parse(varargin{:});
      
      %construct the object
      superOpts = ip.Unmatched;
      % override anything silly
      superOpts.disableToolbar = false;
      superOpts.disableMenubar = false;
      % super constructor
      obj = obj@admin.core.figures.DualAxes(device,superOpts);
      
      % set properties
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
      
      % set the binning method for the histogram
      obj.binMethod = ip.Results.method;
      
      % Set YLabel to '' for detecting set in the bottom
      obj.axesHandles(1).YLabel.String = '';
      obj.axesHandles(2).YLabel.String = '';
      
      % link the axes in the y direction
      linkaxes(obj.axesHandles,'y');
      
      %construct a listener for post set on title string
      addlistener(obj,'titleString','PostSet',@(s,e)obj.setTitle());
    end
    
    
    function handleEpoch(obj,epoch)
      handleEpoch@admin.core.figures.DualAxes(obj,epoch);
      
      % get the data from the epoch for the bound device
      [x,y,units] = obj.getResponseData(epoch);
      
      % check that we have data
      if isempty(x), return; end
      
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
        sweep.count = ones(1,numel(y));
        sweep.line = line( ...
          obj.axesHandles(1), ...
          sweep.x, sweep.y, ...
          'Color', obj.getColor(length(obj.sweeps)+1) ... %getColor updates sweepcolor
          );
        % Construct the histogram
        [counts,edges] = histcounts(y,'BinMethod',obj.binMethod);
        [sVals,heights] = admin.utils.hist2dots(y,counts);
        edges = admin.utils.rep(edges,1,2);
        counts = [0;admin.utils.rep(counts,1,2);0];
        % plot the histogram
        sweep.hist = gobjects(1,2);
        % create the points
        sweep.histSweep(2) = line( ...
          obj.axesHandles(2), ...
          heights, ...
          sVals, ...
          'linestyle', 'none', ...
          'marker', '.', ...
          'markersize', 0.5, ...
          'color', obj.sweepColor ...
          );
        % lines
        sweep.histSweep(1) = line( ...
          obj.axesHandles(2), ...
          counts, edges, ...
          'LineWidth', 2, ...
          'Color',  brighten(obj.sweepColor,-0.1) ...
          );
        % if we are showing each, we need to plot the children
        if obj.showEach
          childColor = brighten(obj.sweepColor,0.8);
          sweep.childLines{1} = line(sweep.x, sweep.y, ...
            'Parent', obj.axesHandles(1), ...
            'Color', childColor ...
            );
          sweep.childHist{1,1} = line( ...
            obj.axesHandles(2), ...
            heights, ...
            sVals, ...
            'linestyle', 'none', ...
            'marker', '.', ...
            'markersize', 0.5, ...
            'color', childColor ...
            );
          sweep.childHist{1,2} = line( ...
            obj.axesHandles(2), ...
            counts, edges, ...
            'LineWidth', 1, ...
            'Color',  brighten(obj.sweepColor,-0.1) ...
            );
          % keep the original traces on the bottom
          uistack(sweep.childLines{1},'bottom');
          uistack([sweep.childHist{1,:}], 'bottom');
        end
        obj.sweeps{end + 1} = sweep;
        % set new units on first run
        obj.axesHandles(1).YLabel.String = sprintf('Response (%s)',units);
        obj.axesHandles(1).XLabel.String = 'Time (sec)';
        obj.axesHandles(2).XLabel.String = 'Frequency (counts)';
      else
        % already exists, need to update the mean line by weighting the averaged
        % line by the number of sweep: (Y*w + y) / (w+1)
        % this assumes that epochs being averaged together are the same length
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
        
        set(sweep.line,'XData',sweep.x,'YData', sweep.y);
        
        % update the histogram
        % Construct the histogram
        [counts,edges] = histcounts(sweep.y,'BinMethod',obj.binMethod);
        [sVals,heights] = admin.utils.hist2dots(sweep.y,counts);
        edges = admin.utils.rep(edges,1,2);
        counts = [0;admin.utils.rep(counts,1,2);0];
        set(sweep.histSweep(2),'XData',heights,'YData',sVals);
        set(sweep.histSweep(1),'XData',counts,'YData',edges);
        
        if obj.showEach
          % if showing children lines, we need to plot the new data in grey
          childColor = brighten(sweep.line.Color,0.8);
          sweep.childLines{end +1} = line( ...
            sweep.x, y, ...
            'Parent', obj.axesHandles(1), ...
            'Color', childColor ...
            );
          sweep.childHist{end+1,1} = line( ...
            obj.axesHandles(2), ...
            heights, ...
            sVals, ...
            'linestyle', 'none', ...
            'marker', '.', ...
            'markersize', 0.5, ...
            'color', childColor ...
            );
          sweep.childHist{end,2} = line( ...
            obj.axesHandles(2), ...
            counts, edges, ...
            'LineWidth', 1, ...
            'Color',  brighten(obj.sweepColor,-0.1) ...
            );
          % keep the original traces on the bottom
          uistack(sweep.childLines{end}, 'bottom');
          uistack([sweep.childHist{end,:}], 'bottom');
        end
        
        %always set the line modified to the top of the graphics stack
        uistack(sweep.line,'top');
        uistack(sweep.histSweep(1),'top');
        obj.sweeps{sweepIndex} = sweep;
      end
      %obj.axesHandles(2).YLim = lims;
      obj.axesHandles(1).YLimMode = 'auto';
    end
    
    % extend clear() to handle histogram
    function clear(obj)
      clear@admin.core.figures.DualAxes(obj);
      % clear will delete all axes children, so we just need to empty the sweep
      % container
    end
    
  end
  
  
  
  methods (Access=protected)
    
    function setTitle(obj)
      if obj.figureHandle.isvalid && ~obj.disableTitles
        obj.axesHandles(1).Title.String = obj.titleString;
        obj.axesHandles(2).Title.String = 'Distribution';
      end
    end
    
  end
  
end