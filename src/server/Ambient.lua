-- Little scenes dotted round the islands so the land between camps isn't empty:
-- a trader's cart left by the road, a woodcutter's corner, a hanging birdcage, a ring
-- of violet spirit torches round a standing stone, a fish-drying rack on the shore,
-- an old campsite, a signpost, a rain barrel corner. All plain parts, anchored.
local Props = require(script.Parent.Props)

local Ambient = {}

local rgb = Color3.fromRGB
local part = Props.part
local WOOD, DARK, LIGHT = Props.WOOD, Props.WOOD_DARK, Props.WOOD_LIGHT
local IRON = rgb(64, 60, 58)

local function wheel(m: Instance, cf: CFrame, r: number)
	part(m, { Name = "Wheel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, r * 2, r * 2), CFrame = cf, Color = DARK, Material = Enum.Material.Wood })
	part(m, { Name = "Hub", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.7, r * 0.5, r * 0.5), CFrame = cf, Color = IRON, Material = Enum.Material.Metal, CanCollide = false })
	for k = 0, 2 do
		part(m, { Name = "Spoke", Size = Vector3.new(0.3, r * 1.9, 0.25), CFrame = cf * CFrame.Angles(k * math.pi / 3, 0, 0), Color = WOOD, Material = Enum.Material.Wood, CanCollide = false })
	end
end

local function lantern(m: Instance, at: CFrame, color: Color3?)
	local glass = part(m, { Name = "Lantern", Size = Vector3.new(0.9, 1.1, 0.9), CFrame = at, Color = color or rgb(255, 210, 130), Material = Enum.Material.Neon, Transparency = 0.2, CanCollide = false })
	part(m, { Name = "LanternCap", Size = Vector3.new(1.2, 0.25, 1.2), CFrame = at * CFrame.new(0, 0.65, 0), Color = IRON, Material = Enum.Material.Metal, CanCollide = false })
	local light = Instance.new("PointLight")
	light.Color = color or rgb(255, 200, 130)
	light.Range = 16
	light.Brightness = 1
	light.Shadows = false
	light.Parent = glass
end

local SCENES = {}

-- A two-wheeled trader's cart, tipped onto its shafts, loaded with crates and sacks.
function SCENES.cart(m: Instance, cf: CFrame)
	local bed = part(m, { Name = "CartBed", Size = Vector3.new(5, 0.5, 8), CFrame = cf * CFrame.new(0, 2.6, 0) * CFrame.Angles(math.rad(-6), 0, 0), Color = LIGHT, Material = Enum.Material.WoodPlanks })
	for _, x in { -2.6, 2.6 } do
		part(m, { Name = "CartSide", Size = Vector3.new(0.3, 1.2, 8), CFrame = bed.CFrame * CFrame.new(x, 0.8, 0), Color = WOOD, Material = Enum.Material.WoodPlanks })
		wheel(m, cf * CFrame.new(x * 1.05, 2, 0.6), 2)
		part(m, { Name = "Shaft", Size = Vector3.new(0.4, 0.4, 6), CFrame = cf * CFrame.new(x * 0.6, 1.2, -6) * CFrame.Angles(math.rad(-14), 0, 0), Color = DARK, Material = Enum.Material.Wood })
	end
	Props.crate(m, bed.CFrame * CFrame.new(-1, 0.25, 1.5) * CFrame.Angles(0, 0.2, 0), 2.4)
	Props.crate(m, bed.CFrame * CFrame.new(1.1, 0.25, -1.2) * CFrame.Angles(0, -0.3, 0), 2)
	for k = 0, 1 do
		part(m, { Name = "Sack", Shape = Enum.PartType.Ball, Size = Vector3.new(2.2, 1.8, 2.2), CFrame = bed.CFrame * CFrame.new(1 - k * 0.6, 1, 2.4 + k * 0.4), Color = rgb(206, 178, 124), Material = Enum.Material.Fabric, CanCollide = false })
	end
	part(m, { Name = "LampPole", Size = Vector3.new(0.3, 4, 0.3), CFrame = bed.CFrame * CFrame.new(2.4, 2.2, 3.6), Color = DARK, Material = Enum.Material.Wood, CanCollide = false })
	lantern(m, bed.CFrame * CFrame.new(2.4, 3.6, 4.2))
	Props.crate(m, cf * CFrame.new(-4.5, 0, 2.5) * CFrame.Angles(0, 0.5, 0), 2.8)
end

-- A woodcutter's corner: a log stack, a chopping stump with an axe in it, split logs.
function SCENES.woodcutter(m: Instance, cf: CFrame)
	Props.logPile(m, cf * CFrame.new(0, 0, 3))
	local stump = part(m, { Name = "Stump", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 2.6, 2.6), CFrame = cf * CFrame.new(-4, 1, -2) * CFrame.Angles(0, 0, math.pi / 2), Color = WOOD, Material = Enum.Material.Wood })
	part(m, { Name = "StumpTop", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 2.4, 2.4), CFrame = stump.CFrame * CFrame.new(1.01, 0, 0), Color = rgb(206, 170, 118), Material = Enum.Material.Wood, CanCollide = false })
	part(m, { Name = "AxeHandle", Size = Vector3.new(0.3, 3, 0.3), CFrame = cf * CFrame.new(-4, 3.1, -2) * CFrame.Angles(0, 0, math.rad(25)), Color = LIGHT, Material = Enum.Material.Wood, CanCollide = false })
	part(m, { Name = "AxeHead", Size = Vector3.new(1.2, 0.8, 0.2), CFrame = cf * CFrame.new(-3.6, 2.2, -2) * CFrame.Angles(0, 0, math.rad(25)), Color = rgb(150, 150, 156), Material = Enum.Material.Metal, CanCollide = false })
	for k = 0, 2 do
		part(m, { Name = "Split", Size = Vector3.new(0.8, 2, 0.9), CFrame = cf * CFrame.new(-6 + k * 0.9, 0.6, -4 + k * 0.4) * CFrame.Angles(math.rad(80), k, 0), Color = rgb(196, 160, 110), Material = Enum.Material.Wood })
	end
