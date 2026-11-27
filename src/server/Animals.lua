-- Animals that wander the island. Hit one and it runs, then turns and fights back.
-- Kill it for meat and leather.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AnimalDefs = require(Shared.Animals)
local Meshes = require(Shared.Meshes)
local Inventory = require(script.Parent.Inventory)
local Drops = require(script.Parent.Drops)
local Remotes = require(Shared.Remotes)
local Progression = require(script.Parent.Progression)
local Quests = require(script.Parent.Quests)

local Animals = {}
local Bosses -- required lazily (it needs Inventory, which is fine, but keeps start-up order simple)

type State = {
	model: Model,
	def: any,
	home: Vector3,
	target: Vector3?,
	mode: string, -- "wander" | "idle" | "flee" | "angry"
	modeUntil: number,
	attacker: Player?,
	nextBite: number,
	phase: number,
	nearest: Player?,
	nearestDist: number,
	limbs: { { part: BasePart, rest: CFrame, kind: string, side: number } }?,
	windupUntil: number?,
	busyUntil: number?,
}

local states: { [Model]: State } = {}
local rng = Random.new()

local function folder(): Folder
	return workspace:WaitForChild("Animals") :: Folder
end

local function groundAt(x: number, z: number): (Vector3?, Enum.Material?)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	params.IgnoreWater = false
	local hit = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -600, 0), params)
	if hit then
		return hit.Position, hit.Material
	end
	return nil, nil
end

local function part(model: Model, size: Vector3, cf: CFrame, color: Color3, name: string?): Part
	local p = Instance.new("Part")
	p.Name = name or "Part"
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

-- A chunky low-poly boar, facing -Z, standing on the origin.
local function buildBoar(): Model
	local m = Instance.new("Model")
	local fur = Color3.fromRGB(110, 78, 56)
	local dark = Color3.fromRGB(76, 52, 38)
	local body = part(m, Vector3.new(2.6, 2.2, 4.2), CFrame.new(0, 2.3, 0), fur, "Body")
	part(m, Vector3.new(2.2, 0.6, 3.6), CFrame.new(0, 3.45, 0.1), dark, "Mane")
	part(m, Vector3.new(2, 1.8, 1.6), CFrame.new(0, 2.5, -2.6), fur, "Head")
	part(m, Vector3.new(1.1, 0.8, 0.6), CFrame.new(0, 2.1, -3.6), Color3.fromRGB(196, 140, 130), "Snout")
	for _, x in { -0.55, 0.55 } do
		part(m, Vector3.new(0.15, 0.7, 0.15), CFrame.new(x, 2.1, -3.7) * CFrame.Angles(math.rad(-30), 0, 0), Color3.fromRGB(240, 232, 210), "Tusk")
		part(m, Vector3.new(0.5, 0.6, 0.2), CFrame.new(x * 1.3, 3.5, -2.4), dark, "Ear")
		part(m, Vector3.new(0.25, 0.25, 0.1), CFrame.new(x * 0.9, 2.9, -3.42), Color3.new(0, 0, 0), "Eye")
	end
	for _, pos in { Vector3.new(-0.8, 0.6, -1.4), Vector3.new(0.8, 0.6, -1.4), Vector3.new(-0.8, 0.6, 1.4), Vector3.new(0.8, 0.6, 1.4) } do
		part(m, Vector3.new(0.6, 1.3, 0.6), CFrame.new(pos), dark, "Leg")
	end
	part(m, Vector3.new(0.2, 0.2, 0.8), CFrame.new(0, 2.8, 2.4) * CFrame.Angles(math.rad(40), 0, 0), dark, "Tail")
	m.PrimaryPart = body
	body.PivotOffset = body.CFrame:Inverse() -- pivot at the feet
	for _, p in m:GetChildren() do
		(p :: BasePart).CanQuery = true
	end
	return m
end

-- The Blender boar faces -Z like the block one, so either works.
local function boar(): Model
	local model = Meshes.build("boar", { collide = false })
	if not model then
		return buildBoar()
	end
	for _, p in model:GetChildren() do
		(p :: BasePart).CanQuery = true
	end
	return model
end

-- Block models for the other animals, all facing -Z and standing on the origin.
local function legs(m: Model, color: Color3, spots: { Vector3 }, size: Vector3)
	for _, pos in spots do
		part(m, size, CFrame.new(pos), color, "Leg")
	end
