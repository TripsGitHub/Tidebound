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
local STONE = Color3.fromRGB(128, 126, 120)

local function part(props): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	return p
end

-- One function per structure type. Each returns a Model centred on `cf`.
local builders = {}

local function plankWall(cf: CFrame, size: Vector3, color: Color3, material: Enum.Material, planks: number): Model
	local model = Instance.new("Model")
	local core = part({ Name = "Core", Size = size, CFrame = cf, Color = color, Material = material })
	core.Parent = model
	-- A few darker strips so walls read as planks/blocks instead of flat slabs.
	for i = 1, planks - 1 do
		local y = -size.Y / 2 + i * size.Y / planks
		local strip = part({
			Name = "Seam",
			Size = Vector3.new(size.X + 0.05, 0.12, size.Z + 0.05),
			CFrame = cf * CFrame.new(0, y, 0),
			Color = color:Lerp(Color3.new(0, 0, 0), 0.35),
			Material = material,
			CanCollide = false,
		})
		strip.Parent = model
	end
	model.PrimaryPart = core
	return model
end

function builders.WoodWall(cf: CFrame, size: Vector3): Model
	return plankWall(cf, size, WOOD, Enum.Material.WoodPlanks, 4)
end

function builders.StoneWall(cf: CFrame, size: Vector3): Model
	return plankWall(cf, size, STONE, Enum.Material.Cobblestone, 3)
end

function builders.WoodFloor(cf: CFrame, size: Vector3): Model
	local model = Instance.new("Model")
	local core = part({ Name = "Core", Size = size, CFrame = cf, Color = WOOD, Material = Enum.Material.WoodPlanks })
	core.Parent = model
	model.PrimaryPart = core
	return model
end

function builders.WoodDoor(cf: CFrame, size: Vector3, owner: Player): Model
	local model = Instance.new("Model")
	local core = part({ Name = "Core", Size = size, CFrame = cf, Color = WOOD:Lerp(Color3.new(0, 0, 0), 0.15), Material = Enum.Material.Wood })
	core.Parent = model
	local handle = part({
		Name = "Handle",
		Size = Vector3.new(0.3, 0.3, size.Z + 0.4),
		CFrame = cf * CFrame.new(size.X / 2 - 0.6, 0, 0),
		Color = Color3.fromRGB(60, 45, 30),
		CanCollide = false,
	})
	handle.Parent = model
	model.PrimaryPart = core

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open"
	prompt.ObjectText = "Door"
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = core
	local open = false
	prompt.Triggered:Connect(function(who)
		if who.UserId ~= owner.UserId then
			Remotes.Notify:FireClient(who, "This door is locked.")
			return
		end
		open = not open
		core.CanCollide = not open
		core.Transparency = if open then 0.7 else 0
		prompt.ActionText = if open then "Close" else "Open"
	end)
	return model
end

function builders.Campfire(cf: CFrame, size: Vector3): Model
	local model = Instance.new("Model")
	local base = part({
		Name = "Core",
		Size = Vector3.new(size.X, 0.2, size.Z),
		CFrame = cf * CFrame.new(0, -size.Y / 2 + 0.1, 0),
		Transparency = 1,
		CanCollide = false,
	})
	base.Parent = model
	for i = 0, 7 do
		local angle = i / 8 * math.pi * 2
		local stone = part({
			Name = "Stone",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.9, 0.9, 0.9),
			CFrame = cf * CFrame.new(math.cos(angle) * 1.5, -size.Y / 2 + 0.4, math.sin(angle) * 1.5),
			Color = STONE,
			Material = Enum.Material.Slate,
		})
		stone.Parent = model
	end
	for i = 0, 2 do
		local log = part({
			Name = "Log",
			Size = Vector3.new(0.4, 0.4, 2.4),
			CFrame = cf * CFrame.new(0, -size.Y / 2 + 0.5, 0) * CFrame.Angles(0, i * math.pi / 3, math.rad(10)),
			Color = Color3.fromRGB(90, 62, 40),
			Material = Enum.Material.Wood,
		})
		log.Parent = model
	end
	local fire = Instance.new("Fire")
	fire.Size = 4
	fire.Heat = 6
	fire.Parent = base
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 170, 90)
	light.Range = 18
	light.Brightness = 2
	light.Parent = base
	model.PrimaryPart = base
	return model
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
	if not def or not builder then
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local pos = position :: Vector3
	if (pos - (root :: BasePart).Position).Magnitude > Config.BuildRange then
		Remotes.Notify:FireClient(player, "Too far away to build there.")
		return
	end

	local spawnPoint = workspace:FindFirstChild("TideboundSpawn")
	if spawnPoint and (pos - (spawnPoint :: BasePart).Position).Magnitude < Config.SpawnNoBuildRadius then
		Remotes.Notify:FireClient(player, "You can't build this close to the spawn.")
		return
	end

	-- Find the ground (or a structure) under the spot.
	local snapped = Structures.snap(pos)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = characterList()
	table.insert(exclude, workspace:WaitForChild("Nodes"))
	table.insert(exclude, workspace:WaitForChild("LootSacks"))
	params.FilterDescendantsInstances = exclude
	local hit = workspace:Raycast(Vector3.new(snapped.X, pos.Y + 4, snapped.Z), Vector3.new(0, -40, 0), params)
	if not hit then
		return
	end

	local rot = Structures.snapRotation(rotation :: number)
	local cf = CFrame.new(snapped.X, hit.Position.Y + def.size.Y / 2, snapped.Z) * CFrame.Angles(0, math.rad(rot), 0)

	-- Make sure nothing is in the way.
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Include
	overlap.FilterDescendantsInstances = { workspace.Structures, workspace.Nodes }
	local blocking = workspace:GetPartBoundsInBox(cf, def.size - Vector3.new(0.3, 0.3, 0.3), overlap)
	if #blocking > 0 then
		Remotes.Notify:FireClient(player, "Something is in the way.")
		return
	end

	if not Inventory.take(player, itemId, 1) then
		return
	end
	local model = builder(cf, def.size, player)
	model.Name = item.structure
	model:SetAttribute("StructureType", item.structure)
	model:SetAttribute("HP", def.hp)
	model:SetAttribute("MaxHP", def.hp)
	model:SetAttribute("OwnerId", player.UserId)
	model.Parent = workspace.Structures
	Quests.record(player, "build", nil, 1)
end

return Building
