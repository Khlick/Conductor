function [status] = import()
%IMPORT Conductor utils


% query registry for software
[~,paths] = system('reg query HKLM\SOFTWARE');
paths = strsplit(paths,'\n');
paths = cellfun(@(s)string(strtrim(s)),paths)';
paths(paths == "") = [];
paths = flipud(paths); % seems to install to Wow6432Node

conductorLocation = endsWith(paths,"Conductor");

if ~any(conductorLocation)
  for a = 1:numel(paths)
    [~,subpath] = system(sprintf("reg query %s", paths(a)));
    subpath = strsplit(subpath,'\n');
    subpath = cellfun(@(s)string(strtrim(s)),subpath)';
    subpath(subpath == "") = [];
    subloc = contains(subpath,"Conductor","IgnoreCase",false);
    if any(subloc)
      subKey = subpath(subloc);
      break
    end
  end
else
  subKey = paths(conductorLocation);
end

HKLM = 'HKEY_LOCAL_MACHINE';
installPath = winqueryreg( ...
  HKLM, ...
  regexprep(subKey,strcat(HKLM,"\"),""), ...
  'InstallPath' ...
  );

if isempty(installPath)
  status = false;
  return
end

addpath(genpath(fullfile(installPath,'main')));
status = true;
end

