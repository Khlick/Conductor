classdef NoiseGenerator < symphonyui.core.StimulusGenerator
  %NOISEGENERATOR Generate different "noise" types
  
  properties
    preTime     % Leading duration (ms)
    stimTime    % Stimulus duration (ms)
    tailTime    % Trailing duration (ms)
    stimDelay   % Leadin time at oscillation center
    stimFollow % Trailing time at oscillation center
    contrast    % Standard deviation of the WN (units)
    center      % Amplitude center for WN step (units)
    background  % Device background quantity
    filtOrder = 11 % Filter order for butterworth rolloff
    setSeed     % RNG seed: reset to 0 to reproduce each trace
    outputLimits % Extreme limits [low,high] of the output signal (after inversion)
    invert = false % Invert output range
    type = 'GaussianLowPass' % One of: 'Flat','ButterLowPass','GaussianLowPass','GaussianBandPass','GaussianBandStop'
    sampleRate  % stimulus sample rate
    units       % stimulus device units
    addToBackground = false; % Should the center value be added to background
  end
  
  properties(Dependent)
    filtFreq    % Upper limit for the frequency componenets
  end
  
  properties (Access=private)
    internalFilterFreq
  end
  
  methods
    
    function obj = NoiseGenerator(map)
      if nargin < 1
        map = containers.Map();
      end
      obj@symphonyui.core.StimulusGenerator(map);
    end
    
    function set.outputLimits(obj,value)
      if length(value) ~= 2
        error('Output Limits must be vector of length 2');
      end
      obj.outputLimits = sort(value,'ascend');
    end
    
    function fq = get.filtFreq(obj)
      fq = obj.internalFilterFreq;
    end
    
    function set.filtFreq(obj,value)
      if contains(obj.type,'Band') 
        if length(value) ~= 2
          error('Band pass/stop type noise requires filtFreq to be of length: 2');
        end
      else
        if length(value) > 1
          value(2:end) = [];
        end
      end
      % store
      obj.internalFilterFreq = value;
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

      % generate random phases on [0,2pi)
      phases = 0+(2*pi).*rGen.rand(1,fix(stimLen/2));
      % set zero frequency phase to 0
      phases(1) = 0;
      nZ = rem(stimLen,fix(stimLen/2));
      phases = [phases,zeros(1,nZ+1),-fliplr(phases(2:end))];

      %Generate frequency bins
      freqBinSize = obj.sampleRate / stimLen;
      frequencyVector = (0:(fix(stimLen/2))-1) .* freqBinSize;
      frequencyBand = obj.filtFreq;
      
      % Create the magnitude spectrum
      switch lower(obj.type)
        case 'flat'
          noiseSpectra = ones(1,fix(stimLen/2));
          noiseSpectra(frequencyVector >= frequencyBand(1)) = 0; 
        case 'butterlowpass'
          noiseSpectra = 1 ./(1 + (frequencyVector/frequencyBand(1)).^(2*obj.filtOrder));
        case 'gaussianlowpass'
          noiseSpectra = exp(-((frequencyVector).^2 / (2*frequencyBand(1)^2)));
        case 'gaussianbandpass'
          fcenter = mean(frequencyBand);
          noiseSpectra = exp(-((frequencyVector-fcenter).^2 / (2*diff(frequencyBand)^2)));
        case 'gaussianbandstop'
          fcenter = mean(frequencyBand);
          noiseSpectra = 1-exp(-((frequencyVector-fcenter).^2 / (2*diff(frequencyBand)^2)));
      end
      noiseSpectra(1) = 0; % set zero component to 0
      noiseSpectra = [noiseSpectra,zeros(1,nZ+1),fliplr(noiseSpectra(2:end))];
      % assign random phases and convert to time domain
      stimulus = real(ifft( ...
        noiseSpectra .*(cos(phases)+1i.*sin(phases)) ...
        ));
      
      % We need to rescale and zero-center the data considering our 
      % desired contrast (standard deviation). This will produce an RMS peak at
      % our desired contrast, such that rms(stim) = obj.contrast.
      stimulus = (stimulus - mean(stimulus)) * obj.contrast/std(stimulus);
      % invert the stimulus now.
      if obj.invert
        stimulus = -stimulus;
      end
      
      % VALIDATE RANGE ---
      % For now, let's just truncate the values, it will mess up the
      % contrast if we indeed have values beyond our bounds.
      stimulus((stimulus+obj.center) > max(obj.outputLimits)) = ...
        max(obj.outputLimits)-obj.center;
      stimulus((stimulus+obj.center) < min(obj.outputLimits)) = ...
        min(obj.outputLimits)-obj.center;
      
      
      
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
  
  methods (Static)
    
    function types = allowableTypes()
      types = { ...
        'Flat', 'ButterLowPass', ...
        'GaussianLowPass', 'GaussianBandPass', ...
        'GaussianBandStop' ...
        };
    end
    
  end
  
  
end