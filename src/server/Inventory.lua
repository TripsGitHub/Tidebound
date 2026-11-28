-- What every player carries, holds and wears. Lives on the server so it can't be faked.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Remotes = require(Shared.Remotes)
local Appearance = require(script.Parent.Appearance)

type PlayerData = {
	items: { [string]: number },
	equipped: string?,
	armour: { [string]: string }, -- slot -> itemId (worn items stay counted in items)
}

local Inventory = {}
local data: { [Player]: PlayerData } = {}

function Inventory.init(player: Player)
	data[player] = { items = {}, equipped = nil, armour = {} }
end

function Inventory.removePlayer(player: Player)
	data[player] = nil
end

function Inventory.bagSize(player: Player): number
	local d = data[player]
	local bag = d and d.armour.bag
	return if bag then Items[bag].bagSize or Config.BaseBagSize else Config.BaseBagSize
end

function Inventory.used(player: Player): number
	local d = data[player]
	if not d then
		return 0
	end
	local total = 0
	for itemId, count in d.items do
		-- Worn armour and your bag don't take up bag space.
		local item = Items[itemId]
		local worn = item.kind == "armour" and d.armour[item.slot] == itemId
		total += if worn then count - 1 else count
	end
	return total
end

function Inventory.space(player: Player): number
	return math.max(0, Inventory.bagSize(player) - Inventory.used(player))
end

function Inventory.sync(player: Player)
	local d = data[player]
	if d then
		Remotes.Inventory:FireClient(player, d.items, d.equipped, d.armour, Inventory.bagSize(player))
		player:SetAttribute("BagUsed", Inventory.used(player))
		player:SetAttribute("BagSize", Inventory.bagSize(player))
		-- Armour %s for the badges over everyone's nameplate.
		player:SetAttribute("DefMob", math.floor(Inventory.defense(player, "mob") * 1000 + 0.5) / 10)
		player:SetAttribute("DefPlayer", math.floor(Inventory.defense(player, "player") * 1000 + 0.5) / 10)
		-- The tier most of your armour is made of (chestplate wins a tie), so the
		-- shield badge can be drawn in that material.
		local votes, best, bestN = {}, nil, 0
		for slot, id in d.armour do
			local t = string.match(id, "^(.-)_") 
			if t and slot ~= "bag" then
				votes[t] = (votes[t] or 0) + (if slot == "body" then 1.5 else 1)
				if votes[t] > bestN then
					best, bestN = t, votes[t]
				end
			end
		end
		player:SetAttribute("ArmourTier", best)
	end
end

function Inventory.count(player: Player, itemId: string): number
	local d = data[player]
	return d and d.items[itemId] or 0
end

-- Adds up to `amount`, limited by bag space unless `ignoreSpace`. Returns how many were added.
function Inventory.add(player: Player, itemId: string, amount: number, ignoreSpace: boolean?): number
	local d = data[player]
	assert(Items[itemId], "Unknown item " .. tostring(itemId))
	if not d or amount <= 0 then
		return 0
	end
	local n = if ignoreSpace then amount else math.min(amount, Inventory.space(player))
	if n > 0 then
		d.items[itemId] = (d.items[itemId] or 0) + n
		Inventory.sync(player)
	end
	return n
end

function Inventory.hasAll(player: Player, cost: { [string]: number }): boolean
	for itemId, amount in cost do
		if Inventory.count(player, itemId) < amount then
			return false
		end
	end
	return true
end

function Inventory.takeAll(player: Player, cost: { [string]: number }): boolean
	local d = data[player]
	if not d or not Inventory.hasAll(player, cost) then
		return false
	end
	for itemId, amount in cost do
		local left = d.items[itemId] - amount
		d.items[itemId] = if left > 0 then left else nil
		if left <= 0 then
			if d.equipped == itemId then
				d.equipped = nil
				Appearance.setTool(player, nil)
			end
			local item = Items[itemId]
			if item.kind == "armour" and d.armour[item.slot] == itemId then
				d.armour[item.slot] = nil
				Appearance.setArmour(player, d.armour)
			end
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

function Inventory.getArmour(player: Player): { [string]: string }
	local d = data[player]
	return if d then table.clone(d.armour) else {}
