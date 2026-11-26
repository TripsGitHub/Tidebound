-- Crafting recipes, in the order they show in the crafting menu.
-- level: the player level needed before the recipe unlocks.

local Recipes = {
	{ id = "wood_axe", level = 1, cost = { wood = 4, fiber = 2 } },
	{ id = "wood_pick", level = 1, cost = { wood = 4, fiber = 2 } },
	{ id = "wood_wall", level = 2, cost = { wood = 8 } },
	{ id = "wood_floor", level = 2, cost = { wood = 6 } },
	{ id = "campfire", level = 2, cost = { wood = 6, stone = 4 } },
	{ id = "stone_axe", level = 3, cost = { wood = 3, stone = 6, sticky_slime = 2 } },
	{ id = "stone_pick", level = 3, cost = { wood = 3, stone = 6, sticky_slime = 2 } },
	{ id = "wood_door", level = 3, cost = { wood = 8, sticky_slime = 1 } },
	{ id = "stone_wall", level = 4, cost = { stone = 12, sticky_slime = 2 } },
}

return Recipes
