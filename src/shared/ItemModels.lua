-- Builds a small 3D model for every item. The same model is used for
-- items dropped on the ground, the tool in your hand, and the icons in the UI.
--
-- Tools are built standing up: the grip is at the origin and the tool points along +Y.
-- Everything else is built centred on the origin.

local ItemModels = {}

local Meshes = require(script.Parent.Meshes)
local Tiers = require(script.Parent.Tiers)
local ArmourModels = require(script.Parent.ArmourModels)
local Items = require(script.Parent.Items)

-- Items that have a Blender mesh. Tools keep their grip at the origin (the bottom
-- of the mesh); everything else is centred.
-- `scale` evens out the sizes of the smallest items.
local ITEM_MESHES: { [string]: { mesh: string, tool: boolean?, scale: number? } } = {
	wood_club = { mesh = "club", tool = true },
	rock = { mesh = "rock" },
	log = { mesh = "log" },
	stick = { mesh = "stick", scale = 1.2 },
	leaves = { mesh = "leaves", scale = 1.5 },
	stone = { mesh = "stone", scale = 1.3 },
	raw_meat = { mesh = "raw_meat" },
	cooked_meat = { mesh = "cooked_meat" },
	leather = { mesh = "leather" },
	leather_bag = { mesh = "bag_satchel" },
	hide_pack = { mesh = "bag_hide" },
	explorer_pack = { mesh = "bag_explorer" },
}

-- Tiered swords and harvesters use their tier's style mesh, recoloured (see Tiers.lua).
-- These meshes have a Bounds box centred on the grip.
local function tierTool(itemId: string): Model?
	local tier, kind = Tiers.split(itemId)
	if not tier or (kind ~= "sword" and kind ~= "harvester") then
		return nil
	end
	local mesh = Meshes.build(kind .. "_" .. tier.style, { centre = true, collide = false })
	if mesh then
		Tiers.paint(mesh, tier)
	end
	return mesh
end

local C = {
	wood = Color3.fromRGB(141, 101, 64),
	woodDark = Color3.fromRGB(104, 72, 45),
	woodLight = Color3.fromRGB(178, 136, 92),
	stone = Color3.fromRGB(128, 128, 133),
	stoneDark = Color3.fromRGB(98, 98, 104),
	leaf = Color3.fromRGB(78, 140, 62),
	leather = Color3.fromRGB(122, 74, 42),
	slime = Color3.fromRGB(122, 214, 84),
	meatRaw = Color3.fromRGB(205, 92, 92),
	meatCooked = Color3.fromRGB(160, 84, 46),
	berry = Color3.fromRGB(190, 38, 64),
	coconut = Color3.fromRGB(110, 76, 46),
}

local function part(model: Model, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Anchored = true
	p.Massless = true
	p.Parent = model
	return p
end

-- A chunky low-poly lump made from a few overlapping rotated blocks.
local function lump(model: Model, size: number, cf: CFrame, color: Color3, material: Enum.Material?, seed: number?): Part
	local rng = Random.new(seed or 7)
	local core = part(model, Vector3.new(size, size * 0.8, size * 0.9), cf * CFrame.Angles(0.3, 0.5, 0.2), color, material)
	for _ = 1, 2 do
		part(
			model,
			Vector3.new(size * rng:NextNumber(0.6, 0.85), size * rng:NextNumber(0.55, 0.75), size * rng:NextNumber(0.6, 0.85)),
			cf * CFrame.new(rng:NextNumber(-0.15, 0.15) * size, rng:NextNumber(-0.1, 0.1) * size, rng:NextNumber(-0.15, 0.15) * size)
				* CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), rng:NextNumber(0, 3)),
			color:Lerp(Color3.new(0, 0, 0), rng:NextNumber(0, 0.12)),
			material
		)
	end
	return core
end

local builders: { [string]: (Model) -> BasePart } = {}

-- Tools ------------------------------------------------------------------------

function builders.rock(m)
	return lump(m, 0.9, CFrame.new(0, 0.3, 0), C.stone, Enum.Material.Slate, 3)
end

-- A real club: thin at the grip, swelling to a heavy rounded end.
-- Built from a stack of cylinders that get wider, capped with a ball.
local CLUB_WOOD = Color3.fromRGB(122, 64, 40)

local function club(m: Model, stoneHead: boolean): BasePart
	local up = CFrame.Angles(0, 0, math.rad(90)) -- cylinders run along X; turn them to run along Y
	local grip
	local segments = 7
	local length = 3.2
	for i = 0, segments - 1 do
		local t = i / (segments - 1)
		local d = 0.24 + 0.36 * t ^ 1.6
		local y = -0.2 + length * (i + 0.5) / segments
		local lean = CFrame.Angles(math.rad(3 * t), 0, 0) -- a slight bend so it isn't a perfect rod
		local p = part(m, Vector3.new(length / segments + 0.06, d, d), CFrame.new(0, y, 0) * lean * up, CLUB_WOOD:Lerp(Color3.new(0, 0, 0), (i % 2) * 0.06), Enum.Material.Wood, Enum.PartType.Cylinder)
		if i == 0 then
			grip = p
		end
	end
	part(m, Vector3.new(0.62, 0.62, 0.62), CFrame.new(0, length - 0.25, 0.05), CLUB_WOOD, Enum.Material.Wood, Enum.PartType.Ball)
	-- Grip wrap
	part(m, Vector3.new(0.75, 0.29, 0.29), CFrame.new(0, 0.25, 0) * up, Color3.fromRGB(86, 58, 38), Enum.Material.Fabric, Enum.PartType.Cylinder)
	if stoneHead then
		for i = 0, 2 do
			local a = i * math.pi * 2 / 3
			lump(m, 0.38, CFrame.new(math.cos(a) * 0.28, length - 0.55, math.sin(a) * 0.28), C.stone, Enum.Material.Slate, 11 + i)
		end
	end
	return grip
end

function builders.wood_club(m)
	return club(m, false)
end

-- Swords share one shape; only the colour changes by tier.
-- Faceted tapered blade, short crossguard, leather grip, tier-coloured pommel.
local SWORD_TIERS: { [string]: Color3 } = {
	wood = Color3.fromRGB(156, 118, 84),
	stone = Color3.fromRGB(122, 122, 130),
	silver = Color3.fromRGB(226, 228, 236),
	gold = Color3.fromRGB(240, 204, 64),
	sunsteel = Color3.fromRGB(176, 28, 38),
	diamond = Color3.fromRGB(196, 242, 242),
	amethyst = Color3.fromRGB(124, 52, 222),
	obsidian = Color3.fromRGB(32, 30, 38),
	lunar = Color3.fromRGB(214, 222, 255),
}
local GRIP = Color3.fromRGB(112, 72, 46)

local function sword(m: Model, tier: string): BasePart
	local blade = SWORD_TIERS[tier]
	local dark = blade:Lerp(Color3.new(0, 0, 0), 0.3)
	local light = blade:Lerp(Color3.new(1, 1, 1), 0.18)
	local grip = part(m, Vector3.new(0.26, 1, 0.26), CFrame.new(0, 0.35, 0), GRIP, Enum.Material.Fabric)
	part(m, Vector3.new(0.34, 0.22, 0.34), CFrame.new(0, -0.25, 0), dark)
	part(m, Vector3.new(1, 0.2, 0.3), CFrame.new(0, 0.95, 0), dark)
	-- Flat blade plus a diamond-section ridge down the middle gives the faceted look.
	part(m, Vector3.new(0.5, 2.6, 0.1), CFrame.new(0, 2.35, 0), blade)
	part(m, Vector3.new(0.2, 2.6, 0.2), CFrame.new(0, 2.35, 0) * CFrame.Angles(0, math.rad(45), 0), light)
	-- Pointed tip: blocks turned 45 degrees so half of each sticks out past the blade.
	part(m, Vector3.new(0.354, 0.354, 0.1), CFrame.new(0, 3.65, 0) * CFrame.Angles(0, 0, math.rad(45)), blade)
	part(m, Vector3.new(0.141, 0.141, 0.141), CFrame.new(0, 3.65, 0) * CFrame.Angles(0, math.rad(45), 0) * CFrame.Angles(math.rad(45), 0, 0), light)
	return grip
end

for tier in SWORD_TIERS do
	builders[tier .. "_sword"] = function(m)
		return sword(m, tier)
	end
end

-- Obsidian: a black volcanic-glass blade knapped into jagged shards, with molten
-- orange cracks glowing down the middle, a rough black guard and a shard pommel.
function builders.obsidian_sword(m)
	local glass = Color3.fromRGB(14, 12, 20)
	local sheen = Color3.fromRGB(46, 40, 62)
	local magma = Color3.fromRGB(255, 104, 30)
	local grip = part(m, Vector3.new(0.26, 1, 0.26), CFrame.new(0, 0.35, 0), Color3.fromRGB(30, 24, 22), Enum.Material.Fabric)
	-- Shard pommel and a rough, uneven guard.
	part(m, Vector3.new(0.3, 0.3, 0.3), CFrame.new(0, -0.3, 0) * CFrame.Angles(math.rad(45), math.rad(30), math.rad(45)), glass, Enum.Material.Glass)
	part(m, Vector3.new(0.55, 0.22, 0.32), CFrame.new(-0.25, 0.97, 0) * CFrame.Angles(0, 0, math.rad(10)), glass, Enum.Material.Basalt)
	part(m, Vector3.new(0.55, 0.22, 0.32), CFrame.new(0.25, 0.93, 0) * CFrame.Angles(0, 0, math.rad(-14)), glass, Enum.Material.Basalt)
	-- The blade: stacked flakes, each a little off-line, so the edge is chipped and jagged.
	local flakes = { { 1.4, 0.56, 0 }, { 1.95, 0.5, 6 }, { 2.5, 0.46, -5 }, { 3.0, 0.4, 7 }, { 3.45, 0.3, -6 } }
	for i, f in flakes do
		local y, w, tilt = f[1], f[2], f[3]
		part(m, Vector3.new(w, 0.62, 0.1), CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.rad(tilt)), if i % 2 == 0 then sheen else glass, Enum.Material.Glass)
	end
	-- Pointed tip.
	part(m, Vector3.new(0.3, 0.3, 0.1), CFrame.new(0, 3.75, 0) * CFrame.Angles(0, 0, math.rad(45)), glass, Enum.Material.Glass)
	-- Molten cracks down both faces.
	for _, z in { -0.06, 0.06 } do
		part(m, Vector3.new(0.06, 2.5, 0.02), CFrame.new(0.02, 2.4, z) * CFrame.Angles(0, 0, math.rad(3)), magma, Enum.Material.Neon)
		part(m, Vector3.new(0.05, 0.5, 0.02), CFrame.new(0.12, 1.9, z) * CFrame.Angles(0, 0, math.rad(-35)), magma, Enum.Material.Neon)
		part(m, Vector3.new(0.05, 0.45, 0.02), CFrame.new(-0.1, 2.9, z) * CFrame.Angles(0, 0, math.rad(30)), magma, Enum.Material.Neon)
	end
	local glow = Instance.new("PointLight")
	glow.Color = magma
	glow.Range = 5
	glow.Brightness = 0.6
	glow.Parent = grip
	return grip