end

local function crab(): Model
	local m = Instance.new("Model")
	local shell, claw = Color3.fromRGB(214, 84, 52), Color3.fromRGB(232, 120, 80)
	part(m, Vector3.new(2.6, 1, 2), CFrame.new(0, 1.1, 0), shell, "Body")
	for _, x in { -1, 1 } do
		part(m, Vector3.new(0.9, 0.7, 1.1), CFrame.new(x * 1.6, 1.2, -1.2) * CFrame.Angles(0, x * 0.4, 0), claw, "Claw")
		part(m, Vector3.new(0.2, 0.6, 0.2), CFrame.new(x * 0.4, 1.8, -0.8), shell, "Stalk")
		part(m, Vector3.new(0.3, 0.3, 0.3), CFrame.new(x * 0.4, 2.15, -0.8), Color3.new(0, 0, 0), "Eye")
		for k = -1, 1 do
			part(m, Vector3.new(1.2, 0.2, 0.2), CFrame.new(x * 1.6, 0.6, k * 0.6) * CFrame.Angles(0, 0, x * -0.6), shell, "Leg")
		end
	end
	return m
end

local function wolf(): Model
	local m = Instance.new("Model")
	local fur, dark = Color3.fromRGB(150, 154, 162), Color3.fromRGB(92, 96, 106)
	part(m, Vector3.new(1.8, 1.8, 4.2), CFrame.new(0, 2.6, 0), fur, "Body")
	part(m, Vector3.new(1.6, 1.5, 1.6), CFrame.new(0, 3.2, -2.6), fur, "Head")
	part(m, Vector3.new(0.9, 0.7, 1.2), CFrame.new(0, 2.9, -3.8), dark, "Snout")
	for _, x in { -0.5, 0.5 } do
		part(m, Vector3.new(0.4, 0.7, 0.3), CFrame.new(x, 4.2, -2.4), dark, "Ear")
		part(m, Vector3.new(0.25, 0.2, 0.1), CFrame.new(x * 0.8, 3.5, -3.42), Color3.fromRGB(255, 210, 80), "Eye")
	end
	part(m, Vector3.new(0.5, 0.5, 2), CFrame.new(0, 3.2, 2.8) * CFrame.Angles(math.rad(30), 0, 0), dark, "Tail")
	legs(m, dark, { Vector3.new(-0.6, 0.9, -1.4), Vector3.new(0.6, 0.9, -1.4), Vector3.new(-0.6, 0.9, 1.4), Vector3.new(0.6, 0.9, 1.4) }, Vector3.new(0.5, 1.8, 0.5))
	return m
end

local function bogSlime(): Model
	local m = Instance.new("Model")
	local body = part(m, Vector3.new(3.4, 2.6, 3.4), CFrame.new(0, 1.3, 0), Color3.fromRGB(120, 214, 84), "Body")
	body.Material = Enum.Material.Glass
	body.Transparency = 0.25
	part(m, Vector3.new(1.6, 1, 1.6), CFrame.new(0, 1.1, 0), Color3.fromRGB(70, 140, 50), "Core")
	for _, x in { -0.6, 0.6 } do
		part(m, Vector3.new(0.4, 0.5, 0.1), CFrame.new(x, 1.8, -1.72), Color3.new(0, 0, 0), "Eye")
	end
	return m
end

local function cinderBeetle(): Model
	local m = Instance.new("Model")
	local shell, glow = Color3.fromRGB(36, 32, 38), Color3.fromRGB(255, 110, 40)
	part(m, Vector3.new(3.4, 2, 4.6), CFrame.new(0, 1.8, 0.2), shell, "Body")
	local seam = part(m, Vector3.new(0.3, 0.3, 4.4), CFrame.new(0, 2.85, 0.2), glow, "Seam")
	seam.Material = Enum.Material.Neon
	part(m, Vector3.new(2, 1.2, 1.4), CFrame.new(0, 1.6, -2.6), shell, "Head")
	for _, x in { -1, 1 } do
		part(m, Vector3.new(0.3, 0.3, 1.4), CFrame.new(x * 0.6, 1.6, -3.8) * CFrame.Angles(0, x * -0.4, 0), glow, "Mandible").Material = Enum.Material.Neon
		for k = -1, 1 do
			part(m, Vector3.new(1.6, 0.3, 0.3), CFrame.new(x * 2.2, 0.7, k * 1.3) * CFrame.Angles(0, 0, x * -0.7), shell, "Leg")
		end
	end
	return m
