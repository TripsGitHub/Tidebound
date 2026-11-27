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
local Tiers = require(Shared.Tiers)
local Remotes = require(Shared.Remotes)
local Animals = require(script.Parent.Animals)
local CloverIsland = require(script.Parent.CloverIsland)
local IslandFields = require(script.Parent.IslandFields)
local MapScale = require(script.Parent.MapScale)
local Caves = require(script.Parent.Caves)
local Landmarks = require(script.Parent.Landmarks)
local Minimap = require(script.Parent.Minimap)
local Props = require(script.Parent.Props)
local Camps = require(script.Parent.Camps)

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
	FruitPalm = { mesh = "palm", scale = { 1.05, 1.3 } },
	Boulder = { mesh = "boulder", scale = { 0.85, 1.2 } },
	Bush = { mesh = "bush", scale = { 0.9, 1.15 } },
	SlimePool = { mesh = "slimepool", scale = { 1, 1 } },
}

-- Ore veins and crystal clusters: a squat boulder (the mesh when there is one) with
-- the tier's colour breaking out of it, as metal nuggets or a crown of shards.
local function makeOre(def, cf: CFrame): Model
	local tier = Tiers.get(def.tier)
	local s = rng:NextNumber(0.85, 1.1)
	local turn = cf * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	local rockColor = if def.look == "crystal" then COLORS.rockDark else COLORS.rock
	local m = Meshes.build("boulder", { fit = Vector3.new(5, 3.2, 4.6) * s })
	if m then
		m:PivotTo(turn)
		for _, p in m:GetDescendants() do
			if p:IsA("BasePart") then
				p.Color = p.Color:Lerp(rockColor, 0.35)
				p:SetAttribute("BaseTransparency", p.Transparency)
				p:SetAttribute("BaseCollide", p.CanCollide)
			end
		end
	else
		m = Instance.new("Model")
		local main = lump(m, Vector3.new(5, 3.2, 4.6) * s, turn * CFrame.new(0, 1.3 * s, 0), rockColor, "Rock")
		m.PrimaryPart = main
		main.PivotOffset = main.CFrame:Inverse() * cf
	end

	local glow = tier.glow
	if def.look == "metal" then
		-- Nuggets half-buried round the sides and top.
		for i = 1, 7 do
			local a = i / 7 * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
			local up = rng:NextNumber(0.2, 1)
			local r = 2.1 * s * (1 - up * 0.45)
			local d = rng:NextNumber(0.7, 1.2) * s
			part(m, {
				Name = "Ore",
				Size = Vector3.new(d, d * 0.8, d),
				CFrame = turn * CFrame.new(math.cos(a) * r, 0.5 * s + up * 2.3 * s, math.sin(a) * r) * CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), rng:NextNumber(0, 3)),
				Color = if i % 3 == 0 then tier.trim else tier.plate,
				Material = if glow and i % 3 == 1 then Enum.Material.Neon else Enum.Material.Metal,
				Reflectance = 0.1,
				CanCollide = false,
			})
		end
	else
		-- A crown of shards leaning outwards from the top.
		for i = 1, 6 do
			local a = i / 6 * math.pi * 2 + rng:NextNumber(-0.25, 0.25)
			local h = rng:NextNumber(2.4, 4.2) * s
			local w = rng:NextNumber(0.7, 1.1) * s
			local lean = rng:NextNumber(0.25, 0.55)
			local base = turn * CFrame.new(math.cos(a) * 1.1 * s, 2.3 * s, math.sin(a) * 1.1 * s)
			part(m, {
				Name = "Crystal",
				Size = Vector3.new(w, h, w),
				CFrame = base * CFrame.Angles(0, -a, 0) * CFrame.Angles(0, 0, -lean) * CFrame.new(0, h * 0.3, 0) * CFrame.Angles(0, math.rad(45), 0),
				Color = if i % 2 == 0 then tier.accent else tier.plate,
				Material = if glow and i % 2 == 0 then Enum.Material.Neon else Enum.Material.Glass,
				Transparency = if glow and i % 2 == 0 then 0 else 0.15,
				CanCollide = false,
			})
		end
		part(m, {
			Name = "Crystal",
			Size = Vector3.new(1.3, 4.8, 1.3) * s,
			CFrame = turn * CFrame.new(0, 3.6 * s, 0) * CFrame.Angles(0, math.rad(45), rng:NextNumber(-0.1, 0.1)),
			Color = tier.plate,
			Material = if glow then Enum.Material.Neon else Enum.Material.Glass,
			Transparency = if glow then 0 else 0.1,
			CanCollide = false,
		})
	end
	if glow then
		local light = Instance.new("PointLight")
		light.Color = tier.accent
		light.Range = 12
		light.Brightness = 1.2
		light.Parent = m.PrimaryPart
	end
	return m
end

-- Uses the imported mesh when the place has it, otherwise the block model.
-- Variants: the same tree, bush or rock in different colours, chosen per island, so
-- an autumn forest has orange and gold pines, Frost Isle's pines carry snow, and so on.
-- { tint name, weight }; nil = the plain mesh colours.
local rgbc = Color3.fromRGB
local TINTS = {
	autumn = { Leaf = rgbc(232, 120, 44) },
	gold = { Leaf = rgbc(236, 186, 60) },
	snowy = { Leaf = rgbc(226, 236, 240), mix = 0.6 },
	dark = { Leaf = rgbc(46, 92, 70) },
	blueberry = { Berry = rgbc(70, 90, 200) },
	blossom = { Berry = rgbc(255, 190, 220), BushLeaf = rgbc(120, 170, 70) },
	sandstone = { Basalt = rgbc(196, 132, 86), Moss = rgbc(180, 120, 80) },
	ashen = { Basalt = rgbc(46, 42, 48), Moss = rgbc(90, 40, 34) },
	snowcap = { Moss = rgbc(240, 244, 248) },
	bare = { Moss = rgbc(120, 116, 110) },
	lush = { Frond = rgbc(110, 190, 70) },
	sunfruit = { Coconut = rgbc(255, 150, 40) },
}
local VARIANTS = {
	Pine = {
		default = { { nil, 6 }, { "autumn", 1 }, { "gold", 1 } },
		hills = { { nil, 5 }, { "autumn", 2 }, { "gold", 2 }, { "dark", 1 } },
		ruins = { { "autumn", 3 }, { "gold", 3 }, { nil, 2 } },
		snow = { { "snowy", 5 }, { nil, 1 } },
		crags = { { "dark", 3 }, { nil, 1 } },
	},
	Bush = { default = { { nil, 4 }, { "blueberry", 1 }, { "blossom", 1 } } },
	Boulder = {
		default = { { nil, 3 }, { "bare", 1 } },
		mesa = { { "sandstone", 1 } },
		ember = { { "ashen", 1 } },
		skull = { { "ashen", 2 }, { nil, 1 } },
		maw = { { "ashen", 2 }, { "bare", 1 } },
		snow = { { "snowcap", 2 }, { nil, 1 } },
	},
	Palm = { default = { { nil, 3 }, { "lush", 1 } } },
	FruitPalm = { default = { { "sunfruit", 1 } } },
}
local currentBiome = "default" -- set by populate while it fills an island

