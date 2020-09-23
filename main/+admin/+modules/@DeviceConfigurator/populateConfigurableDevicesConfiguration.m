function populateConfigurableDevicesConfiguration(obj)
% POPULATEConfigurableDevicesCONFIGURATION In a single proptery grid table, create a
% category for each device name.
import appbox.*;
devs = obj.configurableDevices;
n = numel(devs);
s = obj.controlBlocks('ConfigurableDevices');
% build the components
b = struct();
b.layout = cell(1,n);

% create the grid
b.grid = cell(1,n);

% Loop through and collect property descriptors for each device. Then set
% the field.Category to the device name. Each device will get its own VBox
% container to store the configurations for that device. Otherwise the
% java based methods won't pass the correct event data for each category.
% collect the grid counts for setting heights
ngrids = zeros(1,n);
for L = 1:n
  thisLayout = uix.VBox( ...
    'Parent', s.adjustable, ...
    'Spacing', 0, ...
    'Padding', 0 ...
    );
  thisGrid = uiextras.jide.PropertyGrid( ...
    thisLayout, ...
    'BorderType', 'none' ...
    );
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
  thisGrid.Properties = fields(:);% column
  thisGrid.Callback = @obj.onDeviceConfigured;
  b.layout{L} = thisLayout;
  b.grid{L} = thisGrid;
  ngrids(L) = numel(fields);
end

% set the heights based on the number of fields
s.adjustable.Heights = -(ngrids+1);

% store for update
s.components('layout') = b.layout;
s.components('grid') = b.grid;
obj.controlBlocks('ConfigurableDevices') = s;
end