local ecs = ...
local world = ecs.world
local math3d = require "math3d"
local rhwi = import_package 'ant.render'.hwi
local mc = import_package "ant.math".constant
local iwd = world:interface "ant.render|iwidget_drawer"
local iss = world:interface "ant.scene|iscenespace"
local computil = world:interface "ant.render|entity"
local gizmo_sys = ecs.system "gizmo_system"
local iom = world:interface "ant.objcontroller|obj_motion"
local ies = world:interface "ant.scene|ientity_state"
local gizmo_const = require "gizmo.const"
local imaterial = world:interface "ant.asset|imaterial"
local cmd_queue = require "gizmo.command_queue"(world)
local hierarchy = require "hierarchy"
local utils = require "mathutils"(world)
local worldedit = import_package "ant.editor".worldedit(world)
local global_data = require "common.global_data"
local camera_mgr = require "camera_manager"(world)
local gizmo = require "gizmo.gizmo"(world)

local move_axis
local rotate_axis
local uniform_scale = false
local gizmo_scale = 1.0
local local_space = false
local global_axis_eid
local axis_plane_area

function gizmo:set_target(eid)
	local target = hierarchy:get_select_adapter(eid)
	if self.target_eid == target then
		return
	end
	local old_target = self.target_eid
	self.target_eid = target
	if target then
		self:set_position()
		self:set_rotation()
		self:update_scale()
		self:updata_uniform_scale()
		self:update_axis_plane()
	end
	gizmo:show_by_state(target ~= nil)
	world:pub {"Gizmo","ontarget", old_target, target}
end

function gizmo:updata_uniform_scale()
	if not self.rw.eid[1] then return end
	self.rw.dir = math3d.totable(iom.get_direction(camera_mgr.main_camera))
	--update_camera
	local r = iom.get_rotation(camera_mgr.main_camera)
	-- local s,r,t = math3d.srt(world[cameraeid].transform)
	iom.set_rotation(self.rw.eid[1], r)
	iom.set_rotation(self.rw.eid[3], r)
	iom.set_rotation(self.rw.eid[4], r)
end

function gizmo:set_scale(inscale)
	if not self.target_eid then
		return
	end
	iom.set_scale(self.target_eid, inscale)
end

function gizmo:set_position(worldpos)
	if not self.target_eid then
		return
	end
	local newpos
	if worldpos then
		local parent_worldmat = iom.calc_worldmat(world[gizmo.target_eid].parent)
		local localPos
		if not parent_worldmat then
			localPos = worldpos
		else
			localPos = math3d.totable(math3d.transform(math3d.inverse(parent_worldmat), worldpos, 1))
		end
		
		iom.set_position(self.target_eid, localPos)
		newpos = worldpos
	else
		local s,r,t = math3d.srt(iom.calc_worldmat(gizmo.target_eid))
		newpos = math3d.totable(t)
	end
	iom.set_position(self.root_eid, newpos)
	iom.set_position(self.uniform_rot_root_eid, newpos)
end

function gizmo:set_rotation(inrot)
	if not self.target_eid then
		return
	end
	local newrot
	if inrot then
		iom.set_rotation(self.target_eid, inrot)
		newrot = inrot
	else
		newrot = iom.get_rotation(self.target_eid)
	end
	if self.mode == gizmo_const.SCALE then
		iom.set_rotation(self.root_eid, newrot)
	elseif self.mode == gizmo_const.MOVE or self.mode == gizmo_const.ROTATE then
		if local_space then
			iom.set_rotation(self.root_eid, newrot)
		else
			iom.set_rotation(self.root_eid, math3d.quaternion{0,0,0})
		end
	end
end

function gizmo:on_mode(mode)
	self:show_by_state(false)
	self.mode = mode
	self:show_by_state(true)
	self:set_rotation()
end

local function create_arrow_widget(axis_root, axis_str)
	local cone_t
	local cylindere_t
	local local_rotator
	if axis_str == "x" then
		cone_t = math3d.vector(gizmo_const.AXIS_LEN, 0, 0)
		local_rotator = math3d.quaternion{0, 0, math.rad(-90)}
		cylindere_t = math3d.vector(0.5 * gizmo_const.AXIS_LEN, 0, 0)
	elseif axis_str == "y" then
		cone_t = math3d.vector(0, gizmo_const.AXIS_LEN, 0)
		local_rotator = math3d.quaternion{0, 0, 0}
		cylindere_t = math3d.vector(0, 0.5 * gizmo_const.AXIS_LEN, 0)
	elseif axis_str == "z" then
		cone_t = math3d.vector(0, 0, gizmo_const.AXIS_LEN)
		local_rotator = math3d.quaternion{math.rad(90), 0, 0}
		cylindere_t = math3d.vector(0, 0, 0.5 * gizmo_const.AXIS_LEN)
	end
	local cylindereid = world:create_entity{
		policy = {
			"ant.render|render",
			"ant.general|name",
			"ant.scene|hierarchy_policy",
		},
		data = {
			scene_entity = true,
			state = ies.create_state "visible",
			transform = {
				s = math3d.ref(math3d.vector(0.2, 10, 0.2)),
				r = local_rotator,
				t = cylindere_t,
			},
			material = "/pkg/ant.resources/materials/t_gizmos.material",
			mesh = '/pkg/ant.resources.binary/meshes/base/cylinder.glb|meshes/pCylinder1_P1.meshbin',
			name = "arrow.cylinder" .. axis_str
		}
	}
	ies.set_state(cylindereid, "auxgeom", true)
	iss.set_parent(cylindereid, axis_root)
	local coneeid = world:create_entity{
		policy = {
			"ant.render|render",
			"ant.general|name",
			"ant.scene|hierarchy_policy",
		},
		data = {
			scene_entity = true,
			state = ies.create_state "visible",
			transform = {s = {1, 1.5, 1, 0}, r = local_rotator, t = cone_t},
			material = "/pkg/ant.resources/materials/t_gizmos.material",
			mesh = '/pkg/ant.resources.binary/meshes/base/cone.glb|meshes/pCone1_P1.meshbin',
			name = "arrow.cone" .. axis_str
		}
	}
	ies.set_state(coneeid, "auxgeom", true)
	iss.set_parent(coneeid, axis_root)
	if axis_str == "x" then
		gizmo.tx.eid = {cylindereid, coneeid}
	elseif axis_str == "y" then
		gizmo.ty.eid = {cylindereid, coneeid}
	elseif axis_str == "z" then
		gizmo.tz.eid = {cylindereid, coneeid}
	end
