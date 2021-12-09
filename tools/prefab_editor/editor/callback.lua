local imgui         = require "imgui"
local task          = require "editor.task"
local event         = require "editor.event"
local worlds        = require "editor.worlds"
local cb = {}

function cb.init(width, height, cfg)
    worlds.create "prefab_editor" {
        fbw=width, fbh=height,
        viewport = {x=0, y=0, w=1, h=1},
        ecs = cfg.ecs,
    }
    event("init", width, height)
end

function cb.update(viewid, delta)
    for _, w in ipairs(worlds) do
        w.update()
    end
    task.update(delta)
    event "update"
end

function cb.exit()
    for _, w in ipairs(worlds) do
        w.exit()
    end
    event "exit"
end

function cb.mouse_wheel(x, y, delta)
    local mvp = imgui.GetMainViewport()
    x, y = x - mvp.WorkPos[1], y - mvp.WorkPos[2]
    for _, w in ipairs(worlds) do
        w.mouse_wheel(x, y, delta)
    end
end
function cb.mouse(x, y, what, state)
    local mvp = imgui.GetMainViewport()
    x, y = x - mvp.MainPos[1], y - mvp.MainPos[2]
    for _, w in ipairs(worlds) do
        w.mouse(x, y, what, state)
    end
end
function cb.keyboard(...)
    for _, w in ipairs(worlds) do
        w.keyboard(...)
    end
end
function cb.size(...)
    for _, w in ipairs(worlds) do
        w.size(...)
    end
end
function cb.dropfiles(filelst)
    event("dropfiles", filelst)
end

return cb