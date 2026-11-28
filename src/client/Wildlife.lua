-- Little bits of life around you, client-side only so they cost the server nothing:
-- seagulls wheeling over the coast, fish leaping out of the sea, and butterflies
-- drifting over grass in the daytime. They only exist near the camera.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local Wildlife = {}

local rng = Random.new()
local camera = workspace.CurrentCamera
local folder: Folder

local function part(parent: Instance, size: Vector3, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.IgnoreWater = false

local function groundBelow(x: number, z: number): (Vector3?, Enum.Material?)
	params.FilterDescendantsInstances = { workspace.Terrain }
	local hit = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -600, 0), params)
	if hit then
		return hit.Position, hit.Material
	end
	return nil, nil
end

-- Seagulls ---------------------------------------------------------------------------
type Gull = { body: Part, wl: Part, wr: Part, centre: Vector3, radius: number, height: number, speed: number, phase: number }
local gulls: { Gull } = {}

-- A gull: a rounded white body and head, orange beak, grey back, and two-part
-- wings (inner and outer, swept back, black tips) that bend as they flap.
local GULL_WHITE, GULL_GREY, GULL_TIP = Color3.fromRGB(246, 246, 242), Color3.fromRGB(176, 182, 190), Color3.fromRGB(46, 46, 50)
local function makeGull(centre: Vector3): Gull
	local m = Instance.new("Model")
	m.Name = "Gull"
	m.Parent = folder
	local body = part(m, Vector3.new(0.7, 0.62, 1.7), GULL_WHITE)
	body.Shape = Enum.PartType.Ball
	local head = part(m, Vector3.new(0.5, 0.5, 0.55), GULL_WHITE)
	head.Shape = Enum.PartType.Ball
	local beak = part(m, Vector3.new(0.12, 0.12, 0.42), Color3.fromRGB(246, 176, 50))
	local back = part(m, Vector3.new(0.5, 0.12, 1.1), GULL_GREY)
	local tail = part(m, Vector3.new(0.5, 0.08, 0.6), GULL_GREY)
	local parts: { [string]: BasePart } = { head = head, beak = beak, back = back, tail = tail }
	for _, side in { "L", "R" } do
		parts["in" .. side] = part(m, Vector3.new(1.3, 0.1, 0.75), GULL_GREY)
		parts["out" .. side] = part(m, Vector3.new(1.3, 0.09, 0.55), GULL_GREY)
		parts["tip" .. side] = part(m, Vector3.new(0.5, 0.1, 0.42), GULL_TIP)
	end
	local g = { body = body, wl = parts.inL, wr = parts.inR, centre = centre, radius = rng:NextNumber(25, 55), height = rng:NextNumber(26, 46), speed = rng:NextNumber(0.25, 0.4) * (if rng:NextNumber() < 0.5 then -1 else 1), phase = rng:NextNumber(0, math.pi * 2) }
	;(g :: any).parts = parts
	return g
end

local function stepGull(g: Gull, t: number)
	local a = g.phase + t * g.speed
	local pos = g.centre + Vector3.new(math.cos(a) * g.radius, g.height + math.sin(t * 0.7 + g.phase) * 3, math.sin(a) * g.radius)
	local dir = Vector3.new(-math.sin(a), 0, math.cos(a)) * math.sign(g.speed)
	local bank = CFrame.Angles(0, 0, -0.35 * math.sign(g.speed))
	local cf = CFrame.lookAt(pos, pos + dir) * bank
	-- Mostly gliding, with a few flaps now and then; the outer wing lags the inner.
	local flapping = math.sin(t * 0.5 + g.phase) > 0.3
	local flap = if flapping then math.sin(t * 9 + g.phase) * 0.55 else 0.08
	local lag = if flapping then math.sin(t * 9 + g.phase - 0.7) * 0.45 else -0.06
	local p = (g :: any).parts
	g.body.CFrame = cf
	p.head.CFrame = cf * CFrame.new(0, 0.28, -0.85)
	p.beak.CFrame = cf * CFrame.new(0, 0.24, -1.25) * CFrame.Angles(math.rad(-8), 0, 0)
	p.back.CFrame = cf * CFrame.new(0, 0.26, 0.1)
	p.tail.CFrame = cf * CFrame.new(0, 0.1, 1.05) * CFrame.Angles(math.rad(8), 0, 0)
	for _, side in { -1, 1 } do
		local k = if side < 0 then "L" else "R"
		local shoulder = cf * CFrame.new(side * 0.25, 0.18, -0.1) * CFrame.Angles(0, side * math.rad(-10), side * -flap)
		local inner = shoulder * CFrame.new(side * 0.65, 0, 0)
		p["in" .. k].CFrame = inner
		local elbow = shoulder * CFrame.new(side * 1.3, 0, 0.05) * CFrame.Angles(0, side * math.rad(-22), side * -lag)
		p["out" .. k].CFrame = elbow * CFrame.new(side * 0.62, 0, 0.1)
		p["tip" .. k].CFrame = elbow * CFrame.new(side * 1.45, 0, 0.2)
	end
end

