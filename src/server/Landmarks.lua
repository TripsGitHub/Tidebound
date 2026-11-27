-- Landmarks: the big, memorable thing on each island, built round that island's
-- second cave exit (Caves.lua carves a ramp from the Upper Chamber up to it), so the
-- landmark is both a place to meet and a way into the caves. Also marks the secret
-- rooms deep in the caves, which are kept empty for traders and events later.
local Landmarks = {}

local Props = require(script.Parent.Props)
local WorldBake = require(script.Parent.WorldBake)
local Meshes = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Meshes"))

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

-- Terrain rock, so a landmark made of stone is part of the island and not a pile of
-- bricks on top of it: balls filled along a line from a (radius r0) to b (radius r1).
local function rockLine(a: Vector3, b: Vector3, r0: number, r1: number, mat: Enum.Material)
	local len = (b - a).Magnitude
	local steps = math.max(1, math.ceil(len / (math.min(r0, r1) * 0.5)))
	for k = 0, steps do
		local t = k / steps
		WorldBake.terrain:FillBall(a:Lerp(b, t), r0 + (r1 - r0) * t, mat)
	end
end

-- An invisible marker at the top of the landmark (admin teleports aim at it). No
-- floating name: the minimap names places instead.
local function nameSign(model: Model, _text: string, at: Vector3)
	part(model, { Name = "SignAnchor", Size = Vector3.one, CFrame = CFrame.new(at), Transparency = 1, CanCollide = false, CanQuery = false })
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

-- Stone Shelf: the Sentinel Arch, one great bow of living rock over the hole.
function BUILDERS.rock(m: Model, c: Vector3, groundAt)
	local rock = Enum.Material.Rock
	for side = -1, 1, 2 do
		rockLine(c + Vector3.new(side * 20, -6, 1), c + Vector3.new(side * 15, 22, 0), 7.5, 5.5, rock)
		rockLine(c + Vector3.new(side * 15, 22, 0), c + Vector3.new(side * 12, 30, 0), 5.5, 5, rock)
	end
	for k = 0, 16 do
		local a = k / 16 * math.pi
		WorldBake.terrain:FillBall(c + Vector3.new(math.cos(a) * 12, 30 + math.sin(a) * 7, 0), 5 - math.sin(a) * 0.6, rock)
	end
	return "The Sentinel Arch", 44
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

-- Ember Isle: the Smoking Vent, a low crater of black rock that never stops smoking.
function BUILDERS.ember(m: Model, c: Vector3, groundAt)
	local T = WorldBake.terrain
	for i = 0, 17 do
		local a = i / 18 * math.pi * 2
		local h = 3 + math.sin(i * 1.9) * 2.5 + (i % 3)
		local p = c + Vector3.new(math.cos(a) * 17, h - 2, math.sin(a) * 17)
		T:FillBall(p, 5 + (i % 2), Enum.Material.Basalt)
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
	return "The Smoking Vent", 24
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

