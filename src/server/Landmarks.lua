-- Landmarks: the big, memorable thing on each island, built round that island's
-- second cave exit (Caves.lua carves a ramp from the Upper Chamber up to it), so the
-- landmark is both a place to meet and a way into the caves. Also marks the secret
-- rooms deep in the caves, which are kept empty for traders and events later.
local Landmarks = {}

local rng = Random.new(777)

local function part(parent: Instance, props): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end

local function wedge(parent: Instance, props): WedgePart
	local p = Instance.new("WedgePart")
	p.Anchored = true
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end

local function nameSign(model: Model, text: string, at: Vector3)
	local anchor = part(model, { Name = "SignAnchor", Size = Vector3.one, CFrame = CFrame.new(at), Transparency = 1, CanCollide = false, CanQuery = false })
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(260, 44)
	gui.MaxDistance = 220
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.FontFace = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Bold)
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 236, 196)
	label.TextStrokeTransparency = 0.2
	label.Text = text
	label.Parent = gui
	gui.Parent = anchor
end

-- Each builder gets the hole's centre (on the ground) and puts the landmark round it.
-- Everything stands at least 11 studs from the centre, so the hole stays open.
local BUILDERS = {}

-- Clover Island: the Old Well. A round stone wall with a timber roof on four posts.
function BUILDERS.clover(m: Model, c: Vector3, groundAt)
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2
		local p = c + Vector3.new(math.cos(a) * 12, 0, math.sin(a) * 12)
		part(m, { Name = "WellStone", Size = Vector3.new(5, 4 + (i % 3), 3), CFrame = CFrame.lookAt(p + Vector3.new(0, 1.5, 0), c + Vector3.new(0, 1.5, 0)), Color = Color3.fromRGB(150, 146, 138), Material = Enum.Material.Cobblestone })
	end
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + math.pi / 4
		local p = c + Vector3.new(math.cos(a) * 13.5, 0, math.sin(a) * 13.5)
		part(m, { Name = "Post", Size = Vector3.new(1.4, 18, 1.4), CFrame = CFrame.new(p + Vector3.new(0, 9, 0)), Color = Color3.fromRGB(110, 76, 48), Material = Enum.Material.Wood })
	end
	for side = -1, 1, 2 do
		wedge(m, { Name = "Roof", Size = Vector3.new(32, 7, 16), CFrame = CFrame.new(c + Vector3.new(0, 21.5, side * 8)) * CFrame.Angles(0, if side > 0 then 0 else math.pi, 0), Color = Color3.fromRGB(150, 70, 52), Material = Enum.Material.WoodPlanks })
	end
	part(m, { Name = "Beam", Size = Vector3.new(30, 1.2, 1.2), CFrame = CFrame.new(c + Vector3.new(0, 18, 0)), Color = Color3.fromRGB(96, 64, 40), Material = Enum.Material.Wood })
	part(m, { Name = "Rope", Size = Vector3.new(0.3, 14, 0.3), CFrame = CFrame.new(c + Vector3.new(0, 11, 0)), Color = Color3.fromRGB(200, 180, 130), Material = Enum.Material.Fabric, CanCollide = false })
	return "The Old Well", 26
end

-- Pine Hills: the Hollow Stump of a tree that was taller than the hills.
function BUILDERS.hills(m: Model, c: Vector3, groundAt)
	local bark = Color3.fromRGB(92, 62, 40)
	for i = 0, 17 do
		local a = i / 18 * math.pi * 2
		local h = 14 + math.sin(i * 1.7) * 5 + rng:NextNumber(0, 4)
		local p = c + Vector3.new(math.cos(a) * 13, 0, math.sin(a) * 13)
		part(m, { Name = "Bark", Size = Vector3.new(5.4, h, 3.4), CFrame = CFrame.lookAt(p + Vector3.new(0, h / 2 - 2, 0), c + Vector3.new(0, h / 2 - 2, 0)), Color = bark, Material = Enum.Material.Wood })
		if i % 3 == 0 then
			local r = c + Vector3.new(math.cos(a) * 19, 0, math.sin(a) * 19)
			part(m, { Name = "Root", Size = Vector3.new(3, 3, 12), CFrame = CFrame.lookAt(r + Vector3.new(0, 0.5, 0), c + Vector3.new(0, 4, 0)), Color = bark, Material = Enum.Material.Wood })
		end
	end
	for i = 1, 5 do
		local a = rng:NextNumber(0, math.pi * 2)
		local p = c + Vector3.new(math.cos(a) * 13, rng:NextNumber(4, 12), math.sin(a) * 13)
		part(m, { Name = "Moss", Shape = Enum.PartType.Ball, Size = Vector3.one * rng:NextNumber(3, 5), CFrame = CFrame.new(p), Color = Color3.fromRGB(78, 128, 58), Material = Enum.Material.Grass, CanCollide = false })
	end
	return "The Hollow Stump", 26
