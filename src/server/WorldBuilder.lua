-- Builds the world when the server starts: a ring of five outer islands (one biome
-- each, Clover Island as the spawn) around a late-game middle island, in Smooth Terrain, plus trees, rocks,
-- bushes, slime pools, boars, a quest board and a trader. Every island has a
-- hand-designed shape (CloverIsland.lua, IslandFields.lua) with named zones that
-- decide what grows where.
-- (The hand-built v2 map replaces this in a later milestone.)
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Nodes = require(Shared.Nodes)
local Meshes = require(Shared.Meshes)
local Remotes = require(Shared.Remotes)
local Animals = require(script.Parent.Animals)
local CloverIsland = require(script.Parent.CloverIsland)
local IslandFields = require(script.Parent.IslandFields)

local WorldBuilder = {}
local rng = Random.new(1911)

local COLORS = {
	trunk = Color3.fromRGB(122, 88, 58),
	trunkDark = Color3.fromRGB(96, 68, 44),
	pine = Color3.fromRGB(52, 112, 64),
	pineDark = Color3.fromRGB(40, 92, 54),
	palmLeaf = Color3.fromRGB(86, 158, 66),
	coconut = Color3.fromRGB(105, 72, 45),
	rock = Color3.fromRGB(132, 132, 138),
	rockDark = Color3.fromRGB(104, 104, 112),
	bush = Color3.fromRGB(70, 132, 58),
	berry = Color3.fromRGB(196, 40, 66),
	slime = Color3.fromRGB(122, 214, 84),
}

local function part(model: Model, props): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(p :: any)[key] = value
	end
	p:SetAttribute("BaseTransparency", p.Transparency)
	p:SetAttribute("BaseCollide", p.CanCollide)
	p.Parent = model
	return p
end

local function folder(name: string): Folder
	local old = workspace:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = workspace
	return f
end

-- Low-poly node models (each stands on the origin) ----------------------------------

local function makePine(cf: CFrame): Model
	local m = Instance.new("Model")
	local scale = rng:NextNumber(0.85, 1.25)
	local trunkH = 7 * scale
	local trunk = part(m, { Name = "Trunk", Size = Vector3.new(1.4, trunkH, 1.4) * Vector3.new(scale, 1, scale), CFrame = cf * CFrame.new(0, trunkH / 2, 0), Color = COLORS.trunk, Material = Enum.Material.Wood })
	-- Stacked, alternately-rotated tiers read as a faceted low-poly pine.
	local y = trunkH * 0.55
	local width = 7.5 * scale
	for tier = 1, 4 do
		local h = 3.2 * scale
		local color = if tier % 2 == 0 then COLORS.pine else COLORS.pineDark
		for k = 0, 1 do
			part(m, { Name = "Needles", Size = Vector3.new(width, h, width), CFrame = cf * CFrame.new(0, y + h / 2, 0) * CFrame.Angles(0, math.rad(k * 45 + tier * 20), 0), Color = color })
		end
		y += h * 0.8
		width *= 0.68
	end
	part(m, { Name = "Top", Size = Vector3.new(1.2, 1.8, 1.2) * scale, CFrame = cf * CFrame.new(0, y + 0.6, 0) * CFrame.Angles(0, math.rad(45), 0), Color = COLORS.pine })
	m.PrimaryPart = trunk
	trunk.PivotOffset = trunk.CFrame:Inverse() * cf
	return m
end

