-- Swings, hit shakes, a few chips, bobbing slime and optional sounds.
-- If Config.Animations.Swing has an id, a real keyframed animation plays instead
-- of the built-in code swing.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)
local Items = require(ReplicatedStorage:WaitForChild("Shared").Items)
local Nodes = require(ReplicatedStorage:WaitForChild("Shared").Nodes)
local TweenService = game:GetService("TweenService")
local Anim = require(script.Parent.Anim)

local Effects = {}
local trail: (Model, Model, string) -> ()

function Effects.sound(name: string, at: Instance?)
	local id = Config.Sounds[name]
	if not id or id == "" then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = 0.6
	s.PlaybackSpeed = 0.92 + math.random() * 0.16
	if at and at:IsA("BasePart") then
		s.Parent = at
	else
		s.Parent = SoundService
	end
	s:Play()
	Debris:AddItem(s, 3)
end

-- Swing --------------------------------------------------------------------------

-- A crescent trail behind the tip of the held item, only while the arm is moving
-- fast. Weapons get a bright cyan arc; tools a faint white one.
local TRAIL = {
	slash = { color = Color3.fromRGB(110, 236, 255), from = 0.11, to = 0.25, alpha = 0.15 },
	swing = { color = Color3.fromRGB(255, 255, 255), from = 0.08, to = 0.2, alpha = 0.55 },
}
local trails: { [Model]: Trail } = setmetatable({}, { __mode = "k" }) :: any

trail = function(character: Model, held: Model, style: string)
	local spec = TRAIL[style]
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if not spec or not hand or not hand:IsA("BasePart") then
		return
	end
	local t = trails[held]
	if not t or not t.Parent then
		-- Grip is at the bottom of the fist; the tip is the far end of the item.
		local grip = Vector3.new(0, -hand.Size.Y / 2 + 0.1, 0)
		local cf, size = held:GetBoundingBox()
		local centre = hand.CFrame:PointToObjectSpace(cf.Position)
		local dir = centre - grip
		if dir.Magnitude < 0.1 then
			dir = Vector3.new(0, 0, -1) * size.Magnitude / 2
		end
		local a0 = Instance.new("Attachment")
		a0.Name = "TrailBase"
		a0.Position = grip + dir * 0.9
		a0.Parent = hand
		local a1 = Instance.new("Attachment")
		a1.Name = "TrailTip"
		a1.Position = grip + dir * 2
		a1.Parent = hand
		t = Instance.new("Trail")
		t.Attachment0 = a0
		t.Attachment1 = a1
		t.FaceCamera = false
		t.LightEmission = 0.8
		t.Lifetime = 0.16
		t.MinLength = 0.05
		t.Enabled = false
		t.Parent = hand
		trails[held] = t
		held.Destroying:Connect(function()
			a0:Destroy()
			a1:Destroy()
			t:Destroy()
		end)
	end
	t.Color = ColorSequence.new(spec.color)
	t.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, spec.alpha), NumberSequenceKeypoint.new(1, 1) })
	t.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.2) })
	task.delay(spec.from, function()
		t.Enabled = true
		task.wait(spec.to - spec.from)
		t.Enabled = false
	end)
end

local loadedTracks: { [Humanoid]: AnimationTrack } = {}

