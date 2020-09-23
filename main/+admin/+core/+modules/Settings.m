classdef Settings < appbox.Settings
  %% SETTINGS Allows modules to have position/size persisted.
  properties (Access = private)
    customSettings
  end
  
  methods
    
    function obj = Settings(varargin)
      obj = obj@appbox.Settings(varargin{:});
      obj.customSettings = obj.get( ...
        'customSettings', ...
        containers.Map('KeyType', 'char', 'ValueType', 'any') ...
        );
    end
    
    function Set(obj,name,value)
      obj.customSettings(name) = value;
    end
    
    function v = Get(obj,name,default)
      if nargin < 3, default = []; end
      if ~obj.customSettings.isKey(name)
        obj.customSettings(name) = default;
        v = default;
        return
      end
      v = obj.customSettings(name);
    end
    
  end
  
  methods (Access=public,Hidden=true)
    
    function delete(obj)
      obj.put('customSettings', obj.customSettings);
      obj.save();
    end
  end
end