local function makePalm(cf: CFrame): Model
	local m = Instance.new("Model")
	local lean = CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(5, 12)))
	local c = cf * lean
	local trunk
	local segH = 2.6
	for i = 0, 5 do
		local w = 1.5 - i * 0.12
		local seg = part(m, { Name = if i == 0 then "Trunk" else "Segment", Size = Vector3.new(w, segH + 0.15, w), CFrame = c * CFrame.new(0, segH * (i + 0.5), 0) * CFrame.Angles(0, math.rad(i * 25), 0), Color = if i % 2 == 0 then COLORS.trunk else COLORS.trunkDark, Material = Enum.Material.Wood })
		if i == 0 then
			trunk = seg
		end
		c = c * CFrame.Angles(0, 0, math.rad(2.5))
	end
	local top = c * CFrame.new(0, segH * 6, 0)
	for i = 0, 6 do
		local yaw = i / 7 * math.pi * 2
		-- Each frond is two drooping planks.
		local base = top * CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.rad(-12), 0, 0)
		part(m, { Name = "Frond", Size = Vector3.new(1.9, 0.2, 3.6), CFrame = base * CFrame.new(0, 0, -1.8), Color = COLORS.palmLeaf, CanCollide = false })
		part(m, { Name = "Frond", Size = Vector3.new(1.5, 0.2, 3.2), CFrame = base * CFrame.new(0, 0, -3.4) * CFrame.Angles(math.rad(-28), 0, 0) * CFrame.new(0, 0, -1.4), Color = COLORS.palmLeaf:Lerp(Color3.new(0, 0, 0), 0.12), CanCollide = false })
	end
	for i = 0, 2 do
		part(m, { Name = "Coconut", Shape = Enum.PartType.Ball, Size = Vector3.new(0.9, 0.9, 0.9), CFrame = top * CFrame.Angles(0, i * 2.1, 0) * CFrame.new(0, -0.6, -0.65), Color = COLORS.coconut, CanCollide = false })
	end
	m.PrimaryPart = trunk
	trunk.PivotOffset = trunk.CFrame:Inverse() * cf
	return m
end

local function lump(m: Model, size: Vector3, cf: CFrame, color: Color3, name: string): Part
	local main = part(m, { Name = name, Size = size, CFrame = cf * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 6), rng:NextNumber(-0.4, 0.4)), Color = color, Material = Enum.Material.Slate })
	part(m, { Name = name, Size = size * Vector3.new(0.8, 0.75, 0.8), CFrame = cf * CFrame.new(0, size.Y * 0.2, 0) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), rng:NextNumber(0, 6)), Color = color:Lerp(Color3.new(1, 1, 1), 0.06), Material = Enum.Material.Slate })
	return main
end

local function makeBoulder(cf: CFrame): Model
	local m = Instance.new("Model")
	local s = rng:NextNumber(0.9, 1.3)
	local main = lump(m, Vector3.new(6, 4.5, 5.5) * s, cf * CFrame.new(0, 1.8 * s, 0), COLORS.rock, "Rock")
	lump(m, Vector3.new(3.4, 2.6, 3.2) * s, cf * CFrame.new(2.8 * s, 0.9 * s, 1.2 * s), COLORS.rockDark, "Rock")
	m.PrimaryPart = main
	main.PivotOffset = main.CFrame:Inverse() * cf
	return m
end

local function makeBush(cf: CFrame): Model
	local m = Instance.new("Model")
	local main
	for i = 1, 3 do
		local s = rng:NextNumber(2.4, 3.2)
		local p = part(m, { Name = "Leaves", Size = Vector3.new(s, s * 0.8, s), CFrame = cf * CFrame.new(rng:NextNumber(-1.1, 1.1), s * 0.35, rng:NextNumber(-1.1, 1.1)) * CFrame.Angles(rng:NextNumber(0, 1), rng:NextNumber(0, 6), rng:NextNumber(0, 1)), Color = COLORS.bush:Lerp(COLORS.pineDark, i * 0.2), Material = Enum.Material.Grass })
		main = main or p
	end
	for _ = 1, 6 do
		local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0.3, 1), rng:NextNumber(-1, 1)).Unit
		part(m, { Name = "Berry", Size = Vector3.new(0.45, 0.45, 0.45), CFrame = cf * CFrame.new(Vector3.new(0, 1.1, 0) + dir * 1.6) * CFrame.Angles(0.5, 0.5, 0), Color = COLORS.berry, CanCollide = false })
	end
	m.PrimaryPart = main
	main.PivotOffset = main.CFrame:Inverse() * cf
	return m
end

