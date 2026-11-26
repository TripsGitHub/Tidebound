-- Crafting: check the level, take the materials, give the item.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Recipes = require(Shared.Recipes)
local Remotes = require(Shared.Remotes)
local Inventory = require(script.Parent.Inventory)
local Progression = require(script.Parent.Progression)
local Quests = require(script.Parent.Quests)

local Crafting = {}

function Crafting.onCraft(player: Player, recipeId: unknown)
	if type(recipeId) ~= "string" then
		return
	end
	for _, recipe in Recipes do
		if recipe.id == recipeId then
			if Progression.getLevel(player) < recipe.level then
				Remotes.Notify:FireClient(player, "Reach level " .. recipe.level .. " to craft that.")
				return
			end
			if not Inventory.takeAll(player, recipe.cost) then
				Remotes.Notify:FireClient(player, "You don't have the materials.")
				return
			end
			Inventory.add(player, recipe.id, recipe.amount or 1)
			Progression.addXp(player, Config.XpPerCraft)
			Quests.record(player, "craft", recipe.id, 1)
			Remotes.Notify:FireClient(player, "Crafted " .. Items[recipe.id].name)
			return
		end
	end
end

return Crafting
