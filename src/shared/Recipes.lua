-- Crafting recipes. tab: which crafting tab it shows in. level: level needed.
local Recipes = {
	-- Tools
	{ id = "wood_club", tab = "Tools", level = 1, cost = { log = 3, stick = 1 } },
	{ id = "wood_harvester", tab = "Tools", level = 1, cost = { log = 2, stick = 2, stone = 2 } },
	{ id = "stone_harvester", tab = "Tools", level = 6, cost = { stick = 3, stone = 12, sticky_slime = 2 } },
	{ id = "stone_sword", tab = "Tools", level = 7, cost = { log = 4, stone = 10, sticky_slime = 2 } },

	-- Armour
	{ id = "leather_bag", tab = "Armour", level = 2, cost = { leather = 4, leaves = 6 } },
	{ id = "wood_boots", tab = "Armour", level = 2, cost = { log = 4, leaves = 2 } },
	{ id = "wood_helmet", tab = "Armour", level = 3, cost = { log = 5, leaves = 2 } },
	{ id = "wood_legs", tab = "Armour", level = 4, cost = { log = 6, leaves = 3 } },
	{ id = "wood_body", tab = "Armour", level = 4, cost = { log = 8, leaves = 3 } },

	-- Buildables
	{ id = "campfire", tab = "Buildables", level = 1, cost = { log = 3, stick = 2, stone = 3 } },
	{ id = "wood_base", tab = "Buildables", level = 3, cost = { log = 20 } },
	{ id = "wood_wall", tab = "Buildables", level = 3, cost = { log = 8 } },
	{ id = "wood_door", tab = "Buildables", level = 4, cost = { log = 8, sticky_slime = 1 } },
	{ id = "stone_base", tab = "Buildables", level = 8, cost = { stone = 30, sticky_slime = 3 } },
	{ id = "stone_wall", tab = "Buildables", level = 8, cost = { stone = 14, sticky_slime = 2 } },
}

return Recipes
