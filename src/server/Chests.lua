-- Storage chests: a placeable box that holds items. Only its owner can open it.
-- What's inside is kept here (not in attributes, so nobody else can read it) and
-- saved with the base (Building.export). Breaking a chest spills its items.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Remotes = require(Shared.Remotes)
local Inventory = require(script.Parent.Inventory)
local Drops = require(script.Parent.Drops)

local Chests = {}

local REACH = 14
local contents: { [Model]: { [string]: number } } = {}
local viewers: { [Model]: { [Player]: boolean } } = {}

local function total(box: { [string]: number }): number
	local n = 0
	for _, c in box do
		n += c
	end
	return n
end

local function core(model: Model): BasePart?
	return model.PrimaryPart
end

local function near(player: Player, model: Model): boolean
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local c = core(model)
	return root ~= nil and c ~= nil and model.Parent ~= nil and (root.Position - c.Position).Magnitude <= REACH
end

local function canOpen(player: Player, model: Model): boolean
	local owner = model:GetAttribute("OwnerId")
	return owner == nil or owner == player.UserId
end

local function send(player: Player, model: Model)
	Remotes.ChestState:FireClient(player, model, contents[model] or {}, Config.ChestCapacity)
end

local function refreshViewers(model: Model)
	for p in viewers[model] or {} do
		if p.Parent and near(p, model) then
			send(p, model)
		else
			viewers[model][p] = nil
		end
	end
end

-- Called by Building when a chest is built (or rebuilt from a save).
function Chests.setup(model: Model, saved: any)
	local box: { [string]: number } = {}
	if type(saved) == "table" then
		for id, n in saved do
			if type(id) == "string" and Items[id] and type(n) == "number" and n > 0 then
				box[id] = math.floor(n)
			end
		end
	end
	contents[model] = box
	viewers[model] = {}
	local c = core(model)
	if c then
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Open"
		prompt.ObjectText = "Storage Chest"
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = c
		prompt.Triggered:Connect(function(player)
			if not canOpen(player, model) then
				Remotes.Notify:FireClient(player, "That chest isn't yours", "warn")
				return
			end
			viewers[model][player] = true
			send(player, model)
		end)
	end
	model.Destroying:Connect(function()
		local box2 = contents[model]
		local at = if c then c.Position else model:GetPivot().Position
		contents[model] = nil
		for p in viewers[model] or {} do
			if p.Parent then
				Remotes.ChestState:FireClient(p, nil)
			end
		end
		viewers[model] = nil
		-- Broken open: everything inside spills out (not when its owner just left).
		if box2 and not model:GetAttribute("Despawn") then
			for id, n in box2 do
				Drops.spawn(id, n, at + Vector3.new(0, 2, 0))
			end
		end
	end)
end

function Chests.export(model: Model): { [string]: number }?
	local box = contents[model]
	if not box or next(box) == nil then
		return nil
	end
	local copy = {}
	for id, n in box do
		copy[id] = n
	end
	return copy
end

function Chests.onMove(player: Player, model: unknown, itemId: unknown, dir: unknown)
	if typeof(model) ~= "Instance" or not (model :: Instance):IsA("Model") or type(itemId) ~= "string" or not Items[itemId] then
		return
	end
	local m = model :: Model
	local box = contents[m]
	if not box or not canOpen(player, m) or not near(player, m) then
		return
	end
	if dir == "put" then
		local have = Inventory.count(player, itemId)
		local n = math.min(have, Config.ChestCapacity - total(box))
		if n <= 0 then
			Remotes.Notify:FireClient(player, if have > 0 then "The chest is full" else "You don't have that", "warn")
		elseif Inventory.take(player, itemId, n) then
			box[itemId] = (box[itemId] or 0) + n
		end
	elseif dir == "take" then
		local n = box[itemId] or 0
		if n > 0 then
			local added = Inventory.add(player, itemId, n)
			if added <= 0 then
				Remotes.Notify:FireClient(player, "Your bag is full", "warn")
			end
			box[itemId] = if n - added > 0 then n - added else nil
		end
	end
	viewers[m][player] = true
	refreshViewers(m)
end

function Chests.removePlayer(player: Player)
	for _, v in viewers do
		v[player] = nil
	end
end

Remotes.ChestMove.OnServerEvent:Connect(Chests.onMove)
game:GetService("Players").PlayerRemoving:Connect(Chests.removePlayer)

return Chests
