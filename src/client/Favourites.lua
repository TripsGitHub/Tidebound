--!strict
-- Starred items, in the order you starred them. Starred items take the first
-- hotbar slots (any kind, armour too); the rest of the bar auto-fills.
local Favourites = {}

local order: { string } = {}
local changed = Instance.new("BindableEvent")
Favourites.Changed = changed.Event

function Favourites.has(id: string): boolean
	return table.find(order, id) ~= nil
end

function Favourites.list(): { string }
	return table.clone(order)
end

function Favourites.toggle(id: string)
	local i = table.find(order, id)
	if i then
		table.remove(order, i)
	else
		table.insert(order, id)
	end
	changed:Fire()
end

return Favourites
