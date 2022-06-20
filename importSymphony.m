function [status,me] = importSymphony()
  %IMPORTSYMPHONY Import Symphony to the path
  import matlab.internal.apputil.AppUtil
  status = 'SUCCESS';
  me = '';
  infos = AppUtil.getAllAppsInDefaultLocation;
  if isempty(infos)
    status = 'FAILED';
    me = symphonyError();
    return
  end
  appIndex = AppUtil.findAppIDs( ...
    {infos.id}, ...
    'SymphonyAPP', ...
    false ...
    );
  appInfo = infos(appIndex);
  % make sure Symphony is installed
  if isempty(appInfo)
    status = 'FAILED';
    me = symphonyError();
    return
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
end

%% Helpers
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

  function except = symphonyError()
    except = MException( ...
      "SETUPSYMPHONY:NOTINSTALLED", ...
      "Install Symphony available from the %s.", ...
      '<a href="https://github.com/Khlick/symphony-matlab/releases/tag/2.6.3.1">development github</a>' ...
      );
  end
end
