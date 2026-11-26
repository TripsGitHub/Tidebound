-- Builds the test world when the server starts: a flat sandy-green test ground,
-- palms, boulders, bushes, slime pools, a quest board and a trader.
-- (The real hand-built islands replace this in a later milestone.)
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Nodes = require(Shared.Nodes)
local Remotes = require(Shared.Remotes)

local WorldBuilder = {}

local rng = Random.new(2026)

local COLORS = {
	grass = Color3.fromRGB(111, 176, 82),
	sand = Color3.fromRGB(232, 214, 160),
	trunk = Color3.fromRGB(140, 104, 70),
	leaf = Color3.fromRGB(76, 160, 70),
	leafDark = Color3.fromRGB(58, 130, 58),
	coconut = Color3.fromRGB(105, 72, 45),
	rock = Color3.fromRGB(135, 135, 140),
	rockDark = Color3.fromRGB(108, 108, 115),
	bush = Color3.fromRGB(64, 140, 62),
	berry = Color3.fromRGB(200, 40, 70),
	slime = Color3.fromRGB(110, 220, 90),
}

local function part(props): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	p:SetAttribute("BaseTransparency", p.Transparency)
	p:SetAttribute("BaseCollide", p.CanCollide)
	return p
end

local function folder(name: string): Folder
	local f = workspace:FindFirstChild(name)
	if f then
		f:Destroy()
	end
	local new = Instance.new("Folder")
	new.Name = name
	new.Parent = workspace
	return new
end

-- Node models --------------------------------------------------------------

local function makePalm(pos: Vector3): Model
	local model = Instance.new("Model")
	local lean = CFrame.Angles(math.rad(rng:NextNumber(-8, 8)), rng:NextNumber(0, math.pi * 2), math.rad(rng:NextNumber(4, 10)))
	local cf = CFrame.new(pos) * lean
	local segments = 4
	local segHeight = 3.4
	local trunk
	for i = 0, segments - 1 do
		local seg = part({
			Name = if i == 0 then "Trunk" else "TrunkSegment",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(segHeight + 0.2, 1.5 - i * 0.12, 1.5 - i * 0.12),
			CFrame = cf * CFrame.new(0, segHeight * (i + 0.5), 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color = if i % 2 == 0 then COLORS.trunk else COLORS.trunk:Lerp(Color3.new(0, 0, 0), 0.12),
			Material = Enum.Material.Wood,
		})
		seg.Parent = model
		if i == 0 then
			trunk = seg
		end
		cf = cf * CFrame.Angles(0, 0, math.rad(3))
	end
	local top = cf * CFrame.new(0, segHeight * segments, 0)
	local fronds = 6
	for i = 0, fronds - 1 do
		local yaw = i / fronds * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local frond = part({
			Name = "Frond",
			Size = Vector3.new(1.8, 0.25, 6.5),
			CFrame = top * CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.rad(-22), 0, 0) * CFrame.new(0, 0, -3),
			Color = if i % 2 == 0 then COLORS.leaf else COLORS.leafDark,
			Material = Enum.Material.Grass,
			CanCollide = false,
		})
		frond.Parent = model
	end
	for i = 0, 2 do
		local yaw = i / 3 * math.pi * 2
		local nut = part({
			Name = "Coconut",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.9, 0.9, 0.9),
			CFrame = top * CFrame.Angles(0, yaw, 0) * CFrame.new(0, -0.6, -0.7),
			Color = COLORS.coconut,
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
		})
		nut.Parent = model
	end
	model.PrimaryPart = trunk
	return model
end

local function makeBoulder(pos: Vector3): Model
	local model = Instance.new("Model")
	local main = part({
		Name = "Rock",
		Size = Vector3.new(6, 4.2, 5.2),
		CFrame = CFrame.new(pos + Vector3.new(0, 1.6, 0)) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6.28), rng:NextNumber(-0.3, 0.3)),
		Color = COLORS.rock,
		Material = Enum.Material.Slate,
	})
	main.Parent = model
	local side = part({
		Name = "RockSide",
		Size = Vector3.new(3.2, 2.6, 3),
		CFrame = main.CFrame * CFrame.new(2.6, -0.8, 1) * CFrame.Angles(0.4, 0.7, 0.2),
		Color = COLORS.rockDark,
		Material = Enum.Material.Slate,
	})
	side.Parent = model
	model.PrimaryPart = main
	return model
end

