-- World events: the only places the two best ores come from.
--   Eruption       every 10-15 minutes Ember Isle rumbles, smokes, and Obsidian Spires
--                  burst out of its slopes. They crumble after 5 minutes if nobody mines them.
--   Meteor shower  most nights a few meteors streak down onto the outer islands and
--                  leave Moonstone Clusters, which fade at dawn.
-- Event nodes are tagged Temporary, so Harvest destroys them instead of regrowing them.
-- Tune the timings in Config.Events. To try one in Studio, run in the server command bar:
--   require(game.ServerScriptService.Server.Events).erupt()   (or .meteorShower())
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local WorldBuilder = require(script.Parent.WorldBuilder)
local Drops = require(script.Parent.Drops)

local Events = {}
local rng = Random.new()
local erupting = false

local function island(name: string)
	for _, isl in WorldBuilder.Islands do
		if isl.name == name then
			return isl
		end
	end
	return nil
end

local function announce(text: string, kind: string)
	Remotes.Notify:FireAllClients(text, "good")
	Remotes.WorldEvent:FireAllClients(text, kind)
end

local function groundAt(x: number, z: number): RaycastResult?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	return workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -600, 0), params)
end

-- Removes an event node later if it's still there and nobody broke it.
local function expire(model: Model, after: number)
	task.delay(after, function()
		if model.Parent and not model:GetAttribute("Depleted") then
			model:Destroy()
		end
	end)
end

local function tag(model: Model?)
	if model then
		model:SetAttribute("Temporary", true)
	end
	return model
end

-- Hurts and shoves everyone near a blast.
local function blast(at: Vector3, radius: number, damage: number, push: number)
	for _, plr in Players:GetPlayers() do
		local character = plr.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		if hrp and hum and hum.Health > 0 then
			local d = hrp.Position - at
			if d.Magnitude < radius then
				local t = 1 - d.Magnitude / radius
				hum:TakeDamage(damage * t)
				local dir = (d * Vector3.new(1, 0, 1)).Unit
				if dir ~= dir then
					dir = Vector3.new(1, 0, 0)
				end
				hrp.AssemblyLinearVelocity += dir * push * t + Vector3.new(0, push * 0.6 * t, 0)
			end
		end
	end
end

-- Eruption -------------------------------------------------------------------------

local function plume(at: Vector3, seconds: number)
	local p = Instance.new("Part")
	p.Name = "EruptionPlume"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Transparency = 1
	p.Size = Vector3.new(10, 2, 10)
	p.CFrame = CFrame.new(at)
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(70, 60, 60), Color3.fromRGB(30, 28, 30))
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 8), NumberSequenceKeypoint.new(1, 30) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	smoke.Lifetime = NumberRange.new(6, 9)
	smoke.Speed = NumberRange.new(18, 26)
	smoke.SpreadAngle = Vector2.new(18, 18)
	smoke.Rate = 14
	smoke.Parent = p
	local embers = Instance.new("ParticleEmitter")
	embers.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	embers.Color = ColorSequence.new(Color3.fromRGB(255, 160, 60), Color3.fromRGB(255, 60, 20))
	embers.LightEmission = 1
	embers.Size = NumberSequence.new(1.2, 0.2)
	embers.Lifetime = NumberRange.new(2, 3.5)
	embers.Speed = NumberRange.new(30, 50)
	embers.SpreadAngle = Vector2.new(35, 35)
	embers.Acceleration = Vector3.new(0, -30, 0)
	embers.Rate = 40
	embers.Parent = p
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 120, 50)
	light.Range = 60
	light.Brightness = 3
	light.Parent = p
	p.Parent = workspace
	task.delay(seconds, function()
		smoke.Enabled = false
		embers.Enabled = false
		light.Enabled = false
		task.wait(10)
		p:Destroy()
	end)
end

