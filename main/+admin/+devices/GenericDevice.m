classdef GenericDevice < admin.core.devices.Device
% GENERICDEVICE Is a wrapper for the custom core device.
% Example digital device:
% > oscil = GenericDevice(                      ...
%     'Oscilloscope',                           ... %name
%     '',                                       ... %unitless
%     daq,                                      ... %daq handle
%     'digitalStream',             'doport1',   ... %digital stream id
%     'bitPosition',              0,            ... %digital port postition
%     'type',                 'Oscilloscope',   ... %device type
%     'manufacturer',           'Tektronix',    ... %manufactureer
%     'description', 'model TBS2000B on input 1'... %description/note
%     );
%
% Example of analog device with a unit conversion
% Create the Temperature Monitor
% > tempProbe = GenericDevice(                  ...
%     'Temperature Monitor',                    ...
%     'dV',                                     ... %convert to dV by 10^1
%     daq,                                      ...
%     'inputStream',                   'ai7',   ...
%     'type',            'Temperature Probe',   ...
%     'manufacturer',   'Warner Instruments',   ...
%     'description',          'Model TC-324B'   ...
%     );
% tempProbe.setResource('conversion_units', '°C');


  methods
    
    function obj = GenericDevice(name,conversionTarget,daq,varargin)
      obj = obj@admin.core.devices.Device(name,conversionTarget,daq,varargin{:});
    end
    
  end
  
end