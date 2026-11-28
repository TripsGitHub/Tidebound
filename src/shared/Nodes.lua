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
		drops = {
			{ item = "log", min = 3, max = 4 },
			{ item = "leaves", min = 1, max = 2 },
			{ item = "coconut", min = 1, max = 2 },
		},
	},
	-- Cave seals: cracked rock plugging the way down to the next cave layer. You need
	-- any sword to break one (better swords hit harder), and it grows back after a while.
	-- Each layer down is tougher: more HP.
	CaveSealLower = {
		seal = true,
		name = "Cave Seal (Lower Caves)",
		material = "stone",
		hp = 400,
		minPower = 3,
		respawn = 600,
		xp = 40,
		drops = { { item = "stone", min = 6, max = 9 } },
	},
	CaveSealMid = {
		seal = true,
		name = "Cave Seal (Middle Caves)",
		material = "stone",
		hp = 700,
		minPower = 4,
		respawn = 600,
		xp = 60,
		drops = { { item = "stone", min = 7, max = 10 }, { item = "silver_ore", min = 0, max = 2 } },
	},
	CaveSealDeep = {
		seal = true,
		name = "Cave Seal (Deep Network)",
		material = "stone",
		hp = 1100,
		minPower = 5,
		respawn = 600,
		xp = 90,
		drops = { { item = "stone", min = 8, max = 12 }, { item = "gold_ore", min = 0, max = 1 } },
	},
	CaveSealAbyss = {
		seal = true,
		name = "Cave Seal (Abyss)",
		material = "stone",
		hp = 1700,
		minPower = 6,
		respawn = 750,
		xp = 130,
		drops = { { item = "stone", min = 8, max = 12 }, { item = "sunstone", min = 0, max = 1 } },
	},
	CaveSealCrystal = {
		seal = true,
		name = "Crystal Seal",
		material = "stone",
		hp = 2400,
		minPower = 7,
		respawn = 900,
		xp = 160,
		drops = { { item = "stone", min = 8, max = 12 }, { item = "sunstone", min = 0, max = 2 } },
	},
	CaveSealMaw = {
		seal = true,
		name = "Maw Seal",
		material = "stone",
		hp = 3400,
		minPower = 7,
		respawn = 900,
		xp = 250,
		drops = { { item = "stone", min = 10, max = 14 }, { item = "diamond", min = 0, max = 1 } },
	},
	-- Tide Seals: coral-crusted rock shutting the sunken grottos (Grottos.lua). Unlike
	-- the cave seals they need a strong sword: swordTier is the weakest that cracks one.
	TideSeal = {
		seal = true,
		swordTier = "diamond",
		name = "Tide Seal",
		material = "stone",
		hp = 2600,
		minPower = 6,
		respawn = 900,
		xp = 220,
		drops = { { item = "stone", min = 8, max = 12 }, { item = "diamond", min = 0, max = 1 } },
	},
	AbyssSeal = {
		seal = true,
		swordTier = "obsidian",
		name = "Abyss Seal",
		material = "stone",
		hp = 4500,
		minPower = 9,
		respawn = 1200,
		xp = 400,
		drops = { { item = "stone", min = 10, max = 14 }, { item = "amethyst", min = 0, max = 1 } },
	},
	-- The Banana Giant on Banana Isle: a huge banana palm you can chop down for a pile
	-- of fruit and logs. Takes a long time to grow back. (Id kept from the old Sunfruit
	-- Giant so saves and the bake still line up.)
	SunfruitGiant = {
		name = "Banana Giant",
		material = "wood",
		hp = 260,
		respawn = 1800,
		xp = 160,
		drops = {
			{ item = "log", min = 12, max = 16 },
			{ item = "leaves", min = 6, max = 8 },
			{ item = "banana", min = 14, max = 20 },
		},
	},
	-- Sunfruit Isle's palms: heavy with fruit.
	FruitPalm = {
		name = "Sunfruit Palm",
		material = "wood",
		hp = 12,
		respawn = 90,
		xp = 12,
		drops = {
			{ item = "log", min = 3, max = 4 },
			{ item = "leaves", min = 1, max = 2 },
			{ item = "sunfruit", min = 2, max = 3 },
		},
	},
	-- Banana Isle's palms: heavy bunches of bananas.
	BananaPalm = {
		name = "Banana Palm",
		material = "wood",
		hp = 12,
		respawn = 90,
		xp = 12,
		drops = {
			{ item = "log", min = 3, max = 4 },
			{ item = "leaves", min = 1, max = 2 },
			{ item = "banana", min = 2, max = 4 },
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
			{ item = "mushroom", min = 0, max = 1 },
		},
	},
	-- A patch of wild crops on bare soil: forage for food and leaves.
	CropPatch = {
		name = "Wild Crops",
		material = "plant",
		hp = 10,
		respawn = 120,
		xp = 8,
		drops = {
			{ item = "berries", min = 2, max = 4 },
			{ item = "leaves", min = 1, max = 3 },
			{ item = "sunfruit", min = 0, max = 1 },
			{ item = "mango", min = 0, max = 1 },
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
			{ item = "slime_spore", min = 0, max = 1 },
		},
	},
	-- Wild crops: dig them up for a bite now and seeds to grow more in a Plant Box.
	WildCarrots = {
		name = "Wild Carrots",
		material = "plant",
		hp = 5,
		respawn = 90,
		xp = 6,
		drops = {
			{ item = "carrot", min = 1, max = 2 },
			{ item = "carrot_seeds", min = 1, max = 2 },
		},
	},
	WildPotatoes = {
		name = "Wild Potatoes",
		material = "plant",
		hp = 5,
		respawn = 90,
		xp = 6,
		drops = {
			{ item = "potato", min = 1, max = 2 },
			{ item = "potato_seeds", min = 1, max = 2 },
		},
	},
	WildMelons = {
		name = "Wild Melons",
		material = "plant",
		hp = 7,
		respawn = 120,
		xp = 8,
		drops = {
			{ item = "watermelon", min = 1, max = 1 },
			{ item = "watermelon_seeds", min = 1, max = 2 },
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