-- Coral Atoll: the Coral Arch, a bow of pale reef rock with coral growing on it.
function BUILDERS.atoll(m: Model, c: Vector3, groundAt)
	local reef = Enum.Material.Limestone
	for side = -1, 1, 2 do
		rockLine(c + Vector3.new(side * 18, -5, 0), c + Vector3.new(side * 14, 14, 0), 6, 4.5, reef)
	end
	for k = 0, 12 do
		local a = k / 12 * math.pi
		WorldBake.terrain:FillBall(c + Vector3.new(math.cos(a) * 14, 14 + math.sin(a) * 6, 0), 4.5 - math.sin(a) * 0.8, reef)
	end
	-- Coral clumps in three colours, a few big ones, sitting on the arch and at its feet.
	local corals = { Color3.fromRGB(255, 120, 120), Color3.fromRGB(255, 170, 90), Color3.fromRGB(200, 120, 255) }
	local spots = {
		Vector3.new(-17, 2, 3), Vector3.new(-16, 4, -3), Vector3.new(18, 1, 4), Vector3.new(15, 6, -3),
		Vector3.new(-9, 22, 2), Vector3.new(4, 24, -2), Vector3.new(11, 20, 3),
	}
	for i, o in spots do
		local size = if i <= 4 then rng:NextNumber(3.5, 5) else rng:NextNumber(2.5, 3.5)
		local col = corals[i % 3 + 1]
		local at = c + o
		part(m, { Name = "Coral", Shape = Enum.PartType.Ball, Size = Vector3.one * size, CFrame = CFrame.new(at), Color = col, Material = Enum.Material.Pebble, CanCollide = false })
		part(m, { Name = "Coral", Shape = Enum.PartType.Ball, Size = Vector3.one * size * 0.6, CFrame = CFrame.new(at + Vector3.new(size * 0.4, size * 0.3, 0)), Color = col:Lerp(Color3.new(1, 1, 1), 0.15), Material = Enum.Material.Pebble, CanCollide = false })
	end
	for i = 1, 8 do
		local a = rng:NextNumber(0, math.pi * 2)
		part(m, { Name = "Shell", Size = Vector3.new(1.6, 0.6, 1.6), CFrame = CFrame.new(c + Vector3.new(math.cos(a) * 14, 0.3, math.sin(a) * 14)) * CFrame.Angles(0, a, 0.3), Color = Color3.fromRGB(250, 226, 200), CanCollide = false })
	end
	return "The Coral Arch", 28
end

-- Silver Crags: the Needle, one spire of slate far taller than the rest of the crags.
function BUILDERS.crags(m: Model, c: Vector3, groundAt)
	local slate = Enum.Material.Slate
	local base = c + Vector3.new(19, -8, 0)
	local kink = base + Vector3.new(-1.5, 34, 1)
	rockLine(base, kink, 9, 5, slate)
	rockLine(kink, kink + Vector3.new(1.5, 28, -0.5), 5, 1.6, slate)
	-- Two shoulders at its foot, so it grows out of the ground instead of standing on it.
	WorldBake.terrain:FillBall(base + Vector3.new(6, 4, 5), 6, slate)
	WorldBake.terrain:FillBall(base + Vector3.new(4, 2, -7), 5, slate)
	return "The Needle", 62
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
	-- The Blender skull (cracked dome, deep sockets with a glow, broken teeth, moss),
	-- half sunk into the sand behind the hole, staring out over it.
	local skull = Meshes.has("skull_rock") and Meshes.build("skull_rock", { scale = 1.1 })
	if skull then
		skull:PivotTo(CFrame.new(c + Vector3.new(0, -1.5, 30)))
		for _, p in skull:GetChildren() do
			if p:IsA("BasePart") and p.Name == "Eye" then
				local light = Instance.new("PointLight")
				light.Color, light.Range, light.Brightness = p.Color, 18, 2
				light.Parent = p
			end
		end
		skull.Name = "SkullRock"
		skull.Parent = m
		return "Skull Rock", 40
	end
	local bone = Color3.fromRGB(222, 214, 196)
	part(m, { Name = "Cranium", Shape = Enum.PartType.Ball, Size = Vector3.one * 30, CFrame = CFrame.new(c + Vector3.new(0, 18, 18)), Color = bone, Material = Enum.Material.Limestone })
	part(m, { Name = "Jaw", Size = Vector3.new(20, 8, 14), CFrame = CFrame.new(c + Vector3.new(0, 4, 10)), Color = bone, Material = Enum.Material.Limestone })
	for _, x in { -6, 6 } do
		part(m, { Name = "Eye", Shape = Enum.PartType.Ball, Size = Vector3.one * 7, CFrame = CFrame.new(c + Vector3.new(x, 20, 4)), Color = Color3.fromRGB(255, 90, 60), Material = Enum.Material.Neon, CanCollide = false })
	end
	return "Skull Rock", 40
end

