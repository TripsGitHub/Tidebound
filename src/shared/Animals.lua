-- Animals you can hunt.
-- loot: { item, min, max, chance? } rolled when it dies; chance is the odds that line
-- drops at all (none means always). Bosses drop parts you can't get anywhere else.
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
		loot = { { "raw_meat", 1, 3 }, { "leather", 1, 3 }, { "supply_crate", 1, 1, 0.02 } },
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
		loot = { { "raw_meat", 1, 1 }, { "raw_fish", 0, 1 }, { "stone", 0, 2 }, { "supply_crate", 1, 1, 0.01 } },
	},
	-- Mountain goats on the Crags and the Mesa. Skittish; butts back if cornered.
	Goat = {
		name = "Goat",
		hp = 45,
		damage = 6,
		attackCooldown = 1.3,
		walkSpeed = 6,
		runSpeed = 17,
		xp = 9,
		respawn = 60,
		loot = { { "raw_meat", 1, 2 }, { "leather", 1, 3 }, { "silver_ore", 1, 1, 0.08 } },
	},
	-- Turtles plod along the beaches. Tough shells, slow to anger.
	Turtle = {
		name = "Turtle",
		hp = 70,
		damage = 5,
		attackCooldown = 1.8,
		walkSpeed = 2.5,
		runSpeed = 5,
		xp = 12,
		respawn = 90,
		loot = { { "raw_meat", 1, 2 }, { "raw_fish", 1, 2 }, { "leather", 1, 2 }, { "supply_crate", 1, 1, 0.05 } },
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
		loot = { { "raw_meat", 1, 3 }, { "leather", 2, 4 }, { "silver_ore", 1, 2, 0.15 }, { "supply_crate", 1, 1, 0.04 } },
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
		scale = 2.2, -- big wobbling blobs, about chest high
		loot = { { "sticky_slime", 2, 4 }, { "gold_ore", 1, 1, 0.06 } },
	},
	-- The same slime, gone pale and glowing in the upper and lower caves.
	CaveSlime = {
		name = "Cave Slime",
		model = "BogSlime",
		cave = true,
		hp = 90,
		damage = 12,
		attackCooldown = 1.3,
		walkSpeed = 4,
		runSpeed = 9,
		xp = 24,
		respawn = 90,
		aggro = 18,
		scale = 2.6,
		tint = Color3.fromRGB(90, 200, 190),
		loot = { { "sticky_slime", 3, 5 }, { "silver_ore", 1, 2, 0.25 }, { "key_fragment", 1, 1, 0.12 } },
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
		loot = { { "stone", 3, 6 }, { "leather", 1, 2 }, { "sunstone", 1, 1, 0.1 }, { "rare_crate", 1, 1, 0.06 } },
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
		loot = { { "leather", 1, 3 }, { "sticky_slime", 1, 3 }, { "gold_ore", 1, 2, 0.2 }, { "key_fragment", 1, 1, 0.35 }, { "rare_crate", 1, 1, 0.08 } },
	},

	-- Bosses: one in each lair below the Maw. `reach` is how close they bite from,
	-- `boss` puts their name over them and they never wander out of the lair.
	CrawlerQueen = {
		name = "Crawler Queen",
		hp = 4500,
		damage = 32,
		attackCooldown = 1.6,
		walkSpeed = 3,
		runSpeed = 5,
		roam = 16, -- barely leaves the middle of its lair
		xp = 600,
		respawn = 900,
		aggro = 45,
		reach = 9,
		cave = true,
		boss = true,
		loot = { { "queen_fang", 1, 1 }, { "epic_crate", 1, 2 }, { "mythic_crate", 1, 1, 0.25 }, { "key_fragment", 1, 2 }, { "diamond", 2, 4 }, { "diamond", 2, 3, 0.5 } },
	},
	CrystalWarden = {
		name = "Crystal Warden",
		hp = 6500,
		damage = 40,
		attackCooldown = 2,
		walkSpeed = 3,
		runSpeed = 5,
		roam = 16, -- barely leaves the middle of its lair
		xp = 800,
		respawn = 900,
		aggro = 40,
		reach = 11,
		cave = true,
		boss = true,
		loot = { { "warden_core", 1, 1 }, { "epic_crate", 1, 2 }, { "mythic_crate", 1, 1, 0.35 }, { "key_fragment", 1, 2 }, { "amethyst", 1, 3, 0.6 }, { "amethyst", 2, 3 } },
	},
	MagmaGolem = {
		name = "Magma Golem",
		hp = 8500,
		damage = 48,
		attackCooldown = 2.2,
		walkSpeed = 3,
		runSpeed = 5,
		roam = 16, -- barely leaves the middle of its lair
		xp = 1000,
		respawn = 1200,
		aggro = 40,
		reach = 12,
		cave = true,
		boss = true,
		loot = { { "golem_heart", 1, 1 }, { "epic_crate", 2, 2 }, { "mythic_crate", 1, 1, 0.5 }, { "key_fragment", 1, 2 }, { "obsidian", 2, 4 }, { "amethyst", 1, 2, 0.5 } },
	},
}

return Animals
