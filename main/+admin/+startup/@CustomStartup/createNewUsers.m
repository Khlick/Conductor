function createNewUsers(obj)
% prompt to create a user name and a package handle
% create a basic file structure (based on a simple template)
import admin.startup.CustomStartup;


hasNewUsers = CustomStartup.userCreator(obj.rootFolder);

if ~hasNewUsers && ~obj.nUsers
  error("No user directories.");
end


obj.populateUserSetups();


end

