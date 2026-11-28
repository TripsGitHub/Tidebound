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

-- The last buildable you crafted and haven't placed yet: cancel the build and you
-- get its materials back.
local pending: { [Player]: { id: string, cost: { [string]: number }, amount: number } } = {}

function Crafting.onCraft(player: Player, recipeId: unknown)
	if type(recipeId) ~= "string" then
		return
	end
	for _, recipe in Recipes do
		if recipe.id == recipeId then
			if recipe.trader then
				local ok, why = require(script.Parent.Traders).canCraft(player, recipe.id)
				if not ok then
					Remotes.Notify:FireClient(player, why or "Only the wandering merchant can make that", "warn")
					return
				end
			end
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
			if Items[recipe.id].kind == "placeable" then
				-- Straight into placing it.
				pending[player] = { id = recipe.id, cost = recipe.cost, amount = recipe.amount or 1 }
				Inventory.setEquipped(player, recipe.id)
			end
			return
		end
	end
end

-- Called when a buildable is placed: it's no longer refundable.
function Crafting.placed(player: Player, itemId: string)
	local p = pending[player]
	if p and p.id == itemId then
		pending[player] = nil
	end
end

-- Cancel build: put the buildable away, and refund it if it was just crafted.
function Crafting.cancelBuild(player: Player)
	local p = pending[player]
	pending[player] = nil
	if p and Inventory.count(player, p.id) >= p.amount and Inventory.take(player, p.id, p.amount) then
		for id, n in p.cost do
			Inventory.add(player, id, n, true)
		end
		Remotes.Notify:FireClient(player, "Refunded " .. Items[p.id].name, "good")
	end
	Inventory.setEquipped(player, nil)
end

function Crafting.removePlayer(player: Player)
	pending[player] = nil
end

return Crafting
