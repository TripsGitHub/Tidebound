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

	-- Cook raw meat here.
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Cook meat"
	prompt.ObjectText = "Campfire"
	prompt.HoldDuration = 1.2
	prompt.MaxActivationDistance = 12
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

local function ownedCount(userId: number): number
	local n = 0
	for _, m in workspace.Structures:GetChildren() do
		if m:GetAttribute("OwnerId") == userId then
			n += 1
		end
	end
	return n
end

-- Builds the structure at cf, owned by userId. No checks: callers check first.
local function construct(ownerId: number, ownerPlayer: Player?, itemId: string, cf: CFrame, tiles: number, hp: number?): Model
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
	model.Parent = workspace.Structures
	return model
end

local function blocked(cf: CFrame, size: Vector3): boolean
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Include
	overlap.FilterDescendantsInstances = { workspace.Structures, workspace.Nodes }
	return #workspace:GetPartBoundsInBox(cf, size - Vector3.new(0.3, 0.3, 0.3), overlap) > 0
end

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
	if ownedCount(player.UserId) >= Config.MaxStructures then
		Remotes.Notify:FireClient(player, "Base is at its size limit (" .. Config.MaxStructures .. " pieces)", "warn")
		return
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
	if blocked(cf, size) then
		Remotes.Notify:FireClient(player, "Something is in the way", "warn")
		return
	end

	if not Inventory.take(player, itemId, cost) then
		return
	end
	construct(player.UserId, player, itemId, cf, n)
	Crafting.placed(player, itemId)
	Quests.record(player, "build", nil, 1)
end

-- Saving bases: every piece you own, as plain numbers, so it can be rebuilt on any
-- server when you come back.
function Building.export(player: Player): { any }
	local list = {}
	for _, m in workspace.Structures:GetChildren() do
		local itemId = m:GetAttribute("ItemId")
		if m:GetAttribute("OwnerId") == player.UserId and itemId and m:IsA("Model") and m.PrimaryPart then
			local cf = m.PrimaryPart.CFrame
			if Structures.isFloor(m:GetAttribute("StructureType")) or m:GetAttribute("StructureType") == "Campfire" then
				-- cores of floors/campfires are offset down from the build centre
				cf = cf * CFrame.new(0, if m:GetAttribute("StructureType") == "Campfire" then (Structures.sizeFor("Campfire").Y / 2 - 0.2) else 0.15, 0)
			end
			local _, ry = cf:ToOrientation()
			table.insert(list, {
				i = itemId,
				x = math.round(cf.X * 10) / 10,
				y = math.round(cf.Y * 10) / 10,
				z = math.round(cf.Z * 10) / 10,
				r = Structures.snapRotation(math.deg(ry)),
				n = m:GetAttribute("Tiles") or 1,
				hp = math.floor(m:GetAttribute("HP") or 0),
			})
			if #list >= Config.MaxStructures then
				break
			end
		end
	end
	return list
end

-- Rebuild a saved base. Pieces already standing (you came back to the same server)
-- or now blocked by something are skipped.
function Building.restore(player: Player, list: any)
	if type(list) ~= "table" then
		return
	end
	workspace:WaitForChild("Structures")
	local mine: { [string]: boolean } = {}
	for _, m in workspace.Structures:GetChildren() do
		if m:GetAttribute("OwnerId") == player.UserId and m:IsA("Model") and m.PrimaryPart then
			local p = m.PrimaryPart.Position
			mine[math.round(p.X) .. "," .. math.round(p.Z) .. "," .. tostring(m:GetAttribute("ItemId"))] = true
		end
	end
	local count = 0
	for _, e in list do
		if count >= Config.MaxStructures then
			break
		end
		local item = type(e) == "table" and Items[e.i]
		if item and item.kind == "placeable" and Structures[item.structure] and type(e.x) == "number" then
			local key = math.round(e.x) .. "," .. math.round(e.z) .. "," .. e.i
			local n = if Structures.isFloor(item.structure) then math.clamp(tonumber(e.n) or 1, 1, Structures.MAX_TILES) else 1
			local size = Structures.sizeFor(item.structure, n)
			local cf = CFrame.new(e.x, e.y, e.z) * CFrame.Angles(0, math.rad(tonumber(e.r) or 0), 0)
			if not mine[key] and not blocked(cf, size) then
				construct(player.UserId, player, e.i, cf, n, if (tonumber(e.hp) or 0) > 0 then e.hp else nil)
				count += 1
			end
		end
	end
end

return Building
