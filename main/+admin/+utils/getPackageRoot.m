function root = getPackageRoot()
%GETPACKAGEROOT Get the full path of the custom package


root = fileparts(regexprep(mfilename('fullpath'), '\\\+.*$', ''));

end

