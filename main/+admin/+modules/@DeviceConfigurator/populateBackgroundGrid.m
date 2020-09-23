function populateBackgroundGrid(obj)
try
  fields = admin.utils.gui.device2field(obj.backgroundDevices);
catch x
  fields = uiextras.jide.PropertyGridField.empty(0, 1);
  obj.view.showError(x.message);
end

set(obj.controlBlocks('background').grid, 'Properties', fields);
end