local function pickVariant(nodeType: string): string?
	local byBiome = VARIANTS[nodeType]
	if not byBiome then
		return nil
	end
	local list = byBiome[currentBiome] or byBiome.default
	if not list then
		return nil
	end
	local total = 0
	for _, v in list do
		total += v[2]
	end
	local roll = rng:NextNumber(0, total)
	for _, v in list do
		roll -= v[2]
		if roll <= 0 then
			return v[1]
		end
	end
	return nil
end

local function applyTint(model: Model, tintName: string?)
	local tint = tintName and TINTS[tintName]
	if not tint then
		return
	end
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			for key, colour in tint do
				if key ~= "mix" and string.find(p.Name, key) then
					p.Color = p.Color:Lerp(colour, tint.mix or 0.85)
				end
			end
		end
	end
end

local function makeNode(nodeType: string, cf: CFrame): Model
	if Nodes[nodeType].ore then
		return makeOre(Nodes[nodeType], cf)
	end
	local spec = NODE_MESHES[nodeType]
	local scale = spec and rng:NextNumber(spec.scale[1], spec.scale[2])
	if spec and (nodeType == "Pine" or nodeType == "Palm") and rng:NextNumber() < 0.06 then
		scale *= 1.5 -- now and then a giant
	end
	local model = spec and Meshes.build(spec.mesh, { scale = scale })
	if model then
		model:PivotTo(cf * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
		applyTint(model, pickVariant(nodeType))
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
	ring: boolean?, -- false: left out of the Deep Network's ring (hangs off its nearest island)
}

local ISLANDS: { Island } = {
	{ name = "Clover Island", x = 0, z = 320, r = 110, biome = "clover" }, -- spawn, south
	{ name = "Pine Hills", x = -300, z = 90, r = 100, biome = "hills" },
	{ name = "Stone Shelf", x = 300, z = 90, r = 110, biome = "rock" },
	{ name = "Frost Isle", x = -190, z = -265, r = 95, biome = "snow" },
	{ name = "Slime Marsh", x = 195, z = -265, r = 96, biome = "marsh" },
	{ name = "Ember Isle", x = 0, z = 0, r = 115, biome = "ember" }, -- late game, middle
	-- Smaller islands between and beyond the big ones (IslandFields.make recipes).
	{ name = "Driftwood Cay", x = -190, z = 300, r = 45, biome = "cay" }, -- food next to spawn
	{ name = "Coral Atoll", x = 190, z = 300, r = 58, biome = "atoll" }, -- palms round a lagoon
	{ name = "Silver Crags", x = -345, z = -110, r = 62, biome = "crags" }, -- silver, wolves
	{ name = "Gold Mesa", x = 345, z = -110, r = 64, biome = "mesa" }, -- gold on the terraces
	{ name = "Old Ruins", x = 0, z = -370, r = 72, biome = "ruins" }, -- far north, past Ember
	{ name = "Skull Key", x = 480, z = 330, r = 34, biome = "skull", ring = false },
	{ name = "Gull Rock", x = -480, z = 330, r = 28, biome = "rockcay", ring = false },
	{ name = "Sunfruit Isle", x = -340, z = 270, r = 66, biome = "fruit" }, -- fruit palms and ponds, near the start
	{ name = "Maw Rock", x = 0, z = 160, r = 36, biome = "maw", ring = false, hub = true }, -- the way down to the Maw
}
-- Built MapScale.H times bigger than the shapes above, and MapScale.Spread further apart.
for _, isl in ISLANDS do
	isl.x *= MapScale.Spread
	isl.z *= MapScale.Spread
	isl.r *= MapScale.H
