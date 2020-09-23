classdef MultiPulseGenerator < symphonyui.core.StimulusGenerator
  % Generate mulitple pulses from input parameters
  properties
    preTime     % Leading duration (ms)
    stimTime    % Duration (ms) of each stimulus
    tailTime    % Trailing duration (ms)
    stimDelay   % Leadin time at oscillation center
    stimInterval% Duration between amplitude presentations
    stimTail % Trailing time during stimulus presentation
    amplitude   % Pulse amplitudes (units) (a vector)
    background  % Device background quantity.
    sampleRate  % Sample rate of generated stimulus (Hz) 
    units       % Units of generated stimulus
  end
  
  methods
    
    function obj = MultiPulseGenerator(map)
      if nargin < 1
        map = containers.Map();
      end
      obj@symphonyui.core.StimulusGenerator(map);
    end
    
    %% Get methods for converting time to points
    function t = get.preTime(obj)
      t = obj.m2p(obj.preTime);
    end
    function t = get.stimDelay(obj)
      t = obj.m2p(obj.stimDelay);
    end
    function t = get.stimTime(obj)
      t = obj.m2p(obj.stimTime);
    end
    function t = get.stimInterval(obj)
      t = obj.m2p(obj.stimInterval);
    end
    function t = get.stimTail(obj)
      t = obj.m2p(obj.preTime);
    end
    function t = get.tailTime(obj)
      t = obj.m2p(obj.tailTime);
    end
  end
  
  methods (Access = protected)
    
    function stim = generateStimulus(obj)
      %GENERATESTIMULUS Note that amplitudes will be added on top of background 
      import Symphony.Core.*;
      
      stimLength = obj.stimDelay + ...
        sum(obj.stimTime) + ...
        sum(obj.stimInterval) + ...
        obj.stimTail;
      
      stimWindow = ones(1,stimLength) .* obj.background;
      
      sIvt = cat(1,obj.stimDelay,obj.stimInterval(:));
      wStart = 0;
      for A = 1:length(obj.amplitude)
        % loop through each amplitude and set them in the correct location
        if A == 1
          prev = 0;
        else
          prev = prev + obj.stimTime(A-1);
        end
        wStart = wStart + prev + sIvt(A);
        stimIndices = (1:obj.stimTime(A)) + wStart;
        stimWindow(stimIndices) = stimWindow(stimIndices) + ...
          ones(1,obj.stimTime(A)) .* obj.amplitude(A);        
      end
      
      waveform = cat(2, ...
        ones(1,obj.preTime).*obj.background, ...
        stimWindow, ...
        ones(1,obj.tailTime).*obj.background ...
        );
      
      % symphony requirements
      parameters = obj.dictionaryFromMap(obj.propertyMap);
      measurements = Measurement.FromArray(waveform, obj.units);
      rate = Measurement(obj.sampleRate, 'Hz');
      output = OutputData(measurements, rate);

      cobj = RenderedStimulus(class(obj), parameters, output);
      stim = symphonyui.core.Stimulus(cobj);
    end
    
  end
  
  methods (Access = private)
    
    function pts = m2p(obj,t)
      pts = round(t.*1e-3.*obj.sampleRate);
    end
    
  end
  
end