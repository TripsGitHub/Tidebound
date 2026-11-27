-- World events: the only places the two best ores come from.
--   Eruption       every 10-15 minutes Ember Isle rumbles, smokes, and Obsidian Spires
--                  burst out of its slopes. They crumble after 5 minutes if nobody mines them.
--   Meteor shower  most nights a few meteors streak down onto the outer islands and
--                  leave Moonstone Clusters, which fade at dawn.
-- Event nodes are tagged Temporary, so Harvest destroys them instead of regrowing them.
-- Tune the timings in Config.Events. To try one in Studio, run in the server command bar:
--   require(game.ServerScriptService.Server.Events).erupt()   (or .meteorShower())
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local WorldBuilder = require(script.Parent.WorldBuilder)

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

local function announce(text: string)
	Remotes.Notify:FireAllClients(text, "good")
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
	announce("The ground shakes... Ember Isle is about to erupt!")
	local top = groundAt(ember.x, ember.z)
	plume((if top then top.Position else Vector3.new(ember.x, 40, ember.z)) + Vector3.new(0, 2, 0), cfg.EruptionWarning + 25)
	task.wait(cfg.EruptionWarning)
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
			local tween = TweenService:Create(v, TweenInfo.new(0.8, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Value = home })
			tween:Play()
			tween.Completed:Once(function()
				v:Destroy()
			end)
		end
	end
	if made > 0 then
		announce("Ember Isle erupted! " .. made .. " Obsidian Spires burst out of its slopes")
	end
	erupting = false
end

-- Meteor shower ----------------------------------------------------------------------

local function meteor(model: Model)
	local target = model:GetPivot().Position
	local parent = model.Parent
	model.Parent = nil -- hidden until the meteor lands
	local rock = Instance.new("Part")
	rock.Name = "Meteor"
	rock.Shape = Enum.PartType.Ball
	rock.Size = Vector3.new(4, 4, 4)
	rock.Material = Enum.Material.Neon
	rock.Color = Color3.fromRGB(180, 210, 255)
	rock.Anchored = true
	rock.CanCollide = false
	rock.CanQuery = false
	local start = target + Vector3.new(rng:NextNumber(-120, 120), 320, rng:NextNumber(-120, 120))
	rock.CFrame = CFrame.new(start)
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position = Vector3.new(0, 1.5, 0), Vector3.new(0, -1.5, 0)
	a0.Parent, a1.Parent = rock, rock
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Lifetime = 1.2
	trail.LightEmission = 1
	trail.Color = ColorSequence.new(Color3.fromRGB(200, 225, 255), Color3.fromRGB(120, 150, 255))
	trail.Transparency = NumberSequence.new(0, 1)
	trail.Parent = rock
	local light = Instance.new("PointLight")
	light.Color = rock.Color
	light.Range = 40
	light.Brightness = 3
	light.Parent = rock
	rock.Parent = workspace
	local fall = TweenService:Create(rock, TweenInfo.new(2.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = CFrame.new(target + Vector3.new(0, 2, 0)) })
	fall:Play()
	fall.Completed:Wait()
	rock.Transparency = 1
	light.Range = 60
	TweenService:Create(light, TweenInfo.new(1.5), { Brightness = 0 }):Play()
	task.delay(2, function()
		rock:Destroy()
	end)
	if parent and parent.Parent then
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
	announce("A meteor shower lights up the night sky!")
	local count = rng:NextInteger(cfg.Meteors[1], cfg.Meteors[2])
	for _ = 1, count do
		task.wait(rng:NextNumber(3, 10))
		local isl = candidates[rng:NextInteger(1, #candidates)]
		local model = tag(WorldBuilder.spawnNodeOn(isl, "MoonstoneCluster"))
		if model then
			announce("A meteor is falling towards " .. isl.name .. "!")
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