-- Sunfruit Isle: the Sunfruit Giant, a palm ten times the size of any other, bent over
-- the island with a crown of huge fronds and a heavy cluster of glowing fruit.
function BUILDERS.fruit(m: Model, c: Vector3, groundAt)
	local bark, barkDark = Color3.fromRGB(176, 124, 70), Color3.fromRGB(140, 96, 54)
	local base = c + Vector3.new(14, 0, 0)
	local p = base
	local dir = Vector3.new(-0.25, 1, 0).Unit
	for k = 0, 13 do
		local w = 5.5 - k * 0.22
		local seg = Props.part(m, { Name = "Trunk", Size = Vector3.new(w, 4.2, w), CFrame = CFrame.lookAt(p, p + Vector3.new(1, 0, 0), dir) * CFrame.Angles(0, k * 0.3, 0), Color = if k % 2 == 0 then bark else barkDark, Material = Enum.Material.Wood })
		seg.CFrame = CFrame.fromMatrix(p + dir * 2, dir:Cross(Vector3.zAxis).Unit, dir) * CFrame.Angles(0, k * 0.3, 0)
		p = p + dir * 4
		dir = (dir + Vector3.new(-0.06, -0.01, 0)).Unit
	end
	local top = p
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		local tip = top + out * 22 + Vector3.new(0, -7, 0)
		local mid = (top + tip) / 2
		Props.part(m, { Class = "WedgePart", Name = "Frond", Size = Vector3.new(0.6, 3, (tip - top).Magnitude), CFrame = CFrame.lookAt(mid, tip) * CFrame.Angles(0, 0, math.pi / 2), Color = if i % 2 == 0 then Color3.fromRGB(110, 180, 60) else Color3.fromRGB(140, 200, 70), Material = Enum.Material.Grass, CanCollide = false })
	end
	for i = 1, 9 do
		local fruit = Props.part(m, { Name = "Sunfruit", Shape = Enum.PartType.Ball, Size = Vector3.one * rng:NextNumber(2.4, 3.4), CFrame = CFrame.new(top + Vector3.new(rng:NextNumber(-3, 3), rng:NextNumber(-5, -2), rng:NextNumber(-3, 3))), Color = if i % 3 == 0 then Color3.fromRGB(255, 200, 60) else Color3.fromRGB(255, 140, 40), Material = Enum.Material.Neon, CanCollide = false })
		if i == 1 then
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 180, 80)
			light.Range = 30
			light.Brightness = 1.4
			light.Parent = fruit
		end
	end
	return "The Sunfruit Giant", (top - c).Y + 6
end

