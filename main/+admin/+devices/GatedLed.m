classdef GatedLed < admin.core.devices.Device
  
  
  methods
    
    function obj = GatedLed(name,daq,varargin)
      ip = inputParser();
      ip.KeepUnmatched = true;
      ip.addOptional(                                         ... % wavelength (nm)
        'wavelength',      'unspecified',                     ... % or e.g. 'white'
        @(x) validateattributes(x,{'numeric','char'},{'row','nonempty'})     ...
        );
      ip.parse(varargin{:});
      
      %construct the device from the superclass
      superOps = ip.Unmatched; %captures manufacturer
      superOps.type = 'LED';
      % a gated led has no analog inputs or outputs
      if isprop(superOps,'inputStream')
        warning('A gated LED should have no input streams.');
      end
      if isprop(superOps,'outputStream')
        warning('A gated LED should have no output streams.');
      end
      if ~isprop(superOps,'digitalStream')
        error('A gated LED requires a digital stream.');
      end
      
      superOps.inputStream = '';
      superOps.outputStream = '';
      
      
      
      obj = obj@admin.core.devices.Device( ...
        name, ...
        '', ... % force unitless
        daq, ...
        superOps ...
        );
      
      % bind resources
      % bind this wavelength as a resource.
      obj.addResource('wavelength', ip.Results.wavelength);
    end
    
  end
  
  
end