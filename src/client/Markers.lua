-- Damage markers, like Island Tribes: every time something takes a hit a marker pops up
-- and floats away. Red crossed swords when you hit something, a red heart when you're
-- hurt, a green heart when you heal, each with the number on a white pill, and a green
-- "XP" orb with "+N Xp" whenever you earn XP.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

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

-- Two crossed swords, drawn flat: red blades with dark edges, gold guards and grips.
local function swords(parent: Instance, size: number, z: number)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.42)
	holder.Size = UDim2.fromOffset(size, size)
	holder.ZIndex = z
	holder.Parent = parent
	local function bar(x: number, y: number, w: number, h: number, rot: number, colour: Color3, edge: Color3?, zi: number)
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(x, y)
		f.Size = UDim2.fromScale(w, h)
		f.Rotation = rot
		f.BackgroundColor3 = colour
		f.BorderSizePixel = 0
		f.ZIndex = zi
		f.Parent = holder
		Instance.new("UICorner", f).CornerRadius = UDim.new(0.3, 0)
		if edge then
			local st = Instance.new("UIStroke")
			st.Color = edge
			st.Thickness = 2
			st.Parent = f
		end
		return f
	end
	local red, edge, gold = Color3.fromRGB(232, 58, 48), Color3.fromRGB(110, 18, 14), Color3.fromRGB(250, 200, 70)
	for _, side in { -1, 1 } do
		local rot = side * 45
		local rad = math.rad(rot)
		local function along(d: number): (number, number)
			-- d: -0.5 (handle end, bottom) .. 0.5 (tip, top)
			return 0.5 + math.sin(rad) * d * 0.9, 0.5 - math.cos(rad) * d * 0.9
		end
		local bx, by = along(0.12)
		bar(bx, by, 0.16, 0.7, rot, red, edge, z + 1)
		local gx, gy = along(-0.26)
		bar(gx, gy, 0.42, 0.1, rot, gold, edge, z + 2)
		local hx, hy = along(-0.38)
		bar(hx, hy, 0.1, 0.2, rot, Color3.fromRGB(120, 70, 36), edge, z + 2)
	end
	return holder
end

