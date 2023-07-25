local ltask   = require "ltask"
local bgfx    = require "bgfx"
local cr      = require "thread.compile"
local texture = require "thread.texture"
require "thread.material"
import_package "ant.service".init_bgfx()

bgfx.init()
cr.init()

local S = require "thread.main"

function S.compile(path)
    return cr.compile(path):string()
end

local quit

ltask.fork(function ()
    bgfx.encoder_create "resource"
    while not quit do
        texture.update()
        bgfx.encoder_frame()
    end
    bgfx.encoder_destroy()
    ltask.wakeup(quit)
end)

function S.quit()
    quit = {}
    ltask.wait(quit)
    bgfx.shutdown()
    ltask.quit()
end

return S