end

local function harvester(m: Model, headColor: Color3, headMaterial: Enum.Material): BasePart
	local handle = part(m, Vector3.new(0.3, 3, 0.3), CFrame.new(0, 1.3, 0), C.woodDark, Enum.Material.Wood)
	-- A pick head on one side and an axe blade on the other.
	part(m, Vector3.new(0.4, 0.4, 0.6), CFrame.new(0, 2.7, 0), headColor, headMaterial)
	part(m, Vector3.new(0.25, 0.35, 1.3), CFrame.new(0, 2.6, -0.85) * CFrame.Angles(math.rad(-15), 0, 0), headColor, headMaterial)
	part(m, Vector3.new(0.18, 1, 0.9), CFrame.new(0, 2.6, 0.7), headColor, headMaterial)
	return handle
end

for _, tier in Tiers.list do
	builders[tier.id .. "_harvester"] = function(m)
		return harvester(m, tier.plate, Enum.Material.SmoothPlastic)
	end
end

function builders.wood_harvester(m)
	return harvester(m, C.woodLight, Enum.Material.Wood)
end

function builders.stone_harvester(m)
	return harvester(m, C.stone, Enum.Material.Slate)
end

-- Resources --------------------------------------------------------------------

function builders.log(m)
	local core = part(m, Vector3.new(2.2, 0.9, 0.9), CFrame.new(), C.wood, Enum.Material.Wood, Enum.PartType.Cylinder)
	part(m, Vector3.new(2.25, 0.6, 0.6), CFrame.new(), C.woodLight, Enum.Material.Wood, Enum.PartType.Cylinder)
	return core
end

function builders.stick(m)
	local core = part(m, Vector3.new(0.22, 2, 0.22), CFrame.Angles(0, 0, math.rad(20)), C.woodDark, Enum.Material.Wood)
	part(m, Vector3.new(0.15, 0.7, 0.15), CFrame.new(0.25, 0.3, 0) * CFrame.Angles(0, 0, math.rad(-30)), C.woodDark, Enum.Material.Wood)
	return core
end

function builders.leaves(m)
	local core = part(m, Vector3.new(1.4, 0.15, 0.8), CFrame.Angles(0, 0.3, 0.1), C.leaf, Enum.Material.Grass)
	part(m, Vector3.new(1.2, 0.15, 0.7), CFrame.new(0.1, 0.12, 0.1) * CFrame.Angles(0, -0.6, -0.1), C.leaf:Lerp(Color3.new(0, 0, 0), 0.15), Enum.Material.Grass)
	return core
end

function builders.stone(m)
	return lump(m, 0.9, CFrame.new(), C.stone, Enum.Material.Slate, 11)
end

function builders.sticky_slime(m)
	local core = part(m, Vector3.new(1, 1, 1), CFrame.new(), C.slime, Enum.Material.Glass, Enum.PartType.Ball)
	core.Transparency = 0.15
	part(m, Vector3.new(0.5, 0.5, 0.5), CFrame.new(0.35, 0.3, -0.2), C.slime:Lerp(Color3.new(1, 1, 1), 0.3), Enum.Material.Glass, Enum.PartType.Ball)
	return core
end

-- Bars: a bevelled ingot in the tier's colour, with a lighter top face.
for _, bar in { "silver", "gold", "sunsteel" } do
	builders[bar .. "_bar"] = function(m)
		local tier = Tiers.get(bar) :: any
		local core = part(m, Vector3.new(1.3, 0.42, 0.62), CFrame.new(), tier.plate, Enum.Material.Metal)
		part(m, Vector3.new(1.1, 0.12, 0.46), CFrame.new(0, 0.25, 0), tier.plate:Lerp(Color3.new(1, 1, 1), 0.25), Enum.Material.Metal)
		for sx = -1, 1, 2 do
			part(m, Vector3.new(0.12, 0.38, 0.56), CFrame.new(sx * 0.66, -0.01, 0) * CFrame.Angles(0, 0, sx * 0.35), tier.trim, Enum.Material.Metal)
		end
		return core
	end
end

-- Ores and crystals: tier-coloured nuggets on a chip of rock, or a small cluster of shards.
for _, ore in require(script.Parent.Ores) do
	builders[ore.item] = function(m)
		local tier = Tiers.get(ore.tier) :: any
		local glowMat = if tier.glow then Enum.Material.Neon else nil
		if ore.look == "metal" then
			local core = lump(m, 0.8, CFrame.new(0, -0.1, 0), C.stone, Enum.Material.Slate, 21)
			part(m, Vector3.new(0.45, 0.4, 0.45), CFrame.new(0.2, 0.25, 0.1) * CFrame.Angles(0.4, 0.7, 0.2), tier.plate, Enum.Material.Metal)
			part(m, Vector3.new(0.35, 0.3, 0.35), CFrame.new(-0.25, 0.2, -0.1) * CFrame.Angles(0.9, 0.2, 0.5), tier.plate, glowMat or Enum.Material.Metal)
			part(m, Vector3.new(0.3, 0.28, 0.3), CFrame.new(0, 0.05, 0.35) * CFrame.Angles(0.2, 1.1, 0.8), tier.trim, Enum.Material.Metal)
			return core
		end
		local core = part(m, Vector3.new(0.42, 1.2, 0.42), CFrame.Angles(0, math.rad(45), 0.08), tier.plate, glowMat or Enum.Material.Glass)
		part(m, Vector3.new(0.32, 0.85, 0.32), CFrame.new(0.3, -0.15, 0.05) * CFrame.Angles(0, math.rad(45), -0.45), tier.accent, Enum.Material.Glass)
		part(m, Vector3.new(0.3, 0.75, 0.3), CFrame.new(-0.28, -0.2, -0.05) * CFrame.Angles(0.1, math.rad(45), 0.5), tier.plate, Enum.Material.Glass)
		return core
	end
end

function builders.leather(m)
	local core = part(m, Vector3.new(1.4, 0.12, 1), CFrame.Angles(0, 0.2, 0.05), C.leather, Enum.Material.Fabric)
	part(m, Vector3.new(1, 0.12, 0.7), CFrame.new(0.1, 0.1, 0) * CFrame.Angles(0, -0.4, 0), C.leather:Lerp(Color3.new(0, 0, 0), 0.15), Enum.Material.Fabric)
	return core
end

-- Food -------------------------------------------------------------------------

-- Fruit and crops: big, chunky and smooth, a strong colour with a highlight and a
-- few details (specks, stripes, a leaf) so each reads at a glance in the bag.
local function ball(m: Model, size: Vector3, cf: CFrame, colour: Color3, material: Enum.Material?): Part
	return part(m, size, cf, colour, material or Enum.Material.SmoothPlastic, Enum.PartType.Ball)
end

local function shine(m: Model, on: BasePart, at: Vector3, size: number)
	ball(m, Vector3.new(size, size * 0.7, size * 0.5), on.CFrame * CFrame.new(at), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic).Transparency = 0.45
end

local function leaf(m: Model, cf: CFrame, colour: Color3?)
	part(m, Vector3.new(0.5, 0.06, 0.28), cf, colour or Color3.fromRGB(86, 168, 62), Enum.Material.SmoothPlastic)
end

-- Redberries: three plump berries with pale specks and a leaf on top.
function builders.berries(m)
	local core
	local red = Color3.fromRGB(196, 44, 56)
	for i, o in { Vector3.new(0, -0.05, 0), Vector3.new(0.42, 0.02, 0.15), Vector3.new(-0.3, 0.05, 0.3) } do
		local b = ball(m, Vector3.new(0.62, 0.6, 0.62), CFrame.new(o), red:Lerp(Color3.fromRGB(120, 20, 40), (i - 1) * 0.12))
		for k = 0, 4 do
			local a = k * 1.3 + i
			part(m, Vector3.new(0.07, 0.07, 0.03), b.CFrame * CFrame.Angles(math.sin(a) * 0.9, a, 0) * CFrame.new(0, 0, -0.31), Color3.fromRGB(250, 214, 210), Enum.Material.SmoothPlastic)
		end
		shine(m, b, Vector3.new(-0.12, 0.15, -0.2), 0.16)
		core = core or b
	end
	part(m, Vector3.new(0.06, 0.25, 0.06), CFrame.new(0.05, 0.35, 0.12), Color3.fromRGB(90, 64, 40))
	leaf(m, CFrame.new(0.22, 0.42, 0.12) * CFrame.Angles(0, 0.4, 0.35))
	return core
