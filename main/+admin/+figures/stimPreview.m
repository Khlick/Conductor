classdef stimPreview < symphonyui.core.ProtocolPreview
    % Displays a cell array of stimuli on a 2D plot. 
    
    properties
        createStimuliFcn
    end
    
    properties (Access = private)
        log
        axes
    end
    
    methods
        
        function obj = stimPreview(panel, createStimuliFcn)
            % Constructs a StimuliPreview on the given panel with the given stimuli. createStimuliFcn should be a
            % callback function that creates a cell array of stimuli.
            
            obj@symphonyui.core.ProtocolPreview(panel);
            obj.createStimuliFcn = createStimuliFcn;
            obj.log = log4m.LogManager.getLogger(class(obj));
            obj.createUi();
        end
        
        function createUi(obj)
            obj.axes = axes( ...
                'Parent', obj.panel, ...
                'FontName', get(obj.panel, 'DefaultUicontrolFontName'), ...
                'FontSize', get(obj.panel, 'DefaultUicontrolFontSize'), ...
                'XTickMode', 'auto'); %#ok<CPROP>
            xlabel(obj.axes, 'sec');
            obj.update();
        end
        
        function update(obj)
          import admin.figures.*;
            cla(obj.axes);
            
            try
                stimuli = obj.createStimuliFcn();
            catch x
                cla(obj.axes);
                text(0.5, 0.5, 'Cannot create stimuli', ...
                    'Parent', obj.axes, ...
                    'FontName', get(obj.panel, 'DefaultUicontrolFontName'), ...
                    'FontSize', get(obj.panel, 'DefaultUicontrolFontSize'), ...
                    'HorizontalAlignment', 'center', ...
                    'Units', 'normalized');
                obj.log.debug(x.message, x);
                return;
            end
            
            if ~iscell(stimuli) && isa(stimuli, 'symphonyui.core.Stimulus')
                stimuli = {stimuli};
            end
            %plot
            labs = cell(0);
            cols = get(obj.axes,'colororder');
            if size(stimuli,2) > size(cols,1)
              cols = repmat(cols,ceil(size(stimuli,2)/size(cols,1)),1);
            end
            for v = 1:size(stimuli,2)
              emptyVec = cellfun(@isempty,stimuli(:,v),'unif',1);
              [x,y,l] = cellfun(...
                @(x)admin.figures.stimPreview.doGetData(x), ...
                stimuli(~emptyVec,v), 'unif',0);
              
              x = cell2mat(x');
              y = cell2mat(y');
              
              line(x,y,'Parent',obj.axes, 'Color', cols(v,:));
              obj.axes.NextPlot = 'add';
              labs(end + (1:length(l))) = l;
            end
            ylabel(obj.axes, strjoin(unique(labs), ', '), 'Interpreter', 'none');
            obj.axes.NextPlot = 'replace';
        end
        
    end
    
    methods (Static)
      
        function [t,r,u] = doGetData(stim)
          [r,u] = stim.getData();
          fs = stim.sampleRate.quantityInBaseUnits;
          t = (1:numel(r))' ./ fs;
          r = r(:);
          
        end
        
    end
    
end

