# ReaScripts
This repository contains scripts that are within my ReaPack. These scripts handle a variety of tasks and are generally organized by what they are used for. All folders aside from the *jk_api/* folder contain ReaScripts for use in Reaper.

## JK API
Included in this ReaPack are the *jk_api* modules, which are Lua modules that are designed to be an extended API for Reaper. Feel free to load the APIs into any of your scripts if you find the functions useful!

The main module, **jk_api.lua**, contains functions and variables that are commonly used in a number of different ReaScripts. The other modules, contained in the *modules/* folder, are catered to more specific scripts and are organized by what they are used for.

In order to load the main module, just add the following code to your script:
```
package.path = reaper.GetResourcePath() .. "/Scripts/jk_reascripts/jk_api/?.lua"
local jk = require "jk_api"
```

Once the main module is loaded you can use the helper functions in the "**Load**" section of **jk_api.lua** to load the other, specific modules.

# Installing
You can install this repo in ReaPack using the following index file:
```
https://github.com/jkooks/jk_reascripts/raw/main/index.xml
```