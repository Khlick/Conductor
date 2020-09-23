function updateLightPathConfiguration(obj)
% UPDATELIGHTPATHCONFIGURATION
%   Here we have to delete the lightpath control blocks and then
%   repopulate them.
s = obj.controlBlocks('lightpath');
keys = s.components.keys();
for k = 1:numel(keys)
  this = s.components(keys{k});
  iK = this.buttonGroups.keys();
  for jK = 1:numel(iK)
    delete(this.buttonGroups(iK{jK}));
  end
  cellfun(@delete,this.internal,'UniformOutput',false);
  delete(this.layout);
end
obj.populateLightPathConfiguration();
end