end

-- Removes everything except the listed item ids.
function Inventory.clearExcept(player: Player, keep: { [string]: boolean })
	local d = data[player]
	if not d then
		return
	end
	local newItems = {}
	for itemId, count in d.items do
		if keep[itemId] then
			newItems[itemId] = 1
		end
	end
	d.items = newItems
	for slot, itemId in d.armour do
		if not newItems[itemId] then
			d.armour[slot] = nil
		end
	end
	if d.equipped and not newItems[d.equipped] then
		d.equipped = nil
	end
	Appearance.setArmour(player, d.armour)
	Appearance.setTool(player, d.equipped)
	Inventory.sync(player)
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
	if itemId ~= nil then
		local item = Items[itemId]
		if not item or (d.items[itemId] or 0) <= 0 or item.kind == "resource" or item.kind == "armour" then
			return
		end
	end
	d.equipped = itemId
	Appearance.setTool(player, itemId)
	Inventory.sync(player)
end

-- Put on a piece of armour, or take it off if it's already worn.
function Inventory.toggleWear(player: Player, itemId: string)
	local d = data[player]
	local item = Items[itemId]
	if not d or not item or item.kind ~= "armour" or (d.items[itemId] or 0) <= 0 then
		return
	end
	if d.armour[item.slot] == itemId then
		if item.slot == "bag" then
			-- Taking the bag off would overflow it.
			local after = Inventory.used(player) + 1
			if after > Config.BaseBagSize then
				Remotes.Notify:FireClient(player, "Empty your bag before taking it off.", "warn")
				return
			end
		end
		d.armour[item.slot] = nil
	else
		d.armour[item.slot] = itemId
	end
	Appearance.setArmour(player, d.armour)
	Inventory.sync(player)
end

-- Total damage reduction from worn armour (0 to 0.9).
-- How much of a hit the player's armour blocks (0..0.9). `vs` is what's hitting them:
-- "mob" (animals, bosses) or "player"; each set is better against one or the other.
function Inventory.defense(player: Player, vs: string?): number
	local d = data[player]
	if not d then
		return 0
	end
	local total = 0
	for _, itemId in d.armour do
		local item = Items[itemId]
		local mult = if vs == "mob" then item.vsMob elseif vs == "player" then item.vsPlayer else 1
		total += (item.defense or 0) * (mult or 1)
	end
	return math.min(total, 0.9)
end

-- A copy of what the player has, for saving. Plain tables only (DataStore-safe).
function Inventory.export(player: Player): { items: { [string]: number }, armour: { [string]: string }, equipped: string? }?
	local d = data[player]
	if not d then
		return nil
	end
	return { items = table.clone(d.items), armour = table.clone(d.armour), equipped = d.equipped }
end

-- Restores saved items. Anything that no longer exists in Items.lua is dropped, and
-- armour only goes back on if the player still has it and it fits that slot.
function Inventory.load(player: Player, saved: { [string]: any })
	local d = data[player]
	if not d or type(saved) ~= "table" then
		return
	end
	local items = {}
	if type(saved.items) == "table" then
		for itemId, count in saved.items do
			if type(itemId) == "string" and Items.LEGACY[itemId] then
				itemId = Items.LEGACY[itemId]
			end
			if type(itemId) == "string" and Items[itemId] and type(count) == "number" and count >= 1 then
				items[itemId] = (items[itemId] or 0) + math.floor(count)
			end
		end
	end
	local armour = {}
	if type(saved.armour) == "table" then
		for slot, itemId in saved.armour do
			local item = type(itemId) == "string" and Items[itemId]
			if item and item.kind == "armour" and item.slot == slot and items[itemId] then
				armour[slot] = itemId
			end
		end
	end
	d.items = items
	d.armour = armour
	d.equipped = if type(saved.equipped) == "string" and items[saved.equipped] then saved.equipped else nil
	Inventory.sync(player)
end

function Inventory.reapplyAppearance(player: Player)
	local d = data[player]
	if d then
		Appearance.setArmour(player, d.armour)
		Appearance.setTool(player, d.equipped)
	end
end

return Inventory
