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
	limbs: { { part: BasePart, rest: CFrame, kind: string, side: number, hinge: Vector3? } }?,
	windupUntil: number?,
	busyUntil: number?,
	foot: number?,
	radius: number?,
	stuck: number?,
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

-- Shape helpers: rounded parts read far better than plain blocks.
local function ball(m: Model, size: Vector3, cf: CFrame, color: Color3, name: string?, mat: Enum.Material?): Part
	local p = part(m, size, cf, color, name)
	p.Shape = Enum.PartType.Ball
	if mat then
		p.Material = mat
	end
	return p
end
local function rod(m: Model, length: number, thick: number, from: Vector3, to: Vector3, color: Color3, name: string?): Part
	local p = part(m, Vector3.new(thick, thick, length), CFrame.lookAt((from + to) / 2, to), color, name)
	return p
end
local function eyes(m: Model, at: Vector3, gap: number, size: number, glow: Color3?)
	for _, x in { -gap, gap } do
		local white = ball(m, Vector3.one * size, CFrame.new(at + Vector3.new(x, 0, 0)), glow or Color3.fromRGB(240, 236, 220), "Eye")
		if glow then
			white.Material = Enum.Material.Neon
		else
			ball(m, Vector3.one * size * 0.55, CFrame.new(at + Vector3.new(x, 0, -size * 0.3)), Color3.fromRGB(20, 18, 16), "Eye")
		end
	end
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
	local fur, dark, belly = Color3.fromRGB(128, 132, 140), Color3.fromRGB(76, 78, 88), Color3.fromRGB(196, 198, 202)
	-- Deep chest tapering to the hips, a ruff of fur at the neck.
	local body = ball(m, Vector3.new(2.2, 2.2, 4.6), CFrame.new(0, 2.7, 0.2), fur, "Body")
	ball(m, Vector3.new(2.4, 2.4, 1.8), CFrame.new(0, 3, -1.5), fur, "Ruff")
	ball(m, Vector3.new(1.6, 1.1, 3), CFrame.new(0, 2.1, 0.3), belly, "Belly")
	-- Head: skull, long muzzle, nose, pointed ears and amber eyes.
	ball(m, Vector3.new(1.7, 1.6, 1.8), CFrame.new(0, 3.6, -2.6), fur, "Head")
	part(m, Vector3.new(0.9, 0.75, 1.5), CFrame.new(0, 3.25, -3.6), dark, "Snout")
	ball(m, Vector3.new(0.4, 0.35, 0.35), CFrame.new(0, 3.45, -4.35), Color3.fromRGB(20, 18, 18), "Snout")
	for _, x in { -0.5, 0.5 } do
		local ear = Instance.new("WedgePart")
		ear.Name = "Ear"
		ear.Size = Vector3.new(0.25, 0.9, 0.6)
		ear.CFrame = CFrame.new(x, 4.6, -2.4) * CFrame.Angles(0, math.pi, x * -0.3)
		ear.Color = dark
		ear.Anchored, ear.CanCollide = true, false
		ear.Parent = m
	end
	eyes(m, Vector3.new(0, 3.85, -3.35), 0.42, 0.32, Color3.fromRGB(255, 190, 60))
	-- Bushy tail.
	ball(m, Vector3.new(0.8, 0.8, 2.6), CFrame.new(0, 3.1, 3.2) * CFrame.Angles(math.rad(35), 0, 0), dark, "Tail")
	legs(m, dark, { Vector3.new(-0.65, 0.95, -1.5), Vector3.new(0.65, 0.95, -1.5), Vector3.new(-0.65, 0.95, 1.6), Vector3.new(0.65, 0.95, 1.6) }, Vector3.new(0.5, 1.9, 0.5))
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

