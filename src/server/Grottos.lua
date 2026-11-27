--!strict
-- Sunken grottos: big caves under the open sea floor, away from every island.
--
-- Each one starts as a hole in the sea bed ringed with glowing coral, with a column
-- of bubbles rising from it to the surface so you can spot it from a boat. A flooded
-- tunnel winds down from the hole and comes out into a dry cave (an air pocket under
-- the sea): crystals on the walls, coral on the floor, a stranger who lives there,
-- and the rare and end-game ores. The two deeper grottos are shut by Tide Seals:
-- coral-crusted rock that only a strong sword can crack (see Nodes.lua).
--
-- WorldBuilder calls Grottos.build once the sea floor is done, handing over its own
-- helpers so the caves look and work like the rest of the map.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Meshes = require(ReplicatedStorage:WaitForChild("Shared").Meshes)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Grottos = {}

local M = Enum.Material
local rng = Random.new(77031)

export type Helpers = {
	spawnNode: (Folder, string, Vector3) -> (),
	crystal: (Instance, Vector3, Color3, boolean?, Vector3?) -> (),
	makeSeal: (Folder, any) -> (),
	npcAvatar: (CFrame, string, number, { shirt: Color3, pants: Color3, skin: Color3 }) -> Model?,
}

-- What each grotto holds. seal: the Tide Seal kind on its tunnel (nil = open).
local KINDS = {
	{
		name = "Pearl Grotto",
		seal = nil,
		glow = Color3.fromRGB(120, 230, 255),
		ores = { { "DiamondCluster", 2 }, { "SunstoneVein", 2 }, { "FractiteCluster", 1 } },
		npc = { name = "Pearl Diver", level = 60, line = "Not many find their way down here. Mind your air on the way back up.", shirt = Color3.fromRGB(60, 120, 150), pants = Color3.fromRGB(50, 60, 80), skin = Color3.fromRGB(196, 150, 112) },
	},
	{
		name = "Drowned Hollow",
		seal = "tide",
		glow = Color3.fromRGB(150, 255, 200),
		ores = { { "FractiteCluster", 2 }, { "AmethystGeode", 1 }, { "DiamondCluster", 2 } },
		npc = { name = "Drowned Hermit", level = 120, line = "The tide sealed this place long ago. You cracked it. Interesting...", shirt = Color3.fromRGB(70, 96, 80), pants = Color3.fromRGB(56, 50, 44), skin = Color3.fromRGB(160, 176, 160) },
	},
	{
		name = "Abyssal Vault",
		seal = "abyss",
		glow = Color3.fromRGB(190, 120, 255),
		ores = { { "ObsidianSpire", 2 }, { "MoonstoneCluster", 1 }, { "AmethystGeode", 2 } },
		npc = { name = "Vault Keeper", level = 250, line = "Few have the steel for the Abyss Seal. What lies deeper is not ready for you yet.", shirt = Color3.fromRGB(40, 30, 60), pants = Color3.fromRGB(30, 26, 40), skin = Color3.fromRGB(120, 110, 150) },
	},
}

local CHAMBER_R = 34
local TUNNEL_R = 7

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { Workspace.Terrain }
params.IgnoreWater = true

local function floorAt(x: number, z: number): number?
	local hit = Workspace:Raycast(Vector3.new(x, -2, z), Vector3.new(0, -260, 0), params)
	return hit and hit.Position.Y
end

-- Open sea, far from every island and every cave below.
local function pickSites(islands: { any }, avoid: { Vector3 }, count: number, extent: number): { Vector3 }
	local sites = {}
	local function clear(x: number, z: number): number
		local best = math.huge
		for _, isl in islands do
			best = math.min(best, math.sqrt((x - isl.x) ^ 2 + (z - isl.z) ^ 2) - isl.r)
		end
		for _, p in avoid do
			best = math.min(best, math.sqrt((x - p.X) ^ 2 + (z - p.Z) ^ 2) - 40)
		end
		for _, s in sites do
			best = math.min(best, (math.sqrt((x - s.X) ^ 2 + (z - s.Z) ^ 2) - 900) * 0.5)
		end
		return best
	end
	for _ = 1, count do
		local best, bx, bz = -math.huge, 0, 0
		for _ = 1, 600 do
			local a, d = rng:NextNumber(0, math.pi * 2), math.sqrt(rng:NextNumber()) * extent
			local x, z = math.cos(a) * d, math.sin(a) * d
			local c = clear(x, z)
			if c > best then
				best, bx, bz = c, x, z
			end
		end
		local y = floorAt(bx, bz)
		if y and best > 160 then
			table.insert(sites, Vector3.new(bx, y, bz))
		end
	end
	return sites
end

