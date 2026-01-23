-- @description Utility API Modules
-- @about Extended API module for everyday use
-- 		Distributed under the GNU GPL v3 License. See license.txt for more information.
-- @author Julius Kukla
-- @version 0.0.0
-- @provides
-- 		[nomain] .
-- 		[nomain] $path/modules/*.lua
-- 		$path/modules/*.lua

--[[
	To import this extended API into a file, copy the below code:
	
	'''
		package.path = reaper.GetResourcePath() .. "/Scripts/jk_reascripts/jk_api/?.lua"
		local jk = require "jk_api"
	'''
	
	For any additional modules, please load them using the helper functions (see Loading section below).
]]--

local jk = {}

------------------
-- CUSTOM TYPES --
------------------

---@diagnostic disable: duplicate-doc-alias
---@alias ReaProject userdata
---@alias MediaItem userdata
---@alias MediaItem_Take userdata
---@alias MediaTrack userdata
---@alias TrackEnvelope userdata
---@alias PCM_source userdata


---------------
---- ENUMS ----
---------------

---@enum ReaperTypes
jk.ReaperTypes = {
	ReaProject 		= "ReaProject*",
	MediaItem 		= "MediaItem*",
	MediaItem_Take 	= "MediaItem_Take*",
	MediaTrack 		= "MediaTrack*",
	TrackEnvelope 	= "TrackEnvelope*",
	PCM_source 		= "PCM_source*",
}


-----------------
-- ENVIRONMENT --
-----------------

---Checks if Windows is the current operating system
---@return boolean
function jk.IsWindows()
    return reaper.GetOS():find("^Win") and true or false
end

---Checks if macOS is the current operating system
---@return boolean
function jk.IsMac()
	local system = reaper.GetOS()
    return (system:find("^OSX") or system:find("^mac")) and true or false
end


--------------
---- PATH ----
--------------

---Normalizes the file path (substitutes "\" for "/" and lowers path on Windows)
---@param path string
---@return string
function jk.NormalizePath(path)
	if type(path) ~= "string" then
		error("Cannot pass a non-string type to this function", 2)
	end

	local norm_path = path:gsub("\\", "/")

	-- only lower path if running Windows (b/c it is case insensitive)
	if jk.IsWindows() then
		norm_path = norm_path:lower()
	end

    return norm_path
end

---Joins the given path strings together and normalizes them
---@param ... string
---@return string
function jk.NormalizeJoin(...)
    local path = ""
	local count = select("#", ...)

	for i = 1, count do
		local segment = select(i, ...)

		if type(segment) ~= "string" then
			error("Cannot pass a non-string type to this function", 2)
		end

		local norm_segment = segment:gsub("\\", "/")

		path = path .. norm_segment

		-- add directory separator unless last add is a file
		if not path:find("/$") and (i < count or not norm_segment:find("%.%w+")) then
			path = path .. "/"
		end
	end

	return jk.NormalizePath(path)
end

---Checks to see if the given path exists (i.e. is a directory or a file)
---@param path string
---@return boolean
function jk.Exists(path)
    return jk.IsFile(path) or jk.IsDir(path)
end

---Checks to see if the given path is a directory.
---This function jk.can be expensive since it resets the cache when checking each directory.
---@param path string
---@return boolean
function jk.IsDir(path)
    if type(path) ~= "string" then
		error("Cannot pass a non-string type to this function", 2)
	end

    path = jk.NormalizePath(path)

    if path:find("/$") then
        path = path:sub(1, path:len() - 1)
    end

    local parent, name = path:match("(.+)/(.+)")

    -- check if there is a folder with the same name in the parent folder
    if parent and name then
        reaper.EnumerateSubdirectories(parent, -1) -- reset the cache

        local index = 0

        while true do
            local subdirectory = reaper.EnumerateSubdirectories(parent, index)

            if subdirectory == name then
                return true
            elseif not subdirectory or subdirectory == "" then
                return false
            else
                index = index + 1
            end
        end

    -- otherwise see if the folder has any children in it
    else
        reaper.EnumerateFiles(path, -1) -- reset the cache
        if reaper.EnumerateFiles(path, 0) or reaper.EnumerateSubdirectories(path, 0) then
            return true
        else
            return false
        end
    end
end

---Checks to see if the given path is a file
---@param path string
---@return boolean
function jk.IsFile(path)
    if type(path) ~= "string" then
		error("Cannot pass a non-string type to this function", 2)
	end

	return reaper.file_exists(path)
end

---Splits off the extension and the file name from the given path
---@param path string
---@return string|nil # the file name
---@return string|nil # the file extension
function jk.SplitExtension(path)
	if type(path) ~= "string" then
		error("Cannot pass a non-string type to this function", 2)
	end

	return jk.NormalizePath(path):match("(.*)(%..*)")
end

---Splits off the directory and the file from the given path
---@param path string
---@return string|nil # the directory
---@return string|nil # the file
function jk.SplitPath(path)
	if type(path) ~= "string" then
		error("Cannot pass a non-string type to this function", 2)
	end

	path = jk.NormalizePath(path)

	if path:find("/$") then
		path = path:sub(1, path:len() - 1)
	end

	return path:match("(.*/)(.*)")
end

---------------
--- LOADING ---
---------------

---@package
---Adds the modules directory to the package.path for easy package import.
---Don't call this function jk.from outside this script - meant to be run once and that is it.
function jk.AddModulesPath()
	local modules_path = jk.NormalizeJoin(
		reaper.GetResourcePath(),
		"Scripts",
		"jk_reascripts",
		"jk_api",
		"modules",
		"?.lua"
	)

	package.path = modules_path
end

---Loads the FX extension API
function jk.LoadFXAPI()
	jk.AddModulesPath()
	return require "jk_fx_api"
end

---Loads the JSON extension API
function jk.LoadJsonAPI()
	jk.AddModulesPath()
	return require "jk_json_api"
end

------------
--- MISC ---
------------

function jk.Msg(...)
	local message = ""

	for i = 1, select("#", ...) do
		message = message .. tostring(select(i, ...)) .. "\n"
	end

	reaper.ShowConsoleMsg(message)
end


---------------
-- ON IMPORT --
---------------

-- This section is contains tasks that need to run when the file is imported.
-- These tasks should be rare and only need to be run once per import.

return jk -- return the module at the end of the file for use