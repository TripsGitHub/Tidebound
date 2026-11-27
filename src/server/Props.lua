-- Small built props shared by landmarks and camps: crates, barrels, torch posts,
-- banners, log piles, flower patches, fences and particle effects. Everything is
-- plain parts (no meshes), anchored, and named so it reads in the Explorer.
local Props = {}

local Meshes = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Meshes"))

local rng = Random.new(5150)
local rgb = Color3.fromRGB

Props.WOOD = rgb(132, 92, 56)
Props.WOOD_DARK = rgb(88, 60, 38)
Props.WOOD_LIGHT = rgb(176, 132, 84)
Props.ROPE = rgb(214, 190, 136)
Props.CLOTH = { rgb(196, 64, 52), rgb(232, 196, 90), rgb(70, 130, 170), rgb(236, 226, 200) }

function Props.part(parent: Instance, props): BasePart
	local class = props.Class or "Part"
	local p = Instance.new(class) :: BasePart
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		if key ~= "Class" then
			(p :: any)[key] = value
		end
	end
	p.Parent = parent
	return p
end
local part = Props.part

-- A wooden crate with darker corner posts and rims, sitting on cf.
function Props.crate(parent: Instance, cf: CFrame, size: number?)
	local s = size or rng:NextNumber(2.6, 3.6)
	local body = part(parent, { Name = "Crate", Size = Vector3.one * s, CFrame = cf * CFrame.new(0, s / 2, 0), Color = Props.WOOD_LIGHT, Material = Enum.Material.WoodPlanks })
	local h = s / 2
	for sx = -1, 1, 2 do
		for sz = -1, 1, 2 do
			part(parent, { Name = "CratePost", Size = Vector3.new(0.4, s + 0.06, 0.4), CFrame = body.CFrame * CFrame.new(sx * h, 0, sz * h), Color = Props.WOOD_DARK, Material = Enum.Material.Wood, CanCollide = false })
		end
	end
	for _, y in { -h, h } do
		for side = -1, 1, 2 do
			part(parent, { Name = "CrateRim", Size = Vector3.new(s + 0.06, 0.4, 0.4), CFrame = body.CFrame * CFrame.new(0, y, side * h), Color = Props.WOOD_DARK, Material = Enum.Material.Wood, CanCollide = false })
			part(parent, { Name = "CrateRim", Size = Vector3.new(0.4, 0.4, s + 0.06), CFrame = body.CFrame * CFrame.new(side * h, y, 0), Color = Props.WOOD_DARK, Material = Enum.Material.Wood, CanCollide = false })
		end
	end
	-- A diagonal brace across the front.
	part(parent, { Name = "CrateBrace", Size = Vector3.new(0.35, s * 1.3, 0.2), CFrame = body.CFrame * CFrame.new(0, 0, -h - 0.05) * CFrame.Angles(0, 0, math.rad(45)), Color = Props.WOOD_DARK, Material = Enum.Material.Wood, CanCollide = false })
	return body
end

-- A stack of two or three crates.
function Props.crateStack(parent: Instance, cf: CFrame)
	local a = Props.crate(parent, cf * CFrame.new(-1.6, 0, 0) * CFrame.Angles(0, rng:NextNumber(-0.2, 0.2), 0), 3.2)
	Props.crate(parent, cf * CFrame.new(1.7, 0, 0.3) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0), 3)
	if rng:NextNumber() < 0.7 then
		Props.crate(parent, CFrame.new(a.Position + Vector3.new(0.6, 1.6, 0)) * CFrame.Angles(0, rng:NextNumber(0, 1), 0), 2.4)
	end
end

