-- @description Route Selected Takes To Stereo
-- @about Adds the Downmixer plugin to the selected takes and routes them to stereo.
-- 		Distributed under the GNU GPL v3 License. See license.txt for more information.
-- @author jkooks
-- @version 0.0.1
-- @link https://github.com/jkooks/jk_reascripts
-- @noindex

-- load APIs
package.path = reaper.GetResourcePath() .. "/Scripts/jk_reascripts/jk_api/?.lua"
local jk = require "jk_api"
local jk_fx = jk.LoadFXAPI()

function Main()
	reaper.Undo_BeginBlock()
	reaper.PreventUIRefresh(1)

	jk_fx.RouteSelectedTakeOutputs({jk_fx.ChannelsToFlag(1), jk_fx.ChannelsToFlag(2)}, true)

	reaper.PreventUIRefresh(-1)
	reaper.UpdateArrange()

	reaper.Undo_EndBlock("Route Selected Tracks to Stereo", -1)
end

Main()
