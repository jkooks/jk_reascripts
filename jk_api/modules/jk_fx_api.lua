-- @description FX API for JK Scripts
-- @about Extended API module that deals with FXs
-- Distributed under the GNU GPL v3 License. See license.txt for more information.
-- @author Kukla
-- @version 0.0.0
-- @noindex
-- @provides
--	[nomain] .

-- make sure JK API is loaded
package.path = reaper.GetResourcePath() .. "/Scripts/jk_reascripts/jk_api/?.lua"
local jk = require "jk_api"

local jk_fx = {}


------------------
-- CUSTOM TYPES --
------------------

---@alias ChannelMap table<number, number> alias for channel output routing - key is 1-based


---------------
-- DOWNMIXER --
---------------

-- names of the downmixer plugin
jk_fx.DOWNMIXER_FX_NAMES = {
	"JS: Channel Mapper-Downmixer (Cockos)",
    "utility/channel_mapper",
    "JS: Channel Mapper-Downmixer (Cockos) [utility\\channel_mapper]",
}

---Adds the downmixing plugin and returns the index of the added instance
---@param pointer MediaItem_Take|MediaTrack
---@return number
function jk_fx.AddDownmixer(pointer)
	local is_track

	if reaper.ValidatePtr(pointer, jk.ReaperTypes.MediaTrack) then
		is_track = true
	elseif reaper.ValidatePtr(pointer, jk.ReaperTypes.MediaItem_Take) then
		is_track = false
	else
		error("Must supply a valid MediaTrack or MediaItem_Take pointer", 2)
	end

	if is_track then
		return reaper.TrackFX_AddByName(pointer, jk_fx.DOWNMIXER_FX_NAMES[1], false, -1)
	else
		return reaper.TakeFX_AddByName(pointer, jk_fx.DOWNMIXER_FX_NAMES[1], -1)
	end
end

---Combine channels into a single flag
---@param ... number channel numbers that you want to set the output to
---@return number
function jk_fx.ChannelsToFlag(...)
	local flag = 0

	for i = 1, select("#", ...) do
		flag = flag | jk_fx.GetChannelLowBit(select(i, ...))
	end

	return flag
end

---Gets the 1-based channel number of the low 32 bits value
---@param channel number
---@return number
function jk_fx.GetChannelLowBit(channel)
	if channel <= 0 then
		error("Must supply a value of greater than or equal to 1", 2)
	end

	-- channel 1=1, channel 2=2, channel 3=4, channel 4=8, channel 5=16, etc
	return 2^(channel-1)
end

---Returns the 0-based index of the Downmixer plugin instance.
---Will return -1 if no instance exists.
---@param pointer MediaItem_Take | MediaTrack
---@return number
function jk_fx.GetDownmixerFXIndex(pointer)
	local get_count

	if reaper.ValidatePtr(pointer, jk.ReaperTypes.MediaTrack) then
		get_count = reaper.TrackFX_GetCount
	elseif reaper.ValidatePtr(pointer, jk.ReaperTypes.MediaItem_Take) then
		get_count = reaper.TakeFX_GetCount
	else
		error("Must supply a valid MediaTrack or MediaItem_Take pointer", 2)
	end

	for i = 0, get_count(pointer) - 1 do
		if jk_fx.IsDownmixerFX(pointer, i) then
			return i
		end
	end

	return -1
end

---Get a mono I/O routing map
---@return ChannelMap
function jk_fx.GetOutputChannelMapMono()
	return {jk_fx.ChannelsToFlag(1)}
end

---Get a stereo I/O routing map
---@return ChannelMap
function jk_fx.GetOutputChannelMapStereo()
	return {jk_fx.ChannelsToFlag(1), jk_fx.ChannelsToFlag(2)}
end

---Checks to see if an instance of the Downmixer plugin exists on the track or take
---@param pointer MediaItem_Take|MediaTrack
---@return boolean
function jk_fx.HasDownmixer(pointer)
	return jk_fx.GetDownmixerFXIndex(pointer) >= 0
