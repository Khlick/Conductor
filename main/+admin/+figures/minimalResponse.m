classdef minimalResponse < admin.core.figures.SingleAxes
  
  
  methods
    
    function obj = minimalResponse(device,varargin)
      obj = obj@admin.core.figures.SingleAxes(device,varargin{:});
      % Name the figure
      obj.figureHandle.Name = sprintf('%s Response',device.name);
    end
    
    function createUi(obj)
      createUi@admin.core.figures.SingleAxes(obj);
      axU = obj.axesHandles.Units;
      if ~strcmpi(axU,'normalized')
        obj.axesHandles.Units = 'normalized';
      end
      % get the inset
      obj.axesHandles.YLabel.String = 'Response';
      drawnow;
      
      inset = obj.axesHandles.TightInset;
      obj.axesHandles.Position = [ ...
        inset(1:2)+[0.015,0], ... %origin
        1-inset(1)-inset(3)-0.016, 1-inset(2)-inset(4) ... % dimensions
        ];
      obj.axesHandles.Units = axU;
    end
    
    
    function handleEpoch(obj,epoch)
      handleEpoch@admin.core.figures.SingleAxes(obj,epoch);
      
      % get the data from the epoch for the bound device
      [x,y,units] = obj.getResponseData(epoch);
      
      % check that we have data
      if isempty(x), return; end
      
      if isempty(obj.sweep)
        obj.sweep = line( ...
          obj.axesHandles, ...
          x, y, ...
          'Color', obj.sweepColor ...
          );
        % set new units on first run
        obj.axesHandles.YLabel.String = units;
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