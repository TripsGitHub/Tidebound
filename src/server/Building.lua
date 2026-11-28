-- Placing structures. The client sends where it wants to build;
-- the server snaps it to the grid, checks it, and builds it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Structures = require(Shared.Structures)
local Meshes = require(Shared.Meshes)
local Remotes = require(Shared.Remotes)
local Inventory = require(script.Parent.Inventory)
local Quests = require(script.Parent.Quests)
local Crafting = require(script.Parent.Crafting)
local Chests = require(script.Parent.Chests)
local Vehicles = require(script.Parent.Vehicles)
local Farming = require(script.Parent.Farming)

local Building = {}

local WOOD = Color3.fromRGB(150, 108, 68)
local WOOD_DARK = Color3.fromRGB(108, 76, 48)
local WOOD_LIGHT = Color3.fromRGB(184, 142, 96)
local STONE = Color3.fromRGB(128, 128, 133)
local STONE_DARK = Color3.fromRGB(100, 100, 106)

local rng = Random.new()

-- `solid` parts can be hit and block placement; decoration can't.
local function part(model: Model, solid: boolean, props): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanQuery = solid
	-- Only the flat core collides: no logs or boulders sticking out to climb on.
	p.CanCollide = solid
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = model
	return p
end

local function boulder(model: Model, size: number, cf: CFrame, color: Color3)
	part(model, false, { Name = "Rock", Size = Vector3.new(size, size * 0.8, size * 0.9), CFrame = cf * CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), rng:NextNumber(0, 3)), Color = color, Material = Enum.Material.Slate })
	part(model, false, { Name = "Rock", Size = Vector3.new(size * 0.7, size * 0.7, size * 0.7), CFrame = cf * CFrame.new(0, size * 0.15, 0) * CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), rng:NextNumber(0, 3)), Color = color:Lerp(Color3.new(1, 1, 1), 0.08), Material = Enum.Material.Slate })
end

local builders = {}

function builders.WoodBase(model: Model, cf: CFrame, size: Vector3)
	local core = part(model, true, { Name = "Core", Size = size - Vector3.new(0, 0.3, 0), CFrame = cf * CFrame.new(0, -0.15, 0), Color = WOOD_LIGHT, Material = Enum.Material.WoodPlanks })
	-- Log border
	for i = 0, 3 do
		local side = cf * CFrame.Angles(0, i * math.pi / 2, 0) * CFrame.new(0, 0.2, size.Z / 2 - 0.45)
		part(model, false, { Name = "Log", Shape = Enum.PartType.Cylinder, Size = Vector3.new(size.X, 0.9, 0.9), CFrame = side, Color = WOOD_DARK, Material = Enum.Material.Wood })
	end
	return core
end

function builders.StoneBase(model: Model, cf: CFrame, size: Vector3)
	local core = part(model, true, { Name = "Core", Size = size - Vector3.new(0, 0.3, 0), CFrame = cf * CFrame.new(0, -0.15, 0), Color = STONE, Material = Enum.Material.Slate })
	-- Chunky boulder border
	local step = 2
	for i = 0, 3 do
		local side = cf * CFrame.Angles(0, i * math.pi / 2, 0)
		for x = -size.X / 2 + 1, size.X / 2 - 1, step do
			boulder(model, rng:NextNumber(1.6, 2.1), side * CFrame.new(x, 0.5, size.Z / 2 - 0.8), if rng:NextNumber() < 0.5 then STONE else STONE_DARK)
		end
	end
	return core
end

function builders.LargeStoneBase(model: Model, cf: CFrame, size: Vector3)
	local core = builders.StoneBase(model, cf, size)
	core.Color = STONE_DARK
	-- Flagstone inlay so it reads as the big one.
	for _, o in { Vector3.new(-size.X / 4, 0, -size.Z / 4), Vector3.new(size.X / 4, 0, size.Z / 4), Vector3.new(-size.X / 4, 0, size.Z / 4), Vector3.new(size.X / 4, 0, -size.Z / 4) } do
		part(model, false, { Name = "Flag", Size = Vector3.new(size.X / 2 - 3, 0.12, size.Z / 2 - 3), CFrame = cf * CFrame.new(o + Vector3.new(0, size.Y / 2 - 0.25, 0)), Color = STONE, Material = Enum.Material.Slate })
	end
	return core
end

function builders.WoodWall(model: Model, cf: CFrame, size: Vector3)
	local core = part(model, true, { Name = "Core", Size = size - Vector3.new(0.2, 0, 0.3), CFrame = cf, Color = WOOD, Material = Enum.Material.Wood })
	-- Upright logs with pointed tops, like a palisade.
	local logs = math.max(7, math.round(size.X / 1.4))
	local w = size.X / logs
	for i = 0, logs - 1 do
		local x = -size.X / 2 + w * (i + 0.5)
		local h = size.Y - 0.8 + (i % 2) * 0.4
		part(model, false, { Name = "Log", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, w + 0.05, w + 0.05), CFrame = cf * CFrame.new(x, -size.Y / 2 + h / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = if i % 2 == 0 then WOOD else WOOD_DARK, Material = Enum.Material.Wood })
		local tip = part(model, false, { Name = "Tip", Size = Vector3.new(w * 0.7, 0.9, w * 0.7), CFrame = cf * CFrame.new(x, -size.Y / 2 + h + 0.3, 0) * CFrame.Angles(0, math.rad(45), 0), Color = WOOD_LIGHT, Material = Enum.Material.Wood })
		tip.Shape = Enum.PartType.Block
	end
	return core