function Effects.swing(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if Config.Animations.Swing ~= "" and humanoid then
		local track = loadedTracks[humanoid]
		if not track then
			local animator = humanoid:FindFirstChildOfClass("Animator")
			if animator then
				local anim = Instance.new("Animation")
				anim.AnimationId = Config.Animations.Swing
				track = animator:LoadAnimation(anim)
				track.Priority = Enum.AnimationPriority.Action
				loadedTracks[humanoid] = track
			end
		end
		if track then
			track:Play(0.05)
			return
		end
	end
	-- Built-in animation (see Anim.lua): weapons slash sideways, everything else
	-- chops overhead. Both leave a short trail behind the tip of what you hold.
	local held = character:FindFirstChild("HeldItem")
	local itemId = held and held:GetAttribute("ItemId")
	local style = if itemId and Items[itemId] and Items[itemId].swing == "slash" then "slash" else "swing"
	Anim.play(character, style)
	if held and held:IsA("Model") then
		trail(character, held, style)
	end
end

-- Hits ---------------------------------------------------------------------------

local shaking: { [Model]: boolean } = {}

local function shake(model: Model)
	if shaking[model] or not model:GetAttribute("NodeType") and not model:GetAttribute("StructureType") then
		return
	end
	shaking[model] = true
	local pivot = model:GetPivot()
	task.spawn(function()
		for i = 1, 4 do
			local s = 0.12 * (1 - i / 5)
			model:PivotTo(pivot * CFrame.new(math.random() * s * 2 - s, 0, math.random() * s * 2 - s) * CFrame.Angles(math.rad((i % 2 * 2 - 1) * 1.5), 0, 0))
			task.wait(0.03)
		end
		if not model:GetAttribute("Depleted") then
			model:PivotTo(pivot)
		end
		shaking[model] = nil
	end)
end

local function chips(model: Model)
	local primary = model.PrimaryPart
	if not primary then
		return
	end
	local cf, size = model:GetBoundingBox()
	local origin = Vector3.new(cf.X, cf.Y - size.Y / 2 + 2.5, cf.Z)
	for _ = 1, 3 do
		local chip = Instance.new("Part")
		chip.Size = Vector3.new(0.25, 0.25, 0.25) * (0.7 + math.random() * 0.8)
		chip.Color = primary.Color
		chip.Material = primary.Material
		chip.CanCollide = false
		chip.CanQuery = false
		chip.CanTouch = false
		chip.CFrame = CFrame.new(origin) * CFrame.Angles(math.random() * 6, math.random() * 6, 0)
		chip.AssemblyLinearVelocity = Vector3.new(math.random(-9, 9), math.random(10, 16), math.random(-9, 9))
		chip.Parent = workspace
		Debris:AddItem(chip, 0.5)
	end
end

-- A short flash over whatever you hit: white on trees, rocks and walls, red on
-- anything alive.
local function flash(model: Model, color: Color3)
	local h = Instance.new("Highlight")
	h.FillColor = color
	h.FillTransparency = 0.55
	h.OutlineTransparency = 1
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Adornee = model
	h.Parent = model
	Debris:AddItem(h, 0.12)
end

-- Hit effects by what you hit -----------------------------------------------------

local function fxPart(props): Part
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = workspace
	return p
end

-- The colour of the model's leaves (or a fresh green).
local function leafColour(model: Model): Color3
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and (string.find(d.Name, "Lea") or string.find(d.Name, "Frond") or d.Material == Enum.Material.Grass) then
			return d.Color
		end
	end
	return Color3.fromRGB(96, 150, 60)
end

-- Leaves come loose from the canopy and flutter down, turning as they go.
local function fallingLeaves(model: Model)
	local cf, size = model:GetBoundingBox()
	local colour = leafColour(model)
	local top = cf.Y + size.Y * 0.32
	local spread = math.min(size.X, size.Z) * 0.4
	for _ = 1, math.random(5, 8) do
		local start = Vector3.new(cf.X + (math.random() - 0.5) * 2 * spread, top + (math.random() - 0.5) * 2, cf.Z + (math.random() - 0.5) * 2 * spread)
		local leaf = fxPart({ Size = Vector3.new(0.7, 0.06, 0.45), Color = colour:Lerp(Color3.fromRGB(200, 190, 80), math.random() * 0.3), Material = Enum.Material.SmoothPlastic, CFrame = CFrame.new(start) * CFrame.Angles(math.random() * 6, math.random() * 6, 0) })
		local fall = 3 + math.random() * 4
		local t = 1.3 + math.random() * 0.8
		local drift = Vector3.new((math.random() - 0.5) * 4, -fall, (math.random() - 0.5) * 4)
		TweenService:Create(leaf, TweenInfo.new(t, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { CFrame = CFrame.new(start + drift) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6) }):Play()
		TweenService:Create(leaf, TweenInfo.new(t * 0.4, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, t * 0.6), { Transparency = 1 }):Play()
		Debris:AddItem(leaf, t + 0.1)
	end
end

-- Sparks and a quick flash of light off ore.
local function sparks(at: Vector3, colour: Color3, count: number)
	local holder = fxPart({ Size = Vector3.one * 0.2, Transparency = 1, CFrame = CFrame.new(at) })
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(255, 240, 190), colour)
	e.LightEmission = 1
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 0) })
	e.Lifetime = NumberRange.new(0.25, 0.5)
	e.Speed = NumberRange.new(10, 20)
	e.SpreadAngle = Vector2.new(70, 70)
	e.Acceleration = Vector3.new(0, -30, 0)
	e.Drag = 2
	e.Rate = 0
	e.EmissionDirection = Enum.NormalId.Top
	e.Parent = holder
	e:Emit(count)
	local light = Instance.new("PointLight")
	light.Color = colour
	light.Range = 14
	light.Brightness = 3
	light.Parent = holder
	TweenService:Create(light, TweenInfo.new(0.25), { Brightness = 0 }):Play()
	Debris:AddItem(holder, 0.7)
