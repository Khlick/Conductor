function updateConfigurableDevicesConfigurations(obj)
s = obj.controlBlocks('ConfigurableDevices');
grid = s.components('grid');
devs = obj.configurableDevices;
n = numel(devs);
% Loop through and collect property descriptors for each device. Then set
% the field.Category to the device name.
% collect the grid counts for setting heights
ngrids = zeros(1,n);
for L = 1:n
  thisGrid = grid{L};
  this = devs{L};
  name = this.name;
  % get configurable descriptions
  configs = this.getConfigurationSettingDescriptors();
  if isempty(configs), continue; end
  try
    fields = admin.utils.gui.description2field(configs);
  catch x
    fields = uiextras.jide.PropertyGridField.empty(0, 1);
    obj.view.showError(x.message);
  end
  [fields.Category] = deal(name);
  % update the fields
  thisGrid.Properties = fields(:);% column
  ngrids(L) = numel(fields);
end
% set the heights
s.adjustable.Heights = -(ngrids+1);

end