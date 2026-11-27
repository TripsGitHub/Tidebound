-- Animals that wander the island. Hit one and it runs, then turns and fights back.
-- Kill it for meat and leather.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AnimalDefs = require(Shared.Animals)
local Meshes = require(Shared.Meshes)
local Inventory = require(script.Parent.Inventory)
local Drops = require(script.Parent.Drops)
local Progression = require(script.Parent.Progression)
local Quests = require(script.Parent.Quests)

local Animals = {}

type State = {
	model: Model,
	def: any,
	home: Vector3,
	target: Vector3?,
	mode: string, -- "wander" | "idle" | "flee" | "angry"
	modeUntil: number,
	attacker: Player?,
	nextBite: number,
	phase: number,
	nearest: Player?,
	nearestDist: number,
}

local states: { [Model]: State } = {}
local rng = Random.new()

local function folder(): Folder
	return workspace:WaitForChild("Animals") :: Folder
end

local function groundAt(x: number, z: number): (Vector3?, Enum.Material?)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	params.IgnoreWater = false
	local hit = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -600, 0), params)
	if hit then
		return hit.Position, hit.Material
	end
	return nil, nil
end

local function part(model: Model, size: Vector3, cf: CFrame, color: Color3, name: string?): Part
	local p = Instance.new("Part")
	p.Name = name or "Part"
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

-- A chunky low-poly boar, facing -Z, standing on the origin.
local function buildBoar(): Model
	local m = Instance.new("Model")
	local fur = Color3.fromRGB(110, 78, 56)
	local dark = Color3.fromRGB(76, 52, 38)
	local body = part(m, Vector3.new(2.6, 2.2, 4.2), CFrame.new(0, 2.3, 0), fur, "Body")
	part(m, Vector3.new(2.2, 0.6, 3.6), CFrame.new(0, 3.45, 0.1), dark, "Mane")
	part(m, Vector3.new(2, 1.8, 1.6), CFrame.new(0, 2.5, -2.6), fur, "Head")
	part(m, Vector3.new(1.1, 0.8, 0.6), CFrame.new(0, 2.1, -3.6), Color3.fromRGB(196, 140, 130), "Snout")
	for _, x in { -0.55, 0.55 } do
		part(m, Vector3.new(0.15, 0.7, 0.15), CFrame.new(x, 2.1, -3.7) * CFrame.Angles(math.rad(-30), 0, 0), Color3.fromRGB(240, 232, 210), "Tusk")
		part(m, Vector3.new(0.5, 0.6, 0.2), CFrame.new(x * 1.3, 3.5, -2.4), dark, "Ear")
		part(m, Vector3.new(0.25, 0.25, 0.1), CFrame.new(x * 0.9, 2.9, -3.42), Color3.new(0, 0, 0), "Eye")
	end
	for _, pos in { Vector3.new(-0.8, 0.6, -1.4), Vector3.new(0.8, 0.6, -1.4), Vector3.new(-0.8, 0.6, 1.4), Vector3.new(0.8, 0.6, 1.4) } do
		part(m, Vector3.new(0.6, 1.3, 0.6), CFrame.new(pos), dark, "Leg")
	end
	part(m, Vector3.new(0.2, 0.2, 0.8), CFrame.new(0, 2.8, 2.4) * CFrame.Angles(math.rad(40), 0, 0), dark, "Tail")
	m.PrimaryPart = body
	body.PivotOffset = body.CFrame:Inverse() -- pivot at the feet
	for _, p in m:GetChildren() do
		(p :: BasePart).CanQuery = true
	end
	return m
end

-- The Blender boar faces -Z like the block one, so either works.
local function boar(): Model
	local model = Meshes.build("boar", { collide = false })
	if not model then
		return buildBoar()
	end
	for _, p in model:GetChildren() do
		(p :: BasePart).CanQuery = true
	end
	return model
end

-- Block models for the other animals, all facing -Z and standing on the origin.
local function legs(m: Model, color: Color3, spots: { Vector3 }, size: Vector3)
	for _, pos in spots do
		part(m, size, CFrame.new(pos), color, "Leg")
	end
end