end

-- A puff of dust off rock.
local function dust(at: Vector3, colour: Color3)
	local holder = fxPart({ Size = Vector3.one * 0.2, Transparency = 1, CFrame = CFrame.new(at) })
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(colour)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1.8) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(0.5, 0.8)
	e.Speed = NumberRange.new(2, 5)
	e.SpreadAngle = Vector2.new(80, 80)
	e.Rate = 0
	e.Parent = holder
	e:Emit(8)
	Debris:AddItem(holder, 1)
end

-- Blobs of slime flying off and splatting.
local function slimeSplat(at: Vector3, colour: Color3)
	for _ = 1, math.random(6, 9) do
		local s = 0.35 + math.random() * 0.45
		local blob = Instance.new("Part")
		blob.Shape = Enum.PartType.Ball
		blob.Size = Vector3.one * s
		blob.Color = colour
		blob.Material = Enum.Material.Glass
		blob.Transparency = 0.15
		blob.CanCollide, blob.CanQuery, blob.CanTouch, blob.CastShadow = false, false, false, false
		blob.CFrame = CFrame.new(at + Vector3.new((math.random() - 0.5) * 1.5, 0.5, (math.random() - 0.5) * 1.5))
		blob.AssemblyLinearVelocity = Vector3.new((math.random() - 0.5) * 22, 10 + math.random() * 10, (math.random() - 0.5) * 22)
		blob.Parent = workspace
		TweenService:Create(blob, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.3), { Transparency = 1, Size = Vector3.new(s * 1.6, s * 0.3, s * 1.6) }):Play()
		Debris:AddItem(blob, 0.85)
	end
end

-- An orange burst where a creature or player takes a hit.
local function fleshBurst(at: Vector3)
	sparks(at, Color3.fromRGB(255, 120, 50), 8)
end

local TREES = { Pine = true, Palm = true, FruitPalm = true, BananaPalm = true, Tree = true, Bush = true, Sapling = true }
local function hitFx(model: Model)
	local cf, size = model:GetBoundingBox()
	local kind = model:GetAttribute("NodeType")
	local animal = model:GetAttribute("AnimalType")
	local low = Vector3.new(cf.X, cf.Y - size.Y / 2 + math.min(size.Y * 0.5, 3), cf.Z)
	if kind then
		local def = Nodes[kind]
		if TREES[kind] or string.find(kind, "Palm") or string.find(kind, "Tree") or (def and def.material == "wood") then
			fallingLeaves(model)
		elseif def and def.ore then
			local glow = Color3.fromRGB(255, 200, 90)
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") and d.Material ~= Enum.Material.Slate and d.Material ~= Enum.Material.Rock and d.Material ~= Enum.Material.Basalt then
					glow = d.Color
					break
				end
			end
			sparks(low, glow, 16)
			dust(low, Color3.fromRGB(150, 144, 136))
		elseif kind == "Boulder" then
			sparks(low, Color3.fromRGB(255, 220, 150), 6)
			dust(low, Color3.fromRGB(160, 154, 146))
		elseif string.find(kind, "Slime") then
			slimeSplat(low, Color3.fromRGB(110, 210, 90))
		end
	elseif animal and string.find(animal, "Slime") then
		local colour = Color3.fromRGB(110, 210, 90)
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and d.Transparency < 0.9 and d.Name ~= "HumanoidRootPart" then
				colour = d.Color
				break
			end
		end
		slimeSplat(cf.Position, colour)
	elseif not model:GetAttribute("StructureType") then
		fleshBurst(cf.Position)
	end
end