end

function gizmo_sys:init()

end

local function mouse_hit_plane(screen_pos, plane_info)
	return utils.ray_hit_plane(iom.ray(camera_mgr.main_camera, screen_pos), plane_info)
end

local function update_global_axis()
	if not global_data.viewport then return end
	local worldPos = mouse_hit_plane({50, global_data.viewport.h  - 50}, {dir = {0,1,0}, pos = {0,0,0}})
	if worldPos then
		iom.set_position(global_axis_eid, math3d.totable(worldPos))
	end
	--print("gizmo_scale", gizmo_scale)
	--todo：
	local adjustScale = (gizmo_scale < 4.5) and 4.5 or gizmo_scale
	iom.set_scale(global_axis_eid, adjustScale * 0.5)
end

function gizmo:update_scale()
	local viewdir = iom.get_direction(camera_mgr.main_camera)
	local eyepos = iom.get_position(camera_mgr.main_camera)
	local project_dist = math3d.dot(math3d.normalize(viewdir), math3d.sub(iom.get_position(self.root_eid), eyepos))
	gizmo_scale = project_dist * 0.35
	if self.root_eid then
		iom.set_scale(self.root_eid, gizmo_scale)
	end
	if self.uniform_rot_root_eid then
		iom.set_scale(self.uniform_rot_root_eid, gizmo_scale)
	end
end