local function meshProp(parent: Instance, name: string, at: Vector3, scale: number, color: Color3?)
	local m = Meshes.has(name) and Meshes.build(name, { scale = scale })
	if not m then
		return
	end
	m:PivotTo(CFrame.new(at - Vector3.new(0, 0.3 * scale, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	if color then
		for _, p in m:GetDescendants() do
			if p:IsA("BasePart") and p.Material == M.Neon then
				p.Color = color
			end
		end
	end
	m.Parent = parent
end

local function bubbles(parent: Instance, at: Vector3, height: number)
	local column = Instance.new("Part")
	column.Name = "BubbleColumn"
	column.Anchored, column.CanCollide, column.CanQuery, column.CanTouch = true, false, false, false
	column.Transparency = 1
	column.Size = Vector3.new(6, 2, 6)
	column.CFrame = CFrame.new(at)
	column.Parent = parent
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(220, 250, 255))
	e.LightEmission = 0.6
	e.Size = NumberSequence.new(0.3, 0.7)
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.9, 0.4), NumberSequenceKeypoint.new(1, 1) })
	e.Speed = NumberRange.new(10, 14)
	e.Lifetime = NumberRange.new(height / 14, height / 10)
	e.Rate = 30
	e.SpreadAngle = Vector2.new(6, 6)
	e.EmissionDirection = Enum.NormalId.Top
	e.Parent = column
end

