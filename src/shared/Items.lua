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
	leather_bag = { name = "Leather Bag", kind = "armour", slot = "bag", order = 45, bagSize = 100 },
	hide_pack = { name = "Hide Pack", kind = "armour", slot = "bag", order = 45.1, bagSize = 120 },
	-- Diving gear: worn on the head, adds seconds of air under water.
	aqua_mask = { name = "Diving Mask", kind = "armour", slot = "head", order = 44, defense = 0.02, air = 30 },
	pearl_helm = { name = "Pearl Diving Helm", kind = "armour", slot = "head", order = 44.1, defense = 0.06, air = 75 },
	explorer_pack = { name = "Explorer Pack", kind = "armour", slot = "bag", order = 45.2, bagSize = 160 },

	-- Food -------------------------------------------------------------
	berries = { name = "Berries", kind = "food", order = 20, hunger = 8 },
	coconut = { name = "Coconut", kind = "food", order = 21, hunger = 14 },
	sunfruit = { name = "Sunfruit", kind = "food", order = 21.5, hunger = 18, heal = 6 },
	banana = { name = "Banana", kind = "food", order = 21.6, hunger = 14, heal = 5 },
	mango = { name = "Mango", kind = "food", order = 21.7, hunger = 16, heal = 6 },
	mushroom = { name = "Mushroom", kind = "food", order = 21.8, hunger = 6, heal = 2 },
	roast_mushroom = { name = "Roast Mushroom", kind = "food", order = 21.9, hunger = 14, heal = 8 },
	raw_fish = { name = "Raw Fish", kind = "food", order = 22.1, hunger = 4, hurt = 3 },
	cooked_fish = { name = "Cooked Fish", kind = "food", order = 22.2, hunger = 24, heal = 12 },
	fruit_salad = { name = "Fruit Salad", kind = "food", order = 23.5, hunger = 45, heal = 25 },
	banana_bread = { name = "Banana Bread", kind = "food", order = 23.6, hunger = 55, heal = 18 },
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

-- Crates come in four rarities. Each holds its own loot table: { item, min, max, weight }.
-- Level-up rewards give the crate that matches the level you reached (see
-- Config.crateForLevel), so a level 6 crate never holds late-game ore. The Mythic
-- materials (Star Shard, Abyss Pearl, Ancient Rune) come from nowhere else: they make
-- the Tidecaller gear, the best in the game.
Items.rare_crate = { name = "Rare Crate", kind = "crate", order = 132.1 }
Items.epic_crate = { name = "Epic Crate", kind = "crate", order = 132.2 }
Items.mythic_crate = { name = "Mythic Crate", kind = "crate", order = 132.3 }
Items.star_shard = { name = "Star Shard", kind = "resource", order = 136, description = "A shard of a fallen star. Only found in Epic and Mythic Crates. Used for Tidecaller gear." }
Items.abyss_pearl = { name = "Abyss Pearl", kind = "resource", order = 136.1, description = "A black pearl from the deepest sea. Only found in Mythic Crates. Used for Tidecaller gear." }
Items.ancient_rune = { name = "Ancient Rune", kind = "resource", order = 136.2, description = "A carved stone from the first tribe. Only found in Mythic Crates. Used for Tidecaller gear." }
-- rarity: colour and label used by the crate-opening screen.
Items.CRATES = {
	supply_crate = {
		rarity = "Common",
		colour = Color3.fromRGB(196, 150, 96),
		rolls = { 2, 3 },
		loot = {
			{ "log", 8, 16, 10 },
			{ "stone", 8, 16, 10 },
			{ "stick", 6, 12, 8 },
			{ "leaves", 6, 12, 6 },
			{ "leather", 3, 6, 8 },
			{ "cooked_meat", 2, 4, 7 },
			{ "sticky_slime", 2, 5, 5 },
			{ "arrow", 10, 20, 3 },
			{ "rare_crate", 1, 1, 0.6 },
		},
	},
	rare_crate = {
		rarity = "Rare",
		colour = Color3.fromRGB(80, 150, 240),
		rolls = { 2, 4 },
		loot = {
			{ "silver_ore", 3, 6, 10 },
			{ "silver_bar", 2, 4, 6 },
			{ "gold_ore", 2, 5, 7 },
			{ "gold_bar", 1, 3, 4 },
			{ "leather", 6, 10, 6 },
			{ "sticky_slime", 4, 8, 6 },
			{ "cooked_meat", 4, 6, 5 },
			{ "key_fragment", 1, 1, 3 },
			{ "epic_crate", 1, 1, 0.5 },
		},
	},
	epic_crate = {
		rarity = "Epic",
		colour = Color3.fromRGB(176, 90, 240),
		rolls = { 3, 4 },
		loot = {
			{ "sunstone", 3, 6, 10 },
			{ "sunsteel_bar", 2, 4, 6 },
			{ "diamond", 2, 4, 7 },
			{ "fractite", 1, 3, 5 },
			{ "amethyst", 1, 2, 3 },
			{ "key_fragment", 1, 2, 5 },
			{ "pink_slime", 2, 4, 4 },
			{ "star_shard", 1, 1, 1 },
			{ "mythic_crate", 1, 1, 0.4 },
		},
	},
	mythic_crate = {
		rarity = "Mythic",
		colour = Color3.fromRGB(255, 196, 60),
		rolls = { 3, 5 },
		loot = {
			{ "amethyst", 3, 6, 8 },
			{ "obsidian", 3, 6, 8 },
			{ "moonstone", 2, 4, 6 },
			{ "gold_slime", 1, 3, 4 },
			{ "key_fragment", 2, 3, 4 },
			{ "star_shard", 1, 3, 6 },
			{ "abyss_pearl", 1, 1, 3 },
			{ "ancient_rune", 1, 1, 3 },
		},
	},
}
Items.CRATE_LOOT = Items.CRATES.supply_crate.loot -- older code

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