end

function builders.StoneWall(model: Model, cf: CFrame, size: Vector3)
	local core = part(model, true, { Name = "Core", Size = size - Vector3.new(0.3, 0.3, 0.4), CFrame = cf, Color = STONE_DARK, Material = Enum.Material.Slate })
	for row = 0, math.floor((size.Y - 1) / 2.2) - 1 do
		local y = -size.Y / 2 + 1.1 + row * 2.2
		for x = -size.X / 2 + 1, size.X / 2 - 1, 2 do
			boulder(model, rng:NextNumber(2.1, 2.6), cf * CFrame.new(x + (row % 2), y, 0), if rng:NextNumber() < 0.5 then STONE else STONE_DARK)
		end
	end
	return core
end

-- A gate looks like a wall with braces across it. There's no opening animation:
-- its owner simply walks through it (each owner's client turns its collision off
-- locally, see Gates.lua), while everyone else is blocked like by any wall.
function builders.WoodGate(model: Model, cf: CFrame, size: Vector3)
	local core = builders.WoodWall(model, cf, size)
	for _, y in { -size.Y / 4, size.Y / 4 } do
		part(model, false, { Name = "Brace", Size = Vector3.new(size.X - 0.4, 0.55, 0.5), CFrame = cf * CFrame.new(0, y, -size.Z / 2 - 0.2), Color = WOOD_LIGHT, Material = Enum.Material.Wood, CanCollide = false })
	end
	local diag = math.sqrt(size.X ^ 2 + (size.Y / 2) ^ 2)
	part(model, false, { Name = "Brace", Size = Vector3.new(diag - 0.6, 0.5, 0.45), CFrame = cf * CFrame.new(0, 0, -size.Z / 2 - 0.2) * CFrame.Angles(0, 0, math.atan2(size.Y / 2, size.X)), Color = WOOD_LIGHT, Material = Enum.Material.Wood, CanCollide = false })
	return core
end

-- A wooden storage chest: planked box, darker lid, iron bands and a brass lock.
-- A raised wooden box full of dark soil, with corner posts.
function builders.PlantBox(model: Model, cf: CFrame, size: Vector3)
	local core = part(model, true, { Name = "Core", Size = size, CFrame = cf, Color = Color3.fromRGB(70, 48, 32), Material = Enum.Material.Ground })
	for i = 0, 3 do
		local side = cf * CFrame.Angles(0, i * math.pi / 2, 0)
		part(model, false, { Name = "Plank", Size = Vector3.new(size.X + 0.5, size.Y + 0.4, 0.5), CFrame = side * CFrame.new(0, 0.2, size.Z / 2), Color = if i % 2 == 0 then WOOD else WOOD_DARK, Material = Enum.Material.WoodPlanks })
		part(model, false, { Name = "Post", Size = Vector3.new(0.7, size.Y + 0.8, 0.7), CFrame = side * CFrame.new(size.X / 2, 0.4, size.Z / 2), Color = WOOD_DARK, Material = Enum.Material.Wood })
	end
	-- Furrows in the soil.
	for r = -1, 1 do
		part(model, false, { Name = "Furrow", Size = Vector3.new(size.X - 1, 0.2, 0.6), CFrame = cf * CFrame.new(0, size.Y / 2 + 0.02, r * size.Z * 0.28), Color = Color3.fromRGB(56, 38, 26), Material = Enum.Material.Ground })
	end
	return core
end

function builders.Chest(model: Model, cf: CFrame, size: Vector3)
	local bodyH = size.Y * 0.68
	local core = part(model, true, { Name = "Core", Size = Vector3.new(size.X, bodyH, size.Z), CFrame = cf * CFrame.new(0, -size.Y / 2 + bodyH / 2, 0), Color = WOOD, Material = Enum.Material.WoodPlanks })
	local lidH = size.Y - bodyH
	part(model, false, { Name = "Lid", Size = Vector3.new(size.X + 0.2, lidH, size.Z + 0.2), CFrame = cf * CFrame.new(0, size.Y / 2 - lidH / 2, 0), Color = WOOD_DARK, Material = Enum.Material.WoodPlanks })
	for _, x in { -size.X * 0.32, size.X * 0.32 } do
		part(model, false, { Name = "Band", Size = Vector3.new(0.35, size.Y + 0.05, size.Z + 0.3), CFrame = cf * CFrame.new(x, 0, 0), Color = Color3.fromRGB(80, 80, 86), Material = Enum.Material.Metal })
	end
	part(model, false, { Name = "Lock", Size = Vector3.new(0.7, 0.8, 0.25), CFrame = cf * CFrame.new(0, size.Y / 2 - lidH - 0.1, -size.Z / 2 - 0.2), Color = Color3.fromRGB(214, 176, 72), Material = Enum.Material.Metal })
	return core
