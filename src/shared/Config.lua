-- Tuning numbers for the whole game. Change a value here and press Play to try it.
local Config = {}

-- Survival (hunger is the only survival stat for now)
Config.MaxHunger = 100
Config.HungerDrainPerSecond = 1 / 8 -- full to empty in about 13 minutes
Config.StarveDamagePerSecond = 2

-- Reach
Config.HitRange = 12 -- how far (studs) you can hit trees, rocks and structures from
Config.BuildRange = 24 -- how far away you can place a structure
Config.GridSize = 2 -- structures snap to this grid
Config.SpawnNoBuildRadius = 20 -- nobody can build right on top of the spawn

-- Death
Config.LootSackLifetime = 300 -- seconds before a dropped sack disappears

-- Progression
Config.MaxLevel = 10
function Config.XpForLevel(level: number): number
	-- XP needed to go from `level` to `level + 1`
	return 15 + level * 10
end
Config.XpPerCraft = 5

-- Economy
Config.StartingShells = 0

return Config
