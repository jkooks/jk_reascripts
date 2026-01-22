-- @description Downmix Selected Tracks To Mono
-- @about Adds the Downmixer plugin to the selected tracks and downmixes them to mono
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

	jk_fx.RouteSelectedTrackOutputs(jk_fx.GetOutputChannelMapMono(), true)

	reaper.PreventUIRefresh(-1)
	reaper.UpdateArrange()

	reaper.Undo_EndBlock("Downmix Selected Tracks to Mono", -1)
end

Main()