end

function builders.Campfire(model: Model, cf: CFrame, size: Vector3)
	local core = part(model, true, { Name = "Core", Size = Vector3.new(size.X, 0.4, size.Z), CFrame = cf * CFrame.new(0, -size.Y / 2 + 0.2, 0), Transparency = 1, CanCollide = false })
	local ringR = size.X * 0.4
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		boulder(model, 1.5, cf * CFrame.new(math.cos(a) * ringR, -size.Y / 2 + 0.6, math.sin(a) * ringR), STONE)
	end
	for i = 0, 3 do
		-- Logs leaning in toward the middle, like a teepee.
		local a = i * math.pi / 2 + 0.4
		part(model, false, { Name = "Log", Size = Vector3.new(0.8, 0.8, size.X * 0.55), CFrame = cf * CFrame.new(math.cos(a) * 1.3, -size.Y / 2 + 1.2, math.sin(a) * 1.3) * CFrame.Angles(0, -a + math.pi / 2, 0) * CFrame.Angles(math.rad(35), 0, 0), Color = WOOD_DARK, Material = Enum.Material.Wood })
	end
	local fire = Instance.new("Fire")
	fire.Size = 9
	fire.Heat = 12
	fire.Parent = core
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 160, 80)
	light.Range = 32
	light.Brightness = 2.2
	light.Shadows = true
	light.Parent = core

	-- Cooking and smelting: drop raw meat or ore into the fire (Smelting.lua).
	return core
end

-- Round 7 structures -----------------------------------------------------------
local Tiers = require(Shared.Tiers)

-- A torch on a stake: wrapped head, a flame and a warm light.
function builders.Torch(model: Model, cf: CFrame, size: Vector3)
	local core = part(model, true, { Name = "Core", Size = Vector3.new(0.7, size.Y, 0.7), CFrame = cf, Color = WOOD_DARK, Material = Enum.Material.Wood })
	local head = part(model, false, { Name = "Head", Size = Vector3.new(1, 1.1, 1), CFrame = cf * CFrame.new(0, size.Y / 2 - 0.3, 0), Color = Color3.fromRGB(120, 86, 52), Material = Enum.Material.Fabric })
	local fire = Instance.new("Fire")
	fire.Size, fire.Heat = 3, 6
	fire.Parent = head
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness, light.Shadows = Color3.fromRGB(255, 170, 90), 26, 1.8, true
	light.Parent = head
	return core
end

-- A lantern hung from the arm of a post: glass box with a steady glow.
function builders.Lamp(model: Model, cf: CFrame, size: Vector3)
	local core = part(model, true, { Name = "Core", Size = Vector3.new(0.8, size.Y, 0.8), CFrame = cf, Color = WOOD_DARK, Material = Enum.Material.Wood })
	part(model, false, { Name = "Arm", Size = Vector3.new(0.4, 0.4, 2.2), CFrame = cf * CFrame.new(0, size.Y / 2 - 0.4, -0.9), Color = WOOD_DARK, Material = Enum.Material.Wood })
	local glass = part(model, false, { Name = "Lantern", Size = Vector3.new(1.1, 1.4, 1.1), CFrame = cf * CFrame.new(0, size.Y / 2 - 1.5, -1.8), Color = Color3.fromRGB(255, 214, 140), Material = Enum.Material.Neon, Transparency = 0.25 })
	part(model, false, { Name = "Cap", Size = Vector3.new(1.4, 0.3, 1.4), CFrame = glass.CFrame * CFrame.new(0, 0.85, 0), Color = Color3.fromRGB(60, 56, 54), Material = Enum.Material.Metal })
	part(model, false, { Name = "Cap", Size = Vector3.new(1.3, 0.25, 1.3), CFrame = glass.CFrame * CFrame.new(0, -0.8, 0), Color = Color3.fromRGB(60, 56, 54), Material = Enum.Material.Metal })
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness, light.Shadows = Color3.fromRGB(255, 200, 130), 40, 2, true
	light.Parent = glass
	return core
end

