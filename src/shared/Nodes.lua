-- Things in the world you hit to gather from. Each hit knocks drops onto the ground.
-- hp: total gathering power it takes to use it up
-- drops: per hit. `scales` multiplies amount by your tool's power.
-- onDeplete: extra drops when it's used up (trees fall and break into logs)

local Nodes = {
	Pine = {
		name = "Pine Tree",
		material = "wood",
		hp = 16,
		respawn = 90,
		xp = 3,
		falls = true,
		drops = {
			{ item = "log", amount = 1, chance = 0.7, scales = true },
			{ item = "stick", amount = 1, chance = 0.35 },
			{ item = "leaves", amount = 1, chance = 0.35 },
		},
		onDeplete = { { item = "log", amount = 4 } },
	},
	Palm = {
		name = "Palm Tree",
		material = "wood",
		hp = 12,
		respawn = 90,
		xp = 3,
		falls = true,
		drops = {
			{ item = "log", amount = 1, chance = 0.6, scales = true },
			{ item = "leaves", amount = 1, chance = 0.4 },
			{ item = "coconut", amount = 1, chance = 0.15 },
		},
		onDeplete = { { item = "log", amount = 3 }, { item = "coconut", amount = 2 } },
	},
	Boulder = {
		name = "Boulder",
		material = "stone",
		hp = 20,
		respawn = 100,
		xp = 3,
		drops = {
			{ item = "stone", amount = 1, chance = 0.8, scales = true },
		},
		onDeplete = { { item = "stone", amount = 4 } },
	},
	Bush = {
		name = "Berry Bush",
		material = "plant",
		hp = 6,
		respawn = 60,
		xp = 2,
		drops = {
			{ item = "leaves", amount = 1, chance = 0.7, scales = true },
			{ item = "berries", amount = 1, chance = 0.5 },
			{ item = "stick", amount = 1, chance = 0.25 },
		},
	},
	SlimePool = {
		name = "Slime Pool",
		material = "slime",
		hp = 8,
		respawn = 120,
		xp = 4,
		drops = {
			{ item = "sticky_slime", amount = 1, chance = 0.6, scales = true },
		},
	},
}

return Nodes
