-- Keeps track of what every player is carrying and what they are holding.
-- Lives only on the server so it can't be faked by exploiters.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Items)
local Remotes = require(Shared.Remotes)
local HeldItem = require(script.Parent.HeldItem)

type PlayerData = { items: { [string]: number }, equipped: string? }

local Inventory = {}
local data: { [Player]: PlayerData } = {}

function Inventory.init(player: Player)
	data[player] = { items = {}, equipped = nil }
end

function Inventory.removePlayer(player: Player)
	data[player] = nil
end

function Inventory.sync(player: Player)
	local d = data[player]
	if d then
		Remotes.Inventory:FireClient(player, d.items, d.equipped)
	end
end

function Inventory.count(player: Player, itemId: string): number
	local d = data[player]
	return d and d.items[itemId] or 0
end

function Inventory.add(player: Player, itemId: string, amount: number)
	local d = data[player]
	assert(Items[itemId], "Unknown item " .. tostring(itemId))
	if not d or amount <= 0 then
		return
	end
	d.items[itemId] = (d.items[itemId] or 0) + amount
	Inventory.sync(player)
end

function Inventory.hasAll(player: Player, cost: { [string]: number }): boolean
	for itemId, amount in cost do
		if Inventory.count(player, itemId) < amount then
			return false
		end
	end
	return true
end

-- Removes items. Returns false (and removes nothing) if the player doesn't have enough.
function Inventory.takeAll(player: Player, cost: { [string]: number }): boolean
	local d = data[player]
	if not d or not Inventory.hasAll(player, cost) then
		return false
	end
	for itemId, amount in cost do
		local left = d.items[itemId] - amount
		d.items[itemId] = if left > 0 then left else nil
		if left <= 0 and d.equipped == itemId then
			Inventory.setEquipped(player, nil)
		end
	end
	Inventory.sync(player)
	return true
end

function Inventory.take(player: Player, itemId: string, amount: number): boolean
	return Inventory.takeAll(player, { [itemId] = amount })
end

function Inventory.getAll(player: Player): { [string]: number }
	local d = data[player]
	return if d then table.clone(d.items) else {}
end

function Inventory.clear(player: Player)
	local d = data[player]
	if d then
		d.items = {}
		Inventory.setEquipped(player, nil)
		Inventory.sync(player)
	end
end

function Inventory.getEquipped(player: Player): string?
	local d = data[player]
	return d and d.equipped
end

function Inventory.setEquipped(player: Player, itemId: string?)
	local d = data[player]
	if not d then
		return
	end
	if itemId ~= nil and (not Items[itemId] or (d.items[itemId] or 0) <= 0) then
		return
	end
	d.equipped = itemId
	HeldItem.update(player, itemId)
	Inventory.sync(player)
end

return Inventory
