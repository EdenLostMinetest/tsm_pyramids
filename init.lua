local S = minetest.get_translator("tsm_pyramids")

tsm_pyramids = {}

dofile(minetest.get_modpath("tsm_pyramids").."/mummy.lua")
dofile(minetest.get_modpath("tsm_pyramids").."/nodes.lua")
dofile(minetest.get_modpath("tsm_pyramids").."/room.lua")

local chest_stuff = {
	{name="default:apple", max = 3},
	{name="default:steel_ingot", max = 3},
	{name="default:copper_ingot", max = 3},
	{name="default:gold_ingot", max = 2},
	{name="default:diamond", max = 1},
	{name="default:pick_steel", max = 1},
	{name="default:pick_diamond", max = 1},
	{name="default:papyrus", max = 9},
}

if minetest.get_modpath("farming") then
	table.insert(chest_stuff, {name="farming:bread", max = 3})
	table.insert(chest_stuff, {name="farming:cotton", max = 8})
else
	table.insert(chest_stuff, {name="farming:apple", max = 8})
	table.insert(chest_stuff, {name="farming:apple", max = 3})
end
if minetest.get_modpath("tnt") then
	table.insert(chest_stuff, {name="tnt:gunpowder", max = 6})
else
	table.insert(chest_stuff, {name="farming:apple", max = 3})
end

function tsm_pyramids.fill_chest(pos, stype, flood_sand)
	minetest.after(2, function()
		local sand = "default:sand"
		if stype == "desert" then
			sand = "default:desert_sand"
		end
		local n = minetest.get_node(pos)
		if n and n.name and n.name == "default:chest" then
			local meta = minetest.get_meta(pos)
			local inv = meta:get_inventory()
			inv:set_size("main", 8*4)
			local stacks = {}
			-- Fill with sand in sand-flooded pyramids
			if flood_sand then
				table.insert(stacks, {name=sand, count = math.random(1,32)})
			end
			-- Add treasures
			if math.random(1,10) >= 7 then
				if minetest.get_modpath("treasurer") ~= nil then
					stacks = treasurer.select_random_treasures(3,7,9,{"minetool", "food", "crafting_component"})
				else
					for i=0,2,1 do
						local stuff = chest_stuff[math.random(1,#chest_stuff)]
						table.insert(stacks, {name=stuff.name, count = math.random(1,stuff.max)})
					end
				end
			end
			for s=1,#stacks do
				if not inv:contains_item("main", stacks[s]) then
					inv:set_stack("main", math.random(1,32), stacks[s])
				end
			end

		end
	end)
end

local function add_spawner(pos)
	minetest.set_node(pos, {name="tsm_pyramids:spawner_mummy"})
	if not minetest.settings:get_bool("only_peaceful_mobs") then tsm_pyramids.spawn_mummy({x=pos.x,y=pos.y,z=pos.z-2},2) end
end

local function can_replace(pos)
	local n = minetest.get_node_or_nil(pos)
	if n and n.name and minetest.registered_nodes[n.name] and not minetest.registered_nodes[n.name].walkable then
		return true
	elseif not n then
		return true
	else
		return false
	end
end

local function underground(pos, stone, sand)
	local p2 = pos
	local cnt = 0
	local mat = stone
	p2.y = p2.y-1
	while can_replace(p2)==true do
		cnt = cnt+1
		if cnt > 25 then break end
		if cnt>math.random(2,4) then mat = stone end
		minetest.set_node(p2, {name=mat})
		p2.y = p2.y-1
	end
end

local function make_entrance(pos, brick, sand, flood_sand)
	local gang = {x=pos.x+10,y=pos.y, z=pos.z}
	local max_sand_height = math.random(1,3)
	for iz=0,6,1 do
		local sand_height = math.random(1,max_sand_height)
		for iy=2,3,1 do
			if flood_sand and iy <= sand_height and iz >= 3 then
				minetest.set_node({x=gang.x+1,y=gang.y+iy,z=gang.z+iz}, {name=sand})
			else
				minetest.remove_node({x=gang.x+1,y=gang.y+iy,z=gang.z+iz})
			end
			if iz >=3 and iy == 3 then
				minetest.set_node({x=gang.x,y=gang.y+iy+1,z=gang.z+iz}, {name=brick})
				minetest.set_node({x=gang.x+1,y=gang.y+iy+1,z=gang.z+iz}, {name=brick})
				minetest.set_node({x=gang.x+2,y=gang.y+iy+1,z=gang.z+iz}, {name=brick})
			end
		end
	end
end

local function make(pos, brick, sandstone, stone, sand, ptype, room_id)
	for iy=0,10,1 do
		for ix=iy,22-iy,1 do
			for iz=iy,22-iy,1 do
			if iy <1 then underground({x=pos.x+ix,y=pos.y,z=pos.z+iz}, stone, sand) end
				minetest.set_node({x=pos.x+ix,y=pos.y+iy,z=pos.z+iz}, {name=brick})
				for yy=1,10-iy,1 do
					local n = minetest.get_node({x=pos.x+ix,y=pos.y+iy+yy,z=pos.z+iz})
					if n and n.name and n.name == stone then
						minetest.set_node({x=pos.x+ix,y=pos.y+iy+yy,z=pos.z+iz},{name=sand})
					end
				end
			end
		end
	end
	local ok, msg, flood_sand = tsm_pyramids.make_room(pos, ptype, room_id)
	add_spawner({x=pos.x+11,y=pos.y+2, z=pos.z+17})
	make_entrance({x=pos.x,y=pos.y, z=pos.z}, brick, sand, flood_sand)
	minetest.log("action", "Created pyramid at ("..pos.x..","..pos.y..","..pos.z..")")
	return ok, msg
end

local perl1 = {SEED1 = 9130, OCTA1 = 3,	PERS1 = 0.5, SCAL1 = 250} -- Values should match minetest mapgen V6 desert noise.
local perlin1

local function hlp_fnct(pos, name)
	local n = minetest.get_node_or_nil(pos)
	if n and n.name and n.name == name then
		return true
	else
		return false
	end
end
local function ground(pos, old)
	local p2 = pos
	while hlp_fnct(p2, "air") do
		p2.y = p2.y -1
	end
	if p2.y < old.y then
		return p2
	else
		return old
	end
end


minetest.register_on_generated(function(minp, maxp, seed)
	if maxp.y < 0 then return end
	math.randomseed(seed)
	local cnt = 0
	if not perlin1 then
		perlin1 = minetest.get_perlin(perl1.SEED1, perl1.OCTA1, perl1.PERS1, perl1.SCAL1)
	end
	local noise1 = perlin1:get_2d({x=minp.x,y=minp.y})--,z=minp.z})

	if noise1 > 0.25 or noise1 < -0.26 then
		local mpos = {x=math.random(minp.x,maxp.x), y=math.random(minp.y,maxp.y), z=math.random(minp.z,maxp.z)}

		local sands = {"default:desert_sand", "default:sand"}
		local p2
		local sand
		for s=1, #sands do
			sand = sands[s]
			p2 = minetest.find_node_near(mpos, 25, sand)
			while p2 == nil and cnt < 5 do
				cnt = cnt+1
				mpos = {x=math.random(minp.x,maxp.x), y=math.random(minp.y,maxp.y), z=math.random(minp.z,maxp.z)}
				p2 = minetest.find_node_near(mpos, 25, sand)
			end
			if p2 ~= nil then
				break
			end
		end
		if p2 == nil then return end
		if p2.y < 0 then return end

		local off = 0
		local opos1 = {x=p2.x+22,y=p2.y-1,z=p2.z+22}
		local opos2 = {x=p2.x+22,y=p2.y-1,z=p2.z}
		local opos3 = {x=p2.x,y=p2.y-1,z=p2.z+22}
		local opos1_n = minetest.get_node_or_nil(opos1)
		local opos2_n = minetest.get_node_or_nil(opos2)
		local opos3_n = minetest.get_node_or_nil(opos3)
		if opos1_n and opos1_n.name and opos1_n.name == "air" then
			p2 = ground(opos1, p2)
		end
		if opos2_n and opos2_n.name and opos2_n.name == "air" then
			p2 = ground(opos2, p2)
		end
		if opos3_n and opos3_n.name and opos3_n.name == "air" then
			p2 = ground(opos3, p2)
		end
		p2.y = p2.y - 3
		if p2.y < 0 then p2.y = 0 end
		if minetest.find_node_near(p2, 25, {"default:water_source"}) ~= nil or 
				minetest.find_node_near(p2, 22, {"default:dirt_with_grass"}) ~= nil or
				minetest.find_node_near(p2, 52, {"default:sandstonebrick"}) ~= nil or
				minetest.find_node_near(p2, 52, {"default:desert_sandstone_brick"}) ~= nil then
			return
		end
	
		if math.random(0,10) > 7 then
			return
		end
		if sand == "default:desert_sand" then
			minetest.after(0.8, make, p2, "default:desert_sandstone_brick", "default:desert_sandstone", "default:desert_stone", "default:desert_sand", "desert")
		else
			minetest.after(0.8, make, p2, "default:sandstonebrick", "default:sandstone", "default:sandstone", "default:sand", "sandstone")
		end
	end
end)

