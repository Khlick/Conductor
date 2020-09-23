classdef DifferentialAmplifier < admin.core.devices.Device
  %DIFFERENTIALAMPLIFIER Generic differential amplifier device type
  
  properties (Hidden)
    listeners
  end
  
  methods
    
    function obj = DifferentialAmplifier(name,conversionTarget,daq,varargin)
      
      ip = inputParser();
      ip.KeepUnmatched = true;
      ip.addOptional('inputStream','ai0',@(x)any(regexp(x,'^ai\d')));
      ip.addParameter('gain', 1000, @(x)~mod(x,10) || (x == 1));
      ip.addParameter('gainOptions', 10.^(1:4),@(x)isvector(x)&&isnumeric(x));
      ip.parse(varargin{:});
      
      % construct the object
      superOpts = ip.Unmatched;
      superOpts.inputStream = ip.Results.inputStream;
      superOpts.type = 'Amplifier';
      
      obj = obj@admin.core.devices.Device(name,conversionTarget,daq,superOpts);
      pause(0.01);
      
      % setup gain configuration
      gainOpts = num2cell(ip.Results.gainOptions);
      obj.addConfiguration('Gain', ip.Results.gain, gainOpts);
      
      % add conversion resources
      % for this amplifier we need to convert xV * gf where gf is the conversion
      % factor for gain. e.g. gf = 1000, 1mV recorded will be 1V. 
      [target,unit] = admin.utils.getPrefixFromUnits(conversionTarget);
      scaleExponent = admin.utils.prefixToExponent(target);
      
      obj.setResource('conversion',10^(-scaleExponent) * ip.Results.gain);
      obj.setResource('conversion_units',[target,unit]);
      
      % Add a listener for when Gain is changed
      obj.listeners = struct();
      obj.listeners.SetConfigurationSetting = addlistener( ...
        obj, ...
        'SetConfigurationSetting', ...
        @obj.didSetConfigurationSetting ...
        );
    end
    
  end
  
  
  methods (Access = protected)
    
    function didSetConfigurationSetting(obj,~,evt)
      % DIDSETCONFIGURATIONSETTING Catches configuration changes.
      %
      % For this device, we will catch changes to gain and then update the
      % conversion resource accordingly.
      d = evt.data;
      if ~strcmpi(d.name,'Gain'), return; end
      
      if iscell(d.value)
        value = str2double(d.value{1});
      elseif ischar(d.value)
        value = str2double(d.value);
      elseif isnumeric(d.value)
        value = double(d.value);
      end
      [target,~] = admin.utils.getPrefixFromUnits( ...
        obj.getResource('conversion_units') ...
        );
      
      scaleExponent = admin.utils.prefixToExponent(target);
      
      % update the conversion resource
      obj.setResource('conversion',value/10^(scaleExponent));
    end
    
  end
end