end

local function caveCrawler(): Model
	local m = Instance.new("Model")
	local hide, eye = Color3.fromRGB(58, 52, 64), Color3.fromRGB(150, 230, 255)
	part(m, Vector3.new(2.6, 1.6, 3.2), CFrame.new(0, 2, 0.8), hide, "Body")
	part(m, Vector3.new(1.8, 1.3, 1.6), CFrame.new(0, 2, -1.4), hide, "Head")
	for i, x in { -0.5, 0, 0.5 } do
		local e = part(m, Vector3.new(0.3, 0.3, 0.1), CFrame.new(x, 2.3 + (if i == 2 then 0.3 else 0), -2.22), eye, "Eye")
		e.Material = Enum.Material.Neon
	end
	for _, x in { -1, 1 } do
		for k = 0, 3 do
			part(m, Vector3.new(2.4, 0.3, 0.3), CFrame.new(x * 2, 1.3, -1 + k * 0.9) * CFrame.Angles(0, (k - 1.5) * 0.25 * x, x * -0.8), hide, "Leg")
		end
	end
	return m
end

local function goat(): Model
	local m = Instance.new("Model")
	local fur, horn = Color3.fromRGB(236, 230, 214), Color3.fromRGB(120, 104, 84)
	part(m, Vector3.new(1.8, 1.7, 3.4), CFrame.new(0, 2.4, 0), fur, "Body")
	part(m, Vector3.new(1.2, 1.3, 1.5), CFrame.new(0, 3.3, -2.1), fur, "Head")
	part(m, Vector3.new(0.5, 0.8, 0.4), CFrame.new(0, 2.4, -2.7), fur, "Beard")
	for _, x in { -0.4, 0.4 } do
		part(m, Vector3.new(0.25, 1.1, 0.25), CFrame.new(x, 4.2, -1.9) * CFrame.Angles(math.rad(35), 0, x * 0.5), horn, "Horn")
		part(m, Vector3.new(0.2, 0.2, 0.1), CFrame.new(x * 0.9, 3.5, -2.86), Color3.new(0, 0, 0), "Eye")
	end
	legs(m, horn, { Vector3.new(-0.55, 0.8, -1.1), Vector3.new(0.55, 0.8, -1.1), Vector3.new(-0.55, 0.8, 1.1), Vector3.new(0.55, 0.8, 1.1) }, Vector3.new(0.4, 1.6, 0.4))
	return m
end

local function turtle(): Model
	local m = Instance.new("Model")
	local shell, skin = Color3.fromRGB(96, 120, 60), Color3.fromRGB(150, 170, 100)
	local s = part(m, Vector3.new(3.2, 1.4, 3.8), CFrame.new(0, 1.3, 0), shell, "Shell")
	part(m, Vector3.new(2.4, 0.5, 3), CFrame.new(0, 2.1, 0), Color3.fromRGB(120, 140, 70), "ShellTop")
	part(m, Vector3.new(1.1, 0.9, 1.2), CFrame.new(0, 1.2, -2.3), skin, "Head")
	for _, x in { -0.3, 0.3 } do
		part(m, Vector3.new(0.18, 0.18, 0.1), CFrame.new(x, 1.4, -2.92), Color3.new(0, 0, 0), "Eye")
	end
	legs(m, skin, { Vector3.new(-1.4, 0.5, -1.2), Vector3.new(1.4, 0.5, -1.2), Vector3.new(-1.4, 0.5, 1.2), Vector3.new(1.4, 0.5, 1.2) }, Vector3.new(0.9, 0.8, 0.9))
	s.Material = Enum.Material.Slate
	return m
end

-- Bosses -------------------------------------------------------------------------
local function neon(p: BasePart): BasePart
	p.Material = Enum.Material.Neon
	return p
end

