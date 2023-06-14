local ecs = ...
local world = ecs.world
local w = world.w

local mathpkg       = import_package "ant.math"
local mc            = mathpkg.constant

local irq           = ecs.import.interface "ant.render|irenderqueue"
local icamera       = ecs.import.interface "ant.camera|icamera"
local iRmlUi        = ecs.import.interface "ant.rmlui|irmlui"
local iani          = ecs.import.interface "ant.animation|ianimation"
local iom           = ecs.import.interface "ant.objcontroller|iobj_motion"
local editor_setting= require "editor_setting"
local imgui         = require "imgui"
local lfs           = require "filesystem.local"
local fs            = require "filesystem"
local gd            = require "common.global_data"
local platform      = require "bee.platform"
local font          = imgui.font
local Font          = imgui.font.SystemFont
local math3d        = require "math3d"
local fmod 			= require "fmod"
local bind_billboard_camera_mb = world:sub{"bind_billboard_camera"}
function ecs.method.bind_billboard_camera(e, camera_ref)
    world:pub{"bind_billboard_camera", e, camera_ref}
end

local m = ecs.system 'init_system'

local function LoadImguiLayout(filename)
    local rf = lfs.open(filename, "rb")
    if rf then
        local setting = rf:read "a"
        rf:close()
        imgui.util.LoadIniSettings(setting)
    end
end