function gizmo_sys:post_init()
	local srt = {r = math3d.quaternion{0, 0, 0}, t = {0,0,0,1}}
	local axis_root = world:create_entity{
		policy = {
			"ant.general|name",
			"ant.scene|transform_policy",
		},
		data = {
			transform = {},
			name = "axis root",
		},
	}
	gizmo.root_eid = axis_root
	local rot_circle_root = world:create_entity{
		policy = {
			"ant.general|name",
			"ant.scene|transform_policy",
		},
		data = {
			transform = srt,
			name = "rot root",
		},
	}

	iss.set_parent(rot_circle_root, axis_root)
	gizmo.rot_circle_root_eid = rot_circle_root

	local uniform_rot_root = world:create_entity{
		policy = {
			"ant.general|name",
			"ant.scene|transform_policy",
		},
		data = {
			transform = srt,
			name = "rot root",
		},
	}
	gizmo.uniform_rot_root_eid = uniform_rot_root

	create_arrow_widget(axis_root, "x")
	create_arrow_widget(axis_root, "y")
	create_arrow_widget(axis_root, "z")
	local plane_xy_eid = computil.create_prim_plane_entity(
		{t = {gizmo_const.MOVE_PLANE_OFFSET, gizmo_const.MOVE_PLANE_OFFSET, 0, 1}, s = {gizmo_const.MOVE_PLANE_SCALE, 1, gizmo_const.MOVE_PLANE_SCALE, 0}, r = math3d.tovalue(math3d.quaternion{math.rad(90), 0, 0})},
		"/pkg/ant.resources/materials/t_gizmos.material",
		"plane_xy")
	ies.set_state(plane_xy_eid, "auxgeom", true)
	imaterial.set_property(plane_xy_eid, "u_color", gizmo.txy.color)
	iss.set_parent(plane_xy_eid, axis_root)
	gizmo.txy.eid = {plane_xy_eid, plane_xy_eid}

	plane_yz_eid = computil.create_prim_plane_entity(
		{t = {0, gizmo_const.MOVE_PLANE_OFFSET, gizmo_const.MOVE_PLANE_OFFSET, 1}, s = {gizmo_const.MOVE_PLANE_SCALE, 1, gizmo_const.MOVE_PLANE_SCALE, 0}, r = math3d.tovalue(math3d.quaternion{0, 0, math.rad(90)})},
		"/pkg/ant.resources/materials/t_gizmos.material",
		"plane_yz")
	ies.set_state(plane_yz_eid, "auxgeom", true)
	imaterial.set_property(plane_yz_eid, "u_color", gizmo.tyz.color)
	iss.set_parent(plane_yz_eid, axis_root)
	gizmo.tyz.eid = {plane_yz_eid, plane_yz_eid}

	plane_zx_eid = computil.create_prim_plane_entity(
		{t = {gizmo_const.MOVE_PLANE_OFFSET, 0, gizmo_const.MOVE_PLANE_OFFSET, 1}, s = {gizmo_const.MOVE_PLANE_SCALE, 1, gizmo_const.MOVE_PLANE_SCALE, 0}},
		"/pkg/ant.resources/materials/t_gizmos.material",
		"plane_zx")
	ies.set_state(plane_zx_eid, "auxgeom", true)
	imaterial.set_property(plane_zx_eid, "u_color", gizmo.tzx.color)
	iss.set_parent(plane_zx_eid, axis_root)
	gizmo.tzx.eid = {plane_zx_eid, plane_zx_eid}
	gizmo:reset_move_axis_color()

	-- roate axis
	local uniform_rot_eid = computil.create_circle_entity(gizmo_const.UNIFORM_ROT_AXIS_LEN, gizmo_const.ROTATE_SLICES, {}, "rotate_gizmo_uniform")
	ies.set_state(uniform_rot_eid, "auxgeom", true)
	imaterial.set_property(uniform_rot_eid, "u_color", gizmo_const.COLOR_GRAY)
	iss.set_parent(uniform_rot_eid, uniform_rot_root)
	local function create_rotate_fan(radius, circle_trans)
		local mesh_eid = computil.create_circle_mesh_entity(radius, gizmo_const.ROTATE_SLICES, circle_trans, "/pkg/ant.resources/materials/t_gizmos.material", "rotate_mesh_gizmo_uniform")
		imaterial.set_property(mesh_eid, "u_color", {0, 0, 1, 0.5})
		ies.set_state(mesh_eid, "visible", false)
		iss.set_parent(mesh_eid, axis_root)
		return mesh_eid
	end
	-- counterclockwise mesh
	local rot_ccw_mesh_eid = create_rotate_fan(gizmo_const.UNIFORM_ROT_AXIS_LEN, {})
	iss.set_parent(rot_ccw_mesh_eid, uniform_rot_root)
	-- clockwise mesh
	local rot_cw_mesh_eid = create_rotate_fan(gizmo_const.UNIFORM_ROT_AXIS_LEN, {})
	iss.set_parent(rot_cw_mesh_eid, uniform_rot_root)
	gizmo.rw.eid = {uniform_rot_eid, uniform_rot_eid, rot_ccw_mesh_eid, rot_cw_mesh_eid}

	local function create_rotate_axis(axis, line_end, circle_trans)
		local line_eid = computil.create_line_entity({}, {0, 0, 0}, line_end)
		ies.set_state(line_eid, "auxgeom", true)
		imaterial.set_property(line_eid, "u_color", axis.color)
		iss.set_parent(line_eid, rot_circle_root)
		local rot_eid = computil.create_circle_entity(gizmo_const.AXIS_LEN, gizmo_const.ROTATE_SLICES, circle_trans, "rotate gizmo circle")
		ies.set_state(rot_eid, "auxgeom", true)
		imaterial.set_property(rot_eid, "u_color", axis.color)
		iss.set_parent(rot_eid, rot_circle_root)
		local rot_ccw_mesh_eid = create_rotate_fan(gizmo_const.AXIS_LEN, circle_trans)
		local rot_cw_mesh_eid = create_rotate_fan(gizmo_const.AXIS_LEN, circle_trans)
		axis.eid = {rot_eid, line_eid, rot_ccw_mesh_eid, rot_cw_mesh_eid}
	end
	create_rotate_axis(gizmo.rx, {gizmo_const.AXIS_LEN * 0.5, 0, 0}, {r = math3d.tovalue(math3d.quaternion{0, math.rad(90), 0})})
	create_rotate_axis(gizmo.ry, {0, gizmo_const.AXIS_LEN * 0.5, 0}, {r = math3d.tovalue(math3d.quaternion{math.rad(90), 0, 0})})
	create_rotate_axis(gizmo.rz, {0, 0, gizmo_const.AXIS_LEN * 0.5}, {})
	
	-- scale axis
	local function create_scale_cube(srt, color, axis_name)
		local eid = world:create_entity {
			policy = {
				"ant.render|render",
				"ant.general|name",
				"ant.scene|hierarchy_policy",
			},
			data = {
				scene_entity = true,
				state = ies.create_state "visible|selectable",
				transform = srt,
				material = "/pkg/ant.resources/materials/t_gizmos.material",
				mesh = "/pkg/ant.resources.binary/meshes/base/cube.glb|meshes/pCube1_P1.meshbin",
				name = "scale_cube" .. axis_name
			}
		}
		ies.set_state(eid, "auxgeom", true)

		imaterial.set_property(eid, "u_color", color)
		return eid
	end
	-- scale axis cube
	local cube_eid = create_scale_cube({s = gizmo_const.AXIS_CUBE_SCALE}, gizmo_const.COLOR_GRAY, "uniform scale")
	ies.set_state(cube_eid, "auxgeom", true)
	iss.set_parent(cube_eid, axis_root)
	gizmo.uniform_scale_eid = cube_eid
	local function create_scale_axis(axis, axis_end)
		local cube_eid = create_scale_cube({t = axis_end, s = gizmo_const.AXIS_CUBE_SCALE}, axis.color, "scale axis")
		iss.set_parent(cube_eid, axis_root)
		local line_eid = computil.create_line_entity({}, {0, 0, 0}, axis_end)
		imaterial.set_property(line_eid, "u_color", axis.color)
		iss.set_parent(line_eid, axis_root)
		axis.eid = {cube_eid, line_eid}
	end
	create_scale_axis(gizmo.sx, {gizmo_const.AXIS_LEN, 0, 0})
	create_scale_axis(gizmo.sy, {0, gizmo_const.AXIS_LEN, 0})
	create_scale_axis(gizmo.sz, {0, 0, gizmo_const.AXIS_LEN})

	global_axis_eid = world:create_entity{
		policy = {
			"ant.general|name",
			"ant.scene|transform_policy",
		},
		data = {
			transform = srt,
			name = "global axis root",
		},
	}
	ies.set_state(global_axis_eid, "auxgeom", true)
	local new_eid = computil.create_line_entity({}, {0, 0, 0}, {0.1, 0, 0})
	ies.set_state(new_eid, "auxgeom", true)
	imaterial.set_property(new_eid, "u_color", gizmo_const.COLOR_X)
	iss.set_parent(new_eid, global_axis_eid)
	new_eid = computil.create_line_entity({}, {0, 0, 0}, {0, 0.1, 0})
	ies.set_state(new_eid, "auxgeom", true)
	imaterial.set_property(new_eid, "u_color", gizmo_const.COLOR_Y)
	iss.set_parent(new_eid, global_axis_eid)
	new_eid = computil.create_line_entity({}, {0, 0, 0}, {0, 0, 0.1})
	ies.set_state(new_eid, "auxgeom", true)
	imaterial.set_property(new_eid, "u_color", gizmo_const.COLOR_Z)
	iss.set_parent(new_eid, global_axis_eid)
	update_global_axis()
	gizmo:update_scale()
	gizmo:show_by_state(false)