local function crawlerQueen(): Model
	local m = caveCrawler()
	m:ScaleTo(3.2)
	local hide = Color3.fromRGB(76, 60, 84)
	part(m, Vector3.new(7, 5, 9), CFrame.new(0, 7, 9), hide, "EggSac")
	for _, x in { -1, 1 } do
		part(m, Vector3.new(1, 1, 6), CFrame.new(x * 2.4, 9, -6) * CFrame.Angles(math.rad(30), x * 0.3, 0), hide, "Fang")
		neon(part(m, Vector3.new(1.2, 1.2, 0.3), CFrame.new(x * 1.6, 9.4, -7.2), Color3.fromRGB(255, 80, 120), "Eye"))
	end
	return m
end

local function crystalWarden(): Model
	local m = Instance.new("Model")
	local stone, glow = Color3.fromRGB(70, 66, 92), Color3.fromRGB(190, 140, 255)
	part(m, Vector3.new(8, 9, 5), CFrame.new(0, 11, 0), stone, "Body")
	part(m, Vector3.new(4.5, 4, 4), CFrame.new(0, 17.5, -0.4), stone, "Head")
	neon(part(m, Vector3.new(3, 0.6, 0.3), CFrame.new(0, 18, -2.5), glow, "Eye"))
	for _, x in { -1, 1 } do
		part(m, Vector3.new(3, 9, 3), CFrame.new(x * 6, 10, 0) * CFrame.Angles(0, 0, x * 0.15), stone, "Arm")
		neon(part(m, Vector3.new(2.4, 3.4, 2.4), CFrame.new(x * 6.8, 5, -0.4), glow, "Fist"))
		part(m, Vector3.new(3, 6.5, 3), CFrame.new(x * 2.3, 3.25, 0), stone, "Leg")
	end
	for i = 1, 5 do
		local a = (i - 3) * 0.35
		neon(part(m, Vector3.new(1.2, 4 + (3 - math.abs(i - 3)) * 1.5, 1.2), CFrame.new(math.sin(a) * 3.2, 17.5, 1.5) * CFrame.Angles(-0.4, 0, -a), glow, "Shard"))
	end
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = glow, 24, 2
	light.Parent = m:FindFirstChild("Eye")
	return m
end

local function magmaGolem(): Model
	local m = Instance.new("Model")
	local rock, lava = Color3.fromRGB(44, 36, 34), Color3.fromRGB(255, 110, 30)
	part(m, Vector3.new(10, 10, 7), CFrame.new(0, 13, 0), rock, "Body")
	neon(part(m, Vector3.new(5, 5, 0.4), CFrame.new(0, 13, -3.6), lava, "Core"))
	part(m, Vector3.new(5, 4, 4.5), CFrame.new(0, 20, -0.8), rock, "Head")
	for _, x in { -1.2, 1.2 } do
		neon(part(m, Vector3.new(1, 0.7, 0.3), CFrame.new(x, 20.4, -3.1), lava, "Eye"))
	end
	for _, x in { -1, 1 } do
		part(m, Vector3.new(4, 4, 4), CFrame.new(x * 7.4, 17, 0), rock, "Shoulder")
		part(m, Vector3.new(3.4, 10, 3.4), CFrame.new(x * 7.6, 10, 0), rock, "Arm")
		neon(part(m, Vector3.new(0.4, 8, 0.4), CFrame.new(x * 7.6, 10, -1.75), lava, "Crack"))
		part(m, Vector3.new(4, 8, 4), CFrame.new(x * 3, 4, 0), rock, "Leg")
	end
	local fire = Instance.new("Fire")
	fire.Size, fire.Heat, fire.Color, fire.SecondaryColor = 6, 4, lava, Color3.fromRGB(255, 200, 80)
	fire.Parent = m:FindFirstChild("Head")
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = lava, 28, 2.5
	light.Parent = m:FindFirstChild("Core")
	return m
end

local builders = { CrawlerQueen = crawlerQueen, CrystalWarden = crystalWarden, MagmaGolem = magmaGolem, Goat = goat, Turtle = turtle, Boar = boar, Crab = crab, Wolf = wolf, BogSlime = bogSlime, CinderBeetle = cinderBeetle, CaveCrawler = caveCrawler }