-- A low wooden bed with a straw mattress, a pillow and a hide blanket.
function builders.Bed(model: Model, cf: CFrame, size: Vector3, owner: Player?)
	local core = part(model, true, { Name = "Core", Size = Vector3.new(size.X, 1, size.Z), CFrame = cf * CFrame.new(0, -size.Y / 2 + 0.5, 0), Color = WOOD, Material = Enum.Material.WoodPlanks })
	part(model, false, { Name = "Mattress", Size = Vector3.new(size.X - 0.4, 0.6, size.Z - 0.4), CFrame = cf * CFrame.new(0, -size.Y / 2 + 1.3, 0), Color = Color3.fromRGB(214, 190, 130), Material = Enum.Material.Fabric })
	part(model, false, { Name = "Pillow", Size = Vector3.new(size.X - 1.2, 0.5, 1.4), CFrame = cf * CFrame.new(0, -size.Y / 2 + 1.8, size.Z / 2 - 1.2), Color = Color3.fromRGB(240, 232, 214), Material = Enum.Material.Fabric })
	part(model, false, { Name = "Blanket", Size = Vector3.new(size.X - 0.2, 0.2, size.Z * 0.55), CFrame = cf * CFrame.new(0, -size.Y / 2 + 1.7, -size.Z * 0.18), Color = Color3.fromRGB(150, 82, 56), Material = Enum.Material.Fabric })
	part(model, false, { Name = "Headboard", Size = Vector3.new(size.X, 2.4, 0.5), CFrame = cf * CFrame.new(0, -size.Y / 2 + 1.2, size.Z / 2 - 0.25), Color = WOOD_DARK, Material = Enum.Material.Wood })
	-- Sleeping in it sets where you wake up after dying.
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Set spawn here"
	prompt.ObjectText = "Bed"
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = core
	prompt.Triggered:Connect(function(who)
		if who.UserId ~= model:GetAttribute("OwnerId") then
			Remotes.Notify:FireClient(who, "That bed isn't yours", "warn")
			return
		end
		who:SetAttribute("BedAt", core.Position + Vector3.new(0, 4, 0))
		Remotes.Notify:FireClient(who, "You'll wake up here when you die", "good")
	end)
	if owner then
		owner:SetAttribute("BedAt", core.Position + Vector3.new(0, 4, 0))
	end
	return core
end

-- A wooden frame of sharpened stakes, low to the ground. Bites anyone but its owner.
function builders.SpikeTrap(model: Model, cf: CFrame, size: Vector3)
	local core = part(model, true, { Name = "Core", Size = size, CFrame = cf, Color = WOOD_DARK, Material = Enum.Material.Wood, CanCollide = false })
	core.CanTouch = true
	for x = -2, 2, 1 do
		for z = -2, 2, 1 do
			if (x + z) % 2 == 0 then
				part(model, false, { Name = "Spike", Size = Vector3.new(0.35, 1.4, 0.35), CFrame = cf * CFrame.new(x * 1.1, 0.6, z * 1.1) * CFrame.Angles(0, math.rad(45), 0), Color = Color3.fromRGB(196, 184, 160), Material = Enum.Material.Wood })
			end
		end
	end
	local last: { [Instance]: number } = {}
	core.Touched:Connect(function(hit)
		local m = hit:FindFirstAncestorOfClass("Model")
		local hum = m and m:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health <= 0 then
			return
		end
		local who = Players:GetPlayerFromCharacter(m)
		if who and who.UserId == model:GetAttribute("OwnerId") then
			return
		end
		if (last[m :: Model] or 0) + 1 > os.clock() then
			return
		end
		last[m :: Model] = os.clock()
		hum:TakeDamage(12)
	end)
	-- Beasts are moved by script, so Touched doesn't see them: check for them instead.
	task.spawn(function()
		local Animals = require(script.Parent.Animals)
		local params = OverlapParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		while model.Parent do
			task.wait(0.5)
			local animals = workspace:FindFirstChild("Animals")
			local owner = Players:GetPlayerByUserId(model:GetAttribute("OwnerId") or 0)
			if animals and owner then
				params.FilterDescendantsInstances = { animals }
				local seen = {}
				for _, p in workspace:GetPartBoundsInBox(core.CFrame, core.Size + Vector3.new(0, 4, 0), params) do
					local a = p:FindFirstAncestorOfClass("Model")
					while a and a.Parent ~= animals do
						a = a:FindFirstAncestorOfClass("Model")
					end
					if a and not seen[a] and (last[a] or 0) + 1 <= os.clock() then
						seen[a] = true
						last[a] = os.clock()
						Animals.damage(a, 12, owner)
					end
				end
			end
		end
	end)
	return core
end

-- A climbable ladder (a truss inside, so the character climbs it).
function builders.Ladder(model: Model, cf: CFrame, size: Vector3)
	local core = Instance.new("TrussPart")
	core.Name = "Core"
	core.Anchored = true
	core.Size = Vector3.new(2, size.Y, 2)
	core.CFrame = cf
	core.Transparency = 1
	core.Parent = model
	for sx = -1, 1, 2 do
		part(model, false, { Name = "Rail", Size = Vector3.new(0.4, size.Y, 0.4), CFrame = cf * CFrame.new(sx * 1.3, 0, 0), Color = WOOD_DARK, Material = Enum.Material.Wood })
	end
	for y = -size.Y / 2 + 1, size.Y / 2 - 0.5, 1.6 do
		part(model, false, { Name = "Rung", Size = Vector3.new(2.6, 0.3, 0.3), CFrame = cf * CFrame.new(0, y, 0), Color = WOOD, Material = Enum.Material.Wood })
	end
	return core :: any
end

