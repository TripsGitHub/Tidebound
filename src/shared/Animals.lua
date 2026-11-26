-- Animals you can hunt.
local Animals = {
	Boar = {
		name = "Boar",
		hp = 60,
		damage = 8, -- per bite once angry
		attackCooldown = 1.4,
		walkSpeed = 6,
		runSpeed = 16,
		xp = 10,
		respawn = 60,
		drops = { { item = "raw_meat", amount = 2 }, { item = "leather", amount = 2 } },
	},
}

return Animals