-- Tidecaller (Mythic) gear outclasses everything else, boss gear included.
Items.tidecaller_sword.damage = 130
Items.tidecaller_sword.cooldown = 0.5
Items.tidecaller_harvester.gather = { wood = 14, stone = 14, plant = 12, slime = 12 }
Items.tidecaller_harvester.cooldown = 0.45
for _, key in { "sword", "harvester", "helmet", "body", "legs", "boots" } do
	Items["tidecaller_" .. key].mythic = true
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
	tidecaller = { mob = 1.3, player = 1.3 },
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
-- Farming: crops you grow in a Plant Box from seeds. Seeds come from wild crops
-- (and slime spores from slime pools); a coconut is its own seed.
Items.carrot = { name = "Carrot", kind = "food", order = 24.1, hunger = 12, heal = 4 }
Items.potato = { name = "Potato", kind = "food", order = 24.2, hunger = 10, heal = 2 }
Items.baked_potato = { name = "Baked Potato", kind = "food", order = 24.25, hunger = 30, heal = 10, description = "Roast a potato on a campfire." }
Items.watermelon = { name = "Watermelon", kind = "food", order = 24.3, hunger = 26, heal = 10 }
Items.green_slime = { name = "Green Slime", kind = "food", order = 24.4, hunger = 10, heal = 14, description = "Chewy and oddly healing." }
Items.blue_slime = { name = "Blue Slime", kind = "food", order = 24.41, hunger = 30, heal = 4, description = "Fills you right up." }
Items.pink_slime = { name = "Pink Slime", kind = "food", order = 24.42, hunger = 16, heal = 30, description = "A rare, sweet slime that heals a lot." }
Items.gold_slime = { name = "Golden Slime", kind = "food", order = 24.43, hunger = 45, heal = 45, description = "The rarest slime. Fills and heals you completely." }
Items.carrot_seeds = { name = "Carrot Seeds", kind = "seed", crop = "carrot", order = 25.1, description = "Plant in a Plant Box." }
Items.potato_seeds = { name = "Potato Seeds", kind = "seed", crop = "potato", order = 25.2, description = "Plant in a Plant Box." }
Items.watermelon_seeds = { name = "Watermelon Seeds", kind = "seed", crop = "watermelon", order = 25.3, description = "Plant in a Plant Box." }
Items.slime_spore = { name = "Slime Spore", kind = "seed", crop = "slime", order = 25.4, description = "Plant in a Plant Box. Grows a green, blue, pink or (rarely) golden slime." }
Items.coconut.crop = "coconut"
Items.coconut.description = "Eat it, or plant it in a Plant Box to grow a coconut sapling."
Items.plant_box = { name = "Plant Box", kind = "placeable", order = 36.4, structure = "PlantBox", description = "A wooden box of soil. Plant seeds in it and come back to harvest." }

-- What each crop grows into. grow: seconds to ripen. yield: { item, min, max } (a
-- slime picks one variant by weight). seeds: seeds you get back { min, max }.
Items.CROPS = {
	carrot = { seed = "carrot_seeds", grow = 120, yield = { { "carrot", 2, 4 } }, seeds = { 1, 2 } },
	potato = { seed = "potato_seeds", grow = 150, yield = { { "potato", 2, 4 } }, seeds = { 1, 2 } },
	watermelon = { seed = "watermelon_seeds", grow = 240, yield = { { "watermelon", 1, 2 } }, seeds = { 1, 3 } },
	coconut = { seed = "coconut", grow = 300, yield = { { "coconut", 3, 5 } }, seeds = { 0, 0 } },
	slime = { seed = "slime_spore", grow = 200, variants = { { "green_slime", 50 }, { "blue_slime", 30 }, { "pink_slime", 15 }, { "gold_slime", 5 } }, yield = { { "*", 1, 2 } }, seeds = { 1, 1 } },
}

