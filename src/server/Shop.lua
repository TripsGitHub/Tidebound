-- The trader: spend Shells on supplies.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Items)
local ShopList = require(Shared.Shop)
local Remotes = require(Shared.Remotes)
local Inventory = require(script.Parent.Inventory)
local Progression = require(script.Parent.Progression)

local Shop = {}

function Shop.onBuy(player: Player, entryId: unknown)
	if type(entryId) ~= "string" then
		return
	end
	for _, entry in ShopList do
		if entry.id == entryId then
			if Inventory.space(player) < entry.amount then
				Remotes.Notify:FireClient(player, "Bag too full!", "warn")
				return
			end
			if not Progression.spendShells(player, entry.price) then
				Remotes.Notify:FireClient(player, "Not enough Shells", "warn")
				return
			end
			Inventory.add(player, entry.item, entry.amount)
			Remotes.Notify:FireClient(player, "Bought " .. entry.amount .. " " .. Items[entry.item].name, "good")
			return
		end
	end
end

return Shop
