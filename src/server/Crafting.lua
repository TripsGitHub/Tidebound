-- Crafting: check the level and bag space, take the materials, give the item.
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
				Remotes.Notify:FireClient(player, "Reach level " .. recipe.level .. " first", "warn")
				return
			end
			if not Inventory.takeAll(player, recipe.cost) then
				Remotes.Notify:FireClient(player, "Not enough materials", "warn")
				return
			end
			-- Crafting always frees up at least as much space as it uses, so ignore the limit.
			Inventory.add(player, recipe.id, recipe.amount or 1, true)
			Progression.addXp(player, Config.XpPerCraft)
			Quests.record(player, "craft", recipe.id, 1)
			Remotes.Notify:FireClient(player, "Crafted " .. Items[recipe.id].name, "good")
			return
		end
	end
end

return Crafting