-- A big cave spider: round abdomen, eight long legs, a cluster of glowing eyes and fangs.
local function caveCrawler(): Model
	local m = Instance.new("Model")
	local hide, mark, eye = Color3.fromRGB(46, 40, 52), Color3.fromRGB(110, 70, 120), Color3.fromRGB(150, 230, 255)
	local body = ball(m, Vector3.new(2, 1.6, 2), CFrame.new(0, 2, -0.6), hide, "Body")
	ball(m, Vector3.new(3, 2.6, 3.4), CFrame.new(0, 2.5, 1.9), hide, "Abdomen")
	ball(m, Vector3.new(1.4, 0.5, 2), CFrame.new(0, 3.75, 1.9), mark, "Marking")
	ball(m, Vector3.new(1.4, 1.2, 1.3), CFrame.new(0, 2, -1.8), hide, "Head")
	for i, o in { Vector3.new(-0.3, 0.25, 0), Vector3.new(0.3, 0.25, 0), Vector3.new(-0.5, 0, 0.1), Vector3.new(0.5, 0, 0.1), Vector3.new(0, 0.45, 0.05) } do
		local e = ball(m, Vector3.one * (if i <= 2 then 0.32 else 0.22), CFrame.new(Vector3.new(0, 2.2, -2.4) + o), eye, "Eye")
		e.Material = Enum.Material.Neon
	end
	for _, x in { -0.25, 0.25 } do
		part(m, Vector3.new(0.22, 0.7, 0.22), CFrame.new(x, 1.5, -2.35) * CFrame.Angles(0.3, 0, -x), Color3.fromRGB(220, 210, 190), "Fang")
	end
	-- Legs: four a side, reaching out and down to the floor.
	for _, side in { -1, 1 } do
		for k = 0, 3 do
			local z = -1.3 + k * 0.6
			local hip = Vector3.new(side * 0.8, 2.2, z)
			local foot = Vector3.new(side * 3.4, 0.1, z + (k - 1.5) * 1.1)
			rod(m, (foot - hip).Magnitude + 0.6, 0.3, hip + Vector3.new(0, 0.6, 0), foot, hide, "Leg")
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

local function crawlerQueen(): Model
	local m = caveCrawler()
	m:ScaleTo(3.4)
	local hide = Color3.fromRGB(60, 40, 66)
	-- A swollen egg sac glowing from inside, and a crown of bone spines.
	local sac = ball(m, Vector3.new(9, 7, 10), CFrame.new(0, 9.5, 11), Color3.fromRGB(170, 120, 150), "EggSac", Enum.Material.Glass)
	sac.Transparency = 0.25
	local glow = ball(m, Vector3.new(5, 4, 6), CFrame.new(0, 9.5, 11), Color3.fromRGB(255, 120, 170), "EggGlow", Enum.Material.Neon)
	glow.Transparency = 0.4
	for k = -2, 2 do
		local spine = Instance.new("WedgePart")
		spine.Name = "Crown"
		spine.Size = Vector3.new(0.6, 3 - math.abs(k) * 0.4, 1.4)
		spine.CFrame = CFrame.new(k * 0.9, 9.6, -5.6) * CFrame.Angles(0, math.pi, k * 0.25)
		spine.Color = Color3.fromRGB(230, 220, 200)
		spine.Anchored, spine.CanCollide = true, false
		spine.Parent = m
	end
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") and (p.Name == "Abdomen" or p.Name == "Body" or p.Name == "Head") then
			p.Color = hide
		end
	end
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = Color3.fromRGB(255, 120, 170), 30, 1.5
	light.Parent = glow
	return m
end

