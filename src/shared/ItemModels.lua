-- Builds a small 3D model for every item. The same model is used for
-- items dropped on the ground, the tool in your hand, and the icons in the UI.
--
-- Tools are built standing up: the grip is at the origin and the tool points along +Y.
-- Everything else is built centred on the origin.

local ItemModels = {}

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

local function club(m: Model, headColor: Color3, headMaterial: Enum.Material, spikes: boolean): BasePart
	local handle = part(m, Vector3.new(0.35, 2.6, 0.35), CFrame.new(0, 1.1, 0), C.woodDark, Enum.Material.Wood)
	local head = part(m, Vector3.new(0.75, 1.4, 0.75), CFrame.new(0, 2.6, 0) * CFrame.Angles(0, math.rad(45), 0), headColor, headMaterial)
	part(m, Vector3.new(0.6, 0.6, 0.6), CFrame.new(0, 3.35, 0) * CFrame.Angles(0, math.rad(45), 0), headColor:Lerp(Color3.new(0, 0, 0), 0.1), headMaterial)
	if spikes then
		for i = 0, 3 do
			part(m, Vector3.new(0.25, 0.25, 0.5), head.CFrame * CFrame.Angles(0, i * math.pi / 2, 0) * CFrame.new(0, 0.1, -0.5), C.stoneDark, Enum.Material.Slate)
		end
	end
	return handle
end

function builders.wood_club(m)
	return club(m, C.wood, Enum.Material.Wood, false)
end

function builders.stone_club(m)
	return club(m, C.stone, Enum.Material.Slate, true)
end

local function harvester(m: Model, headColor: Color3, headMaterial: Enum.Material): BasePart
	local handle = part(m, Vector3.new(0.3, 3, 0.3), CFrame.new(0, 1.3, 0), C.woodDark, Enum.Material.Wood)
	-- A pick head on one side and an axe blade on the other.
	part(m, Vector3.new(0.4, 0.4, 0.6), CFrame.new(0, 2.7, 0), headColor, headMaterial)
	part(m, Vector3.new(0.25, 0.35, 1.3), CFrame.new(0, 2.6, -0.85) * CFrame.Angles(math.rad(-15), 0, 0), headColor, headMaterial)
	part(m, Vector3.new(0.18, 1, 0.9), CFrame.new(0, 2.6, 0.7), headColor, headMaterial)
	return handle
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

function builders.wood_helmet(m)
	local core = part(m, Vector3.new(1.5, 0.9, 1.5), CFrame.new(), C.wood, Enum.Material.WoodPlanks)
	part(m, Vector3.new(1.7, 0.2, 1.7), CFrame.new(0, -0.4, 0), C.woodDark, Enum.Material.Wood)
	return core
end

function builders.wood_body(m)
	local core = part(m, Vector3.new(2.1, 2.1, 1.1), CFrame.new(), C.wood, Enum.Material.WoodPlanks)
	part(m, Vector3.new(2.2, 0.25, 1.2), CFrame.new(0, -0.7, 0), C.woodDark, Enum.Material.Wood)
	return core
end

function builders.wood_legs(m)
	local core = part(m, Vector3.new(0.9, 1.8, 0.9), CFrame.new(-0.5, 0, 0), C.wood, Enum.Material.WoodPlanks)
	part(m, Vector3.new(0.9, 1.8, 0.9), CFrame.new(0.5, 0, 0), C.wood, Enum.Material.WoodPlanks)
	return core
end

function builders.wood_boots(m)
	local core = part(m, Vector3.new(0.9, 0.6, 1.2), CFrame.new(-0.5, 0, 0), C.woodDark, Enum.Material.Wood)
	part(m, Vector3.new(0.9, 0.6, 1.2), CFrame.new(0.5, 0, 0), C.woodDark, Enum.Material.Wood)
	return core
end

function builders.leather_bag(m)
	local core = part(m, Vector3.new(1.6, 1.8, 0.8), CFrame.new(), C.leather, Enum.Material.Fabric)
	part(m, Vector3.new(1.7, 0.5, 0.9), CFrame.new(0, 0.75, 0), C.leather:Lerp(Color3.new(0, 0, 0), 0.2), Enum.Material.Fabric)
	part(m, Vector3.new(0.3, 0.3, 0.1), CFrame.new(0, 0.4, -0.45), Color3.fromRGB(200, 170, 90), Enum.Material.Metal)
	return core
end

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

function builders.wood_door(m)
	local core = part(m, Vector3.new(1.3, 2.2, 0.25), CFrame.new(), C.woodDark, Enum.Material.Wood)
	part(m, Vector3.new(0.15, 0.15, 0.35), CFrame.new(0.45, 0, 0), Color3.fromRGB(60, 45, 30))
	return core
end

-- Public -------------------------------------------------------------------------

-- Returns a new Model for the item, with PrimaryPart set. Every part is anchored,
-- non-colliding and massless; callers change that if they need physics.
function ItemModels.build(itemId: string): Model
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
	return builders[itemId] ~= nil and (itemId == "rock" or itemId:find("_club") ~= nil or itemId:find("_harvester") ~= nil)
end

return ItemModels