-- Maw Rock: a huge jaw of black stone teeth round a dark hollow, the sign that the
-- caves under this rock go down to the Maw, the deepest place in the world.
function BUILDERS.maw(m: Model, c: Vector3, groundAt)
	local tooth, gum = Color3.fromRGB(228, 220, 200), Color3.fromRGB(46, 40, 44)
	for i = 0, 13 do
		local a = i / 14 * math.pi * 2
		local r = 16 + rng:NextNumber(-1.5, 1.5)
		local at = c + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		local h = rng:NextNumber(12, 22)
		local lean = CFrame.lookAt(at, Vector3.new(c.X, at.Y, c.Z)) * CFrame.Angles(math.rad(-rng:NextNumber(14, 26)), 0, 0)
		Props.part(m, { Class = "WedgePart", Name = "Tooth", Size = Vector3.new(rng:NextNumber(3, 5), h, rng:NextNumber(4, 6)), CFrame = lean * CFrame.new(0, h / 2, 0), Color = tooth, Material = Enum.Material.Limestone })
		Props.part(m, { Name = "Gum", Size = Vector3.new(6, 3, 7), CFrame = CFrame.new(at + Vector3.new(0, 1, 0)) * CFrame.Angles(0, -a, 0), Color = gum, Material = Enum.Material.Basalt })
	end
	-- The throat: a dark disc with a dim red glow deep inside.
	Props.part(m, { Shape = Enum.PartType.Cylinder, Name = "Throat", Size = Vector3.new(0.6, 26, 26), CFrame = CFrame.new(c + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(18, 14, 16), Material = Enum.Material.Basalt, CanCollide = false })
	local glow = Props.part(m, { Name = "Glow", Size = Vector3.new(4, 0.4, 4), CFrame = CFrame.new(c + Vector3.new(0, 0.5, 0)), Color = Color3.fromRGB(200, 40, 30), Material = Enum.Material.Neon, CanCollide = false, Transparency = 0.4 })
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = Color3.fromRGB(255, 60, 40), 34, 1.6
	light.Parent = glow
	return "The Maw", 30
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

-- Details and effects added round each landmark after it's built, so each one feels
-- lived in: props people left, plants, and something moving in the air.
local function ring(c: Vector3, r: number, a: number): Vector3
	return c + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
end
local DETAIL = {}
function DETAIL.clover(m, c)
	Props.flowers(m, c, 22, 26)
	Props.barrel(m, CFrame.new(ring(c, 17, 0.3)))
	Props.crate(m, CFrame.new(ring(c, 18, 0.8)) * CFrame.Angles(0, 0.4, 0), 2.6)
	Props.torchPost(m, ring(c, 16, 2.4), 6)
	Props.torchPost(m, ring(c, 16, 5.6), 6)
	local glow = Props.part(m, { Name = "WellGlow", Size = Vector3.new(12, 0.4, 12), CFrame = CFrame.new(c + Vector3.new(0, -5, 0)), Color = Color3.fromRGB(90, 200, 230), Material = Enum.Material.Neon, Transparency = 0.5, CanCollide = false, CanQuery = false })
	Props.particles(glow, "fireflies")
end
function DETAIL.hills(m, c)
	Props.emitter(m, c + Vector3.new(0, 8, 0), Vector3.new(30, 10, 30), "fireflies")
	for i = 1, 7 do
		local p = ring(c, rng:NextNumber(15, 22), rng:NextNumber(0, math.pi * 2))
		local cap = Props.part(m, { Name = "Mushroom", Shape = Enum.PartType.Ball, Size = Vector3.new(2.4, 1, 2.4), CFrame = CFrame.new(p + Vector3.new(0, 1.4, 0)), Color = if i % 2 == 0 then Color3.fromRGB(210, 70, 60) else Color3.fromRGB(236, 196, 120), CanCollide = false })
		Props.part(m, { Name = "MushroomStem", Size = Vector3.new(0.6, 1.4, 0.6), CFrame = cap.CFrame - Vector3.new(0, 0.7, 0), Color = Color3.fromRGB(240, 230, 210), CanCollide = false })
	end
	Props.logPile(m, CFrame.new(ring(c, 22, 1.2)) * CFrame.Angles(0, 1.2, 0))
end
function DETAIL.rock(m, c)
	Props.emitter(m, c + Vector3.new(0, 30, 0), Vector3.new(28, 16, 8), "dust")
end
function DETAIL.snow(m, c)
	Props.emitter(m, c + Vector3.new(0, 30, 0), Vector3.new(40, 2, 40), "snow")
	for i = 0, 5 do
		Props.part(m, { Name = "IceShard", Size = Vector3.new(1.2, rng:NextNumber(3, 6), 1.2), CFrame = CFrame.new(ring(c, rng:NextNumber(19, 25), i * 1.05) + Vector3.new(0, 1.5, 0)) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), 0, rng:NextNumber(-0.4, 0.4)), Color = Color3.fromRGB(190, 230, 250), Material = Enum.Material.Glass, Transparency = 0.3 })
	end
	Props.campfire(m, ring(c, 24, 2))
end
function DETAIL.marsh(m, c)
	Props.emitter(m, c + Vector3.new(0, 8, 0), Vector3.new(34, 12, 34), "spores")
	for i = 0, 9 do
		local p = ring(c, rng:NextNumber(18, 26), i * 0.63)
		Props.part(m, { Name = "Reed", Size = Vector3.new(0.3, rng:NextNumber(3, 5), 0.3), CFrame = CFrame.new(p + Vector3.new(0, 2, 0)) * CFrame.Angles(rng:NextNumber(-0.2, 0.2), 0, rng:NextNumber(-0.2, 0.2)), Color = Color3.fromRGB(110, 140, 60), CanCollide = false })
	end
