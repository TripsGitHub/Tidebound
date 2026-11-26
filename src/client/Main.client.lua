-- Client entry point: input, and wiring the UI, effects and build preview to the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Remotes = require(Shared.Remotes)

local Client = script.Parent
local UI = require(Client.UI)
local Effects = require(Client.Effects)
local BuildMode = require(Client.BuildMode)
local Pointer = require(Client.Pointer)

local player = Players.LocalPlayer
local equipped: string? = nil
local holding = false
local nextSwing = 0

local function equipSlot(index: number)
	local id = UI.hotbarIds()[index]
	if not id then
		return
	end
	if id == equipped then
		Remotes.Equip:FireServer(nil)
	else
		Remotes.Equip:FireServer(id)
	end
end

UI.init({
	onSlot = equipSlot,
	onCraft = function(recipeId)
		Remotes.Craft:FireServer(recipeId)
	end,
	onClaim = function(questId)
		Remotes.ClaimQuest:FireServer(questId)
	end,
	onBuy = function(entryId)
		Remotes.Buy:FireServer(entryId)
	end,
})
Effects.startAmbient()

-- Find the gatherable node or structure under the pointer.
local function targetUnderPointer(): Model?
	local character = player.Character
	local exclude: { Instance } = { workspace.CurrentCamera }
	if character then
		table.insert(exclude, character)
	end
	local hit = Pointer.cast(exclude, 120)
	if not hit then
		return nil
	end
	local inst: Instance? = hit.Instance
	while inst and inst ~= workspace do
		if inst:IsA("Model") and (inst:GetAttribute("NodeType") or inst:GetAttribute("StructureType")) then
			return inst
		end
		inst = inst.Parent
	end
	return nil
end

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
	local target = targetUnderPointer()
	if target then
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local cf, size = target:GetBoundingBox()
		if root then
			local offset = cf:PointToObjectSpace(root.Position)
			local half = size / 2
			local closest = Vector3.new(math.clamp(offset.X, -half.X, half.X), math.clamp(offset.Y, -half.Y, half.Y), math.clamp(offset.Z, -half.Z, half.Z))
			if (offset - closest).Magnitude > Config.HitRange then
				UI.toast("Get closer")
				return
			end
		end
		Remotes.Hit:FireServer(target)
	elseif player.Character then
		-- Swinging at the air still swings, it just doesn't hit anything.
		task.spawn(Effects.swing, player.Character)
	end
end

local function primaryAction()
	local item = equipped and Items[equipped]
	if not item then
		UI.toast("Pick an item from your hotbar (press 1)")
		return
	end
	if item.kind == "tool" then
		holding = true
		trySwing()
	elseif item.kind == "food" then
		Remotes.Eat:FireServer(equipped)
	elseif item.kind == "placeable" then
		BuildMode.tryPlace()
	end
end

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
}

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		Pointer.setTouch(nil)
		primaryAction()
	elseif input.UserInputType == Enum.UserInputType.Touch then
		Pointer.setTouch(input.Position)
		primaryAction()
	elseif KEYS[input.KeyCode] then
		equipSlot(KEYS[input.KeyCode])
	elseif input.KeyCode == Enum.KeyCode.C then
		UI.toggle("crafting")
	elseif input.KeyCode == Enum.KeyCode.R then
		BuildMode.rotate()
	elseif input.KeyCode == Enum.KeyCode.Escape then
		UI.close()
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		holding = false
	end
end)

UserInputService.TouchMoved:Connect(function(input)
	Pointer.setTouch(input.Position)
end)

-- Hold the mouse to keep chopping.
RunService.Heartbeat:Connect(function()
	if holding then
		trySwing()
	end
end)

-- From the server
Remotes.Inventory.OnClientEvent:Connect(function(items, newEquipped)
	equipped = newEquipped
	UI.setInventory(items, newEquipped)
	BuildMode.setItem(newEquipped)
end)
Remotes.Notify.OnClientEvent:Connect(UI.toast)
Remotes.HitFeedback.OnClientEvent:Connect(Effects.hit)
Remotes.QuestState.OnClientEvent:Connect(UI.setQuests)
Remotes.OpenPanel.OnClientEvent:Connect(UI.open)
Remotes.Swing.OnClientEvent:Connect(function(character)
	if character then
		task.spawn(Effects.swing, character)
	end
end)