end

function builders.sunfruit(m)
	local fruit = ball(m, Vector3.new(1.2, 1.15, 1.2), CFrame.new(), Color3.fromRGB(255, 146, 36), Enum.Material.Sand)
	shine(m, fruit, Vector3.new(-0.25, 0.25, -0.38), 0.3)
	part(m, Vector3.new(0.1, 0.22, 0.1), CFrame.new(0, 0.64, 0), Color3.fromRGB(90, 64, 40))
	leaf(m, CFrame.new(0.22, 0.7, 0) * CFrame.Angles(0, 0, 0.4))
	return fruit
end

-- A chunky curved banana: overlapping round sections bending in an arc, thick in the
-- middle, with a brown stalk and tip.
function builders.banana(m)
	local core
	local yellow = Color3.fromRGB(250, 214, 60)
	local n = 9
	for i = 0, n - 1 do
		local t = i / (n - 1)
		local a = (t - 0.5) * 1.7
		local r = 0.3 + math.sin(t * math.pi) * 0.16
		local seg = ball(m, Vector3.new(r * 1.5, r * 1.15, r * 1.15), CFrame.new(math.sin(a) * 1.0, -math.cos(a) * 1.0 + 0.85, 0) * CFrame.Angles(0, 0, a), yellow:Lerp(Color3.fromRGB(210, 170, 40), math.abs(t - 0.5) * 0.4))
		if i == math.floor(n / 2) then
			core = seg
		end
	end
	local a0, a1 = -0.95, 0.95
	part(m, Vector3.new(0.14, 0.34, 0.14), CFrame.new(math.sin(a1) * 1.08, -math.cos(a1) * 1.08 + 0.92, 0) * CFrame.Angles(0, 0, a1), Color3.fromRGB(110, 90, 40))
	ball(m, Vector3.new(0.14, 0.14, 0.14), CFrame.new(math.sin(a0) * 1.02, -math.cos(a0) * 1.02 + 0.85, 0), Color3.fromRGB(70, 50, 30))
	shine(m, core, Vector3.new(0, 0.12, -0.18), 0.24)
	return core
end

function builders.mango(m)
	local fruit = ball(m, Vector3.new(1.0, 1.25, 0.9), CFrame.new() * CFrame.Angles(0, 0, 0.25), Color3.fromRGB(246, 168, 46))
	ball(m, Vector3.new(0.72, 0.8, 0.7), CFrame.new(-0.2, 0.22, 0.08), Color3.fromRGB(226, 84, 56))
	shine(m, fruit, Vector3.new(-0.2, 0.25, -0.34), 0.24)
	part(m, Vector3.new(0.09, 0.2, 0.09), CFrame.new(0.1, 0.66, 0), Color3.fromRGB(90, 64, 40))
	leaf(m, CFrame.new(0.3, 0.7, 0) * CFrame.Angles(0, 0, -0.5))
	return fruit
end

-- A hairy brown coconut with three dark eyes.
function builders.coconut(m)
	local nut = ball(m, Vector3.new(1.15, 1.08, 1.15), CFrame.new(), Color3.fromRGB(104, 70, 44), Enum.Material.Fabric)
	for k = 0, 2 do
		local a = k / 3 * math.pi * 2
		ball(m, Vector3.new(0.16, 0.16, 0.08), CFrame.new(math.cos(a) * 0.14, 0.5, math.sin(a) * 0.14) * CFrame.Angles(math.rad(90), 0, 0), Color3.fromRGB(46, 30, 20))
	end
	for k = 0, 5 do
		local a = k * 1.05
		part(m, Vector3.new(0.05, 0.4, 0.03), nut.CFrame * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -0.56) * CFrame.Angles(0, 0, 0.3), Color3.fromRGB(70, 46, 30), Enum.Material.Fabric)
	end
	return nut
end

-- A striped watermelon.
function builders.watermelon(m)
	local melon = ball(m, Vector3.new(1.5, 1.2, 1.2), CFrame.new(), Color3.fromRGB(64, 140, 56))
	for k = -2, 2 do
		ball(m, Vector3.new(1.52, 1.22, 0.14), CFrame.new() * CFrame.Angles(k * 0.55, 0, 0), Color3.fromRGB(32, 84, 32))
	end
	shine(m, melon, Vector3.new(-0.3, 0.32, -0.3), 0.3)
	part(m, Vector3.new(0.08, 0.16, 0.08), CFrame.new(0.72, 0.2, 0) * CFrame.Angles(0, 0, -1), Color3.fromRGB(90, 64, 40))
	return melon
end

-- A carrot: an orange taper (stacked shrinking rounds) with a leafy green top.
function builders.carrot(m)
	local core
	local orange = Color3.fromRGB(240, 128, 36)
	for i = 0, 5 do
		local t = i / 5
		local r = 0.48 * (1 - t * 0.8)
		local seg = ball(m, Vector3.new(r, 0.42, r), CFrame.new(0, 0.5 - t * 1.2, 0), orange:Lerp(Color3.fromRGB(220, 100, 30), t * 0.4))
		if i == 1 then
			core = seg
		end
	end
	for k = 0, 3 do
		part(m, Vector3.new(0.08, 0.5, 0.18), CFrame.new(0, 0.85, 0) * CFrame.Angles(0, k * 0.8, 0) * CFrame.Angles(0.35, 0, 0) * CFrame.new(0, 0.1, 0), Color3.fromRGB(92, 176, 62))
	end
	for k = 0, 2 do
		part(m, Vector3.new(0.3, 0.03, 0.03), CFrame.new(0, 0.3 - k * 0.3, 0) * CFrame.Angles(0, k, 0) * CFrame.new(0, 0, -0.2 + k * 0.04), Color3.fromRGB(196, 96, 30))
	end
	return core
end

local function potatoModel(m: Model, skin: Color3, spot: Color3): BasePart
	local p = ball(m, Vector3.new(1.25, 0.85, 0.95), CFrame.new() * CFrame.Angles(0, 0, 0.2), skin, Enum.Material.Sand)
	ball(m, Vector3.new(0.7, 0.62, 0.7), CFrame.new(0.38, 0.1, 0.05), skin:Lerp(Color3.new(0, 0, 0), 0.05), Enum.Material.Sand)
	for k = 0, 4 do
		local a = k * 1.25
		ball(m, Vector3.new(0.09, 0.09, 0.05), p.CFrame * CFrame.Angles(math.sin(a) * 0.8, a, 0) * CFrame.new(0, 0, -0.44), spot)
	end
	return p
end

function builders.potato(m)
	return potatoModel(m, Color3.fromRGB(184, 142, 90), Color3.fromRGB(120, 88, 54))
end

function builders.baked_potato(m)
	local p = potatoModel(m, Color3.fromRGB(150, 100, 56), Color3.fromRGB(90, 60, 34))
	part(m, Vector3.new(0.7, 0.12, 0.4), CFrame.new(0, 0.42, 0), Color3.fromRGB(250, 226, 150))
	part(m, Vector3.new(0.26, 0.1, 0.26), CFrame.new(0.05, 0.5, 0), Color3.fromRGB(255, 236, 120))
	return p
end

-- Slimes: a wobbly translucent blob with two eyes, in its variant's colour.
local function slimeModel(m: Model, colour: Color3, glow: boolean?): BasePart
	local body = ball(m, Vector3.new(1.3, 1.0, 1.2), CFrame.new(0, -0.05, 0), colour, Enum.Material.Glass)
	body.Transparency = 0.2
	ball(m, Vector3.new(0.7, 0.5, 0.6), CFrame.new(0, -0.05, 0), colour:Lerp(Color3.new(0, 0, 0), 0.25), if glow then Enum.Material.Neon else Enum.Material.SmoothPlastic)
	for _, x in { -0.22, 0.22 } do
		ball(m, Vector3.new(0.2, 0.26, 0.1), CFrame.new(x, 0.12, -0.56), Color3.fromRGB(20, 20, 24))
		ball(m, Vector3.new(0.07, 0.07, 0.04), CFrame.new(x - 0.04, 0.18, -0.61), Color3.new(1, 1, 1))
	end
	shine(m, body, Vector3.new(-0.3, 0.3, -0.35), 0.28)
	return body
end

function builders.green_slime(m)
	return slimeModel(m, Color3.fromRGB(110, 210, 90))
end
function builders.blue_slime(m)
	return slimeModel(m, Color3.fromRGB(80, 150, 240))
end
function builders.pink_slime(m)
	return slimeModel(m, Color3.fromRGB(250, 130, 200))
end
function builders.gold_slime(m)
	return slimeModel(m, Color3.fromRGB(255, 206, 60), true)
end

-- Seeds: a tied cloth pouch in the crop's colour with a few seeds spilling out, big
-- enough to spot on the ground.
local function seedsModel(m: Model, a: Color3, b: Color3): BasePart
	local cloth = Color3.fromRGB(214, 190, 140)
	local core = ball(m, Vector3.new(1.1, 0.95, 1.1), CFrame.new(0, 0, 0), cloth, Enum.Material.Fabric)
	ball(m, Vector3.new(0.7, 0.4, 0.7), CFrame.new(0, 0.5, 0), cloth:Lerp(Color3.new(0, 0, 0), 0.1), Enum.Material.Fabric)
	part(m, Vector3.new(0.74, 0.12, 0.74), CFrame.new(0, 0.42, 0), a, Enum.Material.Fabric, Enum.PartType.Cylinder).CFrame = CFrame.new(0, 0.42, 0) * CFrame.Angles(0, 0, math.rad(90))
	-- A patch of the crop's colour on the front.
	ball(m, Vector3.new(0.5, 0.5, 0.2), CFrame.new(0, 0, -0.5), a, Enum.Material.SmoothPlastic)
	for i, o in { Vector3.new(0.6, -0.35, -0.3), Vector3.new(0.75, -0.38, 0.05), Vector3.new(0.5, -0.4, 0.3) } do
		ball(m, Vector3.new(0.3, 0.16, 0.2), CFrame.new(o) * CFrame.Angles(0, i * 0.9, 0), if i % 2 == 0 then a else b)
	end
	return core
