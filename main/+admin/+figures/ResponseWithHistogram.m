classdef ResponseWithHistogram < admin.core.figures.DualAxes
  
  properties
    histSweep
    binMethod
  end
  
  methods
    
    function obj = ResponseWithHistogram(device,varargin)
      ip = inputParser;
      ip.KeepUnmatched = true;
      ip.addParameter('method', 'fd', ...
        @(x)admin.utils.ValidStrings(x,{'fd','sturges','auto','scott','sqrt'}) ...
        );
      ip.parse(varargin{:});
      
      %construct the object
      obj = obj@admin.core.figures.DualAxes(device,ip.Unmatched);
      
      % Name the figure
      obj.figureHandle.Name = sprintf('%s Response',device.name);
      
      % initialize histSweep
      obj.histSweep = gobjects(1,2);
      obj.binMethod = ip.Results.method;
      
      % Set axes titles
      if ~obj.disableTitles
        obj.axesHandles(1).Title.String = sprintf('%s Response',device.name);
        obj.axesHandles(2).Title.String = 'Response Distribution';
      end
      
      % link the axes in the y direction
      linkaxes(obj.axesHandles,'y');
      
    end
    
    function handleEpoch(obj,epoch)
      handleEpoch@admin.core.figures.DualAxes(obj,epoch);
      
      % get the data from the epoch for the bound device
      [x,y,units] = obj.getResponseData(epoch);
      
      % check that we have data
      if isempty(x), return; end
      
      % Construct the histogram
      [counts,edges] = histcounts(y,'BinMethod',obj.binMethod);
      [sVals,heights] = admin.utils.hist2dots(y,counts);
      edges = admin.utils.rep(edges,1,2);
      counts = [0;admin.utils.rep(counts,1,2);0];
      % Make sure the autolimits of the first axes are used
      lims = [min(y),max(y)];
      lims = lims + [-1,1].*0.05*diff(lims);
      
      if isempty(obj.sweep)
        obj.sweep = line( ...
          obj.axesHandles(1), ...
          x, y, ...
          'Color', obj.sweepColor ...
          );
        
        % create the histogram line
        obj.histSweep(1) = line( ...
          obj.axesHandles(2), ...
          counts, edges, ...
          'LineWidth', 2, ...
          'Color',  brighten(obj.sweepColor,-0.1) ...
          );
        % create the points
        obj.histSweep(2) = line( ...
          obj.axesHandles(2), ...
          heights, ...
          sVals, ...
          'linestyle', 'none', ...
          'marker', '.', ...
          'markersize', 0.5, ...
          'color', obj.sweepColor ...
          );
        
        % set new units on first run
        obj.axesHandles(1).YLabel.String = sprintf('Response (%s)',units);
        obj.axesHandles(1).XLabel.String = 'Time (sec)';
        obj.axesHandles(2).XLabel.String = 'Frequency (counts)';
      else
        set( ...
          obj.sweep, ...
          'XData', x, ...
          'YData', y ...
          );
        set( ...
          obj.histSweep(1), ...
          'XData', counts, ...
          'YData', edges ...
          );
        set( ...
          obj.histSweep(2), ...
          'XData', heights, ...
          'YData', sVals ...
          );
      end
      
      uistack(obj.histSweep,'top');
      % update limits, axes are linked in this class
      obj.axesHandles(2).YLim = lims;
    end
    
    
    % extend clear() to handle histogram
    function clear(obj)
      clear@admin.core.figures.DualAxes(obj);
      % clear will delete all axes children, so we just need to empty the sweep
      % container
      obj.histSweep = [];
    end
    
  end
  
  
end