function Effects.hit(target: Instance)
	if not target or not target.Parent or not target:IsA("Model") then
		return
	end
	local model = target :: Model
	pcall(hitFx, model)
	if model:GetAttribute("NodeType") then
		shake(model)
		chips(model)
		flash(model, Color3.new(1, 1, 1))
		local stony = model:GetAttribute("NodeType") == "Boulder"
		Effects.sound(if stony then "HitStone" else "ChopWood", model.PrimaryPart)
	elseif model:GetAttribute("StructureType") then
		shake(model)
		chips(model)
		flash(model, Color3.new(1, 1, 1))
		Effects.sound("ChopWood", model.PrimaryPart)
	else
		flash(model, Color3.fromRGB(255, 60, 60))
		Effects.sound("HitFlesh", model.PrimaryPart)
	end
end

-- Ambient ------------------------------------------------------------------------

function Effects.startAmbient()
	local bobbers: { [BasePart]: CFrame } = {}
	local function track(inst: Instance)
		if inst:IsA("BasePart") and inst:GetAttribute("Bob") then
			bobbers[inst] = inst.CFrame
		end
	end
	local nodes = workspace:WaitForChild("Nodes")
	for _, d in nodes:GetDescendants() do
		track(d)
	end
	nodes.DescendantAdded:Connect(track)
	nodes.DescendantRemoving:Connect(function(d)
		bobbers[d :: BasePart] = nil
	end)
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		for p, base in bobbers do
			local phase = (base.Position.X + base.Position.Z) * 0.7
			p.CFrame = base * CFrame.new(0, math.sin(t * 2 + phase) * 0.15, 0)
		end
	end)
end

-- World events -------------------------------------------------------------------
-- Eruptions and meteor showers: the camera shakes (harder the closer you are), the
-- sky changes colour while it lasts, lava bombs and meteors arc through the air,
-- and impacts flash, ring out and throw up dust.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local quakes: { { at: Vector3, untilT: number, power: number } } = {}
RunService.RenderStepped:Connect(function()
	local character = Players.LocalPlayer.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hum or not hrp then
		return
	end
	local now = os.clock()
	local amount = 0
	for i = #quakes, 1, -1 do
		local q = quakes[i]
		if now > q.untilT then
			table.remove(quakes, i)
		else
			local fall = math.clamp(1 - (hrp.Position - q.at).Magnitude / 900, 0.15, 1)
			amount = math.max(amount, q.power * fall * math.min(1, (q.untilT - now) / 1.2))
		end
	end
	if amount > 0.01 then
		hum.CameraOffset = Vector3.new((math.random() - 0.5) * amount, (math.random() - 0.5) * amount, (math.random() - 0.5) * amount * 0.5)
	elseif hum.CameraOffset ~= Vector3.zero then
		hum.CameraOffset = Vector3.zero
	end
end)

local function quake(at: Vector3, seconds: number, power: number)
	table.insert(quakes, { at = at, untilT = os.clock() + seconds, power = power })
end

local tint: ColorCorrectionEffect? = nil
local function sky(color: Color3, seconds: number, mood: string)
	if not tint then
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "EventTint"
		cc.Parent = Lighting
		tint = cc
	end
	local cc = tint :: ColorCorrectionEffect
	TweenService:Create(cc, TweenInfo.new(4, Enum.EasingStyle.Sine), { TintColor = color, Contrast = 0.08, Saturation = if mood == "meteor" then 0.15 else 0.1 }):Play()
	-- Meteor nights get a sky full of shooting stars.
	if mood == "meteor" then
		task.spawn(function()
			local stop = os.clock() + seconds
			while os.clock() < stop do
				local cam = workspace.CurrentCamera
				if cam then
					local from = cam.CFrame.Position + Vector3.new(math.random(-600, 600), math.random(300, 450), math.random(-600, 600))
					local dir = Vector3.new(math.random() - 0.5, -0.35, math.random() - 0.5).Unit
					local p = Instance.new("Part")
					p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
					p.Material = Enum.Material.Neon
					p.Color = Color3.fromRGB(220, 220, 255)
					p.Size = Vector3.new(0.8, 0.8, 30)
					p.CFrame = CFrame.lookAt(from, from + dir)
					p.Parent = workspace.CurrentCamera
					TweenService:Create(p, TweenInfo.new(0.9), { CFrame = CFrame.lookAt(from + dir * 260, from + dir * 261), Transparency = 1 }):Play()
					Debris:AddItem(p, 1)
				end
				task.wait(math.random() * 0.8 + 0.2)
			end
		end)
	end
	task.delay(seconds, function()
		TweenService:Create(cc, TweenInfo.new(6, Enum.EasingStyle.Sine), { TintColor = Color3.new(1, 1, 1), Contrast = 0, Saturation = 0 }):Play()
	end)
