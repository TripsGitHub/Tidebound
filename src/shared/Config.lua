-- Tuning numbers for the whole game. Change a value here and press Play to try it.
local Config = {}

-- Survival (hunger is the only survival stat for now)
Config.MaxHunger = 100
Config.HungerDrainPerSecond = 1 / 8 -- full to empty in about 13 minutes
Config.StarveDamagePerSecond = 2
Config.FoodHealScale = 1.5 -- food heals this much more than its listed heal (no passive regen)

-- Carrying
Config.BaseBagSize = 40 -- how many items you can carry with no bag equipped

-- Reach
Config.HitRange = 11 -- how far (studs) you can hit things from
Config.HeldScale = 1.3 -- tools in your hand are drawn this much bigger
Config.PickupRange = 10 -- how far you can pick up dropped items from
Config.BuildRange = 36 -- how far away you can place a structure
Config.GridSize = 2 -- structures snap to this grid
Config.MaxStructures = 250 -- per player; saved and rebuilt when you come back
Config.MaxLooseStructures = 120 -- per player, built away from their base (not saved)
Config.ChestCapacity = 400 -- items one storage chest holds
Config.SpawnNoBuildRadius = 25 -- nobody can build right on top of the spawn

-- Drops
Config.DropScale = 2 -- items on the ground are drawn this much bigger than their icon model
Config.DropLifetime = 180 -- seconds before an item on the ground disappears
Config.LootSackLifetime = 300

-- Combat
Config.UnarmedDamage = 5
Config.BaseAir = 15 -- seconds of air under water with no diving gear
Config.AirRefillRate = 6 -- air comes back this many times faster than it runs out
Config.DrownDamagePerSecond = 10

-- Progression
-- Levels run to 250 on a slow curve: quick at first, then a long grind.
Config.MaxLevel = 250
function Config.XpForLevel(level: number): number
	-- XP needed to go from `level` to `level + 1`. The first levels come quickly so
	-- new players get going; the full curve kicks in by level 10.
	local early = math.min(1, 0.45 + level * 0.055)
	return math.floor((15 + level * 3 + level * level * 0.12) * early)
end
-- Early levels earn extra XP so new players see the loop (gather, craft, level up,
-- unlock) within minutes: double XP to level 10, easing back to normal by level 30.
function Config.XpBonus(level: number): number
	if level <= 10 then
		return 2
	end
	return math.max(1, 2 - (level - 10) / 20)
end
-- XP for each piece a campfire smelts, by what goes in (rarer ore, more XP).
Config.SmeltXp = { silver_ore = 10, gold_ore = 18, sunstone = 30, raw_meat = 3, raw_fish = 3, mushroom = 2, potato = 2 }
-- Recipes and ores are written on a 1-20 scale (see Recipes.lua and Ores.lua); this
-- spreads them over levels 1-200 on a curve, leaving 200-250 for the very end of the
-- game. Wood gear stays in the first few levels (1-8), stone around 20-35, and the
-- gaps widen from there.
function Config.ScaleLevel(level: number): number
	if level <= 1 then
		return 1
	end
	return math.floor(1 + (level - 1) ^ 1.75 * 1.15 + 0.5)
end

-- Items you get for reaching a level, so the early game has something every step.
-- Past level 20: a Supply Crate every 5 levels, plus Shells every level.
Config.LevelRewards = {
	[2] = { berries = 5, log = 5 },
	[3] = { stick = 6, stone = 8, leather = 3 },
	[4] = { cooked_meat = 3, leaves = 8 },
	[5] = { stone = 12, supply_crate = 1 },
	[7] = { log = 12, stone = 10 },
	[9] = { leather = 5, cooked_meat = 3 },
	[10] = { supply_crate = 1, sticky_slime = 4 },
	[12] = { cooked_meat = 5, leather = 5 },
	[15] = { aqua_mask = 1, supply_crate = 1 },
	[20] = { supply_crate = 2 },
}
-- Which crate a level-up hands out: the loot matches the level you reached, so early
-- crates hold early materials and late crates hold late ones.
function Config.crateForLevel(level: number): string
	if level >= 150 then
		return "mythic_crate"
	elseif level >= 80 then
		return "epic_crate"
	elseif level >= 30 then
		return "rare_crate"
	end
	return "supply_crate"
end
function Config.rewardsFor(level: number): { [string]: number }
	local listed = Config.LevelRewards[level] or {}
	local r = {}
	for id, n in listed do
		-- "supply_crate" in the table means "the crate for this level".
		local key = if id == "supply_crate" then Config.crateForLevel(level) else id
		r[key] = (r[key] or 0) + n
	end
	if level > 20 and level % 5 == 0 then
		local crate = Config.crateForLevel(level)
		r[crate] = (r[crate] or 0) + 1 + math.floor(level / 100)
	end
	return r
end
-- Hotbar slots grow with your level: 5 to start, up to 10.
Config.HotbarSlots = { { 1, 5 }, { 25, 6 }, { 60, 7 }, { 100, 8 }, { 150, 9 }, { 200, 10 } }
function Config.hotbarSlotsFor(level: number): number
	local n = 5
	for _, step in Config.HotbarSlots do
		if level >= step[1] then
			n = step[2]
		end
	end
	return n
end
Config.XpPerCraft = 8

-- World
Config.DayLengthSeconds = 720 -- one full day/night cycle (12 minutes)

-- Optional assets. Paste an id like "rbxassetid://1234567890" to turn one on.
-- Animations must be published from your own Roblox account (see README).
Config.Animations = {
	Swing = "",
}
Config.Sounds = {
	ChopWood = "",
	HitStone = "",
	HitFlesh = "",
	Pickup = "",
	TreeFall = "",
}

Config.StartingShells = 0

-- World events (see src/server/Events.lua). Times are in seconds.
Config.Events = {
	EruptionEvery = { 900, 1500 }, -- Ember Isle erupts every 15-25 minutes, leaving Obsidian
	EruptionWarning = 20, -- rumbling before the obsidian spires burst out
	EruptionSpires = { 4, 6 },
	EruptionLasts = 300, -- unmined spires crumble after this long
	MeteorChance = 0.06, -- chance each night brings a meteor shower (Moonstone): much rarer than eruptions
	Meteors = { 1, 2 },
}

return Config
