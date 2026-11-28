-- Levels, XP and Shells. Stored as attributes on the Player so the UI can read them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Recipes = require(Shared.Recipes)
local Remotes = require(Shared.Remotes)

local Progression = {}

function Progression.init(player: Player)
	player:SetAttribute("Level", 1)
	player:SetAttribute("XP", 0)
	player:SetAttribute("Shells", Config.StartingShells)
end

function Progression.getLevel(player: Player): number
	return player:GetAttribute("Level") or 1
end

function Progression.addXp(player: Player, amount: number)
	local level = Progression.getLevel(player)
	if level >= Config.MaxLevel then
		return
	end
	amount = math.floor(amount * Config.XpBonus(level) + 0.5)
	local xp = (player:GetAttribute("XP") or 0) + amount
	while level < Config.MaxLevel and xp >= Config.XpForLevel(level) do
		xp -= Config.XpForLevel(level)
		level += 1
		local unlocked = {}
		for _, recipe in Recipes do
			if recipe.level == level then
				table.insert(unlocked, Items[recipe.id].name)
			end
		end
		local text = "Level " .. level .. "!"
		if #unlocked > 0 then
			text ..= "  Unlocked: " .. table.concat(unlocked, ", ")
		end
		Remotes.Notify:FireClient(player, text, "good")
		-- Level rewards go straight into your bag (even if it's full), plus Shells.
		local Inventory = require(script.Parent.Inventory)
		local got = {}
		for id, n in Config.rewardsFor(level) do
			if Items[id] then
				Inventory.add(player, id, n, true)
				Remotes.PickedUp:FireClient(player, id, n)
				table.insert(got, n .. " " .. Items[id].name)
			end
		end
		player:SetAttribute("Shells", (player:GetAttribute("Shells") or 0) + level * 2)
		if #got > 0 then
			Remotes.Notify:FireClient(player, "Level reward: " .. table.concat(got, ", "), "good")
		end
	end
	if level >= Config.MaxLevel then
		xp = 0
	end
	player:SetAttribute("Level", level)
	player:SetAttribute("XP", xp)
end

function Progression.getShells(player: Player): number
	return player:GetAttribute("Shells") or 0
end

function Progression.addShells(player: Player, amount: number)
	player:SetAttribute("Shells", Progression.getShells(player) + amount)
end

function Progression.spendShells(player: Player, amount: number): boolean
	local shells = Progression.getShells(player)
	if shells < amount then
		return false
	end
	player:SetAttribute("Shells", shells - amount)
	return true
end

-- For saving.
function Progression.export(player: Player): { level: number, xp: number, shells: number }
	return {
		level = Progression.getLevel(player),
		xp = player:GetAttribute("XP") or 0,
		shells = Progression.getShells(player),
	}
end

function Progression.load(player: Player, saved: { [string]: any })
	if type(saved) ~= "table" then
		return
	end
	local function num(v: any, lo: number, hi: number): number?
		return if type(v) == "number" and v == v then math.clamp(math.floor(v), lo, hi) else nil
	end
	player:SetAttribute("Level", num(saved.level, 1, Config.MaxLevel) or 1)
	player:SetAttribute("XP", num(saved.xp, 0, math.huge) or 0)
	player:SetAttribute("Shells", num(saved.shells, 0, math.huge) or Config.StartingShells)
end

return Progression
