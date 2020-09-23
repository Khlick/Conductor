function f = device2field(devices)
% convert a device to a property grid field for the background control
f = uiextras.jide.PropertyGridField.empty(0, max(1, numel(devices)));
for i = 1:numel(devices)
  d = devices{i};
  f(i) = uiextras.jide.PropertyGridField(d.name, d.background.quantity, ...
    'DisplayName', [d.name ' (' d.background.displayUnits ')']);
end
end