function Events.erupt()
	local ember = island("Ember Isle")
	if not ember or erupting then
		return
	end
	erupting = true
	local cfg = Config.Events
	announce("The ground shakes... Ember Isle is about to erupt!", "eruption")
	local top = groundAt(ember.x, ember.z)
	local crater = (if top then top.Position else Vector3.new(ember.x, 40, ember.z)) + Vector3.new(0, 2, 0)
	plume(crater, cfg.EruptionWarning + 40)
	-- Warning rumbles that build up, then the sky goes red as it blows.
	Remotes.WorldFx:FireAllClients("quake", crater, cfg.EruptionWarning, 0.35)
	task.wait(cfg.EruptionWarning)
	Remotes.WorldFx:FireAllClients("quake", crater, 6, 1.6)
	Remotes.WorldFx:FireAllClients("sky", Color3.fromRGB(255, 150, 110), 45, "eruption")
	Remotes.WorldFx:FireAllClients("impact", crater, 40, "lava")
	-- Lava bombs: arcs of molten rock rain over the island for half a minute. Where
	-- they land they hurt, and sometimes leave a shard of obsidian.
	task.spawn(function()
		local radius = (ember.r or 120) * 0.85
		for _ = 1, 60 do
			local a = rng:NextNumber(0, math.pi * 2)
			local r = rng:NextNumber(20, radius)
			local ground = groundAt(ember.x + math.cos(a) * r, ember.z + math.sin(a) * r)
			if ground and ground.Material ~= Enum.Material.Water then
				local flight = rng:NextNumber(2.2, 3.6)
				Remotes.WorldFx:FireAllClients("bomb", crater + Vector3.new(0, 10, 0), ground.Position, flight)
				task.delay(flight, function()
					blast(ground.Position, 10, 30, 40)
					Remotes.WorldFx:FireAllClients("impact", ground.Position, 8, "lava")
					if rng:NextNumber() < 0.25 then
						Drops.spawn("obsidian", 1, ground.Position + Vector3.new(0, 2, 0), Vector3.new(0, 1, 0))
					end
				end)
			end
			task.wait(rng:NextNumber(0.25, 0.6))
		end
	end)
	local count = rng:NextInteger(cfg.EruptionSpires[1], cfg.EruptionSpires[2])
	local made = 0
	for _ = 1, count do
		local model = tag(WorldBuilder.spawnNodeOn(ember, "ObsidianSpire", "slopes") or WorldBuilder.spawnNodeOn(ember, "ObsidianSpire"))
		if model then
			made += 1
			expire(model, cfg.EruptionLasts)
			-- Burst up out of the ground.
			local home = model:GetPivot()
			model:PivotTo(home * CFrame.new(0, -6, 0))
			local v = Instance.new("CFrameValue")
			v.Value = model:GetPivot()
			v.Changed:Connect(function(cf)
				if model.Parent then
					model:PivotTo(cf)
				end
			end)
			Remotes.WorldFx:FireAllClients("impact", home.Position, 14, "lava")
			local tween = TweenService:Create(v, TweenInfo.new(0.8, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Value = home })
			tween:Play()
			tween.Completed:Once(function()
				v:Destroy()
			end)
		end
	end
	if made > 0 then
		announce("Ember Isle erupted! " .. made .. " Obsidian Spires burst out of its slopes", "eruption")
	end
	erupting = false
end

-- Meteor shower ----------------------------------------------------------------------

-- A meteor: the client draws the fireball streaking in (it's big, slow and loud);
-- the server times the landing, blasts a crater, and puts down a giant Moonstone
-- Cluster in the middle of it that takes a lot of mining and gives a lot back.
local METEOR_FALL = 4.5
local function meteor(model: Model)
	local target = model:GetPivot().Position
	local parent = model.Parent
	model.Parent = nil -- hidden until the meteor lands
	local start = target + Vector3.new(rng:NextNumber(-260, 260), 520, rng:NextNumber(-260, 260))
	Remotes.WorldFx:FireAllClients("meteor", start, target, METEOR_FALL)
	task.wait(METEOR_FALL)
	-- Crater: scoop the ground out and leave a scorched rim.
	local terrain = workspace.Terrain
	pcall(function()
		terrain:FillBall(target + Vector3.new(0, 3, 0), 11, Enum.Material.Air)
		terrain:FillCylinder(CFrame.new(target + Vector3.new(0, -5, 0)), 3, 12, Enum.Material.Basalt)
		for k = 0, 9 do
			local a = k / 10 * math.pi * 2
			terrain:FillBall(target + Vector3.new(math.cos(a) * 12, -1, math.sin(a) * 12), 3.4, Enum.Material.CrackedLava)
		end
	end)
	blast(target, 26, 45, 90)
	Remotes.WorldFx:FireAllClients("impact", target, 60, "moon")
	if parent and parent.Parent then
		-- Massive: sits in the crater floor, needs many more hits, drops four times as much.
		model:PivotTo(model:GetPivot() * CFrame.new(0, -3.5, 0))
		pcall(function()
			model:ScaleTo(2.4)
		end)
		local def = model:GetAttribute("MaxHP") or 100
		model:SetAttribute("MaxHP", def * 4)
		model:SetAttribute("HP", def * 4)
		model:SetAttribute("LootMult", 4)
		model.Parent = parent
	end
end

local function isNight(): boolean
	local t = Lighting.ClockTime
	return t >= 19 or t < 5
end

function Events.meteorShower()
	local cfg = Config.Events
	local candidates = {}
	for i, isl in WorldBuilder.Islands do
		if i > 1 then -- not on the spawn island
			table.insert(candidates, isl)
		end
	end
	announce("A meteor shower lights up the night sky!", "meteor")
	Remotes.WorldFx:FireAllClients("sky", Color3.fromRGB(170, 150, 255), 150, "meteor")
	local count = rng:NextInteger(cfg.Meteors[1], cfg.Meteors[2])
	for _ = 1, count do
		task.wait(rng:NextNumber(3, 10))
		local isl = candidates[rng:NextInteger(1, #candidates)]
		local model = tag(WorldBuilder.spawnNodeOn(isl, "MoonstoneCluster"))
		if model then
			announce("A meteor is falling towards " .. isl.name .. "!", "meteor")
			task.spawn(function()
				meteor(model)
				-- Fades at dawn if nobody mines it.
				while model.Parent and isNight() do
					task.wait(5)
				end
				if model.Parent and not model:GetAttribute("Depleted") then
					model:Destroy()
				end
			end)
		end
	end
end

function Events.start()
	local cfg = Config.Events
	task.spawn(function()
		while true do
			task.wait(rng:NextNumber(cfg.EruptionEvery[1], cfg.EruptionEvery[2]))
			Events.erupt()
		end
	end)
	task.spawn(function()
		local wasNight = isNight()
		while true do
			task.wait(5)
			local night = isNight()
			if night and not wasNight and rng:NextNumber() < cfg.MeteorChance then
				task.delay(rng:NextNumber(10, 60), Events.meteorShower)
			end
			wasNight = night
		end
	end)
end

return Events
