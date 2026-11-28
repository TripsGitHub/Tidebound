-- Damage markers, like Island Tribes: every time something takes a hit a marker pops up
-- and floats away. A red badge with your tool's icon when you hit something, a red heart
-- when you're hurt, a green heart when you heal, each with the number on a white pill.
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
-- Island Tribes style: a flat heart (red when hurt, green when healing) or a red badge
-- with the tool's icon (when you hit something), with a white rounded pill on it
-- holding the number.
local function heart(parent: Instance, size: number, colour: Color3, z: number)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromOffset(size, size)
	holder.ZIndex = z
	holder.Parent = parent
	local function piece(x: number, y: number, w: number, round: boolean, rot: number)
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(x, y)
		f.Size = UDim2.fromScale(w, w)
		f.Rotation = rot
		f.BackgroundColor3 = colour
		f.BorderSizePixel = 0
		f.ZIndex = z
		f.Parent = holder
		if round then
			Instance.new("UICorner", f).CornerRadius = UDim.new(1, 0)
		else
			Instance.new("UICorner", f).CornerRadius = UDim.new(0.12, 0)
		end
	end
	piece(0.5, 0.56, 0.6, false, 45)
	piece(0.3, 0.36, 0.52, true, 0)
	piece(0.7, 0.36, 0.52, true, 0)
	return holder
end

local function show(at: Vector3, amount: number, color: Color3, itemId: string?, _self: boolean, heal: boolean?)
	local anchor = Instance.new("Part")
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = true, false, false, false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.2
	anchor.CFrame = CFrame.new(at + Vector3.new(math.random() * 1.2 - 0.6, 1.2, math.random() * 1.2 - 0.6))
	anchor.Parent = workspace.CurrentCamera
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(72, 72)
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
	scale.Scale = 0.6
	scale.Parent = group
	local dark = if heal then Color3.fromRGB(30, 96, 40) else Color3.fromRGB(120, 22, 18)
	local fill = if heal then Color3.fromRGB(92, 200, 80) else Color3.fromRGB(232, 58, 48)
	local textColour = if heal then Color3.fromRGB(46, 150, 50) else Color3.fromRGB(210, 40, 32)
	local pillY = 0.5
	if itemId and not heal then
		-- What you hit with: a red rounded badge with the tool's icon, number below it.
		local badge = Instance.new("Frame")
		badge.AnchorPoint = Vector2.new(0.5, 0.5)
		badge.Position = UDim2.fromScale(0.5, 0.36)
		badge.Size = UDim2.fromOffset(40, 40)
		badge.BackgroundColor3 = fill
		badge.Parent = group
		Instance.new("UICorner", badge).CornerRadius = UDim.new(0.3, 0)
		local ring = Instance.new("UIStroke")
		ring.Color = dark
		ring.Thickness = 3
		ring.Parent = badge
		local holderIcon = Instance.new("Frame")
		holderIcon.BackgroundTransparency = 1
		holderIcon.AnchorPoint = Vector2.new(0.5, 0.5)
		holderIcon.Position = UDim2.fromScale(0.5, 0.5)
		holderIcon.Size = UDim2.fromOffset(30, 30)
		holderIcon.ZIndex = 2
		holderIcon.Parent = badge
		Icons.make(itemId, holderIcon, UDim2.fromOffset(30, 30), UDim2.fromOffset(0, 0))
		pillY = 0.74
	else
		heart(group, 66, dark, 1)
		heart(group, 58, fill, 2)
		pillY = 0.52
	end
	local pill = Instance.new("TextLabel")
	pill.AnchorPoint = Vector2.new(0.5, 0.5)
	pill.Position = UDim2.fromScale(0.5, pillY)
	pill.Size = UDim2.fromOffset(0, 22)
	pill.AutomaticSize = Enum.AutomaticSize.X
	pill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	pill.ZIndex = 5
	pill.FontFace = FONT
	pill.TextSize = 20
	pill.TextColor3 = textColour
	pill.Text = (if heal then "+" else "-") .. tostring(math.max(1, math.floor(amount + 0.5)))
	pill.Parent = group
	Instance.new("UICorner", pill).CornerRadius = UDim.new(1, 0)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 7), UDim.new(0, 7)
	pad.Parent = pill
	local edge = Instance.new("UIStroke")
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Color = dark
	edge.Thickness = 2
	edge.Parent = pill

	-- Pop in, drift up, and fade out together.
	TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(group, TweenInfo.new(0.12), { GroupTransparency = 0 }):Play()
	TweenService:Create(gui, TweenInfo.new(LIFE, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { StudsOffsetWorldSpace = Vector3.new(0, RISE, 0) }):Play()
	TweenService:Create(group, TweenInfo.new(LIFE * 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, LIFE * 0.4), { GroupTransparency = 1 }):Play()
	task.delay(LIFE + 0.05, function()
		anchor:Destroy()
	end)
end

local HEAL = Color3.fromRGB(150, 245, 125)
local healPending, healTimer = 0, false

-- A few green motes that drift up around you as you heal.
local function sparkle(root: BasePart)
	local att = Instance.new("Attachment")
	att.Position = Vector3.new(0, -1, 0)
	att.Parent = root
	local p = Instance.new("ParticleEmitter")
	p.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	p.Color = ColorSequence.new(Color3.fromRGB(170, 255, 150), Color3.fromRGB(90, 210, 90))
	p.LightEmission = 0.6
	p.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	p.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	p.Lifetime = NumberRange.new(0.8, 1.2)
	p.Speed = NumberRange.new(2, 3.5)
	p.SpreadAngle = Vector2.new(25, 25)
	p.Acceleration = Vector3.new(0, 1.5, 0)
	p.EmissionDirection = Enum.NormalId.Top
	p.Rate = 0
	p.Shape = Enum.ParticleEmitterShape.Cylinder
	p.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	p.Parent = att
	p:Emit(10)
	task.delay(1.5, function()
		att:Destroy()
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
			elseif d >= 2 or (d > 0.01 and (Players.LocalPlayer:GetAttribute("HealPool") or 0) > 0) then
				-- Healing comes in a gentle trickle (food heals over time), so gather it
				-- up and show one soft green marker about every 0.7 s while it lasts.
				healPending += d
				if not healTimer then
					healTimer = true
					task.delay(0.7, function()
						healTimer = false
						local r = character:FindFirstChild("HumanoidRootPart") :: BasePart?
						if r and healPending >= 1 then
							show(r.Position + Vector3.new(0, 2.4, 0), healPending, HEAL, nil, true, true)
							sparkle(r)
						end
						healPending = 0
					end)
				end
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
