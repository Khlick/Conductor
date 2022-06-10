classdef ResponseWithFourier < admin.core.figures.DualAxes
  
  properties (Access = private)
    fourierSweep
    fourierLimits
  end
  
  methods
    
    function obj = ResponseWithFourier(device,varargin)
      % RESPONSEWITHFOURIER Plots the reponse on supplied device with a fft.
      
      % parse for frequency limits
      ip = inputParser();
      ip.KeepUnmatched = true;
      ip.addParameter( ...
        'frequencyRange', [0,50], ...
        @(x) validateattributes(x,{'numeric'},{'numel',2,'>=',0}) ...
        );
      ip.parse(varargin{:});
      
      % construct the main object
      obj = obj@admin.core.figures.DualAxes(device,ip.Unmatched);
      
      % Name the figure
      obj.figureHandle.Name = sprintf('%s Response',device.name);
      
      % initialize fourierSweep
      obj.fourierSweep = [];
      
      % set the axis limits for the fourier plot
      obj.fourierLimits = ip.Results.frequencyRange;
      
      % Set axes titles
      if ~obj.disableTitles
        obj.axesHandles(1).Title.String = sprintf('%s Response',device.name);
        obj.axesHandles(2).Title.String = 'Magnitude Spectrum';
      end
    end
    
    function handleEpoch(obj,epoch)
      handleEpoch@admin.core.figures.DualAxes(obj,epoch);
      
      % get the data from the epoch for the bound device
      [x,y,units] = obj.getResponseData(epoch);
      
      % check that we have data
      if isempty(x), return; end
      
      % compute fft
      fs = epoch.getResponse(obj.device).sampleRate.quantityInBaseUnits;
      y_fft = y(:);%hilbert(y);
      y_fft = y_fft - mean(y_fft);
      NFFT = 2^nextpow2(length(y_fft));
      NFQ  = fix(NFFT/2)+1;
      Nyq = fs/2;
      
      % calculate the frequency space
      fq = linspace(0,1,NFQ)*Nyq;
      
      % fft and scale for power spectrum in each time bin
      y_fft = 1/fs * abs(fft(y_fft,NFFT)*2).^2;
      
      % truncate to positive frequencies only.
      y_fft((NFQ+1):end,:) = [];
      
      
      if isempty(obj.sweep)
        obj.sweep = line( ...
          obj.axesHandles(1), ...
          x, y, ...
          'Color', obj.sweepColor ...
          );
        % set new units on first run
        obj.axesHandles(1).YLabel.String = sprintf('Response (%s)',units);
        obj.axesHandles(1).XLabel.String = 'Time (sec)';
        obj.axesHandles(2).XLabel.String = 'Frequency (Hz)';
        obj.axesHandles(2).YLabel.String = sprintf('Magnitude (%s^{2}/Hz)',units);
        % Construct the histogram
        obj.fourierSweep = line( ...
          obj.axesHandles(2), ...
          fq, ...
          y_fft, ...
          'lineWidth', 0.9, ...
          'color', obj.sweepColor ...
          );
      else
        set( ...
          obj.sweep, ...
          'XData', x, ...
          'YData', y ...
          );
        set( ...
          obj.fourierSweep, ...
          'XData', fq, ...
          'YData', y_fft ...
          );
      end
      % Set the fourier limits in case they have changed.
      obj.axesHandles(2).XLim = obj.fourierLimits;
    end
    
    
    % extend clear() to handle histogram
    function clear(obj)
      clear@admin.core.figures.DualAxes(obj);
      % clear will delete all axes children, so we just need to empty the sweep
      % container
      obj.fourierSweep = [];
    end
    
  end
  
  
end