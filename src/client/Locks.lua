-- Lock / Unlock: on each of your own lockable builds (chests, carts, gates, plant
-- boxes) a prompt only you see. A locked build is yours alone, even to your tribe.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local player = Players.LocalPlayer

local Locks = {}

local function setup(model: Instance)
	if not model:IsA("Model") or not model:GetAttribute("Lockable") or model:GetAttribute("OwnerId") ~= player.UserId then
		return
	end
	local core = model.PrimaryPart
	if not core or core:FindFirstChild("LockPrompt", true) then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "LockPrompt"
	prompt.KeyboardKeyCode = Enum.KeyCode.L
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.UIOffset = Vector2.new(0, 46)
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.AlwaysShow
	local function refresh()
		local locked = model:GetAttribute("Locked") == true
		prompt.ActionText = if locked then "Unlock" else "Lock"
		prompt.ObjectText = if locked then "🔒 Only you" else "Tribe can use"
	end
	refresh()
	model:GetAttributeChangedSignal("Locked"):Connect(refresh)
	prompt.Triggered:Connect(function()
		Remotes.ToggleLock:FireServer(model)
	end)
	-- Gates: by the door (the core's centre is high up the wall).
	prompt.Parent = (if string.find(model.Name, "Gate") then core:WaitForChild("DoorPrompt", 3) else nil) or core
end

function Locks.start()
	local structures = workspace:WaitForChild("Structures")
	for _, m in structures:GetChildren() do
		task.defer(setup, m)
	end
	structures.ChildAdded:Connect(function(m)
		-- Attributes and parts can arrive a moment after the model itself.
		task.wait(0.3)
		setup(m)
		task.wait(1)
		setup(m)
	end)
end

return Locks
