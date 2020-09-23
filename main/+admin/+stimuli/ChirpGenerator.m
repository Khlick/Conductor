classdef ChirpGenerator < symphonyui.core.StimulusGenerator
  %Generate a chirp
  properties
    preTime     % Leading duration (ms)
    stimTime    % Sine wave duration (ms)
    tailTime    % Trailing duration (ms)
    stimDelay   % Leadin time at oscillation center
    followDelay % Trailing time at oscillation center
    amplitude   % Chirp amplitude (units)
    phase = 0   % Phase offset (radians)
    center      % oscillation center
    sampleRate  % Sample rate of generated stimulus (Hz)
    units       % Units of generated stimulus
    quadMode = 'concave' % "convex" or "concave" for quadratic type
    isIncreasing = true % set to false to reverse frequency
    symmetric = false % Will reflect at stimTime/2 (notImplements: july 2020)
  end
  properties (Dependent)
    freqStart   % Initial frequency (Hz)
    freqStop    % Final frequency (Hz)
    method      % "Linear", "Quadratic" or "Logarithmic"
  end
  properties (Dependent,Hidden)
    order
    beta
    timeTarget % time at which we want to reach freqStop
  end
  
  properties (Access = private)
    freqStart_ = 0  % Initial frequency (Hz)
    freqStop_  % Initial frequency (Hz)
    method_ = 'Linear'
  end
  
  methods
    
    function obj = ChirpGenerator(map)
      if nargin < 1
        map = containers.Map();
      end
      obj@symphonyui.core.StimulusGenerator(map);
    end
    
  end
  
  methods (Access = protected)
    
    function s = generateStimulus(obj)
      import Symphony.Core.Measurement;
      import Symphony.Core.OutputData;
      import Symphony.Core.RenderedStimulus;
      
      timeToPts = @(t)(round(t / 1e3 * obj.sampleRate));
      
      prePts = timeToPts(obj.preTime);
      stepPts = timeToPts(obj.stimDelay);
      stimPts = timeToPts(obj.stimTime);
      followPts = timeToPts(obj.followDelay);
      tailPts = timeToPts(obj.tailTime);
      
      data = [...
        zeros(1,prePts), ...
        ones(1, stepPts + stimPts + followPts) .* obj.center, ...
        zeros(1,tailPts) ...
        ];
      
      time = (0:(stimPts-1)) ./ obj.sampleRate;
      
      theChirp = obj.computeChirp(time);
      
      data(prePts + stepPts + (1:stimPts)) = theChirp;
      
      parameters = obj.dictionaryFromMap(obj.propertyMap);
      measurements = Measurement.FromArray(data, obj.units);
      rate = Measurement(obj.sampleRate, 'Hz');
      output = OutputData(measurements, rate);
      
      cobj = RenderedStimulus(class(obj), parameters, output);
      s = symphonyui.core.Stimulus(cobj);
    end
    
  end
  
  methods
    
    function p = get.order(obj)
      switch obj.method
        case 'Quadtratic'
          p = 2;
        otherwise
          p = 1;
      end
    end
    
    function t = get.timeTarget(obj)
      t = obj.stimTime * 1e-3; %ms -> sec
      if obj.symmetric
        t = t/2;
      end
    end
    
    function b = get.beta(obj)
      if isempty(obj.stimTime), b=[]; return; end
      b = (obj.freqStop - obj.freqStart).*(obj.timeTarget.^(-obj.order));
    end
    
    function set.method(obj,t)
      t = validatestring(t,{'Linear', 'Logarithmic', 'Quadratic'});
      if strcmp(t,'Logarithmic') && ~obj.freqStart_
        % freq start cannot be 0
        msg = ['Frequency start cannot be zero when method is "Logarithmic".', ...
          ' Set freqStart >= 1e-6 before setting method.'];
        error(msg);
      end
      % set the private value
      obj.method_ = t;
    end
    
    function m = get.method(obj)
      m = obj.method_;
    end
    
    function set.quadMode(obj,m)
      m = validatestring(m,{'convex','concave'});
      obj.quadMode = m;
    end
    
    function set.freqStart(obj,f0)
      if strcmp(obj.method,'Logarithmic') && f0 < 1e-6
        % freq start cannot be 0
        msg = ['Frequency start cannot be < 1e-6 when method is "Logarithmic".', ...
          ' Set freqStart >= 1e-6.'];
        error(msg);
      end
      obj.freqStart_ = f0;
    end
    function f0 = get.freqStart(obj)
      f0 = obj.freqStart_;
    end
    
    function set.freqStop(obj,f1)
      f0 = obj.freqStart;
      if ~isempty(f0) && (f1 <= f0)
        error('Set freqStop > freqStart. To reverse direction use isIncreasing = 0.');
      end
      obj.freqStop_ = f1;
    end
    function f1 = get.freqStop(obj)
      f1 = obj.freqStop_;
    end
  end
  
  methods (Access = private)
    
    function theChirp = computeChirp(obj,time)
      if obj.symmetric
        time = time - median(time);
        if obj.isIncreasing
          % if increasing, start at 0 rise and then fall to 0
          % note that if numel(time) is odd, then we will start at 0 and end at
          % 1/fs.
          time = circshift(time,-sum(time > 0));
          if mod(length(time),2)
            warning('Chirp has odd number of points but is increasing symmetric, consider using even length.');
          end
        end
      end
        
      switch obj.method
        case 'Linear'
          theChirp = obj.amplitude/2 .* ...
            obj.chirpFcn(time,obj.freqStart,obj.beta,obj.order,obj.phase) + ...
            obj.center;
        case 'Logarithmic'
          f_ratio = obj.freqStop / obj.freqStart;
          tempVector = repmat( ...
              f_ratio, ...
              size(time,1), size(time,2) ...
            ) .^( time./obj.timeTarget );
          instPhi = ...
            ( ...
              obj.timeTarget / log(f_ratio) * obj.freqStart ...
            ) * ...
            ( ...
              tempVector - 1 ...
            );
          theChirp = obj.amplitude/2 .* ...
            cos( 2*pi * ( instPhi + obj.phase/(2*pi) ) ) + ...
            obj.center;
        case 'Quadratic'
          if ( ...
              ( obj.isIncreasing && strcmp(obj.quadMode, 'convex') ) ...
              || ...
              (~obj.isIncreasing && strcmp(obj.quadMode,'concave') ) ...
              )
            time = fliplr(-time);
            f0temp = obj.freqStop;
            f1temp= obj.freqStart;
          else
            f0temp = obj.freqStart;
            f1temp= obj.freqStop;
          end
          b = (f1temp - f0temp) .* ( obj.timeTarget.^(-obj.order) );
          theChirp = obj.amplitude/2 .* ...
            obj.chirpFcn(time,f0temp,b,obj.order,obj.phase) + ...
            obj.center;
      end
      
      if ~obj.symmetric && ~obj.isIncreasing && ~strcmp(obj.method,'Quadratic')
        theChirp = fliplr(theChirp);
      end
      
    end
    
  end
  
  methods (Static)
    
    function sig = chirpFcn(t,f0,beta,order,phi)
      % General function to compute beta and y for both
      % linear and quadratic modes.
      sig = cos( ...
        2 * pi * ...
        ( ...
          beta ./ (1+order) *( t.^(1+order) ) + f0 * t + phi/(2*pi) ...
        ) ...
        );
    end
    
    
  end
  
end

