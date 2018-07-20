local rdebug = require 'remotedebug'

local function event(name, level, ...)
    local r
    rdebug.probe(name)
    return r
end

local function start_hook()
    local _print = print
    function print(...)
        if not event('print', 1, ...) then
            _print(...)
        end
    end

    local _xpcall = xpcall
    function xpcall(f, msgh, ...)
        return _xpcall(f, function(msg)
            event('exception', 2, 'xpcall', msg)
            return msgh(msg)
        end, ...)
    end

    local _pcall = pcall
    function pcall(f, ...)
        return _xpcall(f, function(msg)
            event('exception', 2, 'pcall', msg)
            return msg
        end, ...)
    end
    
    local _coroutine_resume = coroutine.resume
    function coroutine.resume(co, ...)
        event('coroutine', 1, co)
        return _coroutine_resume(co, ...)
    end
end

local function start_master()
    local master = require 'new-debugger.backend.master'
    if master.init() then
        return master.update
    end
end

local function start_worker()
    start_hook()
    rdebug.start 'new-debugger.backend.worker'
    return function()
        event 'update'
    end
end

local function start_all()
    start_hook()
    rdebug.start 'new-debugger.backend.worker'
    return function()
        event 'update_all'
    end
end

return {
    start_master = start_master,
    start_worker = start_worker,
    start_all = start_all,
}