end

function builders.carrot_seeds(m)
	return seedsModel(m, Color3.fromRGB(230, 120, 50), Color3.fromRGB(196, 92, 40))
end
function builders.potato_seeds(m)
	return seedsModel(m, Color3.fromRGB(110, 92, 74), Color3.fromRGB(150, 128, 100))
end
function builders.watermelon_seeds(m)
	return seedsModel(m, Color3.fromRGB(40, 32, 30), Color3.fromRGB(70, 56, 46))
end
function builders.slime_spore(m)
	local core
	for i, o in { Vector3.new(0, 0, 0), Vector3.new(0.34, 0.05, 0.1), Vector3.new(-0.26, 0.08, 0.2) } do
		local s = ball(m, Vector3.new(0.4, 0.4, 0.4), CFrame.new(o), ({ Color3.fromRGB(110, 210, 90), Color3.fromRGB(80, 150, 240), Color3.fromRGB(250, 130, 200) })[i], Enum.Material.Glass)
		s.Transparency = 0.15
		core = core or s
	end
	return core
end

function builders.plant_box(m)
	local soil = part(m, Vector3.new(1.6, 0.4, 1.6), CFrame.new(), Color3.fromRGB(70, 48, 32), Enum.Material.Ground)
	for i = 0, 3 do
		part(m, Vector3.new(1.75, 0.5, 0.14), CFrame.Angles(0, i * math.pi / 2, 0) * CFrame.new(0, 0.05, 0.8), if i % 2 == 0 then C.wood else C.woodDark, Enum.Material.WoodPlanks)
	end
	for k = -1, 1 do
		part(m, Vector3.new(0.12, 0.45, 0.3), CFrame.new(k * 0.45, 0.4, 0) * CFrame.Angles(0, k, 0.2), Color3.fromRGB(92, 176, 62))
	end
	return soil
end