local function build(site: Vector3, kind, folder: Folder, nodes: Folder, helpers: Helpers)
	local terrain = require(script.Parent.WorldBake).terrain
	local model = Instance.new("Model")
	model.Name = kind.name
	model:SetAttribute("Grotto", true)
	model.Parent = folder

	-- The cave sits beside and below the hole, so the tunnel slopes down into it.
	local a = rng:NextNumber(0, math.pi * 2)
	local side = Vector3.new(math.cos(a), 0, math.sin(a))
	local centre = site + side * 70 - Vector3.new(0, 62, 0)
	local floorY = centre.Y - CHAMBER_R * 0.55
	local mouth = centre - side * (CHAMBER_R * 0.85) + Vector3.new(0, floorY + 7 - centre.Y, 0)
	local path = {
		site + Vector3.new(0, 4, 0),
		site - Vector3.new(0, 22, 0),
		site + side * 22 - Vector3.new(0, 44, 0),
		mouth - side * 6,
		mouth + side * 4,
	}
	local pts = {}
	for i = 1, #path - 1 do
		local p, q = path[i], path[i + 1]
		local n = math.max(1, math.ceil((q - p).Magnitude / 3))
		for s = 0, n - 1 do
			table.insert(pts, p:Lerp(q, s / n))
		end
	end
	table.insert(pts, path[#path])

	-- Solid rock round everything first (the sand bed doesn't reach this deep), then
	-- the dry cave, then the flooded tunnel (cleared to air, then filled with water:
	-- water won't push into solid voxels).
	terrain:FillBall(centre, CHAMBER_R + 16, M.Rock)
	for _, p in pts do
		if p.Y < site.Y - TUNNEL_R - 8 then
			terrain:FillBall(p, TUNNEL_R + 7, M.Rock)
		end
	end
	terrain:FillBall(centre, CHAMBER_R, M.Air)
	for _ = 1, 3 do
		local la = rng:NextNumber(0, math.pi * 2)
		local lr = CHAMBER_R * rng:NextNumber(0.45, 0.6)
		terrain:FillBall(centre + Vector3.new(math.cos(la), 0.15, math.sin(la)) * CHAMBER_R * 0.6, lr, M.Air)
	end
	-- A flat floor across the bottom of the dome.
	terrain:FillCylinder(CFrame.new(centre.X, (centre.Y - CHAMBER_R - 18 + floorY) / 2, centre.Z), floorY - (centre.Y - CHAMBER_R - 18), CHAMBER_R + 10, M.Rock)
	terrain:FillCylinder(CFrame.new(centre.X, floorY - 1.5, centre.Z), 3, CHAMBER_R, M.Sand)
	for _, mat in { M.Air, M.Water } do
		for _, p in pts do
			if (p - centre).Magnitude > CHAMBER_R - 2 then
				terrain:FillBall(p, TUNNEL_R, mat)
			end
		end
	end

	task.wait(0.5) -- raycasts only see freshly written terrain a moment later

	-- The seal, a third of the way down the tunnel, in water.
	if kind.seal then
		local i = math.floor(#pts * 0.45)
		local dir = (pts[i + 2] - pts[i]).Unit
		helpers.makeSeal(nodes, { pos = pts[i], dir = dir, r = TUNNEL_R, kind = kind.seal, water = true })
	end

	-- Outside: a ring of glowing coral round the hole and bubbles up to the surface.
	for k = 0, 9 do
		local ang = k / 10 * math.pi * 2
		local at = site + Vector3.new(math.cos(ang), 0, math.sin(ang)) * (TUNNEL_R + 5)
		local y = floorAt(at.X, at.Z)
		if y then
			meshProp(model, if k % 2 == 0 then "coral_tube" else "coral_branch", Vector3.new(at.X, y, at.Z), rng:NextNumber(1.6, 2.4), kind.glow)
		end
	end
	local marker = Instance.new("PointLight")
	bubbles(model, site + Vector3.new(0, 2, 0), -site.Y)
	marker.Color, marker.Range, marker.Brightness = kind.glow, 40, 2
	marker.Parent = model:FindFirstChild("BubbleColumn")

	-- Inside: crystals over the walls and roof, coral and sea plants on the floor.
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = model
	for _ = 1, 26 do
		local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.2, 1), rng:NextNumber(-1, 1)).Unit
		local hit = Workspace:Raycast(centre, dir * (CHAMBER_R + 20), params)
		if hit then
			helpers.crystal(decor, hit.Position, kind.glow, rng:NextNumber() < 0.4, hit.Normal)
		end
	end
	local REEF = { "coral_brain", "coral_yellow", "coral_fan", "sea_plant", "coral_tube" }
	for _ = 1, 18 do
		local ang, d = rng:NextNumber(0, math.pi * 2), math.sqrt(rng:NextNumber()) * CHAMBER_R * 0.85
		local x, z = centre.X + math.cos(ang) * d, centre.Z + math.sin(ang) * d
		if (Vector3.new(x, 0, z) - Vector3.new(mouth.X, 0, mouth.Z)).Magnitude > 12 then
			meshProp(decor, REEF[rng:NextInteger(1, #REEF)], Vector3.new(x, floorY, z), rng:NextNumber(1, 2), nil)
		end
	end
	local glow = Instance.new("Part")
	glow.Name = "Glow"
	glow.Anchored, glow.CanCollide, glow.CanQuery, glow.CanTouch = true, false, false, false
	glow.Transparency = 1
	glow.Size = Vector3.one
	glow.CFrame = CFrame.new(centre + Vector3.new(0, CHAMBER_R * 0.4, 0))
	glow.Parent = model
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness, light.Shadows = kind.glow:Lerp(Color3.new(1, 1, 1), 0.5), 50, 0.5, false
	light.Parent = glow

	-- The ores, spread across the floor away from the way in.
	for _, entry in kind.ores do
		local made = 0
		for _ = 1, 40 do
			if made >= entry[2] then
				break
			end
			local ang, d = rng:NextNumber(0, math.pi * 2), CHAMBER_R * rng:NextNumber(0.25, 0.75)
			local x, z = centre.X + math.cos(ang) * d, centre.Z + math.sin(ang) * d
			if (Vector3.new(x, 0, z) - Vector3.new(mouth.X, 0, mouth.Z)).Magnitude > 14 then
				helpers.spawnNode(nodes, entry[1], Vector3.new(x, floorY, z))
				made += 1
			end
		end
	end

	-- The stranger who lives here (a placeholder for now: one line of talk).
	local spot = centre + side * (CHAMBER_R * 0.55)
	local standAt = Vector3.new(spot.X, floorY, spot.Z)
	do
		local npc = helpers.npcAvatar(CFrame.lookAt(standAt, Vector3.new(mouth.X, floorY, mouth.Z)), kind.npc.name, kind.npc.level, kind.npc)
		if npc then
			npc.Parent = model
			local head = npc:FindFirstChild("Head") :: BasePart?
			if head then
				local prompt = Instance.new("ProximityPrompt")
				prompt.ActionText = "Talk"
				prompt.ObjectText = kind.npc.name
				prompt.MaxActivationDistance = 10
				prompt.RequiresLineOfSight = false
				prompt.Parent = head
				prompt.Triggered:Connect(function(player)
					Remotes.Notify:FireClient(player, kind.npc.name .. ": " .. kind.npc.line, "info")
				end)
			end
		end
	end

	model:SetAttribute("Entrance", site)
	model:SetAttribute("Centre", centre)
	return model
end

-- islands: WorldBuilder's island list. avoid: points of the cave network (tunnel
-- samples and chambers) to stay well clear of.
function Grottos.build(islands: { any }, avoid: { Vector3 }, nodes: Folder, helpers: Helpers, extent: number)
	local folder = Instance.new("Folder")
	folder.Name = "Grottos"
	folder.Parent = Workspace
	local sites = pickSites(islands, avoid, #KINDS, extent)
	local built = {}
	for i, site in sites do
		local ok, err = pcall(build, site, KINDS[i], folder, nodes, helpers)
		if ok then
			table.insert(built, string.format("%s (%d, %d, %d)", KINDS[i].name, site.X, site.Y, site.Z))
		else
			warn("[Grottos] " .. KINDS[i].name .. " failed: " .. tostring(err))
		end
		task.wait()
	end
	print("[Grottos] " .. table.concat(built, ", "))
	return folder
end

return Grottos
