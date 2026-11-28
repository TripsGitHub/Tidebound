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
local Rafts = require(Systems.Rafts)
local Crafting = require(Systems.Crafting)
local Building = require(Systems.Building)
local Death = require(Systems.Death)
local Shop = require(Systems.Shop)
local Drops = require(Systems.Drops)
local Save = require(Systems.Save)
local Events = require(Systems.Events)
local Oxygen = require(Systems.Oxygen)
local Avatar = require(Systems.Avatar)
local Admin = require(Systems.Admin)
local Combat = require(Systems.Combat)

-- Characters are spawned by hand (see onPlayerAdded), once the world exists and the
-- player's save has loaded; otherwise they drop in at the map's centre before the
-- spawn point is built. Also set in default.project.json.
Players.CharacterAutoLoads = false

-- Players are let in as soon as the islands and their trees are up (SpawnReady);
-- the caves, camps and map finish building around them, instead of everyone
-- staring at a loading screen for the whole build.
task.spawn(function()
	local ok, err = pcall(WorldBuilder.build)
	if not ok then
		warn("[World] build failed: " .. tostring(err))
		workspace:SetAttribute("SpawnReady", true) -- never leave players stuck loading
	end
end)
while not workspace:GetAttribute("SpawnReady") do
	workspace:GetAttributeChangedSignal("SpawnReady"):Wait()
end
Survival.start()
require(Systems.Smelting).start()
Rafts.start()
require(Systems.Farming).start()
Save.start()
Events.start()
Oxygen.start()
Admin.start()
Combat.start()

-- Ore is counted when it's mined (Harvest.lua), everything else when picked up.
local ORE_ITEMS = {}
for _, ore in require(game:GetService("ReplicatedStorage").Shared.Ores) do
	ORE_ITEMS[ore.item] = true
end
Drops.setPickupCallback(function(player, itemId, amount)
	if not ORE_ITEMS[itemId] then
		Quests.record(player, "gather", itemId, amount)
	end
end)

local function onCharacterAdded(player: Player, character: Model)
	task.spawn(Avatar.dress, player, character)
	Survival.reset(player)
	if Inventory.count(player, "rock") == 0 then
		Inventory.add(player, "rock", 1, true)
	end
	character:WaitForChild("RightHand", 5)
	character:WaitForChild("UpperTorso", 2)
	Inventory.reapplyAppearance(player)
	-- Wake up at your bed, if you've slept in one and it's still standing.
	local bedAt = player:GetAttribute("BedAt")
	if typeof(bedAt) == "Vector3" then
		local bed = nil
		for _, s in workspace.Structures:GetChildren() do
			if s:GetAttribute("StructureType") == "Bed" and (s:GetPivot().Position - bedAt).Magnitude < 8 then
				bed = s
				break
			end
		end
		if bed then
			task.defer(function()
				local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root then
					character:PivotTo(CFrame.new(bedAt))
				end
			end)
		else
			player:SetAttribute("BedAt", nil)
		end
	end
	if not Inventory.getEquipped(player) then
		Inventory.setEquipped(player, "rock")
	end
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.Died:Connect(function()
		Death.onDied(player, character)
		task.delay(Players.RespawnTime, function()
			if player.Parent and player.Character == character then
				Avatar.load(player)
			end
		end)
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
	else
		Avatar.load(player)
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
	-- Combat logging: leave while in combat and your held tool and armour stay
	-- behind on the ground (before the save, so you don't keep them).
	if Combat.inCombat(player) then
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 and Death.dropGear(player, player.Character) then
			Remotes.WorldEvent:FireAllClients(player.DisplayName .. " logged out in combat and dropped their gear!")
		end
	end
	Save.leave(player) -- snapshots first, so this must come before removePlayer
	Crafting.removePlayer(player)
	Inventory.removePlayer(player)
	Quests.removePlayer(player)
	Harvest.removePlayer(player)
	Combat.removePlayer(player)
	Survival.removePlayer(player)
	Rafts.removePlayer(player)
end)

-- Requests from clients. Every handler double-checks what it's given.
Remotes.Hit.OnServerEvent:Connect(Harvest.onHit)
Remotes.Craft.OnServerEvent:Connect(Crafting.onCraft)
Remotes.Eat.OnServerEvent:Connect(function(player, itemId)
	if type(itemId) == "string" and Items[itemId] and Items[itemId].kind == "raft" then
		Rafts.launch(player, itemId)
	else
		Survival.eat(player, itemId)
	end
end)
Remotes.Place.OnServerEvent:Connect(Building.onPlace)
Remotes.HotbarLayout.OnServerEvent:Connect(function(player, text)
	if type(text) == "string" and #text < 800 then
		player:SetAttribute("HotbarLayout", text)
	end
end)
Remotes.CancelBuild.OnServerEvent:Connect(Crafting.cancelBuild)
Remotes.ClaimQuest.OnServerEvent:Connect(Quests.claim)
Remotes.Buy.OnServerEvent:Connect(Shop.onBuy)
Remotes.PickUp.OnServerEvent:Connect(Drops.pickUp)
Remotes.ToggleLock.OnServerEvent:Connect(Building.toggleLock)
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
