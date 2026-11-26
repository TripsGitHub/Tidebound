-- Things in the world you hit to gather from.
-- Hits only wear a node down. Nothing drops and no XP is given until it breaks;
-- then everything in `drops` spills out at once and the player gets `xp`.
-- hp: total gathering power it takes to break (better tools hit harder)
-- drops: { item, min, max } rolled once when it breaks

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

return Nodes