-- A hulking statue of dark stone grown through with crystal; its fists are crystal.
local function crystalWarden(): Model
	local m = Instance.new("Model")
	local stone, glow, dark = Color3.fromRGB(78, 74, 100), Color3.fromRGB(190, 140, 255), Color3.fromRGB(46, 42, 62)
	local body = ball(m, Vector3.new(10, 10, 7), CFrame.new(0, 12, 0), stone, "Body", Enum.Material.Slate)
	ball(m, Vector3.new(8, 5, 6), CFrame.new(0, 7.5, 0.3), dark, "Hips", Enum.Material.Slate)
	ball(m, Vector3.new(4.6, 4.2, 4.4), CFrame.new(0, 18, -1.2), stone, "Head", Enum.Material.Slate)
	local visor = part(m, Vector3.new(3.4, 0.7, 0.4), CFrame.new(0, 18.2, -3.3), glow, "Eye")
	visor.Material = Enum.Material.Neon
	for _, x in { -1, 1 } do
		ball(m, Vector3.new(4.5, 4.5, 4.5), CFrame.new(x * 6, 15, 0), stone, "Shoulder", Enum.Material.Slate)
		part(m, Vector3.new(3, 8, 3), CFrame.new(x * 6.6, 10, 0) * CFrame.Angles(0, 0, x * 0.12), stone, "Arm").Material = Enum.Material.Slate
		local fist = ball(m, Vector3.new(3.6, 3.6, 3.6), CFrame.new(x * 7.2, 5.2, -0.3), glow, "Fist", Enum.Material.Neon)
		fist.Transparency = 0.1
		part(m, Vector3.new(3.2, 7, 3.2), CFrame.new(x * 2.6, 3.5, 0), dark, "Leg").Material = Enum.Material.Slate
	end
	-- Crystal growths out of the back and shoulders.
	for i = 1, 9 do
		local a = (i - 5) * 0.32
		local h = 3 + (4 - math.abs(i - 5)) * 1.4
		local c = part(m, Vector3.new(1.3, h, 1.3), CFrame.new(math.sin(a) * 4, 15 + math.cos(a) * 2, 2.6) * CFrame.Angles(-0.5, 0, -a * 1.2) * CFrame.new(0, h / 2, 0), glow, "Shard")
		c.Material = Enum.Material.Glass
		c.Transparency = 0.15
	end
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = glow, 30, 2
	light.Parent = visor
	return m
end

-- Cooled black rock with molten cracks; a burning head and a glowing core.
local function magmaGolem(): Model
	local m = Instance.new("Model")
	local rock, lava = Color3.fromRGB(40, 32, 30), Color3.fromRGB(255, 110, 30)
	local body = ball(m, Vector3.new(12, 11, 8), CFrame.new(0, 14, 0), rock, "Body", Enum.Material.Basalt)
	local core = ball(m, Vector3.new(4.5, 4.5, 1.5), CFrame.new(0, 14, -3.6), lava, "Core", Enum.Material.Neon)
	ball(m, Vector3.new(9, 5, 7), CFrame.new(0, 8.5, 0.4), rock, "Hips", Enum.Material.Basalt)
	ball(m, Vector3.new(5, 4.4, 4.6), CFrame.new(0, 20.6, -1), rock, "Head", Enum.Material.Basalt)
	for _, x in { -1.1, 1.1 } do
		ball(m, Vector3.new(0.9, 0.6, 0.4), CFrame.new(x, 20.9, -3.2), lava, "Eye", Enum.Material.Neon)
	end
	for _, x in { -1, 1 } do
		ball(m, Vector3.new(5.5, 5, 5), CFrame.new(x * 7.6, 17, 0), rock, "Shoulder", Enum.Material.Basalt)
		part(m, Vector3.new(3.8, 9, 3.8), CFrame.new(x * 8, 11, 0), rock, "Arm").Material = Enum.Material.Basalt
		ball(m, Vector3.new(4.6, 4.6, 4.6), CFrame.new(x * 8.2, 5.4, -0.3), rock, "Fist", Enum.Material.Basalt)
		part(m, Vector3.new(4.2, 8, 4.2), CFrame.new(x * 3.2, 4, 0), rock, "Leg").Material = Enum.Material.Basalt
	end
	-- Molten seams across the body.
	for i = 1, 7 do
		local seam = part(m, Vector3.new(0.35, rng:NextNumber(3, 6), 0.3), CFrame.new(rng:NextNumber(-4, 4), rng:NextNumber(10, 17), -3.9) * CFrame.Angles(0, 0, rng:NextNumber(-0.8, 0.8)), lava, "Seam")
		seam.Material = Enum.Material.Neon
		if i % 2 == 0 then
			seam.CFrame = CFrame.new(seam.Position.X, seam.Position.Y, 3.9) * CFrame.Angles(0, 0, rng:NextNumber(-0.8, 0.8))
		end
	end
	local fire = Instance.new("Fire")
	fire.Size, fire.Heat, fire.Color, fire.SecondaryColor = 7, 5, lava, Color3.fromRGB(255, 200, 80)
	fire.Parent = m:FindFirstChild("Head")
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = lava, 32, 2.5
	light.Parent = core
	return m