end

-- A tall post with a hanging round birdcage and a little bird in it.
function SCENES.birdcage(m: Instance, cf: CFrame)
	part(m, { Name = "Post", Size = Vector3.new(0.7, 10, 0.7), CFrame = cf * CFrame.new(0, 5, 0), Color = DARK, Material = Enum.Material.Wood })
	part(m, { Name = "Arm", Size = Vector3.new(0.5, 0.5, 4), CFrame = cf * CFrame.new(0, 9.6, -1.8), Color = DARK, Material = Enum.Material.Wood })
	local centre = cf * CFrame.new(0, 6.6, -3.4)
	part(m, { Name = "Chain", Size = Vector3.new(0.15, 1.6, 0.15), CFrame = cf * CFrame.new(0, 8.6, -3.4), Color = IRON, Material = Enum.Material.Metal, CanCollide = false })
	for k = 0, 5 do
		part(m, { Name = "Bar", Size = Vector3.new(0.12, 2.4, 0.12), CFrame = centre * CFrame.Angles(0, k * math.pi / 6 * 2, 0) * CFrame.new(1, 0, 0), Color = rgb(196, 160, 72), Material = Enum.Material.Metal, CanCollide = false })
	end
	part(m, { Name = "CageTop", Shape = Enum.PartType.Ball, Size = Vector3.new(2.3, 1.2, 2.3), CFrame = centre * CFrame.new(0, 1.2, 0), Color = rgb(196, 160, 72), Material = Enum.Material.Metal, CanCollide = false })
	part(m, { Name = "CageBase", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 2.2, 2.2), CFrame = centre * CFrame.new(0, -1.2, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = rgb(150, 120, 60), Material = Enum.Material.Metal, CanCollide = false })
	part(m, { Name = "Bird", Shape = Enum.PartType.Ball, Size = Vector3.new(0.7, 0.6, 0.8), CFrame = centre * CFrame.new(0, -0.7, 0), Color = rgb(250, 206, 70), Material = Enum.Material.SmoothPlastic, CanCollide = false })
	part(m, { Name = "Beak", Size = Vector3.new(0.15, 0.15, 0.3), CFrame = centre * CFrame.new(0, -0.65, -0.45), Color = rgb(240, 130, 40), Material = Enum.Material.SmoothPlastic, CanCollide = false })