end

-- Stone Shelf: the Sentinel Arch, two leaning pillars and a capstone over the hole.
function BUILDERS.rock(m: Model, c: Vector3, groundAt)
	local stone = Color3.fromRGB(132, 128, 122)
	for side = -1, 1, 2 do
		for k = 0, 4 do
			local p = c + Vector3.new(side * (16 - k * 1.2), k * 7 + 3.5, 0)
			part(m, { Name = "Pillar", Size = Vector3.new(7 - k * 0.5, 7.4, 7 - k * 0.5), CFrame = CFrame.new(p) * CFrame.Angles(0, k * 0.4, side * 0.08), Color = stone, Material = Enum.Material.Slate })
		end
	end
	part(m, { Name = "Capstone", Size = Vector3.new(34, 6, 9), CFrame = CFrame.new(c + Vector3.new(0, 38, 0)) * CFrame.Angles(0, 0, 0.04), Color = Color3.fromRGB(116, 112, 108), Material = Enum.Material.Slate })
	for i = 0, 2 do
		part(m, { Name = "Rune", Size = Vector3.new(2, 2, 0.4), CFrame = CFrame.new(c + Vector3.new(-6 + i * 6, 38, -4.6)), Color = Color3.fromRGB(120, 220, 255), Material = Enum.Material.Neon, CanCollide = false })
	end
	return "The Sentinel Arch", 46
end

-- Frost Isle: the Ice Crown, a ring of tall ice spires.
function BUILDERS.snow(m: Model, c: Vector3, groundAt)
	for i = 0, 8 do
		local a = i / 9 * math.pi * 2
		local h = 18 + (i % 3) * 8
		local p = c + Vector3.new(math.cos(a) * 14, 0, math.sin(a) * 14)
		part(m, { Name = "Spire", Size = Vector3.new(3.6, h, 3.6), CFrame = CFrame.new(p + Vector3.new(0, h / 2 - 1, 0)) * CFrame.Angles(math.cos(a) * 0.18, a, math.sin(a) * 0.18), Color = Color3.fromRGB(170, 220, 245), Material = Enum.Material.Glass, Transparency = 0.25 })
	end
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(160, 220, 255)
	light.Range = 30
	light.Parent = part(m, { Name = "Glow", Size = Vector3.one, CFrame = CFrame.new(c + Vector3.new(0, 6, 0)), Transparency = 1, CanCollide = false, CanQuery = false })
	return "The Ice Crown", 40
end

-- Slime Marsh: the Toadstool Sink, giant glowing mushrooms round a bog hole.
function BUILDERS.marsh(m: Model, c: Vector3, groundAt)
	for i = 0, 6 do
		local a = i / 7 * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local h = rng:NextNumber(12, 24)
		local p = c + Vector3.new(math.cos(a) * 15, 0, math.sin(a) * 15)
		part(m, { Name = "Stalk", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, 2.6, 2.6), CFrame = CFrame.new(p + Vector3.new(0, h / 2 - 1, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(226, 214, 186), Material = Enum.Material.SmoothPlastic })
		local cap = part(m, { Name = "Cap", Shape = Enum.PartType.Ball, Size = Vector3.new(h * 0.7, h * 0.28, h * 0.7), CFrame = CFrame.new(p + Vector3.new(0, h, 0)), Color = if i % 2 == 0 then Color3.fromRGB(120, 210, 90) else Color3.fromRGB(170, 90, 200), Material = Enum.Material.Neon })
		cap.Transparency = 0.15
	end
	return "The Toadstool Sink", 34
end

-- Ember Isle: the Smoking Vent, a ring of basalt columns that never stops smoking.
function BUILDERS.ember(m: Model, c: Vector3, groundAt)
	for i = 0, 13 do
		local a = i / 14 * math.pi * 2
		local h = 8 + (i % 4) * 4
		local p = c + Vector3.new(math.cos(a) * 13, 0, math.sin(a) * 13)
		part(m, { Name = "Column", Size = Vector3.new(4, h, 4), CFrame = CFrame.new(p + Vector3.new(0, h / 2 - 1, 0)) * CFrame.Angles(0, a, 0), Color = Color3.fromRGB(40, 38, 44), Material = Enum.Material.Basalt })
	end
	local core = part(m, { Name = "Smoke", Size = Vector3.one, CFrame = CFrame.new(c + Vector3.new(0, 2, 0)), Transparency = 1, CanCollide = false, CanQuery = false })
	local smoke = Instance.new("Smoke")
	smoke.Color = Color3.fromRGB(80, 76, 80)
	smoke.Size = 12
	smoke.RiseVelocity = 8
	smoke.Opacity = 0.25
	smoke.Parent = core
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 120, 50)
	light.Range = 26
	light.Brightness = 1.5
	light.Parent = core
	return "The Smoking Vent", 28
