-- Boss fights in the lairs below the Maw, and the keyed gates in front of them.
--
-- Each boss has its own attacks, and every one is shown before it lands: a dark red
-- circle spreads on the floor where it will hit, so you can get out of the way.
--   Crawler Queen   pounces on you, and calls Cave Crawlers to help
--   Crystal Warden  crystal spikes burst up under you; a shockwave ring you jump over
--   Magma Golem     lobs fireballs that leave lava; stamps the ground round itself
-- Under half health they get angrier: everything comes faster.
--
-- Gates: a heavy iron gate shuts each lair. Hold E with a Maw Key to unlock it; the
-- key is used up and the gate stays open a minute for your whole group.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local AnimalDefs = require(Shared.Animals)
local Inventory = require(script.Parent.Inventory)

local Bosses = {}
local rng = Random.new()

local WARN = Color3.fromRGB(150, 30, 24)
local function folder(): Folder
	local f = workspace:FindFirstChild("BossFX")
	if not f then
		f = Instance.new("Folder")
		f.Name = "BossFX"
		f.Parent = workspace
	end
	return f :: Folder
end

local function floorAt(pos: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	local hit = workspace:Raycast(pos + Vector3.new(0, 6, 0), Vector3.new(0, -30, 0), params)
	return if hit then hit.Position else pos
end

-- Players standing inside `radius` of `centre` (flat distance, within 10 studs up/down).
local function playersIn(centre: Vector3, radius: number): { { player: Player, hum: Humanoid, root: BasePart } }
	local out = {}
	for _, p in Players:GetPlayers() do
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
		if root and hum and hum.Health > 0 then
			local d = root.Position - centre
			if Vector3.new(d.X, 0, d.Z).Magnitude <= radius and math.abs(d.Y) < 10 then
				table.insert(out, { player = p, hum = hum, root = root })
			end
		end
	end
	return out
end

local function hurt(target, amount: number)
	local defense = Inventory.defense(target.player, "mob")
	target.hum:TakeDamage(amount * (1 - defense))
	Remotes.HitFeedback:FireAllClients(target.player.Character)
end

-- A warning circle that spreads over `time` seconds, then calls `strike`.
local function telegraph(at: Vector3, radius: number, time: number, strike: () -> ())
	local disc = Instance.new("Part")
	disc.Name = "Warning"
	disc.Shape = Enum.PartType.Cylinder
	disc.Anchored, disc.CanCollide, disc.CanQuery, disc.CanTouch = true, false, false, false
	disc.Material = Enum.Material.Neon
	disc.Color = WARN
	disc.Transparency = 0.55
	disc.Size = Vector3.new(0.2, 1, 1)
	disc.CFrame = CFrame.new(at + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	disc.Parent = folder()
	local rim = disc:Clone()
	rim.Transparency = 0.8
	rim.Size = Vector3.new(0.15, radius * 2, radius * 2)
	rim.Parent = folder()
	TweenService:Create(disc, TweenInfo.new(time, Enum.EasingStyle.Linear), { Size = Vector3.new(0.2, radius * 2, radius * 2) }):Play()
	task.delay(time, function()
		disc:Destroy()
		rim:Destroy()
		strike()
	end)
end

local function burst(at: Vector3, color: Color3, size: number)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Anchored, p.CanCollide, p.CanQuery = true, false, false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = 0.3
	p.Size = Vector3.one * 2
	p.CFrame = CFrame.new(at)
	p.Parent = folder()
	TweenService:Create(p, TweenInfo.new(0.4), { Size = Vector3.one * size, Transparency = 1 }):Play()
	Debris:AddItem(p, 0.5)
end

-- Attacks ---------------------------------------------------------------------------

local function pounce(s, target: BasePart)
	-- Never leaps out of its lair: the landing spot is kept inside it.
	local want = target.Position
	local off = (want - s.home) * Vector3.new(1, 0, 1)
	local roam = s.def.roam or 42
	if off.Magnitude > roam then
		want = s.home + off.Unit * roam + Vector3.new(0, want.Y - s.home.Y, 0)
	end
	local at = floorAt(want)
	s.busyUntil = os.clock() + 1.6
	s.attack = { kind = "lunge", t0 = os.clock() + 0.9, dur = 0.6 }
	telegraph(at, 10, 1.2, function()
		if s.model.Parent then
			local from = s.model:GetPivot()
			local dir = (at - from.Position) * Vector3.new(1, 0, 1)
			local feet = at + Vector3.new(0, s.foot or 0, 0)
			local look = CFrame.lookAt(feet, feet + (if dir.Magnitude > 0.01 then dir.Unit else from.LookVector * Vector3.new(1, 0, 1)))
			s.model:PivotTo(look)
		end
		burst(at, Color3.fromRGB(120, 90, 110), 22)
		for _, t in playersIn(at, 10) do
			hurt(t, 42)
		end
	end)
end

local function summon(s, spawnMinion)
	local alive = 0
	for _, m in s.minions do
		if m.Parent then
			alive += 1
		end
	end
	if alive >= 4 then
		return
	end
	s.minions = {}
	local pos = s.model:GetPivot().Position
	for _ = 1, 2 do
		local m = spawnMinion("CaveCrawler", pos + Vector3.new(rng:NextNumber(-12, 12), 3, rng:NextNumber(-12, 12)))
		if m then
			table.insert(s.minions, m)
		end
	end
end

local function spikes(s, targets)
	s.busyUntil = os.clock() + 1.3
	s.attack = { kind = "slam", t0 = os.clock(), dur = 1.2 }
	for _, t in targets do
		local at = floorAt(t.Position + Vector3.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3)))
		telegraph(at, 7, 1.1, function()
			for k = 1, 5 do
				local spike = Instance.new("Part")
				spike.Anchored, spike.CanCollide, spike.CanQuery = true, false, false
				spike.Material = Enum.Material.Neon
				spike.Color = Color3.fromRGB(190, 140, 255)
				spike.Size = Vector3.new(1.4, 0.5, 1.4)
				local base = at + Vector3.new(rng:NextNumber(-4, 4), 0, rng:NextNumber(-4, 4))
				spike.CFrame = CFrame.new(base) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), k, rng:NextNumber(-0.3, 0.3))
				spike.Parent = folder()
				TweenService:Create(spike, TweenInfo.new(0.15), { Size = Vector3.new(1.4, rng:NextNumber(6, 10), 1.4) }):Play()
				Debris:AddItem(spike, 1.2)
			end
			for _, p in playersIn(at, 7) do
				hurt(p, 38)
			end
		end)
	end
