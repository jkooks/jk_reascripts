-- @description Downmix Selected Takes To Mono
-- @about Adds the Downmixer plugin to the selected takes and downmixes them to mono
-- 		Distributed under the GNU GPL v3 License. See license.txt for more information.
-- @author Julius Kukla
-- @version 0.0.1
-- @noindex

-- load APIs
package.path = reaper.GetResourcePath() .. "/Scripts/jk_reascripts/jk_api/?.lua"
local jk = require "jk_api"
local jk_fx = jk.LoadFXAPI()

function Main()
	reaper.Undo_BeginBlock()
	reaper.PreventUIRefresh(1)

	jk_fx.RouteSelectedTakeOutputs({jk_fx.ChannelsToFlag(1)}, true)

	reaper.PreventUIRefresh(-1)
	reaper.UpdateArrange()

	reaper.Undo_EndBlock("Downmix Selected Takes to Mono", -1)
end

Main()
