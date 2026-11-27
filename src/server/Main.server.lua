-- Server entry point. Builds the world and connects every system together.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Items)
local Remotes = require(Shared.Remotes)

local Systems = script.Parent
local WorldBuilder = require(Systems.WorldBuilder)
local Inventory = require(Systems.Inventory)
local Progression = require(Systems.Progression)
local Quests = require(Systems.Quests)
local Harvest = require(Systems.Harvest)
local Survival = require(Systems.Survival)
local Crafting = require(Systems.Crafting)
local Building = require(Systems.Building)
local Death = require(Systems.Death)
local Shop = require(Systems.Shop)
local Drops = require(Systems.Drops)
local Save = require(Systems.Save)

WorldBuilder.build()
Survival.start()
Save.start()

Drops.setPickupCallback(function(player, itemId, amount)
	Quests.record(player, "gather", itemId, amount)
end)

local function onCharacterAdded(player: Player, character: Model)
	Survival.reset(player)
	if Inventory.count(player, "rock") == 0 then
		Inventory.add(player, "rock", 1, true)
	end
	character:WaitForChild("RightHand", 5)
	character:WaitForChild("UpperTorso", 2)
	Inventory.reapplyAppearance(player)
	if not Inventory.getEquipped(player) then
		Inventory.setEquipped(player, "rock")
	end
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.Died:Connect(function()
		Death.onDied(player, character)
	end)
end

local function onPlayerAdded(player: Player)
	Inventory.init(player)
	Progression.init(player)
	Quests.init(player)
	-- Load their save before the character is set up, so they spawn with their gear.
	Save.load(player)
	if not player.Parent then
		return
	end
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
	task.delay(1, function()
		Inventory.sync(player)
		Quests.sync(player)
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	Save.leave(player) -- snapshots first, so this must come before removePlayer
	Inventory.removePlayer(player)
	Quests.removePlayer(player)
	Harvest.removePlayer(player)
	Survival.removePlayer(player)
end)

-- Requests from clients. Every handler double-checks what it's given.
Remotes.Hit.OnServerEvent:Connect(Harvest.onHit)
Remotes.Craft.OnServerEvent:Connect(Crafting.onCraft)
Remotes.Eat.OnServerEvent:Connect(Survival.eat)
Remotes.Place.OnServerEvent:Connect(Building.onPlace)
Remotes.ClaimQuest.OnServerEvent:Connect(Quests.claim)
Remotes.Buy.OnServerEvent:Connect(Shop.onBuy)
Remotes.PickUp.OnServerEvent:Connect(Drops.pickUp)
Remotes.Drop.OnServerEvent:Connect(Drops.dropFromBag)
Remotes.EatDrop.OnServerEvent:Connect(function(player, drop)
	Drops.eat(player, drop, Survival.consume)
end)
Remotes.Wear.OnServerEvent:Connect(function(player, itemId)
	if type(itemId) == "string" then
		Inventory.toggleWear(player, itemId)
	end
end)
Remotes.Equip.OnServerEvent:Connect(function(player, itemId)
	if itemId == nil then
		Inventory.setEquipped(player, nil)
	elseif type(itemId) == "string" and Items[itemId] then
		Inventory.setEquipped(player, itemId)
	end
end)
