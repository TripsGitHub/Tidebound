--!strict
-- Your hotbar layout. Every slot holds what you put there and keeps it: drag an item
-- from your bag onto a slot (or star it) to pin it, drag slot to slot to swap. New
-- tools, food and so on drop into the first empty slot and then stay put too, so
-- nothing ever shuffles along on its own. Pinned slots are saved with your data.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local Favourites = {}

local pinned: { [number]: string } = {} -- slots you chose (saved)
local auto: { [number]: string } = {} -- slots things fell into (this session)
local changed = Instance.new("BindableEvent")
Favourites.Changed = changed.Event

local MAX = 12

local function save()
	local parts = {}
	for i = 1, MAX do
		parts[i] = pinned[i] or ""
	end
	Remotes.HotbarLayout:FireServer(table.concat(parts, ","))
end

local function slotIn(t: { [number]: string }, id: string): number?
	for i, v in t do
		if v == id then
			return i
		end
	end
	return nil
end

function Favourites.has(id: string): boolean
	return slotIn(pinned, id) ~= nil
end

function Favourites.slotOf(id: string): number?
	return slotIn(pinned, id) or slotIn(auto, id)
end

-- Starred = pinned, in slot order (older callers sort by this).
function Favourites.list(): { string }
	local out = {}
	for i = 1, MAX do
		if pinned[i] then
			table.insert(out, pinned[i])
		end
	end
	return out
end

-- Puts id in slot i. Whatever was there moves to the slot id came from (a swap), or
-- off the bar if id wasn't on it.
function Favourites.place(id: string, i: number)
	local from = Favourites.slotOf(id)
	local there = pinned[i] or auto[i]
	local p = slotIn(pinned, id)
	if p then
		pinned[p] = nil
	end
	local a = slotIn(auto, id)
	if a then
		auto[a] = nil
	end
	pinned[i], auto[i] = id, nil
	if there and there ~= id and from then
		pinned[from] = there
	end
	save()
	changed:Fire()
end

function Favourites.toggle(id: string)
	local p = slotIn(pinned, id)
	if p then
		pinned[p] = nil
	else
		local a = slotIn(auto, id)
		if a then
			auto[a] = nil
			pinned[a] = id
		else
			for i = 1, MAX do
				if not pinned[i] and not auto[i] then
					pinned[i] = id
					break
				end
			end
		end
	end
	save()
	changed:Fire()
end

-- The bar for this frame: slot -> id (holes are empty slots). have(id) says whether
-- you hold any; wants(id) whether a new item of that kind should fill a free slot.
function Favourites.layout(size: number, have: (string) -> boolean, candidates: { string }): { [number]: string }
	-- Auto slots empty out when the item is gone; pinned ones wait for it.
	for i, id in auto do
		if not have(id) or pinned[i] then
			auto[i] = nil
		end
	end
	for _, id in candidates do
		if not Favourites.slotOf(id) then
			for i = 1, size do
				if not pinned[i] and not auto[i] then
					auto[i] = id
					break
				end
			end
		end
	end
	local out = {}
	for i = 1, size do
		local id = pinned[i] or auto[i]
		if id and have(id) then
			out[i] = id
		end
	end
	return out
end

-- Your saved layout, sent down by the server when you join.
local function load(text: any)
	if type(text) ~= "string" or text == "" then
		return
	end
	local i = 0
	for id in string.gmatch(text .. ",", "([^,]*),") do
		i += 1
		if i > MAX then
			break
		end
		if id ~= "" then
			pinned[i] = id
		end
	end
	changed:Fire()
end
local player = Players.LocalPlayer
load(player:GetAttribute("HotbarLayout"))
player:GetAttributeChangedSignal("HotbarLayout"):Once(function()
	if next(pinned) == nil then
		load(player:GetAttribute("HotbarLayout"))
	end
end)

return Favourites