-- A barrel with two hoops.
function Props.barrel(parent: Instance, cf: CFrame)
	local h = 3.4
	local body = part(parent, { Name = "Barrel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, 2.6, 2.6), CFrame = cf * CFrame.new(0, h / 2, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = Props.WOOD, Material = Enum.Material.Wood })
	for _, y in { -0.9, 0.9 } do
		part(parent, { Name = "Hoop", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 2.75, 2.75), CFrame = body.CFrame * CFrame.new(y, 0, 0), Color = rgb(70, 66, 64), Material = Enum.Material.Metal, CanCollide = false })
	end
	return body
end

-- A post with a burning torch on top.
function Props.torchPost(parent: Instance, at: Vector3, height: number?)
	local h = height or 6
	part(parent, { Name = "TorchPost", Size = Vector3.new(0.7, h, 0.7), CFrame = CFrame.new(at + Vector3.new(0, h / 2, 0)), Color = Props.WOOD_DARK, Material = Enum.Material.Wood })
	local bowl = part(parent, { Name = "TorchBowl", Size = Vector3.new(1.3, 0.6, 1.3), CFrame = CFrame.new(at + Vector3.new(0, h + 0.3, 0)), Color = rgb(60, 56, 52), Material = Enum.Material.Metal })
	local fire = Instance.new("Fire")
	fire.Size = 3
	fire.Heat = 6
	fire.Color = rgb(255, 150, 60)
	fire.SecondaryColor = rgb(255, 220, 120)
	fire.Parent = bowl
	local light = Instance.new("PointLight")
	light.Color = rgb(255, 170, 90)
	light.Range = 20
	light.Brightness = 1.2
	light.Shadows = false
	light.Parent = bowl
end

-- A tall cloth banner on a pole.
function Props.banner(parent: Instance, at: Vector3, color: Color3?, height: number?)
	local h = height or 12
	part(parent, { Name = "BannerPole", Size = Vector3.new(0.6, h, 0.6), CFrame = CFrame.new(at + Vector3.new(0, h / 2, 0)), Color = Props.WOOD_DARK, Material = Enum.Material.Wood })
	part(parent, { Name = "BannerBar", Size = Vector3.new(4.4, 0.4, 0.4), CFrame = CFrame.new(at + Vector3.new(1.9, h - 0.6, 0)), Color = Props.WOOD_DARK, Material = Enum.Material.Wood })
	part(parent, { Name = "Banner", Size = Vector3.new(3.6, h * 0.45, 0.15), CFrame = CFrame.new(at + Vector3.new(2, h - 0.8 - h * 0.225, 0)) * CFrame.Angles(0, 0, 0.02), Color = color or Props.CLOTH[rng:NextInteger(1, #Props.CLOTH)], Material = Enum.Material.Fabric, CanCollide = false })
end

-- A pile of logs lying on their sides.
function Props.logPile(parent: Instance, cf: CFrame)
	for row = 0, 2 do
		for k = 0, 2 - row do
			part(parent, { Name = "Log", Shape = Enum.PartType.Cylinder, Size = Vector3.new(7, 1.5, 1.5), CFrame = cf * CFrame.new(0, 0.75 + row * 1.3, (k - (2 - row) / 2) * 1.55) * CFrame.Angles(0, rng:NextNumber(-0.06, 0.06), 0), Color = if (k + row) % 2 == 0 then Props.WOOD else Props.WOOD_DARK, Material = Enum.Material.Wood })
		end
	end
end

-- A few small flowers.
function Props.flowers(parent: Instance, at: Vector3, radius: number, count: number?)
	local colours = { rgb(255, 120, 150), rgb(255, 220, 90), rgb(200, 140, 255), rgb(255, 255, 255), rgb(255, 150, 70) }
	for _ = 1, count or 8 do
		local a, d = rng:NextNumber(0, math.pi * 2), rng:NextNumber(0, radius)
		local p = at + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
		part(parent, { Name = "Stem", Size = Vector3.new(0.15, 0.9, 0.15), CFrame = CFrame.new(p + Vector3.new(0, 0.45, 0)), Color = rgb(70, 130, 50), CanCollide = false, CanQuery = false })
		part(parent, { Name = "Flower", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.55, CFrame = CFrame.new(p + Vector3.new(0, 0.95, 0)), Color = colours[rng:NextInteger(1, #colours)], CanCollide = false, CanQuery = false })
	end
end

-- A palisade of sharpened logs from a to b, the way tribe camps wall themselves in.
function Props.palisade(parent: Instance, a: Vector3, b: Vector3, height: number?)
	local h = height or 9
	local d = b - a
	local n = math.max(1, math.floor(d.Magnitude / 2))
	for i = 0, n do
		local p = a:Lerp(b, i / n)
		local hh = h + rng:NextNumber(-0.8, 0.8)
		local col = if i % 2 == 0 then Props.WOOD else Props.WOOD_LIGHT
		part(parent, { Name = "Stake", Shape = Enum.PartType.Cylinder, Size = Vector3.new(hh + 2, 2.2, 2.2), CFrame = CFrame.new(p + Vector3.new(0, hh / 2 - 1.5, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = col, Material = Enum.Material.Wood })
		part(parent, { Class = "WedgePart", Name = "Point", Size = Vector3.new(2, 1.8, 2), CFrame = CFrame.new(p + Vector3.new(0, hh, 0)) * CFrame.Angles(0, math.atan2(d.X, d.Z), 0), Color = col, Material = Enum.Material.Wood, CanCollide = false })
	end
	-- Two rope lashings along the wall.
	for _, y in { 3, h * 0.5, h - 2 } do
		local mid = (a + b) / 2 + Vector3.new(0, y, 0)
		part(parent, { Name = "Lashing", Size = Vector3.new(0.25, 0.25, d.Magnitude), CFrame = CFrame.lookAt(mid, mid + d), Color = Props.ROPE, Material = Enum.Material.Fabric, CanCollide = false })
	end
end

-- A tribe totem: stacked carved blocks with painted faces and wings at the top.
function Props.totem(parent: Instance, at: Vector3, height: number?, facing: Vector3?)
	local h = height or 16
	local look = CFrame.lookAt(at, at + (facing or Vector3.zAxis))
	local colours = { rgb(196, 64, 52), rgb(232, 196, 90), rgb(70, 130, 170), rgb(90, 150, 80) }
	local segments = math.floor(h / 3.2)
	for i = 0, segments - 1 do
		local y = i * 3.2 + 1.6
		local block = part(parent, { Name = "TotemBlock", Size = Vector3.new(3, 3.2, 3), CFrame = look * CFrame.new(0, y, 0), Color = Props.WOOD_LIGHT, Material = Enum.Material.Wood })
		local paint = colours[i % #colours + 1]
		-- A face: eyes and a mouth band, painted on the front.
		for _, x in { -0.75, 0.75 } do
			part(parent, { Name = "Eye", Size = Vector3.new(0.7, 0.7, 0.2), CFrame = block.CFrame * CFrame.new(x, 0.6, -1.55), Color = rgb(30, 24, 20), CanCollide = false })
		end
		part(parent, { Name = "Mouth", Size = Vector3.new(2.2, 0.5, 0.2), CFrame = block.CFrame * CFrame.new(0, -0.7, -1.55), Color = paint, CanCollide = false })
		part(parent, { Name = "Brow", Size = Vector3.new(2.8, 0.4, 0.3), CFrame = block.CFrame * CFrame.new(0, 1.25, -1.5), Color = paint, CanCollide = false })
	end
	local top = segments * 3.2
	for side = -1, 1, 2 do
		part(parent, { Class = "WedgePart", Name = "Wing", Size = Vector3.new(0.6, 2.4, 5), CFrame = look * CFrame.new(side * 3.6, top - 1.6, 0) * CFrame.Angles(0, side * math.pi / 2, 0), Color = colours[1], Material = Enum.Material.Wood })
	end
	part(parent, { Class = "WedgePart", Name = "Beak", Size = Vector3.new(1.2, 1.4, 2), CFrame = look * CFrame.new(0, top - 2.4, -2.1) * CFrame.Angles(math.pi, 0, 0), Color = colours[2], Material = Enum.Material.Wood })
end

-- An A-frame hide tent, its open end facing `facing`.
function Props.tent(parent: Instance, at: Vector3, facing: Vector3, r: number?)
	local w = (r or 6) * 1.6 -- width across the two slopes
	local h = (r or 6) * 1.4
	local long = (r or 6) * 2
	local look = CFrame.lookAt(at, at + facing) -- -Z is the door side
	-- The Blender tent (sagging hides, crossed poles, tied-back flaps, guy ropes).
	local mesh = Meshes.has("tent") and Meshes.build("tent", { scale = (r or 6) / 6 })
	if mesh then
		mesh:PivotTo(look)
		mesh.Name = "Tent"
		mesh.Parent = parent
		return
	end
	local hide = rgb(226, 204, 158)
	for side = -1, 1, 2 do
		part(parent, {
			Class = "WedgePart",
			Name = "Hide",
			Size = Vector3.new(long, h, w / 2),
			CFrame = look * CFrame.new(0, h / 2, side * w / 4) * CFrame.Angles(0, math.pi / 2 + (if side > 0 then 0 else math.pi), 0),
			Color = hide,
			Material = Enum.Material.Fabric,
		})
	end
	-- Ridge pole, a dark doorway on the front end, and a painted stripe.
	part(parent, { Name = "Ridge", Size = Vector3.new(0.4, 0.4, long + 2), CFrame = look * CFrame.new(0, h + 0.1, 0), Color = Props.WOOD_DARK, Material = Enum.Material.Wood, CanCollide = false })
	part(parent, { Class = "WedgePart", Name = "Door", Size = Vector3.new(0.2, h * 0.6, w * 0.25), CFrame = look * CFrame.new(w * 0.125, h * 0.3, -long / 2 - 0.05) * CFrame.Angles(0, math.pi / 2, 0), Color = rgb(60, 40, 28), CanCollide = false })
	part(parent, { Class = "WedgePart", Name = "Door", Size = Vector3.new(0.2, h * 0.6, w * 0.25), CFrame = look * CFrame.new(-w * 0.125, h * 0.3, -long / 2 - 0.05) * CFrame.Angles(0, -math.pi / 2, 0), Color = rgb(60, 40, 28), CanCollide = false })
	for side = -1, 1, 2 do
		part(parent, { Name = "Stripe", Size = Vector3.new(0.6, 0.25, long + 0.1), CFrame = look * CFrame.new(side * w * 0.3, h * 0.42, 0) * CFrame.Angles(0, 0, side * math.atan2(h, w / 2)), Color = rgb(170, 70, 52), Material = Enum.Material.Fabric, CanCollide = false })
	end
end

-- A ring of stones with a fire in it and a log seat or two.
function Props.campfire(parent: Instance, at: Vector3)
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		part(parent, { Name = "FireStone", Size = Vector3.new(1.2, 0.9, 1.2), CFrame = CFrame.new(at + Vector3.new(math.cos(a) * 2.2, 0.35, math.sin(a) * 2.2)) * CFrame.Angles(0, a, 0.2), Color = rgb(120, 116, 110), Material = Enum.Material.Slate })
	end
	local core = part(parent, { Name = "Embers", Size = Vector3.new(2.6, 0.4, 2.6), CFrame = CFrame.new(at + Vector3.new(0, 0.2, 0)), Color = rgb(255, 120, 40), Material = Enum.Material.Neon, CanCollide = false })
	local fire = Instance.new("Fire")
	fire.Size = 5
	fire.Heat = 9
	fire.Parent = core
	local light = Instance.new("PointLight")
	light.Color = rgb(255, 160, 80)
	light.Range = 26
	light.Brightness = 1.5
	light.Parent = core
	for side = -1, 1, 2 do
		part(parent, { Name = "LogSeat", Shape = Enum.PartType.Cylinder, Size = Vector3.new(5, 1.6, 1.6), CFrame = CFrame.new(at + Vector3.new(0, 0.8, side * 5)), Color = Props.WOOD, Material = Enum.Material.Wood })
	end
end

-- A big carved sign on two posts, with `text` burnt into it.
function Props.bigSign(parent: Instance, at: Vector3, facing: Vector3, text: string)
	local look = CFrame.lookAt(at, at + facing)
	-- The Blender sign (lashed posts, three nailed planks); the text goes on a thin
	-- invisible board in front of the planks.
	local mesh = Meshes.has("signboard") and Meshes.build("signboard")
	if mesh then
		mesh:PivotTo(look)
		mesh.Name = "Sign"
		mesh.Parent = parent
		local face = part(parent, { Name = "SignText", Size = Vector3.new(10.5, 3.4, 0.1), CFrame = look * CFrame.new(0, 7, -0.85), Transparency = 1, CanCollide = false, CanQuery = false })
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0.6
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.FontFace = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Heavy)
		label.TextScaled = true
		label.TextColor3 = rgb(60, 34, 18)
		label.Text = text
		label.Parent = gui
		gui.Parent = face
		return
	end
	for side = -1, 1, 2 do
		part(parent, { Name = "SignPost", Size = Vector3.new(0.9, 9, 0.9), CFrame = look * CFrame.new(side * 5, 4.5, 0), Color = Props.WOOD_DARK, Material = Enum.Material.Wood })
	end
	local board = part(parent, { Name = "SignBoard", Size = Vector3.new(12, 3.6, 0.6), CFrame = look * CFrame.new(0, 7, -0.5) * CFrame.Angles(0, 0, 0.03), Color = Props.WOOD_LIGHT, Material = Enum.Material.WoodPlanks })
	for side = -1, 1, 2 do
		part(parent, { Class = "WedgePart", Name = "SignPoint", Size = Vector3.new(0.6, 3.6, 1.6), CFrame = board.CFrame * CFrame.new(side * 6.7, 0, 0) * CFrame.Angles(0, side * math.pi / 2, 0), Color = Props.WOOD_LIGHT, Material = Enum.Material.WoodPlanks })
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.6
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.FontFace = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Heavy)
	label.TextScaled = true
	label.TextColor3 = rgb(70, 40, 22)
	label.Text = text
	label.Parent = gui
	gui.Parent = board
end

-- Particle effects: "fireflies", "spores", "snow", "bubbles", "dust", "embers".
function Props.particles(parent: BasePart, kind: string)
	local e = Instance.new("ParticleEmitter")
	e.LightEmission = 0.6
	e.LockedToPart = false
	e.Speed = NumberRange.new(0.5, 1.5)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Lifetime = NumberRange.new(3, 6)
	e.Rate = 6
	e.Size = NumberSequence.new(0.25)
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.1), NumberSequenceKeypoint.new(0.8, 0.2), NumberSequenceKeypoint.new(1, 1) })
	if kind == "fireflies" then
		e.Color = ColorSequence.new(rgb(255, 240, 140))
		e.LightEmission = 1
		e.Acceleration = Vector3.new(0, 0.2, 0)
	elseif kind == "spores" then
		e.Color = ColorSequence.new(rgb(170, 255, 140), rgb(220, 140, 255))
		e.Acceleration = Vector3.new(0, 0.6, 0)
		e.Rate = 10
	elseif kind == "snow" then
		e.Color = ColorSequence.new(rgb(255, 255, 255))
		e.Acceleration = Vector3.new(0, -1.5, 0)
		e.Rate = 14
		e.LightEmission = 0.2
	elseif kind == "bubbles" then
		e.Color = ColorSequence.new(rgb(200, 240, 255))
		e.Acceleration = Vector3.new(0, 2.5, 0)
		e.Size = NumberSequence.new(0.35)
	elseif kind == "dust" then
		e.Color = ColorSequence.new(rgb(200, 230, 255))
		e.Rate = 4
	elseif kind == "embers" then
		e.Color = ColorSequence.new(rgb(255, 160, 60), rgb(255, 80, 30))
		e.LightEmission = 1
		e.Acceleration = Vector3.new(0, 3, 0)
		e.Rate = 12
		e.Size = NumberSequence.new(0.2)
	end
	e.Parent = parent
	return e
end

-- An invisible box that particles drift out of.
function Props.emitter(parent: Instance, at: Vector3, size: Vector3, kind: string)
	local box = part(parent, { Name = "Effect_" .. kind, Size = size, CFrame = CFrame.new(at), Transparency = 1, CanCollide = false, CanQuery = false, CastShadow = false })
	Props.particles(box, kind)
	return box
end

return Props
