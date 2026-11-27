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

-- A chunky number with a thick dark outline that punches in big, settles, hops
-- up and off to one side, then fades. A small icon of the tool you hit with sits
-- in front of it; your own damage and healing are just the number.
local function show(at: Vector3, amount: number, color: Color3, itemId: string?, _self: boolean)
	local anchor = Instance.new("Part")
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = true, false, false, false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.2
	anchor.CFrame = CFrame.new(at + Vector3.new(math.random() * 1.6 - 0.8, 1.2, math.random() * 1.6 - 0.8))
	anchor.Parent = workspace.CurrentCamera
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(140, 48)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 120
	gui.Parent = anchor
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Scale = 1.7
	scale.Parent = holder
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 3)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = holder
	local icon: ViewportFrame? = nil
	if itemId then
		local holderIcon = Instance.new("Frame")
		holderIcon.BackgroundTransparency = 1
		holderIcon.Size = UDim2.fromOffset(26, 26)
		holderIcon.LayoutOrder = 1
		holderIcon.Parent = holder
		icon = Icons.make(itemId, holderIcon, UDim2.fromOffset(26, 26), UDim2.fromOffset(0, 0))
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
	label.Parent = holder
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(28, 10, 6)
	stroke.Thickness = 3
	stroke.Parent = label

	-- Punch in, then hop up and sideways, then fade.
	TweenService:Create(scale, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	local side = (math.random() < 0.5 and -1 or 1) * (0.8 + math.random() * 0.8)
	TweenService:Create(gui, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { StudsOffsetWorldSpace = Vector3.new(side, 3, 0) }):Play()
	task.delay(0.45, function()
		local fade = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
		TweenService:Create(stroke, fade, { Transparency = 1 }):Play()
		TweenService:Create(scale, fade, { Scale = 0.7 }):Play()
		if icon then
			TweenService:Create(icon, fade, { ImageTransparency = 1 }):Play()
		end
	end)
	task.delay(0.85, function()
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