-- Add backwards-compability for nodes from the original pyramids mod
if minetest.get_modpath("pyramids") == nil then
	-- Nodes
	minetest.register_alias("pyramids:trap", "tsm_pyramids:trap")
	minetest.register_alias("pyramids:trap_2", "tsm_pyramids:trap_2")
	minetest.register_alias("pyramids:deco_stone1", "tsm_pyramids:deco_stone1")
	minetest.register_alias("pyramids:deco_stone2", "tsm_pyramids:deco_stone2")
	minetest.register_alias("pyramids:deco_stone3", "tsm_pyramids:deco_stone3")
	minetest.register_alias("pyramids:spawner_mummy", "tsm_pyramids:spawner_mummy")

	-- FIXME: Entities are currently NOT backwards-compatible
	-- TODO: Update README when full backwards-compability is achieved
end

minetest.register_chatcommand("spawnpyramid", {
	description = S("Generate a pyramid"),
		params = S("[<room_type>]"),
		privs = { server = true },
		func = function(name, param)
			local player = minetest.get_player_by_name(name)
			if not player then
				return false, S("No player.")
			end
			local pos = player:get_pos()
			pos = vector.round(pos)
			local s = math.random(1,2)
			local r = tonumber(param)
			local room_id
			if r then
				room_id = r
			end
			local ok, msg
			if s == 1 then
				ok, msg = make(pos, "default:sandstonebrick", "default:sandstone", "default:sandstone", "default:sand", "sandstone", room_id)
			else
				ok, msg = make(pos, "default:desert_sandstone_brick", "default:desert_sandstone", "default:desert_stone", "default:desert_sand", "desert", room_id)
			end
			if ok then
				return true, S("Pyramid generated at @1.", minetest.pos_to_string(pos))
			else
				return false, msg
			end
		end,
	}
)