local function makeSlimePool(cf: CFrame): Model
	local m = Instance.new("Model")
	local pool = part(m, { Name = "Pool", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 6.5, 6.5), CFrame = cf * CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = COLORS.slime, Material = Enum.Material.Glass, Transparency = 0.15 })
	for _ = 1, 3 do
		local d = rng:NextNumber(1, 1.7)
		local blob = part(m, { Name = "Blob", Shape = Enum.PartType.Ball, Size = Vector3.new(d, d, d), CFrame = cf * CFrame.new(rng:NextNumber(-1.8, 1.8), 0.4 + d / 3, rng:NextNumber(-1.8, 1.8)), Color = COLORS.slime:Lerp(Color3.new(1, 1, 1), rng:NextNumber(0, 0.25)), Material = Enum.Material.Glass, Transparency = 0.1, CanCollide = false })
		blob:SetAttribute("Bob", true)
	end
	-- A ring of rocks so it reads as a pool, not a decal.
	for i = 0, 6 do
		local a = i / 7 * math.pi * 2
		part(m, { Name = "Rim", Size = Vector3.new(1.4, 0.9, 1.2), CFrame = cf * CFrame.new(math.cos(a) * 3.4, 0.3, math.sin(a) * 3.4) * CFrame.Angles(0.3, a, 0.2), Color = COLORS.rockDark, Material = Enum.Material.Slate })
	end
	m.PrimaryPart = pool
	pool.PivotOffset = pool.CFrame:Inverse() * cf
	return m
end

local makers = { Pine = makePine, Palm = makePalm, Boulder = makeBoulder, Bush = makeBush, SlimePool = makeSlimePool }

-- The Blender mesh for each node, and how much its size varies.
local NODE_MESHES = {
	Pine = { mesh = "pine", scale = { 0.9, 1.2 } },
	Palm = { mesh = "palm", scale = { 0.9, 1.15 } },
	Boulder = { mesh = "boulder", scale = { 0.85, 1.2 } },
	Bush = { mesh = "bush", scale = { 0.9, 1.15 } },
	SlimePool = { mesh = "slimepool", scale = { 1, 1 } },
}

