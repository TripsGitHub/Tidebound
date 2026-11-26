-- Builds the test island when the server starts: Smooth Terrain island with beaches,
-- grass hills, rock cliffs and a snowy peak in an ocean, plus low-poly trees, rocks,
-- bushes, slime pools, boars, a quest board and a trader.
-- (The hand-built v2 map replaces this in a later milestone.)
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Nodes = require(Shared.Nodes)
local Remotes = require(Shared.Remotes)
local Animals = require(script.Parent.Animals)

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

-- Terrain ------------------------------------------------------------------------

local ISLAND_BLOBS = {
	-- x, z, radius of grass
	{ 0, 0, 105 },
	{ 95, 55, 70 },
	{ -85, -45, 80 },
	{ 35, -105, 60 },
	{ -55, 85, 55 },
}
local ISLET = { 250, -130, 34 }

local function buildTerrain()
	local terrain = workspace.Terrain
	terrain:Clear()
	terrain.WaterColor = Color3.fromRGB(38, 140, 170)
	terrain.WaterTransparency = 0.6
	terrain.WaterWaveSize = 0.12
	terrain.WaterWaveSpeed = 8
	terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(106, 158, 70))
	terrain:SetMaterialColor(Enum.Material.Sand, Color3.fromRGB(218, 196, 140))
	terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(110, 110, 116))

	-- Ocean and sea floor
	terrain:FillBlock(CFrame.new(0, -18, 0), Vector3.new(1200, 36, 1200), Enum.Material.Water)
	terrain:FillBlock(CFrame.new(0, -40, 0), Vector3.new(1200, 8, 1200), Enum.Material.Sand)

	local blobs = table.clone(ISLAND_BLOBS)
	table.insert(blobs, ISLET)
	-- Sand shelves stepping down into the water, then the beach, then grass.
	for _, b in blobs do
		local x, z, r = b[1], b[2], b[3]
		for k = 4, 1, -1 do
			local top = 1.5 - k * 7
			terrain:FillCylinder(CFrame.new(x, top - 20, z), 40, r + 18 + k * 12, Enum.Material.Sand)
		end
		terrain:FillCylinder(CFrame.new(x, 1.5 - 20, z), 40, r + 18, Enum.Material.Sand)
	end
	for _, b in blobs do
		terrain:FillCylinder(CFrame.new(b[1], 3 - 20, b[2]), 40, b[3], Enum.Material.Grass)
	end

	-- Rolling grass hills
	for _ = 1, 14 do
		local b = ISLAND_BLOBS[rng:NextInteger(1, #ISLAND_BLOBS)]
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(0, b[3] * 0.6)
		local radius = rng:NextNumber(16, 34)
		terrain:FillBall(Vector3.new(b[1] + math.cos(a) * d, -radius * 0.62, b[2] + math.sin(a) * d), radius, Enum.Material.Grass)
	end

	-- Rocky cliffs along the coast
	for _ = 1, 10 do
		local b = ISLAND_BLOBS[rng:NextInteger(1, #ISLAND_BLOBS)]
		local a = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(10, 18)
		local d = b[3] - radius * 0.3
		terrain:FillBall(Vector3.new(b[1] + math.cos(a) * d, -radius * 0.25, b[2] + math.sin(a) * d), radius, Enum.Material.Rock)
	end

	-- Snowy peak in the north-west
	terrain:FillBall(Vector3.new(-95, -12, -60), 46, Enum.Material.Grass)
	terrain:FillBall(Vector3.new(-95, 0, -60), 34, Enum.Material.Rock)
	terrain:FillBall(Vector3.new(-95, 14, -60), 22, Enum.Material.Snow)
end

local function groundAt(x: number, z: number): RaycastResult?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	params.IgnoreWater = false
	return workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -600, 0), params)
end

local ALLOWED = {
	Pine = { [Enum.Material.Grass] = true, [Enum.Material.Snow] = true },
	Palm = { [Enum.Material.Sand] = true },
	Boulder = { [Enum.Material.Grass] = true, [Enum.Material.Rock] = true, [Enum.Material.Snow] = true },
	Bush = { [Enum.Material.Grass] = true },
	SlimePool = { [Enum.Material.Grass] = true },
}

local function scatter(nodeFolder: Folder, nodeType: string, count: number, taken: { Vector3 })
	local made, tries = 0, 0
	local blobs = table.clone(ISLAND_BLOBS)
	table.insert(blobs, ISLET)
	while made < count and tries < count * 40 do
		tries += 1
		local b = blobs[rng:NextInteger(1, #blobs)]
		local a = rng:NextNumber(0, math.pi * 2)
		local d = math.sqrt(rng:NextNumber()) * (b[3] + 16)
		local hit = groundAt(b[1] + math.cos(a) * d, b[2] + math.sin(a) * d)
		if hit and ALLOWED[nodeType][hit.Material] and hit.Position.Y > 0.5 and hit.Normal.Y > 0.8 then
			local pos = hit.Position
			local clear = true
			for _, other in taken do
				if (other - pos).Magnitude < 10 then
					clear = false
					break
				end
			end
			if clear then
				table.insert(taken, pos)
				local model = makers[nodeType](CFrame.new(pos - Vector3.new(0, 0.3, 0)))
				model.Name = nodeType
				model:SetAttribute("NodeType", nodeType)
				model:SetAttribute("DisplayName", Nodes[nodeType].name)
				model:SetAttribute("HP", Nodes[nodeType].hp)
				model:SetAttribute("MaxHP", Nodes[nodeType].hp)
				model:SetAttribute("Depleted", false)
				model.Parent = nodeFolder
				made += 1
			end
		end
	end
end

-- Landmarks ----------------------------------------------------------------------

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

local function setLighting()
	Lighting.Brightness = 2.4
	Lighting.Ambient = Color3.fromRGB(90, 90, 100)
	Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 136)
	Lighting.EnvironmentDiffuseScale = 0.5
	Lighting.GlobalShadows = true
	Lighting.ClockTime = 9
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local a = Instance.new("Atmosphere")
		a.Density = 0.3
		a.Offset = 0.1
		a.Color = Color3.fromRGB(198, 220, 236)
		a.Decay = Color3.fromRGB(110, 150, 180)
		a.Haze = 1.2
		a.Parent = Lighting
	end
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

	-- Spawn on the south beach.
	local spawnHit = groundAt(0, 116)
	local spawnPos = if spawnHit then spawnHit.Position else Vector3.new(0, 3, 116)
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
	local boardHit = groundAt(-12, 96)
	local traderHit = groundAt(12, 96)
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
		table.insert(taken, spawnPos + Vector3.new(math.cos(a) * 8, 0, math.sin(a) * 8))
	end

	scatter(nodes, "Pine", 55, taken)
	scatter(nodes, "Palm", 26, taken)
	scatter(nodes, "Boulder", 30, taken)
	scatter(nodes, "Bush", 26, taken)
	scatter(nodes, "SlimePool", 6, taken)

	Animals.spawnHerd("Boar", Vector3.new(60, 0, 30), 3)
	Animals.spawnHerd("Boar", Vector3.new(-40, 0, 40), 3)
	Animals.start()

	startDayNight()
end

return WorldBuilder