-- Leaping fish ----------------------------------------------------------------------
local function leap(at: Vector3)
	local fish = part(folder, Vector3.new(1.4, 0.5, 0.35), Color3.fromRGB(120, 170, 200))
	fish.Shape = Enum.PartType.Ball
	local dir = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1))
	dir = if dir.Magnitude > 0.1 then dir.Unit else Vector3.xAxis
	local dur = rng:NextNumber(0.7, 1.0)
	local len = rng:NextNumber(4, 7)
	local h = rng:NextNumber(2, 3.5)
	local t0 = os.clock()
	local splash = Instance.new("Attachment")
	splash.Parent = workspace.Terrain
	splash.WorldPosition = at
	local drops = Instance.new("ParticleEmitter")
	drops.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	drops.Color = ColorSequence.new(Color3.fromRGB(220, 240, 255))
	drops.Size = NumberSequence.new(0.3, 0)
	drops.Lifetime = NumberRange.new(0.4, 0.6)
	drops.Speed = NumberRange.new(4, 7)
	drops.SpreadAngle = Vector2.new(35, 35)
	drops.Acceleration = Vector3.new(0, -20, 0)
	drops.EmissionDirection = Enum.NormalId.Top
	drops.Rate = 0
	drops.Parent = splash
	drops:Emit(8)
	task.spawn(function()
		while os.clock() - t0 < dur do
			local k = (os.clock() - t0) / dur
			local p = at + dir * len * k + Vector3.new(0, math.sin(k * math.pi) * h, 0)
			local tangent = dir * len + Vector3.new(0, math.cos(k * math.pi) * h * math.pi, 0)
			fish.CFrame = CFrame.lookAt(p, p + tangent) * CFrame.Angles(0, math.pi / 2, 0)
			task.wait()
		end
		splash.WorldPosition = at + dir * len
		drops:Emit(10)
		fish:Destroy()
		task.wait(1)
		splash:Destroy()
	end)
end

-- Butterflies -----------------------------------------------------------------------
type Fly = { a: Part, b: Part, home: Vector3, phase: number }
local flies: { Fly } = {}
local FLY_COLOURS = { Color3.fromRGB(255, 200, 60), Color3.fromRGB(250, 130, 60), Color3.fromRGB(140, 190, 255), Color3.fromRGB(255, 255, 255) }

local function makeFly(home: Vector3): Fly
	local c = FLY_COLOURS[rng:NextInteger(1, #FLY_COLOURS)]
	local a = part(folder, Vector3.new(0.5, 0.05, 0.45), c, Enum.Material.Neon)
	local b = part(folder, Vector3.new(0.5, 0.05, 0.45), c, Enum.Material.Neon)
	return { a = a, b = b, home = home, phase = rng:NextNumber(0, 20) }
end

local function stepFly(f: Fly, t: number)
	local tt = t * 0.6 + f.phase
	local pos = f.home + Vector3.new(math.sin(tt * 1.3) * 4 + math.sin(tt * 0.4) * 3, 1.6 + math.sin(tt * 2.1) * 0.8, math.cos(tt * 1.1) * 4)
	local flap = math.sin(t * 18 + f.phase) * 0.9
	local cf = CFrame.lookAt(pos, pos + Vector3.new(math.cos(tt * 1.3), 0, -math.sin(tt * 1.1)))
	f.a.CFrame = cf * CFrame.Angles(0, 0, flap) * CFrame.new(-0.27, 0, 0)
	f.b.CFrame = cf * CFrame.Angles(0, 0, -flap) * CFrame.new(0.27, 0, 0)
end

function Wildlife.start()
	folder = Instance.new("Folder")
	folder.Name = "Wildlife"
	folder.Parent = camera
	local nextFish, nextCheck = os.clock() + 3, 0
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		local focus = camera.Focus.Position
		local hour = Lighting.ClockTime
		local day = hour > 6 and hour < 19
		local outside = focus.Y > -4
		-- Every couple of seconds: refresh which creatures should be near you.
		if t > nextCheck then
			nextCheck = t + 2
			-- Gulls circle the nearest coast: keep a small flock over you outside.
			for i = #gulls, 1, -1 do
				local g = gulls[i]
				if not outside or (Vector3.new(g.centre.X, 0, g.centre.Z) - Vector3.new(focus.X, 0, focus.Z)).Magnitude > 160 then
					g.body.Parent:Destroy()
					table.remove(gulls, i)
				end
			end
			if outside and day and #gulls < 4 then
				local c = focus + Vector3.new(rng:NextNumber(-60, 60), 0, rng:NextNumber(-60, 60))
				table.insert(gulls, makeGull(Vector3.new(c.X, 0, c.Z)))
			end
			-- Butterflies over grass in the daytime.
			for i = #flies, 1, -1 do
				local f = flies[i]
				if not day or not outside or (f.home - focus).Magnitude > 70 then
					f.a:Destroy()
					f.b:Destroy()
					table.remove(flies, i)
				end
			end
			if day and outside and #flies < 6 then
				local x, z = focus.X + rng:NextNumber(-30, 30), focus.Z + rng:NextNumber(-30, 30)
				local pos, mat = groundBelow(x, z)
				if pos and (mat == Enum.Material.Grass or mat == Enum.Material.LeafyGrass) then
					table.insert(flies, makeFly(pos))
				end
			end
		end
		if t > nextFish and outside then
			nextFish = t + rng:NextNumber(2.5, 6)
			local x, z = focus.X + rng:NextNumber(-50, 50), focus.Z + rng:NextNumber(-50, 50)
			local pos, mat = groundBelow(x, z)
			if pos and mat == Enum.Material.Water then
				leap(Vector3.new(x, pos.Y - 0.3, z))
			end
		end
		for _, g in gulls do
			stepGull(g, t)
		end
		for _, f in flies do
			stepFly(f, t)
		end
	end)
	-- A fresh character (after dying) shouldn't keep old flocks hanging about.
	Players.LocalPlayer.CharacterAdded:Connect(function()
		nextCheck = 0
	end)
end

return Wildlife