local function crab(): Model
	local m = Instance.new("Model")
	local shell, claw = Color3.fromRGB(214, 84, 52), Color3.fromRGB(232, 120, 80)
	part(m, Vector3.new(2.6, 1, 2), CFrame.new(0, 1.1, 0), shell, "Body")
	for _, x in { -1, 1 } do
		part(m, Vector3.new(0.9, 0.7, 1.1), CFrame.new(x * 1.6, 1.2, -1.2) * CFrame.Angles(0, x * 0.4, 0), claw, "Claw")
		part(m, Vector3.new(0.2, 0.6, 0.2), CFrame.new(x * 0.4, 1.8, -0.8), shell, "Stalk")
		part(m, Vector3.new(0.3, 0.3, 0.3), CFrame.new(x * 0.4, 2.15, -0.8), Color3.new(0, 0, 0), "Eye")
		for k = -1, 1 do
			part(m, Vector3.new(1.2, 0.2, 0.2), CFrame.new(x * 1.6, 0.6, k * 0.6) * CFrame.Angles(0, 0, x * -0.6), shell, "Leg")
		end
	end
	return m
end

local function wolf(): Model
	local m = Instance.new("Model")
	local fur, dark = Color3.fromRGB(150, 154, 162), Color3.fromRGB(92, 96, 106)
	part(m, Vector3.new(1.8, 1.8, 4.2), CFrame.new(0, 2.6, 0), fur, "Body")
	part(m, Vector3.new(1.6, 1.5, 1.6), CFrame.new(0, 3.2, -2.6), fur, "Head")
	part(m, Vector3.new(0.9, 0.7, 1.2), CFrame.new(0, 2.9, -3.8), dark, "Snout")
	for _, x in { -0.5, 0.5 } do
		part(m, Vector3.new(0.4, 0.7, 0.3), CFrame.new(x, 4.2, -2.4), dark, "Ear")
		part(m, Vector3.new(0.25, 0.2, 0.1), CFrame.new(x * 0.8, 3.5, -3.42), Color3.fromRGB(255, 210, 80), "Eye")
	end
	part(m, Vector3.new(0.5, 0.5, 2), CFrame.new(0, 3.2, 2.8) * CFrame.Angles(math.rad(30), 0, 0), dark, "Tail")
	legs(m, dark, { Vector3.new(-0.6, 0.9, -1.4), Vector3.new(0.6, 0.9, -1.4), Vector3.new(-0.6, 0.9, 1.4), Vector3.new(0.6, 0.9, 1.4) }, Vector3.new(0.5, 1.8, 0.5))
	return m
end

local function bogSlime(): Model
	local m = Instance.new("Model")
	local body = part(m, Vector3.new(3.4, 2.6, 3.4), CFrame.new(0, 1.3, 0), Color3.fromRGB(120, 214, 84), "Body")
	body.Material = Enum.Material.Glass
	body.Transparency = 0.25
	part(m, Vector3.new(1.6, 1, 1.6), CFrame.new(0, 1.1, 0), Color3.fromRGB(70, 140, 50), "Core")
	for _, x in { -0.6, 0.6 } do
		part(m, Vector3.new(0.4, 0.5, 0.1), CFrame.new(x, 1.8, -1.72), Color3.new(0, 0, 0), "Eye")
	end
	return m
end

local function cinderBeetle(): Model
	local m = Instance.new("Model")
	local shell, glow = Color3.fromRGB(36, 32, 38), Color3.fromRGB(255, 110, 40)
	part(m, Vector3.new(3.4, 2, 4.6), CFrame.new(0, 1.8, 0.2), shell, "Body")
	local seam = part(m, Vector3.new(0.3, 0.3, 4.4), CFrame.new(0, 2.85, 0.2), glow, "Seam")
	seam.Material = Enum.Material.Neon
	part(m, Vector3.new(2, 1.2, 1.4), CFrame.new(0, 1.6, -2.6), shell, "Head")
	for _, x in { -1, 1 } do
		part(m, Vector3.new(0.3, 0.3, 1.4), CFrame.new(x * 0.6, 1.6, -3.8) * CFrame.Angles(0, x * -0.4, 0), glow, "Mandible").Material = Enum.Material.Neon
		for k = -1, 1 do
			part(m, Vector3.new(1.6, 0.3, 0.3), CFrame.new(x * 2.2, 0.7, k * 1.3) * CFrame.Angles(0, 0, x * -0.7), shell, "Leg")
		end
	end
	return m
end

