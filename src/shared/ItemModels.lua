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
	berries = { mesh = "berries", scale = 1.4 },
	coconut = { mesh = "coconut", scale = 1.3 },
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
	fractite = Color3.fromRGB(64, 226, 236),
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

function builders.berries(m)
	local core
	for i, offset in { Vector3.new(0, 0, 0), Vector3.new(0.3, 0.05, 0.1), Vector3.new(-0.2, 0.05, 0.25), Vector3.new(0.05, 0.3, 0.1) } do
		local b = part(m, Vector3.new(0.4, 0.4, 0.4), CFrame.new(offset), C.berry, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		if i == 1 then
			core = b
		end
	end
	return core
end

function builders.sunfruit(m)
	local fruit = part(m, Vector3.new(1.1, 1.25, 1.1), CFrame.new(), Color3.fromRGB(255, 150, 40), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	part(m, Vector3.new(0.6, 0.12, 0.3), CFrame.new(0.2, 0.68, 0) * CFrame.Angles(0, 0, 0.4), Color3.fromRGB(90, 160, 60), Enum.Material.SmoothPlastic)
	return fruit
end

function builders.coconut(m)
	return part(m, Vector3.new(1, 1, 1), CFrame.new(), C.coconut, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
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

function builders.leather_bag(m)
	local core = part(m, Vector3.new(1.6, 1.8, 0.8), CFrame.new(), C.leather, Enum.Material.Fabric)
	part(m, Vector3.new(1.7, 0.5, 0.9), CFrame.new(0, 0.75, 0), C.leather:Lerp(Color3.new(0, 0, 0), 0.2), Enum.Material.Fabric)
	part(m, Vector3.new(0.3, 0.3, 0.1), CFrame.new(0, 0.4, -0.45), Color3.fromRGB(200, 170, 90), Enum.Material.Metal)
	return core
end

builders.hide_pack = builders.leather_bag
builders.explorer_pack = builders.leather_bag

-- Buildable icons ----------------------------------------------------------------

function builders.campfire(m)
	local core = part(m, Vector3.new(0.4, 0.4, 2), CFrame.Angles(0, 0, math.rad(10)), C.woodDark, Enum.Material.Wood)
	part(m, Vector3.new(0.4, 0.4, 2), CFrame.Angles(0, math.rad(60), 0), C.woodDark, Enum.Material.Wood)
	part(m, Vector3.new(0.4, 0.4, 2), CFrame.Angles(0, math.rad(-60), 0), C.woodDark, Enum.Material.Wood)
	part(m, Vector3.new(0.7, 0.9, 0.7), CFrame.new(0, 0.5, 0), Color3.fromRGB(255, 150, 50), Enum.Material.Neon)
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
