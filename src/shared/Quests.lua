-- Quest board quests. Each pays Shells once.
-- type:
--   "gather" collect `amount` of `item` (counted as you gather, not what you hold)
--   "craft"  craft `item` `amount` times
--   "build"  place `amount` structures of any kind

local Quests = {
	{ id = "first_wood", title = "Driftwood Gatherer", text = "Gather 20 Wood", type = "gather", item = "wood", amount = 20, reward = 15 },
	{ id = "first_pick", title = "Tool Maker", text = "Craft a Wood Pick", type = "craft", item = "wood_pick", amount = 1, reward = 20 },
	{ id = "first_slime", title = "Sticky Fingers", text = "Gather 5 Sticky Slime", type = "gather", item = "sticky_slime", amount = 5, reward = 20 },
	{ id = "first_walls", title = "Homesteader", text = "Build 3 structures", type = "build", amount = 3, reward = 30 },
}

return Quests
