-- Client entry point: input, and wiring the HUD, inventory screen, hover info,
-- effects and build preview to the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Items)
local Remotes = require(Shared.Remotes)

local Client = script.Parent
local UI = require(Client.UI)
local InventoryScreen = require(Client.InventoryScreen)
local Effects = require(Client.Effects)
local BuildMode = require(Client.BuildMode)
local Tutorial = require(Client.Tutorial)
local Pointer = require(Client.Pointer)
local Hover = require(Client.Hover)
local Anim = require(Client.Anim)
local Gates = require(Client.Gates)
local Nameplates = require(Client.Nameplates)
local Minimap = require(Client.Minimap)

local player = Players.LocalPlayer
local equipped: string? = nil
local holdingClick = false
local holdingPickup = false
local nextSwing = 0
local nextPickup = 0

local function hold(itemId: string?)
	Remotes.Equip:FireServer(itemId)
end

local function equipSlot(index: number)
	local id = UI.hotbarIds()[index]
	local item = id and Items[id]
	if not item then
		return
	end
	if item.kind == "armour" then
		-- Armour on the hotbar: click to put it on or take it off.
		Remotes.Wear:FireServer(id)
	elseif item.kind == "food" or item.kind == "crate" then
		-- Food heals straight from the hotbar; crates open.
		Remotes.Eat:FireServer(id)
		Tutorial.flag("ate")
		Anim.play(player.Character, "eat")
	else
		hold(if id == equipped then nil else id)
	end
end

UI.init({
	onSlot = equipSlot,
	onClaim = function(id)
		Remotes.ClaimQuest:FireServer(id)
	end,
	onBuy = function(id)
		Remotes.Buy:FireServer(id)
	end,
	onInventory = function()
		InventoryScreen.toggle()
	end,
	onCancelBuild = function()
		Remotes.CancelBuild:FireServer()
	end,
	onPickupDrop = function(target)
		Remotes.PickUp:FireServer(target)
		UI.selectDrop(nil)
	end,
	onEatDrop = function(target)
		Remotes.EatDrop:FireServer(target)
		Anim.play(player.Character, "eat")
		UI.selectDrop(nil)
	end,
})
task.spawn(Tutorial.start, UI.root :: ScreenGui)
InventoryScreen.init(UI.root :: ScreenGui, {
	onCraft = function(id)
		Remotes.Craft:FireServer(id)
	end,
	onWear = function(id)
		Remotes.Wear:FireServer(id)
	end,
	onHold = hold,
	onEat = function(id)
		Remotes.Eat:FireServer(id)
		Tutorial.flag("ate")
		Anim.play(player.Character, "eat")
	end,
	onDrop = function(id)
		Remotes.Drop:FireServer(id)
	end,
})
Hover.start()
Anim.start()
task.spawn(Gates.start)
Nameplates.start()
Minimap.init(UI.root :: ScreenGui)
require(script.Parent.BossBar).init(UI.root :: ScreenGui)
require(script.Parent.Markers).start()
Effects.startAmbient()

-- Swinging -----------------------------------------------------------------------

local function trySwing()
	local item = equipped and Items[equipped]
	if not item or item.kind ~= "tool" then
		return
	end
	local now = os.clock()
	if now < nextSwing then
		return
	end
	nextSwing = now + item.cooldown
	local info = Hover.get()
	if info.target and info.kind ~= "drop" and info.inRange then
		Remotes.Hit:FireServer(info.target)
		UI.targetHit(info.target)
	elseif player.Character then
		-- Swinging at nothing still swings.
		task.spawn(Effects.swing, player.Character)
	end
end

local function primaryAction()
	local item = equipped and Items[equipped]
	if not item then
		return
	end
	if item.kind == "tool" then
		holdingClick = true
		trySwing()
	elseif item.kind == "food" or item.kind == "crate" then
		Remotes.Eat:FireServer(equipped)
		Tutorial.flag("ate")
		Anim.play(player.Character, "eat")
	elseif item.kind == "placeable" then
		BuildMode.tryPlace()
		Tutorial.flag("placed")
	end
end

-- Picking up ------------------------------------------------------------------------

local function tryPickup()
	local now = os.clock()
	if now < nextPickup then
		return
	end
	nextPickup = now + 0.15
	local info = Hover.get()
	local target = if info.kind == "drop" and info.inRange then info.target else Hover.nearestDrop()
	if target then
		Remotes.PickUp:FireServer(target)
	end
