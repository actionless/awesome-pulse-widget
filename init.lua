local widget = require('apw.widget')
local module = {
  widget = widget,
  pactl = require('apw.pactl'),
  pacmd = require('apw.pacmd')
}
return setmetatable(module, {
  __index = widget,
  __call = function(_, ...) return widget(...) end
})
