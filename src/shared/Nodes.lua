-- Things in the world you hit to gather from.
-- Hits only wear a node down. Nothing drops and no XP is given until it breaks;
-- then everything in `drops` spills out at once and the player gets `xp`.
-- hp: total gathering power it takes to break (better tools hit harder)
-- drops: { item, min, max } rolled once when it breaks
-- minPower: the tool's gathering power for this material must be at least this much

local Nodes = {
	Pine = {
		name = "Pine Tree",
		material = "wood",
		hp = 16,
		respawn = 90,
		xp = 12,
		falls = true,
		drops = {
			{ item = "log", min = 4, max = 5 },
			{ item = "stick", min = 1, max = 2 },
			{ item = "leaves", min = 1, max = 3 },
		},
	},
	Palm = {
		name = "Palm Tree",
		material = "wood",
		hp = 12,
		respawn = 90,
		xp = 10,
		falls = true,
		drops = {
			{ item = "log", min = 3, max = 4 },
			{ item = "leaves", min = 1, max = 2 },
			{ item = "coconut", min = 1, max = 2 },
		},
	},
	-- Sunfruit Isle's palms: heavy with fruit.
	FruitPalm = {
		name = "Sunfruit Palm",
		material = "wood",
		hp = 12,
		respawn = 90,
		xp = 12,
		falls = true,
		drops = {
			{ item = "log", min = 3, max = 4 },
			{ item = "leaves", min = 1, max = 2 },
			{ item = "sunfruit", min = 2, max = 3 },
		},
	},
	Boulder = {
		name = "Boulder",
		material = "stone",
		hp = 20,
		respawn = 100,
		xp = 14,
		drops = {
			{ item = "stone", min = 4, max = 6 },
		},
	},
	Bush = {
		name = "Berry Bush",
		material = "plant",
		hp = 6,
		respawn = 60,
		xp = 5,
		drops = {
			{ item = "leaves", min = 2, max = 3 },
			{ item = "berries", min = 1, max = 3 },
			{ item = "stick", min = 0, max = 1 },
		},
	},
	SlimePool = {
		name = "Slime Pool",
		material = "slime",
		hp = 8,
		respawn = 120,
		xp = 15,
		drops = {
			{ item = "sticky_slime", min = 2, max = 3 },
		},
	},
}

-- One ore vein or crystal cluster per tier from Silver up (see Ores.lua). They take
-- about 14 hits with the weakest harvester that can mine them, fewer with better ones.
for _, ore in require(script.Parent.Ores) do
	local p = ore.minPower
	Nodes[ore.node] = {
		name = ore.nodeName,
		material = "stone",
		minPower = p,
		ore = ore.item,
		tier = ore.tier,
		look = ore.look,
		hp = 14 * p,
		respawn = 120 + 15 * p,
		xp = 15 + 6 * p,
		drops = {
			{ item = ore.item, min = 2, max = 4 },
			{ item = "stone", min = 1, max = 2 },
		},
	}
end

return Nodes
