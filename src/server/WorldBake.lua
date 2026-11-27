-- WorldBake: the map is baked once and saved in the place, so a server never has to
-- raise the islands or carve the caves again. Everything made of terrain (islands, sea
-- floor, caves, grottos, terrain landmarks) loads with the place; the server only lays
-- the parts (trees, ores, props, NPCs) on top, which is quick.
--
-- How a bake is made (Studio only):
--   1. Run Play with no bake in the place (or BakeVersion out of date). The world is
--      built the slow way, then copied into ServerStorage.WorldBake (a TerrainRegion of
--      the whole map, and the cave network as text).
--   2. In the Server view, copy ServerStorage.WorldBake, stop, paste it into
--      ServerStorage, and run in the command bar:
--        require(game.ServerScriptService.Server.WorldBake).install()
--      That pastes the terrain into the place and marks it baked. Save the place.
-- Bump VERSION whenever terrain code changes, so the old bake is ignored until re-baked.
local WorldBake = {}

local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")

WorldBake.VERSION = 1

local real = workspace.Terrain

local function bakeFolder(): Instance?
	return ServerStorage:FindFirstChild("WorldBake")
end

WorldBake.baked = real:GetAttribute("BakeVersion") == WorldBake.VERSION
	and bakeFolder() ~= nil
	and (bakeFolder() :: Instance):GetAttribute("Version") == WorldBake.VERSION

-- Calls that change terrain voxels. While the map is baked, the world builder's calls
-- to these do nothing (the voxels are already there); everything else goes through.
local WRITES = {
	Clear = true,
	FillBall = true,
	FillBlock = true,
	FillCylinder = true,
	FillWedge = true,
	FillRegion = true,
	ReplaceMaterial = true,
	WriteVoxels = true,
	PasteRegion = true,
}

-- Stands in for workspace.Terrain in world-building code.
WorldBake.terrain = setmetatable({}, {
	__index = function(_, key)
		local v = (real :: any)[key]
		if typeof(v) == "function" then
			return function(_, ...)
				if WorldBake.baked and WRITES[key] then
					return nil
				end
				return v(real, ...)
			end
		end
		return v
	end,
	__newindex = function(_, key, value)
		(real :: any)[key] = value
	end,
}) :: any

-- Encodes a table of plain values, Vector3s and CFrames (shared and nested tables kept)
-- as JSON, and back again.
local function encode(root: any): string
	local ids, list = {}, {}
	local function enc(v: any): any
		local t = typeof(v)
		if t == "Vector3" then
			return { v = { v.X, v.Y, v.Z } }
		elseif t == "CFrame" then
			return { c = { v:GetComponents() } }
		elseif t == "table" then
			if not ids[v] then
				local id = #list + 1
				ids[v] = id
				list[id] = false
				local pairs_ = {}
				for k, x in v do
					table.insert(pairs_, { enc(k), enc(x) })
				end
				list[id] = pairs_
			end
			return { r = ids[v] }
		elseif t == "number" or t == "string" or t == "boolean" then
			return { p = v }
		end
		return { p = tostring(v) }
	end
	local top = enc(root)
	return HttpService:JSONEncode({ top = top, list = list })
end

local function decode(s: string): any
	local data = HttpService:JSONDecode(s)
	local made = {}
	for id in data.list do
		made[id] = {}
	end
	local function dec(v: any): any
		if v.v then
			return Vector3.new(v.v[1], v.v[2], v.v[3])
		elseif v.c then
			return CFrame.new(table.unpack(v.c))
		elseif v.r then
			return made[v.r]
		end
		return v.p
	end
	for id, pairs_ in data.list do
		local t = made[id]
		for _, kv in pairs_ do
			t[dec(kv[1])] = dec(kv[2])
		end
	end
	return dec(data.top)
end

local CHUNK = 150000

-- The cave network saved with the bake (the result of Caves.build).
function WorldBake.loadNetwork(): any
	local f = bakeFolder() :: Instance
	local parts = {}
	local n = f:GetAttribute("Chunks") or 0
	for i = 1, n do
		table.insert(parts, (f:FindFirstChild("Network" .. i) :: StringValue).Value)
	end
	return decode(table.concat(parts))
end

-- After a slow build in Studio: copies the terrain and the cave network into
-- ServerStorage.WorldBake, ready to be copied into the place.
-- lo, hi: the corners of the world in studs.
function WorldBake.save(network: any, lo: Vector3, hi: Vector3)
	local old = bakeFolder()
	if old then
		old:Destroy()
	end
	local f = Instance.new("Folder")
	f.Name = "WorldBake"
	local text = encode(network)
	local n = 0
	for i = 1, #text, CHUNK do
		n += 1
		local sv = Instance.new("StringValue")
		sv.Name = "Network" .. n
		sv.Value = string.sub(text, i, i + CHUNK - 1)
		sv.Parent = f
	end
	f:SetAttribute("Chunks", n)
	f:SetAttribute("Version", WorldBake.VERSION)
	local ok, err = pcall(function()
		local a = Vector3int16.new(math.floor(lo.X / 4), math.floor(lo.Y / 4), math.floor(lo.Z / 4))
		local b = Vector3int16.new(math.ceil(hi.X / 4), math.ceil(hi.Y / 4), math.ceil(hi.Z / 4))
		local region = real:CopyRegion(Region3int16.new(a, b))
		region.Name = "Terrain"
		region.Parent = f
	end)
	f.Parent = ServerStorage
	print(string.format("[WorldBake] saved: network %d chars in %d parts, terrain %s", #text, n, if ok then "copied" else "FAILED: " .. tostring(err)))
end

-- Run from the command bar (edit mode) after pasting ServerStorage.WorldBake: writes the
-- baked terrain into the place and marks it baked. Then save the place.
function WorldBake.install()
	local f = assert(bakeFolder(), "paste ServerStorage.WorldBake first")
	local region = f:FindFirstChild("Terrain") :: TerrainRegion
	assert(region, "WorldBake has no Terrain region")
	real:Clear()
	real:PasteRegion(region, region.ExtentsMin, true)
	real:SetAttribute("BakeVersion", f:GetAttribute("Version"))
	-- The region is big and the terrain now holds it: keep only the network text.
	region:Destroy()
	print("[WorldBake] installed version " .. tostring(f:GetAttribute("Version")) .. ": save the place")
end

return WorldBake
