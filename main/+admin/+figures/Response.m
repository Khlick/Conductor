classdef Response < admin.core.figures.SingleAxes
  
  
  methods
    
    function obj = Response(device,varargin)
      obj = obj@admin.core.figures.SingleAxes(device,varargin{:});
      % Name the figure
      obj.figureHandle.Name = sprintf('%s Response',device.name);
    end
    
    function handleEpoch(obj,epoch)
      handleEpoch@admin.core.figures.SingleAxes(obj,epoch);
      
      % get the data from the epoch for the bound device
      [x,y,units] = obj.getResponseData(epoch);
      
      % check that we have data
      if isempty(x), return; end
      
      % construct the line
      if isempty(obj.sweep)
        obj.sweep = line( ...
          obj.axesHandles, ...
          x, y, ...
          'Color', obj.sweepColor ...
          );
        % set new units on first run
        obj.axesHandles.YLabel.String = sprintf('Response (%s)',units);
        obj.axesHandles.XLabel.String = 'Time (sec)';
      else
        set( ...
          obj.sweep, ...
          'XData', x, ...
          'YData', y ...
          );
      end
    end
    
  end
  
  
end