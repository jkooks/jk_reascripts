-- @description Downmix Selected Tracks To Stereo
-- @about Adds the Downmixer plugin to the selected tracks and downmixes them to stereo
-- @author Julius Kukla
-- @version 0.0.0
-- @provide
--  jk_api/jk_api.lua
--  jk_api/modules/jk_fx_api.lua

-- load APIs
package.path = reaper.GetResourcePath() .. "/Scripts/jk_reascripts/jk_api/?.lua"
local jk = require "jk_api"
local jk_fx = jk.LoadFXAPI()

function Main()
	reaper.Undo_BeginBlock()
	reaper.PreventUIRefresh(1)

	jk_fx.RouteSelectedTrackOutputs(jk_fx.GetOutputChannelMapStereo(), true)

	reaper.PreventUIRefresh(-1)
	reaper.UpdateArrange()

	reaper.Undo_EndBlock("Downmix Selected Tracks to Stereo", -1)
end

Main()
