-- Damage markers: a number that pops up and floats away every time something takes a
-- hit: red with the tool's icon when you hit something, plain red when you're hurt,
-- green with a + when you heal.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Icons = require(script.Parent.Icons)

local Markers = {}

local RED = Color3.fromRGB(255, 70, 58)
local GREEN = Color3.fromRGB(110, 230, 90)
local FONT = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Heavy)

-- A chunky number with a dark outline that appears, drifts straight up and fades out,
-- smooth and the same every time: damage, healing and your own hurts all move alike,
-- and the icon, number and outline fade together (one CanvasGroup).
local RISE = 2.6 -- studs it drifts up
local LIFE = 1.05 -- seconds on screen
local function show(at: Vector3, amount: number, color: Color3, itemId: string?, _self: boolean)
	local anchor = Instance.new("Part")
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = true, false, false, false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.2
	anchor.CFrame = CFrame.new(at + Vector3.new(math.random() * 1.2 - 0.6, 1.2, math.random() * 1.2 - 0.6))
	anchor.Parent = workspace.CurrentCamera
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(140, 48)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 120
	gui.Parent = anchor
	local group = Instance.new("CanvasGroup")
	group.BackgroundTransparency = 1
	group.AnchorPoint = Vector2.new(0.5, 0.5)
	group.Position = UDim2.fromScale(0.5, 0.5)
	group.Size = UDim2.fromScale(1, 1)
	group.GroupTransparency = 0.15
	group.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Scale = 0.85
	scale.Parent = group
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 3)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = group
	if itemId then
		local holderIcon = Instance.new("Frame")
		holderIcon.BackgroundTransparency = 1
		holderIcon.Size = UDim2.fromOffset(26, 26)
		holderIcon.LayoutOrder = 1
		holderIcon.Parent = group
		Icons.make(itemId, holderIcon, UDim2.fromOffset(26, 26), UDim2.fromOffset(0, 0))
	end
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.LayoutOrder = 2
	label.Size = UDim2.fromOffset(0, 40)
	label.AutomaticSize = Enum.AutomaticSize.X
	label.FontFace = FONT
	label.TextSize = 30
	label.TextColor3 = color
	label.TextStrokeTransparency = 1
	label.Text = (if color == GREEN then "+" else "") .. tostring(math.max(1, math.floor(amount + 0.5)))
	label.Parent = group
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(28, 10, 6)
	stroke.Thickness = 3
	stroke.Parent = label

	-- Grow in softly, drift up, and fade out together.
	TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(group, TweenInfo.new(0.12), { GroupTransparency = 0 }):Play()
	TweenService:Create(gui, TweenInfo.new(LIFE, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { StudsOffsetWorldSpace = Vector3.new(0, RISE, 0) }):Play()
	TweenService:Create(group, TweenInfo.new(LIFE * 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, LIFE * 0.4), { GroupTransparency = 1 }):Play()
	task.delay(LIFE + 0.05, function()
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
