-- Material tiers for armour and tools, weakest first. Each tier uses one of four model
-- styles (see assets/models/blender/set3.py) and recolours it by part role:
--   Plate (main armour / blade), Trim (bands, rivets, guards), Accent (gems, plumes,
--   horns), Strap (leather). Handle parts keep their wood colour.
-- glow: the Accent parts are Neon.

export type Tier = {
	id: string,
	name: string,
	rank: number,
	style: "wood" | "stone" | "metal" | "crystal",
	plate: Color3,
	trim: Color3,
	accent: Color3,
	strap: Color3,
	glow: boolean,
}

local rgb = Color3.fromRGB

local LIST: { Tier } = {
	{ id = "wood", name = "Wood", style = "wood", plate = rgb(150, 108, 66), trim = rgb(196, 170, 118), accent = rgb(96, 132, 58), strap = rgb(92, 62, 40), glow = false },
	{ id = "stone", name = "Stone", style = "stone", plate = rgb(128, 126, 122), trim = rgb(110, 72, 44), accent = rgb(232, 222, 196), strap = rgb(96, 62, 40), glow = false },
	{ id = "silver", name = "Silver", style = "metal", plate = rgb(206, 210, 218), trim = rgb(120, 124, 134), accent = rgb(70, 120, 210), strap = rgb(88, 58, 38), glow = false },
	{ id = "gold", name = "Gold", style = "metal", plate = rgb(236, 192, 72), trim = rgb(150, 104, 40), accent = rgb(200, 40, 48), strap = rgb(88, 58, 38), glow = false },
	{ id = "sunsteel", name = "Sunsteel", style = "metal", plate = rgb(186, 44, 40), trim = rgb(240, 180, 60), accent = rgb(255, 150, 40), strap = rgb(60, 36, 30), glow = true },
	{ id = "diamond", name = "Diamond", style = "crystal", plate = rgb(170, 236, 240), trim = rgb(60, 70, 86), accent = rgb(230, 252, 255), strap = rgb(52, 44, 52), glow = false },
	{ id = "amethyst", name = "Amethyst", style = "crystal", plate = rgb(150, 80, 220), trim = rgb(50, 34, 70), accent = rgb(230, 180, 255), strap = rgb(44, 36, 52), glow = true },
	-- Obsidian: dark navy-charcoal plates with hot orange inlays.
	{ id = "obsidian", name = "Obsidian", style = "crystal", plate = rgb(36, 44, 58), trim = rgb(22, 26, 36), accent = rgb(255, 104, 36), strap = rgb(26, 28, 36), glow = true },
	-- Lunar: clean teal crystal with pale moon-yellow inlays.
	{ id = "lunar", name = "Lunar", style = "crystal", plate = rgb(34, 150, 146), trim = rgb(18, 98, 100), accent = rgb(250, 240, 150), strap = rgb(20, 70, 72), glow = true },
	-- Tidecaller (Mythic): deep sea blue and gold with glowing foam-green inlays. Made
	-- only from the Mythic crate materials (Star Shard, Abyss Pearl, Ancient Rune).
	{ id = "tidecaller", name = "Tidecaller", style = "metal", plate = rgb(28, 64, 150), trim = rgb(232, 190, 80), accent = rgb(120, 255, 220), strap = rgb(30, 34, 60), glow = true, mythic = true },
} :: any

local Tiers = { list = LIST }
-- Side sets that aren't part of the tool ladder (no sword or harvester): armour only.
-- They're found by Tiers.get / Tiers.split but never appear in Tiers.list.
local EXTRA = {
	{ id = "slime", name = "Slime", style = "wood", plate = rgb(122, 200, 88), trim = rgb(70, 130, 52), accent = rgb(200, 255, 150), strap = rgb(60, 96, 40), glow = false, rank = 3 },
}
Tiers.extra = EXTRA
local byId: { [string]: Tier } = {}
for i, t in LIST do
	t.rank = i
	byId[t.id] = t
end
for _, t in EXTRA do
	byId[t.id] = t :: any
end

function Tiers.get(id: string): Tier?
	return byId[id]
end

-- "gold_helmet" -> gold tier, "helmet"
function Tiers.split(itemId: string): (Tier?, string?)
	local id, rest = itemId:match("^(%a+)_(.+)$")
	if id and byId[id] then
		return byId[id], rest
	end
	return nil, nil
end

local PLATE_MATERIAL = {
	wood = Enum.Material.Wood,
	stone = Enum.Material.Slate,
	metal = Enum.Material.Metal,
	crystal = Enum.Material.Glass,
}

-- Colours every part of a built model by its role.
function Tiers.paint(model: Model, tier: Tier)
	for _, d in model:GetDescendants() do
		if not d:IsA("BasePart") then
			continue
		end
		local role = d.Name
		if role == "Plate" then
			d.Color = tier.plate
			d.Material = PLATE_MATERIAL[tier.style]
			-- Metal and crystal catch the light (Island Tribes-style shine).
			d.Reflectance = if tier.style == "crystal" then 0.35 elseif tier.style == "metal" then 0.28 else 0
		elseif role == "Trim" then
			d.Color = tier.trim
			d.Material = if tier.style == "wood" then Enum.Material.Fabric
				elseif tier.style == "stone" then Enum.Material.Leather
				else Enum.Material.Metal
			d.Reflectance = if tier.style == "metal" or tier.style == "crystal" then 0.2 else 0
		elseif role == "Accent" then
			d.Color = tier.accent
			d.Material = if tier.glow then Enum.Material.Neon else Enum.Material.SmoothPlastic
		elseif role == "Strap" then
			d.Color = tier.strap
			d.Material = Enum.Material.Leather
		elseif role == "Handle" then
			d.Material = Enum.Material.Wood
		end
	end
end

return Tiers