end

-- Driftwood Cay: The Wreck, a ship run aground and broken open round the hole.
function BUILDERS.cay(m: Model, c: Vector3, groundAt)
	local wood, dark = Color3.fromRGB(122, 86, 56), Color3.fromRGB(80, 56, 38)
	for side = -1, 1, 2 do
		for k = -3, 3 do
			local p = c + Vector3.new(side * 12, 3 + math.abs(k) * 0.3, k * 6)
			part(m, { Name = "Hull", Size = Vector3.new(1.4, 8 - math.abs(k) * 0.6, 6), CFrame = CFrame.new(p) * CFrame.Angles(0, 0, side * 0.35), Color = if k % 2 == 0 then wood else dark, Material = Enum.Material.WoodPlanks })
		end
	end
	part(m, { Name = "Keel", Size = Vector3.new(2, 2, 44), CFrame = CFrame.new(c + Vector3.new(14, 0, 0)) * CFrame.Angles(0.1, 0, 0.2), Color = dark, Material = Enum.Material.Wood })
	local mast = part(m, { Name = "Mast", Size = Vector3.new(1.6, 30, 1.6), CFrame = CFrame.new(c + Vector3.new(-13, 13, 8)) * CFrame.Angles(0.25, 0, -0.35), Color = wood, Material = Enum.Material.Wood })
	part(m, { Name = "Sail", Size = Vector3.new(12, 10, 0.3), CFrame = mast.CFrame * CFrame.new(5, 6, 0) * CFrame.Angles(0, 0, 0.1), Color = Color3.fromRGB(226, 214, 186), Material = Enum.Material.Fabric, CanCollide = false })
	return "The Wreck", 30
end

-- Coral Atoll: the Coral Arch, a bright reef arch with shells round its feet.
function BUILDERS.atoll(m: Model, c: Vector3, groundAt)
	local corals = { Color3.fromRGB(255, 120, 120), Color3.fromRGB(255, 170, 90), Color3.fromRGB(200, 120, 255) }
	for k = 0, 12 do
		local a = k / 12 * math.pi
		local p = c + Vector3.new(math.cos(a) * 15, math.sin(a) * 20, 0)
		part(m, { Name = "Coral", Shape = Enum.PartType.Ball, Size = Vector3.one * (6 - math.sin(a) * 1.5), CFrame = CFrame.new(p), Color = corals[k % 3 + 1], Material = Enum.Material.Pebble })
	end
	for i = 1, 8 do
		local a = rng:NextNumber(0, math.pi * 2)
		part(m, { Name = "Shell", Size = Vector3.new(1.6, 0.6, 1.6), CFrame = CFrame.new(c + Vector3.new(math.cos(a) * 14, 0.3, math.sin(a) * 14)) * CFrame.Angles(0, a, 0.3), Color = Color3.fromRGB(250, 226, 200), CanCollide = false })
	end
	return "The Coral Arch", 28
end

-- Silver Crags: the Needle, one spire far taller than the rest, with a silver band.
function BUILDERS.crags(m: Model, c: Vector3, groundAt)
	for k = 0, 6 do
		local w = 9 - k * 1.1
		part(m, { Name = "Needle", Size = Vector3.new(w, 9, w), CFrame = CFrame.new(c + Vector3.new(16, k * 8.6 + 4, 0)) * CFrame.Angles(0, k * 0.5, 0.03 * k), Color = Color3.fromRGB(98, 98, 106), Material = Enum.Material.Slate })
	end
	part(m, { Name = "Band", Size = Vector3.new(8.6, 1.2, 8.6), CFrame = CFrame.new(c + Vector3.new(16, 30, 0)), Color = Color3.fromRGB(210, 214, 222), Material = Enum.Material.Metal })
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		part(m, { Name = "Rubble", Size = Vector3.new(4, 3, 4), CFrame = CFrame.new(c + Vector3.new(math.cos(a) * 12, 1, math.sin(a) * 12)) * CFrame.Angles(a, a, 0), Color = Color3.fromRGB(120, 120, 126), Material = Enum.Material.Slate })
	end
	return "The Needle", 64
