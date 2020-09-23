function updateUserSelection(obj,src,evt)
      
node = evt.Nodes;
if strcmp(node.Name,obj.lab)

  % root was selected, force to first user/setup
  uNode = node.Children(1);
  sNode = uNode.Children(1);
  src.SelectedNodes = sNode;
  obj.user = sNode.UserData{1};
  obj.setup = sNode.UserData{2};

elseif isempty(node.UserData)

  % user was selected but not a rig
  obj.user = node.Name;
  sNode = node.Children(1);
  % set the setup to the first setup for the user
  obj.setup = sNode.Name;

else

  ud = node.UserData;
  obj.user = ud{1};
  obj.setup = ud{2};
  
end
% now that a selection was made, we can enable the button
button = obj.uiMap('button');
if strcmp(button.Enable,'off')
  button.Enable = 'on';
end
end