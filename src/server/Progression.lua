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
		local text = "Level up! You are now level " .. level .. "."
		if #unlocked > 0 then
			text ..= " Unlocked: " .. table.concat(unlocked, ", ")
		end
		Remotes.Notify:FireClient(player, text)
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

return Progression