end

-- The Blender models (assets/models/blender/set4.py) replace the block ones when the
-- place has them imported; the block builders above stay as the fallback.
local MESH_NAMES = {
	Wolf = "wolf",
	Goat = "goat",
	Crab = "crab",
	Turtle = "turtle",
	CaveCrawler = "cave_crawler",
	CinderBeetle = "cinder_beetle",
	BogSlime = "bog_slime",
	CrawlerQueen = "crawler_queen",
	CrystalWarden = "crystal_warden",
	MagmaGolem = "magma_golem",
}
local function withMesh(kind: string, fallback: () -> Model): () -> Model
	return function()
		local model = Meshes.has(MESH_NAMES[kind]) and Meshes.build(MESH_NAMES[kind], { collide = false })
		if not model then
			return fallback()
		end
		for _, p in model:GetChildren() do
			if p:IsA("BasePart") then
				p.CanQuery = true
			end
		end
		-- Glowing parts light up their surroundings a little, like the block bosses did.
		local glow = model:FindFirstChild("Eye") or model:FindFirstChild("Core")
		if glow and (kind == "CrawlerQueen" or kind == "CrystalWarden" or kind == "MagmaGolem") then
			local light = Instance.new("PointLight")
			light.Range, light.Brightness = 30, 2
			light.Color = (glow :: BasePart).Color
			light.Parent = glow
		end
		if kind == "MagmaGolem" then
			local head = model:FindFirstChild("Head")
			if head then
				local fire = Instance.new("Fire")
				fire.Size, fire.Heat = 7, 5
				fire.Color, fire.SecondaryColor = Color3.fromRGB(255, 110, 30), Color3.fromRGB(255, 200, 80)
				fire.Parent = head
			end
		end
		return model
	end
end
local builders = { CrawlerQueen = crawlerQueen, CrystalWarden = crystalWarden, MagmaGolem = magmaGolem, Goat = goat, Turtle = turtle, Boar = boar, Crab = crab, Wolf = wolf, BogSlime = bogSlime, CinderBeetle = cinderBeetle, CaveCrawler = caveCrawler }
for kind, fallback in builders do
	if MESH_NAMES[kind] then
		builders[kind] = withMesh(kind, fallback)
	end
end

-- Cave animals can't look for the ground from the sky (that finds the island above
-- them), so they feel for the floor just under where they are.
local function floorNear(x: number, y: number, z: number): (Vector3?, Enum.Material?)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	params.IgnoreWater = false
	local hit = workspace:Raycast(Vector3.new(x, y + 5, z), Vector3.new(0, -14, 0), params)
	if hit then
		return hit.Position, hit.Material, hit.Normal
	end
	return nil, nil, nil
end

-- What a creature can stand on and bump into: terrain plus built structures,
-- resource nodes and world props, but never other creatures or players.
local solidParams = RaycastParams.new()
solidParams.FilterType = Enum.RaycastFilterType.Exclude
solidParams.IgnoreWater = false
local function refreshSolidFilter()
	local skip: { Instance } = { folder() }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(skip, p.Character)
		end
	end
	local drops = workspace:FindFirstChild("Drops")
	if drops then
		table.insert(skip, drops)
	end
	table.insert(skip, workspace.CurrentCamera)
	solidParams.FilterDescendantsInstances = skip