-- Cave animals can't look for the ground from the sky (that finds the island above
-- them), so they feel for the floor just under where they are.
local function floorNear(x: number, y: number, z: number): (Vector3?, Enum.Material?)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	params.IgnoreWater = false
	local hit = workspace:Raycast(Vector3.new(x, y + 5, z), Vector3.new(0, -14, 0), params)
	if hit then
		return hit.Position, hit.Material
	end
	return nil, nil
end

local function groundFor(s: State, x: number, z: number, y: number): (Vector3?, Enum.Material?)
	if s.def.cave then
		return floorNear(x, y, z)
	end
	return groundAt(x, z)
end

local function pickWanderTarget(s: State): Vector3?
	for _ = 1, 8 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(8, if s.def.cave then 20 else 40)
		local pos, mat = groundFor(s, s.home.X + math.cos(a) * r, s.home.Z + math.sin(a) * r, s.home.Y)
		if pos and mat ~= Enum.Material.Water and mat ~= Enum.Material.Rock then
			return pos
		end
	end
	return nil
end

local function spawnAnimal(kind: string, home: Vector3): Model
	local def = AnimalDefs[kind]
	local model = builders[kind]()
	model.Name = kind
	model:SetAttribute("AnimalType", kind)
	model:SetAttribute("HP", def.hp)
	model:SetAttribute("MaxHP", def.hp)
	model:PivotTo(CFrame.new(home))
	if def.boss then
		-- A boss's name hangs over it so you know what you've walked into.
		local _, size = model:GetBoundingBox()
		local tag = Instance.new("BillboardGui")
		tag.Name = "BossTag"
		tag.Size = UDim2.fromOffset(260, 40)
		tag.MaxDistance = 140
		tag.AlwaysOnTop = false
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.Cartoon
		label.TextScaled = true
		label.Text = def.name
		label.TextColor3 = Color3.fromRGB(255, 214, 120)
		label.TextStrokeTransparency = 0.2
		label.Parent = tag
		tag.Adornee = model:FindFirstChild("Body") or model:FindFirstChildWhichIsA("BasePart")
		tag.StudsOffsetWorldSpace = Vector3.new(0, size.Y * 0.6, 0)
		tag.Parent = model
	end
	model.Parent = folder()
	-- Remember where each limb sits on the body so the step can swing it.
	local limbs = {}
	local pivot = model:GetPivot()
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			local kind = if p.Name == "Leg" then "leg" elseif p.Name == "Arm" or p.Name == "Fist" or p.Name == "Claw" or p.Name == "Mandible" or p.Name == "Fang" then "arm" elseif p.Name == "Head" or p.Name == "Snout" or p.Name == "Eye" or p.Name == "Ear" or p.Name == "Horn" or p.Name == "Beard" then "head" elseif p.Name == "Tail" then "tail" else nil
			if kind then
				local rest = pivot:ToObjectSpace(p.CFrame)
				table.insert(limbs, { part = p, rest = rest, kind = kind, side = if rest.Position.X >= 0 then 1 else -1, front = rest.Position.Z < 0 })
			end
		end
	end
	states[model] = {
		model = model,
		def = def,
		home = home,
		target = nil,
		mode = "idle",
		modeUntil = os.clock() + rng:NextNumber(1, 4),
		attacker = nil,
		nextBite = 0,
		phase = rng:NextNumber(0, 6),
		nearest = nil,
		nearestDist = math.huge,
		limbs = limbs,
	}
	return model
end

-- Pose the limbs: legs swing in a trot while moving, the head dips and rises, arms and
-- jaws pull back during a wind-up and snap forward on the strike.
local function pose(s, moving: boolean, windup: number)
	local pivot = s.model:GetPivot()
	local t = s.phase
	for _, l in s.limbs or {} do
		local size = l.part.Size
		local cf = l.rest
		if l.kind == "leg" then
			local a = if moving then math.sin(t * 1.6 + (if l.front == (l.side > 0) then 0 else math.pi)) * 0.5 else 0
			if size.Y >= size.X then
				-- Upright leg: swing about its top.
				cf = cf * CFrame.new(0, size.Y / 2, 0) * CFrame.Angles(a, 0, 0) * CFrame.new(0, -size.Y / 2, 0)
			else
				-- Spidery leg sticking out sideways: lift and drop it.
				cf = cf * CFrame.Angles(0, a * 0.5, a * 0.4 * l.side)
			end
		elseif l.kind == "arm" then
			local a = -windup * 1.1 + (if moving then math.sin(t * 1.6 + (if l.side > 0 then math.pi else 0)) * 0.3 else 0)
			cf = cf * CFrame.new(0, size.Y / 2, 0) * CFrame.Angles(a, 0, 0) * CFrame.new(0, -size.Y / 2, 0)
		elseif l.kind == "head" then
			cf = CFrame.new(0, (if moving then math.sin(t * 3.2) * 0.12 else math.sin(os.clock() * 1.5) * 0.06) + windup * 0.4, windup * 0.5) * cf
		elseif l.kind == "tail" then
			cf = cf * CFrame.Angles(0, math.sin(t * 2.4 + os.clock() * 2) * 0.3, 0)
		end
		l.part.CFrame = pivot * cf
	end
