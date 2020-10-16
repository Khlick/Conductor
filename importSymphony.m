function [status] = importSymphony()
%IMPORTSYMPHONY Import Symphony to the path
import matlab.internal.apputil.AppUtil
status = 'FAILED';
infos = AppUtil.getAllAppsInDefaultLocation;
if isempty(infos)
  error( ...
    "SETUPSYMPHONY:NOTINSTALLED", ...
    "Install Symphony available from '%s'", ...
    'https://symphony-das.github.io/' ...
    );
end
appIndex = AppUtil.findAppIDs( ...
  {infos.id}, ...
  'SymphonyAPP', ...
  false ...
  );
appInfo = infos(appIndex);
% make sure Symphony is installed
if isempty(appInfo)
  error( ...
    "SETUPSYMPHONY:NOTINSTALLED", ...
    "Install Symphony available from '%s'", ...
    'https://symphony-das.github.io/' ...
    );
end

% app location string
appinstalldir = appInfo.location;
addpath(genpath(appinstalldir));
addDotNetAssemblies({'Symphony.Core.dll'});
addJavaJars( ...
  { ...
    'UIExtrasComboBox.jar', 'UIExtrasTable.jar', ...
    'UIExtrasTable2.jar', 'UIExtrasTree.jar', ...
    'UIExtrasPropertyGrid.jar' ...
  } ...
  );
% import main folder
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here,'main'));
status = 'SUCCESS';
end


function addDotNetAssemblies(asms)
for i = 1:numel(asms)
  path = which(asms{i});
  if isempty(path)
    error(['Cannot find ' asms{i} ' on the matlab path']);
  end
  NET.addAssembly(path);
end
end

function addJavaJars(jars)
for i = 1:numel(jars)
  path = which(jars{i});
  if isempty(path)
    error(['Cannot find ' jars{i} ' on the matlab path']);
  end
  if ~any(strcmpi(javaclasspath, path))
    javaaddpath(path);
  end
end
end
