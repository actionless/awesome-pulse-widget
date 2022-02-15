-- Copyright 2013 mokasin
-- This file is part of the Awesome Pulseaudio Widget (APW).
--
-- APW is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- APW is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with APW. If not, see <http://www.gnu.org/licenses/>.

local awful = require('awful')
local gears = require('gears')


-- Simple pulseaudio command bindings for Lua.

local pulseaudio = {}


local cmd = "pacmd"
local default_sink = ""

function pulseaudio:Create()
	local o = {}
	setmetatable(o, self)
	self.__index = self

	o.Volume = 0     -- volume of default sink
	o.Mute = false   -- state of the mute flag of the default sink

	-- retrieve current state from pulseaudio
	pulseaudio.UpdateState(o)

	return o
end

local update_pending = false

function pulseaudio:UpdateState(callback)
	if update_pending then return end
	update_pending = true
	awful.spawn.easy_async({cmd, "dump"}, function(out)
		local result = true
		gears.protected_call(function()
			-- find default sink
			default_sink = string.match(out, "set%-default%-sink ([^\n]+)")
			if default_sink == nil then
				default_sink = ""
				result = false
				return
			end

			-- retrieve volume of default sink
			for sink, value in string.gmatch(out, "set%-sink%-volume ([^%s]+) (0x%x+)") do
				if sink == default_sink then
					self.Volume = tonumber(value) / 0x10000
				end
			end

			-- retrieve mute state of default sink
			for sink, value in string.gmatch(out, "set%-sink%-mute ([^%s]+) (%a+)") do
				if sink == default_sink then
					self.Mute = value == "yes"
				end
			end
		end)

		update_pending = false
		if callback then
			callback(result)
		end
	end)
end

-- Sets the volume of the default sink to vol from 0 to 1.
function pulseaudio:SetVolume(vol, callback)
	if vol > 1 then
		vol = 1
	end

	if vol < 0 then
		vol = 0
	end
	self.Volume = vol

	vol = vol * 0x10000
	-- set…
	awful.spawn.easy_async(
		{ cmd, "set-sink-volume", default_sink, string.format("0x%x", math.floor(vol)) },
		function()
			-- …and update values
			self:UpdateState(callback)
		end
	)
end


-- Toggles the mute flag of the default default_sink.
function pulseaudio:ToggleMute(callback)
	local mute_cmd
	if self.Mute then
		mute_cmd = { cmd, "set-sink-mute", default_sink, "0"}
	else
		mute_cmd = { cmd, "set-sink-mute", default_sink, "1"}
	end
	awful.spawn.easy_async(
		mute_cmd,
		function()
			-- …and update values
			self:UpdateState(callback)
		end
	)
end


return pulseaudio

