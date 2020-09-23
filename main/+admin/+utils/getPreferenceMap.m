function map = getPreferenceMap()

pref = getpref('symphonyui','admin_startup_CustomStartup',containers.Map());
if ~pref.Count()
  error("Preferences not found.");
end
keys = pref.keys();
key = keys(contains(keys,'conductor_startup'));
map = pref(key{1});
end

