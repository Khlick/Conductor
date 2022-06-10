function importColonyList(obj,~,~)
% prompt for getting
userDir = winqueryreg( ...
  'HKEY_CURRENT_USER',...
  ['Software\Microsoft\Windows\CurrentVersion\' ...
  'Explorer\Shell Folders'],'Personal' ...
  );
[fileName,loc] = uigetfile( ...
  {'*.csv','Comma-Separated File'}, ...
  'Select Colony List File', ...
  userDir ...
  );
if all(~fileName)
  return
end

expNames = {'Species','Genotype'};

% import the data as a table and ensure the variable names are correct.
listData = readtable(fullfile(loc,fileName),'delimiter',',','Format','%s%s');

varNames = listData.Properties.VariableNames;

if ~all(ismember(lower(expNames), lower(varNames)))
  error( ...
    'Colony List is expected to contain column headers: "Species" & "Genotype".' ...
    );
end

listData.Properties.VariableNames = expNames;

% validate no empty fields
newData = table2cell(listData);
empties = cellfun(@isempty,newData);
drops = all(empties,2);
newData(drops,:) = [];
empties(drops,:) = [];

if any(empties,'all')
  error('Table cannot have empty entries.');
end

newTable = cell2table(newData,'VariableNames',expNames);

% save the new table
saveloc = fullfile(obj.rootFolder,'main','lib','ColonyList.csv');
writetable(newTable,saveloc,'Delimiter',',');

msgbox('Colony List imported!','Success','help','modal');
end