end

-- Gold Mesa: the Lookout, a timber watchtower with a gold-capped roof.
function BUILDERS.mesa(m: Model, c: Vector3, groundAt)
	local wood = Color3.fromRGB(128, 92, 58)
	for sx = -1, 1, 2 do
		for sz = -1, 1, 2 do
			part(m, { Name = "Leg", Size = Vector3.new(1.6, 34, 1.6), CFrame = CFrame.new(c + Vector3.new(sx * 13, 17, sz * 13)) * CFrame.Angles(sz * -0.06, 0, sx * 0.06), Color = wood, Material = Enum.Material.Wood })
		end
	end
	part(m, { Name = "Deck", Size = Vector3.new(24, 1.4, 24), CFrame = CFrame.new(c + Vector3.new(0, 33, 0)), Color = wood, Material = Enum.Material.WoodPlanks })
	for k = 0, 3 do
		local a = k / 4 * math.pi * 2
		part(m, { Name = "Rail", Size = Vector3.new(24, 3, 0.6), CFrame = CFrame.new(c + Vector3.new(math.cos(a) * 12, 35, math.sin(a) * 12)) * CFrame.Angles(0, a + math.pi / 2, 0), Color = wood, Material = Enum.Material.Wood })
	end
	wedge(m, { Name = "Roof", Size = Vector3.new(26, 8, 13), CFrame = CFrame.new(c + Vector3.new(0, 44, 6.5)), Color = Color3.fromRGB(236, 192, 72), Material = Enum.Material.Metal })
	wedge(m, { Name = "Roof", Size = Vector3.new(26, 8, 13), CFrame = CFrame.new(c + Vector3.new(0, 44, -6.5)) * CFrame.Angles(0, math.pi, 0), Color = Color3.fromRGB(236, 192, 72), Material = Enum.Material.Metal })
	return "The Lookout", 50
end

-- Old Ruins: the Sunken Temple, broken columns round a stepped pit.
function BUILDERS.ruins(m: Model, c: Vector3, groundAt)
	local stone = Color3.fromRGB(176, 168, 150)
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		local h = if i % 3 == 0 then 6 else 22
		local p = c + Vector3.new(math.cos(a) * 18, 0, math.sin(a) * 18)
		part(m, { Name = "Column", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, 4, 4), CFrame = CFrame.new(p + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = stone, Material = Enum.Material.Limestone })
		if h > 10 and i % 2 == 0 then
			local q = c + Vector3.new(math.cos(a + 0.26) * 18, 0, math.sin(a + 0.26) * 18)
			part(m, { Name = "Lintel", Size = Vector3.new(4, 3, 10), CFrame = CFrame.lookAt((p + q) / 2 + Vector3.new(0, h + 1.5, 0), q + Vector3.new(0, h + 1.5, 0)), Color = stone, Material = Enum.Material.Limestone })
		end
	end
	for k = 1, 3 do
		part(m, { Name = "Step", Size = Vector3.new(4, 1, 30 - k * 4), CFrame = CFrame.new(c + Vector3.new(11 + k * 2.5, k - 0.5, 0)), Color = stone, Material = Enum.Material.Limestone })
	end
	local idol = part(m, { Name = "Idol", Size = Vector3.new(3, 6, 3), CFrame = CFrame.new(c + Vector3.new(-22, 3, 0)), Color = Color3.fromRGB(140, 120, 90), Material = Enum.Material.Limestone })
	part(m, { Name = "Eyes", Size = Vector3.new(0.4, 0.6, 2), CFrame = idol.CFrame * CFrame.new(1.6, 1.6, 0), Color = Color3.fromRGB(120, 255, 210), Material = Enum.Material.Neon, CanCollide = false })
	return "The Sunken Temple", 30
end