end

-- One animal at a cave floor or ground spot near `at`; returns its model.
function Animals.spawnOne(kind: string, at: Vector3): Model?
	local pos = if AnimalDefs[kind].cave then floorNear(at.X, at.Y, at.Z) else groundAt(at.X, at.Z)
	if not pos then
		return nil
	end
	local model = spawnAnimal(kind, pos)
	model:SetAttribute("Minion", true) -- called up by a boss: doesn't come back when killed
	return model
end

function Animals.spawnHerd(kind: string, center: Vector3, count: number)
	local cave = AnimalDefs[kind].cave
	for _ = 1, count do
		local x, z = center.X + rng:NextNumber(-20, 20), center.Z + rng:NextNumber(-20, 20)
		local pos = if cave then floorNear(x, center.Y, z) else groundAt(x, z)
		if pos then
			spawnAnimal(kind, pos)
		end
	end
end

-- Called when a player hits an animal.
function Animals.damage(model: Model, amount: number, attacker: Player)
	local s = states[model]
	if not s then
		return
	end
	local hp = (model:GetAttribute("HP") or 0) - amount
	model:SetAttribute("HP", hp)
	if hp <= 0 then
		states[model] = nil
		local pos = model:GetPivot().Position + Vector3.new(0, 2, 0)
		for _, line in s.def.loot or {} do
			if not line[4] or rng:NextNumber() < line[4] then
				for _ = 1, rng:NextInteger(line[2], line[3]) do
					Drops.spawn(line[1], 1, pos)
				end
			end
		end
		Progression.addXp(attacker, s.def.xp)
		Quests.record(attacker, "hunt", model:GetAttribute("AnimalType"), 1)
		local minion = model:GetAttribute("Minion")
		model:Destroy()
		local kind, home = model.Name, s.home
		if not minion then
			task.delay(s.def.respawn, function()
				spawnAnimal(kind, home)
			end)
		end
		return
	end
	-- Run first, then come back angry. Hunters and bosses turn on you straight away.
	s.attacker = attacker
	if s.def.aggro and s.mode ~= "angry" then
		s.mode = "angry"
		s.modeUntil = os.clock() + 12
	elseif s.mode ~= "angry" then
		s.mode = "flee"
		s.modeUntil = os.clock() + 2
	end
end