end
function DETAIL.ember(m, c)
	Props.emitter(m, c + Vector3.new(0, 3, 0), Vector3.new(10, 2, 10), "embers")
	for i = 0, 5 do
		local p = ring(c, rng:NextNumber(18, 24), i * 1.05)
		local crack = Props.part(m, { Name = "LavaCrack", Size = Vector3.new(0.8, 0.3, rng:NextNumber(4, 8)), CFrame = CFrame.new(p + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), Color = Color3.fromRGB(255, 110, 40), Material = Enum.Material.Neon, CanCollide = false })
		crack.CastShadow = false
	end
end
function DETAIL.cay(m, c)
	Props.barrel(m, CFrame.new(ring(c, 18, 0.4)) * CFrame.Angles(0, 0, 0))
	Props.barrel(m, CFrame.new(ring(c, 20, 0.9)))
	Props.crateStack(m, CFrame.new(ring(c, 19, 2.2)) * CFrame.Angles(0, 2.2, 0))
	Props.part(m, { Name = "Chest", Size = Vector3.new(3.4, 2.2, 2.2), CFrame = CFrame.new(ring(c, 15, 4) + Vector3.new(0, 1.1, 0)) * CFrame.Angles(0, 0.6, 0.12), Color = Color3.fromRGB(120, 76, 40), Material = Enum.Material.WoodPlanks })
	Props.emitter(m, ring(c, 15, 4) + Vector3.new(0, 2.6, 0), Vector3.new(2, 1, 2), "fireflies")
end
function DETAIL.atoll(m, c)
	Props.emitter(m, c + Vector3.new(0, 4, 0), Vector3.new(20, 2, 20), "bubbles")
	Props.flowers(m, c, 22, 14)
end
function DETAIL.crags(m, c)
	Props.emitter(m, c + Vector3.new(16, 40, 0), Vector3.new(8, 30, 8), "dust")
	Props.crateStack(m, CFrame.new(ring(c, 20, 2.5)) * CFrame.Angles(0, 2.5, 0))
	Props.torchPost(m, ring(c, 18, 3.6), 6)
end
function DETAIL.mesa(m, c)
	Props.banner(m, c + Vector3.new(0, 47, 0), Props.CLOTH[1], 8)
	Props.crateStack(m, CFrame.new(ring(c, 20, 1)) * CFrame.Angles(0, 1, 0))
	Props.barrel(m, CFrame.new(ring(c, 19, 1.8)))
	Props.torchPost(m, ring(c, 17, 4), 6)
	Props.torchPost(m, ring(c, 17, 5.4), 6)
end
function DETAIL.ruins(m, c)
	Props.emitter(m, c + Vector3.new(0, 10, 0), Vector3.new(36, 14, 36), "fireflies")
	for i = 0, 11 do
		local p = ring(c, rng:NextNumber(14, 22), i * 0.52)
		Props.part(m, { Name = "Vine", Size = Vector3.new(0.3, rng:NextNumber(6, 14), 0.3), CFrame = CFrame.new(p + Vector3.new(0, 5, 0)) * CFrame.Angles(0, 0, rng:NextNumber(-0.15, 0.15)), Color = Color3.fromRGB(70, 120, 50), CanCollide = false })
	end
	Props.torchPost(m, ring(c, 25, 0), 7)
	Props.torchPost(m, ring(c, 25, math.pi), 7)
end
function DETAIL.skull(m, c)
	Props.torchPost(m, c + Vector3.new(-14, 0, -4), 8)
	Props.torchPost(m, c + Vector3.new(14, 0, -4), 8)
	Props.emitter(m, c + Vector3.new(0, 20, 4), Vector3.new(14, 6, 4), "embers")
	for i = 1, 5 do
		Props.part(m, { Name = "Bone", Size = Vector3.new(0.6, 0.6, rng:NextNumber(2, 4)), CFrame = CFrame.new(ring(c, rng:NextNumber(10, 18), rng:NextNumber(3.5, 6)) + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), Color = Color3.fromRGB(230, 222, 204), CanCollide = false })
	end
