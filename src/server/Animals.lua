-- Animals that wander the island. Hit one and it runs, then turns and fights back.
-- Kill it for meat and leather.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AnimalDefs = require(Shared.Animals)
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

local builders = { Boar = buildBoar }

local function pickWanderTarget(s: State): Vector3?
	for _ = 1, 8 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(8, 40)
		local pos, mat = groundAt(s.home.X + math.cos(a) * r, s.home.Z + math.sin(a) * r)
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
	}
end

function Animals.spawnHerd(kind: string, center: Vector3, count: number)
	for _ = 1, count do
		local pos = groundAt(center.X + rng:NextNumber(-20, 20), center.Z + rng:NextNumber(-20, 20))
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
			local ground, mat = groundAt(nextPos.X, nextPos.Z)
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
			if r then
				table.insert(roots, (r :: BasePart).Position)
			end
		end
		for _, s in states do
			local pos = s.model:GetPivot().Position
			local near = false
			for _, r in roots do
				if (r - pos).Magnitude < 250 then
					near = true
					break
				end
			end
			if near then
				step(s, step_dt)
			end
		end
	end)
end

return Animals
