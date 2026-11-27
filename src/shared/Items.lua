-- Every item in the game. To add an item, copy an entry and change it.
-- kind:
--   "tool"      held in your hand: gathers, fights, and breaks structures
--   "armour"    worn in a slot (head, body, legs, feet, bag)
--   "food"      eat it
--   "placeable" build it
--   "raft"      put it in the water and ride it
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
	-- Diving gear: worn on the head, adds seconds of air under water.
	aqua_mask = { name = "Diving Mask", kind = "armour", slot = "head", order = 44, defense = 0.02, air = 30 },
	pearl_helm = { name = "Pearl Diving Helm", kind = "armour", slot = "head", order = 44.1, defense = 0.06, air = 75 },
	explorer_pack = { name = "Explorer Pack", kind = "armour", slot = "bag", order = 45.2, bagSize = 160 },

	-- Food -------------------------------------------------------------
	berries = { name = "Berries", kind = "food", order = 20, hunger = 8 },
	coconut = { name = "Coconut", kind = "food", order = 21, hunger = 14 },
	sunfruit = { name = "Sunfruit", kind = "food", order = 21.5, hunger = 18, heal = 6 },
	raw_meat = { name = "Raw Meat", kind = "food", order = 22, hunger = 5, hurt = 5 },
	cooked_meat = { name = "Cooked Meat", kind = "food", order = 23, hunger = 35, heal = 15 },

	-- Buildables -------------------------------------------------------
	campfire = { name = "Campfire", kind = "placeable", order = 30, structure = "Campfire" },
	wood_base = { name = "Wooden Base", kind = "placeable", order = 31, structure = "WoodBase" },
	wood_wall = { name = "Wood Wall", kind = "placeable", order = 32, structure = "WoodWall" },
	wood_gate = { name = "Wood Gate", kind = "placeable", order = 33, structure = "WoodGate" },
	stone_base = { name = "Stone Base", kind = "placeable", order = 34, structure = "StoneBase" },
	stone_wall = { name = "Stone Wall", kind = "placeable", order = 35, structure = "StoneWall" },
	large_stone_base = { name = "Large Stone Base", kind = "placeable", order = 34.5, structure = "LargeStoneBase" },
	storage_chest = { name = "Storage Chest", kind = "placeable", order = 36, structure = "Chest" },

	-- Resources --------------------------------------------------------
	log = { name = "Small Log", kind = "resource", order = 100 },
	stick = { name = "Stick", kind = "resource", order = 101 },
	leaves = { name = "Leaves", kind = "resource", order = 102 },
	stone = { name = "Small Rock", kind = "resource", order = 103 },
	sticky_slime = { name = "Sticky Slime", kind = "resource", order = 104 },
	leather = { name = "Leather", kind = "resource", order = 105 },
}

-- Cave loot -----------------------------------------------------------------------
-- Key Fragments drop from deep cave creatures and bosses; three make a Maw Key, which
-- opens one boss gate. Supply Crates drop rarely from creatures: open one for a
-- random haul. Boss parts drop from nothing else, and make the best gear in the game.
Items.key_fragment = { name = "Key Fragment", kind = "resource", order = 130 }
Items.maw_key = { name = "Maw Key", kind = "resource", order = 131 }
Items.supply_crate = { name = "Supply Crate", kind = "crate", order = 132 }
Items.queen_fang = { name = "Queen's Fang", kind = "resource", order = 133 }
Items.warden_core = { name = "Warden Core", kind = "resource", order = 134 }
Items.golem_heart = { name = "Golem Heart", kind = "resource", order = 135 }
Items.fang_blade = { name = "Fang Blade", kind = "tool", swing = "slash", order = 4.9, gather = { wood = 2, plant = 2 }, cooldown = 0.55, damage = 110 }
Items.golem_harvester = { name = "Golem Harvester", kind = "tool", order = 4.95, gather = { wood = 12, stone = 12, plant = 10, slime = 10 }, cooldown = 0.5, damage = 40 }
Items.warden_pack = { name = "Warden Pack", kind = "armour", slot = "bag", order = 45.9, bagSize = 1000 }