end

local function tryEatDrop()
	local info = Hover.get()
	if info.kind == "drop" and info.inRange and info.target then
		local itemId = info.target:GetAttribute("ItemId")
		if Items[itemId] and Items[itemId].kind == "food" then
			Remotes.EatDrop:FireServer(info.target)
			Anim.play(player.Character, "eat")
		end
	end
end

-- Input -----------------------------------------------------------------------------

local KEYS = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6,
	[Enum.KeyCode.Seven] = 7,
	[Enum.KeyCode.Eight] = 8,
	[Enum.KeyCode.Nine] = 9,
	[Enum.KeyCode.Zero] = 10,
}

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		Pointer.setTouch(if input.UserInputType == Enum.UserInputType.Touch then input.Position else nil)
		-- Clicking a dropped item pops up its pickup prompt instead of swinging.
		Hover.refresh()
		local info = Hover.get()
		if info.kind == "drop" and info.target and info.inRange then
			UI.selectDrop(info.target)
			return
		end
		UI.selectDrop(nil)
		primaryAction()
	elseif KEYS[input.KeyCode] then
		equipSlot(KEYS[input.KeyCode])
	elseif input.KeyCode == Enum.KeyCode.C then
		InventoryScreen.toggle()
		UI.closePanels()
	elseif input.KeyCode == Enum.KeyCode.F then
		holdingPickup = true
		tryPickup()
	elseif input.KeyCode == Enum.KeyCode.E then
		tryEatDrop()
	elseif input.KeyCode == Enum.KeyCode.R then
		BuildMode.rotate()
	elseif input.KeyCode == Enum.KeyCode.RightBracket then
		BuildMode.resize(1)
	elseif input.KeyCode == Enum.KeyCode.LeftBracket then
		BuildMode.resize(-1)
	elseif input.KeyCode == Enum.KeyCode.X and BuildMode.current() then
		Remotes.CancelBuild:FireServer()
	elseif input.KeyCode == Enum.KeyCode.Escape then
		InventoryScreen.close()
		UI.closePanels()
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		holdingClick = false
	elseif input.KeyCode == Enum.KeyCode.F then
		holdingPickup = false
	end
end)

UserInputService.TouchMoved:Connect(function(input)
	Pointer.setTouch(input.Position)
end)

-- Hold the mouse to keep swinging; hold F to vacuum up nearby drops.
RunService.Heartbeat:Connect(function()
	if holdingClick then
		trySwing()
	end
	if holdingPickup then
		tryPickup()
	end
end)

-- From the server -------------------------------------------------------------------

Remotes.Inventory.OnClientEvent:Connect(function(items, newEquipped, armour, bagSize)
	-- Just crafted a buildable: close the bag so you can place it straight away.
	if newEquipped and newEquipped ~= equipped and Items[newEquipped] and Items[newEquipped].kind == "placeable" and InventoryScreen.isOpen() then
		InventoryScreen.close()
	end
	equipped = newEquipped
	UI.setInventory(items, newEquipped, armour, bagSize)
	InventoryScreen.set(items, newEquipped, armour)
	Tutorial.update(items, newEquipped)
	BuildMode.setItem(newEquipped)
	UI.setBuild(BuildMode.current())
end)
Remotes.Notify.OnClientEvent:Connect(UI.notify)
Remotes.PickedUp.OnClientEvent:Connect(function(itemId, amount)
	UI.pickup(itemId, amount)
	Effects.sound("Pickup")
	if not Anim.isPlaying(player.Character) then
		Anim.play(player.Character, "pickup")
	end
end)
Remotes.HitFeedback.OnClientEvent:Connect(Effects.hit)
Remotes.WorldFx.OnClientEvent:Connect(Effects.worldFx)
Remotes.QuestState.OnClientEvent:Connect(UI.setQuests)
Remotes.OpenPanel.OnClientEvent:Connect(function(name)
	InventoryScreen.close()
	UI.openPanel(name)
	if name == "quests" then
		Tutorial.flag("quests")
	end
end)
Remotes.Swing.OnClientEvent:Connect(function(character)
	if character then
		task.spawn(Effects.swing, character)
	end
end)