end

-- The floor right under (x, z) near height y: a short ray from a little above the
-- creature down, so it follows slopes and floors and can't snap onto a cliff top
-- or a roof far above it, or through the ground to a cave far below.
local function groundFor(s: State, x: number, z: number, y: number): (Vector3?, Enum.Material?, Vector3?)
	local hit = workspace:Raycast(Vector3.new(x, y + 2.8, z), Vector3.new(0, -10, 0), solidParams)
	if hit and hit.Instance and hit.Instance ~= workspace.Terrain and not hit.Instance.CanCollide then
		hit = nil
	end
	if hit then
		return hit.Position, hit.Material, hit.Normal
	end
	if s.def.cave then
		return floorNear(x, y, z)
	end
	return nil, nil, nil
end

-- A wall in the way: a ray from knee and chest height along the step, as long as
-- the step plus the creature's half-width. Any collidable hit counts.
local function blockedAhead(s: State, pos: Vector3, dir: Vector3, dist: number): boolean
	local reach = dist + (s.radius or 1.5)
	for _, h in { 1.2, 2.6 } do
		local hit = workspace:Raycast(pos + Vector3.new(0, h, 0), dir * reach, solidParams)
		if hit and (hit.Instance == workspace.Terrain or (hit.Instance :: BasePart).CanCollide) then
			-- A gentle slope reads as a "wall" to the low ray; let the ground check judge it.
			if not (h < 2 and hit.Normal.Y > 0.6) then
				return true
			end
		end
	end
	return false
end

local function pickWanderTarget(s: State): Vector3?
	for _ = 1, 8 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(8, if s.def.cave then 20 else 40)
		local x, z = s.home.X + math.cos(a) * r, s.home.Z + math.sin(a) * r
		local pos, mat
		if s.def.cave then
			pos, mat = floorNear(x, s.home.Y, z)
		else
			pos, mat = groundAt(x, z)
		end
		if pos and mat ~= Enum.Material.Water and mat ~= Enum.Material.Rock then
			return pos
		end
	end
	return nil
end

local function spawnAnimal(kind: string, home: Vector3): Model
	local def = AnimalDefs[kind]
	local model = (builders[def.model or kind] or builders[kind])()
	if def.scale then
		model:ScaleTo(model:GetScale() * def.scale)
	end
	if def.tint then
		for _, p in model:GetDescendants() do
			if p:IsA("BasePart") and p.Material ~= Enum.Material.Neon then
				p.Color = p.Color:Lerp(def.tint, 0.55)
			end
		end
	end
	model.Name = kind
	model:SetAttribute("AnimalType", kind)
	model:SetAttribute("HP", def.hp)
	model:SetAttribute("MaxHP", def.hp)
	model:PivotTo(CFrame.new(home))
	if def.boss then
		-- Lit from within, so it reads in a dark lair (lava orange for the golem).
		local core = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
		if core then
			local glow = Instance.new("PointLight")
			glow.Color = if kind == "MagmaGolem" then Color3.fromRGB(255, 130, 50) else Color3.fromRGB(200, 220, 255)
			glow.Range, glow.Brightness, glow.Shadows = 34, 1.6, false
			glow.Parent = core
		end
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
			-- Mesh parts can carry a colour after the role ("EyeEyeDark"): the first word counts.
			local n = if string.find(p.Name, "_") then p.Name else (string.match(p.Name, "^%u%l*") or p.Name)
			local kind = if n == "Leg" then "leg" elseif n == "Arm" or n == "Fist" or n == "Claw" or n == "Mandible" or n == "Fang" then "arm" elseif n == "Head" or n == "Snout" or n == "Eye" or n == "Ear" or n == "Horn" or n == "Beard" then "head" elseif n == "Tail" then "tail" else nil
			if kind then
				local rest = pivot:ToObjectSpace(p.CFrame)
				table.insert(limbs, { part = p, rest = rest, kind = kind, side = if rest.Position.X >= 0 then 1 else -1, front = rest.Position.Z < 0 })
			end
		end
	end
	-- Arms made of several parts share a shoulder: the top of the highest arm part on that side.
	local shoulders = {}
	for _, l in limbs do
		if l.kind == "arm" and not string.find(l.part.Name, "^Mandible") then
			local top = l.rest.Position + Vector3.new(0, l.part.Size.Y / 2, 0)
			local cur = shoulders[l.side]
			if not cur or top.Y > cur.Y then
				shoulders[l.side] = top
			end
		end
	end
	for _, l in limbs do
		if l.kind == "arm" and not string.find(l.part.Name, "^Mandible") then
			l.hinge = shoulders[l.side]
		end
	end
	-- How far the pivot sits above the lowest point of the model, so it's always
	-- stood on the ground rather than sunk into it, and how wide it is for walls.
	local bbCf, bbSize = model:GetBoundingBox()
	local foot = math.max(0, model:GetPivot().Position.Y - (bbCf.Position.Y - bbSize.Y / 2))
	local radius = math.clamp(math.max(bbSize.X, bbSize.Z) * 0.35, 1, 6)
	model:PivotTo(CFrame.new(home + Vector3.new(0, foot, 0)))
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
		foot = foot,
		radius = radius,
	}
	return model