end

local function gizmo_dir_to_world(localDir)
	if local_space or (gizmo.mode == gizmo_const.SCALE) then
		return math3d.totable(math3d.transform(iom.get_rotation(gizmo.root_eid), localDir, 0))
	else
		return localDir
	end
end

function gizmo:update_axis_plane()
	if self.mode ~= gizmo_const.MOVE or not self.target_eid then
		return
	end

	local gizmoPosVec = iom.get_position(self.root_eid)
	local worldDir = math3d.vector(gizmo_dir_to_world(gizmo_const.DIR_Z))
	local plane_xy = {n = worldDir, d = -math3d.dot(worldDir, gizmoPosVec)}
	worldDir = math3d.vector(gizmo_dir_to_world(gizmo_const.DIR_Y))
	local plane_zx = {n = worldDir, d = -math3d.dot(worldDir, gizmoPosVec)}
	worldDir = math3d.vector(gizmo_dir_to_world(gizmo_const.DIR_X))
	local plane_yz = {n = worldDir, d = -math3d.dot(worldDir, gizmoPosVec)}

	local eyepos = iom.get_position(camera_mgr.main_camera)

	local project = math3d.sub(eyepos, math3d.mul(plane_xy.n, math3d.dot(plane_xy.n, eyepos) + plane_xy.d))
	local invmat = math3d.inverse(iom.srt(self.root_eid))
	local tp = math3d.totable(math3d.transform(invmat, project, 1))
	iom.set_position(self.txy.eid[1], {(tp[1] > 0) and gizmo_const.MOVE_PLANE_OFFSET or -gizmo_const.MOVE_PLANE_OFFSET, (tp[2] > 0) and gizmo_const.MOVE_PLANE_OFFSET or -gizmo_const.MOVE_PLANE_OFFSET, 0})
	self.txy.area = (tp[1] > 0) and ((tp[2] > 0) and gizmo_const.RIGHT_TOP or gizmo_const.RIGHT_BOTTOM) or (((tp[2] > 0) and gizmo_const.LEFT_TOP or gizmo_const.LEFT_BOTTOM))

	project = math3d.sub(eyepos, math3d.mul(plane_zx.n, math3d.dot(plane_zx.n, eyepos) + plane_zx.d))
	tp = math3d.totable(math3d.transform(invmat, project, 1))
	iom.set_position(self.tzx.eid[1], {(tp[1] > 0) and gizmo_const.MOVE_PLANE_OFFSET or -gizmo_const.MOVE_PLANE_OFFSET, 0, (tp[3] > 0) and gizmo_const.MOVE_PLANE_OFFSET or -gizmo_const.MOVE_PLANE_OFFSET})
	self.tzx.area = (tp[1] > 0) and ((tp[3] > 0) and gizmo_const.RIGHT_TOP or gizmo_const.RIGHT_BOTTOM) or (((tp[3] > 0) and gizmo_const.LEFT_TOP or gizmo_const.LEFT_BOTTOM))

	project = math3d.sub(eyepos, math3d.mul(plane_yz.n, math3d.dot(plane_yz.n, eyepos) + plane_yz.d))
	tp = math3d.totable(math3d.transform(invmat, project, 1))
	iom.set_position(self.tyz.eid[1], {0,(tp[2] > 0) and gizmo_const.MOVE_PLANE_OFFSET or -gizmo_const.MOVE_PLANE_OFFSET, (tp[3] > 0) and gizmo_const.MOVE_PLANE_OFFSET or -gizmo_const.MOVE_PLANE_OFFSET})
	self.tyz.area = (tp[3] > 0) and ((tp[2] > 0) and gizmo_const.RIGHT_TOP or gizmo_const.RIGHT_BOTTOM) or (((tp[2] > 0) and gizmo_const.LEFT_TOP or gizmo_const.LEFT_BOTTOM))
end

local keypress_mb = world:sub{"keyboard"}

local pickup_mb = world:sub {"pickup"}


