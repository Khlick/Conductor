function createBackgroundGrid(obj)
% CREATEBACKGROUNDGRID If background devices exist, create the grid
if isempty(obj.backgroundDevices), return; end
import appbox.*;
if obj.controlBlocks.isKey('background')
  % if updating, just delete the grid and remake it.
  s = obj.controlBlocks('background');
  delete(s.grid);
else
  % aesthetic: set padding to 2px
  aes = obj.aes;
  aes{find(cellfun(@(v)isequal(v,'Padding'),aes,'UniformOutput',true),1,'first')+1} = 2;
  s = struct();
  s.box = uix.BoxPanel( ...
    'Parent', obj.mainLayout, ...
    'Title', 'Background Control', ...
    aes{:} ...
    );
end
% create the grid
s.grid = uiextras.jide.PropertyGrid( ...
  s.box, ...
  'BorderType', 'none', ...
  'Callback', @obj.onSetBackground ...
  );
% store the new handles
obj.controlBlocks('background') = s;
% populate
obj.populateBackgroundGrid();
end