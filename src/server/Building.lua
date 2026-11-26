-- Placing structures. The client sends where it wants to build;
-- the server snaps it to the grid, checks it, and builds it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Structures = require(Shared.Structures)
local Remotes = require(Shared.Remotes)
local Inventory = require(script.Parent.Inventory)
local Quests = require(script.Parent.Quests)

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

function builders.WoodWall(model: Model, cf: CFrame, size: Vector3)
	local core = part(model, true, { Name = "Core", Size = size - Vector3.new(0.2, 0, 0.3), CFrame = cf, Color = WOOD, Material = Enum.Material.Wood })
	-- Upright logs with pointed tops, like a palisade.
	local logs = 7
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
	for row = 0, 3 do
		local y = -size.Y / 2 + 1.1 + row * 2.2
		for x = -size.X / 2 + 1, size.X / 2 - 1, 2 do
			boulder(model, rng:NextNumber(2.1, 2.6), cf * CFrame.new(x + (row % 2), y, 0), if rng:NextNumber() < 0.5 then STONE else STONE_DARK)
		end
	end
	return core
end

function builders.WoodDoor(model: Model, cf: CFrame, size: Vector3, owner: Player)
	local core = part(model, true, { Name = "Core", Size = size, CFrame = cf, Color = WOOD_DARK, Material = Enum.Material.WoodPlanks })
	for _, y in { -size.Y / 3, size.Y / 3 } do
		part(model, false, { Name = "Brace", Size = Vector3.new(size.X + 0.05, 0.4, size.Z + 0.15), CFrame = cf * CFrame.new(0, y, 0), Color = WOOD, Material = Enum.Material.Wood, CanCollide = false })
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open"
	prompt.ObjectText = "Door"
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = core
	local open = false
	prompt.Triggered:Connect(function(who)
		if who.UserId ~= owner.UserId then
			Remotes.Notify:FireClient(who, "This door is locked", "warn")
			return
		end
		open = not open
		core.CanCollide = not open
		core.Transparency = if open then 0.75 else 0
		prompt.ActionText = if open then "Close" else "Open"
	end)
	return core
end

function builders.Campfire(model: Model, cf: CFrame, size: Vector3)
	local core = part(model, true, { Name = "Core", Size = Vector3.new(size.X, 0.4, size.Z), CFrame = cf * CFrame.new(0, -size.Y / 2 + 0.2, 0), Transparency = 1, CanCollide = false })
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		boulder(model, 0.8, cf * CFrame.new(math.cos(a) * 1.55, -size.Y / 2 + 0.35, math.sin(a) * 1.55), STONE)
	end
	for i = 0, 2 do
		part(model, false, { Name = "Log", Size = Vector3.new(0.45, 0.45, 2.4), CFrame = cf * CFrame.new(0, -size.Y / 2 + 0.55, 0) * CFrame.Angles(0, i * math.pi / 3, math.rad(12)), Color = WOOD_DARK, Material = Enum.Material.Wood })
	end
	local fire = Instance.new("Fire")
	fire.Size = 4
	fire.Heat = 7
	fire.Parent = core
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 160, 80)
	light.Range = 22
	light.Brightness = 2.2
	light.Shadows = true
	light.Parent = core

	-- Cook raw meat here.
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Cook meat"
	prompt.ObjectText = "Campfire"
	prompt.HoldDuration = 1.2
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = core
	prompt.Triggered:Connect(function(who)
		local raw = Inventory.count(who, "raw_meat")
		if raw <= 0 then
			Remotes.Notify:FireClient(who, "You have no raw meat", "warn")
			return
		end
		if Inventory.take(who, "raw_meat", raw) then
			Inventory.add(who, "cooked_meat", raw, true)
			Remotes.Notify:FireClient(who, "Cooked " .. raw .. " meat", "good")
		end
	end)
	return core
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

function Building.onPlace(player: Player, itemId: unknown, position: unknown, rotation: unknown)
	if type(itemId) ~= "string" or typeof(position) ~= "Vector3" or type(rotation) ~= "number" then
		return
	end
	local item = Items[itemId]
	if not item or item.kind ~= "placeable" or Inventory.count(player, itemId) < 1 then
		return
	end
	local def = Structures[item.structure]
	local builder = builders[item.structure]
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not def or not builder or not root then
		return
	end
	local pos = position :: Vector3
	if (pos - root.Position).Magnitude > Config.BuildRange then
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

	local rot = Structures.snapRotation(rotation :: number)
	local cf = CFrame.new(snapped.X, hit.Position.Y + def.size.Y / 2, snapped.Z) * CFrame.Angles(0, math.rad(rot), 0)

	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Include
	overlap.FilterDescendantsInstances = { workspace.Structures, workspace.Nodes }
	if #workspace:GetPartBoundsInBox(cf, def.size - Vector3.new(0.3, 0.3, 0.3), overlap) > 0 then
		Remotes.Notify:FireClient(player, "Something is in the way", "warn")
		return
	end

	if not Inventory.take(player, itemId, 1) then
		return
	end
	local model = Instance.new("Model")
	model.Name = item.structure
	model.PrimaryPart = builder(model, cf, def.size, player)
	model:SetAttribute("StructureType", item.structure)
	model:SetAttribute("DisplayName", item.name)
	model:SetAttribute("HP", def.hp)
	model:SetAttribute("MaxHP", def.hp)
	model:SetAttribute("OwnerId", player.UserId)
	model.Parent = workspace.Structures
	Quests.record(player, "build", nil, 1)
end

return Building