-- Uses the imported mesh when the place has it, otherwise the block model.
local function makeNode(nodeType: string, cf: CFrame): Model
	local spec = NODE_MESHES[nodeType]
	local model = spec and Meshes.build(spec.mesh, { scale = rng:NextNumber(spec.scale[1], spec.scale[2]) })
	if model then
		model:PivotTo(cf * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
		return model
	end
	return makers[nodeType](cf)
end

-- Terrain ------------------------------------------------------------------------
-- Island Tribes-style layout: a ring of outer islands around a large middle island.
-- Each outer island is one biome with its own main resource; better resources sit
-- further out or in the middle, across water. Nothing is a safe island.

export type Island = {
	name: string,
	x: number,
	z: number,
	r: number, -- radius of the island's land (studs)
	biome: string,
}

local ISLANDS: { Island } = {
	{ name = "Clover Island", x = 0, z = 320, r = 110, biome = "clover" }, -- spawn, south
	{ name = "Pine Hills", x = -300, z = 90, r = 100, biome = "hills" },
	{ name = "Stone Shelf", x = 300, z = 90, r = 110, biome = "rock" },
	{ name = "Frost Isle", x = -190, z = -265, r = 95, biome = "snow" },
	{ name = "Slime Marsh", x = 195, z = -265, r = 96, biome = "marsh" },
	{ name = "Ember Isle", x = 0, z = 0, r = 115, biome = "ember" }, -- late game, middle
}
WorldBuilder.Islands = ISLANDS

-- What grows where. `cluster` = trees per clump (min, max).
local BIOME_NODES = {
	-- Clover Island is zoned per leaf: { node, count, clump?, zone }.
	clover = {
		{ "Pine", 24, { 2, 4 }, zone = "pines" },
		{ "Bush", 3, zone = "pines" },
		{ "Boulder", 2, zone = "pines" },
		{ "Boulder", 13, zone = "rocks" },
		{ "Pine", 2, { 1, 1 }, zone = "rocks" },
		{ "Palm", 14, { 1, 3 }, zone = "palms" },
		{ "Bush", 3, zone = "palms" },
		{ "Bush", 8, zone = "meadow" },
		{ "Pine", 3, { 1, 2 }, zone = "meadow" },
		{ "Boulder", 2, zone = "meadow" },
		{ "Pine", 3, { 1, 2 }, zone = "centre" },
		{ "Bush", 2, zone = "centre" },
	},
	-- The other islands are zoned too (see IslandFields.lua). "*" = anywhere.
	hills = { -- wood: thick clumps in the western forest, open meadow to the south
		{ "Pine", 30, { 2, 4 }, zone = "forest" },
		{ "Bush", 3, zone = "forest" },
		{ "Boulder", 3, zone = "forest" },
		{ "Pine", 4, { 1, 2 }, zone = "meadow" },
		{ "Bush", 8, zone = "meadow" },
		{ "Palm", 5, { 1, 2 }, zone = "shore" },
	},
	rock = { -- stone: boulders all over the stepped cliffs
		{ "Boulder", 16, zone = "cliffs" },
		{ "Boulder", 3, zone = "slope" },
		{ "Pine", 5, { 1, 2 }, zone = "slope" },
		{ "Bush", 4, zone = "slope" },
	},
	snow = {
		{ "Pine", 14, { 1, 3 }, zone = "slopes" },
		{ "Boulder", 6, zone = "peak" },
		{ "Boulder", 2, zone = "shore" },
	},
	marsh = { -- slime: pools on every islet
		{ "SlimePool", 8, zone = "*" },
		{ "Bush", 10, zone = "*" },
		{ "Pine", 2, { 1, 1 }, zone = "heart" },
	},
	ember = {
		{ "Boulder", 9, zone = "slopes" },
		{ "Boulder", 3, zone = "camp" },
	},
}

-- Spacing, in studs. Island Tribes keeps trees 20-40 studs apart with open ground
-- between, so you can always see the next one.
local CLUMP_SPACING = 30 -- between clumps of trees
local IN_CLUMP_SPACING = 7 -- between trees in one clump
local NODE_SPACING = 16 -- between any other nodes

local function lerpColor(a: Color3, b: Color3, t: number)
	return a:Lerp(b, t)
end

local function island(terrain: Terrain, isl: Island)
	local x, z, r = isl.x, isl.z, isl.r
	if isl.biome == "clover" then
		CloverIsland.fill(terrain, x, z)
		return
	end
	local field = IslandFields[isl.biome]
	if field then
		IslandFields.fill(field, terrain, x, z)
		return
	end
	local top = if isl.biome == "beach" then "Sand" else "Grass"
	-- Sand shelves stepping down into the water, then the beach.
	for k = 4, 1, -1 do
		terrain:FillCylinder(CFrame.new(x, 1.5 - k * 7 - 20, z), 40, r + 16 + k * 12, Enum.Material.Sand)
	end
	terrain:FillCylinder(CFrame.new(x, 1.5 - 20, z), 40, r + 16, Enum.Material.Sand)

	local core = {
		beach = Enum.Material.Grass,
		hills = Enum.Material.Grass,
		rock = Enum.Material.Rock,
		snow = Enum.Material.Snow,
		marsh = Enum.Material.LeafyGrass,
		ember = Enum.Material.Basalt,
	}
	local coreR = if top == "Sand" then r * 0.5 else r
	terrain:FillCylinder(CFrame.new(x, 3 - 20, z), 40, coreR, core[isl.biome])

	if isl.biome == "hills" then
		-- Rolling hills and a couple of inland lakes.
		for _ = 1, 7 do
			local a, d = rng:NextNumber(0, math.pi * 2), rng:NextNumber(0, r * 0.6)
			local rad = rng:NextNumber(20, 38)
			terrain:FillBall(Vector3.new(x + math.cos(a) * d, -rad * 0.6, z + math.sin(a) * d), rad, Enum.Material.Grass)
		end
		for _ = 1, 2 do
			local a, d = rng:NextNumber(0, math.pi * 2), rng:NextNumber(r * 0.2, r * 0.5)
			terrain:FillCylinder(CFrame.new(x + math.cos(a) * d, 1.6, z + math.sin(a) * d), 3, rng:NextNumber(10, 16), Enum.Material.Water)
		end
	elseif isl.biome == "rock" then
		-- Steep rock cliffs along the coast, grass between.
		terrain:FillCylinder(CFrame.new(x, 3.2 - 20, z), 40, r * 0.55, Enum.Material.Grass)
		for _ = 1, 9 do
			local a = rng:NextNumber(0, math.pi * 2)
			local rad = rng:NextNumber(14, 22)
			local d = r - rad * 0.35
			terrain:FillBall(Vector3.new(x + math.cos(a) * d, -rad * 0.1, z + math.sin(a) * d), rad, Enum.Material.Rock)
		end
	elseif isl.biome == "snow" then
		terrain:FillBall(Vector3.new(x, -16, z), 50, Enum.Material.Rock)
		terrain:FillBall(Vector3.new(x, -4, z), 40, Enum.Material.Snow)
	elseif isl.biome == "marsh" then
		for _ = 1, 5 do
			local a, d = rng:NextNumber(0, math.pi * 2), rng:NextNumber(0, r * 0.7)
			terrain:FillCylinder(CFrame.new(x + math.cos(a) * d, 2.4, z + math.sin(a) * d), 2, rng:NextNumber(8, 14), Enum.Material.Mud)
		end
	elseif isl.biome == "ember" then
		-- The late-game middle: a dark volcano ringed by cliffs.
		for _ = 1, 10 do
			local a = rng:NextNumber(0, math.pi * 2)
			local rad = rng:NextNumber(16, 26)
			local d = r - rad * 0.3
			terrain:FillBall(Vector3.new(x + math.cos(a) * d, -rad * 0.05, z + math.sin(a) * d), rad, Enum.Material.Basalt)
		end
		terrain:FillBall(Vector3.new(x, -30, z), 70, Enum.Material.Basalt)
		terrain:FillBall(Vector3.new(x, 26, z), 26, Enum.Material.Basalt)
		terrain:FillCylinder(CFrame.new(x, 50, z), 6, 9, Enum.Material.CrackedLava)
	end
end

local function buildTerrain()
	local terrain = workspace.Terrain
	terrain:Clear()
	terrain.WaterColor = Color3.fromRGB(30, 98, 112)
	terrain.WaterTransparency = 0.6
	terrain.WaterWaveSize = 0.12
	terrain.WaterWaveSpeed = 8
	-- Animated long grass on Grass/LeafyGrass, like the footage. Not settable
	-- from scripts on every engine version, so default.project.json sets it too.
	pcall(function()
		(terrain :: any).Decoration = true
	end)
	terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(118, 126, 58))
	terrain:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(92, 102, 50))
	terrain:SetMaterialColor(Enum.Material.Sand, Color3.fromRGB(198, 178, 130))
	terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(84, 80, 74))
	terrain:SetMaterialColor(Enum.Material.Basalt, Color3.fromRGB(44, 42, 46))
	terrain:SetMaterialColor(Enum.Material.Mud, Color3.fromRGB(74, 62, 46))
	terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(112, 88, 60))
	terrain:SetMaterialColor(Enum.Material.Snow, Color3.fromRGB(236, 242, 246))
	terrain:SetMaterialColor(Enum.Material.Glacier, Color3.fromRGB(176, 214, 232))
	terrain:SetMaterialColor(Enum.Material.Slate, Color3.fromRGB(74, 74, 78))
	terrain:SetMaterialColor(Enum.Material.CrackedLava, Color3.fromRGB(240, 100, 36))

	-- Ocean and sea floor
	terrain:FillBlock(CFrame.new(0, -18, 0), Vector3.new(1400, 36, 1400), Enum.Material.Water)
	terrain:FillBlock(CFrame.new(0, -40, 0), Vector3.new(1400, 8, 1400), Enum.Material.Sand)

	for _, isl in ISLANDS do
		island(terrain, isl)
	end