local function step(s: State, dt: number)
	local now = os.clock()
	local model = s.model
	local pivot = model:GetPivot()
	local pos = pivot.Position
	local speed = s.def.walkSpeed
	local goal: Vector3? = nil

	local attackerRoot = s.attacker and s.attacker.Character and s.attacker.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local attackerHum = s.attacker and s.attacker.Character and s.attacker.Character:FindFirstChildOfClass("Humanoid")
	if (s.mode == "flee" or s.mode == "angry") and (not attackerRoot or not attackerHum or attackerHum.Health <= 0) then
		s.mode = "idle"
		s.attacker = nil
		s.modeUntil = now + 2
	end

	if s.mode == "flee" then
		speed = s.def.runSpeed
		if attackerRoot then
			local away = (pos - attackerRoot.Position) * Vector3.new(1, 0, 1)
			goal = pos + (if away.Magnitude > 0 then away.Unit else Vector3.xAxis) * 10
		end
		if now > s.modeUntil then
			s.mode = "angry"
			s.modeUntil = now + 12
		end
	elseif s.mode == "angry" and attackerRoot and attackerHum then
		speed = s.def.runSpeed * 0.85
		local toward = attackerRoot.Position - pos
		local flat = Vector3.new(toward.X, 0, toward.Z)
		local reach = s.def.reach or 4.5
		local busy = false
		if s.def.boss then
			Bosses = Bosses or require(script.Parent.Bosses)
			busy = Bosses.think(s, attackerRoot, function(kind, at)
				return Animals.spawnOne(kind, at)
			end)
			s.modeUntil = now + 12 -- a boss doesn't lose interest while you're in its lair
		end
		if busy then
			goal = nil
		elseif s.windupUntil then
			-- Mid wind-up: hold still, then strike whoever is still in reach.
			goal = nil
			if now >= s.windupUntil then
				s.windupUntil = nil
				s.nextBite = now + s.def.attackCooldown
				if flat.Magnitude < reach + 1.5 then
					local defense = Inventory.defense(s.attacker :: Player)
					attackerHum:TakeDamage(s.def.damage * (1 - defense))
					Remotes.HitFeedback:FireAllClients(s.attacker.Character)
				end
			end
		elseif flat.Magnitude < reach then
			goal = nil
			if now >= s.nextBite then
				-- A short, visible wind-up before every bite, so you can back off or block.
				s.windupUntil = now + (if s.def.boss then 0.6 else 0.35)
			end
		else
			goal = attackerRoot.Position
		end
		-- Face the target even when standing still.
		if not goal and flat.Magnitude > 0.1 then
			model:PivotTo(CFrame.lookAt(pos, pos + flat.Unit))
		end
		local leash = if s.def.boss then (pos - s.home).Magnitude > 70 else flat.Magnitude > 80
		if now > s.modeUntil or leash then
			s.mode = "idle"
			s.attacker = nil
			s.modeUntil = now + 3
		end
	elseif (s.mode == "idle" or s.mode == "wander") and s.def.aggro and s.nearest and s.nearestDist < s.def.aggro then
		-- Hostile animals come for whoever gets close.
		s.attacker = s.nearest
		s.mode = "angry"
		s.modeUntil = now + 12
	elseif s.mode == "idle" then
		if now > s.modeUntil then
			s.target = pickWanderTarget(s)
			s.mode = "wander"
			s.modeUntil = now + 10
		end
	elseif s.mode == "wander" then
		goal = s.target
		if not goal or (Vector3.new(goal.X, 0, goal.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude < 2 or now > s.modeUntil then
			s.mode = "idle"
			s.modeUntil = now + rng:NextNumber(2, 6)
			goal = nil
		end
	end

	if goal then
		local flat = Vector3.new(goal.X - pos.X, 0, goal.Z - pos.Z)
		if flat.Magnitude > 0.1 then
			local move = flat.Unit * math.min(flat.Magnitude, speed * dt)
			local nextPos = pos + move
			local ground, mat = groundFor(s, nextPos.X, nextPos.Z, pos.Y)
			if ground and mat ~= Enum.Material.Water then
				s.phase += dt * speed
				local bob = math.abs(math.sin(s.phase * 1.2)) * 0.15
				local look = CFrame.lookAt(ground, ground + flat.Unit)
				model:PivotTo(look + Vector3.new(0, bob, 0))
			else
				s.target = nil
			end
		end
	end
	local windup = if s.windupUntil then 1 - math.clamp((s.windupUntil - now) / 0.6, 0, 1) else 0
	pose(s, goal ~= nil, windup)
end

function Animals.start()
	local accum = 0
	RunService.Heartbeat:Connect(function(dt)
		accum += dt
		if accum < 1 / 15 then
			return
		end
		local step_dt = accum
		accum = 0
		-- Only animate animals someone is near; far ones just stand still.
		local roots = {}
		for _, p in Players:GetPlayers() do
			local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
			local h = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
			if r and h and h.Health > 0 then
				table.insert(roots, { player = p, pos = (r :: BasePart).Position })
			end
		end
		for _, s in states do
			local pos = s.model:GetPivot().Position
			local near = false
			s.nearest, s.nearestDist = nil, math.huge
			for _, r in roots do
				local d = (r.pos - pos).Magnitude
				if d < 250 then
					near = true
				end
				if d < s.nearestDist then
					s.nearest, s.nearestDist = r.player, d
				end
			end
			if near then
				step(s, step_dt)
			end
		end
	end)
end

return Animals