end

-- Pose the limbs: legs swing in a trot while moving, the head dips and rises, arms and
-- jaws pull back during a wind-up and snap forward on the strike.
local function pose(s, moving: boolean, windup: number)
	local pivot = s.model:GetPivot()
	local t = s.phase
	local atk = s.attack
	local atkK = 0
	if atk then
		atkK = (os.clock() - atk.t0) / atk.dur
		if atkK > 1 then
			s.attack, atk = nil, nil
		elseif atkK < 0 then
			atk = nil -- not started yet
		end
	end
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
			-- A boss's big moves (set by Bosses): both arms up and slam down, or one
			-- arm drawn back and thrown forward.
			if atk then
				if atk.kind == "slam" then
					a = if atkK < 0.75 then -2.5 * math.min(1, atkK / 0.35) else -2.5 + 3.0 * math.min(1, (atkK - 0.75) / 0.08)
				elseif atk.kind == "throw" and l.side > 0 then
					a = if atkK < 0.6 then 1.0 * math.min(1, atkK / 0.4) else 1.0 - 3.2 * math.min(1, (atkK - 0.6) / 0.12)
				elseif atk.kind == "lunge" then
					a = -1.4 * math.sin(math.min(1, atkK) * math.pi)
				end
			end
			if l.hinge then
				-- Every arm part on this side (arm, fist, pincer) turns about one shoulder.
				cf = CFrame.new(l.hinge) * CFrame.Angles(a, 0, 0) * CFrame.new(-l.hinge) * cf
			else
				cf = cf * CFrame.new(0, size.Y / 2, 0) * CFrame.Angles(a, 0, 0) * CFrame.new(0, -size.Y / 2, 0)
			end
		elseif l.kind == "head" then
			local lift = if atk and atk.kind == "slam" then (if atkK < 0.75 then 0.6 else -0.4) else 0
			cf = CFrame.new(0, (if moving then math.sin(t * 3.2) * 0.12 else math.sin(os.clock() * 1.5) * 0.06) + windup * 0.4 + lift, windup * 0.5) * cf
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

-- Is one of this kind alive anywhere (bosses spawn one at a time)?
function Animals.alive(kind: string): boolean
	for model, s in states do
		if model.Parent and model:GetAttribute("AnimalType") == kind then
			return true
		end
	end
	return false
end

