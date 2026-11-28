-- Damage markers, like Island Tribes: every time something takes a hit a marker pops up
-- and floats away. One colour: red crossed swords when you hit something, a red heart
-- when you're hurt (a green one when you heal), each with the number on a white pill,
-- and a green "XP" orb with "+N Xp" whenever you earn XP.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local Markers = {}

local RED = Color3.fromRGB(255, 70, 58)
local FONT = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Heavy)

-- Every marker moves the same: pops in, drifts straight up and fades out.
local RISE = 2.6 -- studs it drifts up
local LIFE = 1.05 -- seconds on screen

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

local Config = require(Shared.Config)
local EDGE = Color3.fromRGB(120, 14, 10)
local HEAL_TEXT = Color3.fromRGB(40, 150, 46)
local HEAL_EDGE = Color3.fromRGB(22, 84, 24)

-- 12 -> "12", 12.46 -> "12.5": decimals only when there are any, like Island Tribes.
local function fmt(n: number): string
	local r = math.floor(n * 10 + 0.5) / 10
	if r == math.floor(r) then
		return tostring(math.floor(r))
	end
	return string.format("%.1f", r)
end

-- Island Tribes' damage marker, in one colour: a flat red icon (crossed swords when
-- you hit something, a heart when you're hurt) with a white rounded pill over its
-- lower half holding the red number. Healing is the same in green. It pops in,
-- drifts straight up and fades.
local function show(at: Vector3, amount: number, _color: Color3, itemId: string?, _self: boolean, heal: boolean?)
	local anchor = Instance.new("Part")
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = true, false, false, false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.2
	anchor.CFrame = CFrame.new(at + Vector3.new(math.random() * 1.2 - 0.6, 1.2, math.random() * 1.2 - 0.6))
	anchor.Parent = workspace.CurrentCamera
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(76, 76)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 120
	gui.Parent = anchor
	-- No CanvasGroup (it renders at low resolution): each piece fades on its own.
	local group = Instance.new("Frame")
	group.BackgroundTransparency = 1
	group.Size = UDim2.fromScale(1, 1)
	group.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Scale = 0.5
	scale.Parent = group

	local hit = itemId ~= nil and not heal and not _self
	local imageId = if heal then Config.Icons.healHeart elseif hit then Config.Icons.hitSwords else Config.Icons.hurtHeart
	local fill = if heal then Color3.fromRGB(86, 200, 70) else Color3.fromRGB(232, 52, 44)
	if imageId ~= 0 then
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.AnchorPoint = Vector2.new(0.5, 0.5)
		img.Position = UDim2.fromScale(0.5, 0.38)
		img.Size = UDim2.fromOffset(50, 50)
		img.Image = "rbxassetid://" .. imageId
		img.ZIndex = 1
		img.Parent = group
	else
		-- Not uploaded yet: a plain glyph in the same red.
		local g = Instance.new("TextLabel")
		g.BackgroundTransparency = 1
		g.AnchorPoint = Vector2.new(0.5, 0.5)
		g.Position = UDim2.fromScale(0.5, 0.36)
		g.Size = UDim2.fromOffset(50, 50)
		g.Text = if hit then "X" else "♥"
		g.TextScaled = true
		g.FontFace = FONT
		g.TextColor3 = fill
		g.TextStrokeColor3 = if heal then HEAL_EDGE else EDGE
		g.TextStrokeTransparency = 0
		g.ZIndex = 1
		g.Parent = group
	end

	local pill = Instance.new("TextLabel")
	pill.AnchorPoint = Vector2.new(0.5, 0.5)
	pill.Position = UDim2.fromScale(0.5, 0.7)
	pill.Size = UDim2.fromOffset(0, 22)
	pill.AutomaticSize = Enum.AutomaticSize.X
	pill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	pill.ZIndex = 3
	pill.FontFace = FONT
	pill.TextSize = 20
	pill.TextColor3 = if heal then HEAL_TEXT else Color3.fromRGB(214, 36, 28)
	pill.Text = (if heal then "+" else "-") .. fmt(math.max(amount, 0.1))
	pill.Parent = group
	Instance.new("UICorner", pill).CornerRadius = UDim.new(1, 0)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 7), UDim.new(0, 7)
	pad.Parent = pill

	-- Pop in, drift up, and fade out together.
	TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(gui, TweenInfo.new(LIFE, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { StudsOffsetWorldSpace = Vector3.new(0, RISE, 0) }):Play()
	local fadeInfo = TweenInfo.new(LIFE * 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, LIFE * 0.4)
	for _, d in group:GetDescendants() do
		if d:IsA("ImageLabel") then
			TweenService:Create(d, fadeInfo, { ImageTransparency = 1 }):Play()
		elseif d:IsA("TextLabel") then
			TweenService:Create(d, fadeInfo, { TextTransparency = 1, TextStrokeTransparency = 1, BackgroundTransparency = 1 }):Play()
		end
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