local function makeBush(pos: Vector3): Model
	local model = Instance.new("Model")
	local main
	for i = 0, 2 do
		local offset = Vector3.new(rng:NextNumber(-1.2, 1.2), 0, rng:NextNumber(-1.2, 1.2))
		local d = rng:NextNumber(2.6, 3.4)
		local ball = part({
			Name = "Leaves",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(d, d, d),
			Position = pos + offset + Vector3.new(0, d / 2 - 0.3, 0),
			Color = COLORS.bush:Lerp(COLORS.leafDark, i * 0.25),
			Material = Enum.Material.Grass,
		})
		ball.Parent = model
		main = main or ball
	end
	for _ = 1, 5 do
		local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0.2, 1), rng:NextNumber(-1, 1)).Unit
		local berry = part({
			Name = "Berry",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.45, 0.45, 0.45),
			Position = pos + Vector3.new(0, 1.3, 0) + dir * 1.6,
			Color = COLORS.berry,
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
		})
		berry.Parent = model
	end
	model.PrimaryPart = main
	return model
end

local function makeSlimePool(pos: Vector3): Model
	local model = Instance.new("Model")
	local pool = part({
		Name = "Pool",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 6, 6),
		CFrame = CFrame.new(pos + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = COLORS.slime,
		Material = Enum.Material.Glass,
		Transparency = 0.15,
	})
	pool.Parent = model
	for i = 1, 3 do
		local d = rng:NextNumber(1, 1.6)
		local blob = part({
			Name = "Blob",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(d, d, d),
			Position = pos + Vector3.new(rng:NextNumber(-1.8, 1.8), 0.4 + d / 3, rng:NextNumber(-1.8, 1.8)),
			Color = COLORS.slime:Lerp(Color3.new(1, 1, 1), 0.1 * i),
			Material = Enum.Material.Glass,
			Transparency = 0.1,
			CanCollide = false,
		})
		blob:SetAttribute("Bob", true)
		blob.Parent = model
	end
	model.PrimaryPart = pool
	return model
end

local makers = {
	Palm = makePalm,
	Boulder = makeBoulder,
	Bush = makeBush,
	SlimePool = makeSlimePool,
}

-- Landmarks ----------------------------------------------------------------

