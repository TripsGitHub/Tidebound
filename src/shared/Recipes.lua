-- Crafting recipes. tab: which crafting tab it shows in. level: level needed.
local Recipes = {
	-- Tools
	{ id = "wood_club", tab = "Tools", level = 1, cost = { log = 3, stick = 1 } },
	{ id = "wood_harvester", tab = "Tools", level = 1, cost = { log = 2, stick = 2, stone = 2 } },
	{ id = "stone_harvester", tab = "Tools", level = 6, cost = { stick = 3, stone = 12, sticky_slime = 2 } },
	{ id = "stone_sword", tab = "Tools", level = 7, cost = { log = 4, stone = 10, sticky_slime = 2 } },
	{ id = "wood_sword", tab = "Tools", level = 2, cost = { log = 5, stick = 2 } },

	-- Armour
	{ id = "leather_bag", tab = "Armour", level = 2, cost = { leather = 4, leaves = 6 } },
	{ id = "wood_boots", tab = "Armour", level = 2, cost = { log = 4, leaves = 2 } },
	{ id = "wood_helmet", tab = "Armour", level = 3, cost = { log = 5, leaves = 2 } },
	{ id = "wood_legs", tab = "Armour", level = 4, cost = { log = 6, leaves = 3 } },
	{ id = "wood_body", tab = "Armour", level = 4, cost = { log = 8, leaves = 3 } },
	{ id = "stone_boots", tab = "Armour", level = 6, cost = { stone = 6, leather = 2 } },
	{ id = "stone_helmet", tab = "Armour", level = 7, cost = { stone = 10, leather = 2 } },
	{ id = "stone_legs", tab = "Armour", level = 8, cost = { stone = 14, leather = 3, sticky_slime = 1 } },
	{ id = "stone_body", tab = "Armour", level = 8, cost = { stone = 18, leather = 4, sticky_slime = 2 } },
	{ id = "aqua_mask", tab = "Armour", level = 6, cost = { leather = 4, sticky_slime = 6, stone = 4 } },
	{ id = "pearl_helm", tab = "Armour", level = 15, cost = { silver_bar = 8, sticky_slime = 10, leather = 6 } },
	{ id = "hide_pack", tab = "Armour", level = 8, cost = { leather = 10, sticky_slime = 3 } },
	{ id = "explorer_pack", tab = "Armour", level = 14, cost = { leather = 16, gold_bar = 4, sticky_slime = 4 } },

	-- Food: mix what you forage into something more filling.
	{ id = "fruit_salad", tab = "Food", level = 3, cost = { berries = 4, banana = 1, mango = 1 } },
	{ id = "banana_bread", tab = "Food", level = 5, cost = { banana = 3, coconut = 1, roast_mushroom = 1 } },

	-- Cave and boss gear (levels on the 1-20 scale like the rest)
	{ id = "maw_key", tab = "Tools", level = 9, cost = { key_fragment = 3, gold_bar = 4 } },
	{ id = "fang_blade", tab = "Tools", level = 19, cost = { queen_fang = 1, diamond = 6, leather = 6 } },
	{ id = "golem_harvester", tab = "Tools", level = 20, cost = { golem_heart = 1, obsidian = 8, stick = 6 } },
	{ id = "warden_pack", tab = "Armour", level = 19, cost = { warden_core = 1, amethyst = 4, leather = 12 } },

	-- Slime armour: soaks up beasts' bites, weak against other players' blades.
	{ id = "slime_boots", tab = "Armour", level = 9, cost = { sticky_slime = 10, leather = 2 } },
	{ id = "slime_helmet", tab = "Armour", level = 9, cost = { sticky_slime = 14, leather = 2 } },
	{ id = "slime_legs", tab = "Armour", level = 10, cost = { sticky_slime = 18, leather = 3 } },
	{ id = "slime_body", tab = "Armour", level = 10, cost = { sticky_slime = 24, leather = 4 } },

	-- Buildables
	{ id = "campfire", tab = "Buildables", level = 1, cost = { log = 3, stick = 2, stone = 3 } },
	{ id = "wood_base", tab = "Buildables", level = 3, cost = { log = 30 } },
	{ id = "wood_wall", tab = "Buildables", level = 3, cost = { log = 8 } },
	{ id = "storage_chest", tab = "Buildables", level = 3, cost = { log = 10, stick = 4 } },
	{ id = "wood_gate", tab = "Buildables", level = 4, cost = { log = 8, sticky_slime = 1 } },
	{ id = "stone_base", tab = "Buildables", level = 8, cost = { stone = 50, sticky_slime = 4 } },
	{ id = "large_stone_base", tab = "Buildables", level = 12, cost = { stone = 90, sticky_slime = 8, silver_bar = 4 } },
	{ id = "stone_wall", tab = "Buildables", level = 8, cost = { stone = 14, sticky_slime = 2 } },

	-- Round 7: lights, beds, traps, ladders, carts, rafts, shields, bows
	{ id = "torch", tab = "Buildables", level = 2, cost = { stick = 3, leaves = 2, log = 1 } },
	{ id = "ladder", tab = "Buildables", level = 3, cost = { log = 4, stick = 6 } },
	{ id = "bed", tab = "Buildables", level = 3, cost = { log = 8, leaves = 10, leather = 3 } },
	{ id = "spike_trap", tab = "Buildables", level = 5, cost = { log = 4, stone = 8 } },
	{ id = "lamp", tab = "Buildables", level = 9, cost = { log = 3, silver_bar = 1, sticky_slime = 2 } },
	{ id = "wood_cart", tab = "Buildables", level = 3, cost = { log = 14, stick = 6 } },
	{ id = "stone_cart", tab = "Buildables", level = 7, cost = { log = 10, stone = 16 } },
	{ id = "silver_cart", tab = "Buildables", level = 9, cost = { log = 10, silver_bar = 8 } },
	{ id = "gold_cart", tab = "Buildables", level = 11, cost = { log = 12, gold_bar = 8 } },
	{ id = "log_raft", tab = "Buildables", level = 2, cost = { log = 10, leaves = 6 } },
	{ id = "sail_raft", tab = "Buildables", level = 8, cost = { log = 14, leather = 6, sticky_slime = 3 } },
	{ id = "gold_raft", tab = "Buildables", level = 12, cost = { log = 18, leather = 8, gold_bar = 6 } },
	{ id = "wood_shield", tab = "Armour", level = 2, cost = { log = 6, leather = 1 } },
	{ id = "stone_shield", tab = "Armour", level = 6, cost = { stone = 10, log = 4, leather = 2 } },
	{ id = "wood_bow", tab = "Tools", level = 3, cost = { log = 3, stick = 4, leather = 1 } },
	{ id = "arrow", tab = "Tools", level = 3, amount = 10, cost = { stick = 3, stone = 2, leaves = 2 } },
}