local function select_axis_plane(x, y)
	if gizmo.mode ~= gizmo_const.MOVE then
		return nil
	end
	local function hit_test_axix_plane(axis_plane)
		local gizmoPos = iom.get_position(gizmo.root_eid)
		local hitPosVec = mouse_hit_plane({x, y}, {dir = gizmo_dir_to_world(axis_plane.dir), pos = math3d.totable(gizmoPos)})
		if hitPosVec then
			return math3d.totable(math3d.transform(math3d.inverse(iom.get_rotation(gizmo.root_eid)), math3d.sub(hitPosVec, gizmoPos), 0))
		end
		return nil
	end
	local planeHitRadius = gizmo_scale * gizmo_const.MOVE_PLANE_HIT_RADIUS * 0.5
	local axis_plane = gizmo.tyz
	local posToGizmo = hit_test_axix_plane(axis_plane)
	
	if posToGizmo then
		if axis_plane.area == gizmo_const.RIGHT_BOTTOM then
			posToGizmo[2] = -posToGizmo[2]
		elseif axis_plane.area == gizmo_const.LEFT_BOTTOM then
			posToGizmo[3] = -posToGizmo[3]
			posToGizmo[2] = -posToGizmo[2]
		elseif axis_plane.area == gizmo_const.LEFT_TOP then
			posToGizmo[3] = -posToGizmo[3]
		end
		if posToGizmo[2] > 0 and posToGizmo[2] < planeHitRadius and posToGizmo[3] > 0 and posToGizmo[3] < planeHitRadius then
			return axis_plane
		end
	end
	posToGizmo = hit_test_axix_plane(gizmo.txy)
	axis_plane = gizmo.txy
	if posToGizmo then
		if axis_plane.area == gizmo_const.RIGHT_BOTTOM then
			posToGizmo[2] = -posToGizmo[2]
		elseif axis_plane.area == gizmo_const.LEFT_BOTTOM then
			posToGizmo[1] = -posToGizmo[1]
			posToGizmo[2] = -posToGizmo[2]
		elseif axis_plane.area == gizmo_const.LEFT_TOP then
			posToGizmo[1] = -posToGizmo[1]
		end
		if posToGizmo[1] > 0 and posToGizmo[1] < planeHitRadius and posToGizmo[2] > 0 and posToGizmo[2] < planeHitRadius then
			return axis_plane
		end
	end
	posToGizmo = hit_test_axix_plane(gizmo.tzx)
	axis_plane = gizmo.tzx
	if posToGizmo then
		if axis_plane.area == gizmo_const.RIGHT_BOTTOM then
			posToGizmo[3] = -posToGizmo[3]
		elseif axis_plane.area == gizmo_const.LEFT_BOTTOM then
			posToGizmo[1] = -posToGizmo[1]
			posToGizmo[3] = -posToGizmo[3]
		elseif axis_plane.area == gizmo_const.LEFT_TOP then
			posToGizmo[1] = -posToGizmo[1]
		end
		if posToGizmo[1] > 0 and posToGizmo[1] < planeHitRadius and posToGizmo[3] > 0 and posToGizmo[3] < planeHitRadius then
			return axis_plane
		end
	end
	return nil
end

local function select_axis(x, y)
	if not gizmo.target_eid or not x or not y then
		return
	end
	if gizmo.mode == gizmo_const.SCALE then
		gizmo:reset_scale_axis_color()
	elseif gizmo.mode == gizmo_const.MOVE then
		gizmo:reset_move_axis_color()
	end
	-- by plane
	local axisPlane = select_axis_plane(x, y)
	if axisPlane then
		return axisPlane
	end
	
	local gizmo_obj_pos = iom.get_position(gizmo.root_eid)
	local start = utils.world_to_screen(camera_mgr.main_camera, gizmo_obj_pos)
	uniform_scale = false
	-- uniform scale
	local hp = {x, y, 0}
	if gizmo.mode == gizmo_const.SCALE then
		local radius = math3d.length(math3d.sub(hp, start))
		if radius < gizmo_const.MOVE_HIT_RADIUS_PIXEL then
			uniform_scale = true
			imaterial.set_property(gizmo.uniform_scale_eid, "u_color", gizmo_const.HIGHTLIGHT_COLOR)
			imaterial.set_property(gizmo.sx.eid[1], "u_color", gizmo_const.HIGHTLIGHT_COLOR)
			imaterial.set_property(gizmo.sx.eid[2], "u_color", gizmo_const.HIGHTLIGHT_COLOR)
			imaterial.set_property(gizmo.sy.eid[1], "u_color", gizmo_const.HIGHTLIGHT_COLOR)
			imaterial.set_property(gizmo.sy.eid[2], "u_color", gizmo_const.HIGHTLIGHT_COLOR)
			imaterial.set_property(gizmo.sz.eid[1], "u_color", gizmo_const.HIGHTLIGHT_COLOR)
			imaterial.set_property(gizmo.sz.eid[2], "u_color", gizmo_const.HIGHTLIGHT_COLOR)
			return nil
		end
	end
	-- by axis
	local line_len = gizmo_const.AXIS_LEN * gizmo_scale
	local end_x = utils.world_to_screen(camera_mgr.main_camera, math3d.add(gizmo_obj_pos, math3d.vector(gizmo_dir_to_world({line_len, 0, 0}))))
	
	local axis = (gizmo.mode == gizmo_const.SCALE) and gizmo.sx or gizmo.tx
	if utils.point_to_line_distance2D(start, end_x, hp) < gizmo_const.MOVE_HIT_RADIUS_PIXEL then
		return axis
	end

	local end_y = utils.world_to_screen(camera_mgr.main_camera, math3d.add(gizmo_obj_pos, math3d.vector(gizmo_dir_to_world({0, line_len, 0}))))
	axis = (gizmo.mode == gizmo_const.SCALE) and gizmo.sy or gizmo.ty
	if utils.point_to_line_distance2D(start, end_y, hp) < gizmo_const.MOVE_HIT_RADIUS_PIXEL then
		return axis
	end

	local end_z = utils.world_to_screen(camera_mgr.main_camera, math3d.add(gizmo_obj_pos, math3d.vector(gizmo_dir_to_world({0, 0, line_len}))))
	axis = (gizmo.mode == gizmo_const.SCALE) and gizmo.sz or gizmo.tz
	if utils.point_to_line_distance2D(start, end_z, hp) < gizmo_const.MOVE_HIT_RADIUS_PIXEL then
		return axis
	end
	return nil
end