end

-- Violet spirit torches round a mossy standing stone.
function SCENES.spiritStones(m: Instance, cf: CFrame)
	part(m, { Name = "StandingStone", Size = Vector3.new(2.6, 7, 1.6), CFrame = cf * CFrame.new(0, 3.2, 0) * CFrame.Angles(0.05, 0.3, 0.06), Color = rgb(120, 118, 112), Material = Enum.Material.Slate })
	part(m, { Name = "Moss", Size = Vector3.new(2.7, 1.2, 1.7), CFrame = cf * CFrame.new(0, 6.3, 0) * CFrame.Angles(0.05, 0.3, 0.06), Color = rgb(96, 130, 64), Material = Enum.Material.Grass, CanCollide = false })
	for k = 0, 2 do
		local a = k / 3 * math.pi * 2 + 0.5
		local at = (cf * CFrame.new(math.cos(a) * 5, 0, math.sin(a) * 5)).Position
		part(m, { Name = "SpiritPost", Size = Vector3.new(0.6, 4.5, 0.6), CFrame = CFrame.new(at + Vector3.new(0, 2.25, 0)), Color = rgb(60, 48, 70), Material = Enum.Material.Wood })
		local bowl = part(m, { Name = "SpiritBowl", Size = Vector3.new(1.2, 0.5, 1.2), CFrame = CFrame.new(at + Vector3.new(0, 4.7, 0)), Color = IRON, Material = Enum.Material.Metal })
		local fire = Instance.new("Fire")
		fire.Size, fire.Heat = 3, 7
		fire.Color, fire.SecondaryColor = rgb(170, 80, 255), rgb(230, 170, 255)
		fire.Parent = bowl
		local light = Instance.new("PointLight")
		light.Color, light.Range, light.Brightness, light.Shadows = rgb(180, 110, 255), 16, 1.2, false
		light.Parent = bowl
	end
end

-- A fish-drying rack: two A-frames, a pole, fish hanging off it, a basket.
function SCENES.fishRack(m: Instance, cf: CFrame)
	for _, x in { -3, 3 } do
		for _, s in { -1, 1 } do
			part(m, { Name = "Leg", Size = Vector3.new(0.4, 5, 0.4), CFrame = cf * CFrame.new(x, 2.4, s * 0.8) * CFrame.Angles(s * 0.3, 0, 0), Color = DARK, Material = Enum.Material.Wood })
		end
	end
	part(m, { Name = "Pole", Size = Vector3.new(7, 0.35, 0.35), CFrame = cf * CFrame.new(0, 4.7, 0), Color = WOOD, Material = Enum.Material.Wood })
	for k = 0, 4 do
		local x = -2.4 + k * 1.2
		part(m, { Name = "Line", Size = Vector3.new(0.06, 0.8, 0.06), CFrame = cf * CFrame.new(x, 4.2, 0), Color = Props.ROPE, Material = Enum.Material.Fabric, CanCollide = false })
		part(m, { Name = "Fish", Shape = Enum.PartType.Ball, Size = Vector3.new(0.5, 1.6, 0.8), CFrame = cf * CFrame.new(x, 3.2, 0), Color = if k % 2 == 0 then rgb(150, 170, 186) else rgb(196, 140, 96), Material = Enum.Material.SmoothPlastic, CanCollide = false })
	end
	part(m, { Name = "Basket", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.4, 2.2, 2.2), CFrame = cf * CFrame.new(4.4, 0.7, 1.4) * CFrame.Angles(0, 0, math.pi / 2), Color = rgb(186, 146, 84), Material = Enum.Material.Fabric })
end