local function glyphRanges(t)
	assert(#t % 2 == 0)
	local s = {}
	for i = 1, #t do
		s[#s+1] = ("<I4"):pack(t[i])
	end
	s[#s+1] = "\x00\x00\x00"
	return table.concat(s)
end

function m:init()
    world.__EDITOR__ = true
    iani.set_edit_mode(true)

    LoadImguiLayout(fs.path "":localpath() .. "/" .. "imgui.layout")

    imgui.SetWindowTitle("PrefabEditor")
    gd.editor_package_path = "/pkg/tools.prefab_editor/"

    if editor_setting.setting.camera == nil then
        editor_setting.update_camera_setting(0.1)
    end
    world:pub { "camera_controller", "move_speed", editor_setting.setting.camera.speed }
    world:pub { "camera_controller", "stop", true}
    world:pub { "UpdateDefaultLight", true }

	if platform.os == "windows" then
		local ff = assert(fs.open(fs.path("/pkg/tools.prefab_editor/res/fonts/fa-solid-900.ttf"), "rb"))
		local fafontdata = ff:read "a"
		ff:close()
        font.Create {
            { Font "Segoe UI Emoji" , 18, glyphRanges { 0x23E0, 0x329F, 0x1F000, 0x1FA9F }},
            { Font "黑体" , 18, glyphRanges { 0x0020, 0xFFFF }},
			{ fafontdata, 16, glyphRanges {
				0xf062, 0xf062, -- ICON_FA_ARROW_UP 			"\xef\x81\xa2"	U+f062
				0xf063, 0xf063,	-- ICON_FA_ARROW_DOWN 			"\xef\x81\xa3"	U+f063
				0xf0c7, 0xf0c7,	-- ICON_FA_FLOPPY_DISK 			"\xef\x83\x87"	U+f0c7
				0xf04b, 0xf04b, -- ICON_FA_PLAY 				"\xef\x81\x8b"	U+f04b
				0xf04d, 0xf04d, -- ICON_FA_STOP 				"\xef\x81\x8d"	U+f04d
				0xf14a, 0xf14a, -- ICON_FA_SQUARE_CHECK 		"\xef\x85\x8a"	U+f14a
				0xf2d3, 0xf2d3, -- ICON_FA_SQUARE_XMARK 		"\xef\x8b\x93"	U+f2d3
				0xf05e, 0xf05e, -- ICON_FA_BAN 					"\xef\x81\x9e"	U+f05e
				0xf1f8, 0xf1f8, -- ICON_FA_TRASH 				"\xef\x87\xb8"	U+f1f8
				0xf2ed, 0xf2ed, -- ICON_FA_TRASH_CAN 			"\xef\x8b\xad"	U+f2ed
				0xf28b, 0xf28b, -- ICON_FA_CIRCLE_PAUSE 		"\xef\x8a\x8b"	U+f28b
				0xf144, 0xf144, -- ICON_FA_CIRCLE_PLAY 			"\xef\x85\x84"	U+f144
				0xf28d, 0xf28d, -- ICON_FA_CIRCLE_STOP 			"\xef\x8a\x8d"	U+f28d
				0xf0fe, 0xf0fe, -- ICON_FA_SQUARE_PLUS 			"\xef\x83\xbe"	U+f0fe
				0xf0e2, 0xf0e2, -- ICON_FA_ARROW_ROTATE_LEFT 	"\xef\x83\xa2"	U+f0e2
				0xf01e, 0xf01e, -- ICON_FA_ARROW_ROTATE_RIGHT 	"\xef\x80\x9e"	U+f01e
				0xf002, 0xf002, -- ICON_FA_MAGNIFYING_GLASS 	"\xef\x80\x82"	U+f002
				0xf07b, 0xf07b, -- ICON_FA_FOLDER 				"\xef\x81\xbb"	U+f07b
				0xf07c, 0xf07c, -- ICON_FA_FOLDER_OPEN 			"\xef\x81\xbc"	U+f07c
				0xe4c2, 0xe4c2, -- ICON_FA_ARROWS_UP_TO_LINE 	"\xee\x93\x82"	U+e4c2
				0xe4b8, 0xe4b8, -- ICON_FA_ARROWS_DOWN_TO_LINE  "\xee\x92\xb8"	U+e4b8
				0xf65e, 0xf65e, -- ICON_FA_FOLDER_PLUS 			"\xef\x99\x9e"	U+f65e
				0xf65d, 0xf65d, -- ICON_FA_FOLDER_MINUS 		"\xef\x99\x9d"	U+f65d
				0xf24d, 0xf24d, -- ICON_FA_CLONE 				"\xef\x89\x8d"	U+f24d
				0xf068, 0xf068, -- ICON_FA_MINUS 				"\xef\x81\xa8"	U+f068
				0xf019, 0xf019, -- ICON_FA_DOWNLOAD 			"\xef\x80\x99"	U+f019
				0xf00d, 0xf00d, -- ICON_FA_XMARK 				"\xef\x80\x8d"	U+f00d
				0xf013, 0xf013, -- ICON_FA_GEAR 				"\xef\x80\x93"	U+f013
				0xf085, 0xf085, -- ICON_FA_GEARS 				"\xef\x82\x85"	U+f085
				0xf15b, 0xf15b, -- ICON_FA_FILE 				"\xef\x85\x9b"	U+f15b
				0xf31c, 0xf31c, -- ICON_FA_FILE_PEN 			"\xef\x8c\x9c"	U+f31c
				0xf304, 0xf304, -- ICON_FA_PEN 					"\xef\x8c\x84"	U+f304
				0xf0eb, 0xf0eb, -- ICON_FA_LIGHTBULB 			"\xef\x83\xab"	U+f0eb
				0xf03a, 0xf03a, -- ICON_FA_LIST 				"\xef\x80\xba"	U+f03a
				0xf023, 0xf023, -- ICON_FA_LOCK 				"\xef\x80\xa3"	U+f023
				0xf3c1, 0xf3c1, -- ICON_FA_LOCK_OPEN 			"\xef\x8f\x81"	U+f3c1
				0xf06e, 0xf06e, -- ICON_FA_EYE 					"\xef\x81\xae"	U+f06e
				0xf070, 0xf070, -- ICON_FA_EYE_SLASH 			"\xef\x81\xb0"	U+f070
				0xf00c, 0xf00c, -- ICON_FA_CHECK 				"\xef\x80\x8c"	U+f00c
				0xf058, 0xf058, -- ICON_FA_CIRCLE_CHECK 		"\xef\x81\x98"	U+f058
				0xf056, 0xf056, -- ICON_FA_CIRCLE_MINUS 		"\xef\x81\x96"	U+f056
				0xf055, 0xf055, -- ICON_FA_CIRCLE_PLUS 			"\xef\x81\x95"	U+f055
				0xf120, 0xf120, -- ICON_FA_TERMINAL 			"\xef\x84\xa0"	U+f120
				0xf05a, 0xf05a, -- ICON_FA_CIRCLE_INFO 			"\xef\x81\x9a"	U+f05a
				0xf35d, 0xf35d, -- ICON_FA_UP_RIGHT_FROM_SQUARE "\xef\x8d\x9d"	U+f35d
				0xf071, 0xf071, -- ICON_FA_TRIANGLE_EXCLAMATION "\xef\x81\xb1"	U+f071
			}},
        }
    elseif platform.os == "macos" then
        font.Create { { Font "华文细黑" , 18, glyphRanges { 0x0020, 0xFFFF }} }
    else -- iOS
        font.Create { { Font "Heiti SC" , 18, glyphRanges { 0x0020, 0xFFFF }} }
    end
	gd.audio = fmod.init()
end

local function init_camera()
    local mq = w:first "main_queue camera_ref:in"
    local e <close> = w:entity(mq.camera_ref)
    local eye, at = math3d.vector(0, 5, -10), mc.ZERO_PT
    iom.set_position(e, eye)
    iom.set_direction(e, math3d.normalize(math3d.sub(at, eye)))
    local f = icamera.get_frustum(e)
    f.n, f.f = 1, 1000
    icamera.set_frustum(e, f)
end

local light_gizmo = ecs.require "gizmo.light"
local prefab_mgr = ecs.require "prefab_manager"
function m:init_world()
    irq.set_view_clear_color("main_queue", 0x353535ff)--0xa0a0a0ff
    init_camera()
    light_gizmo.init()
    prefab_mgr:reset_prefab()
end

function m:post_init()
    iRmlUi.add_bundle "/rml.bundle"
    iRmlUi.set_prefix "/pkg/tools.prefab_editor/res/ui"
end

function m:data_changed()
    for _, e, camera_ref in bind_billboard_camera_mb:unpack() do
        w:extend(e, "render_object?in")
        e.render_object.camera_ref = camera_ref or w:first("main_queue camera_ref:in").camera_ref
    end
	gd.audio:update()
end

function m:exit()
	gd.audio:shutdown()
end