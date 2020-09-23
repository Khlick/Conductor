function id = getRigID(rigLocation)
cList = cellstr(ls(rigLocation));
cList(~contains(cList,'+')) = [];
if isempty(cList), id = ''; return; end
cList = strsplit(cList{end},'+');
id = cList{end};
end