end
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
		{ "Palm", 11, { 1, 3 }, zone = "palms" },
		{ "FruitPalm", 4, { 1, 2 }, zone = "palms" },
		{ "Bush", 3, zone = "palms" },
		{ "Bush", 8, zone = "meadow" },
		{ "Pine", 3, { 1, 2 }, zone = "meadow" },
		{ "Boulder", 2, zone = "meadow" },
		{ "SilverVein", 3, zone = "rocks" },
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
		{ "SilverVein", 6, zone = "cliffs" },
		{ "GoldVein", 5, zone = "cliffs" },
		{ "Boulder", 3, zone = "slope" },
		{ "Pine", 5, { 1, 2 }, zone = "slope" },
		{ "Bush", 4, zone = "slope" },
	},
	snow = {
		{ "Pine", 14, { 1, 3 }, zone = "slopes" },
		{ "Boulder", 6, zone = "peak" },
		{ "GoldVein", 2, zone = "slopes" },
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
	-- Recipe islands are zoned shore / inland / peak.
	cay = {
		{ "Palm", 10, { 1, 3 }, zone = "inland" },
		{ "Palm", 4, { 1, 1 }, zone = "shore" },
		{ "Bush", 7, zone = "inland" },
		{ "Boulder", 2, zone = "*" },
	},
	atoll = {
		{ "Palm", 13, { 1, 3 }, zone = "inland" },
		{ "FruitPalm", 4, { 1, 2 }, zone = "inland" },
		{ "Bush", 6, zone = "inland" },
		{ "Boulder", 3, zone = "shore" },
	},
	crags = { -- silver
		{ "SilverVein", 10, zone = "inland" },
		{ "SilverVein", 4, zone = "peak" },
		{ "GoldVein", 2, zone = "peak" },
		{ "Boulder", 10, zone = "inland" },
		{ "Pine", 6, { 1, 2 }, zone = "inland" },
	},
	mesa = { -- gold
		{ "GoldVein", 10, zone = "inland" },
		{ "GoldVein", 4, zone = "peak" },
		{ "Boulder", 8, zone = "*" },
		{ "Bush", 4, zone = "inland" },
		{ "Palm", 4, { 1, 1 }, zone = "shore" },
	},
	ruins = {
		{ "Pine", 20, { 2, 4 }, zone = "inland" },
		{ "Bush", 6, zone = "inland" },
		{ "Boulder", 6, zone = "*" },
		{ "SilverVein", 3, zone = "inland" },
		{ "GoldVein", 3, zone = "peak" },
	},
	skull = {
		{ "Boulder", 6, zone = "*" },
		{ "SilverVein", 2, zone = "*" },
		{ "GoldVein", 3, zone = "*" },
	},
	maw = {
		{ "Boulder", 8, zone = "*" },
		{ "SilverVein", 2, zone = "*" },
	},
	rockcay = {
		{ "Boulder", 4, zone = "*" },
		{ "Palm", 2, { 1, 1 }, zone = "shore" },
	},
	fruit = { -- food: groves of fruit palms, berry bushes round the ponds
		{ "FruitPalm", 18, { 2, 4 }, zone = "inland" },
		{ "Palm", 6, { 1, 2 }, zone = "shore" },
		{ "Bush", 10, zone = "inland" },
		{ "Boulder", 3, zone = "*" },
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
	terrain.WaterColor = Color3.fromRGB(64, 150, 160) -- bright turquoise shallows
	terrain.WaterTransparency = 0.7
	terrain.WaterReflectance = 0.6
	terrain.WaterWaveSize = 0.12
	terrain.WaterWaveSpeed = 8
	-- Animated long grass on Grass/LeafyGrass, like the footage. Not settable
	-- from scripts on every engine version, so default.project.json sets it too.
	pcall(function()
		(terrain :: any).Decoration = true
	end)
	terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(168, 176, 60))
	terrain:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(140, 156, 56))
	terrain:SetMaterialColor(Enum.Material.Sand, Color3.fromRGB(232, 212, 158))
	terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(112, 104, 94))
	terrain:SetMaterialColor(Enum.Material.Basalt, Color3.fromRGB(44, 42, 46))
	terrain:SetMaterialColor(Enum.Material.Sandstone, Color3.fromRGB(196, 128, 82))
	terrain:SetMaterialColor(Enum.Material.Mud, Color3.fromRGB(96, 80, 56))
	terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(150, 118, 78))
	terrain:SetMaterialColor(Enum.Material.Snow, Color3.fromRGB(236, 242, 246))
	terrain:SetMaterialColor(Enum.Material.Glacier, Color3.fromRGB(176, 214, 232))
	terrain:SetMaterialColor(Enum.Material.Slate, Color3.fromRGB(74, 74, 78))
	terrain:SetMaterialColor(Enum.Material.CrackedLava, Color3.fromRGB(240, 100, 36))

	-- Ocean and sea floor
	local V = MapScale.V
	local extent = 0
	for _, isl in ISLANDS do
		extent = math.max(extent, math.abs(isl.x) + isl.r, math.abs(isl.z) + isl.r)
	end
	local sea = (extent + 600) * 2 -- open water well past the outer islands
	terrain:FillBlock(CFrame.new(0, -18 * V, 0), Vector3.new(sea, 36 * V, sea), Enum.Material.Water)
	terrain:FillBlock(CFrame.new(0, -40 * V, 0), Vector3.new(sea, 8 * V, sea), Enum.Material.Sand)

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

local settleParams = RaycastParams.new()
settleParams.FilterType = Enum.RaycastFilterType.Include

-- Sinks a model until its whole footprint touches the ground: on a slope the downhill
-- side would otherwise float. Looks under the corners of its base and drops it to the
-- lowest one (plus a little, so it sits in the ground rather than on it).
local function settle(model: Model, pos: Vector3, extra: number?)
	settleParams.FilterDescendantsInstances = { workspace.Terrain }
	local _, size = model:GetBoundingBox()
	local rx, rz = math.min(size.X * 0.32, 3), math.min(size.Z * 0.32, 3) -- the base, not a canopy
	local low = pos.Y
	for _, off in { Vector3.new(rx, 0, 0), Vector3.new(-rx, 0, 0), Vector3.new(0, 0, rz), Vector3.new(0, 0, -rz), Vector3.new(rx, 0, rz) * 0.7, Vector3.new(-rx, 0, -rz) * 0.7 } do
		local from = pos + off + Vector3.new(0, 6, 0)
		local hit = workspace:Raycast(from, Vector3.new(0, -16, 0), settleParams)
		if hit then
			low = math.min(low, hit.Position.Y)
		end
	end
	local drop = pos.Y - low + (extra or 0)
	if drop > 0 then
		model:PivotTo(model:GetPivot() - Vector3.new(0, drop, 0))
	end
end
WorldBuilder.settle = settle

local function spawnNode(nodeFolder: Folder, nodeType: string, pos: Vector3)
	local model = makeNode(nodeType, CFrame.new(pos - Vector3.new(0, 0.3, 0)))
	settle(model, pos, 0.2)
	model.Name = nodeType
	model:SetAttribute("NodeType", nodeType)
	model:SetAttribute("DisplayName", Nodes[nodeType].name)
	model:SetAttribute("HP", Nodes[nodeType].hp)
	model:SetAttribute("MaxHP", Nodes[nodeType].hp)
	model:SetAttribute("Depleted", false)
	model.Parent = nodeFolder
	return model
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
		local rx, rz = (px - isl.x) / MapScale.H, (pz - isl.z) / MapScale.H -- the zone maps are at 1x
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
	currentBiome = isl.biome
	for _, entry in BIOME_NODES[isl.biome] do
		local nodeType, clump, zone = entry[1], entry[3], entry.zone
		-- Same density as the hand-tuned 1x map (scaled by Density), over more land.
		local count = math.max(1, math.round(entry[2] * MapScale.H * MapScale.H * MapScale.Density))
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

