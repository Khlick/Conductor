<img src="./main/lib/icons/main.png" alt="Conductor logo" title="Conductor" align="right" height="60" />

Conductor
=========
[![Symphony Version](https://img.shields.io/static/v1?label=Symphony%20DAS&message=2%2E6%2E3%2E1%28custom%29&color=green&style=flat)](https://github.com/Khlick/symphony-matlab)

An extension package for [Symphony-DAS](http://symphony-das.github.io/).

**In order to use this extension package, Symphony-Core libraries must be installed
and Symphony must be packaged from [this
repository](https://github.com/Khlick/symphony-matlab).**

Alternatively, contact
[Khrisgriffis at ucla.edu](mailto:khrisgriffis@ucla.edu) for a pre-packaged
`.mlappinstall` file.

## Key Features

* Manage multiple users and configurations.
* Store presets for users and configurations
* Protocol wrapper classes for standardizing new protocols
  * Includes extensive working protocols designed for slice patch and ERG rigs
  * LED protocols will populate LED device parameters based on rig
    configuration, no longer needing to identify LED device names in protocol
    classes.
* Extended device classes and device management methods
  * Specific device classes for amplifiers, LEDs, filter wheels
  * Bind motorized filter wheels to LED device configurations
* Modules
  * Note taking.
  * Enhanced background, configuration and filter wheel control in a single module.
* Reusable default figures
  * Dual stim preview: for previewing 2 stimuli on the preview panel
  * Persist epochs in mean response figures
  * Show a histogram or fourier transform of a recorded epoch.
  * Custom color figures
* Additional utilities 


## How To Use

### Installation

1) To use the latest stable version, download the release executable and follow
instructions of the installer. *Tip*: Choose an install directory located
somewhere on the main system drive, e.g. `.../User/Documents/Conductor`.

2) To use the latest development version, clone this repo into your chosen
   working directory:
   ```powershell
   cd Path/To/Your/Package/
   git clone https://github.com/sampath-lab-ucla/Conductor.git
   ```

### Setup
Run MATLAB where Symphony-DAS will be used. Navigate the Current Folder to the
install directory of Conductor. At the MATLAB command window, run
`SetupSymphony` and follow the prompts to configure Symphony for Conductor.

Create a user with a template setup type in the displayed prompt and edit the 
rig configuration files to match your specific rig. Users and user setups will
be added to the install directory.

For example, creating a user, `Khris`, with a single setup, `Calibration`, will
result in the following document structure:
```powershell
[.\Conductor]> ls
    Directory: .\Conductor


Mode                 LastWriteTime         Length Name
----                 -------------         ------ ----
d-----          1/1/2020   1:01 PM                main
d-----          1/1/2020   1:01 PM                khris
------          1/1/2020   1:01 PM           3146 SetupSymphony.m
------          1/1/2020   1:01 PM           1548 SymphonyShutdown.m
------          1/1/2020   1:01 PM           3138 SymphonyStartup.m


[.\Conductor]> ls .\khris


    Directory: .\Conductor\khris


Mode                 LastWriteTime         Length Name
----                 -------------         ------ ----
d-----          1/1/2020   1:01 PM                Calibration


[.\Conductor]> ls .\khris\Calibration\ -r


    Directory: .\Conductor\khris\Calibration


Mode                 LastWriteTime         Length Name
----                 -------------         ------ ----
d-----          1/1/2020   1:01 PM                +kg


    Directory: .\Conductor\khris\Calibration\+kg


Mode                 LastWriteTime         Length Name
----                 -------------         ------ ----
d-----          1/1/2020   1:01 PM                +epochgroups
d-----          1/1/2020   1:01 PM                +experiments
d-----          1/1/2020   1:01 PM                +protocols
d-----          1/1/2020   1:01 PM                +rigs
d-----          1/1/2020   1:01 PM                +sources

```

In general, a user file structure follows this scheme:
```
./<Conductor root>
├── User_A
│   ├── Setup_1
│   │   └── +id
│   │       ├── +epochgroups
│   │       ├── +experiments
│   │       ├── +protocols
│   │       ├── +rigs
│   │       └── +sources
│   └── <Setup_2>
│       └── ...
├── <User_B>
│   └── ...
└── [Conductor files]
```

## Contact

Report bugs and requests through github issues. All other questions can be addressed to khrisgriffis[at]ucla.edu.


## Thanks To Creators:

[Mark Cafaro](https://github.com/cafarm) for [Symphony](https://symphony-das.github.io/) and patient attentiveness
on the groups forum.

[Jan Simon](https://www.mathworks.com/matlabcentral/profile/authors/869888) for the [FilterM](https://www.mathworks.com/matlabcentral/fileexchange/32261-filterm) tool.