-- What a Supply Crate can hold: { item, min, max, weight }.
Items.CRATE_LOOT = {
	{ "log", 8, 16, 10 },
	{ "stone", 8, 16, 10 },
	{ "leather", 3, 6, 8 },
	{ "sticky_slime", 3, 6, 6 },
	{ "cooked_meat", 2, 4, 6 },
	{ "silver_ore", 2, 5, 6 },
	{ "gold_ore", 2, 4, 4 },
	{ "sunstone", 1, 3, 2.5 },
	{ "key_fragment", 1, 2, 4 },
	{ "diamond", 1, 2, 0.8 },
	{ "fractite", 1, 1, 0.3 },
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

-- How well each set stands up to mobs and to other players (multipliers on its
-- defence). Slime soaks up beasts but does little against a blade in a player's hand;
-- obsidian is strong against both and best of all against players.
Items.ARMOUR_VS = {
	wood = { mob = 1.0, player = 0.9 },
	stone = { mob = 1.1, player = 0.9 },
	silver = { mob = 1.0, player = 1.05 },
	gold = { mob = 0.9, player = 1.1 },
	sunsteel = { mob = 1.15, player = 0.95 },
	diamond = { mob = 1.05, player = 1.05 },
	fractite = { mob = 1.2, player = 0.9 },
	amethyst = { mob = 0.95, player = 1.2 },
	obsidian = { mob = 1.2, player = 1.4 },
	lunar = { mob = 1.15, player = 1.15 },
	slime = { mob = 1.8, player = 0.45 },
}
for _, tier in Tiers.extra do
	for i, piece in ARMOUR do
		Items[tier.id .. "_" .. piece.key] = {
			name = tier.name .. " " .. piece.label,
			kind = "armour",
			slot = piece.slot,
			defense = round(0.22 * piece.share / 14),
			order = 40 + tier.rank * 0.1 + 0.05 + i * 0.01,
		}
	end
end

-- Bars: raw metal ore smelted in a campfire (Smelting.lua). Metal gear is made from
-- bars, not raw ore.
Items.silver_bar = { name = "Silver Bar", kind = "resource", order = 61.1, description = "Silver Ore smelted in a campfire. Used for Silver gear." }
Items.gold_bar = { name = "Gold Bar", kind = "resource", order = 61.2, description = "Gold Ore smelted in a campfire. Used for Gold gear." }
Items.sunsteel_bar = { name = "Sunsteel Bar", kind = "resource", order = 61.3, description = "Sunstone smelted in a campfire. Used for Sunsteel gear." }
Items.BAR_FOR = { silver_ore = "silver_bar", gold_ore = "gold_bar", sunstone = "sunsteel_bar" }

-- Round 7 gear ---------------------------------------------------------------------
-- Lights, beds, traps and ladders for your base.
Items.torch = { name = "Torch", kind = "placeable", order = 37, structure = "Torch", description = "A tall torch on a stake. Lights up your base at night." }
Items.lamp = { name = "Lantern Post", kind = "placeable", order = 37.1, structure = "Lamp", description = "A glass lantern hung on a post: a bigger, steadier light than a torch." }
Items.bed = { name = "Bed", kind = "placeable", order = 37.2, structure = "Bed", description = "Sleep here once and you'll wake up here when you die." }
Items.spike_trap = { name = "Spike Trap", kind = "placeable", order = 37.3, structure = "SpikeTrap", description = "Hidden spikes that hurt anyone but you (and your tribe) who steps on them, beasts included." }
Items.ladder = { name = "Ladder", kind = "placeable", order = 37.4, structure = "Ladder", description = "Climb up walls and cliffs." }

-- Walls and chests made from each ore, tougher (and roomier) the rarer the ore.
Items.ORE_BUILD = {}
for _, tier in Tiers.list do
	if tier.rank >= 3 then
		local wall, chest = tier.id .. "_wall", tier.id .. "_chest"
		Items[wall] = { name = tier.name .. " Wall", kind = "placeable", order = 35 + tier.rank * 0.01, structure = (tier.name:gsub("%s", "")) .. "Wall", tier = tier.id, description = "A wall of " .. tier.name .. ". Much harder to break than stone." }
		Items[chest] = { name = tier.name .. " Chest", kind = "placeable", order = 36 + tier.rank * 0.01, structure = (tier.name:gsub("%s", "")) .. "Chest", tier = tier.id, description = "A " .. tier.name .. "-bound chest: holds more and takes a beating." }
		table.insert(Items.ORE_BUILD, tier.id)
	end
end
-- Carts: storage on wheels, from wood up to gold.
Items.CARTS = { "wood", "stone", "silver", "gold" }
for i, t in Items.CARTS do
	local tier = Tiers.get(t) :: any
	Items[t .. "_cart"] = { name = tier.name .. " Cart", kind = "placeable", order = 36.5 + i * 0.01, structure = tier.name .. "Cart", tier = t, description = "A cart to keep things in. Better carts hold more." }
end

-- Shields: worn on the off arm, one for every tool tier.
for _, tier in Tiers.list do
	Items[tier.id .. "_shield"] = { name = tier.name .. " Shield", kind = "armour", slot = "shield", order = 44.5 + tier.rank * 0.01, defense = round(0.03 + 0.012 * tier.rank), tier = tier.id, description = "Blocks a share of every hit while you wear it." }
end

-- Bows shoot arrows (each shot uses one) at anything in sight.
Items.arrow = { name = "Arrow", kind = "resource", order = 62, description = "Ammunition for bows. Each shot uses one." }
Items.BOWS = { wood = { 14, 70 }, silver = { 24, 85 }, gold = { 32, 95 }, diamond = { 44, 110 } }
for t, spec in Items.BOWS do
	local tier = Tiers.get(t) :: any
	Items[t .. "_bow"] = { name = tier.name .. " Bow", kind = "tool", swing = "shoot", ranged = true, range = spec[2], damage = spec[1], cooldown = 0.9, gather = {}, order = 3.5 + tier.rank * 0.1, tier = t, description = "Shoots arrows up to " .. spec[2] .. " studs. Each shot uses an Arrow." }
end

-- Rafts: drop one in the water and ride it.
Items.RAFTS = {
	log_raft = { name = "Log Raft", speed = 16, hp = 120, order = 38 },
	sail_raft = { name = "Sail Raft", speed = 26, hp = 180, order = 38.1 },
	gold_raft = { name = "Gilded Raft", speed = 36, hp = 320, order = 38.2 },
}
for id, r in Items.RAFTS do
	Items[id] = { name = r.name, kind = "raft", order = r.order, description = "Use it at the shore to put it in the water, then sit on it and sail. Top speed " .. r.speed .. "." }
end

-- Armour strength against beasts vs other players, by material (see ARMOUR_VS).
for id, item in Items do
	if type(item) == "table" and item.kind == "armour" and item.defense then
		local tier = string.match(id, "^(%a+)_")
		local vs = Items.ARMOUR_VS[tier or ""] or { mob = 1, player = 1 }
		item.vsMob, item.vsPlayer = vs.mob, vs.player
	end
end

-- A bag for every ore tier, each one bigger than the last (after the Leather Bag,
-- Hide Pack and Explorer Pack). Recipes are in Recipes.lua.
Items.BAG_SIZES = { silver = 200, gold = 250, sunsteel = 310, diamond = 380, fractite = 460, amethyst = 550, obsidian = 650, lunar = 800 }
for _, tier in Tiers.list do
	local size = Items.BAG_SIZES[tier.id]
	if size then
		Items[tier.id .. "_bag"] = { name = tier.name .. " Bag", kind = "armour", slot = "bag", order = 45.3 + tier.rank * 0.01, bagSize = size }
	end
end

return Items
