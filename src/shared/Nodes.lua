-- Things in the world you can hit to gather from.
-- hp: how much gathering power it takes to use it up
-- drops: what each hit gives. `scales = true` multiplies the amount by your tool's power.

local Nodes = {
	Palm = {
		material = "wood",
		hp = 14,
		respawn = 60,
		xp = 3,
		drops = {
			{ item = "wood", amount = 1, chance = 1, scales = true },
			{ item = "coconut", amount = 1, chance = 0.12 },
		},
	},
	Boulder = {
		material = "stone",
		hp = 16,
		respawn = 75,
		xp = 3,
		drops = {
			{ item = "stone", amount = 1, chance = 1, scales = true },
		},
	},
	Bush = {
		material = "plant",
		hp = 6,
		respawn = 45,
		xp = 2,
		drops = {
			{ item = "fiber", amount = 1, chance = 1, scales = true },
			{ item = "berries", amount = 1, chance = 0.5 },
		},
	},
	SlimePool = {
		material = "slime",
		hp = 8,
		respawn = 90,
		xp = 4,
		drops = {
			{ item = "sticky_slime", amount = 1, chance = 0.6, scales = true },
		},
	},
}

return Nodes
