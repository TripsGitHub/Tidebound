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
Config.HeldScale = 1.3 -- tools in your hand are drawn this much bigger
Config.PickupRange = 10 -- how far you can pick up dropped items from
Config.BuildRange = 28 -- how far away you can place a structure
Config.GridSize = 2 -- structures snap to this grid
Config.MaxStructures = 150 -- per player; saved and rebuilt when you come back
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
	-- XP needed to go from `level` to `level + 1`
	return math.floor(15 + level * 3 + level * level * 0.12)
end
-- Recipes and ores are written on a 1-20 scale (see Recipes.lua and Ores.lua); this
-- spreads them over levels 1-200, leaving 200-250 for the very end of the game.
function Config.ScaleLevel(level: number): number
	if level <= 1 then
		return 1
	end
	return math.floor(1 + (level - 1) * 10.5)
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

-- World events (see src/server/Events.lua). Times are in seconds.
Config.Events = {
	EruptionEvery = { 900, 1500 }, -- Ember Isle erupts every 15-25 minutes, leaving Obsidian
	EruptionWarning = 20, -- rumbling before the obsidian spires burst out
	EruptionSpires = { 4, 6 },
	EruptionLasts = 300, -- unmined spires crumble after this long
	MeteorChance = 0.15, -- chance each night brings a meteor shower (Moonstone): rarer than eruptions
	Meteors = { 2, 4 },
}

return Config
