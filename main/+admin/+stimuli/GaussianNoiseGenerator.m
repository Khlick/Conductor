classdef GaussianNoiseGenerator < symphonyui.core.StimulusGenerator
  %GAUSSIANNOISEGENERATOR Generate "white" noise in a provided range
  
  properties
    preTime     % Leading duration (ms)
    stimTime    % Stimulus duration (ms)
    tailTime    % Trailing duration (ms)
    stimDelay   % Leadin time at oscillation center
    stimFollow % Trailing time at oscillation center
    contrast    % Standard deviation of the WN (units)
    center      % Amplitude center for WN step (units)
    background  % Device background quantity
    filtFreq    % Upper limit for the frequency componenets
    filtOrder   % Filter order for butterworth rolloff
    setSeed     % RNG seed: reset to 0 to reproduce each trace
    outputLimits % Extreme limits [low,high] of the output signal (after inversion)
    invert = false % Invert output range
    sampleRate  % stimulus sample rate
    units       % stimulus device units
    addToBackground = false; % Should the center value be added to background
  end
  
  
  methods
    
    function obj = GaussianNoiseGenerator(map)
      if nargin < 1
        map = containers.Map();
      end
      obj@symphonyui.core.StimulusGenerator(map);
    end
    
  end
  
  methods (Access = protected)
    
    function stim = generateStimulus(obj)
      import Symphony.Core.*;
      
      ms2pt = @(t)round(t*1e-3*obj.sampleRate);
      
      % first create the white noise stim, correct the range, add to a step
      stimLen = ms2pt(obj.stimTime);
      
      %define MATLAB default random generator for reproducibility
      % by default use the mersenne twister
      rGen = RandStream('mt19937ar','Seed', obj.setSeed);
      
      % generate gaussian noise (full spectrum)
      noiseSpectra = fft(rGen.randn(1,stimLen));
      
      freqBinSize = obj.sampleRate / stimLen;
      
      lenOffset = mod(stimLen,2);
      
      frequencyVector = (0:(stimLen - lenOffset) /2) .* freqBinSize;
      % use buttter filter design
      flt = 1 ./(1 + (frequencyVector/obj.filtFreq).^(2*obj.filtOrder));
      % fft is symmetrical around Nyquist, so make filter sym too.
      flt = flt([1:end-(~lenOffset),end:-1:2]);
      % Apply the filter to the signal
      noiseSpectra = noiseSpectra .* flt;
      
      % convert the signal to time domain
      stimulus = real(ifft(noiseSpectra));
      
      % We need to rescale and zero-center the data considering our 
      % desired contrast (standard deviation).
      stimulus = (stimulus - mean(stimulus)) * obj.contrast/std(stimulus);
      
      % invert the stimulus now.
      if obj.invert
        stimulus = -stimulus;
      end
      
      % VALIDATE RANGE --- TODO
      % For now, let's just truncate the values, it will mess up the
      % contrast if we indeed have values beyond our bounds.
      %stimulus((stimulus+obj.center) > max(obj.outputLimits)) = ...
      %  max(obj.outputLimits)-obj.center;
      %stimulus((stimulus+obj.center) > min(obj.outputLimits)) = ...
      %  min(obj.outputLimits)-obj.center;
      
      % create the complete stimulus
      prePts = ms2pt(obj.preTime);
      tailPts = ms2pt(obj.tailTime);
      delayPts = ms2pt(obj.stimDelay);
      followPts = ms2pt(obj.stimFollow);
      
      
      stimTotal = delayPts+stimLen+followPts;
      stimWindow = ones(1,stimTotal) * obj.center;
      if obj.addToBackground
        stimWindow = stimWindow + obj.background;
      end
      stimWindow(delayPts+(1:stimLen)) = stimWindow(delayPts+(1:stimLen))+stimulus;
      
      data = ones(1,prePts+delayPts+stimLen+followPts+tailPts) * obj.background;
      data(prePts+(1:stimTotal)) = stimWindow;
      
      % symphony requirements
      parameters = obj.dictionaryFromMap(obj.propertyMap);
      measurements = Measurement.FromArray(data, obj.units);
      rate = Measurement(obj.sampleRate, 'Hz');
      output = OutputData(measurements, rate);

      cobj = RenderedStimulus(class(obj), parameters, output);
      stim = symphonyui.core.Stimulus(cobj);
      
    end
    
  end
  
  
end