-- An Island Tribes XP orb: a green octagon with "XP" on it.
local function xpOrb(parent: Instance, size: number, z: number)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.4)
	holder.Size = UDim2.fromOffset(size, size)
	holder.ZIndex = z
	holder.Parent = parent
	for i, spec in { { 1, Color3.fromRGB(30, 110, 30), 0 }, { 0.82, Color3.fromRGB(110, 220, 80), 1 } } do
		for _, rot in { 0, 45 } do
			local f = Instance.new("Frame")
			f.AnchorPoint = Vector2.new(0.5, 0.5)
			f.Position = UDim2.fromScale(0.5, 0.5)
			f.Size = UDim2.fromScale(spec[1] * 0.92, spec[1] * 0.92)
			f.Rotation = rot
			f.BackgroundColor3 = spec[2]
			f.BorderSizePixel = 0
			f.ZIndex = z + spec[3]
			f.Parent = holder
			Instance.new("UICorner", f).CornerRadius = UDim.new(0.08, 0)
		end
		if i == 2 then
			local t = Instance.new("TextLabel")
			t.BackgroundTransparency = 1
			t.Size = UDim2.fromScale(1, 1)
			t.Text = "XP"
			t.TextScaled = true
			t.FontFace = FONT
			t.TextColor3 = Color3.fromRGB(255, 255, 255)
			t.ZIndex = z + 3
			t.Parent = holder
			local st = Instance.new("UIStroke")
			st.Color = Color3.fromRGB(30, 90, 30)
			st.Thickness = 2
			st.Parent = t
			local pad = Instance.new("UIPadding")
			pad.PaddingTop, pad.PaddingBottom = UDim.new(0.22, 0), UDim.new(0.22, 0)
			pad.Parent = t
		end
	end
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
	-- One group so everything fades together. Item icons are 3D (ViewportFrames),
	-- which don't draw inside a CanvasGroup, so those markers fade piece by piece.
	local withIcon = false -- drawn icons only now, so the whole marker fades as one group
	local group = Instance.new(if withIcon then "Frame" else "CanvasGroup") :: any
	group.BackgroundTransparency = 1
	group.AnchorPoint = Vector2.new(0.5, 0.5)
	group.Position = UDim2.fromScale(0.5, 0.5)
	group.Size = UDim2.fromScale(1, 1)
	if not withIcon then
		group.GroupTransparency = 0.15
	end
	group.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Scale = 0.6
	scale.Parent = group
	local dark = if heal then Color3.fromRGB(30, 96, 40) else Color3.fromRGB(120, 22, 18)
	local fill = if heal then Color3.fromRGB(92, 200, 80) else Color3.fromRGB(232, 58, 48)
	local textColour = if heal then Color3.fromRGB(46, 150, 50) else Color3.fromRGB(210, 40, 32)
	local pillY = 0.5
	if itemId and not heal then
		-- You hit something: Island Tribes' red crossed swords, number below.
		swords(group, 50, 1)
		pillY = 0.76
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
	TweenService:Create(gui, TweenInfo.new(LIFE, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { StudsOffsetWorldSpace = Vector3.new(0, RISE, 0) }):Play()
	if withIcon then
		local fadeInfo = TweenInfo.new(LIFE * 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, LIFE * 0.4)
		for _, d in group:GetDescendants() do
			if d:IsA("ViewportFrame") then
				TweenService:Create(d, fadeInfo, { ImageTransparency = 1 }):Play()
			elseif d:IsA("TextLabel") then
				TweenService:Create(d, fadeInfo, { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
			elseif d:IsA("Frame") and d.BackgroundTransparency < 1 then
				TweenService:Create(d, fadeInfo, { BackgroundTransparency = 1 }):Play()
			elseif d:IsA("UIStroke") then
				TweenService:Create(d, fadeInfo, { Transparency = 1 }):Play()
			end
		end
	else
		TweenService:Create(group, TweenInfo.new(0.12), { GroupTransparency = 0 }):Play()
		TweenService:Create(group, TweenInfo.new(LIFE * 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, LIFE * 0.4), { GroupTransparency = 1 }):Play()
	end
	task.delay(LIFE + 0.05, function()
		anchor:Destroy()
	end)
end

-- XP you earn: a green "XP" orb that pops up over you with "+N Xp" under it.
local function showXp(at: Vector3, amount: number)
	local anchor = Instance.new("Part")
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = true, false, false, false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.2
	anchor.CFrame = CFrame.new(at + Vector3.new(math.random() * 3 - 1.5, 2 + math.random(), math.random() * 3 - 1.5))
	anchor.Parent = workspace.CurrentCamera
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(80, 80)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 120
	gui.Parent = anchor
	local group = Instance.new("CanvasGroup")
	group.BackgroundTransparency = 1
	group.Size = UDim2.fromScale(1, 1)
	group.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Scale = 0.5
	scale.Parent = group
	xpOrb(group, 50, 1)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.AnchorPoint = Vector2.new(0.5, 0)
	t.Position = UDim2.fromScale(0.5, 0.72)
	t.Size = UDim2.fromOffset(90, 20)
	t.Text = "+" .. math.floor(amount + 0.5) .. " Xp"
	t.TextSize = 18
	t.FontFace = FONT
	t.TextColor3 = Color3.fromRGB(255, 255, 255)
	t.ZIndex = 6
	t.Parent = group
	local st = Instance.new("UIStroke")
	st.Color = Color3.fromRGB(20, 50, 20)
	st.Thickness = 2
	st.Parent = t
	TweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(gui, TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { StudsOffsetWorldSpace = Vector3.new(0, 3, 0) }):Play()
	TweenService:Create(group, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.6), { GroupTransparency = 1 }):Play()
	task.delay(1.5, function()
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
	-- XP orbs whenever you earn XP (a level-up resets XP, so count across it).
	local Config = require(Shared.Config)
	local lastXp, lastLevel = player:GetAttribute("XP") or 0, player:GetAttribute("Level") or 1
	local loaded = false
	task.delay(8, function()
		loaded = true -- skip the jump when the save loads
		lastXp, lastLevel = player:GetAttribute("XP") or 0, player:GetAttribute("Level") or 1
	end)
	player:GetAttributeChangedSignal("XP"):Connect(function()
		local xp, level = player:GetAttribute("XP") or 0, player:GetAttribute("Level") or 1
		local gained = if level > lastLevel then Config.XpForLevel(lastLevel) - lastXp + xp else xp - lastXp
		lastXp, lastLevel = xp, level
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if loaded and gained > 0 and root then
			showXp(root.Position, gained)
		end
	end)
	if player.Character then
		task.spawn(hook, player.Character)
	end
	player.CharacterAdded:Connect(hook)
end

return Markers
