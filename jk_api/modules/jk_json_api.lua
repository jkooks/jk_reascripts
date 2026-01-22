-- @description JSON API for JK Scripts
-- @about Extended API module that deals with JSON files
-- @author Julius Kukla
-- @version 0.0.0
-- @noindex
-- @provides
--	[nomain] .


--[[
	Some of the code used in this file was taken from Benjamin-Dobell's Debug Adapter Protocol Wireshark Plugin
	https://github.com/glassechidna/wireshark-debug-adapter-protocol/blob/master/README.md

	As such, here is that plugin's license:

	Copyright (c) 2019 Benjamin Dobell, Glass Echidna Pty Ltd

	lunajson:
		Copyright (c) 2015-2017 Shunsuke Shimizu (grafi)

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in
	all copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
	THE SOFTWARE.
]]--


-- make sure JK API is loaded
package.path = reaper.GetResourcePath() .. "/Scripts/jk_reascripts/jk_api/?.lua"
local jk = require "jk_api"

local jk_json = {}


----------------
--- ENCODING ---
----------------

---Encodes information from the passed table as a JSON formatted string
---@param info table
---@return string
function jk_json.Encode(info)
    local dispatcher
    local depth = 0

    local string_escape_pattern = '[\0-\31"\\]'

    local string_substitues = {
        ['"'] = '\\"',
        ['\\'] = '\\\\',
        ['\b'] = '\\b',
        ['\f'] = '\\f',
        ['\n'] = '\\n',
        ['\r'] = '\\r',
        ['\t'] = '\\t',
        __index = function(_, c)
            return string.format('\\u00%02X', string.byte(c))
        end
    }

    setmetatable(string_substitues, string_substitues)

    local function GetTabs(current_depth)
        local tabs = ''
        local tab_count = 0
        while current_depth > 0 and tab_count < current_depth do
            tabs = tabs .. '\t'
            tab_count = tab_count + 1
        end

        return tabs
    end

    local function RemoveComma(json_info)
        local first_part, second_part = json_info:match('(.*),(.*)')
        return first_part .. second_part
    end

    local function Stack(value)
        local value_type
        if not value then
            value_type = 'null'
        else
            value_type = type(value)
        end

        local ending = ''
        if depth > 0 then ending = ",\n" end

        return dispatcher[value_type](value) .. ending
    end

    local function EncodeString(value)
        if value:find(string_escape_pattern) then
            value = value:gsub(string_escape_pattern, string_substitues)
        end

        return "\"" .. value .. "\""
    end

    local function EncodeNumber(value)
        return value
    end

    local function EncodeBoolean(value)
        if value then
            return "true"
        else 
            return "false"
        end
    end

    local function EncodeNil(value)
        return "null"
    end

    local function EncodeTable(value)
        if #value > 0 then
            local encoding = '[\n'
            depth = depth + 1

            local value_length = #value

            local i = 1
            if value[0] then
                i = 0
                value_length = value_length - 1
            end

            repeat
                encoding = encoding .. GetTabs(depth) .. Stack(value[i])
                i = i + 1
            until i > value_length

            encoding = RemoveComma(encoding)

            depth = depth - 1
            encoding = encoding .. GetTabs(depth) .. ']'

            return encoding

        else
            local encoding = '{\n'
            depth = depth + 1

            for key, v in pairs(value) do
                encoding = encoding .. GetTabs(depth) .. "\"" .. key .. "\"" .. " : " .. Stack(v)
            end

            encoding = RemoveComma(encoding)

            depth = depth - 1
            encoding = encoding .. GetTabs(depth) .. "}"

            return encoding
        end
    end

    dispatcher = {
        string = EncodeString,
        number = EncodeNumber,
        boolean = EncodeBoolean,
        table = EncodeTable,
        null = EncodeNil,
    }

    return Stack(info)
end

---Dumps info from tables into the file that you want to pass it.
---Doesn't close the file if a file handle is passed.
---@param info table
---@param file string|file*
function jk_json.Dump(info, file)
	local open_file, error_msg, already_open

    if type(file) == 'string' then
        open_file, error_msg = io.open(file, 'r')
		already_open = false
	else
		open_file = file
		already_open = true
    end

    if not open_file then
		error(error_msg or "Failed to open file")
    end

    local new_string = jk_json.Encode(info)
    open_file:write(new_string)

	if not already_open then
		open_file:close()
	end
end


----------------
--- ENCODING ---
----------------

