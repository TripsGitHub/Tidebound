-- Quests.
--
-- The Tribe Path (Quests.PATH) is the route every new player follows: one step at a
-- time, shown in the top-left. Each step pays XP, Shells and often an item the moment
-- it's done (no walking back to a board), and leads straight into the next, so the
-- first half hour goes: gather, tools, food, a bag, stone gear, a base, a raft,
-- silver, smelting, silver gear, then the caves and the first boss key.
--
-- Board quests (the list below PATH) are side jobs at the Quest Board, claimed there.
-- type: "gather" (pick up `amount` of `item`), "craft" (craft `item`), "build" (place
-- structures), "hunt" (kill animals; item = the animal type, or nil for any),
-- "smelt" (smelt `amount` of `item` in a campfire).
local Quests = {
	{ id = "logs", title = "Woodcutter", text = "Pick up 25 Small Logs", type = "gather", item = "log", amount = 25, reward = 15, xp = 40 },
	{ id = "harvester", title = "Tool Maker", text = "Craft a Wooden Harvester", type = "craft", item = "wood_harvester", amount = 1, reward = 15, xp = 30 },
	{ id = "boar", title = "Hunter", text = "Hunt 2 Boars", type = "hunt", item = "Boar", amount = 2, reward = 25, xp = 60 },
	{ id = "base", title = "Homesteader", text = "Place a Wooden Base", type = "craft", item = "wood_base", amount = 1, reward = 30, xp = 80 },
	{ id = "rocks", title = "Quarry", text = "Pick up 40 Small Rocks", type = "gather", item = "stone", amount = 40, reward = 20, xp = 60 },
	{ id = "crabs", title = "Beach Patrol", text = "Hunt 4 Crabs", type = "hunt", item = "Crab", amount = 4, reward = 20, xp = 60 },
	{ id = "builder", title = "Builder", text = "Place 10 structures", type = "build", amount = 10, reward = 40, xp = 120 },
	{ id = "slime", title = "Slime Collector", text = "Pick up 15 Sticky Slime", type = "gather", item = "sticky_slime", amount = 15, reward = 30, xp = 100 },
	{ id = "wolves", title = "Wolf Hunter", text = "Hunt 3 Wolves", type = "hunt", item = "Wolf", amount = 3, reward = 50, xp = 150 },
	{ id = "goldsmith", title = "Goldsmith", text = "Smelt 10 Gold Ore", type = "smelt", item = "gold_ore", amount = 10, reward = 80, xp = 300 },
}

-- reward: Shells. items: given straight into the bag.
Quests.PATH = {
	{ id = "p_logs", title = "Gather wood", text = "Hit trees to collect 10 Small Logs", type = "gather", item = "log", amount = 10, xp = 25, reward = 5 },
	{ id = "p_rocks", title = "Gather rocks", text = "Hit boulders to collect 8 Small Rocks", type = "gather", item = "stone", amount = 8, xp = 25, reward = 5 },
	{ id = "p_harv", title = "Your first tool", text = "Press C and craft a Wooden Harvester", type = "craft", item = "wood_harvester", amount = 1, xp = 35, reward = 10, items = { stick = 4 } },
	{ id = "p_fire", title = "Light a fire", text = "Craft a Campfire and place it", type = "craft", item = "campfire", amount = 1, xp = 35, reward = 10, items = { raw_meat = 2 } },
	{ id = "p_boar", title = "Hunt", text = "Hunt a Boar (cook its meat on your fire)", type = "hunt", item = "Boar", amount = 1, xp = 50, reward = 10, items = { leather = 2 } },
	{ id = "p_bag", title = "Carry more", text = "Craft a Leather Bag and wear it", type = "craft", item = "leather_bag", amount = 1, xp = 50, reward = 15 },
	{ id = "p_stone", title = "Stone age", text = "Gather 25 Small Rocks with your harvester", type = "gather", item = "stone", amount = 25, xp = 50, reward = 10 },
	{ id = "p_sharv", title = "Stone tools", text = "Craft a Stone Harvester", type = "craft", item = "stone_harvester", amount = 1, xp = 80, reward = 20 },
	{ id = "p_ssword", title = "Arm yourself", text = "Craft a Stone Sword", type = "craft", item = "stone_sword", amount = 1, xp = 80, reward = 20, items = { cooked_meat = 3 } },
	{ id = "p_base", title = "Make a home", text = "Craft and place a Wooden Base", type = "craft", item = "wood_base", amount = 1, xp = 100, reward = 25, items = { log = 10 } },
	{ id = "p_helm", title = "Stone armour", text = "Craft a Stone Helmet", type = "craft", item = "stone_helmet", amount = 1, xp = 100, reward = 25, items = { supply_crate = 1 } },
	{ id = "p_hunt", title = "Island hunter", text = "Hunt 5 animals", type = "hunt", amount = 5, xp = 120, reward = 30 },
	{ id = "p_raft", title = "Set sail", text = "Craft a Log Raft and sail to another island", type = "craft", item = "log_raft", amount = 1, xp = 120, reward = 30 },
	{ id = "p_silver", title = "Silver", text = "Mine 6 Silver Ore (silver veins, stone harvester)", type = "gather", item = "silver_ore", amount = 6, xp = 150, reward = 40 },
	{ id = "p_smelt", title = "Smelting", text = "Drop Silver Ore into a lit campfire to smelt 6 bars", type = "smelt", item = "silver_ore", amount = 6, xp = 200, reward = 40, items = { supply_crate = 1 } },
	{ id = "p_sbody", title = "Stone body", text = "Craft a Stone Chestplate", type = "craft", item = "stone_body", amount = 1, xp = 150, reward = 40 },
	{ id = "p_silvh", title = "Silver tools", text = "Craft a Silver Harvester", type = "craft", item = "silver_harvester", amount = 1, xp = 250, reward = 60, items = { rare_crate = 1 } },
	{ id = "p_gold", title = "Gold", text = "Mine 6 Gold Ore with your Silver Harvester", type = "gather", item = "gold_ore", amount = 6, xp = 300, reward = 60 },
	{ id = "p_keys", title = "Into the caves", text = "Find 3 Key Fragments in the caves", type = "gather", item = "key_fragment", amount = 3, xp = 400, reward = 80 },
	{ id = "p_mawkey", title = "The first gate", text = "Craft a Maw Key and open a boss gate", type = "craft", item = "maw_key", amount = 1, xp = 500, reward = 100, items = { rare_crate = 1 } },
}

return Quests