end

local function groundAt(x: number, z: number): RaycastResult?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	params.IgnoreWater = false
	return workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -600, 0), params)
end

local NO_GROW = { [Enum.Material.Water] = true, [Enum.Material.CrackedLava] = true, [Enum.Material.Mud] = true }

local function spawnNode(nodeFolder: Folder, nodeType: string, pos: Vector3)
	local model = makeNode(nodeType, CFrame.new(pos - Vector3.new(0, 0.3, 0)))
	model.Name = nodeType
	model:SetAttribute("NodeType", nodeType)
	model:SetAttribute("DisplayName", Nodes[nodeType].name)
	model:SetAttribute("HP", Nodes[nodeType].hp)
	model:SetAttribute("MaxHP", Nodes[nodeType].hp)
	model:SetAttribute("Depleted", false)
	model.Parent = nodeFolder
end

-- A spot on this island that is dry, not too steep, and `spacing` away from everything taken.
local function findSpot(
	isl: Island,
	taken: { Vector3 },
	spacing: number,
	near: Vector3?,
	nearRadius: number?,
	zone: string?
): Vector3?
	for _ = 1, 30 do
		local px, pz
		if near then
			local a = rng:NextNumber(0, math.pi * 2)
			local d = rng:NextNumber(spacing, nearRadius or spacing * 1.4)
			px, pz = near.X + math.cos(a) * d, near.Z + math.sin(a) * d
		else
			local a = rng:NextNumber(0, math.pi * 2)
			local d = math.sqrt(rng:NextNumber()) * (isl.r + 10)
			px, pz = isl.x + math.cos(a) * d, isl.z + math.sin(a) * d
		end
		local zoneOk = true
		local rx, rz = px - isl.x, pz - isl.z
		local field = if isl.biome == "clover" then CloverIsland else IslandFields[isl.biome]
		if field then
			zoneOk = field.canGrow(rx, rz) and (zone == nil or zone == "*" or field.zoneAt(rx, rz) == zone)
		end
		local hit = zoneOk and groundAt(px, pz)
		if hit and not NO_GROW[hit.Material] and hit.Position.Y > 0.8 and hit.Normal.Y > 0.8 then
			local ok = true
			for _, other in taken do
				if (other - hit.Position).Magnitude < spacing then
					ok = false
					break
				end
			end
			if ok then
				return hit.Position
			end
		end
	end
	return nil
