local lfs = require "filesystem.local"
local fs = require "filesystem"
local toolset = require "editor.fx.toolset"
local fxsetting = require "editor.fx.setting"
local SHARER_INC = lfs.absolute(fs.path "/pkg/ant.resources/shaders":localpath())
local setting = import_package "ant.settings".setting

local function DEF_FUNC() end

local SETTING_MAPPING = {
    lighting = function (v)
        if v == "on" then
            return "ENABLE_LIGHTING=1"
        end
    end,
    shadow_receive = function (v)
        if v == "on" then
            return "ENABLE_SHADOW=1"
        end
    end,
    skinning = function (v)
        if v == "GPU" then
            return "GPU_SKINNING=1"
        end
    end,
    os = DEF_FUNC,
    renderer = DEF_FUNC,
    stage = DEF_FUNC,
    varying_path= DEF_FUNC,
    subsurface = DEF_FUNC,
    surfacetype = DEF_FUNC,
    shadow_cast = DEF_FUNC,
}

local enable_cs = setting:get 'graphic/lighting/cluster_shading' ~= 0

local function default_macros(setting)
    local m = {
        "ENABLE_SRGB_TEXTURE=1",
        "ENABLE_SRGB_FB=1",
        "ENABLE_IBL=1",
    }

    if enable_cs then
        m[#m+1] = "HOMOGENEOUS_DEPTH=" .. (setting.hd and "1" or "0")
        m[#m+1] = "ORIGIN_BOTTOM_LEFT=" .. (setting.obl and "1" or "0")
        m[#m+1] = "CLUSTER_SHADING=1"
    end
    return m
end

local function get_macros(s)
    local setting = fxsetting.adddef(s)
    local macros = default_macros(setting)
    for k, v in pairs(setting) do
        local f = SETTING_MAPPING[k]
        if f == nil then
            macros[#macros+1] = k .. '=' .. v
        else
            local t = type(f)
            if t == "function" then
                local tt = f(v)
                if tt then
                    macros[#macros+1] = tt
                end
            elseif t == "string" then
                macros[#macros+1] = f
            else
                error("invalid type")
            end
        end
    end
	return macros
end

local function compile_debug_shader(platform, renderer)
    if platform == "windows" and renderer:match "direct3d" then
        return true
    end
end

return function (input, output, setting, localpath)
    local vp = setting.varying_path
    if vp then
        vp = localpath(vp)
    end
    local ok, err, deps = toolset.compile {
        platform = setting.os,
        renderer = setting.renderer,
        input = input,
        output = output / "main.bin",
        includes = {SHARER_INC},
        stage = assert(setting.stage),
        varying_path = vp,
        macros = get_macros(setting),
        debug = compile_debug_shader(setting.os, setting.renderer),
    }
    if not ok then
        return false, ("compile failed: " .. input:string() .. "\n\n" .. err)
    end
    return true, deps
end
