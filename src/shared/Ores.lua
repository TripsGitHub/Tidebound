-- The ore or crystal behind each tier from Silver up, and the node it is mined from.
-- To mine a node your harvester's stone power must reach `minPower`: every harvester
-- has stone power rank + 1, so the harvester of the tier below always unlocks it
-- (Stone Harvester -> Silver, Silver Harvester -> Gold, ... Obsidian -> Moonstone).
-- level: the level that tier's gear unlocks at.
-- Where they come from:
--   Silver, Gold                on the surface (Clover's rocks, Stone Shelf, Frost Isle)
--   Sunstone, Diamond           the Deep Vault, below sea level in Stone Shelf's cave
--   Fractite, Amethyst          the Hollow, the deepest chamber of that cave
--   Obsidian                    only from Ember Isle eruptions (world event)
--   Moonstone                   only from meteor showers at night (world event)
-- look: how the node and the item are drawn ("metal" = nuggets in rock,
--       "crystal" = a cluster of shards).

export type Ore = {
	tier: string,
	item: string,
	name: string,
	node: string,
	nodeName: string,
	look: "metal" | "crystal",
	minPower: number,
	level: number,
}

local Ores: { Ore } = {
	{ tier = "silver", item = "silver_ore", name = "Silver Ore", node = "SilverVein", nodeName = "Silver Vein", look = "metal", minPower = 3, level = 7 },
	{ tier = "gold", item = "gold_ore", name = "Gold Ore", node = "GoldVein", nodeName = "Gold Vein", look = "metal", minPower = 4, level = 10 },
	{ tier = "sunsteel", item = "sunstone", name = "Sunstone", node = "SunstoneVein", nodeName = "Sunstone Vein", look = "metal", minPower = 5, level = 13 },
	{ tier = "diamond", item = "diamond", name = "Diamond", node = "DiamondCluster", nodeName = "Diamond Cluster", look = "crystal", minPower = 6, level = 14 },
	{ tier = "fractite", item = "fractite", name = "Fractite Shard", node = "FractiteCluster", nodeName = "Fractite Cluster", look = "crystal", minPower = 7, level = 15 },
	{ tier = "amethyst", item = "amethyst", name = "Amethyst", node = "AmethystGeode", nodeName = "Amethyst Geode", look = "crystal", minPower = 8, level = 17 },
	{ tier = "obsidian", item = "obsidian", name = "Obsidian", node = "ObsidianSpire", nodeName = "Obsidian Spire", look = "crystal", minPower = 9, level = 18 },
	{ tier = "lunar", item = "moonstone", name = "Moonstone", node = "MoonstoneCluster", nodeName = "Moonstone Cluster", look = "crystal", minPower = 10, level = 20 },
}

return Ores