end

local function populate(nodeFolder: Folder, isl: Island, taken: { Vector3 })
	for _, entry in BIOME_NODES[isl.biome] do
		local nodeType, count, clump, zone = entry[1], entry[2], entry[3], entry.zone
		local made = 0
		for _ = 1, count * 3 do
			if made >= count then
				break
			end
			if clump then
				-- Trees grow alone or in small clumps, with open ground between clumps.
				local centre = findSpot(isl, taken, if zone then CLUMP_SPACING * 0.75 else CLUMP_SPACING, nil, nil, zone)
				if centre then
					local size = rng:NextInteger(clump[1], clump[2])
					local clumpTaken = {}
					spawnNode(nodeFolder, nodeType, centre)
					table.insert(clumpTaken, centre)
					made += 1
					for _ = 2, size do
						if made >= count then
							break
						end
						local spot = findSpot(isl, clumpTaken, IN_CLUMP_SPACING, centre, IN_CLUMP_SPACING * 1.6, zone)
						if spot then
							spawnNode(nodeFolder, nodeType, spot)
							table.insert(clumpTaken, spot)
							made += 1
						end
					end
					for _, p in clumpTaken do
						table.insert(taken, p)
					end
				end
			else
				local spot = findSpot(isl, taken, if zone then NODE_SPACING * 0.75 else NODE_SPACING, nil, nil, zone)
				if spot then
					spawnNode(nodeFolder, nodeType, spot)
					table.insert(taken, spot)
					made += 1
				end
			end
		end
	end
end

-- Landmarks ----------------------------------------------------------------------

-- A ring of pale fang-shaped rocks round the cave mouth on Stone Shelf, so the
-- entrance reads from across the water.
local function makeCaveMouth(centre: Vector3, facing: Vector3)
	local m = Instance.new("Model")
	m.Name = "CaveMouth"
	local look = CFrame.lookAt(centre, centre + Vector3.new(facing.X, 0, facing.Z))
	for k = 0, 8 do
		local a = math.rad(-150 + k * 37.5)
		local offset = Vector3.new(math.cos(a) * 9.5, 0, math.sin(a) * 6 - 3)
		local base = look * CFrame.new(offset)
		local hit = groundAt(base.X, base.Z)
		local y = if hit then hit.Position.Y else base.Y
		local h = if k % 2 == 0 then 7 else 10
		part(m, {
			Name = "Fang",
			Size = Vector3.new(2.6, h, 2.6),
			CFrame = CFrame.new(base.X, y + h / 2 - 1, base.Z) * CFrame.Angles(math.rad(rng:NextNumber(-12, 12)), a, math.rad(rng:NextNumber(-12, 12))),
			Color = Color3.fromRGB(232, 228, 214),
			Material = Enum.Material.Limestone,
		})
		local tip = part(m, {
			Name = "FangTip",
			Size = Vector3.new(1.4, h * 0.45, 1.4),
			CFrame = CFrame.new(base.X, y + h + h * 0.18 - 1, base.Z) * CFrame.Angles(0, a + 0.4, 0),
			Color = Color3.fromRGB(244, 240, 228),
			Material = Enum.Material.Limestone,
		})
		tip.CanCollide = false
	end
	m.Parent = workspace
end

local function sign(text: string, adornee: BasePart, height: number)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(170, 32)
	gui.StudsOffset = Vector3.new(0, height, 0)
	gui.MaxDistance = 70
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 244, 214)
	label.TextStrokeTransparency = 0.3
	label.Text = text
	label.Parent = gui
	gui.Parent = adornee
