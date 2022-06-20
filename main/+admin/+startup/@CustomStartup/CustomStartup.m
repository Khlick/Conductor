classdef CustomStartup < appbox.Settings
  
  events
    Close
  end
  
  properties (Constant=true)
    version = 2.3
  end
  
  properties (SetAccess = private)
    institution = ''
    lab = ''
    user
    setup
  end
  
  properties (SetAccess = private, Hidden)
    view
    isFirstRun
    rootFolder
    previousMap = []
  end
  
  properties %(Access = private)
    userMap
    uiMap
  end
  
  properties (Dependent)
    nUsers
  end
  
  
  methods
    
    function obj = CustomStartup(root)
      % bind the customstartup object to symphony's startup
      [~,rootName,~] = fileparts(root);
      obj = obj@appbox.Settings(sprintf('conductor_startup_%s',rootName),'symphonyui');
      import admin.startup.CustomStartup;
      
      obj.userMap = containers.Map();
      obj.uiMap   = containers.Map();
      
      if ~isfolder(root), error('Please provide valid root directory.'); end
      obj.rootFolder = root;
      
      % check if is first run
      if obj.isFirstRun
        [obj.institution,obj.lab] = CustomStartup.promptForLab();
      end
      
      % create the UI (not visible)
      obj.createUi();
      
      % add a listener for close request
      addlistener(obj, 'Close', @(s,e)obj.onViewClosed());
      
      % detect the available users
      obj.populateUserSetups();
      
      % startup the ui
      obj.run();
    end
    
    % GET/SET for storing preferences
    function n = get.nUsers(obj)
      n = obj.userMap.Count;
    end
    
    function tf = get.isFirstRun(obj)
      tf = obj.get('isFirstRun', true);
    end
    function set.isFirstRun(obj,val)
      obj.put('isFirstRun', logical(val));
    end
    
    function name = get.lab(obj)
      name = obj.get('lab', '');
    end
    function set.lab(obj,name)
      name = matlab.lang.makeValidName(name);
      obj.put('lab', name);
    end
    
    function name = get.institution(obj)
      name = obj.get('institution', '');
    end
    function set.institution(obj,name)
      name = matlab.lang.makeValidName(name);
      obj.put('institution', name);
    end
    
    function usr = get.user(obj)
      usr = obj.get('user', '');
    end
    function set.user(obj,v)
      obj.put('user', v);
    end
    
    function stp = get.setup(obj)
      stp = obj.get('setup', '');
    end
    function set.setup(obj,v)
      obj.put('setup', v);
    end
    
    function reset(obj)
      import admin.startup.CustomStartup;
      reset@appbox.Settings(obj);
      [obj.lab,obj.institution] = CustomStartup.promptForLab();
      obj.populateUserSetups();
      obj.save();
    end
    
    function delete(obj)
      obj.completeFirstRun();
      obj.save();
      delete(obj);
    end
    
    function completeFirstRun(obj)
      obj.isFirstRun = false;
    end
    
  end
  
  methods %(Access = private)
    
    % external method files
    createUi(obj)
    updateUi(obj)
    
    createNewUsers(obj)
    populateUserSetups(obj)
    
    changeLabName(obj)
    updateUserSelection(obj,src,evt)
    locatePrevious(obj)
    
    updateColonyList(obj,src,evt)
    importColonyList(obj,src,evt)
    
    function run(obj)
      % check that we have users and run add user is none
      if ~obj.nUsers
        warning('No users found.');
        obj.createNewUsers();
      end
      obj.view.Visible = 'on';
      drawnow();
      button = findall(obj.view,'Tag', 'goButton');
      uicontrol(button);
      uiwait(obj.view);
    end
    
    function onViewClosed(obj)
      % collect user and setup information from the ui then shut it down
      uiresume(obj.view);
      delete(obj.view);
    end
    
  end
  
  methods (Static = true)
    
    [institute,lab] = promptForLab()
    success = userCreator(root)
    id = getRigID(rigLocation)
    [desc,preset] = presetBanks(userPreset,preset)
    
  end
  
  
  
end

