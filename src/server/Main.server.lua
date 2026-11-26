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

WorldBuilder.build()
Survival.start()

local function onCharacterAdded(player: Player, character: Model)
	Survival.reset(player)
	if Inventory.count(player, "rock") == 0 then
		Inventory.add(player, "rock", 1)
	end
	-- Wait until the hand exists so the held tool can attach to it.
	character:WaitForChild("RightHand", 5)
	Inventory.setEquipped(player, "rock")

	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.Died:Connect(function()
		Death.onDied(player, character)
	end)
end

local function onPlayerAdded(player: Player)
	Inventory.init(player)
	Progression.init(player)
	Quests.init(player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
	-- Give the client a moment to load its UI, then send the starting state.
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
Remotes.Equip.OnServerEvent:Connect(function(player, itemId)
	if itemId == nil then
		Inventory.setEquipped(player, nil)
	elseif type(itemId) == "string" and Items[itemId] and Items[itemId].kind ~= "resource" then
		Inventory.setEquipped(player, itemId)
	end
end)