end

local function prompt(parent: BasePart, action: string, object: string, panel: string)
	local p = Instance.new("ProximityPrompt")
	p.ActionText = action
	p.ObjectText = object
	p.MaxActivationDistance = 10
	p.RequiresLineOfSight = false
	p.Parent = parent
	p.Triggered:Connect(function(player)
		Remotes.OpenPanel:FireClient(player, panel)
	end)
end

local function makeQuestBoard(cf: CFrame)
	local m = Instance.new("Model")
	m.Name = "QuestBoard"
	for _, x in { -2.8, 2.8 } do
		part(m, { Size = Vector3.new(0.7, 7.5, 0.7), CFrame = cf * CFrame.new(x, 3.75, 0), Color = COLORS.trunk, Material = Enum.Material.Wood })
	end
	local board = part(m, { Name = "Board", Size = Vector3.new(6.4, 3.8, 0.4), CFrame = cf * CFrame.new(0, 4.8, 0), Color = Color3.fromRGB(168, 126, 82), Material = Enum.Material.WoodPlanks })
	part(m, { Size = Vector3.new(7.4, 0.5, 1.8), CFrame = cf * CFrame.new(0, 7.4, 0), Color = COLORS.trunkDark, Material = Enum.Material.Wood })
	for i, x in { -1.7, 0.1, 1.8 } do
		part(m, { Size = Vector3.new(1.3, 1.6, 0.05), CFrame = cf * CFrame.new(x, 4.8 + (i % 2) * 0.3, -0.23) * CFrame.Angles(0, 0, math.rad((i - 2) * 6)), Color = Color3.fromRGB(240, 228, 196) })
	end
	sign("Quest Board", board, 3.2)
	prompt(board, "View quests", "Quest Board", "quests")
	m.Parent = workspace
end

local function makeTrader(cf: CFrame)
	local m = Instance.new("Model")
	m.Name = "Trader"
	part(m, { Size = Vector3.new(2, 2, 1), CFrame = cf * CFrame.new(0, 1, 1.5), Color = Color3.fromRGB(96, 72, 50) })
	part(m, { Size = Vector3.new(2.2, 2.2, 1.1), CFrame = cf * CFrame.new(0, 3.1, 1.5), Color = Color3.fromRGB(70, 110, 130) })
	local head = part(m, { Name = "Head", Size = Vector3.new(1.3, 1.3, 1.3), CFrame = cf * CFrame.new(0, 4.85, 1.5), Color = Color3.fromRGB(200, 156, 118) })
	part(m, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.35, 3, 3), CFrame = cf * CFrame.new(0, 5.65, 1.5) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(214, 186, 112), Material = Enum.Material.Fabric })
	part(m, { Size = Vector3.new(7, 2.8, 1.6), CFrame = cf * CFrame.new(0, 1.4, -0.6), Color = COLORS.trunk, Material = Enum.Material.WoodPlanks })
	part(m, { Size = Vector3.new(7.6, 0.3, 4.2), CFrame = cf * CFrame.new(0, 7.2, 0.4) * CFrame.Angles(math.rad(-12), 0, 0), Color = Color3.fromRGB(196, 92, 62), Material = Enum.Material.Fabric })
	for _, x in { -3.4, 3.4 } do
		part(m, { Size = Vector3.new(0.45, 7.3, 0.45), CFrame = cf * CFrame.new(x, 3.65, -1.2), Color = COLORS.trunkDark, Material = Enum.Material.Wood })
	end
	sign("Trader", head, 2.4)
	prompt(head, "Trade", "Trader", "shop")
	m.Parent = workspace
end

-- Island Tribes' look comes mostly from Roblox's own lighting: warm low sun, thick
-- golden haze over the sea, bloom and sun rays, and slightly muted, contrasty
-- colour. Lighting.Technology = Future is set in default.project.json (it can't be
-- set from a script).
local function lightingEffect(className: string, props: { [string]: any })
	local e = Lighting:FindFirstChildOfClass(className) or Instance.new(className)
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = Lighting
end