end

-- An expanding ring along the floor: you have to jump as it passes.
local function shockwave(s, radius: number, damage: number, color: Color3)
	s.busyUntil = os.clock() + 2.2
	s.attack = { kind = "slam", t0 = os.clock(), dur = 0.75 }
	local centre = floorAt(s.model:GetPivot().Position)
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored, ring.CanCollide, ring.CanQuery = true, false, false
	ring.Material = Enum.Material.Neon
	ring.Color = color
	ring.Transparency = 0.4
	ring.Size = Vector3.new(1.2, 2, 2)
	ring.CFrame = CFrame.new(centre + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Parent = folder()
	local hit: { [Player]: boolean } = {}
	local t0 = os.clock()
	local dur = 1.6
	task.delay(0.6, function() -- a short wind-up before it rolls out
		t0 = os.clock()
		while os.clock() - t0 < dur do
			local r = (os.clock() - t0) / dur * radius
			ring.Size = Vector3.new(1.2, r * 2, r * 2)
			ring.Transparency = 0.4 + 0.5 * (r / radius)
			for _, t in playersIn(centre, r + 1.5) do
				local d = (t.root.Position - centre) * Vector3.new(1, 0, 1)
				local onGround = t.hum.FloorMaterial ~= Enum.Material.Air
				if not hit[t.player] and d.Magnitude > r - 3 and onGround then
					hit[t.player] = true
					hurt(t, damage)
				end
			end
			task.wait()
		end
		ring:Destroy()
	end)
end

local function fireball(s, target: BasePart)
	local from = s.model:GetPivot().Position + Vector3.new(0, 18, 0)
	local at = floorAt(target.Position)
	s.busyUntil = os.clock() + 0.9
	s.attack = { kind = "throw", t0 = os.clock(), dur = 0.9 }
	local ball = Instance.new("Part")
	ball.Shape = Enum.PartType.Ball
	ball.Anchored, ball.CanCollide, ball.CanQuery = true, false, false
	ball.Material = Enum.Material.Neon
	ball.Color = Color3.fromRGB(255, 110, 30)
	ball.Size = Vector3.one * 3.5
	ball.CFrame = CFrame.new(from)
	local fire = Instance.new("Fire")
	fire.Size, fire.Heat = 5, 6
	fire.Parent = ball
	ball.Parent = folder()
	local flight = 1.3
	telegraph(at, 8, flight, function()
		ball:Destroy()
		burst(at, Color3.fromRGB(255, 120, 40), 18)
		for _, t in playersIn(at, 8) do
			hurt(t, 44)
		end
		-- A lava puddle that burns for a few seconds.
		local pool = Instance.new("Part")
		pool.Shape = Enum.PartType.Cylinder
		pool.Anchored, pool.CanCollide, pool.CanQuery = true, false, false
		pool.Material = Enum.Material.Neon
		pool.Color = Color3.fromRGB(255, 90, 20)
		pool.Size = Vector3.new(0.3, 12, 12)
		pool.CFrame = CFrame.new(at + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		pool.Parent = folder()
		task.spawn(function()
			for _ = 1, 12 do
				task.wait(0.5)
				for _, t in playersIn(at, 6) do
					hurt(t, 5)
				end
			end
			pool:Destroy()
		end)
	end)
	task.spawn(function()
		local t0 = os.clock()
		while ball.Parent and os.clock() - t0 < flight do
			local k = (os.clock() - t0) / flight
			ball.CFrame = CFrame.new(from:Lerp(at, k) + Vector3.new(0, math.sin(k * math.pi) * 22, 0))
			task.wait()
		end
	end)
end

local function stomp(s)
	local at = floorAt(s.model:GetPivot().Position)
	s.busyUntil = os.clock() + 1.8
	s.attack = { kind = "slam", t0 = os.clock(), dur = 1.7 }
	telegraph(at, 22, 1.5, function()
		burst(at, Color3.fromRGB(255, 120, 40), 46)
		for _, t in playersIn(at, 22) do
			hurt(t, 52)
		end
	end)
end

-- Called from Animals' step for an angry boss. `target` is who it's after.
function Bosses.think(s, target: BasePart, spawnMinion: (string, Vector3) -> Model?)
	local now = os.clock()
	s.next = s.next or {}
	s.minions = s.minions or {}
	if now < (s.busyUntil or 0) then
		return true -- mid-attack: stand still
	end
	local hp, max = s.model:GetAttribute("HP") or 1, s.model:GetAttribute("MaxHP") or 1
	local rage = if hp / max < 0.5 then 0.65 else 1
	s.model:SetAttribute("Enraged", rage < 1)
	local function ready(name: string, every: number): boolean
		if now >= (s.next[name] or now + 2) then
			s.next[name] = now + every * rage
			return true
		end
		s.next[name] = s.next[name] or now + 2
		return false
	end
	local kind = s.model.Name
	local near = {}
	for _, p in Players:GetPlayers() do
		local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if r and ((r :: BasePart).Position - s.model:GetPivot().Position).Magnitude < 90 then
			table.insert(near, r)
		end
	end
	if kind == "CrawlerQueen" then
		if ready("summon", 18) then
			summon(s, spawnMinion)
			return true
		elseif ready("pounce", 7) then
			pounce(s, target)
			return true
		end
	elseif kind == "CrystalWarden" then
		if ready("wave", 14) then
			shockwave(s, 48, 34, Color3.fromRGB(190, 140, 255))
			return true
		elseif ready("spikes", 6) then
			spikes(s, near)
			return true
		end
	elseif kind == "MagmaGolem" then
		if ready("stomp", 15) then
			stomp(s)
			return true
		elseif ready("fireball", 4.5) then
			fireball(s, near[rng:NextInteger(1, math.max(1, #near))] or target)
			return true
		end
	end
	return false
end

-- Gates ------------------------------------------------------------------------------

-- An iron portcullis in a stone arch, plugging the hall at `b.pos`.
function Bosses.makeGate(b, bossName: string, onOpen: (() -> ())?)
	local gates = workspace:FindFirstChild("BossGates") or Instance.new("Folder")
	gates.Name = "BossGates"
	gates.Parent = workspace
	local m = Instance.new("Model")
	m.Name = "Gate_" .. bossName
	local look = CFrame.lookAt(b.pos, b.pos + b.dir)
	local size = b.r * 2 + 4
	local stone = Color3.fromRGB(70, 64, 62)
	local function part(props)
		local p = Instance.new("Part")
		p.Anchored = true
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		for k, v in props do
			(p :: any)[k] = v
		end
		p.Parent = m
		return p
	end
	-- A thick stone wall with the doorway cut through it.
	local wall = part({ Name = "Wall", Size = Vector3.new(size + 6, size + 6, 4), CFrame = look, Color = stone, Material = Enum.Material.Slate, Transparency = 1, CanCollide = false })
	for side = -1, 1, 2 do
		part({ Name = "Jamb", Size = Vector3.new(4, size, 5), CFrame = look * CFrame.new(side * (size / 2 - 1), 0, 0), Color = stone, Material = Enum.Material.Cobblestone })
	end
	part({ Name = "Lintel", Size = Vector3.new(size, 4, 5), CFrame = look * CFrame.new(0, size / 2 - 1, 0), Color = stone, Material = Enum.Material.Cobblestone })
	local bars = Instance.new("Model")
	bars.Name = "Bars"
	bars.Parent = m
	for x = -size / 2 + 3, size / 2 - 3, 2.4 do
		local bar = part({ Name = "Bar", Size = Vector3.new(0.7, size - 3, 0.7), CFrame = look * CFrame.new(x, -1, 0), Color = Color3.fromRGB(56, 52, 50), Material = Enum.Material.Metal, Reflectance = 0.1 })
		bar.Parent = bars
	end
	for y = -size / 2 + 3, size / 2 - 4, 4 do
		local rail = part({ Name = "Rail", Size = Vector3.new(size - 4, 0.6, 0.9), CFrame = look * CFrame.new(0, y, 0), Color = Color3.fromRGB(56, 52, 50), Material = Enum.Material.Metal })
		rail.Parent = bars
	end
	-- A block across the doorway that actually stops you (the bars have gaps).
	local block = part({ Name = "Block", Size = Vector3.new(size - 4, size - 3, 1.5), CFrame = look * CFrame.new(0, -1, 0), Transparency = 1 })
	block.Parent = bars
	-- Outside (the way in, behind the gate's facing): a lock that takes a Maw Key.
	-- Inside (the lair side): a lever that opens it free, so nobody gets shut in.
	local lock = part({ Name = "Lock", Size = Vector3.new(1.6, 2, 1.2), CFrame = look * CFrame.new(0, -1, 1.2), Color = Color3.fromRGB(150, 50, 40), Material = Enum.Material.Metal })
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Unlock"
	prompt.ObjectText = "Lair Gate (Maw Key)"
	prompt.HoldDuration = 1.2
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.OneGlobally
	prompt.Parent = lock
	local lever = part({ Name = "Lever", Size = Vector3.new(0.6, 3, 0.6), CFrame = look * CFrame.new(size / 2 - 3, -size / 2 + 3, -1.4) * CFrame.Angles(0.4, 0, 0), Color = Color3.fromRGB(120, 90, 60), Material = Enum.Material.Wood })
	local inside = Instance.new("ProximityPrompt")
	inside.ActionText = "Open"
	inside.ObjectText = "Lair Gate"
	inside.HoldDuration = 0.6
	inside.MaxActivationDistance = 10
	inside.RequiresLineOfSight = false
	inside.Exclusivity = Enum.ProximityPromptExclusivity.OneGlobally
	inside.Parent = lever
	local function onLairSide(player: Player): boolean
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		return root ~= nil and (root.Position - look.Position):Dot(look.LookVector) > 0
	end
	m.WorldPivot = look
	m.Parent = gates
	local barsHome = {}
	for _, p in bars:GetChildren() do
		barsHome[p] = p.CFrame
	end
	local open = false
	local function openGate()
		open = true
		prompt.Enabled = false
		inside.Enabled = false
		if onOpen then
			onOpen()
		end
		for p, home in barsHome do
			p.CanCollide = false
			TweenService:Create(p, TweenInfo.new(2, Enum.EasingStyle.Quad), { CFrame = home - Vector3.new(0, size - 2, 0) }):Play()
		end
		task.delay(60, function()
			for p, home in barsHome do
				TweenService:Create(p, TweenInfo.new(2, Enum.EasingStyle.Quad), { CFrame = home }):Play()
			end
			task.wait(2)
			for p in barsHome do
				p.CanCollide = true
			end
			open = false
			prompt.Enabled = true
			inside.Enabled = true
		end)
	end
	prompt.Triggered:Connect(function(player)
		if open then
			return
		end
		if onLairSide(player) then
			openGate()
			return
		end
		if not Inventory.take(player, "maw_key", 1) then
			Remotes.Notify:FireClient(player, "You need a Maw Key", "warn")
			return
		end
		openGate()
	end)
	inside.Triggered:Connect(function(player)
		if open then
			return
		end
		if not onLairSide(player) then
			Remotes.Notify:FireClient(player, "The lever is on the other side of the bars", "warn")
			return
		end
		openGate()
	end)
	return wall
end

return Bosses