-- Carts: storage on wheels, from wood up to gold.
Items.CARTS = { "wood", "stone", "silver", "gold" }
for i, t in Items.CARTS do
	local tier = Tiers.get(t) :: any
	Items[t .. "_cart"] = { name = tier.name .. " Cart", kind = "placeable", order = 36.5 + i * 0.01, structure = tier.name .. "Cart", tier = t, description = "A cart to keep things in that you can also ride: sit on the back and drive it, faster than walking. Better carts hold more and go faster." }
end

-- Shields: worn on the off arm, one for every tool tier.
for _, tier in Tiers.list do
	Items[tier.id .. "_shield"] = { name = tier.name .. " Shield", kind = "armour", slot = "shield", order = 44.5 + tier.rank * 0.01, defense = round(0.03 + 0.012 * tier.rank), tier = tier.id, description = "Blocks a share of every hit while you wear it." }
end

-- Bows shoot arrows (each shot uses one). An arrow flies dead straight until it hits
-- something or has gone `range` studs, where it fades out. Better bows shoot faster,
-- harder arrows; from Diamond up they're crossbows.
Items.arrow = { name = "Arrow", kind = "resource", order = 62, description = "Ammunition for bows and crossbows. Each shot uses one." }
-- tier = { damage, range (studs before it fades), arrow speed (studs/s), cooldown }
Items.BOWS = {
	wood = { 14, 160, 110, 0.9 },
	silver = { 22, 180, 130, 0.9 },
	gold = { 30, 200, 150, 0.85 },
	sunsteel = { 38, 220, 170, 0.85 },
	diamond = { 48, 250, 200, 1.0 },
	fractite = { 58, 270, 220, 1.0 },
	amethyst = { 68, 290, 240, 0.95 },
	obsidian = { 80, 310, 260, 0.95 },
	lunar = { 94, 340, 290, 0.9 },
}
Items.CROSSBOW_FROM = 6 -- tier rank where bows become crossbows (Diamond)
for t, spec in Items.BOWS do
	local tier = Tiers.get(t) :: any
	if tier then
		local cross = tier.rank >= Items.CROSSBOW_FROM
		local id = t .. (if cross then "_crossbow" else "_bow")
		Items[id] = { name = tier.name .. (if cross then " Crossbow" else " Bow"), kind = "tool", swing = "shoot", ranged = true, crossbow = cross, range = spec[2], damage = spec[1], arrowSpeed = spec[3], cooldown = spec[4], gather = {}, order = 3.5 + tier.rank * 0.1, tier = t, description = "Shoots arrows dead straight for " .. spec[2] .. " studs at " .. spec[3] .. " studs/s, " .. spec[1] .. " damage. Each shot uses an Arrow." }
	end
end
-- Old item ids that saved games may still hold, and what they turn into.
Items.LEGACY = { diamond_bow = "diamond_crossbow" }

-- Rafts: drop one in the water and ride it.
Items.RAFTS = {
	log_raft = { name = "Log Raft", speed = 24, hp = 120, order = 38 },
	sail_raft = { name = "Sail Raft", speed = 32, hp = 180, order = 38.1 },
	gold_raft = { name = "Gilded Raft", speed = 42, hp = 320, order = 38.2 },
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
Items.BAG_SIZES = { silver = 200, gold = 250, sunsteel = 310, diamond = 380, fractite = 460, amethyst = 550, obsidian = 650, lunar = 800, tidecaller = 1200 }
for _, tier in Tiers.list do
	local size = Items.BAG_SIZES[tier.id]
	if size then
		Items[tier.id .. "_bag"] = { name = tier.name .. " Bag", kind = "armour", slot = "bag", order = 45.3 + tier.rank * 0.01, bagSize = size }
	end
end

-- Lunar gear is heavy (see Appearance.lua): each piece slows you and lowers your jump.
for _, key in { "sword", "harvester", "helmet", "body", "legs", "boots", "shield", "bag", "crossbow" } do
	local item = Items["lunar_" .. key]
	if item then
		item.heavy = true
		item.description = (if item.description then item.description .. " " else "") .. "Heavy: slows your walk and jump while you wear or hold it."
	end
end

return Items