local function setLighting()
	Lighting.Brightness = 3
	Lighting.Ambient = Color3.fromRGB(46, 42, 40)
	Lighting.OutdoorAmbient = Color3.fromRGB(104, 96, 86)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.ExposureCompensation = -0.1
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.25
	Lighting.ClockTime = 15.5
	Lighting.GeographicLatitude = 30
	lightingEffect("Atmosphere", {
		Density = 0.36,
		Offset = 0.25,
		Color = Color3.fromRGB(214, 200, 168),
		Decay = Color3.fromRGB(120, 112, 98),
		Glare = 0.4,
		Haze = 1.8,
	})
	lightingEffect("BloomEffect", { Intensity = 0.6, Size = 30, Threshold = 1.6 })
	lightingEffect("SunRaysEffect", { Intensity = 0.06, Spread = 0.7 })
	lightingEffect("ColorCorrectionEffect", {
		Brightness = -0.02,
		Contrast = 0.12,
		Saturation = -0.12,
		TintColor = Color3.fromRGB(255, 244, 226),
	})
	lightingEffect("DepthOfFieldEffect", { FarIntensity = 0.12, FocusDistance = 120, InFocusRadius = 140, NearIntensity = 0 })
end

-- Day and night: a full cycle every Config.DayLengthSeconds.
local function startDayNight()
	local pending = 0
	RunService.Heartbeat:Connect(function(dt)
		pending += dt
		if pending >= 0.5 then
			Lighting.ClockTime = (Lighting.ClockTime + pending * 24 / Config.DayLengthSeconds) % 24
			pending = 0
		end
	end)
end

function WorldBuilder.build()
	for _, child in workspace:GetChildren() do
		if child.Name == "Baseplate" or child:IsA("SpawnLocation") or child.Name == "TestGround" then
			child:Destroy()
		end
	end
	setLighting()
	buildTerrain()

	-- Right after the server starts, raycasts can't see freshly filled terrain yet.
	-- Wait (up to 10s) until the main island answers, or nothing gets placed.
	local waited = 0
	while not groundAt(0, 0) and waited < 10 do
		waited += task.wait(0.1)
	end
	task.wait(0.2)

	-- Spawn on the stem of Clover Island.
	local home = ISLANDS[1]
	local sx, sz = home.x + CloverIsland.Spawn.X, home.z + CloverIsland.Spawn.Y
	local spawnHit = groundAt(sx, sz)
	local spawnPos = if spawnHit then spawnHit.Position else Vector3.new(sx, 3, sz)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "TideboundSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(spawnPos + Vector3.new(0, 0.2, 0))
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Duration = 3
	spawn.Neutral = true
	spawn.Parent = workspace

	local nodes = folder("Nodes")
	folder("Structures")
	folder("Drops")
	folder("Animals")
	folder("LootSacks")

	-- Quest board and trader just inland from the spawn, facing it.
	local boardHit = groundAt(home.x + CloverIsland.Board.X, home.z + CloverIsland.Board.Y)
	local traderHit = groundAt(home.x + CloverIsland.Trader.X, home.z + CloverIsland.Trader.Y)
	local taken = { spawnPos }
	if boardHit then
		makeQuestBoard(CFrame.lookAt(boardHit.Position, Vector3.new(spawnPos.X, boardHit.Position.Y, spawnPos.Z)))
		table.insert(taken, boardHit.Position)
	end
	if traderHit then
		makeTrader(CFrame.lookAt(traderHit.Position, Vector3.new(spawnPos.X, traderHit.Position.Y, spawnPos.Z)))
		table.insert(taken, traderHit.Position)
	end
	-- Keep a clearing around the spawn.
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		table.insert(taken, spawnPos + Vector3.new(math.cos(a) * 10, 0, math.sin(a) * 10))
	end

	for _, isl in ISLANDS do
		populate(nodes, isl, taken)
	end

	-- Stone Shelf's cave mouth faces north.
	local shelf = ISLANDS[3]
	local mouth = IslandFields.rock.caveMouth
	makeCaveMouth(Vector3.new(shelf.x + mouth.X, 3, shelf.z + mouth.Y), Vector3.new(0, 0, -1))

	-- Boars roam the two grassy islands.
	Animals.spawnHerd("Boar", Vector3.new(home.x + CloverIsland.Herd.X, 0, home.z + CloverIsland.Herd.Y), 3)
	local hills = ISLANDS[2]
	Animals.spawnHerd("Boar", Vector3.new(hills.x - 20, 0, hills.z + 45), 4) -- Pine Hills' meadow
	Animals.start()

	startDayNight()
end

return WorldBuilder
