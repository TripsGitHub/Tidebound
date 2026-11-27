-- Every item in the game. To add an item, copy an entry and change it.
-- kind:
--   "tool"      held in your hand: gathers, fights, and breaks structures
--   "armour"    worn in a slot (head, body, legs, feet, bag)
--   "food"      eat it
--   "placeable" build it
--   "resource"  crafting material
-- gather: how much each hit gathers from each material (missing = can't)
-- damage: damage to players, animals and structures
-- defense: armour damage reduction (0.05 = 5%)
-- bagSize: for bags, how many items you can carry
-- swing: "slash" for weapons (a sideways sweep); tools without it chop overhead

local Items = {
	-- Tools ------------------------------------------------------------
	rock = { name = "Rock", kind = "tool", order = 1, gather = { wood = 1, stone = 1, plant = 1, slime = 1 }, cooldown = 0.55, damage = 6 },
	wood_club = { name = "Wooden Club", kind = "tool", order = 2, swing = "slash", gather = { wood = 1, plant = 1 }, cooldown = 0.6, damage = 14 },
	wood_harvester = { name = "Wooden Harvester", kind = "tool", order = 3, gather = { wood = 2, stone = 2, plant = 2, slime = 1 }, cooldown = 0.55, damage = 8 },
	stone_sword = { name = "Stone Sword", kind = "tool", order = 4, swing = "slash", gather = { wood = 1, plant = 1 }, cooldown = 0.65, damage = 22 },
	stone_harvester = { name = "Stone Harvester", kind = "tool", order = 5, gather = { wood = 3, stone = 3, plant = 2, slime = 2 }, cooldown = 0.55, damage = 11 },

	-- Armour -----------------------------------------------------------
	wood_helmet = { name = "Wood Helmet", kind = "armour", slot = "head", order = 40, defense = 0.03 },
	wood_body = { name = "Wood Chestplate", kind = "armour", slot = "body", order = 41, defense = 0.05 },
	wood_legs = { name = "Wood Leggings", kind = "armour", slot = "legs", order = 42, defense = 0.04 },
	wood_boots = { name = "Wood Boots", kind = "armour", slot = "feet", order = 43, defense = 0.02 },
	leather_bag = { name = "Leather Bag", kind = "armour", slot = "bag", order = 45, bagSize = 80 },
	hide_pack = { name = "Hide Pack", kind = "armour", slot = "bag", order = 45.1, bagSize = 120 },
	explorer_pack = { name = "Explorer Pack", kind = "armour", slot = "bag", order = 45.2, bagSize = 160 },

	-- Food -------------------------------------------------------------
	berries = { name = "Berries", kind = "food", order = 20, hunger = 8 },
	coconut = { name = "Coconut", kind = "food", order = 21, hunger = 14 },
	raw_meat = { name = "Raw Meat", kind = "food", order = 22, hunger = 5, hurt = 5 },
	cooked_meat = { name = "Cooked Meat", kind = "food", order = 23, hunger = 35, heal = 15 },

	-- Buildables -------------------------------------------------------
	campfire = { name = "Campfire", kind = "placeable", order = 30, structure = "Campfire" },
	wood_base = { name = "Wood Base", kind = "placeable", order = 31, structure = "WoodBase" },
	wood_wall = { name = "Wood Wall", kind = "placeable", order = 32, structure = "WoodWall" },
	wood_gate = { name = "Wood Gate", kind = "placeable", order = 33, structure = "WoodGate" },
	stone_base = { name = "Stone Base", kind = "placeable", order = 34, structure = "StoneBase" },
	stone_wall = { name = "Stone Wall", kind = "placeable", order = 35, structure = "StoneWall" },

	-- Resources --------------------------------------------------------
	log = { name = "Small Log", kind = "resource", order = 100 },
	stick = { name = "Stick", kind = "resource", order = 101 },
	leaves = { name = "Leaves", kind = "resource", order = 102 },
	stone = { name = "Small Rock", kind = "resource", order = 103 },
	sticky_slime = { name = "Sticky Slime", kind = "resource", order = 104 },
	leather = { name = "Leather", kind = "resource", order = 105 },
}

-- Ores and crystals (see Ores.lua), one per tier from Silver up.
for i, ore in require(script.Parent.Ores) do
	Items[ore.item] = { name = ore.name, kind = "resource", order = 110 + i }
end

-- Tiered gear ------------------------------------------------------------
-- Every tier in Tiers.lua gets a helmet, chestplate, leggings, boots, sword and harvester.
-- Entries written out above keep their stats; the rest scale with the tier's rank.
-- Their recipes are generated in Recipes.lua.
local Tiers = require(script.Parent.Tiers)

local ARMOUR = {
	{ key = "helmet", slot = "head", label = "Helmet", share = 3 },
	{ key = "body", slot = "body", label = "Chestplate", share = 5 },
	{ key = "legs", slot = "legs", label = "Leggings", share = 4 },
	{ key = "boots", slot = "feet", label = "Boots", share = 2 },
}

local function round(x: number): number
	return math.floor(x * 1000 + 0.5) / 1000
end

for _, tier in Tiers.list do
	local r = tier.rank
	-- Defence for the full set: 14% for wood, +5% per tier (59% for lunar).
	local total = 0.14 + 0.05 * (r - 1)
	for i, piece in ARMOUR do
		local id = tier.id .. "_" .. piece.key
		local item = Items[id] or {
			name = tier.name .. " " .. piece.label,
			kind = "armour",
			slot = piece.slot,
			defense = round(total * piece.share / 14),
		}
		item.order = 40 + r * 0.1 + i * 0.01
		Items[id] = item
	end

	local sword = tier.id .. "_sword"
	Items[sword] = Items[sword] or {
		name = tier.name .. " Sword",
		kind = "tool",
		swing = "slash",
		gather = { wood = 1, plant = 1 },
		cooldown = 0.65,
		damage = if r == 1 then 16 else 22 + 7 * (r - 2),
	}
	Items[sword].order = 3 + r * 0.1 + 0.01

	local harvester = tier.id .. "_harvester"
	Items[harvester] = Items[harvester] or {
		name = tier.name .. " Harvester",
		kind = "tool",
		gather = { wood = r + 1, stone = r + 1, plant = math.max(2, r), slime = r },
		cooldown = 0.55,
		damage = 8 + 3 * (r - 1),
	}
	Items[harvester].order = 3 + r * 0.1 + 0.02
end

return Items
