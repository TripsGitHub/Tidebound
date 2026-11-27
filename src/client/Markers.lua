-- Damage markers: a number that pops up and floats away every time something takes a
-- hit. The icon says what happened:
--   the tool you used, tinted red   you hit a creature, a player or a resource
--   a red heart                      you took damage
--   a green heart                    you healed
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Icons = require(script.Parent.Icons)

local Markers = {}

local RED = Color3.fromRGB(214, 64, 52)
local GREEN = Color3.fromRGB(90, 200, 90)

local function show(at: Vector3, amount: number, color: Color3, itemId: string?, heart: boolean)
	local anchor = Instance.new("Part")
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = true, false, false, false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.2
	anchor.CFrame = CFrame.new(at + Vector3.new(math.random() * 2 - 1, 1.5, math.random() * 2 - 1))
	anchor.Parent = workspace.CurrentCamera
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(110, 34)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 120
	gui.Parent = anchor
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = gui
	if heart then
		local h = Instance.new("TextLabel")
		h.BackgroundTransparency = 1
		h.Size = UDim2.fromOffset(30, 30)
		h.Position = UDim2.fromOffset(6, 2)
		h.Text = "♥"
		h.TextScaled = true
		h.TextColor3 = color
		h.TextStrokeTransparency = 0.3
		h.Parent = holder
	elseif itemId then
		local icon = Icons.make(itemId, holder, UDim2.fromOffset(30, 30), UDim2.fromOffset(6, 2))
		icon.ImageColor3 = color
	end
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -40, 1, 0)
	label.Position = UDim2.fromOffset(40, 0)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.Text = (if color == GREEN then "+" else "-") .. tostring(math.max(1, math.floor(amount + 0.5)))
	label.Parent = holder
	TweenService:Create(anchor, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = anchor.CFrame + Vector3.new(0, 3.5, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(0.95, function()
		anchor:Destroy()
	end)
end

function Markers.start()
	Remotes.Marker.OnClientEvent:Connect(function(at: Vector3, amount: number, kind: string, itemId: string?)
		show(at, amount, RED, itemId or "rock", false)
	end)
	-- Your own health: red heart when you're hurt, green heart when you heal (ignoring
	-- the slow trickle of natural regeneration).
	local function hook(character: Model)
		local hum = character:WaitForChild("Humanoid") :: Humanoid
		local last = hum.Health
		hum.HealthChanged:Connect(function(hp)
			local d = hp - last
			last = hp
			local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not root then
				return
			end
			if d <= -0.5 then
				show(root.Position + Vector3.new(0, 2, 0), -d, RED, nil, true)
			elseif d >= 2 then
				show(root.Position + Vector3.new(0, 2, 0), d, GREEN, nil, true)
			end
		end)
	end
	local player = Players.LocalPlayer
	if player.Character then
		task.spawn(hook, player.Character)
	end
	player.CharacterAdded:Connect(hook)
end

return Markers
