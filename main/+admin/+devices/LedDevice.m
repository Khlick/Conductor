classdef LedDevice < admin.core.devices.Device
  
  properties (Transient,Hidden)
    maxVoltage = Inf
  end
  
  methods
    
    function obj = LedDevice(name,daq,varargin)
      ip = inputParser();
      ip.KeepUnmatched = true;
      ip.addOptional(                                         ... % wavelength (nm)
        'wavelength',      'unspecified',                     ... % or e.g. 'white'
        @(x) validateattributes(x,{'numeric','char'},{'row','nonempty'})     ...
        );
      ip.addOptional(                                         ... % output stream
        'outputStream',        'ao0',                         ...
        @(x) any(regexp(x,'^ao\d'))                           ...
        );
      ip.addParameter(                                        ... % input stream
        'inputStream',            '',                         ...
        @(x) isempty(x) || any(regexp(x,'^ai\d'))             ...
        );
      ip.addParameter(                                        ... % output units
        'outputTargetUnits',     'V',                         ...
        @ischar                                               ...
        );
      ip.addParameter(                                        ... % input units
        'inputTargetUnits',      'A',                         ...
        @ischar                                               ...
        );
      ip.addParameter(                                        ... % input extra scale
        'inputExtraScale',         1,                         ... % factor multiple
        @(x) validateattributes(x,{'numeric'},{'scalar'})     ... % f * 10^(Uo - Ui)
        );
      ip.addParameter(                                        ... % stim Max V
        'maximum',               Inf,                         ...
        @(x) validateattributes(x,{'numeric'},{'scalar'})     ...
        );
      ip.addParameter(                                        ... % calibration
        'calibrationLUT',   '(None)',                         ...
        @ischar                                               ...
        );
      ip.addParameter(                                        ... % measured spectrum
        'spectrum',         '(None)',                         ... % for this LED
        @ischar                                               ...
        );
      ip.addParameter(                                        ... % ND lookup
        'ndLUT',            '(None)',                         ... % e.g. for attached
        @ischar                                               ... % filter wheel
        );
      ip.addParameter(                                        ... % custom nd config
        'nd',                  {'0'},                         ... % value
        @(x) isempty(x) || iscellstr(x) || isstring(x)        ... % ignored if empty
        );
      ip.addParameter(                                        ... % custom nd config
        'ndOptions',     {'0','...'},                         ... % options
        @(x) isempty(x) || iscellstr(x) || isstring(x)        ... % ignored if empty
        );
      ip.addParameter(                                        ... % lambda is fixed
        'isLambdaFixed',       false,                         ... % if true, can be
        @(x) validateattributes(x,{'logical'},{'scalar'})     ... % removed,
        );
      
      ip.parse(varargin{:});
      
      %construct the device from the superclass
      superOps = ip.Unmatched; %captures manufacturer
      
      % append validated fields
      superOps.inputStream = ip.Results.inputStream;
      superOps.outputStream = ip.Results.outputStream;
      
      % override any extras
      superOps.type = 'LED';
      
      % call the constructor
      % we use the output units for conversion since it is more important that
      % we have perfect scaling for the command voltage.
      % We will use the input units for scaling the input in a figure handler
      obj = obj@admin.core.devices.Device( ...
        name, ...
        ip.Results.outputTargetUnits, ...
        daq, ...
        superOps ...
        );
      
      % bind resources
      obj.maxVoltage = ip.Results.maximum;
      obj.setResource('maximum',                                 ip.Results.maximum);
      calLut = ip.Results.calibrationLUT;
      if ~contains(calLut,'None')
        try %#ok<TRYNC>
          calLut = importdata(calLut);
        end
      end
      obj.setResource('calibrationLut',                                      calLut);
      specLut = ip.Results.spectrum;
      if ~contains(specLut,'None')
        try %#ok<TRYNC>
          specLut = importdata(specLut);
        end
      end
      obj.setResource('spectrum',                                           specLut);
      ndLUT = ip.Results.calibrationLUT;
      if ~contains(ndLUT,'None')
        try %#ok<TRYNC>
          ndLUT = importdata(ndLUT);
        end
      end
      obj.setResource('neutralDensityLUT',                                    ndLUT);
      
      % calculate conversion for incoming streams. Unfortunately, the incoming
      % stream is not apparently scaled like the output stream.
      [inputPrefix,inputUnit] = admin.utils.getPrefixFromUnits(ip.Results.inputTargetUnits);
      inputExponent = admin.utils.prefixToExponent(inputPrefix);
      
      obj.setResource( ...
        'conversion', ...
        ip.Results.inputExtraScale * 10^(-inputExponent) ...
        );
      obj.setResource('conversion_units', [inputPrefix,inputUnit]);
      
      % bind configurations
      % set wavelength as a configuration instead of a resource to allow
      % interference filters on a FilterWheelDevice (see
      % admin.devices.dummyFilterWheel) to change the value. This also forces
      % the wavelength to be stored with each epoch.
      obj.addConfiguration( ...
        'wavelength', ...
        ip.Results.wavelength, ...
        {}, ...
        ~ip.Results.isLambdaFixed, ...
        false, ...
        'isRemovable', true, ...
        'isReadOnly', ip.Results.isLambdaFixed, ...
        'description', 'Wavelength of the LED' ...
        );
      
      % check if we intend to add ND filters
      if ~isempty(ip.Results.nd)
        obj.addConfiguration( ...
          'ND', ...
          ip.Results.nd, ...
          ip.Results.ndOptions, ...
          true, ...
          false, ...
          'isRemovable', true, ...
          'isReadOnly', false, ...
          'description', 'Nuetral Density (optical density units) in pathway.' ...
          );
      end
    end
    
    function tf = canAcceptVoltage(obj,v)
      tf = (v <= obj.maxVoltage) & (v >= 0);
    end
    
  end
end