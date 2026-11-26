-- Tuning numbers for the whole game. Change a value here and press Play to try it.
local Config = {}

-- Survival (hunger is the only survival stat for now)
Config.MaxHunger = 100
Config.HungerDrainPerSecond = 1 / 8 -- full to empty in about 13 minutes
Config.StarveDamagePerSecond = 2

-- Carrying
Config.BaseBagSize = 30 -- how many items you can carry with no bag equipped

-- Reach
Config.HitRange = 11 -- how far (studs) you can hit things from
Config.PickupRange = 10 -- how far you can pick up dropped items from
Config.BuildRange = 28 -- how far away you can place a structure
Config.GridSize = 2 -- structures snap to this grid
Config.SpawnNoBuildRadius = 25 -- nobody can build right on top of the spawn

-- Drops
Config.DropLifetime = 180 -- seconds before an item on the ground disappears
Config.LootSackLifetime = 300

-- Combat
Config.UnarmedDamage = 5

-- Progression
Config.MaxLevel = 20
function Config.XpForLevel(level: number): number
	-- XP needed to go from `level` to `level + 1`
	return 20 + level * 12
end
Config.XpPerCraft = 5

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

return Config
