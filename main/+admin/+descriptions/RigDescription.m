classdef (Abstract) RigDescription < symphonyui.core.descriptions.RigDescription
  
  properties
    rigID
  end
  
  methods
    
    function obj = RigDescription()
      rigName = regexp(class(obj),'(?=.)\w*$','match');
      obj.rigID = rigName;
      
      %Send clear screen and start logger
      obj.doReport('start');
      
      % create the rig
      obj.createRig();
      
      % report the status
      obj.doReport('end');
    end
    
    createRig(obj)
    
    
    function doReport(obj, atWhen)
      persistent curtime logdir logfile
      if isempty(curtime)
        curtime = datestr(now,'yyyymmmdd_HHMMSS');
      end
      name = strsplit(class(obj),'.');
      name = name{end};
      if any([~logfile, ~logdir,isempty(logfile),isempty(logdir)])
        logfile = regexprep(sprintf('symphonyLog_%s',curtime), '\W', '');
        logdir = fullfile( ...
          winqueryreg('HKEY_CURRENT_USER', ...
            'Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders',...
            'Personal'),...
          'Symphony2Logs' ...
          );
        if ~exist(logdir,'dir')
          [s,m,~] = mkdir(logdir);
          if ~s
            error(m);
          end
        end
      end

      switch lower(atWhen)
        case 'start'
          %clc;
          diary(fullfile(logdir,[logfile,'.txt']));
          fprintf('Starting Symphony V%s... \n',symphonyui.app.App.version);
        case 'end'
          fprintf(' ''%s'' Initialized!\n', name);
          fprintf('    Command Log located in:\n      %s\n      ''%s''\n', ...
            logdir, [logfile,'.txt']);
      end
    end
    
    
  end
  
end