local function mushroomModel(m: Model, cap: Color3): BasePart
	local stem = part(m, Vector3.new(0.35, 0.7, 0.35), CFrame.new(0, -0.15, 0), Color3.fromRGB(236, 226, 200), Enum.Material.SmoothPlastic)
	part(m, Vector3.new(1.1, 0.45, 1.1), CFrame.new(0, 0.3, 0), cap, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	for _, o in { Vector3.new(0.25, 0.5, 0.1), Vector3.new(-0.2, 0.48, -0.2), Vector3.new(0.05, 0.52, 0.3) } do
		part(m, Vector3.new(0.14, 0.08, 0.14), CFrame.new(o), Color3.fromRGB(250, 244, 230), Enum.Material.SmoothPlastic)
	end
	return stem
end

function builders.mushroom(m)
	return mushroomModel(m, Color3.fromRGB(200, 60, 50))
end

function builders.roast_mushroom(m)
	return mushroomModel(m, Color3.fromRGB(130, 70, 40))
end

local function fish(m: Model, body: Color3, belly: Color3): BasePart
	local core = part(m, Vector3.new(1.4, 0.55, 0.4), CFrame.new(), body, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	part(m, Vector3.new(1.0, 0.3, 0.36), CFrame.new(0.05, -0.12, 0), belly, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	part(m, Vector3.new(0.1, 0.55, 0.45), CFrame.new(0.78, 0, 0) * CFrame.Angles(0.785, 0, 0), body, Enum.Material.SmoothPlastic)
	part(m, Vector3.new(0.08, 0.08, 0.08), CFrame.new(-0.5, 0.08, 0.17), Color3.fromRGB(20, 20, 20), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	return core
end

function builders.raw_fish(m)
	return fish(m, Color3.fromRGB(110, 150, 190), Color3.fromRGB(220, 230, 235))
end

function builders.cooked_fish(m)
	return fish(m, Color3.fromRGB(176, 110, 60), Color3.fromRGB(220, 170, 110))
end

function builders.fruit_salad(m)
	local bowl = part(m, Vector3.new(1.4, 0.5, 1.4), CFrame.new(0, -0.15, 0), Color3.fromRGB(150, 100, 60), Enum.Material.Wood, Enum.PartType.Cylinder)
	bowl.CFrame = CFrame.new(0, -0.15, 0) * CFrame.Angles(0, 0, math.pi / 2)
	bowl.Size = Vector3.new(0.5, 1.4, 1.4)
	for i, c in { Color3.fromRGB(250, 214, 70), Color3.fromRGB(240, 150, 50), Color3.fromRGB(150, 40, 80), Color3.fromRGB(110, 200, 80), Color3.fromRGB(250, 214, 70) } do
		local a = i / 5 * math.pi * 2
		part(m, Vector3.new(0.38, 0.38, 0.38), CFrame.new(math.cos(a) * 0.35, 0.18, math.sin(a) * 0.35), c, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	end
	return bowl
end

function builders.banana_bread(m)
	local loaf = part(m, Vector3.new(1.4, 0.7, 0.8), CFrame.new(), Color3.fromRGB(170, 110, 60), Enum.Material.SmoothPlastic)
	part(m, Vector3.new(1.3, 0.3, 0.7), CFrame.new(0, 0.42, 0), Color3.fromRGB(120, 72, 38), Enum.Material.SmoothPlastic)
	part(m, Vector3.new(0.08, 0.5, 0.6), CFrame.new(-0.3, 0.1, 0), Color3.fromRGB(230, 200, 140), Enum.Material.SmoothPlastic)
	return loaf
end


local function meat(m: Model, color: Color3): BasePart
	local core = part(m, Vector3.new(1.3, 0.6, 0.9), CFrame.new(), color, Enum.Material.SmoothPlastic)
	part(m, Vector3.new(1.0, 0.4, 0.7), CFrame.new(0.05, 0.3, 0), color:Lerp(Color3.new(0, 0, 0), 0.1), Enum.Material.SmoothPlastic)
	part(m, Vector3.new(0.2, 0.2, 0.9), CFrame.new(0.7, 0, 0) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(240, 230, 210), Enum.Material.SmoothPlastic)
	return core
end

function builders.raw_meat(m)
	return meat(m, C.meatRaw)
end

function builders.cooked_meat(m)
	return meat(m, C.meatCooked)
end

-- Armour -----------------------------------------------------------------------

-- Block fallbacks for when the armour meshes aren't in the place.
local function armourBlocks(m: Model, slot: string, main: Color3, edge: Color3, material: Enum.Material): BasePart
	if slot == "helmet" then
		local core = part(m, Vector3.new(1.5, 0.9, 1.5), CFrame.new(), main, material)
		part(m, Vector3.new(1.7, 0.2, 1.7), CFrame.new(0, -0.4, 0), edge, material)
		return core
	elseif slot == "body" then
		local core = part(m, Vector3.new(2.1, 2.1, 1.1), CFrame.new(), main, material)
		part(m, Vector3.new(2.2, 0.25, 1.2), CFrame.new(0, -0.7, 0), edge, material)
		return core
	elseif slot == "legs" then
		local core = part(m, Vector3.new(0.9, 1.8, 0.9), CFrame.new(-0.5, 0, 0), main, material)
		part(m, Vector3.new(0.9, 1.8, 0.9), CFrame.new(0.5, 0, 0), main, material)
		return core
	end
	local core = part(m, Vector3.new(0.9, 0.6, 1.2), CFrame.new(-0.5, 0, 0), edge, material)
	part(m, Vector3.new(0.9, 0.6, 1.2), CFrame.new(0.5, 0, 0), edge, material)
	return core
end

for _, tier in Tiers.list do
	for _, slot in { "helmet", "body", "legs", "boots" } do
		builders[tier.id .. "_" .. slot] = function(m)
			if tier.id == "wood" then
				return armourBlocks(m, slot, C.wood, C.woodDark, Enum.Material.WoodPlanks)
			end
			return armourBlocks(m, slot, tier.plate, tier.trim, Enum.Material.SmoothPlastic)
		end
	end
end

-- A proper rucksack: a rounded main body, a top flap with a buckle, a front pocket
-- with its own flap, two side pouches, a rolled bedroll strapped on top and two
-- shoulder straps down the back (the -Z side sits against the wearer).
local function backpack(m: Model, body: Color3, flap: Color3, trim: Color3, accent: Color3, accentMat: Enum.Material, bodyMat: Enum.Material?)
	local mat = bodyMat or Enum.Material.Fabric
	local core = part(m, Vector3.new(1.6, 1.7, 0.85), CFrame.new(0, -0.05, 0), body, mat)
	-- Rounded top and bottom edges.
	part(m, Vector3.new(1.6, 0.85, 0.85), CFrame.new(0, 0.8, 0), body, mat, Enum.PartType.Cylinder)
	part(m, Vector3.new(1.5, 0.3, 0.8), CFrame.new(0, -0.95, 0), body:Lerp(Color3.new(0, 0, 0), 0.15), mat)
	-- Top flap folding over the front, with a buckle.
	part(m, Vector3.new(1.66, 0.22, 0.95), CFrame.new(0, 1.12, 0.02), flap, mat)
	part(m, Vector3.new(1.62, 0.62, 0.12), CFrame.new(0, 0.82, 0.48), flap, mat)
	part(m, Vector3.new(0.18, 0.5, 0.06), CFrame.new(0, 0.5, 0.56), trim, Enum.Material.Leather)
	part(m, Vector3.new(0.3, 0.22, 0.07), CFrame.new(0, 0.34, 0.57), accent, accentMat)
	-- Front pocket.
	part(m, Vector3.new(1.1, 0.75, 0.3), CFrame.new(0, -0.45, 0.55), body:Lerp(flap, 0.35), mat)
	part(m, Vector3.new(1.14, 0.22, 0.34), CFrame.new(0, -0.1, 0.56), flap, mat)
	part(m, Vector3.new(0.2, 0.14, 0.06), CFrame.new(0, -0.24, 0.73), accent, accentMat)
	-- Side pouches.
	for _, x in { -0.9, 0.9 } do
		part(m, Vector3.new(0.26, 0.7, 0.55), CFrame.new(x, -0.35, 0.05), body:Lerp(flap, 0.35), mat)
		part(m, Vector3.new(0.3, 0.12, 0.58), CFrame.new(x, 0.0, 0.05), trim, Enum.Material.Leather)
	end
	-- Bedroll on top, tied with two straps.
	part(m, Vector3.new(1.9, 0.5, 0.5), CFrame.new(0, 1.45, 0), Color3.fromRGB(178, 150, 110), Enum.Material.Fabric, Enum.PartType.Cylinder)
	for _, x in { -0.55, 0.55 } do
		part(m, Vector3.new(0.12, 0.56, 0.56), CFrame.new(x, 1.45, 0), trim, Enum.Material.Leather, Enum.PartType.Cylinder)
	end
	-- Shoulder straps down the back.
	for _, x in { -0.45, 0.45 } do
		part(m, Vector3.new(0.22, 1.5, 0.08), CFrame.new(x, 0.05, -0.46), trim, Enum.Material.Leather)
	end
	-- Trim straps round the body.
	part(m, Vector3.new(1.64, 0.1, 0.89), CFrame.new(0, -0.75, 0), trim, Enum.Material.Leather)
	return core
end

function builders.leather_bag(m)
	return backpack(m, C.leather, C.leather:Lerp(Color3.new(0, 0, 0), 0.2), Color3.fromRGB(86, 56, 34), Color3.fromRGB(200, 170, 90), Enum.Material.Metal)
end

builders.hide_pack = builders.leather_bag
builders.explorer_pack = builders.leather_bag
-- Ore-tier bags: the rucksack in the tier's colours.
for _, tier in Tiers.list do
	builders[tier.id .. "_bag"] = function(m)
		local accentMat = if tier.glow then Enum.Material.Neon else Enum.Material.Metal
		return backpack(m, tier.plate, tier.trim, tier.strap, tier.accent, accentMat, if tier.style == "crystal" then Enum.Material.Glass else Enum.Material.Fabric)
	end
end

-- Cave loot ------------------------------------------------------------------------

-- Crates: a big iron-banded chest whose bands and lock show its rarity. The lid parts
-- are named "Lid" so the opening screen can swing it open.
local CRATE_LOOK = {
	supply_crate = { wood = C.wood, band = Color3.fromRGB(96, 70, 48), gem = Color3.fromRGB(220, 180, 70), glow = false },
	rare_crate = { wood = Color3.fromRGB(120, 86, 58), band = Color3.fromRGB(70, 120, 200), gem = Color3.fromRGB(120, 190, 255), glow = false },
	epic_crate = { wood = Color3.fromRGB(86, 60, 70), band = Color3.fromRGB(140, 70, 200), gem = Color3.fromRGB(210, 140, 255), glow = true },
	mythic_crate = { wood = Color3.fromRGB(60, 44, 40), band = Color3.fromRGB(230, 180, 60), gem = Color3.fromRGB(255, 220, 110), glow = true },
}
for id, look in CRATE_LOOK do
	builders[id] = function(m)
		local W, H, D = 2.4, 1.5, 1.7
		local core = part(m, Vector3.new(W, H, D), CFrame.new(0, -0.2, 0), look.wood, Enum.Material.WoodPlanks)
		-- Corner posts and the base rim.
		for _, x in { -1, 1 } do
			for _, z in { -1, 1 } do
				part(m, Vector3.new(0.22, H + 0.06, 0.22), CFrame.new(x * (W / 2 - 0.05), -0.2, z * (D / 2 - 0.05)), look.band, Enum.Material.Metal)
			end
		end
		part(m, Vector3.new(W + 0.1, 0.16, D + 0.1), CFrame.new(0, -0.2 - H / 2 + 0.08, 0), look.band, Enum.Material.Metal)
		-- Two bands round the body.
		for _, x in { -0.6, 0.6 } do
			part(m, Vector3.new(0.18, H + 0.04, D + 0.06), CFrame.new(x, -0.2, 0), look.band, Enum.Material.Metal)
		end
		-- The lid: a slab with a rounded top and its own bands.
		local lid = part(m, Vector3.new(W + 0.08, 0.3, D + 0.08), CFrame.new(0, 0.7, 0), look.wood, Enum.Material.WoodPlanks)
		lid.Name = "Lid"
		local top = part(m, Vector3.new(W - 0.1, 0.22, D - 0.2), CFrame.new(0, 0.95, 0), look.wood:Lerp(Color3.new(1, 1, 1), 0.08), Enum.Material.WoodPlanks)
		top.Name = "Lid"
		for _, x in { -0.6, 0.6 } do
			local band = part(m, Vector3.new(0.2, 0.42, D + 0.12), CFrame.new(x, 0.8, 0), look.band, Enum.Material.Metal)
			band.Name = "Lid"
		end
		-- Lock plate and gem on the front.
		local plate = part(m, Vector3.new(0.5, 0.56, 0.08), CFrame.new(0, 0.5, -D / 2 - 0.06), look.band, Enum.Material.Metal)
		plate.Name = "Lid"
		local gem = part(m, Vector3.new(0.26, 0.26, 0.26), CFrame.new(0, 0.5, -D / 2 - 0.12) * CFrame.Angles(0, 0, math.rad(45)), look.gem, if look.glow then Enum.Material.Neon else Enum.Material.Glass)
		gem.Name = "Lid"
		return core
	end
end

-- Mythic materials, only found in crates.
function builders.star_shard(m)
	local core = part(m, Vector3.new(0.5, 1.5, 0.5), CFrame.Angles(0, 0, math.rad(12)), Color3.fromRGB(255, 236, 150), Enum.Material.Neon)
	part(m, Vector3.new(0.36, 1, 0.36), CFrame.new(0.35, -0.3, 0) * CFrame.Angles(0, 0, math.rad(-30)), Color3.fromRGB(255, 210, 90), Enum.Material.Glass)
	part(m, Vector3.new(0.3, 0.8, 0.3), CFrame.new(-0.32, -0.35, 0.1) * CFrame.Angles(math.rad(10), 0, math.rad(35)), Color3.fromRGB(255, 250, 220), Enum.Material.Glass)
	return core
end
function builders.abyss_pearl(m)
	local core = part(m, Vector3.new(1, 1, 1), CFrame.new(0, 0.2, 0), Color3.fromRGB(40, 30, 70), Enum.Material.Glass, Enum.PartType.Ball)
	core.Reflectance = 0.3
	part(m, Vector3.new(1.4, 0.3, 1.2), CFrame.new(0, -0.35, 0), Color3.fromRGB(70, 86, 110), Enum.Material.Slate)
	part(m, Vector3.new(0.3, 0.3, 0.3), CFrame.new(0.2, 0.45, -0.38), Color3.fromRGB(150, 120, 255), Enum.Material.Neon, Enum.PartType.Ball)
	return core
end
function builders.ancient_rune(m)
	local core = part(m, Vector3.new(1.2, 1.4, 0.4), CFrame.new(), Color3.fromRGB(120, 116, 104), Enum.Material.Slate)
	part(m, Vector3.new(0.14, 0.9, 0.05), CFrame.new(0, 0, -0.22), Color3.fromRGB(120, 255, 220), Enum.Material.Neon)
	part(m, Vector3.new(0.6, 0.14, 0.05), CFrame.new(0, 0.2, -0.22), Color3.fromRGB(120, 255, 220), Enum.Material.Neon)
	part(m, Vector3.new(0.5, 0.14, 0.05), CFrame.new(0, -0.25, -0.22) * CFrame.Angles(0, 0, math.rad(30)), Color3.fromRGB(120, 255, 220), Enum.Material.Neon)
	return core
end

local function keyShape(m, color: Color3, broken: boolean)
	local core = part(m, Vector3.new(0.25, 0.25, 1.4), CFrame.new(), color, Enum.Material.Metal)
	local ring = part(m, Vector3.new(0.18, 0.8, 0.8), CFrame.new(0, 0, 0.9), color, Enum.Material.Metal)
	ring.Shape = Enum.PartType.Cylinder
	if not broken then
		part(m, Vector3.new(0.18, 0.4, 0.25), CFrame.new(0, -0.25, -0.55), color, Enum.Material.Metal)
		part(m, Vector3.new(0.18, 0.3, 0.25), CFrame.new(0, -0.2, -0.25), color, Enum.Material.Metal)
	end
	return core
end
builders.maw_key = function(m)
	return keyShape(m, Color3.fromRGB(150, 50, 40), false)
end
builders.key_fragment = function(m)
	return keyShape(m, Color3.fromRGB(120, 110, 100), true)
end

function builders.queen_fang(m)
	local core = part(m, Vector3.new(0.5, 1.8, 0.5), CFrame.Angles(0, 0, 0.2), Color3.fromRGB(236, 226, 206), Enum.Material.SmoothPlastic)
	part(m, Vector3.new(0.6, 0.4, 0.6), CFrame.new(-0.18, -0.9, 0), Color3.fromRGB(120, 60, 90), Enum.Material.SmoothPlastic)
	return core
end
function builders.warden_core(m)
	local core = part(m, Vector3.new(1, 1.4, 1), CFrame.Angles(0, math.rad(45), 0), Color3.fromRGB(200, 150, 255), Enum.Material.Neon)
	part(m, Vector3.new(0.6, 1.8, 0.6), CFrame.Angles(0, math.rad(20), math.rad(10)), Color3.fromRGB(150, 90, 230), Enum.Material.Glass)
	return core
end
function builders.golem_heart(m)
	local core = part(m, Vector3.new(1.2, 1.2, 1.2), CFrame.new(), Color3.fromRGB(255, 110, 30), Enum.Material.Neon)
	core.Shape = Enum.PartType.Ball
	part(m, Vector3.new(1.4, 0.4, 1.4), CFrame.new(0, 0.2, 0), Color3.fromRGB(44, 36, 34), Enum.Material.Basalt)
	return core
end
function builders.warden_pack(m)
	local core = part(m, Vector3.new(1.8, 2, 0.9), CFrame.new(), Color3.fromRGB(70, 66, 92), Enum.Material.Slate)
	part(m, Vector3.new(0.6, 0.9, 0.2), CFrame.new(0, 0.2, -0.5), Color3.fromRGB(200, 150, 255), Enum.Material.Neon)
	return core
end
function builders.fang_blade(m)
	local grip = part(m, Vector3.new(0.3, 1.2, 0.3), CFrame.new(), C.leather, Enum.Material.Fabric)
	part(m, Vector3.new(1.2, 0.25, 0.3), CFrame.new(0, 0.7, 0), Color3.fromRGB(120, 60, 90), Enum.Material.SmoothPlastic)
	local blade = part(m, Vector3.new(0.35, 3.6, 0.15), CFrame.new(0, 2.6, 0) * CFrame.Angles(0, 0, 0.08), Color3.fromRGB(236, 226, 206), Enum.Material.SmoothPlastic)
	blade.Reflectance = 0.15
	return grip
end
function builders.golem_harvester(m)
	local grip = part(m, Vector3.new(0.35, 3, 0.35), CFrame.new(0, 1, 0), C.woodDark, Enum.Material.Wood)
	part(m, Vector3.new(2.2, 0.7, 0.5), CFrame.new(0, 2.6, 0), Color3.fromRGB(44, 36, 34), Enum.Material.Basalt)
	part(m, Vector3.new(0.5, 0.5, 0.55), CFrame.new(0, 2.6, 0), Color3.fromRGB(255, 110, 30), Enum.Material.Neon)
	return grip
end

-- Buildable icons ----------------------------------------------------------------

function builders.campfire(m)
	local core = part(m, Vector3.new(0.4, 0.4, 2), CFrame.Angles(0, 0, math.rad(10)), C.woodDark, Enum.Material.Wood)
	part(m, Vector3.new(0.4, 0.4, 2), CFrame.Angles(0, math.rad(60), 0), C.woodDark, Enum.Material.Wood)
	part(m, Vector3.new(0.4, 0.4, 2), CFrame.Angles(0, math.rad(-60), 0), C.woodDark, Enum.Material.Wood)
	part(m, Vector3.new(0.7, 0.9, 0.7), CFrame.new(0, 0.5, 0), Color3.fromRGB(255, 150, 50), Enum.Material.Neon)
	return core
end

function builders.storage_chest(m)
	local core = part(m, Vector3.new(2.4, 1.4, 1.6), CFrame.new(), C.wood, Enum.Material.WoodPlanks)
	part(m, Vector3.new(2.5, 0.5, 1.7), CFrame.new(0, 0.9, 0), C.woodDark, Enum.Material.WoodPlanks)
	for _, x in { -0.8, 0.8 } do
		part(m, Vector3.new(0.2, 1.95, 1.75), CFrame.new(x, 0.25, 0), Color3.fromRGB(90, 90, 96), Enum.Material.Metal)
	end
	part(m, Vector3.new(0.4, 0.45, 0.15), CFrame.new(0, 0.6, -0.85), Color3.fromRGB(214, 176, 72), Enum.Material.Metal)
	return core
end

local function slab(m: Model, color: Color3, material: Enum.Material, border: Color3): BasePart
	local core = part(m, Vector3.new(2.4, 0.3, 2.4), CFrame.new(), color, material)
	for i = 0, 3 do
		part(m, Vector3.new(2.6, 0.35, 0.3), CFrame.Angles(0, i * math.pi / 2, 0) * CFrame.new(0, 0.15, 1.2), border, material)
	end
	return core
end

function builders.wood_base(m)
	return slab(m, C.woodLight, Enum.Material.WoodPlanks, C.woodDark)
end

function builders.stone_base(m)
	return slab(m, C.stone, Enum.Material.Slate, C.stoneDark)
end

function builders.large_stone_base(m)
	local core = slab(m, C.stoneDark, Enum.Material.Slate, C.stone)
	part(m, Vector3.new(1.2, 0.32, 1.2), CFrame.new(0, 0.05, 0), C.stone, Enum.Material.Slate)
	return core
end

function builders.wood_wall(m)
	return part(m, Vector3.new(2, 2.2, 0.3), CFrame.new(), C.wood, Enum.Material.WoodPlanks)
end

function builders.stone_wall(m)
	local core = part(m, Vector3.new(2, 2.2, 0.5), CFrame.new(), C.stone, Enum.Material.Slate)
	lump(m, 0.8, CFrame.new(-0.5, 1.2, 0), C.stoneDark, Enum.Material.Slate, 5)
	lump(m, 0.8, CFrame.new(0.5, 1.2, 0), C.stone, Enum.Material.Slate, 6)
	return core
end

function builders.wood_gate(m)
	local core = part(m, Vector3.new(2, 2.2, 0.25), CFrame.new(), C.woodDark, Enum.Material.Wood)
	part(m, Vector3.new(1.9, 0.25, 0.35), CFrame.new(0, 0.5, 0), C.woodLight, Enum.Material.Wood)
	part(m, Vector3.new(1.9, 0.25, 0.35), CFrame.new(0, -0.5, 0), C.woodLight, Enum.Material.Wood)
	part(m, Vector3.new(2.2, 0.22, 0.33), CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.rad(27)), C.woodLight, Enum.Material.Wood)
	return core
end

-- Diving gear: a sea-glass dome with a brass rim.
function builders.aqua_mask(m)
	local core = part(m, Vector3.new(1.5, 1.1, 1.5), CFrame.new(), Color3.fromRGB(96, 184, 196), Enum.Material.Glass)
	part(m, Vector3.new(1.7, 0.22, 1.7), CFrame.new(0, -0.5, 0), Color3.fromRGB(176, 132, 64), Enum.Material.Metal)
	part(m, Vector3.new(0.9, 0.5, 0.15), CFrame.new(0, 0.05, -0.76), Color3.fromRGB(200, 240, 246), Enum.Material.Glass)
	return core
end

function builders.pearl_helm(m)
	local core = part(m, Vector3.new(1.6, 1.3, 1.6), CFrame.new(), Color3.fromRGB(232, 226, 236), Enum.Material.Glass)
	part(m, Vector3.new(1.8, 0.25, 1.8), CFrame.new(0, -0.6, 0), Color3.fromRGB(150, 160, 176), Enum.Material.Metal)
	part(m, Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, 0.75, 0), Color3.fromRGB(250, 246, 255), Enum.Material.Glass, Enum.PartType.Ball)
	return core
end

-- Round 7 gear --------------------------------------------------------------------

local function tierColour(id: string): (Color3, Color3)
	local tier = Tiers.get(id) :: any
	if tier then
		return tier.plate, tier.trim
	end
	return C.wood, C.woodDark
end

local function tierMaterial(id: string): Enum.Material
	local tier = Tiers.get(id) :: any
	local style = tier and tier.style
	if style == "metal" then
		return Enum.Material.Metal
	elseif style == "crystal" then
		return Enum.Material.Glass
	elseif style == "stone" then
		return Enum.Material.Slate
	end
	return Enum.Material.WoodPlanks
end

function builders.torch(m)
	local core = part(m, Vector3.new(0.25, 2.4, 0.25), CFrame.new(0, -0.3, 0), C.woodDark, Enum.Material.Wood)
	part(m, Vector3.new(0.45, 0.4, 0.45), CFrame.new(0, 0.95, 0), C.leather, Enum.Material.Fabric)
	part(m, Vector3.new(0.4, 0.6, 0.4), CFrame.new(0, 1.4, 0), Color3.fromRGB(255, 160, 60), Enum.Material.Neon, Enum.PartType.Ball)
	return core
end

function builders.lamp(m)
	local core = part(m, Vector3.new(0.25, 2.6, 0.25), CFrame.new(-0.5, 0, 0), C.woodDark, Enum.Material.Wood)
	part(m, Vector3.new(1, 0.2, 0.2), CFrame.new(-0.1, 1.2, 0), C.woodDark, Enum.Material.Wood)
	part(m, Vector3.new(0.6, 0.7, 0.6), CFrame.new(0.3, 0.7, 0), Color3.fromRGB(255, 214, 140), Enum.Material.Neon)
	part(m, Vector3.new(0.7, 0.12, 0.7), CFrame.new(0.3, 1.08, 0), Color3.fromRGB(60, 56, 52), Enum.Material.Metal)
	part(m, Vector3.new(0.7, 0.12, 0.7), CFrame.new(0.3, 0.32, 0), Color3.fromRGB(60, 56, 52), Enum.Material.Metal)
	return core
end

function builders.bed(m)
	local core = part(m, Vector3.new(1.4, 0.4, 2.6), CFrame.new(0, -0.2, 0), C.wood, Enum.Material.WoodPlanks)
	part(m, Vector3.new(1.3, 0.3, 2.4), CFrame.new(0, 0.12, 0), Color3.fromRGB(196, 170, 124), Enum.Material.Fabric)
	part(m, Vector3.new(1.32, 0.32, 1.4), CFrame.new(0, 0.16, 0.45), Color3.fromRGB(150, 64, 52), Enum.Material.Fabric)
	part(m, Vector3.new(1, 0.3, 0.55), CFrame.new(0, 0.35, -0.85), Color3.fromRGB(238, 230, 210), Enum.Material.Fabric)
	return core
end

function builders.spike_trap(m)
	local core = part(m, Vector3.new(2.2, 0.2, 2.2), CFrame.new(0, -0.3, 0), C.woodDark, Enum.Material.WoodPlanks)
	for x = -1, 1 do
		for z = -1, 1 do
			part(m, Vector3.new(0.16, 0.8, 0.16), CFrame.new(x * 0.65, 0.15, z * 0.65) * CFrame.Angles(0, math.rad(45), math.rad(x * 6)), Color3.fromRGB(160, 156, 150), Enum.Material.Metal)
		end
	end
	return core
end

function builders.ladder(m)
	local core = part(m, Vector3.new(0.2, 2.6, 0.2), CFrame.new(-0.5, 0, 0), C.wood, Enum.Material.Wood)
	part(m, Vector3.new(0.2, 2.6, 0.2), CFrame.new(0.5, 0, 0), C.wood, Enum.Material.Wood)
	for i = -2, 2 do
		part(m, Vector3.new(1, 0.14, 0.14), CFrame.new(0, i * 0.5, 0), C.woodLight, Enum.Material.Wood)
	end
	return core
end

for _, t in Items.ORE_BUILD do
	builders[t .. "_wall"] = function(m)
		local plate, trim = tierColour(t)
		local mat = tierMaterial(t)
		local core = part(m, Vector3.new(2, 2.2, 0.5), CFrame.new(), plate, mat)
		part(m, Vector3.new(2.15, 0.25, 0.6), CFrame.new(0, 0.95, 0), trim, Enum.Material.Metal)
		part(m, Vector3.new(2.15, 0.25, 0.6), CFrame.new(0, -0.95, 0), trim, Enum.Material.Metal)
		return core
	end
	builders[t .. "_chest"] = function(m)
		local plate, trim = tierColour(t)
		local core = part(m, Vector3.new(2.4, 1.4, 1.6), CFrame.new(), C.woodDark, Enum.Material.WoodPlanks)
		part(m, Vector3.new(2.5, 0.5, 1.7), CFrame.new(0, 0.9, 0), plate, tierMaterial(t))
		for _, x in { -0.8, 0.8 } do
			part(m, Vector3.new(0.22, 1.95, 1.75), CFrame.new(x, 0.25, 0), trim, Enum.Material.Metal)
		end
		part(m, Vector3.new(0.4, 0.45, 0.15), CFrame.new(0, 0.6, -0.85), plate, Enum.Material.Metal)
		return core
	end
end

-- Gates: the wall icon with a door in it. Floors: a slab. Roofs: a little peak.
for _, t in { "stone", table.unpack(Items.ORE_BUILD) } do
	builders[t .. "_gate"] = function(m)
		local plate, trim = tierColour(t)
		local mat = tierMaterial(t)
		local core = part(m, Vector3.new(2, 2.2, 0.45), CFrame.new(), plate, mat)
		local door = if t == "stone" then C.woodDark else plate:Lerp(Color3.new(0, 0, 0), 0.25)
		part(m, Vector3.new(0.9, 1.25, 0.55), CFrame.new(0, -0.48, 0), door, if t == "stone" then Enum.Material.WoodPlanks else mat)
		part(m, Vector3.new(1, 0.14, 0.6), CFrame.new(0, -0.2, 0), trim, Enum.Material.Metal)
		part(m, Vector3.new(0.14, 0.14, 0.62), CFrame.new(0.3, -0.5, 0), Color3.fromRGB(214, 176, 72), Enum.Material.Metal)
		return core
	end
end
for _, t in Items.BUILD_TIERS do
	builders[t .. "_floor"] = function(m)
		local plate, trim = tierColour(t)
		local mat = tierMaterial(t)
		local core = part(m, Vector3.new(2.4, 0.3, 2.4), CFrame.new(), trim, mat)
		for gx = -1, 1, 2 do
			for gz = -1, 1, 2 do
				part(m, Vector3.new(1.1, 0.12, 1.1), CFrame.new(gx * 0.6, 0.18, gz * 0.6), if gx == gz then plate else plate:Lerp(Color3.new(0, 0, 0), 0.15), mat)
			end
		end
		return core
	end
	builders[t .. "_roof"] = function(m)
		local plate, trim = tierColour(t)
		local roof = if t == "wood" then Color3.fromRGB(196, 150, 80) else plate
		local core = part(m, Vector3.new(2.4, 0.2, 2.2), CFrame.new(0, -0.5, 0), trim, tierMaterial(t))
		for sz = -1, 1, 2 do
			local w = part(m, Vector3.new(2.5, 1, 1.15), CFrame.new(0, 0.1, sz * 0.55) * CFrame.Angles(0, if sz > 0 then 0 else math.pi, 0), roof, if t == "wood" then Enum.Material.Grass else tierMaterial(t), Enum.PartType.Wedge)
			_ = w
		end
		part(m, Vector3.new(2.6, 0.16, 0.2), CFrame.new(0, 0.62, 0), trim, Enum.Material.Metal)
		return core
	end
end

for _, t in Items.CARTS do
	builders[t .. "_cart"] = function(m)
		local plate, trim = tierColour(t)
		local core = part(m, Vector3.new(2.2, 1, 1.4), CFrame.new(0, 0.2, 0), C.wood, Enum.Material.WoodPlanks)
		part(m, Vector3.new(2.3, 0.15, 1.5), CFrame.new(0, 0.72, 0), plate, tierMaterial(t))
		for _, x in { -0.7, 0.7 } do
			for _, z in { -0.78, 0.78 } do
				part(m, Vector3.new(0.18, 0.8, 0.8), CFrame.new(x, -0.35, z) * CFrame.Angles(0, math.rad(90), 0), trim, Enum.Material.Metal, Enum.PartType.Cylinder)
			end
		end
		part(m, Vector3.new(1.2, 0.12, 0.12), CFrame.new(1.6, 0.1, 0), C.woodDark, Enum.Material.Wood)
		return core
	end
end

for _, tier in Tiers.list do
	-- A big rounded shield, worn large on the forearm: a wide round top tapering to a
	-- blunt point at the bottom, a thick rim in the tier's material (crystal tiers
	-- get glassy, glowing rims), a planked wooden face that bulges a little, and a
	-- round boss with the tier's accent glowing in it.
	builders[tier.id .. "_shield"] = function(m)
		local wood, woodDark = Color3.fromRGB(150, 98, 52), Color3.fromRGB(104, 66, 36)
		local rimMat = if tier.id == "wood" then Enum.Material.Wood else tierMaterial(tier.id)
		local rimColour = if tier.id == "wood" then woodDark else tier.plate
		local core = part(m, Vector3.new(0.7, 0.34, 0.24), CFrame.new(0, 0, 0.16), woodDark, Enum.Material.Wood) -- the handle at the back
		local ROWS, H, W = 20, 1.3, 1.05 -- half height, half width
		local step = H * 2 / ROWS
		for i = 0, ROWS - 1 do
			local y = -H + (i + 0.5) * step
			local t = y / H
			local half = if t >= 0 then W * math.sqrt(math.max(0, 1 - t * t)) ^ 0.8 else W * (1 - math.abs(t) ^ 1.6) ^ 0.7
			half = math.max(half, 0.12)
			local bulge = 0.08 * (1 - t * t)
			-- The rim, then the wooden face inside it.
			part(m, Vector3.new(half * 2 + 0.3, step + 0.02, 0.22), CFrame.new(0, y, 0), rimColour, rimMat)
			if half > 0.2 then
				part(m, Vector3.new(half * 2 - 0.05, step + 0.02, 0.22 + bulge), CFrame.new(0, y, -0.03 - bulge / 2), if i % 3 == 0 then wood:Lerp(woodDark, 0.2) else wood, Enum.Material.Wood)
			end
		end
		-- Plank lines down the face, and a band across it.
		for _, x in { -0.42, 0, 0.42 } do
			part(m, Vector3.new(0.035, H * 1.5, 0.02), CFrame.new(x, -0.05, -0.2), woodDark, Enum.Material.Wood)
		end
		-- The boss: an iron ring with the tier's accent glowing in the middle.
		part(m, Vector3.new(0.14, 0.8, 0.8), CFrame.new(0, -0.05, -0.2) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(70, 62, 52), Enum.Material.Metal, Enum.PartType.Cylinder)
		local accent = if tier.id == "wood" then Color3.fromRGB(250, 214, 90) else tier.accent
		part(m, Vector3.new(0.46, 0.46, 0.46), CFrame.new(0, -0.05, -0.27), accent, Enum.Material.Neon, Enum.PartType.Ball)
		-- Rivets round the rim.
		for k = 0, 7 do
			local a = k / 8 * math.pi * 2
			local rx, ry = math.cos(a) * (W - 0.05), math.sin(a) * (H - 0.08)
			if ry < 0 then
				rx *= 0.7
			end
			part(m, Vector3.new(0.12, 0.12, 0.06), CFrame.new(rx, ry, -0.13), Color3.fromRGB(80, 72, 60), Enum.Material.Metal)
		end
		-- Same pivot as the old round shield (turned a quarter about Y, at the middle),
		-- so it still straps onto the forearm facing out.
		core.PivotOffset = CFrame.new(0, 0, -0.12) * CFrame.Angles(0, math.rad(90), 0)
		return core
	end
end

-- Bows: a smooth D-shaped arc (the limbs curve forward, away from you) with a
-- leather grip, tips that flick back and a taut string; the hand holds the grip
-- (the core), string towards you (+Z). Crossbows: a stock pointing forward (-Z)
-- with the limbs across the front, a string pulled back to the latch, a trigger
-- under the grip, and a bolt loaded on top.
local function arcLimbs(m: Model, plate: Color3, trim: Color3, mat: Enum.Material, half: number, depth: number, axis: string, z0: number)
	-- An arc through the middle (0, 0) and the tips (+-half, depth), split into short
	-- segments, each turned along the curve. axis "y" bends a bow, "x" a crossbow.
	local r = (half * half + depth * depth) / (2 * depth)
	local theta = math.asin(half / r)
	local n = 10
	local tips = {}
	for i = 0, n - 1 do
		local a0 = -theta + (2 * theta) * i / n
		local a1 = -theta + (2 * theta) * (i + 1) / n
		local p0 = Vector2.new(r * math.sin(a0), r - r * math.cos(a0))
		local p1 = Vector2.new(r * math.sin(a1), r - r * math.cos(a1))
		local mid = (p0 + p1) / 2
		local len = (p1 - p0).Magnitude + 0.04
		local thick = 0.17 * (1 - math.abs(mid.X) / half * 0.35)
		local colour = if math.abs(mid.X) > half * 0.8 then trim else plate
		local cf
		if axis == "y" then
			cf = CFrame.lookAt(Vector3.new(0, mid.X, z0 + mid.Y), Vector3.new(0, p1.X, z0 + p1.Y)) * CFrame.Angles(math.rad(90), 0, 0)
			part(m, Vector3.new(thick, len, thick * 1.3), cf, colour, mat)
		else
			cf = CFrame.lookAt(Vector3.new(mid.X, 0, z0 + mid.Y), Vector3.new(p1.X, 0, z0 + p1.Y)) * CFrame.Angles(math.rad(90), 0, 0)
			part(m, Vector3.new(thick * 1.3, len, thick), cf, colour, mat)
		end
		if i == 0 then
			tips[1] = p0
		elseif i == n - 1 then
			tips[2] = p1
		end
	end
	return tips
end

for t, spec in Items.BOWS do
	local tier = Tiers.get(t) :: any
	local cross = tier and tier.rank >= Items.CROSSBOW_FROM
	local id = t .. (if cross then "_crossbow" else "_bow")
	builders[id] = function(m)
		local plate, trim = tierColour(t)
		local mat = if t == "wood" then Enum.Material.Wood else tierMaterial(t)
		local str = Color3.fromRGB(236, 230, 214)
		if not cross then
			local core = part(m, Vector3.new(0.24, 0.62, 0.3), CFrame.new(), C.leather, Enum.Material.Fabric)
			local half, depth = 1.35, 0.62
			local tips = arcLimbs(m, plate, trim, mat, half, depth, "y", 0)
			-- Tips flick back towards you, and the string runs tip to tip behind the grip.
			for _, tip in tips do
				part(m, Vector3.new(0.12, 0.32, 0.12), CFrame.new(0, tip.X + math.sign(tip.X) * 0.08, tip.Y + 0.1) * CFrame.Angles(math.rad(-35 * math.sign(tip.X)), 0, 0), trim, mat)
			end
			part(m, Vector3.new(0.035, half * 2 - 0.05, 0.035), CFrame.new(0, 0, depth + 0.1), str, Enum.Material.Fabric)
			if tier and tier.glow then
				part(m, Vector3.new(0.27, 0.12, 0.33), CFrame.new(0, 0.2, 0), tier.accent, Enum.Material.Neon)
				part(m, Vector3.new(0.27, 0.12, 0.33), CFrame.new(0, -0.2, 0), tier.accent, Enum.Material.Neon)
			end
			return core
		end
		-- Crossbow
		local core = part(m, Vector3.new(0.26, 0.7, 0.34), CFrame.new(0, -0.3, 0.25) * CFrame.Angles(math.rad(-18), 0, 0), C.woodDark, Enum.Material.Wood)
		part(m, Vector3.new(0.3, 0.3, 2.4), CFrame.new(0, 0.1, -0.35), C.wood, Enum.Material.Wood)
		part(m, Vector3.new(0.34, 0.42, 0.7), CFrame.new(0, 0.02, 1.1), C.woodDark, Enum.Material.Wood)
		part(m, Vector3.new(0.34, 0.12, 2.0), CFrame.new(0, 0.3, -0.45), plate, mat)
		part(m, Vector3.new(0.06, 0.24, 0.12), CFrame.new(0, -0.12, 0.28), trim, Enum.Material.Metal)
		local half, depth = 1.15, 0.38
		local z0 = -1.55
		local tips = arcLimbs(m, plate, trim, mat, half, depth, "x", z0)
		part(m, Vector3.new(0.4, 0.36, 0.3), CFrame.new(0, 0.12, z0 + 0.05), trim, Enum.Material.Metal)
		-- String from each tip back to the latch.
		local latch = Vector3.new(0, 0.32, 0.05)
		for _, tip in tips do
			local a = Vector3.new(tip.X, 0.05, z0 + tip.Y)
			local d = (latch - a).Magnitude
			part(m, Vector3.new(0.035, 0.035, d), CFrame.lookAt((a + latch) / 2, latch), str, Enum.Material.Fabric)
		end
		-- The loaded bolt.
		part(m, Vector3.new(0.07, 0.07, 1.7), CFrame.new(0, 0.42, -0.75), C.woodLight, Enum.Material.Wood)
		part(m, Vector3.new(0.14, 0.14, 0.26), CFrame.new(0, 0.42, -1.65), if tier and tier.glow then tier.accent else trim, if tier and tier.glow then Enum.Material.Neon else Enum.Material.Metal)
		if tier and tier.glow then
			part(m, Vector3.new(0.36, 0.06, 1.6), CFrame.new(0, 0.37, -0.45), tier.accent, Enum.Material.Neon)
		end
		return core
	end
end

function builders.arrow(m)
	local core = part(m, Vector3.new(0.1, 2, 0.1), CFrame.new(), C.woodLight, Enum.Material.Wood)
	part(m, Vector3.new(0.22, 0.3, 0.22), CFrame.new(0, 1.1, 0), C.stoneDark, Enum.Material.Slate)
	part(m, Vector3.new(0.02, 0.4, 0.3), CFrame.new(0, -0.8, 0), Color3.fromRGB(236, 232, 224), Enum.Material.Fabric)
	part(m, Vector3.new(0.3, 0.4, 0.02), CFrame.new(0, -0.8, 0), Color3.fromRGB(196, 72, 56), Enum.Material.Fabric)
	return core
end

local function raftLogs(m: Model, n: number, color: Color3): BasePart
	local core
	for i = 1, n do
		local x = (i - (n + 1) / 2) * 0.45
		local p = part(m, Vector3.new(2.6, 0.44, 0.44), CFrame.new(0, 0, x), color:Lerp(Color3.new(0, 0, 0), (i % 2) * 0.08), Enum.Material.Wood, Enum.PartType.Cylinder)
		core = core or p
	end
	part(m, Vector3.new(0.2, 0.2, n * 0.45 + 0.1), CFrame.new(-0.9, 0.18, 0), C.leather, Enum.Material.Fabric)
	part(m, Vector3.new(0.2, 0.2, n * 0.45 + 0.1), CFrame.new(0.9, 0.18, 0), C.leather, Enum.Material.Fabric)
	return core
end

function builders.log_raft(m)
	return raftLogs(m, 5, C.wood)
end

function builders.sail_raft(m)
	local core = raftLogs(m, 5, C.woodLight)
	part(m, Vector3.new(0.15, 2.4, 0.15), CFrame.new(0, 1.2, 0), C.woodDark, Enum.Material.Wood)
	part(m, Vector3.new(0.05, 1.6, 1.5), CFrame.new(0.1, 1.4, 0), Color3.fromRGB(238, 228, 200), Enum.Material.Fabric)
	return core
end

function builders.gold_raft(m)
	local core = raftLogs(m, 6, C.woodDark)
	part(m, Vector3.new(2.7, 0.12, 0.12), CFrame.new(0, 0.26, -1.4), Color3.fromRGB(236, 192, 72), Enum.Material.Metal)
	part(m, Vector3.new(2.7, 0.12, 0.12), CFrame.new(0, 0.26, 1.4), Color3.fromRGB(236, 192, 72), Enum.Material.Metal)
	part(m, Vector3.new(0.15, 2.6, 0.15), CFrame.new(0, 1.3, 0), C.woodDark, Enum.Material.Wood)
	part(m, Vector3.new(0.05, 1.7, 1.7), CFrame.new(0.1, 1.5, 0), Color3.fromRGB(176, 52, 48), Enum.Material.Fabric)
	return core
end

-- Public -------------------------------------------------------------------------

-- Returns a new Model for the item, with PrimaryPart set. Every part is anchored,
-- non-colliding and massless; callers change that if they need physics.
function ItemModels.build(itemId: string): Model
	local spec = ITEM_MESHES[itemId]
	local mesh = ArmourModels.build(itemId)
		or tierTool(itemId)
		or (spec and Meshes.build(spec.mesh, { centre = not spec.tool, collide = false, scale = spec.scale }))
	if mesh then
		mesh.Name = itemId
		for _, p in mesh:GetChildren() do
			local part = p :: BasePart
			part.CanQuery = false
			part.Massless = true
		end
		return mesh
	end

	local model = Instance.new("Model")
	model.Name = itemId
	local builder = builders[itemId]
	local primary
	if builder then
		primary = builder(model)
	else
		primary = part(model, Vector3.new(1, 1, 1), CFrame.new(), Color3.fromRGB(200, 0, 200))
	end
	model.PrimaryPart = primary
	-- Make the model's pivot the origin it was built around (the grip for tools).
	primary.PivotOffset = primary.CFrame:Inverse()
	return model
end

function ItemModels.isTool(itemId: string): boolean
	local item = Items[itemId]
	return item ~= nil and item.kind == "tool"
end

return ItemModels
