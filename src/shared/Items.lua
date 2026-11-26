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

local Items = {
	-- Tools ------------------------------------------------------------
	rock = { name = "Rock", kind = "tool", order = 1, gather = { wood = 1, stone = 1, plant = 1, slime = 1 }, cooldown = 0.55, damage = 6 },
	wood_club = { name = "Wooden Club", kind = "tool", order = 2, gather = { wood = 1, plant = 1 }, cooldown = 0.6, damage = 14 },
	wood_harvester = { name = "Wooden Harvester", kind = "tool", order = 3, gather = { wood = 2, stone = 2, plant = 2, slime = 1 }, cooldown = 0.55, damage = 8 },
	stone_club = { name = "Stone Club", kind = "tool", order = 4, gather = { wood = 1, plant = 1 }, cooldown = 0.65, damage = 22 },
	stone_harvester = { name = "Stone Harvester", kind = "tool", order = 5, gather = { wood = 3, stone = 3, plant = 2, slime = 2 }, cooldown = 0.55, damage = 11 },

	-- Armour -----------------------------------------------------------
	wood_helmet = { name = "Wood Helmet", kind = "armour", slot = "head", order = 40, defense = 0.03 },
	wood_body = { name = "Wood Body", kind = "armour", slot = "body", order = 41, defense = 0.05 },
	wood_legs = { name = "Wood Legs", kind = "armour", slot = "legs", order = 42, defense = 0.04 },
	wood_boots = { name = "Wood Boots", kind = "armour", slot = "feet", order = 43, defense = 0.02 },
	leather_bag = { name = "Leather Bag", kind = "armour", slot = "bag", order = 44, bagSize = 80 },

	-- Food -------------------------------------------------------------
	berries = { name = "Berries", kind = "food", order = 20, hunger = 8 },
	coconut = { name = "Coconut", kind = "food", order = 21, hunger = 14 },
	raw_meat = { name = "Raw Meat", kind = "food", order = 22, hunger = 5, hurt = 5 },
	cooked_meat = { name = "Cooked Meat", kind = "food", order = 23, hunger = 35, heal = 15 },

	-- Buildables -------------------------------------------------------
	campfire = { name = "Campfire", kind = "placeable", order = 30, structure = "Campfire" },
	wood_base = { name = "Wood Base", kind = "placeable", order = 31, structure = "WoodBase" },
	wood_wall = { name = "Wood Wall", kind = "placeable", order = 32, structure = "WoodWall" },
	wood_door = { name = "Wood Door", kind = "placeable", order = 33, structure = "WoodDoor" },
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

return Items
