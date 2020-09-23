classdef inputOutputSimulator < symphonyui.core.Simulation
  
  methods
    
    function inputMap = run(obj, daq, outputMap, timeStep)
      inputMap = containers.Map();
      
      % Loop through all input streams.
      inputStreams = daq.getInputStreams();
      for i = 1:numel(inputStreams)
        inStream = inputStreams{i};
        ioName = inStream.name;
        inData = [];
        
        if ~inStream.active
          % We don't care to process inactive input streams (i.e. channels without devices).
          continue;
        end
        
        % If there is a corresponding output data, make it into input data.
        outData = [];
        if outputMap.isKey(strrep(ioName, 'ai', 'ao'))
          outData = outputMap(strrep(ioName, 'ai', 'ao'));
        elseif outputMap.isKey(strrep(ioName, 'diport', 'doport'))
          outData = outputMap(strrep(ioName, 'diport', 'doport'));
        end
        if ~isempty(outData)
          [quantities, units] = outData.getData();
          rate = outData.sampleRate;
          [target,~] = admin.utils.getPrefixFromUnits(units);
          ex = admin.utils.prefixToExponent(target);
          inData = symphonyui.core.InputData(quantities+randn(size(quantities))*10^(ex-3), units, rate);
        end
        
        % If there is no corresponding output data, simulate noise.
        if isempty(inData)
          rate = inStream.sampleRate;
          nsamples = seconds(timeStep) * rate.quantityInBaseUnits;
          if strncmp(ioName, 'diport', 6)
            % Digital noise.
            quantities = randi(2^16-1, 1, nsamples);
          else
            % Analog noise.
            quantities = rand(1, nsamples) - 0.5;
            if strcmp(ioName,'ai7')              
              %temp monitor
              quantities = quantities + 3.7;% add 3.7V to it
            end
          end
          units = inStream.measurementConversionTarget;
          inData = symphonyui.core.InputData(quantities, units, rate);
        end
        
        inputMap(ioName) = inData;
      end
    end
    
    
  end
  
end