end
function DETAIL.maw(m, c)
	Props.emitter(m, c + Vector3.new(0, 4, 0), Vector3.new(22, 4, 22), "embers")
	for k = 0, 3 do
		Props.torchPost(m, ring(c, 24, k * math.pi / 2 + 0.4), 9)
	end
	for _ = 1, 8 do
		Props.part(m, { Name = "Bone", Size = Vector3.new(0.7, 0.7, rng:NextNumber(2, 5)), CFrame = CFrame.new(ring(c, rng:NextNumber(20, 30), rng:NextNumber(0, 6.28)) + Vector3.new(0, 0.35, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), Color = Color3.fromRGB(230, 222, 204), CanCollide = false })
	end
end
function DETAIL.fruit(m, c)
	Props.emitter(m, c + Vector3.new(0, 18, 0), Vector3.new(30, 10, 30), "fireflies")
	Props.crateStack(m, CFrame.new(ring(c, 18, 0.5)) * CFrame.Angles(0, 0.5, 0))
	Props.barrel(m, CFrame.new(ring(c, 17, 1.3)))
	Props.flowers(m, c, 24, 24)
end

Landmarks.Builders = BUILDERS

-- Nothing floats: every part standing near the base is pushed down to the ground under
-- it (upright posts and walls grow downwards instead, so their tops stay put).
local function ground(m: Model, base: number, groundAt)
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") and p.Name ~= "SignAnchor" and p.Transparency < 1 then
			local cf = p.CFrame
			local shape = if p:IsA("Part") then p.Shape else nil
			local verticalCylinder = shape == Enum.PartType.Cylinder and math.abs(cf.RightVector.Y) > 0.9
			local height = if verticalCylinder then p.Size.X else p.Size.Y
			local bottom = p.Position.Y - height / 2
			if bottom < base + 4 then
				local hit = groundAt(p.Position.X, p.Position.Z)
				if hit and hit.Position.Y < bottom - 0.2 then
					local gap = bottom - hit.Position.Y + 0.6
					if verticalCylinder then
						p.Size += Vector3.new(gap, 0, 0)
						p.CFrame = cf - Vector3.new(0, gap / 2, 0)
					elseif cf.UpVector.Y > 0.9 and shape ~= Enum.PartType.Ball then
						p.Size += Vector3.new(0, gap, 0)
						p.CFrame = cf - Vector3.new(0, gap / 2, 0)
					else
						p.CFrame = cf - Vector3.new(0, gap, 0)
					end
				end
			end
		end
	end
end

-- Builds one landmark of `kind` round the point `centre` (on the ground). Returns the model.
function Landmarks.place(kind: string, centre: Vector3, groundAt, title: string?): Model
	local m = Instance.new("Model")
	local builder = BUILDERS[kind] or BUILDERS.default
	local name, height = builder(m, centre, groundAt)
	if DETAIL[kind] then
		DETAIL[kind](m, centre)
	end
	ground(m, centre.Y, groundAt)
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
	-- Terrain landmarks (the Arch, the Needle) may have filled over the ramp up from the
	-- caves: carve the last stretch of every exit ramp open again.
	for _, t in network.tunnels do
		if t.kind == "exit" then
			for k = 1, #t.points - 1 do
				local a, b = t.points[k], t.points[k + 1]
				local steps = math.ceil((b - a).Magnitude / (t.r * 0.5))
				for j = 0, steps do
					local q = a:Lerp(b, j / steps)
					for _, e in network.exits do
						if Vector3.new(q.X - e.pos.X, 0, q.Z - e.pos.Z).Magnitude < 45 then
							WorldBake.terrain:FillBall(q, t.r, Enum.Material.Air)
							break
						end
					end
				end
			end
		end
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
