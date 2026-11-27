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
	{ id = "pearl_helm", tab = "Armour", level = 15, cost = { silver_ore = 8, sticky_slime = 10, leather = 6 } },
	{ id = "hide_pack", tab = "Armour", level = 8, cost = { leather = 10, sticky_slime = 3 } },
	{ id = "explorer_pack", tab = "Armour", level = 14, cost = { leather = 16, gold_ore = 4, sticky_slime = 4 } },

	-- Cave and boss gear (levels on the 1-20 scale like the rest)
	{ id = "maw_key", tab = "Tools", level = 9, cost = { key_fragment = 3, gold_ore = 4 } },
	{ id = "fang_blade", tab = "Tools", level = 19, cost = { queen_fang = 1, diamond = 6, leather = 6 } },
	{ id = "golem_harvester", tab = "Tools", level = 20, cost = { golem_heart = 1, obsidian = 8, stick = 6 } },
	{ id = "warden_pack", tab = "Armour", level = 19, cost = { warden_core = 1, amethyst = 4, leather = 12 } },

	-- Buildables
	{ id = "campfire", tab = "Buildables", level = 1, cost = { log = 3, stick = 2, stone = 3 } },
	{ id = "wood_base", tab = "Buildables", level = 3, cost = { log = 30 } },
	{ id = "wood_wall", tab = "Buildables", level = 3, cost = { log = 8 } },
	{ id = "storage_chest", tab = "Buildables", level = 3, cost = { log = 10, stick = 4 } },
	{ id = "wood_gate", tab = "Buildables", level = 4, cost = { log = 8, sticky_slime = 1 } },
	{ id = "stone_base", tab = "Buildables", level = 8, cost = { stone = 50, sticky_slime = 4 } },
	{ id = "large_stone_base", tab = "Buildables", level = 12, cost = { stone = 90, sticky_slime = 8, silver_ore = 4 } },
	{ id = "stone_wall", tab = "Buildables", level = 8, cost = { stone = 14, sticky_slime = 2 } },
}

-- Every tier from Silver up: a harvester and sword first (the harvester mines the next
-- tier's ore), then armour. Each piece takes that tier's ore, and the bigger pieces
-- also take some of the tier below's, so you can't skip a tier.
local Ores = require(script.Parent.Ores)
for i, ore in Ores do
	local prev = Ores[i - 1]
	local m = 1 + 0.1 * (i - 1) -- later tiers need a bit more ore
	local function cost(n: number, extra: { [string]: number }, prevAmount: number?)
		local c = table.clone(extra)
		c[ore.item] = math.ceil(n * m)
		if prev and prevAmount then
			c[prev.item] = prevAmount
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