-- Every tier from Silver up: a harvester and sword first (the harvester mines the next
-- tier's ore), then armour. Each piece takes that tier's ore, and the bigger pieces
-- also take some of the tier below's, so you can't skip a tier.
local Ores = require(script.Parent.Ores)
-- Metal ores have to be smelted into bars first (Smelting.lua); crystals are used as cut.
local BAR = { silver_ore = "silver_bar", gold_ore = "gold_bar", sunstone = "sunsteel_bar" }
local function material(item: string): string
	return BAR[item] or item
end
for i, ore in Ores do
	local prev = Ores[i - 1]
	local m = 1 + 0.1 * (i - 1) -- later tiers need a bit more ore
	local function cost(n: number, extra: { [string]: number }, prevAmount: number?)
		local c = table.clone(extra)
		c[material(ore.item)] = math.ceil(n * m)
		if prev and prevAmount then
			c[material(prev.item)] = prevAmount
		end
		return c
	end
	local L, L2 = ore.level, ore.level + 1
	local t = ore.tier
	table.insert(Recipes, { id = t .. "_harvester", tab = "Tools", level = L, cost = cost(8, { stick = 4 }, 3) })
	table.insert(Recipes, { id = t .. "_sword", tab = "Tools", level = L, cost = cost(10, { log = 3 }, 4) })
	table.insert(Recipes, { id = t .. "_boots", tab = "Armour", level = L, cost = cost(6, { leather = 2 }) })
	table.insert(Recipes, { id = t .. "_helmet", tab = "Armour", level = L, cost = cost(9, { leather = 2 }) })
	table.insert(Recipes, { id = t .. "_legs", tab = "Armour", level = L2, cost = cost(12, { leather = 3 }, 4) })
	table.insert(Recipes, { id = t .. "_body", tab = "Armour", level = L2, cost = cost(15, { leather = 4 }, 6) })
	table.insert(Recipes, { id = t .. "_bag", tab = "Armour", level = L2, cost = cost(10, { leather = 6, sticky_slime = 2 }, 4) })
	table.insert(Recipes, { id = t .. "_shield", tab = "Armour", level = L, cost = cost(9, { leather = 2, log = 2 }, 3) })
	table.insert(Recipes, { id = t .. "_wall", tab = "Buildables", level = L, cost = cost(10, { stone = 6 }) })
	table.insert(Recipes, { id = t .. "_chest", tab = "Buildables", level = L, cost = cost(8, { log = 8 }) })
	local Items = require(script.Parent.Items)
	local bowId = if Items[t .. "_crossbow"] then t .. "_crossbow" else t .. "_bow"
	if Items[bowId] then
		table.insert(Recipes, { id = bowId, tab = "Tools", level = L, cost = cost(if Items[bowId].crossbow then 9 else 7, { log = 2, leather = 2 }, 2) })
	end
end

-- Recipes above are on a 1-20 scale; spread them over the real level range.
local Config = require(script.Parent.Config)
for _, r in Recipes do
	r.level = Config.ScaleLevel(r.level)
end

-- Lowest level first, so the crafting screen lists them in the order you unlock them.
local order = {}
for i, r in Recipes do
	order[r] = i
end
table.sort(Recipes, function(a, b)
	if a.level ~= b.level then
		return a.level < b.level
	end
	return order[a] < order[b]
end)

return Recipes
