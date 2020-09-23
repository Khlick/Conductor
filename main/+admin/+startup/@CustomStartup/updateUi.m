function updateUi(obj)

userIcon = fullfile(admin.utils.getPackageRoot(),'main','lib','icons','user.png');
configIcon = fullfile(admin.utils.getPackageRoot(),'main','lib','icons','config.png');

tree = obj.uiMap('tree');

root = tree.Root;
root.Name = sprintf('%s (%s)',obj.lab,obj.institution);

% clear roots
delete(root.Children);

users = obj.userMap.keys();

% loop through and create user and setup nodes
for u = 1:obj.nUsers
  usr = users{u};
  % build user node
  uNode = uiextras.jTree.TreeNode('Parent', root, 'Name', usr);
  uNode.setIcon(userIcon);
  % loop through setups creating new setups
  setups = obj.userMap(usr);
  nSetups = numel(setups);
  for s = 1:nSetups
    setup = setups{s};
    sNode = uiextras.jTree.TreeNode('Parent', uNode, 'Name', setup);
    sNode.setIcon(configIcon);
    sNode.UserData = {usr,setup};
  end
  % expand the user nodes
  tree.expandNode(uNode);
end

% set the selected node and button status
button = obj.uiMap('button');
isOff = strcmp(button.Enable,'off');
if isempty(obj.user)
  if ~isOff
    button.Enable = 'off';
  end
  return
end
if isOff
  button.Enable = 'on';
end
parent = root.Children(strcmpi({root.Children.Name},obj.user));
tree.SelectedNodes = parent.Children(strcmpi({parent.Children.Name},obj.setup));

end