-- Ore walls: a stone wall faced with plates of the ore, with a rim along the top.
-- Ore chests and carts: the wooden chest bound in the ore.
for name, def in Structures do
	if type(def) ~= "table" or not def.tier then
		continue
	end
	local tier = Tiers.get(def.tier) :: any
	if def.wall then
		builders[name] = function(model: Model, cf: CFrame, size: Vector3)
			local core = part(model, true, { Name = "Core", Size = size - Vector3.new(0.3, 0.3, 0.4), CFrame = cf, Color = STONE_DARK, Material = Enum.Material.Slate })
			for row = 0, 3 do
				for col = 0, 1 do
					local y = -size.Y / 2 + 2.3 + row * 4.4
					local x = -size.X / 4 + col * size.X / 2 + (if row % 2 == 0 then 0 else 0.4)
					for side = -1, 1, 2 do
						part(model, false, { Name = "Plate", Size = Vector3.new(size.X / 2 - 0.5, 4, 0.25), CFrame = cf * CFrame.new(x, y, side * (size.Z / 2 - 0.05)), Color = if (row + col) % 2 == 0 then tier.plate else tier.plate:Lerp(tier.trim, 0.3), Material = Enum.Material.Metal })
					end
				end
			end
			part(model, false, { Name = "Rim", Size = Vector3.new(size.X + 0.2, 0.6, size.Z + 0.3), CFrame = cf * CFrame.new(0, size.Y / 2 - 0.3, 0), Color = tier.trim, Material = Enum.Material.Metal })
			if tier.glow then
				part(model, false, { Name = "Glow", Size = Vector3.new(size.X - 1, 0.2, size.Z + 0.35), CFrame = cf * CFrame.new(0, size.Y / 2 - 0.75, 0), Color = tier.accent, Material = Enum.Material.Neon })
			end
			return core
		end
	elseif def.chest and not def.cart then
		builders[name] = function(model: Model, cf: CFrame, size: Vector3)
			local core = builders.Chest(model, cf, size)
			for _, p in model:GetChildren() do
				if p:IsA("BasePart") and (p.Name == "Band" or p.Name == "Lock") then
					p.Color = if p.Name == "Lock" then tier.accent else tier.plate
				end
			end
			return core
		end
	elseif def.cart then
		builders[name] = function(model: Model, cf: CFrame, size: Vector3)
			local boxH = size.Y * 0.55
			local core = part(model, true, { Name = "Core", Size = Vector3.new(size.X, boxH, size.Z), CFrame = cf * CFrame.new(0, size.Y / 2 - boxH / 2, 0), Color = WOOD, Material = Enum.Material.WoodPlanks })
			for sx = -1, 1, 2 do
				for sz = -1, 1, 2 do
					part(model, false, { Name = "Wheel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 2.2, 2.2), CFrame = cf * CFrame.new(sx * (size.X / 2 - 1.2), -size.Y / 2 + 1.1, sz * (size.Z / 2 + 0.2)) * CFrame.Angles(0, math.rad(90), 0), Color = WOOD_DARK, Material = Enum.Material.Wood })
									end
			end
			part(model, false, { Name = "Rim", Size = Vector3.new(size.X + 0.2, 0.3, size.Z + 0.2), CFrame = cf * CFrame.new(0, size.Y / 2 - 0.15, 0), Color = if def.tier == "wood" then WOOD_DARK else tier.plate, Material = if def.tier == "wood" then Enum.Material.Wood else Enum.Material.Metal })
			part(model, false, { Name = "Handle", Size = Vector3.new(0.3, 0.3, 3), CFrame = cf * CFrame.new(-size.X / 2 - 1.2, 0, 0) * CFrame.Angles(0, math.rad(90), 0), Color = WOOD_DARK, Material = Enum.Material.Wood })
			return core
		end
	end
end

local function characterList(): { Instance }
	local list = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(list, p.Character)
		end
	end
	return list
end

-- Structures that have a Blender mesh. The builder still makes the invisible core
-- (collision, hits, fire, prompts); the mesh replaces the block decoration.
local STRUCTURE_MESHES = {
	WoodWall = { mesh = "woodwall", stretch = true },
	WoodGate = { mesh = "woodgate", stretch = true },
	WoodBase = { mesh = "woodfloor", stretch = true },
	Campfire = { mesh = "campfire" },
}

local function dressWithMesh(model: Model, core: BasePart, structure: string, cf: CFrame, size: Vector3)
	local spec = STRUCTURE_MESHES[structure]
	local mesh = spec and Meshes.build(spec.mesh, if spec.stretch then { fit = size, collide = false } else { width = size.X, collide = false })
	if not mesh then
		return
	end
	for _, p in model:GetChildren() do
		if p ~= core and p:IsA("BasePart") then
			p:Destroy()
		end
	end
	core.Transparency = 1
	mesh:PivotTo(cf * CFrame.new(0, -size.Y / 2, 0))
	for _, p in mesh:GetChildren() do
		(p :: BasePart).CanQuery = false
		p.Parent = model
	end
	mesh:Destroy()
end

-- Builds the structure at cf, owned by userId. No checks: callers check first.
local function construct(ownerId: number, ownerPlayer: Player?, itemId: string, cf: CFrame, tiles: number, hp: number?, stored: any?): Model
	local item = Items[itemId]
	local def = Structures[item.structure]
	local size = Structures.sizeFor(item.structure, tiles)
	local model = Instance.new("Model")
	model.Name = item.structure
	local core = builders[item.structure](model, cf, size, ownerPlayer)
	model.PrimaryPart = core
	dressWithMesh(model, core, item.structure, cf, size)
	local maxHp = def.hp * (if Structures.isFloor(item.structure) then tiles * tiles else 1)
	model:SetAttribute("StructureType", item.structure)
	model:SetAttribute("ItemId", itemId)
	model:SetAttribute("Tiles", tiles)
	model:SetAttribute("DisplayName", item.name)
	model:SetAttribute("HP", math.min(hp or maxHp, maxHp))
	model:SetAttribute("MaxHP", maxHp)
	model:SetAttribute("OwnerId", ownerId)
	if def.chest then
		model:SetAttribute("Capacity", def.chest)
		Chests.setup(model, stored)
	end
	if def.planter then
		Farming.setup(model, stored)
	end
	if def.cart then
		-- Carts roll: an invisible low-friction skid under the wheels touches the
		-- ground, the seat sits on the back of the box, and the owner can drive it.
		local skid = part(model, true, { Name = "Skid", Size = Vector3.new(size.X - 0.4, 0.6, size.Z), CFrame = cf * CFrame.new(0, -size.Y / 2 + 0.3, 0), Transparency = 1 })
		skid.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.05, 0, 1, 1)
		local seatCf = cf * CFrame.new(size.X / 2 - 1.3, size.Y / 2 + 0.25, 0) * CFrame.Angles(0, math.rad(90), 0)
		Vehicles.rig(model, core, "cart", def.speed or 24, seatCf)
		model:SetAttribute("Forward", Vector3.new(-1, 0, 0))
	end
	model.Parent = workspace.Structures
	return model
end

local function blocked(cf: CFrame, size: Vector3, structuresOnly: boolean?): boolean
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Include
	overlap.FilterDescendantsInstances = if structuresOnly then { workspace.Structures } else { workspace.Structures, workspace.Nodes }
	return #workspace:GetPartBoundsInBox(cf, size - Vector3.new(0.3, 0.3, 0.3), overlap) > 0
end

-- A base plate clears the ground it's laid on: trees, rocks and bushes under it go
-- (cave seals and the like are never touched), and so does loose decoration.
local function clearGround(cf: CFrame, size: Vector3)
	local box = Vector3.new(size.X + 2, 40, size.Z + 2)
	local at = cf * CFrame.new(0, 18, 0)
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Include
	local folders = {}
	for _, name in { "Nodes", "Decor" } do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(folders, f)
		end
	end
	overlap.FilterDescendantsInstances = folders
	local gone: { [Instance]: boolean } = {}
	for _, p in workspace:GetPartBoundsInBox(at, box, overlap) do
		local nodes = workspace:FindFirstChild("Nodes")
		local target: Instance = p
		if nodes and p:IsDescendantOf(nodes) then
			while target.Parent and target.Parent ~= nodes do
				target = target.Parent
			end
			local kind = tostring(target:GetAttribute("NodeType") or "")
			if string.find(kind, "Seal") or string.find(kind, "Gate") or target:GetAttribute("Boss") then
				continue
			end
		end
		if not gone[target] then
			gone[target] = true
			target:Destroy()
		end
	end
end

-- Defined with the base saving code below.
local baseOf: (userId: number) -> Model?
local rebuildOn: (player: Player, base: Model) -> ()
local countPieces: (player: Player, at: Vector3) -> (number, number, boolean)

function Building.onPlace(player: Player, itemId: unknown, position: unknown, rotation: unknown, tiles: unknown)
	if type(itemId) ~= "string" or typeof(position) ~= "Vector3" or type(rotation) ~= "number" then
		return
	end
	local item = Items[itemId]
	if not item or item.kind ~= "placeable" then
		return
	end
	local def = Structures[item.structure]
	local builder = builders[item.structure]
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not def or not builder or not root then
		return
	end
	local n = if Structures.isFloor(item.structure) and type(tiles) == "number" then math.clamp(math.floor(tiles), 1, Structures.MAX_TILES) else 1
	local cost = n * n
	if Inventory.count(player, itemId) < cost then
		Remotes.Notify:FireClient(player, "You need " .. cost .. " " .. item.name .. " for that size", "warn")
		return
	end
	if Structures.isBase(item.structure) and baseOf(player.UserId) then
		Remotes.Notify:FireClient(player, "You already have a base. Build on it, or break it to move", "warn")
		return
	end
	-- Two separate limits: what stands on your base (saved with it), and loose
	-- pieces out in the world (camps, bridges, walls on the way somewhere).
	if not Structures.isBase(item.structure) then
		local onYourBase, loose, isOnBase = countPieces(player, position :: Vector3)
		if isOnBase and onYourBase >= Config.MaxStructures then
			Remotes.Notify:FireClient(player, "Your base is full (" .. Config.MaxStructures .. " pieces)", "warn")
			return
		elseif not isOnBase and loose >= Config.MaxLooseStructures then
			Remotes.Notify:FireClient(player, "Too many pieces out in the world (" .. Config.MaxLooseStructures .. "). Break some, or build on your base", "warn")
			return
		end
	end
	local size = Structures.sizeFor(item.structure, n)
	local pos = position :: Vector3
	if (pos - root.Position).Magnitude > Config.BuildRange + size.X / 2 then
		Remotes.Notify:FireClient(player, "Too far away", "warn")
		return
	end
	local spawnPoint = workspace:FindFirstChild("TideboundSpawn") :: BasePart?
	if spawnPoint and (pos - spawnPoint.Position).Magnitude < Config.SpawnNoBuildRadius then
		Remotes.Notify:FireClient(player, "Too close to the spawn", "warn")
		return
	end

	local snapped = Structures.snap(pos)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = characterList()
	for _, name in { "Nodes", "Drops", "Animals", "LootSacks" } do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(exclude, f)
		end
	end
	params.FilterDescendantsInstances = exclude
	local hit = workspace:Raycast(Vector3.new(snapped.X, pos.Y + 4, snapped.Z), Vector3.new(0, -40, 0), params)
	if not hit or hit.Material == Enum.Material.Water then
		Remotes.Notify:FireClient(player, "Can't build there", "warn")
		return
	end

	-- Walls on a floor's edge: the ray can slip past the floor's rim, so if the
	-- client put it on top of one of the floors there, trust that height.
	local groundY = hit.Position.Y
	if pos.Y > groundY + 0.5 then
		for _, m in workspace.Structures:GetChildren() do
			local st = m:GetAttribute("StructureType")
			local core = m:IsA("Model") and m.PrimaryPart
			if st and core and Structures.isFloor(st) then
				local top = core.Position.Y + core.Size.Y / 2
				local rel = core.CFrame:PointToObjectSpace(pos)
				if math.abs(top - pos.Y) < 0.6 and math.abs(rel.X) <= core.Size.X / 2 + 1 and math.abs(rel.Z) <= core.Size.Z / 2 + 1 then
					groundY = top
					break
				end
			end
		end
	end
	local rot = Structures.snapRotation(rotation :: number)
	local cf = CFrame.new(snapped.X, groundY + size.Y / 2, snapped.Z) * CFrame.Angles(0, math.rad(rot), 0)
	local isBase = Structures.isBase(item.structure)
	if blocked(cf, size, isBase) then
		Remotes.Notify:FireClient(player, if isBase then "Too close to someone else's build" else "Something is in the way", "warn")
		return
	end

	if not Inventory.take(player, itemId, cost) then
		return
	end
	if isBase then
		clearGround(cf, size)
	end
	local placed = construct(player.UserId, player, itemId, cf, n)
	Crafting.placed(player, itemId)
	if Structures.isBase(item.structure) then
		rebuildOn(player, placed)
	end
	Quests.record(player, "build", nil, 1)
end

-- Bases ---------------------------------------------------------------------------
-- Each player has one base (a Wooden, Stone or Large Stone plot). Only what stands on
-- it is saved, relative to the base, so the whole thing can be put down anywhere:
-- when you join you craft a new base plate, and placing it rebuilds what was on your
-- old one (any plate type; pieces that don't fit on a smaller plate stay saved).
-- Pieces built away from your base are temporary. Leaving clears your pieces.

local pending: { [Player]: { itemId: string?, builds: { any } } } = {}

function baseOf(userId: number): Model?
	for _, m in workspace.Structures:GetChildren() do
		local st = m:GetAttribute("StructureType")
		if m:GetAttribute("OwnerId") == userId and st and Structures.isBase(st) and m:IsA("Model") and m.PrimaryPart then
			return m
		end
	end
	return nil
end
Building.baseOf = baseOf

-- The base's build frame: centre of its top face, turned with it.
local function baseFrame(base: Model): (CFrame, Vector3)
	local core = base.PrimaryPart :: BasePart
	local _, ry = core.CFrame:ToOrientation()
	local top = core.Position.Y + core.Size.Y / 2
	return CFrame.new(core.Position.X, top, core.Position.Z) * CFrame.Angles(0, ry, 0), core.Size
end

-- Where a piece was built (the cf construct() got), from its core.
local function buildCf(m: Model): CFrame
	local cf = (m.PrimaryPart :: BasePart).CFrame
	local st = m:GetAttribute("StructureType")
	if st and Structures[st] and Structures[st].chest and not Structures[st].cart then
		local size = Structures.sizeFor(st)
		cf = cf * CFrame.new(0, size.Y / 2 - size.Y * 0.34, 0)
	elseif st == "Campfire" then
		cf = cf * CFrame.new(0, Structures.sizeFor("Campfire").Y / 2 - 0.2, 0)
	elseif st and Structures.isBase(st) then
		cf = cf * CFrame.new(0, 0.15, 0)
	end
	return cf
end

local function onBase(frame: CFrame, size: Vector3, p: Vector3): boolean
	local rel = frame:PointToObjectSpace(p)
	return math.abs(rel.X) <= size.X / 2 + 1.5 and math.abs(rel.Z) <= size.Z / 2 + 1.5 and rel.Y > -3 and rel.Y < 40
end

function countPieces(player: Player, at: Vector3): (number, number, boolean)
	local base = baseOf(player.UserId)
	local frame, size
	if base then
		frame, size = baseFrame(base)
	end
	local on, loose = 0, 0
	for _, m in workspace.Structures:GetChildren() do
		local st = m:GetAttribute("StructureType")
		if m ~= base and m:GetAttribute("OwnerId") == player.UserId and st and not Structures.isBase(st) and m:IsA("Model") and m.PrimaryPart then
			if frame and onBase(frame, size, m.PrimaryPart.Position) then
				on += 1
			else
				loose += 1
			end
		end
	end
	return on, loose, frame ~= nil and onBase(frame, size, at)
end

local function round1(n: number): number
	return math.round(n * 10) / 10
end

-- Called when a base goes down: if it's the one you saved, everything on it comes back.
function rebuildOn(player: Player, base: Model)
	local saved = pending[player]
	if not saved then
		return
	end
	pending[player] = nil
	local frame, plate = baseFrame(base)
	local count, skipped = 0, 0
	local leftover = {}
	for _, e in saved.builds do
		local item = type(e) == "table" and Items[e.i]
		if item and item.kind == "placeable" and Structures[item.structure] and not Structures.isBase(item.structure) and type(e.x) == "number" then
			local size = Structures.sizeFor(item.structure)
			local cf = frame * CFrame.new(e.x, e.y, e.z) * CFrame.Angles(0, math.rad(tonumber(e.r) or 0), 0)
			if not onBase(frame, plate, cf.Position) then
				table.insert(leftover, e) -- needs a bigger plate; kept for next time
			elseif count < Config.MaxStructures and not blocked(cf, size) then
				construct(player.UserId, player, e.i, cf, 1, if (tonumber(e.hp) or 0) > 0 then e.hp else nil, e.c)
				count += 1
			else
				skipped += 1
			end
		end
	end
	if #leftover > 0 then
		-- Remember what didn't fit, so a bigger plate later still brings it back.
		pending[player] = { itemId = saved.itemId, builds = leftover }
	end
	Remotes.Notify:FireClient(player, "Your base is back" .. (if count > 0 then " with " .. count .. " pieces" else "") .. (if #leftover > 0 then " (" .. #leftover .. " need a bigger base)" elseif skipped > 0 then " (" .. skipped .. " were blocked)" else ""), "good")
end

-- What to save: your base and everything on it. nil when you have no base.
function Building.export(player: Player): any
	local base = baseOf(player.UserId)
	if not base then
		local p = pending[player]
		return if p then { i = p.itemId, builds = p.builds } else nil
	end
	local frame, size = baseFrame(base)
	local list = {}
	for _, m in workspace.Structures:GetChildren() do
		local itemId = m:GetAttribute("ItemId")
		local st = m:GetAttribute("StructureType")
		if m ~= base and m:GetAttribute("OwnerId") == player.UserId and itemId and st and m:IsA("Model") and m.PrimaryPart and not Structures.isBase(st) then
			local cf = buildCf(m)
			if onBase(frame, size, cf.Position) then
				local rel = frame:ToObjectSpace(cf)
				local _, ry = rel:ToOrientation()
				table.insert(list, {
					i = itemId,
					x = round1(rel.X),
					y = round1(rel.Y),
					z = round1(rel.Z),
					r = Structures.snapRotation(math.deg(ry)),
					hp = math.floor(m:GetAttribute("HP") or 0),
					c = if Structures[st] and Structures[st].chest then Chests.export(m) elseif Structures[st] and Structures[st].planter then Farming.export(m) else nil,
				})
				if #list >= Config.MaxStructures then
					break
				end
			end
		end
	end
	return { i = base:GetAttribute("ItemId"), hp = math.floor(base:GetAttribute("HP") or 0), builds = list }
end

-- On join: remember what stood on your base. Craft and place a base plate to get it back.
function Building.load(player: Player, saved: any)
	if type(saved) ~= "table" or type(saved.builds) ~= "table" or #saved.builds == 0 then
		return
	end
	local item = type(saved.i) == "string" and Items[saved.i]
	pending[player] = { itemId = saved.i, builds = saved.builds }
	task.delay(6, function() -- once their screen is up
		if player.Parent and pending[player] then
			Remotes.Notify:FireClient(player, "Craft and place a base to bring back your " .. #saved.builds .. " saved pieces" .. (if item then " (you had a " .. item.name .. ")" else ""), "good")
		end
	end)
end

function Building.pendingBase(player: Player): string?
	local p = pending[player]
	return p and p.itemId
end

-- Leaving: your pieces go with you (they're saved on your base).
function Building.removePlayer(player: Player)
	local id = player.UserId
	task.delay(1, function() -- after Save.leave has taken its snapshot
		pending[player] = nil
		if game:GetService("Players"):GetPlayerByUserId(id) then
			return -- came straight back
		end
		for _, m in workspace.Structures:GetChildren() do
			if m:GetAttribute("OwnerId") == id then
				m:SetAttribute("Despawn", true)
				m:Destroy()
			end
		end
	end)
end
Players.PlayerRemoving:Connect(Building.removePlayer)

return Building