-- Caves ---------------------------------------------------------------------------
-- The advanced ores only grow underground (or come from world events, see Events.lua).
-- Stone Shelf has its own hand-carved cave (IslandFields), and Caves.lua runs a
-- network under the whole map. The deeper the chamber, the better the ore.
local CAVE_NODES = {
	-- The open chambers on the main way down: common ores only.
	upper = { { "SilverVein", 2 }, { "GoldVein", 1 } },
	lower = { { "GoldVein", 2 }, { "SunstoneVein", 1 } },
	deep = { { "SunstoneVein", 2 }, { "GoldVein", 1 } },
	-- Rare ore only in the pockets at the end of the crawlways.
	pocket_lower = { { "DiamondCluster", 2 } },
	pocket_deep = { { "FractiteCluster", 1 }, { "AmethystGeode", 1 } },
	-- The Maw and the boss lairs below it.
	abyss = { { "SunstoneVein", 2 }, { "DiamondCluster", 1 } },
	lair = { { "FractiteCluster", 1 }, { "AmethystGeode", 1 }, { "DiamondCluster", 1 } },
}
-- Odd ores along the halls, by depth (and never the rare ones).
local HALL_ORE = { upper = "SilverVein", lower = "GoldVein", deep = "SunstoneVein", abyss = "SunstoneVein" }
local CRYSTAL_GLOW = { Color3.fromRGB(120, 200, 255), Color3.fromRGB(190, 140, 255), Color3.fromRGB(120, 255, 210) }
local TORCH_GLOW = Color3.fromRGB(255, 170, 80)

local function terrainParams(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	return params
end

-- Raycast down inside a cave from `from` to find the floor.
local function caveFloorAt(x: number, z: number, from: number): RaycastResult?
	return workspace:Raycast(Vector3.new(x, from, z), Vector3.new(0, -40, 0), terrainParams())
end

-- A cluster of glowing crystals growing out of a cave surface (floor, wall or roof):
-- shards fan out round the surface's normal, a few long ones and more short ones,
-- each a slightly different shade. The deep caves' light, and a sign of rare ore.
local function crystal(parent: Instance, pos: Vector3, color: Color3, big: boolean?, normal: Vector3?)
	local up = normal or Vector3.yAxis
	local k = (if big then 2 else 1) * rng:NextNumber(0.7, 1.3)
	local count = rng:NextInteger(if big then 5 else 3, if big then 9 else 6)
	local cluster = Instance.new("Model")
	cluster.Name = "CaveCrystal"
	for i = 1, count do
		local lean = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)) * (if i == 1 then 0.15 else 0.65)
		local dir = (up + lean).Unit
		local long = if i <= 2 then rng:NextNumber(2.2, 3.6) else rng:NextNumber(0.8, 2.2)
		local w = rng:NextNumber(0.45, 0.8) * k * (if i <= 2 then 1.15 else 0.85)
		local base = pos + Vector3.new(rng:NextNumber(-0.8, 0.8), rng:NextNumber(-0.8, 0.8), rng:NextNumber(-0.8, 0.8)) * k - up * 0.3
		local length = long * k
		local right = dir:Cross(if math.abs(dir.Y) < 0.95 then Vector3.yAxis else Vector3.xAxis).Unit
		local cf = CFrame.fromMatrix(base + dir * length / 2, right, dir) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
		local shard = Instance.new("Part")
		shard.Name = "Shard"
		shard.Anchored = true
		shard.CanCollide = false
		shard.CanQuery = false
		shard.CastShadow = false
		shard.Size = Vector3.new(w, length, w)
		shard.CFrame = cf
		shard.Material = if i % 3 == 0 then Enum.Material.Glass else Enum.Material.Neon
		shard.Transparency = if i % 3 == 0 then 0.2 else 0
		local h, sat, val = color:ToHSV()
		shard.Color = Color3.fromHSV((h + rng:NextNumber(-0.03, 0.03)) % 1, math.clamp(sat * rng:NextNumber(0.75, 1.1), 0, 1), math.clamp(val * rng:NextNumber(0.8, 1), 0, 1))
		shard.Parent = cluster
		if i == 1 then
			local light = Instance.new("PointLight")
			light.Color = color
			light.Range = (if big then 24 else 16) * rng:NextNumber(0.85, 1.15)
			light.Brightness = 0.8
			light.Shadows = false
			light.Parent = shard
		end
	end
	cluster.Parent = parent
end

-- A random direction out from a tunnel's middle, more often sideways or down than up,
-- so crystals end up on walls, floor and now and then the roof.
local function surfaceDir(): Vector3
	local y = rng:NextNumber(-1, 0.6)
	local a = rng:NextNumber(0, math.pi * 2)
	local flat = math.sqrt(math.max(0, 1 - y * y))
	return Vector3.new(math.cos(a) * flat, y, math.sin(a) * flat)
end

-- A torch stuck in the wall: the shallow caves are lit by people, not crystals.
local function torch(parent: Instance, wall: Vector3, normal: Vector3)
	local m = Instance.new("Model")
	m.Name = "CaveTorch"
	local out = Vector3.new(normal.X, 0, normal.Z)
	out = if out.Magnitude > 0.1 then out.Unit else Vector3.xAxis
	local base = wall + out * 0.6
	local stick = part(m, {
		Name = "Stick",
		Size = Vector3.new(0.35, 2.2, 0.35),
		CFrame = CFrame.lookAt(base, base + out) * CFrame.Angles(math.rad(-55), 0, 0) * CFrame.new(0, 0.9, 0),
		Color = Color3.fromRGB(96, 64, 40),
		Material = Enum.Material.Wood,
	})
	stick.CanCollide = false
	local flame = part(m, {
		Name = "Flame",
		Size = Vector3.new(0.5, 0.7, 0.5),
		CFrame = stick.CFrame * CFrame.new(0, 1.3, 0),
		Color = TORCH_GLOW,
		Material = Enum.Material.Neon,
	})
	flame.CanCollide = false
	flame.CanQuery = false
	local fire = Instance.new("Fire")
	fire.Size = 2
	fire.Heat = 4
	fire.Color = Color3.fromRGB(255, 150, 60)
	fire.SecondaryColor = Color3.fromRGB(255, 220, 120)
	fire.Parent = flame
	local light = Instance.new("PointLight")
	light.Color = TORCH_GLOW
	light.Range = 24
	light.Brightness = 1.3
	light.Shadows = false
	light.Parent = flame
	m.Parent = parent
end