-- Skull Key: Skull Rock, a giant stone skull with glowing eyes.
function BUILDERS.skull(m: Model, c: Vector3, groundAt)
	local bone = Color3.fromRGB(222, 214, 196)
	part(m, { Name = "Cranium", Shape = Enum.PartType.Ball, Size = Vector3.one * 30, CFrame = CFrame.new(c + Vector3.new(0, 18, 18)), Color = bone, Material = Enum.Material.Limestone })
	part(m, { Name = "Jaw", Size = Vector3.new(20, 8, 14), CFrame = CFrame.new(c + Vector3.new(0, 4, 10)), Color = bone, Material = Enum.Material.Limestone })
	for _, x in { -6, 6 } do
		part(m, { Name = "Eye", Shape = Enum.PartType.Ball, Size = Vector3.one * 7, CFrame = CFrame.new(c + Vector3.new(x, 20, 4)), Color = Color3.fromRGB(255, 90, 60), Material = Enum.Material.Neon, CanCollide = false })
	end
	return "Skull Rock", 40
end

-- A plain cairn for any island without its own landmark.
function BUILDERS.default(m: Model, c: Vector3, groundAt)
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		local p = c + Vector3.new(math.cos(a) * 12, 0, math.sin(a) * 12)
		part(m, { Name = "Standing", Size = Vector3.new(3, 9 + (i % 2) * 5, 2), CFrame = CFrame.lookAt(p + Vector3.new(0, 4, 0), c + Vector3.new(0, 4, 0)), Color = Color3.fromRGB(140, 134, 124), Material = Enum.Material.Slate })
	end
	return "Standing Stones", 22
end

Landmarks.Builders = BUILDERS

-- Builds one landmark of `kind` round the point `centre` (on the ground). Returns the model.
function Landmarks.place(kind: string, centre: Vector3, groundAt, title: string?): Model
	local m = Instance.new("Model")
	local builder = BUILDERS[kind] or BUILDERS.default
	local name, height = builder(m, centre, groundAt)
	m.Name = title or name
	m.WorldPivot = CFrame.new(centre)
	nameSign(m, title or name, centre + Vector3.new(0, height + 6, 0))
	m:SetAttribute("Landmark", title or name)
	return m
end

local function secretRoom(parent: Instance, room)
	local m = Instance.new("Model")
	m.Name = "SecretRoom"
	local floorY = room.pos.Y - room.size.Y / 2
	local cf = CFrame.lookAt(room.pos, room.pos + room.facing)
	local half = Vector3.new(room.size.Z, 0, room.size.X) / 2 - Vector3.new(3, 0, 3)
	-- Carved pillars in the corners and a cold brazier in the middle: someone was here.
	for sx = -1, 1, 2 do
		for sz = -1, 1, 2 do
			local p = cf * Vector3.new(sx * half.X, 0, sz * half.Z)
			part(m, { Name = "Pillar", Size = Vector3.new(3, room.size.Y, 3), CFrame = CFrame.new(p.X, floorY + room.size.Y / 2, p.Z), Color = Color3.fromRGB(96, 92, 100), Material = Enum.Material.Slate })
		end
	end
	local bowl = part(m, { Name = "Brazier", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.6, 6, 6), CFrame = CFrame.new(room.pos.X, floorY + 2.2, room.pos.Z) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(70, 60, 54), Material = Enum.Material.Metal })
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(150, 130, 255)
	light.Range = 22
	light.Brightness = 0.7
	light.Parent = bowl
	-- The marker events and traders will use later.
	local marker = part(m, { Name = "Marker", Size = Vector3.new(room.size.Z, room.size.Y, room.size.X), CFrame = cf, Transparency = 1, CanCollide = false, CanQuery = false })
	marker:SetAttribute("Reserved", "trader_or_event")
	m.Parent = parent
end

-- network: the result of Caves.build. spotOn(isl) finds a flat open spot for islands
-- whose landmark has no cave exit under it.
function Landmarks.build(network, islands: { any }, groundAt, spotOn: (any) -> Vector3?)
	local f = workspace:FindFirstChild("Landmarks") or Instance.new("Folder")
	f.Name = "Landmarks"
	f.Parent = workspace
	local done = {}
	for _, e in network.exits do
		-- e.pos is the ground before the exit was carved (the hole is there now).
		local m = Landmarks.place(e.biome, e.pos, groundAt)
		m:SetAttribute("CaveExit", true)
		m.Parent = f
		done[e.island] = true
	end
	for i, isl in islands do
		if not done[i] then
			local spot = spotOn(isl)
			if spot then
				Landmarks.place(isl.biome, spot, groundAt).Parent = f
			end
		end
	end
	local rooms = workspace:FindFirstChild("SecretRooms") or Instance.new("Folder")
	rooms.Name = "SecretRooms"
	rooms.Parent = workspace
	for _, room in network.secretRooms do
		secretRoom(rooms, room)
	end
end

return Landmarks