end

---Checks if the FX at that index is an instance of the Downmixer plugin
---@param pointer MediaItem_Take|MediaTrack
---@param fx_index number
---@return boolean
function jk_fx.IsDownmixerFX(pointer, fx_index)
	local retval, fx_name

	if reaper.ValidatePtr(pointer, jk.ReaperTypes.MediaTrack) then
		retval, fx_name = reaper.TrackFX_GetFXName(pointer, fx_index)
	elseif reaper.ValidatePtr(pointer, jk.ReaperTypes.MediaItem_Take) then
		retval, fx_name = reaper.TakeFX_GetFXName(pointer, fx_index)
	else
		error("Must supply a valid MediaTrack or MediaItem_Take pointer", 2)
	end

	if not retval then
		return false
	else
		for i, name in ipairs(jk_fx.DOWNMIXER_FX_NAMES) do
			if name == fx_name then
				return true
			end
		end
	end

	return false
end

---Routes the Downmixer plugin's pins to the mappings I/O
---@param pointer MediaItem_Take|MediaTrack
---@param fx_index number
---@param mapping ChannelMap
---@param clear_missing boolean? # if missing channels in the channel map should be routed to no output - default is false
function jk_fx.RouteDownmixer(pointer, fx_index, mapping, clear_missing)
	if not jk_fx.IsDownmixerFX(pointer, fx_index) then
		error("The Downmixer plugin is not at the given FX index", 2)
	end

	local io_func
	local set_func

	if reaper.ValidatePtr(pointer, jk.ReaperTypes.MediaTrack) then
		io_func = reaper.TrackFX_GetIOSize
		set_func = reaper.TrackFX_SetPinMappings
	elseif reaper.ValidatePtr(pointer, jk.ReaperTypes.MediaItem_Take) then
		io_func = reaper.TakeFX_GetIOSize
		set_func = reaper.TakeFX_SetPinMappings
	else
		error("Must supply a valid MediaTrack or MediaItem_Take pointer", 2)
	end

	local _, _, count = io_func(pointer, fx_index) -- get output count

	for channel = 1, count do
		local flag = mapping[channel] -- gets nil if channel isn't in map

		if flag == nil and clear_missing then
			flag = 0
		end

		if flag >= 0 then

			-- 1 == output channels
			-- channel-1 == 0-based bin
			-- unsure of last arg
			set_func(pointer, fx_index, 1, channel - 1, flag, 0)
		end
	end
end

---Routes the selected takes to the output map
---@param mapping ChannelMap
---@param clear_missing boolean? # if missing channels in the channel map should be routed to no output - default is false
function jk_fx.RouteSelectedTakeOutputs(mapping, clear_missing)
	for i = 0, reaper.CountSelectedMediaItems(0) - 1 do
		local item = reaper.GetSelectedMediaItem(0, i)
		local take = reaper.GetActiveTake(item)

		if take then
			local index = jk_fx.GetDownmixerFXIndex(take)

			if index == -1 then
				index = jk_fx.AddDownmixer(take)
			end

			jk_fx.RouteDownmixer(take, index, mapping, clear_missing)
		end
	end
end

---Routes the selected tracks to the output map
---@param mapping ChannelMap
---@param clear_missing boolean? # if missing channels in the channel map should be routed to no output - default is false
function jk_fx.RouteSelectedTrackOutputs(mapping, clear_missing)
	for i = 0, reaper.CountSelectedTracks(0) - 1 do
		local track = reaper.GetSelectedTrack(0, i)

		local index = jk_fx.GetDownmixerFXIndex(track)

		if index == -1 then
			index = jk_fx.AddDownmixer(track)
		end

		jk_fx.RouteDownmixer(track, index, mapping, clear_missing)
	end
end


---------------
-- ON IMPORT --
---------------

return jk_fx