local function select_rotate_axis(x, y)
	if not gizmo.target_eid or not x or not y then
		return
	end
	gizmo:reset_rotate_axis_color()

	local function hit_test_rotate_axis(axis)
		local gizmoPos = iom.get_position(gizmo.root_eid)
		local axisDir = (axis ~= gizmo.rw) and gizmo_dir_to_world(axis.dir) or axis.dir
		local hitPosVec = mouse_hit_plane({x, y}, {dir = axisDir, pos = math3d.totable(gizmoPos)})
		if not hitPosVec then
			return
		end
		local dist = math3d.length(math3d.sub(gizmoPos, hitPosVec))
		local adjust_axis_len = (axis == gizmo.rw) and gizmo_const.UNIFORM_ROT_AXIS_LEN or gizmo_const.AXIS_LEN
		if math.abs(dist - gizmo_scale * adjust_axis_len) < gizmo_const.ROTATE_HIT_RADIUS * gizmo_scale then
			imaterial.set_property(axis.eid[1], "u_color", gizmo_const.HIGHTLIGHT_COLOR)
			imaterial.set_property(axis.eid[2], "u_color", gizmo_const.HIGHTLIGHT_COLOR)
			return hitPosVec
		else
			imaterial.set_property(axis.eid[1], "u_color", axis.color)
			imaterial.set_property(axis.eid[2], "u_color", axis.color)
			return nil
		end
	end

	local hit = hit_test_rotate_axis(gizmo.rx)
	if hit then
		return gizmo.rx, hit
	end

	hit = hit_test_rotate_axis(gizmo.ry)
	if hit then
		return gizmo.ry, hit
	end

	hit = hit_test_rotate_axis(gizmo.rz)
	if hit then
		return gizmo.rz, hit
	end

	hit = hit_test_rotate_axis(gizmo.rw)
	if hit then
		return gizmo.rw, hit
	end
end

local camera_zoom = world:sub {"camera", "zoom"}
local mouse_drag = world:sub {"mousedrag"}
local mouse_move = world:sub {"mousemove"}
local mouse_down = world:sub {"mousedown"}
local mouse_up = world:sub {"mouseup"}

local gizmo_mode_event = world:sub {"GizmoMode"}

local last_mouse_pos
local last_gizmo_pos
local init_offset = math3d.ref()
local last_gizmo_scale
local last_rotate_axis = math3d.ref()
local last_rotate = math3d.ref()
local last_hit = math3d.ref()
local gizmo_seleted = false

local function move_gizmo(x, y)
	if not gizmo.target_eid or not x or not y then
		return
	end
	local deltaPos
	if move_axis == gizmo.txy or move_axis == gizmo.tyz or move_axis == gizmo.tzx then
		local gizmoTPos = math3d.totable(iom.get_position(gizmo.root_eid))
		local downpos = mouse_hit_plane(last_mouse_pos, {dir = gizmo_dir_to_world(move_axis.dir), pos = gizmoTPos})
		local curpos = mouse_hit_plane({x, y}, {dir = gizmo_dir_to_world(move_axis.dir), pos = gizmoTPos})
		if downpos and curpos then
			local deltapos = math3d.totable(math3d.sub(curpos, downpos))
			deltaPos = {last_gizmo_pos[1] + deltapos[1], last_gizmo_pos[2] + deltapos[2], last_gizmo_pos[3] + deltapos[3]}
		end
	else
		local newOffset = utils.view_to_axis_constraint(iom.ray(camera_mgr.main_camera, {x, y}), iom.get_position(camera_mgr.main_camera), gizmo_dir_to_world(move_axis.dir), last_gizmo_pos)
		local deltaOffset = math3d.totable(math3d.sub(newOffset, init_offset))
		deltaPos = {last_gizmo_pos[1] + deltaOffset[1], last_gizmo_pos[2] + deltaOffset[2], last_gizmo_pos[3] + deltaOffset[3]}
	end

	gizmo:set_position(deltaPos)
	gizmo:update_scale()
	is_tran_dirty = true
	world:pub {"Gizmo", "update"}
end

local function show_rotate_fan(rotAxis, startAngle, deltaAngle)
	world[rotAxis.eid[3]]._rendercache.ib.num = 0
	world[rotAxis.eid[4]]._rendercache.ib.num = 0
	local start
	local num
	local stepAngle = gizmo_const.ROTATE_SLICES / 360
	if deltaAngle > 0 then
		start = math.floor(startAngle * stepAngle) * 3
		local totalAngle = startAngle + deltaAngle
		if totalAngle > 360 then
			local extraAngle = (totalAngle - 360)
			deltaAngle = deltaAngle - extraAngle
			world[rotAxis.eid[4]]._rendercache.ib.start = 0
			world[rotAxis.eid[4]]._rendercache.ib.num = math.floor(extraAngle * stepAngle) * 3
		end
		num = math.floor(deltaAngle * stepAngle + 1) * 3
	else
		local extraAngle = startAngle + deltaAngle
		if extraAngle < 0 then
			start = 0
			num = math.floor(startAngle * stepAngle) * 3
			world[rotAxis.eid[4]]._rendercache.ib.start = math.floor((360 + extraAngle) * stepAngle) * 3
			world[rotAxis.eid[4]]._rendercache.ib.num = math.floor(-extraAngle * stepAngle + 1) * 3
		else
			num = math.floor(-deltaAngle * stepAngle + 1) * 3
			start = math.floor(startAngle * stepAngle) * 3 - num
			if start < 0 then
				num = num + start
				start = 0
			end
		end
	end
	world[rotAxis.eid[3]]._rendercache.ib.start = start
	world[rotAxis.eid[3]]._rendercache.ib.num = num

	ies.set_state(rotAxis.eid[3], "visible", world[rotAxis.eid[3]]._rendercache.ib.num > 0)
	ies.set_state(rotAxis.eid[4], "visible", world[rotAxis.eid[4]]._rendercache.ib.num > 0)
end