local function caveCrawler(): Model
	local m = Instance.new("Model")
	local hide, eye = Color3.fromRGB(58, 52, 64), Color3.fromRGB(150, 230, 255)
	part(m, Vector3.new(2.6, 1.6, 3.2), CFrame.new(0, 2, 0.8), hide, "Body")
	part(m, Vector3.new(1.8, 1.3, 1.6), CFrame.new(0, 2, -1.4), hide, "Head")
	for i, x in { -0.5, 0, 0.5 } do
		local e = part(m, Vector3.new(0.3, 0.3, 0.1), CFrame.new(x, 2.3 + (if i == 2 then 0.3 else 0), -2.22), eye, "Eye")
		e.Material = Enum.Material.Neon
	end
	for _, x in { -1, 1 } do
		for k = 0, 3 do
			part(m, Vector3.new(2.4, 0.3, 0.3), CFrame.new(x * 2, 1.3, -1 + k * 0.9) * CFrame.Angles(0, (k - 1.5) * 0.25 * x, x * -0.8), hide, "Leg")
		end
	end
	return m
end

local builders = { Boar = boar, Crab = crab, Wolf = wolf, BogSlime = bogSlime, CinderBeetle = cinderBeetle, CaveCrawler = caveCrawler }

-- Cave animals can't look for the ground from the sky (that finds the island above
-- them), so they feel for the floor just under where they are.
local function floorNear(x: number, y: number, z: number): (Vector3?, Enum.Material?)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	params.IgnoreWater = false
	local hit = workspace:Raycast(Vector3.new(x, y + 5, z), Vector3.new(0, -14, 0), params)
	if hit then
		return hit.Position, hit.Material
	end
	return nil, nil
end

local function groundFor(s: State, x: number, z: number, y: number): (Vector3?, Enum.Material?)
	if s.def.cave then
		return floorNear(x, y, z)
	end
	return groundAt(x, z)
end

local function pickWanderTarget(s: State): Vector3?
	for _ = 1, 8 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(8, if s.def.cave then 20 else 40)
		local pos, mat = groundFor(s, s.home.X + math.cos(a) * r, s.home.Z + math.sin(a) * r, s.home.Y)
		if pos and mat ~= Enum.Material.Water and mat ~= Enum.Material.Rock then
			return pos
		end
	end
	return nil
end

local function spawnAnimal(kind: string, home: Vector3)
	local def = AnimalDefs[kind]
	local model = builders[kind]()
	model.Name = kind
	model:SetAttribute("AnimalType", kind)
	model:SetAttribute("HP", def.hp)
	model:SetAttribute("MaxHP", def.hp)
	model:PivotTo(CFrame.new(home))
	model.Parent = folder()
	states[model] = {
		model = model,
		def = def,
		home = home,
		target = nil,
		mode = "idle",
		modeUntil = os.clock() + rng:NextNumber(1, 4),
		attacker = nil,
		nextBite = 0,
		phase = rng:NextNumber(0, 6),
		nearest = nil,
		nearestDist = math.huge,
	}
end

function Animals.spawnHerd(kind: string, center: Vector3, count: number)
	local cave = AnimalDefs[kind].cave
	for _ = 1, count do
		local x, z = center.X + rng:NextNumber(-20, 20), center.Z + rng:NextNumber(-20, 20)
		local pos = if cave then floorNear(x, center.Y, z) else groundAt(x, z)
		if pos then
			spawnAnimal(kind, pos)
		end
	end
end

-- Called when a player hits an animal.
function Animals.damage(model: Model, amount: number, attacker: Player)
	local s = states[model]
	if not s then
		return
	end
	local hp = (model:GetAttribute("HP") or 0) - amount
	model:SetAttribute("HP", hp)
	if hp <= 0 then
		states[model] = nil
		local pos = model:GetPivot().Position + Vector3.new(0, 2, 0)
		for _, drop in s.def.drops do
			Drops.spawn(drop.item, drop.amount, pos)
		end
		Progression.addXp(attacker, s.def.xp)
		Quests.record(attacker, "hunt", model:GetAttribute("AnimalType"), 1)
		model:Destroy()
		local kind, home = model.Name, s.home
		task.delay(s.def.respawn, function()
			spawnAnimal(kind, home)
		end)
		return
	end
	-- Run first, then come back angry.
	s.attacker = attacker
	if s.mode ~= "angry" then
		s.mode = "flee"
		s.modeUntil = os.clock() + 2
	end
