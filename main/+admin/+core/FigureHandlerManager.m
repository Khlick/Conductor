classdef FigureHandlerManager < handle
  % A FigureHandlerManager manages figure handlers for a protocol.
  % modified from the original version to allow for reusable figures based on an
  % instance ID.
  
  properties (Access = private)
    log
  end
  
  properties (Access = private, Transient)
    figureHandlers
  end
  
  methods
    
    function obj = FigureHandlerManager()
      obj.log = log4m.LogManager.getLogger(class(obj));
    end
    
    function delete(obj)
      obj.closeFigures();
    end
    
    function h = showFigure(obj, className, varargin)
      
      % find instance Id
      idIndex = 0;
      for v = 1:numel(varargin)
        if ischar(varargin{v}) && strcmpi(varargin{v},'instanceid')
          idIndex = v;
          break
        end
      end
      if ~idIndex
        id = className;
      else
        id = varargin{idIndex+1};
      end
      % check if this figure is already open
      for i = 1:numel(obj.figureHandlers)
        handler = obj.figureHandlers{i};
        if isprop(handler,'instanceId') && strcmpi(id,handler.instanceId) && strcmp(class(handler), className)
          handler.show();
          h = handler;
          return;
        end
      end
      
      constructor = str2func(className);
      handler = constructor(varargin{:});
      handler.show();
      obj.figureHandlers{end + 1} = handler;
      addlistener(handler, 'Closed', @obj.onFigureHandlerClosed);
      h = handler;
    end
    
    function updateFigures(obj, epochOrInterval)
      for i = 1:numel(obj.figureHandlers)
        obj.figureHandlers{i}.handleEpochOrInterval(epochOrInterval);
      end
    end
    
    function clearFigures(obj)
      for i = 1:numel(obj.figureHandlers)
        obj.figureHandlers{i}.clear();
      end
    end
    
    function closeFigures(obj)
      while ~isempty(obj.figureHandlers)
        obj.figureHandlers{1}.close();
      end
    end
    
  end
  
  methods (Access = private)
    
    function onFigureHandlerClosed(obj, handler, ~)
      index = cellfun(@(h)h == handler, obj.figureHandlers);
      delete(handler);
      obj.figureHandlers(index) = [];
    end
    
  end
  
end