local function rotate_gizmo(x, y)
	if not x or not y then return end
	local axis_dir = (rotate_axis ~= gizmo.rw) and gizmo_dir_to_world(rotate_axis.dir) or rotate_axis.dir
	local gizmoPos = iom.get_position(gizmo.root_eid)
	local hitPosVec = mouse_hit_plane({x, y}, {dir = axis_dir, pos = math3d.totable(gizmoPos)})
	if not hitPosVec then
		return
	end
	local gizmo_to_last_hit = math3d.normalize(math3d.sub(last_hit, gizmoPos))
	local tangent = math3d.normalize(math3d.cross(axis_dir, gizmo_to_last_hit))
	local proj_len = math3d.dot(tangent, math3d.sub(hitPosVec, last_hit))
	
	local angleBaseDir = gizmo_dir_to_world(math3d.vector(1, 0, 0))
	if rotate_axis == gizmo.rx then
		angleBaseDir = gizmo_dir_to_world(math3d.vector(0, 0, -1))
	elseif rotate_axis == gizmo.rw then
		angleBaseDir = math3d.normalize(math3d.cross(math3d.vector(0, 1, 0), axis_dir))
	end
	
	local deltaAngle = proj_len * 200 / gizmo_scale
	if deltaAngle > 360 then
		deltaAngle = deltaAngle - 360
	elseif deltaAngle < -360 then
		deltaAngle = deltaAngle + 360
	end
	if math.abs(deltaAngle) < 0.0001 then
		return
	end
	local tableGizmoToLastHit
	if local_space and rotate_axis ~= gizmo.rw then
		tableGizmoToLastHit = math3d.totable(math3d.transform(math3d.inverse(iom.get_rotation(gizmo.root_eid)), gizmo_to_last_hit, 0))
	else
		tableGizmoToLastHit = math3d.totable(gizmo_to_last_hit)
	end
	local isTop  = tableGizmoToLastHit[2] > 0
	if rotate_axis == gizmo.ry then
		isTop = tableGizmoToLastHit[3] > 0
	end
	local angle = math.deg(math.acos(math3d.dot(gizmo_to_last_hit, angleBaseDir)))
	if not isTop then
		angle = 360 - angle
	end

	show_rotate_fan(rotate_axis, angle, (rotate_axis == gizmo.ry) and -deltaAngle or deltaAngle)
	
	local quat = math3d.quaternion { axis = last_rotate_axis, r = math.rad(deltaAngle) }
	
	gizmo:set_rotation(math3d.mul(last_rotate, quat))
	if local_space then
		iom.set_rotation(gizmo.rot_circle_root_eid, quat)
	end
	is_tran_dirty = true
	world:pub {"Gizmo", "update"}
end

local function scale_gizmo(x, y)
	if not x or not y then return end
	local newScale
	if uniform_scale then
		local delta_x = x - last_mouse_pos[1]
		local delta_y = last_mouse_pos[2] - y
		local factor = (delta_x + delta_y) / 60.0
		local scaleFactor = 1.0
		if factor < 0 then
			scaleFactor = 1 / (1 + math.abs(factor))
		else
			scaleFactor = 1 + factor
		end
		newScale = {last_gizmo_scale[1] * scaleFactor, last_gizmo_scale[2] * scaleFactor, last_gizmo_scale[3] * scaleFactor}
	else
		newScale = {last_gizmo_scale[1], last_gizmo_scale[2], last_gizmo_scale[3]}
		local newOffset = utils.view_to_axis_constraint(iom.ray(camera_mgr.main_camera, {x, y}), iom.get_position(camera_mgr.main_camera), gizmo_dir_to_world(move_axis.dir), last_gizmo_pos)
		local deltaOffset = math3d.totable(math3d.sub(newOffset, init_offset))
		local scaleFactor = (1.0 + 3.0 * math3d.length(deltaOffset))
		if move_axis.dir == gizmo_const.DIR_X then
			if deltaOffset[1] < 0 then
				newScale[1] = last_gizmo_scale[1] / scaleFactor
			else
				newScale[1] = last_gizmo_scale[1] * scaleFactor
			end
		elseif move_axis.dir == gizmo_const.DIR_Y then
			if deltaOffset[2] < 0 then
				newScale[2] = last_gizmo_scale[2] / scaleFactor
			else
				newScale[2] = last_gizmo_scale[2] * scaleFactor
			end
			
		elseif move_axis.dir == gizmo_const.DIR_Z then
			if deltaOffset[3] < 0 then
				newScale[3] = last_gizmo_scale[3] / scaleFactor
			else
				newScale[3] = last_gizmo_scale[3] * scaleFactor
			end
		end

	end
	gizmo:set_scale(newScale)
	is_tran_dirty = true
	world:pub {"Gizmo", "update"}
end


function gizmo:select_gizmo(x, y)
	if not x or not y then return false end
	if self.mode == gizmo_const.MOVE or self.mode == gizmo_const.SCALE then
		move_axis = select_axis(x, y)
		gizmo:highlight_axis_or_plane(move_axis)
		if move_axis or uniform_scale then
			last_mouse_pos = {x, y}
			last_gizmo_scale = math3d.totable(iom.get_scale(gizmo.target_eid))
			if move_axis then
				last_gizmo_pos = math3d.totable(iom.get_position(gizmo.root_eid))
				init_offset.v = utils.view_to_axis_constraint(iom.ray(camera_mgr.main_camera, {x, y}), iom.get_position(camera_mgr.main_camera), gizmo_dir_to_world(move_axis.dir), last_gizmo_pos)
			end
			return true
		end
	elseif self.mode == gizmo_const.ROTATE then
		rotate_axis, last_hit.v = select_rotate_axis(x, y)
		if rotate_axis then
			last_rotate.q = iom.get_rotation(gizmo.target_eid)
			if rotate_axis == gizmo.rw or not local_space then
				last_rotate_axis.v = math3d.transform(math3d.inverse(iom.get_rotation(gizmo.target_eid)), rotate_axis.dir, 0)
			else
				last_rotate_axis.v = rotate_axis.dir
			end
			return true
		end
	end
	return false
end

