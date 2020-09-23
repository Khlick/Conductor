function changeLabName(obj)
import admin.startup.CustomStartup;
obj.view.Visible = 'off';
[obj.institution,obj.lab] = CustomStartup.promptForLab();

% update the ui
obj.updateUi();

obj.view.Visible = 'on';
figure(obj.view);
end