local ecs = ...

local build_ik_tranform = ecs.transform "build_ik"

local function check_joints_in_hierarchy_chain(ske, joint_indices)
	for i=3, 2, -1 do
		local jidx = joint_indices[i]
		local pidx = ske:parent(jidx)

		local next_jidx = joint_indices[i-1]
		while pidx ~= next_jidx and pidx ~= 0 do
			pidx = ske:parent(pidx)
		end

		if pidx == 0 then
			error(string.format("ik joints can not use as foot ik, which joints must as parent clain:%d %d %d", joint_indices[1], joint_indices[2], joint_indices[3]))
		end
	end
end

function build_ik_tranform.process_prefab(e)
	local ske = e.skeleton._handle
	local ik = e.ik

	for _, ikdata in pairs(ik.jobs) do
		local joint_indices = {}
		for _, jn in ipairs(ikdata.joints) do
			local jointidx = ske:joint_index(jn)
			if jointidx == nil then
				error(string.format("invalid joint name:%s", jn))
			end

			joint_indices[#joint_indices+1] = jointidx
		end

		if e.ik.type == "two_bone" then
			assert(#joint_indices == 3)

			check_joints_in_hierarchy_chain(joint_indices)
		end
		ikdata._joint_indices = joint_indices
	end
end

local ikdata_cache = {}
local function prepare_ikdata(ikdata)
	ikdata_cache.type		= ikdata.type
	ikdata_cache.target 	= ikdata.target.p
	ikdata_cache.pole_vector= ikdata.pole_vector.p
	ikdata_cache.weight		= ikdata.weight
	ikdata_cache.twist_angle= ikdata.twist_angle
	ikdata_cache.joint_indices= ikdata._joint_indices

	if ikdata.type == "aim" then
		ikdata_cache.forward	= ikdata.forward.p
		ikdata_cache.up_axis	= ikdata.up_axis.p
		ikdata_cache.offset		= ikdata.offset.p
	else
		assert(ikdata.type == "two_bone")
		ikdata_cache.soften		= ikdata.soften
		ikdata_cache.mid_axis	= ikdata.mid_axis.p
	end
	return ikdata_cache
end

local ik_i = {}

function ik_i.setup(e)
	local skehandle = e.skeleton._handle
	e.pose_result:setup(skehandle)
end

function ik_i.do_ik(pr, ikdata)
	pr:do_ik(prepare_ikdata(ikdata))
end

return ik_i