end

local function fireball(size: number, color: Color3, heat: Color3): Part
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = Vector3.one * size
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position = Vector3.new(0, size * 0.45, 0), Vector3.new(0, -size * 0.45, 0)
	a0.Parent, a1.Parent = p, p
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Lifetime = 1.4
	trail.LightEmission = 1
	trail.Color = ColorSequence.new(color, heat)
	trail.Transparency = NumberSequence.new(0.1, 1)
	trail.WidthScale = NumberSequence.new(1, 0.2)
	trail.Parent = p
	local fire = Instance.new("Fire")
	fire.Size = size * 1.6
	fire.Heat = 20
	fire.Color = heat
	fire.SecondaryColor = color
	fire.Parent = p
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(60, 50, 50))
	smoke.Size = NumberSequence.new(size * 0.8, size * 2.5)
	smoke.Transparency = NumberSequence.new(0.4, 1)
	smoke.Lifetime = NumberRange.new(1.5, 2.5)
	smoke.Rate = 30
	smoke.Speed = NumberRange.new(0, 2)
	smoke.Parent = p
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = math.min(60, size * 10)
	light.Brightness = 4
	light.Parent = p
	p.Parent = workspace
	return p
end

-- Arc from a to b in `t` seconds, peaking `height` studs above the higher end.
local function arc(p: Part, a: Vector3, b: Vector3, t: number, height: number)
	local start = os.clock()
	local top = math.max(a.Y, b.Y) + height
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local k = math.clamp((os.clock() - start) / t, 0, 1)
		local flat = a:Lerp(b, k)
		local y = (1 - k) ^ 2 * a.Y + 2 * (1 - k) * k * top + k ^ 2 * b.Y
		if p.Parent then
			p.CFrame = CFrame.new(flat.X, y, flat.Z)
		end
		if k >= 1 or not p.Parent then
			conn:Disconnect()
		end
	end)
end

local function impact(at: Vector3, size: number, kind: string)
	local color = if kind == "moon" then Color3.fromRGB(190, 200, 255) else Color3.fromRGB(255, 130, 50)
	quake(at, if size > 30 then 2.2 else 0.5, math.clamp(size / 40, 0.1, 1.6))
	-- Flash
	local flash = Instance.new("Part")
	flash.Shape = Enum.PartType.Ball
	flash.Anchored, flash.CanCollide, flash.CanQuery, flash.CanTouch = true, false, false, false
	flash.Material = Enum.Material.Neon
	flash.Color = color
	flash.Size = Vector3.one * size * 0.3
	flash.CFrame = CFrame.new(at)
	flash.Parent = workspace
	TweenService:Create(flash, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.one * size, Transparency = 1 }):Play()
	Debris:AddItem(flash, 0.6)
	-- Shockwave ring along the ground
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored, ring.CanCollide, ring.CanQuery, ring.CanTouch = true, false, false, false
	ring.Material = Enum.Material.Neon
	ring.Color = color
	ring.Transparency = 0.2
	ring.Size = Vector3.new(0.4, size * 0.2, size * 0.2)
	ring.CFrame = CFrame.new(at + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = workspace
	TweenService:Create(ring, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.4, size * 2.2, size * 2.2), Transparency = 1 }):Play()
	Debris:AddItem(ring, 1)
	-- Dust and glowing rocks thrown up
	local holder = Instance.new("Part")
	holder.Anchored, holder.CanCollide, holder.CanQuery, holder.Transparency = true, false, false, 1
	holder.Size = Vector3.one
	holder.CFrame = CFrame.new(at)
	holder.Parent = workspace
	local dust = Instance.new("ParticleEmitter")
	dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
	dust.Color = ColorSequence.new(if kind == "moon" then Color3.fromRGB(140, 140, 170) else Color3.fromRGB(90, 70, 60))
	dust.Size = NumberSequence.new(size * 0.15, size * 0.5)
	dust.Transparency = NumberSequence.new(0.2, 1)
	dust.Lifetime = NumberRange.new(2, 4)
	dust.Speed = NumberRange.new(size * 0.4, size * 0.9)
	dust.SpreadAngle = Vector2.new(70, 70)
	dust.Acceleration = Vector3.new(0, -8, 0)
	dust.EmissionDirection = Enum.NormalId.Top
	dust.Enabled = false
	dust.Parent = holder
	dust:Emit(math.clamp(math.floor(size), 8, 60))
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(color)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new(1.4, 0.2)
	sparks.Lifetime = NumberRange.new(1, 2)
	sparks.Speed = NumberRange.new(size * 0.5, size * 1.2)
	sparks.SpreadAngle = Vector2.new(60, 60)
	sparks.Acceleration = Vector3.new(0, -60, 0)
	sparks.EmissionDirection = Enum.NormalId.Top
	sparks.Enabled = false
	sparks.Parent = holder
	sparks:Emit(math.clamp(math.floor(size * 1.5), 10, 90))
	Debris:AddItem(holder, 5)
	if size > 30 then
		Effects.sound("Boom", holder)
	end
