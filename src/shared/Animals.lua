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
	-- Beaches and atolls. Scuttles off, pinches back.
	Crab = {
		name = "Crab",
		hp = 30,
		damage = 5,
		attackCooldown = 1.1,
		walkSpeed = 5,
		runSpeed = 14,
		xp = 6,
		respawn = 45,
		drops = { { item = "raw_meat", amount = 1 } },
	},
	-- Frost Isle and the Silver Crags. Hunts in packs: comes for you if you get close.
	Wolf = {
		name = "Wolf",
		hp = 85,
		damage = 12,
		attackCooldown = 1.2,
		walkSpeed = 7,
		runSpeed = 18,
		xp = 22,
		respawn = 90,
		aggro = 32,
		drops = { { item = "raw_meat", amount = 2 }, { item = "leather", amount = 3 } },
	},
	-- Slime Marsh. Wobbles at you if you stand too close.
	BogSlime = {
		name = "Bog Slime",
		hp = 50,
		damage = 8,
		attackCooldown = 1.3,
		walkSpeed = 4,
		runSpeed = 9,
		xp = 14,
		respawn = 60,
		aggro = 14,
		drops = { { item = "sticky_slime", amount = 3 } },
	},
	-- Ember Isle's slopes. Slow, tough, hits hard.
	CinderBeetle = {
		name = "Cinder Beetle",
		hp = 140,
		damage = 18,
		attackCooldown = 1.6,
		walkSpeed = 5,
		runSpeed = 12,
		xp = 40,
		respawn = 120,
		aggro = 24,
		drops = { { item = "stone", amount = 4 }, { item = "leather", amount = 2 } },
	},
	-- The lower and deep caves. Waits in the dark and rushes anyone who comes near:
	-- go down with friends.
	CaveCrawler = {
		name = "Cave Crawler",
		hp = 110,
		damage = 15,
		attackCooldown = 1.2,
		walkSpeed = 6,
		runSpeed = 17,
		xp = 45,
		respawn = 150,
		aggro = 30,
		cave = true,
		drops = { { item = "leather", amount = 2 }, { item = "sticky_slime", amount = 2 } },
	},
}

return Animals