local function makeQuestBoard(pos: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "QuestBoard"
	for _, x in { -2.6, 2.6 } do
		part({ Name = "Post", Size = Vector3.new(0.6, 7, 0.6), Position = pos + Vector3.new(x, 3.5, 0), Color = COLORS.trunk, Material = Enum.Material.Wood }).Parent = model
	end
	local board = part({ Name = "Board", Size = Vector3.new(6, 3.6, 0.4), Position = pos + Vector3.new(0, 4.6, 0), Color = Color3.fromRGB(170, 128, 84), Material = Enum.Material.WoodPlanks })
	board.Parent = model
	part({ Name = "Roof", Size = Vector3.new(7, 0.4, 1.6), Position = pos + Vector3.new(0, 7.1, 0), Color = COLORS.trunk, Material = Enum.Material.Wood }).Parent = model
	for i, x in { -1.6, 0.1, 1.7 } do
		part({
			Name = "Note",
			Size = Vector3.new(1.3, 1.6, 0.05),
			CFrame = CFrame.new(pos + Vector3.new(x, 4.6 + (i % 2) * 0.3, -0.23)) * CFrame.Angles(0, 0, math.rad((i - 2) * 6)),
			Color = Color3.fromRGB(245, 235, 205),
			Material = Enum.Material.SmoothPlastic,
		}).Parent = model
	end
	local sign = Instance.new("BillboardGui")
	sign.Size = UDim2.fromOffset(160, 30)
	sign.StudsOffset = Vector3.new(0, 3, 0)
	sign.MaxDistance = 60
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Text = "Quest Board"
	label.Parent = sign
	sign.Parent = board

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "View quests"
	prompt.ObjectText = "Quest Board"
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = board
	prompt.Triggered:Connect(function(player)
		Remotes.OpenPanel:FireClient(player, "quests")
	end)
	model.Parent = workspace
	return model
end

local function makeTrader(pos: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "Trader"
	local skin = Color3.fromRGB(204, 160, 120)
	part({ Name = "Legs", Size = Vector3.new(2, 2, 1), Position = pos + Vector3.new(0, 1, 0), Color = Color3.fromRGB(120, 90, 60), Material = Enum.Material.Fabric }).Parent = model
	part({ Name = "Body", Size = Vector3.new(2.2, 2.2, 1.1), Position = pos + Vector3.new(0, 3.1, 0), Color = Color3.fromRGB(60, 120, 150), Material = Enum.Material.Fabric }).Parent = model
	local head = part({ Name = "Head", Size = Vector3.new(1.4, 1.4, 1.4), Position = pos + Vector3.new(0, 4.9, 0), Color = skin, Material = Enum.Material.SmoothPlastic })
	head.Parent = model
	part({ Name = "Hat", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 3, 3), CFrame = CFrame.new(pos + Vector3.new(0, 5.7, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(220, 190, 110), Material = Enum.Material.Fabric }).Parent = model
	-- Stall
	part({ Name = "Counter", Size = Vector3.new(6, 2.6, 1.6), Position = pos + Vector3.new(0, 1.3, -2.2), Color = COLORS.trunk, Material = Enum.Material.WoodPlanks }).Parent = model
	part({ Name = "Awning", Size = Vector3.new(7, 0.3, 4), CFrame = CFrame.new(pos + Vector3.new(0, 7, -1)) * CFrame.Angles(math.rad(-12), 0, 0), Color = Color3.fromRGB(230, 120, 80), Material = Enum.Material.Fabric }).Parent = model
	for _, x in { -3.2, 3.2 } do
		part({ Name = "Pole", Size = Vector3.new(0.4, 7, 0.4), Position = pos + Vector3.new(x, 3.5, -2.8), Color = COLORS.trunk, Material = Enum.Material.Wood }).Parent = model
	end

	local sign = Instance.new("BillboardGui")
	sign.Size = UDim2.fromOffset(160, 30)
	sign.StudsOffset = Vector3.new(0, 2.6, 0)
	sign.MaxDistance = 60
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Text = "Trader"
	label.Parent = sign
	sign.Parent = head

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Trade"
	prompt.ObjectText = "Trader"
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = head
	prompt.Triggered:Connect(function(player)
		Remotes.OpenPanel:FireClient(player, "shop")
	end)
	model.Parent = workspace
	return model
end

-- World --------------------------------------------------------------------

local function setLighting()
	Lighting.ClockTime = 13.5
	Lighting.Brightness = 2.5
	Lighting.Ambient = Color3.fromRGB(110, 110, 120)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 150)
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local atmosphere = Instance.new("Atmosphere")
		atmosphere.Density = 0.25
		atmosphere.Color = Color3.fromRGB(200, 225, 240)
		atmosphere.Decay = Color3.fromRGB(120, 170, 200)
		atmosphere.Parent = Lighting
	end
end

local function scatter(nodeFolder: Folder, nodeType: string, count: number, minR: number, maxR: number, taken: { Vector3 })
	local made = 0
	local tries = 0
	while made < count and tries < count * 30 do
		tries += 1
		local angle = rng:NextNumber(0, math.pi * 2)
		local r = math.sqrt(rng:NextNumber((minR / maxR) ^ 2, 1)) * maxR
		local pos = Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r)
		local clear = true
		for _, other in taken do
			if (other - pos).Magnitude < 9 then
				clear = false
				break
			end
		end
		if clear then
			table.insert(taken, pos)
			local model = makers[nodeType](pos)
			model.Name = nodeType
			model:SetAttribute("NodeType", nodeType)
			model:SetAttribute("HP", Nodes[nodeType].hp)
			model:SetAttribute("Depleted", false)
			model.Parent = nodeFolder
			made += 1
		end
	end
end

function WorldBuilder.build()
	-- Replace Studio's default baseplate and spawn with ours.
	for _, child in workspace:GetChildren() do
		if child.Name == "Baseplate" or child:IsA("SpawnLocation") then
			child:Destroy()
		end
	end
	setLighting()

	local old = workspace:FindFirstChild("TestGround")
	if old then
		old:Destroy()
	end
	local ground = Instance.new("Model")
	ground.Name = "TestGround"
	part({ Name = "Grass", Size = Vector3.new(320, 2, 320), Position = Vector3.new(0, -1, 0), Color = COLORS.grass, Material = Enum.Material.Grass }).Parent = ground
	part({ Name = "Beach", Size = Vector3.new(380, 1.8, 380), Position = Vector3.new(0, -1.2, 0), Color = COLORS.sand, Material = Enum.Material.Sand }).Parent = ground
	ground.Parent = workspace

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "TideboundSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 0.4, 10)
	spawn.Position = Vector3.new(0, 0.2, 0)
	spawn.Color = COLORS.sand
	spawn.Material = Enum.Material.Sand
	spawn.Duration = 3
	spawn.Neutral = true
	spawn.Parent = workspace

	local nodes = folder("Nodes")
	folder("Structures")
	folder("LootSacks")

	-- Keep the middle clear around spawn, the board and the trader.
	local taken = { Vector3.zero, Vector3.new(14, 0, 14), Vector3.new(-14, 0, 14) }
	scatter(nodes, "Bush", 16, 22, 90, taken)
	scatter(nodes, "Palm", 26, 26, 140, taken)
	scatter(nodes, "Boulder", 16, 30, 130, taken)
	scatter(nodes, "SlimePool", 6, 60, 140, taken)

	makeQuestBoard(Vector3.new(14, 0, 14))
	makeTrader(Vector3.new(-14, 0, 14))
end

return WorldBuilder