end

function Effects.worldFx(kind: string, a: any, b: any, c: any)
	if kind == "quake" then
		quake(a, b, c)
	elseif kind == "sky" then
		sky(a, b, c)
	elseif kind == "bomb" then
		local p = fireball(math.random(25, 40) / 10, Color3.fromRGB(255, 120, 40), Color3.fromRGB(255, 200, 80))
		p.CFrame = CFrame.new(a)
		arc(p, a, b, c, math.random(60, 110))
		Debris:AddItem(p, c + 0.05)
	elseif kind == "meteor" then
		local p = fireball(14, Color3.fromRGB(170, 190, 255), Color3.fromRGB(120, 90, 255))
		p.CFrame = CFrame.new(a)
		TweenService:Create(p, TweenInfo.new(c, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = CFrame.new(b) }):Play()
		Debris:AddItem(p, c + 0.05)
	elseif kind == "impact" then
		impact(a, b, c)
	end
end

-- An arrow from a bow: flies dead straight at the bow's arrow speed. If it hit
-- nothing it fades away over the end of its range; if it hit the ground or a wall
-- it sticks there for a few seconds; if it hit a creature it vanishes into it.
function Effects.arrow(character: Model?, from: Vector3, to: Vector3, hit: boolean, speed: number?, faded: boolean?)
	if character then
		Anim.play(character, "shoot")
	end
	local arrow = Instance.new("Model")
	arrow.Name = "Arrow"
	local shaft = Instance.new("Part")
	shaft.Size = Vector3.new(0.12, 0.12, 2.4)
	shaft.Color = Color3.fromRGB(178, 136, 92)
	shaft.Material = Enum.Material.Wood
	local tip = Instance.new("Part")
	tip.Size = Vector3.new(0.24, 0.24, 0.4)
	tip.Color = Color3.fromRGB(98, 98, 104)
	tip.Material = Enum.Material.Slate
	local fletch = Instance.new("Part")
	fletch.Size = Vector3.new(0.04, 0.4, 0.5)
	fletch.Color = Color3.fromRGB(236, 232, 224)
	fletch.Material = Enum.Material.Fabric
	local parts = { shaft, tip, fletch }
	for _, p in parts do
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Parent = arrow
	end
	-- A faint streak behind it so a fast arrow is still easy to follow.
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position = Vector3.new(0, 0.05, 1.1), Vector3.new(0, -0.05, 1.1)
	a0.Parent, a1.Parent = shaft, shaft
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Lifetime = 0.15
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 250, 230))
	trail.Transparency = NumberSequence.new(0.5, 1)
	trail.Parent = shaft
	arrow.Parent = workspace
	local dist = (to - from).Magnitude
	local duration = math.max(0.05, dist / (speed or 140))
	local dir = if dist > 1e-3 then (to - from).Unit else Vector3.zAxis
	local cf0 = CFrame.lookAt(from, from + dir)
	local function place(t: number)
		local cf = cf0 + dir * dist * t
		shaft.CFrame = cf
		tip.CFrame = cf * CFrame.new(0, 0, -1.3)
		fletch.CFrame = cf * CFrame.new(0, 0, 1)
		if faded and t > 0.8 then
			local fade = (t - 0.8) / 0.2
			for _, p in parts do
				p.Transparency = fade
			end
			trail.Enabled = fade < 0.6
		end
	end
	place(0)
	local start = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = math.min(1, (os.clock() - start) / duration)
		place(t)
		if t >= 1 then
			conn:Disconnect()
			trail.Enabled = false
			if hit or faded then
				arrow:Destroy()
			else
				Debris:AddItem(arrow, 4)
			end
		end
	end)
end

return Effects