local keypress_mb = world:sub{"keyboard"}
local viewpos_event = world:sub{"ViewportDirty"}
local mouse_pos_x
local mouse_pos_y
local imgui = require "imgui"
local function on_mouse_move()
	if gizmo_seleted then return end
	local viewport = imgui.GetMainViewport()
	local io = imgui.IO
	local is_mouse_move = false
	local wx = io.MousePos[1] - viewport.MainPos[1]
	local wy = io.MousePos[2] - viewport.MainPos[2]
	if mouse_pos_x ~= wx then
		mouse_pos_x = wx
		is_mouse_move = true
	end
	if mouse_pos_y ~= wy then
		mouse_pos_y = wy
		is_mouse_move = true
	end
	if is_mouse_move and gizmo.mode ~= gizmo_const.SELECT then
		local vx, vy = utils.mouse_pos_in_view(mouse_pos_x, mouse_pos_y)
		if vx and vy then
			if gizmo.mode == gizmo_const.MOVE or gizmo.mode == gizmo_const.SCALE then
				local axis = select_axis(vx, vy)
				gizmo:highlight_axis_or_plane(axis)
			elseif gizmo.mode == gizmo_const.ROTATE then
				gizmo:hide_rotate_fan()
				select_rotate_axis(vx, vy)
			end
		end
	end
end

function gizmo_sys:data_changed()
	for _, vp in viewpos_event:unpack() do
		global_data.viewport = vp
		update_global_axis()
	end

	for _ in camera_zoom:unpack() do
		gizmo:update_scale()
	end

	for _, what, value in gizmo_mode_event:unpack() do
		if what == "select" then
			gizmo:on_mode(gizmo_const.SELECT)
		elseif what == "rotate" then
			gizmo:on_mode(gizmo_const.ROTATE)
		elseif what == "move" then
			gizmo:on_mode(gizmo_const.MOVE)
		elseif what == "scale" then
			gizmo:on_mode(gizmo_const.SCALE)
		elseif what == "localspace" then
			local_space = value
			gizmo:update_axis_plane()
			gizmo:set_rotation()
		end
	end

	for _, what, x, y in mouse_down:unpack() do
		if what == "LEFT" then
			gizmo_seleted = gizmo:select_gizmo(x, y)
			gizmo:click_axis_or_plane(move_axis)
			gizmo:click_axis(rotate_axis)
		elseif what == "MIDDLE" then
			
		end
	end

	for _, what, x, y in mouse_up:unpack() do
		if what == "LEFT" then
			gizmo:reset_move_axis_color()
			if gizmo.mode == gizmo_const.ROTATE then
				--gizmo:hide_rotate_fan()
				if local_space then
					if gizmo.target_eid then
						iom.set_rotation(gizmo.root_eid, iom.get_rotation(gizmo.target_eid))
					end
					iom.set_rotation(gizmo.rot_circle_root_eid, math3d.quaternion{0,0,0})
				end
			end
			gizmo_seleted = false
			if is_tran_dirty then
				is_tran_dirty = false
				local target = gizmo.target_eid
				if target then
					if gizmo.mode == gizmo_const.SCALE then
						cmd_queue:record({action = gizmo_const.SCALE, eid = target, oldvalue = last_gizmo_scale, newvalue = math3d.totable(iom.get_scale(target))})
					elseif gizmo.mode == gizmo_const.ROTATE then
						cmd_queue:record({action = gizmo_const.ROTATE, eid = target, oldvalue = math3d.totable(last_rotate), newvalue = math3d.totable(iom.get_rotation(target))})
					elseif gizmo.mode == gizmo_const.MOVE then
						local localPos = math3d.totable(math3d.transform(math3d.inverse(iom.calc_worldmat(world[target].parent)), last_gizmo_pos, 1))
						cmd_queue:record({action = gizmo_const.MOVE, eid = target, oldvalue = localPos, newvalue = math3d.totable(iom.get_position(target))})
					end
				end
			end
		elseif what == "RIGHT" then
			gizmo:update_axis_plane()
		end
	end
	
	on_mouse_move()

	-- for _, what, x, y in mouse_move:unpack() do
	-- 	if what == "UNKNOWN" then
	-- 		mouse_pos_x_in_view, mouse_pos_y_in_view = x, y
	-- 		if gizmo.mode == gizmo_const.MOVE or gizmo.mode == gizmo_const.SCALE then
	-- 			local axis = select_axis(x, y)
	-- 			gizmo:highlight_axis_or_plane(axis)
	-- 		elseif gizmo.mode == gizmo_const.ROTATE then
	-- 			gizmo:hide_rotate_fan()
	-- 			select_rotate_axis(x, y)
	-- 		end
	-- 	end
	-- end
	
	for _, what, x, y, dx, dy in mouse_drag:unpack() do
		if what == "LEFT" then
			if gizmo.mode == gizmo_const.MOVE and move_axis then
				move_gizmo(x, y)
			elseif gizmo.mode == gizmo_const.SCALE then
				if move_axis or uniform_scale then
					scale_gizmo(x, y)
				end
			elseif gizmo.mode == gizmo_const.ROTATE and rotate_axis then
				rotate_gizmo(x, y)
			else
				world:pub { "camera", "pan", dx, dy }
			end
		elseif what == "RIGHT" then
			world:pub { "camera", "rotate", dx, dy }
			gizmo:update_scale()
			gizmo:updata_uniform_scale()
		end
	end
	
	for _,pick_id,pick_ids in pickup_mb:unpack() do
        local eid = pick_id
		if eid and world[eid] then
			if gizmo.mode ~= gizmo_const.SELECT and not gizmo_seleted then
				gizmo:set_target(eid)
			end
		else
			if not gizmo_seleted and not camera_mgr.select_frustum then
				local vx, vy = utils.mouse_pos_in_view(mouse_pos_x, mouse_pos_y)
				if vx and vy then
					gizmo:set_target(nil)
				end
			end
		end
	end
	for _, key, press, state in keypress_mb:unpack() do
		if state.CTRL then
			if key == "Z" then
				if press == 1 then
					cmd_queue:undo()
				end
			elseif key == "Y" then
				if press == 1 then
					cmd_queue:redo()
				end
			end
		end
	end
	update_global_axis()
end
