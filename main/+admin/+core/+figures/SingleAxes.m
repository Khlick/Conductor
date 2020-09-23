classdef (Abstract) SingleAxes < admin.core.figures.FigureWrap
  
  properties (Access = protected)
    axesHandles
  end
  
  methods
    
    function createUi(obj)
      obj.axesHandles = axes( ...
        'Parent', obj.figureHandle, ...
        'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'), ...
        'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'), ...
        'XTickMode', 'auto' ...
        );
    end
    
    
  end
  
end