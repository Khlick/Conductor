classdef (ConstructOnLoad) filterWheelEvent < event.EventData & dynamicprops
  %FILTERWHEELEVENT Event data for filterwheel events 
  
  properties
    WheelIndex
  end
  
  
  methods
    
    function evt = filterWheelEvent(wheelIdx,varargin)
      %FILTERWHEELEVENT Construct an instance of this class
      evt.WheelIndex = wheelIdx;
      for i = 1:2:numel(varargin)
        propname = matlab.lang.makeValidName(varargin{i});
        evt.addprop(propname);
        evt.(varargin{i}) = varargin{i+1};
      end
    end
    
  end
  
end

