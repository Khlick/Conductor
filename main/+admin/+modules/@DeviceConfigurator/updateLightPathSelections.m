function updateLightPathSelections(obj,src,evt)
s = obj.controlBlocks('lightpath');
buttonMap = s.components;
filtGroup = buttonMap(src.name);
wheelId = evt.WheelName;
newTarget = evt.NewPosition;
buttonGroup = filtGroup.buttonGroups(wheelId);
% set the selection
buttonGroup.Selection = newTarget;
end