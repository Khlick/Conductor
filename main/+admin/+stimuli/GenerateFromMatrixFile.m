classdef GenerateFromMatrixFile < symphonyui.core.StimulusGenerator
  %GENERATEFROMMATRIXFILE Generates arbitrary waveform (or family) from a 
  
  properties (Dependent)
    stimulusFile
    sampleRate
    units
    offset
    scale
  end
  
  properties (Hidden,SetAccess=protected)
    currentIndex = 0
  end
  
  properties (Hidden,Access=protected)
    stimulusMatrix = []
    fileName = ''
    private_sampleRate
    private_units
    private_offset = 0
    private_scale = 1
  end
  
  properties (Dependent,Hidden)
    lengths
    nStimuli
  end
  
  properties(Dependent,Hidden,Access=protected)
    nextStimulus
  end
  
  methods
    function obj = GenerateFromMatrixFile(map)
      if nargin < 1
        map = containers.Map();
      end
      obj@symphonyui.core.StimulusGenerator(map);
    end
    
    function s = generate(obj)
      % every call to generate() loops through the matrix to generate the
      % stimulus. If we've reached the end, nextStimulus() will loop back (i.e.
      % reset currentIndex to 0
      % collect the next stimulus
      data = obj.nextStimulus();
      s = obj.generateStimulus(data);
    end
    
    function tf = hasMatrix(obj)
      tf = ~isempty(obj.stimulusMatrix);
    end
    
    function set.stimulusFile(obj,fn)
      % set method to automatically load the matrix into the simulusMatrix
      % property.
      obj.resetCounter();
      if isempty(fn) || strcmpi(fn,'none')
        obj.fileName = '';
        obj.stimulusMatrix = [];
        return;
      end
      
      obj.fileName = fn;
      s = importdata(fn);
      if isstruct(s)
        % find the first double variable
        fnames = fieldnames(s);
        firstDouble = find( ...
          structfun( ...
            @(f)isa(f,'double') && (isvector(f) || ismatrix(f)), ...
            s, ...
            'UniformOutput',true ...
          ), ...
          1, ...
          'first' ...
          );
        s = s.(fnames{firstDouble});
      end
      if isvector(s)
        s = s(:); %make a column vector
      end
      obj.stimulusMatrix = s;
    end
    
    function set.sampleRate(obj,fs)
      obj.private_sampleRate = fs;
      obj.resetCounter();
    end
    
    function fs = get.sampleRate(obj)
      fs = obj.private_sampleRate;
    end
    
    function set.units(obj,units)
      obj.private_units = units;
    end
    
    function u = get.units(obj)
      u = obj.private_units;
    end
    
    function set.scale(obj,v)
      obj.private_scale = v;
    end
    
    function v = get.scale(obj)
      v = obj.private_scale;
    end
    
    function set.offset(obj,v)
      obj.private_offset = v;
    end
    
    function v = get.offset(obj)
      v = obj.private_offset;
    end
    
    function f = get.stimulusFile(obj)
      f = obj.fileName;
    end
    
    function n = get.nStimuli(obj)
      n = size(obj.stimulusMatrix,2);
    end
    
    function stimVector = get.nextStimulus(obj)
      % if we're at the end, reset the counter
      if obj.currentIndex == obj.nStimuli
        obj.resetCounter();
      end
      % increment the current index
      obj.currentIndex = obj.currentIndex + 1;
      stimVector = obj.stimulusMatrix(:,obj.currentIndex);
    end
    
    function len = get.lengths(obj)
      len = zeros(1,obj.nStimuli);
      for idx = 1:obj.nStimuli
        len(idx) = sum(~isnan(obj.stimulusMatrix(:,idx)));
      end
    end
    
    function d = getDurations(obj)
      len = obj.lengths;
      d = len./obj.sampleRate .* 1e3; %ms
    end
    
    function resetCounter(obj)
      obj.currentIndex = 0;
    end
    
    function bs = getBaselines(obj,npts)
      if nargin < 2, npts = 100; end
      
      if ~obj.hasMatrix(), error('No data available for baselines.'); end
      
      [len,~] = size(obj.stimulusMatrix);
      
      if npts > len, npts = len; end
      
      bs = mean(obj.stimulusMatrix(1:npts,:),1,'omitnan');
      
    end
    
  end
  
  methods (Access = protected)
    
    function stim = generateStimulus(obj,data)
      import Symphony.Core.*;

      % apply the scale
      data = data * obj.scale;
      % apply the offset
      data = data + obj.offset;
      % truncate to non-nan
      data(isnan(data)) = [];

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

