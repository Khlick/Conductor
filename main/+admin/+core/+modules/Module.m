classdef (Abstract) Module < symphonyui.ui.Module
  
  properties (Access = protected)
    log
    settings
  end
  
  methods
    
    function obj = Module()
      obj.log = log4m.LogManager.getLogger(class(obj));
      setKey = matlab.lang.makeValidName(class(obj));
      setGrp = strsplit(class(obj),'.');
      setGrp = setGrp{end};
      obj.settings = admin.core.modules.Settings(setKey,setGrp);
    end
    
  end
  
  methods (Abstract,Access=protected)
    saveSettings(obj)
    loadSettings(obj)
  end
  
end