---Decodes the information from a JSON formatted string into a table.
---Some of the code used in this function was taken from Benjamin-Dobell's Debug Adapter Protocol Wireshark Plugin
---https://github.com/glassechidna/wireshark-debug-adapter-protocol/blob/master/README.md
---@param info string
---@param is_zero boolean? # if the table is 0-based
---@return table
function jk_json.Decode(info, is_zero)
    local dispatcher
    local start_pos, end_pos = 1, 1

    local f_str_escapetbl = {
        ['"']  = '"',
        ['\\'] = '\\',
        ['/']  = '/',
        ['b']  = '\b',
        ['f']  = '\f',
        ['n']  = '\n',
        ['r']  = '\r',
        ['t']  = '\t',
        __index = function()
            reaper.ReaScriptError("!invalid escape sequence")
        end
    }
    setmetatable(f_str_escapetbl, f_str_escapetbl)

    --returnns the json line number that the decoder errored on
    local function GetLineNumber()
        local subbed_line, line_count = info:sub(1, end_pos):gsub('\n', '-_-') --special face symbol for fun (really because this should never be in a string)
        if not subbed_line:find("-_-$") then line_count = line_count + 1 end -- check to see if the error didn't end on a new line (line count is one off if it doesn't)

        return line_count
    end

    local function StartsWith(line, char)
        return line:find('^' .. char)
    end

    local inf = math.huge
    local f_str_surrogate_prev = 0

    local f_str_hextbl = {
        0x0, 0x1, 0x2, 0x3, 0x4, 0x5, 0x6, 0x7,
        0x8, 0x9, inf, inf, inf, inf, inf, inf,
        inf, 0xA, 0xB, 0xC, 0xD, 0xE, 0xF, inf,
        inf, inf, inf, inf, inf, inf, inf, inf,
        inf, inf, inf, inf, inf, inf, inf, inf,
        inf, inf, inf, inf, inf, inf, inf, inf,
        inf, 0xA, 0xB, 0xC, 0xD, 0xE, 0xF,
        __index = function()
            return inf
        end
    }
    setmetatable(f_str_hextbl, f_str_hextbl)

    local function SurrogateError()
        reaper.ReaScriptError("! Failed to match surrogate pair with the second byte")
    end

    local function StringSubstitute(ch, ucode)
        if ch == 'u' then
            local c1, c2, c3, c4, rest = string.byte(ucode, 1, 5)
            ucode = f_str_hextbl[c1-47] * 0x1000 +
                    f_str_hextbl[c2-47] * 0x100 +
                    f_str_hextbl[c3-47] * 0x10 +
                    f_str_hextbl[c4-47]
            if ucode ~= inf then
                if ucode < 0x80 then  -- 1byte
                    if rest then
                        return string.char(ucode, rest)
                    end
                    return string.char(ucode)
                elseif ucode < 0x800 then  -- 2bytes
                    c1 = math.floor(ucode / 0x40)
                    c2 = ucode - c1 * 0x40
                    c1 = c1 + 0xC0
                    c2 = c2 + 0x80
                    if rest then
                        return string.char(c1, c2, rest)
                    end
                    return string.char(c1, c2)
                elseif ucode < 0xD800 or 0xE000 <= ucode then  -- 3bytes
                    c1 = math.floor(ucode / 0x1000)
                    ucode = ucode - c1 * 0x1000
                    c2 = math.floor(ucode / 0x40)
                    c3 = ucode - c2 * 0x40
                    c1 = c1 + 0xE0
                    c2 = c2 + 0x80
                    c3 = c3 + 0x80
                    if rest then
                        return string.char(c1, c2, c3, rest)
                    end
                    return string.char(c1, c2, c3)
                elseif 0xD800 <= ucode and ucode < 0xDC00 then  -- surrogate pair 1st
                    if f_str_surrogate_prev == 0 then
                        f_str_surrogate_prev = ucode
                        if not rest then
                            return ''
                        end
                        SurrogateError()
                    end
                    f_str_surrogate_prev = 0
                    SurrogateError()
                else  -- surrogate pair 2nd
                    if f_str_surrogate_prev ~= 0 then
                        ucode = 0x10000 +
                                (f_str_surrogate_prev - 0xD800) * 0x400 +
                                (ucode - 0xDC00)
                        f_str_surrogate_prev = 0
                        c1 = math.floor(ucode / 0x40000)
                        ucode = ucode - c1 * 0x40000
                        c2 = math.floor(ucode / 0x1000)
                        ucode = ucode - c2 * 0x1000
                        c3 = math.floor(ucode / 0x40)
                        c4 = ucode - c3 * 0x40
                        c1 = c1 + 0xF0
                        c2 = c2 + 0x80
                        c3 = c3 + 0x80
                        c4 = c4 + 0x80
                        if rest then
                            return string.char(c1, c2, c3, c4, rest)
                        end
                        return string.char(c1, c2, c3, c4)
                    end
                    reaper.ReaScriptError("!2nd surrogate pair byte appeared without 1st")
                end
            end
            reaper.ReaScriptError("!Invalid unicode codepoint literal")
        end
        if f_str_surrogate_prev ~= 0 then
            f_str_surrogate_prev = 0
            SurrogateError()
        end
        return f_str_escapetbl[ch] .. ucode
    end

    local function Stack(line)
        local response

        if StartsWith(line, '[\"]') then
            response = dispatcher['string'](line)
        elseif StartsWith(line, '%-?[%d%.]') then
            response = dispatcher['number'](line)
        elseif StartsWith(line, '[tf]') then
            response = dispatcher['boolean'](line)
        elseif StartsWith(line, 'null') then
            response = dispatcher['Null'](line)
        elseif StartsWith(line, '[%[{]') then
            response = dispatcher['table'](line)
        else
            reaper.ReaScriptError('! Incorrectly tried to decode a sequence with no type (line #' .. GetLineNumber() .. '): ' .. line)
            response = nil
        end

        return response
    end

    local function DecodeString(line)
        local new_line = line:match('[\"](.*)[\"]')
        if not new_line then reaper.ReaScriptError('! Incorrectly tried to decode a string (line #' .. GetLineNumber() .. '): ' .. line) end

        if new_line:find('\\', 1, true) then  -- check whether a backslash exists
            -- We need to grab 4 characters after the escape char,
            -- for encoding unicode codepoint to UTF-8.
            -- As we need to ensure that every first surrogate pair byte is
            -- immediately followed by second one, we grab upto 5 characters and
            -- check the last for this purpose.
            new_line = new_line:gsub('\\(.)([^\\]?[^\\]?[^\\]?[^\\]?[^\\]?)', StringSubstitute)
            if f_str_surrogate_prev ~= 0 then
                f_str_surrogate_prev = 0
                reaper.ReaScriptError('! 1st surrogate pair byte not continued by 2nd (line #' .. GetLineNumber() .. '): ' .. line)
            end
        end

        return new_line
    end

    local function DecodeNumber(line)
        local number = tonumber(line)
        if not number then reaper.ReaScriptError('! Incorrectly tried to decode a number (line #' .. GetLineNumber() .. '): ' .. line) end

        return number
    end

    local function DecodeBoolean(line)
        if line == "true" then
            return true
        elseif line == "false" then
            return false
        else
            reaper.ReaScriptError('! Incorrectly tried to decode a boolean: (line #' .. GetLineNumber() .. '): ' .. line)
            return nil
        end
    end

    local function DecodeNil(line)
        return nil
    end

    local function DecodeTable(line)
        local decoding = {}

        if line:find('^%[') then
            local array_start, array_end, array_match = info:find('(%b[])', start_pos)

            if array_match then
                end_pos = array_start + 1

                local insert_position = 1
                if is_zero then insert_position = 0 end

                while end_pos < array_end - 1 do
                    local line_start, line_end, line_match = info:find('%s*(.-)[,\n%]]', end_pos)

					if not line_start then
						error("Failed to find the start of the line")
					end

                    --if the line is a string and it doesn't end with an end quote 
					-- (because of a comma in the string breaking the regular expression)
					-- do some more work to get the whole line
                    if line_match and StartsWith(line_match, '[\"]') and not line_match:find('\"$') then
                        local new_line = info:sub(line_start)
                        local new_start, new_end, new_match = new_line:find('(\".-\")')

                        if new_match then
                            line_match = new_match
                            line_end = line_start + new_end
                        else
                            reaper.ReaScriptError('! Can\'t find the end of a string - additional comma in string may be causing this: (line #' .. GetLineNumber() .. '): ' .. line)
                        end
                    end

                    if not line_match or line_match == '' or StartsWith(line_match, "%]") then break end

                    start_pos = line_start
                    end_pos = line_end + 1

                    decoding[insert_position] = Stack(line_match)

                    insert_position = insert_position + 1
                end

				if not array_end then
					error("Failed to match the end of the array")
				end

                start_pos = array_end

                end_pos = array_end + 3
            end
        else
            local dict_start, dict_end, dict_match = info:find('(%b{})', start_pos)

            if dict_match then
                local values_end = dict_match:find('%s*}$') --splits off any spaces before the '}' to know when the actual end of the dictionary entries are

                values_end = values_end + dict_start - 1

                end_pos = dict_start + 1

                while end_pos < values_end do
                    local line_start, line_end, key_match, line_match = info:find('%s-[\"](.-)[\"]%s-:%s*(.-),?\n', end_pos) -- does the %s* break something?
                    if not key_match or not line_match or StartsWith(line_match, "}") then break end

					if not line_start or not line_end then
						error("Failed to match the line")
					end

                    start_pos = line_start
                    end_pos = line_end

                    decoding[key_match] = Stack(line_match)
                end

				if not dict_end then
					error("Failed to match the end of the dictionary")
				end

                start_pos = dict_end
                end_pos = dict_end + 3
            end
        end

        return decoding
    end

    dispatcher = {
        string = DecodeString,
        number = DecodeNumber,
        boolean = DecodeBoolean,
        table = DecodeTable,
        null = DecodeNil,
    }

    return DecodeTable(info)
end

---Decodes the table from a JSON formatted file and returns it as a table.
---Doesn't close the file if a file handle is passed.
---@param file string|file*
---@return table
function jk_json.Load(file)
	local open_file, error_msg, already_open

    if type(file) == 'string' then
        open_file, error_msg = io.open(file, 'r')
		already_open = false
	else
		open_file = file
		already_open = true
    end

	if not open_file then
		error(error_msg or "Failed to open the file")
	end

    local file_info = open_file:read("*all")

	if not already_open then
		open_file:close()
	end

    return jk_json.Decode(file_info)
end

---------------
-- ON IMPORT --
---------------

return jk_json