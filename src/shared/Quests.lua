-- Quest board quests. Each pays Shells once.
-- type: "gather" (pick up `amount` of `item`), "craft" (craft `item`), "build" (place structures), "hunt" (kill animals)
local Quests = {
	{ id = "logs", title = "Woodcutter", text = "Pick up 25 Small Logs", type = "gather", item = "log", amount = 25, reward = 15 },
	{ id = "harvester", title = "Tool Maker", text = "Craft a Wooden Harvester", type = "craft", item = "wood_harvester", amount = 1, reward = 15 },
	{ id = "boar", title = "Hunter", text = "Hunt 2 Boars", type = "hunt", item = "Boar", amount = 2, reward = 25 },
	{ id = "base", title = "Homesteader", text = "Place a Wood Base", type = "craft", item = "wood_base", amount = 1, reward = 30 },
}

return Quests