-- An old campsite: a ring of stones round a fire, log seats and a bedroll.
function SCENES.campsite(m: Instance, cf: CFrame)
	Props.campfire(m, cf.Position)
	for k = 0, 1 do
		local a = k * math.pi + 0.4
		part(m, { Name = "Seat", Shape = Enum.PartType.Cylinder, Size = Vector3.new(5, 1.4, 1.4), CFrame = cf * CFrame.new(math.cos(a) * 5, 0.7, math.sin(a) * 5) * CFrame.Angles(0, -a + math.pi / 2, 0), Color = WOOD, Material = Enum.Material.Wood })
	end
	part(m, { Name = "Bedroll", Size = Vector3.new(2.4, 0.5, 5), CFrame = cf * CFrame.new(-1, 0.25, 6) * CFrame.Angles(0, 1.4, 0), Color = Props.CLOTH[1], Material = Enum.Material.Fabric })
	part(m, { Name = "Pillow", Size = Vector3.new(2.2, 0.8, 1.2), CFrame = cf * CFrame.new(-1, 0.5, 6) * CFrame.Angles(0, 1.4, 0) * CFrame.new(0, 0, 2), Color = rgb(214, 190, 136), Material = Enum.Material.Fabric })
	part(m, { Name = "Pot", Shape = Enum.PartType.Ball, Size = Vector3.new(1.6, 1.4, 1.6), CFrame = cf * CFrame.new(2.6, 0.6, -2), Color = IRON, Material = Enum.Material.Metal })
end

-- A signpost with three boards pointing off in different directions.
function SCENES.signpost(m: Instance, cf: CFrame)
	part(m, { Name = "Post", Size = Vector3.new(0.7, 8, 0.7), CFrame = cf * CFrame.new(0, 4, 0), Color = DARK, Material = Enum.Material.Wood })
	for k = 0, 2 do
		part(m, { Name = "Board", Size = Vector3.new(4, 0.9, 0.25), CFrame = cf * CFrame.new(0, 7 - k * 1.3, 0) * CFrame.Angles(0, k * 1.9 + 0.3, 0) * CFrame.new(1.8, 0, 0), Color = LIGHT, Material = Enum.Material.WoodPlanks })
	end
	part(m, { Name = "Stone", Shape = Enum.PartType.Ball, Size = Vector3.new(2.4, 1.6, 2.2), CFrame = cf * CFrame.new(0.9, 0.4, 0.6), Color = rgb(128, 124, 118), Material = Enum.Material.Slate })
end

-- A rain barrel corner: barrels, a water trough and a bucket.
function SCENES.barrels(m: Instance, cf: CFrame)
	Props.barrel(m, cf * CFrame.new(-2, 0, 0))
	Props.barrel(m, cf * CFrame.new(0.8, 0, -0.6))
	Props.barrel(m, cf * CFrame.new(-0.6, 3.4, -0.3))
	local trough = part(m, { Name = "Trough", Size = Vector3.new(5, 1.4, 2), CFrame = cf * CFrame.new(1, 0.7, 3), Color = WOOD, Material = Enum.Material.WoodPlanks })
	part(m, { Name = "Water", Size = Vector3.new(4.6, 0.2, 1.6), CFrame = trough.CFrame * CFrame.new(0, 0.55, 0), Color = rgb(90, 150, 170), Material = Enum.Material.Glass, Transparency = 0.3, CanCollide = false })
	part(m, { Name = "Bucket", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 1.1, 1.1), CFrame = cf * CFrame.new(4.2, 0.6, 1) * CFrame.Angles(0, 0, math.pi / 2), Color = rgb(150, 110, 70), Material = Enum.Material.Wood })
end

Ambient.KINDS = { "cart", "woodcutter", "birdcage", "spiritStones", "fishRack", "campsite", "signpost", "barrels" }
Ambient.SHORE = { fishRack = true }

-- Builds one scene standing on `at` (ground point), turned to `facing`.
function Ambient.place(parent: Instance, kind: string, at: Vector3, yaw: number): Model
	local m = Instance.new("Model")
	m.Name = "Ambient_" .. kind
	local cf = CFrame.new(at) * CFrame.Angles(0, yaw, 0)
	SCENES[kind](m, cf)
	m.WorldPivot = cf -- so clients that haven't streamed the parts in still know where it is
	m.Parent = parent
	return m
end

return Ambient
