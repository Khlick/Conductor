function gatherPreviousSettings(obj)
prev = getpref('admin');
if isempty(prev), return; end
fn = fieldnames(prev);
startupIdx = find(contains(fn,'startup'),1,'first');
prev = prev.(fn{startupIdx});%map object
map = prev(fn{startupIdx});
obj.previousMap = map;
% remove the old preferences
rmpref('admin');
end