local cr = import_package "ant.compile_resource"
local thread = require "thread"
local math3d = require "math3d"
local bgfx = require "bgfx"
local declmgr = import_package "ant.render".declmgr

local proxy_vb = {}
function proxy_vb:__index(k)
    if k == "handle" then
        assert(#self.memory <= 3 and (type(self.memory[1]) == "userdata" or type(self.memory[1]) == "string"))
        local membuf = bgfx.memory_buffer(table.unpack(self.memory))
        local h = bgfx.create_vertex_buffer(membuf, declmgr.get(self.declname).handle)
        self.handle = h
        return h
    end
end

local proxy_ib = {}
function proxy_ib:__index(k)
    if k == "handle" then
        assert(#self.memory <= 3 and (type(self.memory[1]) == "userdata" or type(self.memory[1]) == "string"))
        local membuf = bgfx.memory_buffer(table.unpack(self.memory))
        local h = bgfx.create_index_buffer(membuf, self.flag)
        self.handle = h
        return h
    end
end

local function init(mesh)
    local vb = mesh.vb
    for idx, v in ipairs(vb) do
        if type(v) == "userdata" then
            vb[idx] = {handle=v}
        else
            setmetatable(v, proxy_vb)
        end
    end
    local ib = mesh.ib
    if ib then
        if type(ib.handle) ~= "userdata" then
            setmetatable(ib, proxy_ib)
        end
    end
    return mesh
end

local function delete(mesh)
    local vb = mesh.vb
    for idx, v in ipairs(vb) do
        if type(v) ~= "userdata" then
            bgfx.destory(v.handle)
        end
    end

    local ib = mesh.ib
    if ib then
        if type(ib.handle) ~= "userdata" then
            bgfx.destory(ib.handle)
        end
    end
end

local function create_bounding(bounding)
    if bounding then
        bounding.aabb = math3d.ref(math3d.aabb(bounding.aabb[1], bounding.aabb[2]))
    end
end

local function loader(filename)
    local c = cr.read_file(filename)
    local mesh = thread.unpack(c)
    create_bounding(mesh.bounding)
    return init(mesh)
end

local function unloader(filename, res, obj)
    delete(res)
end

return {
    init = init,
    delete = delete,
    loader = loader,
    unloader = unloader,
}
