local module = {
  widget = require('apw.widget'),
  pactl = require('apw.pactl'),
  pacmd = require('apw.pacmd')
}
return setmetatable(module, {
  __index = module.widget,
  __call = function(_, ...) return module.widget(...) end
})