-- Called when a player hits an animal.
function Animals.damage(model: Model, amount: number, attacker: Player)
	local s = states[model]
	if not s then
		return
	end
	local hp = (model:GetAttribute("HP") or 0) - amount
	model:SetAttribute("HP", hp)
	s.damageBy = s.damageBy or {}
	s.damageBy[attacker] = (s.damageBy[attacker] or 0) + amount
	if hp <= 0 then
		states[model] = nil
		local pos = model:GetPivot().Position + Vector3.new(0, 2, 0)
		local top = Drops.topDamager(s.damageBy) or attacker
		for _, line in s.def.loot or {} do
			if not line[4] or rng:NextNumber() < line[4] then
				for _ = 1, rng:NextInteger(line[2], line[3]) do
					Drops.reserve(Drops.spawn(line[1], 1, pos), top)
				end
			end
		end
		Progression.addXp(attacker, s.def.xp)
		Quests.record(attacker, "hunt", model:GetAttribute("AnimalType"), 1)
		local minion = model:GetAttribute("Minion")
		if s.def.boss then
			Remotes.WorldEvent:FireAllClients(attacker.DisplayName .. " defeated the " .. s.def.name .. "!")
		end
		model:Destroy()
		local kind, home = model.Name, s.home
		if not minion and not s.def.boss then -- bosses come back when their gate is opened again
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
	-- A boss that got out of its lair anyhow (knocked, glitched) goes straight back.
	if s.def.boss and ((pos - s.home) * Vector3.new(1, 0, 1)).Magnitude > 70 or (s.def.boss and math.abs(pos.Y - s.home.Y) > 30) then
		model:PivotTo(CFrame.new(s.home + Vector3.new(0, s.foot or 0, 0)))
		s.target = nil
		return
	end
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
					local defense = Inventory.defense(s.attacker :: Player, "mob")
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
			local dist = math.min(flat.Magnitude, speed * dt)
			local feet = pos - Vector3.new(0, s.foot or 0, 0)
			-- Try straight at the goal, then steer round whatever is in the way.
			local moved = false
			for _, turn in { 0, 40, -40, 80, -80, 120, -120 } do
				local dir = (CFrame.Angles(0, math.rad(turn), 0) * flat.Unit)
				if not blockedAhead(s, feet, dir, dist) then
					local nextPos = feet + dir * dist
					local ground, mat, normal = groundFor(s, nextPos.X, nextPos.Z, feet.Y)
					-- No climbing sheer steps, walls or cave sides (only a gentle slope when
					-- going up), no walking off ledges, and no swimming. Bosses stay in their lair.
					local rise = if ground then ground.Y - feet.Y else 0
					local steep = rise > 0.4 and normal ~= nil and normal.Y < 0.62
					local strays = s.def.boss and Vector3.new(nextPos.X - s.home.X, 0, nextPos.Z - s.home.Z).Magnitude > (s.def.roam or 42)
					if ground and mat ~= Enum.Material.Water and rise < 2.6 and -rise < 6 and not steep and not strays then
						s.phase += dt * speed
						local bob = math.abs(math.sin(s.phase * 1.2)) * (if s.def.boss then 0.6 else 0.15)
						local at = ground + Vector3.new(0, (s.foot or 0) + bob, 0)
						model:PivotTo(CFrame.lookAt(at, at + dir))
						moved = true
						break
					end
				end
			end
			if not moved then
				s.stuck = (s.stuck or 0) + dt
				if s.stuck > 1.5 then
					s.target = nil
					s.stuck = 0
					if s.mode == "wander" then
						s.mode = "idle"
						s.modeUntil = now + 1
					end
				end
			else
				s.stuck = 0
			end
		end
	end
	local windup = if s.windupUntil then 1 - math.clamp((s.windupUntil - now) / 0.6, 0, 1) else 0
	pose(s, goal ~= nil, windup)
end

function Animals.start()
	local accum = 0
	local nextFilter = 0
	RunService.Heartbeat:Connect(function(dt)
		if os.clock() > nextFilter then
			nextFilter = os.clock() + 2
			refreshSolidFilter()
		end
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
