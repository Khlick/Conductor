classdef dualStimPreview < symphonyui.core.ProtocolPreview
    % Displays a cell array of stimuli on a 2D plot. 
    
    properties
        createStimuliFcn
    end
    
    properties (Access = private)
        log
        axes
    end
    
    methods
        
        function obj = dualStimPreview(panel, createStimuliFcn)
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
          import admin.figures.dualStimPreview;
          
          yyaxis(obj.axes,'left');  
          cla(obj.axes);
          yyaxis(obj.axes,'right');
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

          if ~iscell(stimuli) || size(stimuli,1) ~= 2
              error('Stimulus cell array should be 2xN');
          end

          %plot
          labs = cell(2,size(stimuli,2));
          
          for v = 1:size(stimuli,2)
            emptyVec = cellfun(@isempty,stimuli(:,v),'unif',1);
            [x,y,l] = cellfun(...
              @(x)dualStimPreview.doGetData(x), ...
              stimuli(~emptyVec,v), 'unif',0);
            yyaxis(obj.axes,'left');
            line(x{1},y{1},'Parent',obj.axes);
            
            yyaxis(obj.axes,'right');
            line(x{2},y{2},'Parent',obj.axes);

            labs(:,v) = l(:);
          end
          ylabel(obj.axes, strjoin(unique(labs(2,:)), ', '), 'Interpreter', 'none');
          dom = obj.axes.YLim;
          ylim(obj.axes,dom + [-0.1,0.1].*diff(dom));
          yyaxis(obj.axes,'left');  
          ylabel(obj.axes, strjoin(unique(labs(1,:)), ', '), 'Interpreter', 'none');
          dom = obj.axes.YLim;
          ylim(obj.axes,dom + [-0.1,0.1].*diff(dom));
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

