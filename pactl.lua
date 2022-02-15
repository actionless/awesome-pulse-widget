-- Copyright 2022 actnlzz
-- This file is part of the Awesome pipewire Widget (APW).
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


-- Simple pipewire command bindings for Lua.

local pipewire = {}


local cmd = "pactl"
local default_sink = "@DEFAULT_SINK@"

function pipewire:Create()
	local o = {}
	setmetatable(o, self)
	self.__index = self

	o.Volume = 0     -- volume of default sink
	o.Mute = false   -- state of the mute flag of the default sink

	-- retrieve current state from pipewire
	pipewire.UpdateState(o)

	return o
end

local update_pending = false

function pipewire:UpdateState(callback)
  if update_pending then return end
  update_pending = true
  awful.spawn.easy_async({cmd, "get-sink-volume", default_sink}, function(out)

    local result = true
    gears.protected_call(function()
      local value = string.gmatch(out, 'Volume:.* (%d+)%% .*')()
      self.Volume = tonumber(value) / 100
      awful.spawn.easy_async({cmd, "get-sink-mute", "@DEFAULT_SINK@"}, function(out2)

        local value2 = string.gmatch(out2, 'Mute: (.*)\n')()
        self.Mute = value2 == "yes"
        update_pending = false
        if callback then
          callback(result)
        end

      end)
    end)

  end)
end

-- Sets the volume of the default sink to vol from 0 to 1.
function pipewire:SetVolume(vol, callback)
	if vol > 1 then
		vol = 1
	end

	if vol < 0 then
		vol = 0
	end
	self.Volume = vol

	-- set…
	awful.spawn.easy_async(
		{ cmd, "set-sink-volume", default_sink, string.format("%d%%", math.floor(vol*100)) },
		function()
			-- …and update values
			self:UpdateState(callback)
		end
	)
end


-- Toggles the mute flag of the default default_sink.
function pipewire:ToggleMute(callback)
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


return pipewire