-- tunnels: { points, r, kind }; chambers: { pos = floor centre, r, tier };
-- pockets: { pos, tier }.
local function dressCaves(nodeFolder: Folder, chambers: { any }, tunnels: { any }, pockets: { any })
	local decor = workspace:FindFirstChild("CaveLights") or Instance.new("Folder")
	decor.Name = "CaveLights"
	decor.Parent = workspace
	local params = terrainParams()
	local taken = {}
	local function free(pos: Vector3, gap: number): boolean
		for _, o in taken do
			if (o - pos).Magnitude < gap then
				return false
			end
		end
		return true
	end

	-- Along every tunnel: torches on the walls up high, crystals on the floor deep
	-- down, and now and then a common ore in the halls.
	for n, t in tunnels do
		if t.kind ~= "ravine" then
			local pts = Caves.samples(t.points)
			local every = if t.kind == "hall" then rng:NextInteger(8, 13) else rng:NextInteger(7, 11) -- samples (3 studs each)
			local sinceOre = 0
			for i = 1, #pts - 1, every do
				local p, q = pts[i], pts[i + 1]
				local tier = Caves.tierAt(p.Y)
				local dir = Vector3.new(q.X - p.X, 0, q.Z - p.Z)
				if tier == "upper" and dir.Magnitude > 0 then
					local side = Vector3.new(-dir.Z, 0, dir.X).Unit * (if (i // every) % 2 == 0 then 1 else -1)
					local hit = workspace:Raycast(p, side * (t.r + 6), params)
					if hit then
						torch(decor, hit.Position, hit.Normal)
					end
				elseif rng:NextNumber() < 0.7 then
					-- Not on a beat: some stretches get two clusters, some none.
					for _ = 1, (if rng:NextNumber() < 0.3 then 2 else 1) do
						local hit = workspace:Raycast(p, surfaceDir() * (t.r + 6), params)
						if hit then
							crystal(decor, hit.Position, CRYSTAL_GLOW[rng:NextInteger(1, #CRYSTAL_GLOW)], rng:NextNumber() < 0.15, hit.Normal)
						end
					end
				end
				sinceOre += every * 3
				if t.kind == "hall" and sinceOre > 130 and p.Y < -15 then
					local hit = caveFloorAt(p.X, p.Z, p.Y + 2)
					if hit and hit.Position.Y < p.Y and free(hit.Position, 40) then
						spawnNode(nodeFolder, HALL_ORE[tier], hit.Position + Vector3.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3)))
						table.insert(taken, hit.Position)
						sinceOre = 0
					end
				end
			end
		end
		if n % 6 == 0 then
			task.wait()
		end
	end

	local function oresIn(c, list)
		local f, r = c.pos, c.r
		for _, entry in list or {} do
			local made = 0
			for _ = 1, entry[2] * 12 do
				if made >= entry[2] then
					break
				end
				local a = rng:NextNumber(0, math.pi * 2)
				local d = math.sqrt(rng:NextNumber()) * r * 0.65
				local hit = caveFloorAt(f.X + math.cos(a) * d, f.Z + math.sin(a) * d, f.Y + r * 0.6)
				if hit and hit.Normal.Y > 0.7 and math.abs(hit.Position.Y - f.Y) < 8 and free(hit.Position, 7) then
					spawnNode(nodeFolder, entry[1], hit.Position)
					table.insert(taken, hit.Position)
					made += 1
				end
			end
		end
	end

	-- Chambers: a ring of torches or crystals, and their ores.
	for _, c in chambers do
		if c.tier ~= "pocket" then
			local f, r = c.pos, c.r
			for i = 1, 6 do
				local a = i / 6 * math.pi * 2
				local x, z = f.X + math.cos(a) * r * 0.75, f.Z + math.sin(a) * r * 0.75
				if c.tier == "upper" then
					local from = f + Vector3.new(0, 5, 0)
					local hit = workspace:Raycast(from, Vector3.new(x - f.X, 0, z - f.Z).Unit * (r + 6), params)
					if hit then
						torch(decor, hit.Position, hit.Normal)
					end
				else
					local centre = f + Vector3.new(0, r * 0.45, 0)
					local hit = workspace:Raycast(centre, surfaceDir() * (r + 8), params)
					if hit then
						crystal(decor, hit.Position, CRYSTAL_GLOW[rng:NextInteger(1, #CRYSTAL_GLOW)], c.tier ~= "lower" and rng:NextNumber() < 0.5, hit.Normal)
					end
				end
			end
			oresIn(c, CAVE_NODES[c.tier] or CAVE_NODES.deep)
		end
	end

	-- Pockets at the end of the crawlways: big crystals and the rare ore.
	for _, pk in pockets do
		local c = { pos = pk.pos, r = 11 }
		local glow = CRYSTAL_GLOW[rng:NextInteger(1, #CRYSTAL_GLOW)]
		for _ = 1, rng:NextInteger(3, 6) do
			local hit = workspace:Raycast(pk.pos + Vector3.new(0, 5, 0), surfaceDir() * 18, params)
			if hit then
				crystal(decor, hit.Position, glow, rng:NextNumber() < 0.4, hit.Normal)
			end
		end
		oresIn(c, CAVE_NODES[if pk.tier == "deep" then "pocket_deep" else "pocket_lower"])
	end
end

-- Stone Shelf's hand-carved cave, in world coordinates.
local function shelfCave(isl: Island): ({ any }, { any })
	local H, V = MapScale.H, MapScale.V
	local field = IslandFields.rock
	local tiers = { chamber = "upper", vault = "lower", hollow = "deep" }
	local chambers, paths = {}, {}
	for _, c in field.chambers do
		table.insert(chambers, { pos = Vector3.new(isl.x + c[1] * H, c[4] * V, isl.z + c[2] * H), r = c[3] * H * 0.8, tier = tiers[c.name] })
	end
	for _, path in field.tunnels do
		local pts = {}
		for _, q in path do
			table.insert(pts, Vector3.new(isl.x + q[1] * H, q[3] * V + 5, isl.z + q[2] * H))
		end
		table.insert(paths, pts)
	end
	local tunnels = {}
	for _, pts in paths do
		table.insert(tunnels, { points = pts, r = 6, kind = "hall" })
	end
	return chambers, tunnels
end

-- Landmarks ----------------------------------------------------------------------

-- A ring of pale fang-shaped rocks round the cave mouth on Stone Shelf, so the
-- entrance reads from across the water.
local function makeCaveMouth(centre: Vector3, facing: Vector3, size: number?)
	local k0 = size or 1
	local m = Instance.new("Model")
	m.Name = "CaveMouth"
	local look = CFrame.lookAt(centre, centre + Vector3.new(facing.X, 0, facing.Z))
	for k = 0, 8 do
		local a = math.rad(-150 + k * 37.5)
		local offset = Vector3.new(math.cos(a) * 9.5, 0, math.sin(a) * 6 - 3) * k0
		local base = look * CFrame.new(offset)
		local hit = groundAt(base.X, base.Z)
		local y = if hit then hit.Position.Y else base.Y
		local h = (if k % 2 == 0 then 7 else 10) * k0
		part(m, {
			Name = "Fang",
			Size = Vector3.new(2.6, h / k0, 2.6) * k0,
			CFrame = CFrame.new(base.X, y + h / 2 - 1, base.Z) * CFrame.Angles(math.rad(rng:NextNumber(-12, 12)), a, math.rad(rng:NextNumber(-12, 12))),
			Color = Color3.fromRGB(232, 228, 214),
			Material = Enum.Material.Limestone,
		})
		local tip = part(m, {
			Name = "FangTip",
			Size = Vector3.new(1.4, h * 0.45 / k0, 1.4) * k0,
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
	label.FontFace = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Bold)
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
	-- Warm, bright and golden by day: saturated grass, creamy sand, a soft haze on the
	-- horizon that turns far islands pale.
	Lighting.Brightness = 3.2
	Lighting.Ambient = Color3.fromRGB(64, 58, 52)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 138, 114)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.ExposureCompensation = 0.1
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.25
	Lighting.ClockTime = 15.5
	Lighting.GeographicLatitude = 30
	lightingEffect("Atmosphere", {
		Density = 0.3,
		Offset = 0.12,
		Color = Color3.fromRGB(240, 226, 192),
		Decay = Color3.fromRGB(196, 176, 136),
		Glare = 0.7,
		Haze = 2.2,
	})
	lightingEffect("BloomEffect", { Intensity = 0.5, Size = 28, Threshold = 1.4 })
	lightingEffect("SunRaysEffect", { Intensity = 0.08, Spread = 0.8 })
	lightingEffect("ColorCorrectionEffect", {
		Brightness = 0.03,
		Contrast = 0.08,
		Saturation = 0.14,
		TintColor = Color3.fromRGB(255, 246, 224),
	})
	lightingEffect("DepthOfFieldEffect", { FarIntensity = 0.05, FocusDistance = 160, InFocusRadius = 220, NearIntensity = 0 })
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

-- For world events (Events.lua): drop a node somewhere on an island's open ground.
function WorldBuilder.spawnNodeOn(isl: Island, nodeType: string, zone: string?): Model?
	local nodes = workspace:FindFirstChild("Nodes") :: Folder?
	if not nodes then
		return nil
	end
	local taken = {}
	for _, m in nodes:GetChildren() do
		table.insert(taken, m:GetPivot().Position)
	end
	local spot = findSpot(isl, taken, 10, nil, nil, zone)
	return if spot then spawnNode(nodes, nodeType, spot) else nil
end

-- Ground cover: grass tufts, ferns, flowers, pebbles, mushrooms and reeds, by island.
-- Not harvestable, no collisions; just so the ground between resources isn't bare.
local DECOR = {
	default = { "tuft", "tuft", "flowers", "pebbles", "fern" },
	clover = { "tuft", "tuft", "flowers", "flowers", "pebbles", "fern" },
	hills = { "tuft", "fern", "fern", "mushrooms", "flowers", "pebbles" },
	rock = { "pebbles", "pebbles", "tuft" },
	snow = { "pebbles", "icicles" },
	marsh = { "reeds", "reeds", "mushrooms", "tuft" },
	ember = { "pebbles", "embers" },
	cay = { "tuft", "shells", "pebbles" },
	atoll = { "tuft", "shells", "flowers" },
	crags = { "pebbles", "pebbles", "fern" },
	mesa = { "pebbles", "tuft" },
	ruins = { "fern", "mushrooms", "flowers", "tuft", "pebbles" },
	skull = { "pebbles", "shells" },
	rockcay = { "pebbles", "shells" },
	maw = { "pebbles", "pebbles", "shells" },
	fruit = { "flowers", "flowers", "tuft", "fern", "shells" },
}
local function decorPiece(f: Instance, kind: string, at: Vector3)
	local function bit(props)
		props.Anchored = true
		props.CanCollide = false
		props.CanQuery = false
		props.CastShadow = false
		local p = Instance.new(props.Class or "Part")
		props.Class = nil
		for k, v in props do
			(p :: any)[k] = v
		end
		p.Parent = f
		return p
	end
	if kind == "tuft" then
		for i = 1, 4 do
			bit({ Size = Vector3.new(0.25, rng:NextNumber(1.2, 2.2), 0.6), CFrame = CFrame.new(at + Vector3.new(rng:NextNumber(-0.6, 0.6), 0.6, rng:NextNumber(-0.6, 0.6))) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), i * 0.8, rng:NextNumber(-0.4, 0.4)), Color = rgbc(150, 176, 60):Lerp(rgbc(200, 196, 80), rng:NextNumber()), Material = Enum.Material.Grass })
		end
	elseif kind == "fern" then
		for i = 0, 5 do
			bit({ Class = "WedgePart", Size = Vector3.new(0.15, 0.8, 2.6), CFrame = CFrame.new(at + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, i * 1.05, 0) * CFrame.new(0, 0, -1.2) * CFrame.Angles(0.5, 0, 0), Color = rgbc(70, 130, 50), Material = Enum.Material.Grass })
		end
	elseif kind == "flowers" then
		local colours = { rgbc(255, 120, 150), rgbc(255, 220, 90), rgbc(200, 140, 255), rgbc(255, 255, 255), rgbc(255, 150, 70) }
		local c = colours[rng:NextInteger(1, #colours)]
		for _ = 1, rng:NextInteger(3, 6) do
			local p = at + Vector3.new(rng:NextNumber(-1.5, 1.5), 0, rng:NextNumber(-1.5, 1.5))
			bit({ Size = Vector3.new(0.12, 0.8, 0.12), CFrame = CFrame.new(p + Vector3.new(0, 0.4, 0)), Color = rgbc(70, 130, 50) })
			bit({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.5, CFrame = CFrame.new(p + Vector3.new(0, 0.85, 0)), Color = c })
		end
	elseif kind == "pebbles" then
		for _ = 1, rng:NextInteger(2, 4) do
			bit({ Size = Vector3.new(rng:NextNumber(0.6, 1.4), rng:NextNumber(0.3, 0.7), rng:NextNumber(0.6, 1.4)), CFrame = CFrame.new(at + Vector3.new(rng:NextNumber(-1.5, 1.5), 0.15, rng:NextNumber(-1.5, 1.5))) * CFrame.Angles(0, rng:NextNumber(0, 6), rng:NextNumber(-0.3, 0.3)), Color = rgbc(130, 126, 118):Lerp(rgbc(170, 162, 148), rng:NextNumber()), Material = Enum.Material.Slate })
		end
	elseif kind == "mushrooms" then
		for _ = 1, rng:NextInteger(2, 4) do
			local p = at + Vector3.new(rng:NextNumber(-1.2, 1.2), 0, rng:NextNumber(-1.2, 1.2))
			local h = rng:NextNumber(0.5, 1.1)
			bit({ Size = Vector3.new(0.25, h, 0.25), CFrame = CFrame.new(p + Vector3.new(0, h / 2, 0)), Color = rgbc(236, 226, 206) })
			bit({ Shape = Enum.PartType.Ball, Size = Vector3.new(0.9, 0.4, 0.9) * (h + 0.4), CFrame = CFrame.new(p + Vector3.new(0, h, 0)), Color = if rng:NextNumber() < 0.5 then rgbc(210, 70, 60) else rgbc(220, 180, 120) })
		end
	elseif kind == "reeds" then
		for _ = 1, rng:NextInteger(4, 7) do
			local h = rng:NextNumber(2.5, 4.5)
			bit({ Size = Vector3.new(0.2, h, 0.2), CFrame = CFrame.new(at + Vector3.new(rng:NextNumber(-1, 1), h / 2, rng:NextNumber(-1, 1))) * CFrame.Angles(rng:NextNumber(-0.15, 0.15), 0, rng:NextNumber(-0.15, 0.15)), Color = rgbc(120, 150, 60) })
		end
	elseif kind == "shells" then
		for _ = 1, rng:NextInteger(1, 3) do
			bit({ Size = Vector3.new(0.7, 0.25, 0.6), CFrame = CFrame.new(at + Vector3.new(rng:NextNumber(-1.5, 1.5), 0.1, rng:NextNumber(-1.5, 1.5))) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), Color = rgbc(250, 226, 210):Lerp(rgbc(240, 170, 150), rng:NextNumber()) })
		end
	elseif kind == "icicles" then
		for _ = 1, 3 do
			bit({ Size = Vector3.new(0.5, rng:NextNumber(1, 2.2), 0.5), CFrame = CFrame.new(at + Vector3.new(rng:NextNumber(-1, 1), 0.6, rng:NextNumber(-1, 1))) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), 0, rng:NextNumber(-0.3, 0.3)), Color = rgbc(200, 236, 250), Material = Enum.Material.Glass, Transparency = 0.25 })
		end
	elseif kind == "embers" then
		bit({ Size = Vector3.new(rng:NextNumber(1, 2), 0.2, rng:NextNumber(0.3, 0.6)), CFrame = CFrame.new(at + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), Color = rgbc(255, 110, 40), Material = Enum.Material.Neon })
	end
end

local function decorate(isl: Island)
	local f = workspace:FindFirstChild("Decor") or folder("Decor")
	local kinds = DECOR[isl.biome] or DECOR.default
	local count = math.floor((isl.r / 10) ^ 2 * 0.08)
	for i = 1, count do
		local spot = findSpot(isl, {}, 0, nil, nil, "*")
		if spot then
			decorPiece(f, kinds[rng:NextInteger(1, #kinds)], spot)
		end
		if i % 40 == 0 then
			task.wait()
		end
	end
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
	local H = MapScale.H
	local sx, sz = home.x + CloverIsland.Spawn.X * H, home.z + CloverIsland.Spawn.Y * H
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
	-- The board and trader stay close to the spawn (not scaled out with the island).
	local boardHit = groundAt(sx + CloverIsland.Board.X, sz + (CloverIsland.Board.Y - CloverIsland.Spawn.Y))
	local traderHit = groundAt(sx + CloverIsland.Trader.X, sz + (CloverIsland.Trader.Y - CloverIsland.Spawn.Y))
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
		-- Each island only checks spacing against what's on it (keeps placement fast).
		local local_ = {}
		local centre = Vector3.new(isl.x, 0, isl.z)
		for _, p in taken do
			if (Vector3.new(p.X, 0, p.Z) - centre).Magnitude < isl.r * 1.6 then
				table.insert(local_, p)
			end
		end
		populate(nodes, isl, local_)
		decorate(isl)
		task.wait()
	end

	-- Stone Shelf's cave mouth faces north.
	local shelf = ISLANDS[3]
	local mouth = IslandFields.rock.caveMouth
	makeCaveMouth(Vector3.new(shelf.x + mouth.X * H, 3 * MapScale.V, shelf.z + mouth.Y * H), Vector3.new(0, 0, -1), 1.9)
	local chambers, tunnels = shelfCave(shelf)

	-- The cave network under the whole map, with an entrance on every island.
	local network = Caves.build(workspace.Terrain, ISLANDS, groundAt, function(isl, x, z)
		local field = if isl.biome == "clover" then CloverIsland else IslandFields[isl.biome]
		local rx, rz = (x - isl.x) / H, (z - isl.z) / H
		local far = (Vector3.new(x, 0, z) - Vector3.new(sx, 0, sz)).Magnitude > 60
		return far and (field == nil or field.canGrow(rx, rz))
	end)
	for _, e in network.entrances do
		makeCaveMouth(e.pos, e.facing, Caves.HALL_R / 7)
	end
	table.move(network.chambers, 1, #network.chambers, #chambers + 1, chambers)
	table.move(network.tunnels, 1, #network.tunnels, #tunnels + 1, tunnels)
	dressCaves(nodes, chambers, tunnels, network.pockets)
	if network.hub then
		-- The heart of the Maw: a giant crystal pillar from floor to roof, ringed by
		-- torches, with a sign pointing the way down to the lairs.
		local hub = Instance.new("Model")
		hub.Name = "MawHeart"
		local c = network.hub.pos
		hub.WorldPivot = CFrame.new(c)
		local hit = caveFloorAt(c.X, c.Z, c.Y + 10)
		local floor = if hit then hit.Position else c
		crystal(hub, floor, Color3.fromRGB(190, 140, 255), true, Vector3.yAxis)
		local pillar = Props.part(hub, { Name = "HeartPillar", Size = Vector3.new(9, 46, 9), CFrame = CFrame.new(floor + Vector3.new(0, 23, 0)) * CFrame.Angles(0, 0.4, 0), Color = Color3.fromRGB(170, 120, 255), Material = Enum.Material.Glass, Transparency = 0.15 })
		local core = Props.part(hub, { Name = "HeartCore", Size = Vector3.new(3, 40, 3), CFrame = pillar.CFrame, Color = Color3.fromRGB(210, 170, 255), Material = Enum.Material.Neon, CanCollide = false })
		local light = Instance.new("PointLight")
		light.Color, light.Range, light.Brightness = Color3.fromRGB(190, 150, 255), 60, 2
		light.Parent = core
		for k = 0, 5 do
			local a = k / 6 * math.pi * 2
			local at = caveFloorAt(floor.X + math.cos(a) * 20, floor.Z + math.sin(a) * 20, floor.Y + 12)
			if at then
				if k % 2 == 0 then
					Props.torchPost(hub, at.Position, 8)
				else
					crystal(hub, at.Position, CRYSTAL_GLOW[rng:NextInteger(1, #CRYSTAL_GLOW)], true, Vector3.yAxis)
				end
			end
		end
		Props.bigSign(hub, floor + Vector3.new(0, 0, 14), Vector3.new(0, 0, 1), "THE MAW")
		hub.Parent = workspace
	end
	Landmarks.build(network, ISLANDS, groundAt, function(isl)
		return findSpot(isl, {}, 0, Vector3.new(isl.x, 0, isl.z), isl.r * 0.4, "*")
	end)
	-- The Sunfruit Giant can be chopped down: its trunk, fronds and fruit become a node.
	local giantLandmark = workspace.Landmarks:FindFirstChild("The Sunfruit Giant")
	if giantLandmark then
		local giant = Instance.new("Model")
		giant.Name = "SunfruitGiant"
		for _, p in giantLandmark:GetDescendants() do
			if p:IsA("BasePart") and (p.Name == "Trunk" or p.Name == "Frond" or p.Name == "Sunfruit") then
				if not p.CanCollide then
					p:SetAttribute("BaseCollide", false)
				end
				p.Parent = giant
			end
		end
		local trunk = giant:FindFirstChild("Trunk") :: BasePart?
		if trunk then
			giant.PrimaryPart = trunk
			giant:SetAttribute("NodeType", "SunfruitGiant")
			giant:SetAttribute("DisplayName", Nodes.SunfruitGiant.name)
			giant:SetAttribute("HP", Nodes.SunfruitGiant.hp)
			giant:SetAttribute("MaxHP", Nodes.SunfruitGiant.hp)
			giant:SetAttribute("Depleted", false)
			giant.Parent = nodes
		else
			giant:Destroy()
		end
	end
	-- Camps on most islands, on a flat open spot away from the landmark; clear the
	-- trees and rocks inside their walls.
	Camps.build(ISLANDS, groundAt, function(isl)
		for _ = 1, 40 do
			local spot = findSpot(isl, {}, 0, nil, nil, "*")
			if spot and (spot - Vector3.new(sx, spot.Y, sz)).Magnitude > 120 then
				local flat = true
				for k = 0, 7 do
					local a = k / 8 * math.pi * 2
					local hit = groundAt(spot.X + math.cos(a) * 24, spot.Z + math.sin(a) * 24)
					if not hit or math.abs(hit.Position.Y - spot.Y) > 5 or hit.Material == Enum.Material.Water or hit.Position.Y < 1 then
						flat = false
						break
					end
				end
				local clear = true
				for _, lm in (workspace:FindFirstChild("Landmarks") :: Folder):GetChildren() do
					if (lm:GetPivot().Position - spot).Magnitude < 70 then
						clear = false
					end
				end
				if flat and clear then
					return spot
				end
			end
		end
		return nil
	end)
	for _, camp in workspace.Camps:GetChildren() do
		local c = camp:GetPivot().Position
		for _, n in nodes:GetChildren() do
			if (n:GetPivot().Position - c).Magnitude < 30 then
				n:Destroy()
			end
		end
		for _, d in workspace.Decor:GetChildren() do
			if (d.Position - c).Magnitude < 28 then
				d:Destroy()
			end
		end
	end
	Minimap.publish(ISLANDS, network, groundAt)
	if game:GetService("RunService"):IsStudio() and workspace:GetAttribute("VerifyCaves") ~= false then
		task.spawn(Caves.verify, workspace.Terrain, network)
	end

	-- Boars roam the two grassy islands.
	Animals.spawnHerd("Boar", Vector3.new(home.x + CloverIsland.Herd.X * H, 0, home.z + CloverIsland.Herd.Y * H), 5)
	local hills = ISLANDS[2]
	Animals.spawnHerd("Boar", Vector3.new(hills.x - 20 * H, 0, hills.z + 45 * H), 6) -- Pine Hills' meadow
	-- Everything else, by island: { kind, herds, per herd, zone }.
	local MOBS = {
		["Clover Island"] = { { "Crab", 2, 3, "palms" } },
		["Coral Atoll"] = { { "Crab", 4, 3, "shore" }, { "Boar", 1, 3, "inland" }, { "Turtle", 3, 2, "shore" } },
		["Sunfruit Isle"] = { { "Boar", 2, 3, "inland" }, { "Turtle", 2, 2, "shore" }, { "Crab", 2, 3, "shore" } },
		["Pine Hills"] = { { "Boar", 1, 4, "forest" } },
		["Silver Crags"] = { { "Wolf", 2, 3, "inland" }, { "Goat", 2, 3, "peak" } },
		["Frost Isle"] = { { "Wolf", 3, 3, "slopes" } },
		["Slime Marsh"] = { { "BogSlime", 4, 3, "*" } },
		["Gold Mesa"] = { { "Boar", 2, 3, "inland" }, { "Goat", 3, 3, "*" } },
		["Driftwood Cay"] = { { "Crab", 3, 3, "shore" }, { "Turtle", 2, 2, "shore" } },
		["Old Ruins"] = { { "Wolf", 2, 3, "inland" }, { "Boar", 2, 4, "inland" } },
		["Ember Isle"] = { { "CinderBeetle", 3, 2, "slopes" } },
		["Skull Key"] = { { "Crab", 2, 4, "*" } },
	}
	for _, isl in ISLANDS do
		for _, mob in MOBS[isl.name] or {} do
			for _ = 1, mob[2] do
				local spot = findSpot(isl, {}, 0, nil, nil, mob[4])
				if spot then
					Animals.spawnHerd(mob[1], spot, mob[3])
				end
			end
		end
	end
	-- Cave Crawlers wait in some of the lower and deep chambers.
	for _, c in network.chambers do
		if (c.tier == "lower" or c.tier == "deep") and rng:NextNumber() < 0.35 then
			Animals.spawnHerd("CaveCrawler", c.pos + Vector3.new(0, 3, 0), rng:NextInteger(1, 2))
		end
	end
	-- A boss in each lair below the Maw.
	for _, lair in network.bossRooms do
		Animals.spawnHerd(lair.boss, lair.pos + Vector3.new(0, 3, 0), 1)
	end
	Animals.start()

	startDayNight()
end

return WorldBuilder
