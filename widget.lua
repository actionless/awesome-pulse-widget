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

local awful = require("awful")
local wibox = require("wibox")
local beautiful = require("beautiful")
local spawn_with_shell = awful.util.spawn_with_shell or awful.spawn.with_shell

local pacmd = require("apw.pacmd")
local pactl = require("apw.pactl")
local backends = {
  pacmd = pacmd,
  pactl = pactl,
}
local backend
local pulseBar = wibox.widget.progressbar()

-- Configuration variables
local width         = 40        -- width in pixels of progressbar
local margin_right  = 0         -- right margin in pixels of progressbar
local margin_left   = 0         -- left margin in pixels of progressbar
local margin_top    = 0         -- top margin in pixels of progressbar
local margin_bottom = 0         -- bottom margin in pixels of progressbar
local step          = 0.05      -- stepsize for volume change (ranges from 0 to 1)
local color         = '#698f1e' -- foreground color of progessbar
local color_bg      = '#33450f' -- background color
local color_mute    = '#be2a15' -- foreground color when muted
local color_bg_mute = '#532a15' -- background color when muted
local mixer         = 'pavucontrol' -- mixer command
local show_text     = false     -- show percentages on progressbar
local text_color    = '#fff' -- color of text
pulseBar.forced_width = width
pulseBar.step = step
local default_backend = 'pulseaudio'
-- End of configuration

-- default colors overridden by Beautiful theme
color = beautiful.apw_fg_color or color
color_bg = beautiful.apw_bg_color or color_bg
color_mute = beautiful.apw_mute_fg_color or color_mute
color_bg_mute = beautiful.apw_mute_bg_color or color_bg_mute
show_text = beautiful.apw_show_text or show_text
text_color = beautiful.apw_text_colot or text_color



local pulseWidget

local pulseText
if show_text then
	pulseText = wibox.widget.textbox()
	pulseText:set_align("center")
	pulseWidget = wibox.container.margin(
		wibox.widget {
			pulseBar,
			pulseText,
			layout = wibox.layout.stack
		},
		margin_right, margin_left,
		margin_top, margin_bottom
	)
else
	pulseWidget = wibox.container.margin(
		pulseBar,
		margin_right, margin_left,
		margin_top, margin_bottom
	)
end

function pulseWidget.setColor(mute)
	if mute then
		pulseBar:set_color(color_mute)
		pulseBar:set_background_color(color_bg_mute)
	else
		pulseBar:set_color(color)
		pulseBar:set_background_color(color_bg)
	end
end

function pulseWidget._redraw()
	pulseBar:set_value(backend.Volume)
	pulseWidget.setColor(backend.Mute)
	if show_text then
		pulseText:set_markup('<span color="'..text_color..'">'..math.ceil(backend.Volume*100)..'%</span>')
	end
end

function pulseWidget.SetMixer(command)
	mixer = command
end

function pulseWidget.Up(callback)
	backend:SetVolume(backend.Volume + pulseBar.step, function()
		pulseWidget._redraw()
		if callback then
			callback()
		end
	end)
end

function pulseWidget.Down(callback)
	backend:SetVolume(backend.Volume - pulseBar.step, function()
		pulseWidget._redraw()
		if callback then
			callback()
		end
	end)
end

function pulseWidget.ToggleMute()
	backend:ToggleMute(pulseWidget._redraw)
end

function pulseWidget:_checkInit(args, ...)
  if not pulseWidget.backend then
    args = args or {}
    backend = backends[args.backend or default_backend]:Create()
    pulseWidget.backend = backend
    pulseWidget.pulseBar = pulseBar
    pulseWidget._redraw()
  end
  return pulseWidget
end

function pulseWidget.Update(callback)
  pulseWidget:_checkInit()
  backend:UpdateState(function()
    if callback then
      callback()
    end
    pulseWidget._redraw()
  end)
end

function pulseWidget.LaunchMixer()
	spawn_with_shell( mixer )
end


-- register mouse button actions
local is_already_scrolling = false
pulseWidget:buttons(awful.util.table.join(
		awful.button({ }, 1, pulseWidget.ToggleMute),
		awful.button({ }, 3, pulseWidget.LaunchMixer),
		awful.button({ }, 4, function()
			if is_already_scrolling then return end
			is_already_scrolling = true
			pulseWidget.Up(function() is_already_scrolling = false end)
		end),
		awful.button({ }, 5, function()
			if is_already_scrolling then return end
			is_already_scrolling = true
			pulseWidget.Down(function() is_already_scrolling = false end)
		end)
	)
)


local post_startup_timer
local post_startup_timer_timeout = 0.1
post_startup_timer = require('gears.timer'){
	callback = function()
		pulseWidget.Update(function()
                  if pulseWidget.backend.Volume > 0 or pulseWidget.backend.Mute then
                          post_startup_timer:stop()
                  else
                          post_startup_timer_timeout = post_startup_timer_timeout * 2
                          post_startup_timer.timeout = post_startup_timer_timeout
                  end
                end)
	end,
	timeout=post_startup_timer_timeout,
	autostart=true,
	call_now=false,
}

local function init(args, ...)
  return pulseWidget:_checkInit(args, ...)
end
return setmetatable(pulseWidget, { __call = function(_, ...) return init(...) end })
