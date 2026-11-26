-- Every item in the game. To add an item, copy an entry and change it.
-- kind:
--   "tool"      held in your hand, used to gather and to break structures
--   "food"      click while holding it to eat
--   "placeable" click while holding it to build it
--   "resource"  crafting material, lives in your pack
-- gather: how much each hit gathers from each material (missing = can't gather it)
-- damage: how much each hit does to structures (and later, players)

local WOOD = Color3.fromRGB(124, 92, 60)

local Items = {
	-- Tools ------------------------------------------------------------
	rock = {
		name = "Rock",
		kind = "tool",
		order = 1,
		gather = { wood = 1, stone = 1, plant = 2, slime = 1 },
		cooldown = 0.5,
		damage = 5,
		color = Color3.fromRGB(120, 120, 125),
		handleSize = Vector3.new(0.9, 0.9, 0.9),
	},
	wood_axe = {
		name = "Wood Axe",
		kind = "tool",
		order = 2,
		gather = { wood = 2, stone = 1, plant = 2, slime = 1 },
		cooldown = 0.55,
		damage = 8,
		color = WOOD,
		headColor = Color3.fromRGB(160, 120, 80),
		handleSize = Vector3.new(0.3, 0.3, 3),
	},
	wood_pick = {
		name = "Wood Pick",
		kind = "tool",
		order = 3,
		gather = { wood = 1, stone = 2, plant = 1, slime = 1 },
		cooldown = 0.55,
		damage = 8,
		color = WOOD,
		headColor = Color3.fromRGB(160, 120, 80),
		handleSize = Vector3.new(0.3, 0.3, 3),
	},
	stone_axe = {
		name = "Stone Axe",
		kind = "tool",
		order = 4,
		gather = { wood = 4, stone = 1, plant = 2, slime = 2 },
		cooldown = 0.6,
		damage = 14,
		color = WOOD,
		headColor = Color3.fromRGB(110, 110, 115),
		handleSize = Vector3.new(0.3, 0.3, 3),
	},
	stone_pick = {
		name = "Stone Pick",
		kind = "tool",
		order = 5,
		gather = { wood = 1, stone = 4, plant = 1, slime = 2 },
		cooldown = 0.6,
		damage = 14,
		color = WOOD,
		headColor = Color3.fromRGB(110, 110, 115),
		handleSize = Vector3.new(0.3, 0.3, 3),
	},

	-- Food -------------------------------------------------------------
	berries = { name = "Berries", kind = "food", order = 20, hunger = 12 },
	coconut = { name = "Coconut", kind = "food", order = 21, hunger = 20 },

	-- Buildables -------------------------------------------------------
	wood_wall = { name = "Wood Wall", kind = "placeable", order = 30, structure = "WoodWall" },
	wood_floor = { name = "Wood Floor", kind = "placeable", order = 31, structure = "WoodFloor" },
	wood_door = { name = "Wood Door", kind = "placeable", order = 32, structure = "WoodDoor" },
	stone_wall = { name = "Stone Wall", kind = "placeable", order = 33, structure = "StoneWall" },
	campfire = { name = "Campfire", kind = "placeable", order = 34, structure = "Campfire" },

	-- Resources --------------------------------------------------------
	wood = { name = "Wood", kind = "resource", order = 100 },
	stone = { name = "Stone", kind = "resource", order = 101 },
	fiber = { name = "Fiber", kind = "resource", order = 102 },
	sticky_slime = { name = "Sticky Slime", kind = "resource", order = 103 },
}

return Items