end

local function step(s: State, dt: number)
	local now = os.clock()
	local model = s.model
	local pivot = model:GetPivot()
	local pos = pivot.Position
	local speed = s.def.walkSpeed
	local goal: Vector3? = nil

	local attackerRoot = s.attacker and s.attacker.Character and s.attacker.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local attackerHum = s.attacker and s.attacker.Character and s.attacker.Character:FindFirstChildOfClass("Humanoid")
	if (s.mode == "flee" or s.mode == "angry") and (not attackerRoot or not attackerHum or attackerHum.Health <= 0) then
		s.mode = "idle"
		s.attacker = nil
		s.modeUntil = now + 2
	end

	if s.mode == "flee" then
		speed = s.def.runSpeed
		if attackerRoot then
			local away = (pos - attackerRoot.Position) * Vector3.new(1, 0, 1)
			goal = pos + (if away.Magnitude > 0 then away.Unit else Vector3.xAxis) * 10
		end
		if now > s.modeUntil then
			s.mode = "angry"
			s.modeUntil = now + 12
		end
	elseif s.mode == "angry" and attackerRoot and attackerHum then
		speed = s.def.runSpeed * 0.85
		local toward = attackerRoot.Position - pos
		local flat = Vector3.new(toward.X, 0, toward.Z)
		if flat.Magnitude < 4.5 then
			goal = nil
			if now >= s.nextBite then
				s.nextBite = now + s.def.attackCooldown
				local defense = Inventory.defense(s.attacker :: Player)
				attackerHum:TakeDamage(s.def.damage * (1 - defense))
			end
		else
			goal = attackerRoot.Position
		end
		if now > s.modeUntil or flat.Magnitude > 80 then
			s.mode = "idle"
			s.attacker = nil
			s.modeUntil = now + 3
		end
	elseif (s.mode == "idle" or s.mode == "wander") and s.def.aggro and s.nearest and s.nearestDist < s.def.aggro then
		-- Hostile animals come for whoever gets close.
		s.attacker = s.nearest
		s.mode = "angry"
		s.modeUntil = now + 12
	elseif s.mode == "idle" then
		if now > s.modeUntil then
			s.target = pickWanderTarget(s)
			s.mode = "wander"
			s.modeUntil = now + 10
		end
	elseif s.mode == "wander" then
		goal = s.target
		if not goal or (Vector3.new(goal.X, 0, goal.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude < 2 or now > s.modeUntil then
			s.mode = "idle"
			s.modeUntil = now + rng:NextNumber(2, 6)
			goal = nil
		end
	end

	if goal then
		local flat = Vector3.new(goal.X - pos.X, 0, goal.Z - pos.Z)
		if flat.Magnitude > 0.1 then
			local move = flat.Unit * math.min(flat.Magnitude, speed * dt)
			local nextPos = pos + move
			local ground, mat = groundFor(s, nextPos.X, nextPos.Z, pos.Y)
			if ground and mat ~= Enum.Material.Water then
				s.phase += dt * speed
				local bob = math.abs(math.sin(s.phase * 1.2)) * 0.15
				local look = CFrame.lookAt(ground, ground + flat.Unit)
				model:PivotTo(look + Vector3.new(0, bob, 0))
			else
				s.target = nil
			end
		end
	end
end

function Animals.start()
	local accum = 0
	RunService.Heartbeat:Connect(function(dt)
		accum += dt
		if accum < 1 / 15 then
			return
		end
		local step_dt = accum
		accum = 0
		-- Only animate animals someone is near; far ones just stand still.
		local roots = {}
		for _, p in Players:GetPlayers() do
			local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
			local h = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
			if r and h and h.Health > 0 then
				table.insert(roots, { player = p, pos = (r :: BasePart).Position })
			end
		end
		for _, s in states do
			local pos = s.model:GetPivot().Position
			local near = false
			s.nearest, s.nearestDist = nil, math.huge
			for _, r in roots do
				local d = (r.pos - pos).Magnitude
				if d < 250 then
					near = true
				end
				if d < s.nearestDist then
					s.nearest, s.nearestDist = r.player, d
				end
			end
			if near then
				step(s, step_dt)
			end
		end
	end)
end

return Animals
