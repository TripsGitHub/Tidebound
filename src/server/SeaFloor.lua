-- The open sea floor: deep, uneven and dressed, instead of one flat sand slab just
-- under the surface.
--
-- 1. WorldBuilder lays a thick sand bed under the whole sea (before the caves).
-- 2. After the caves are carved, this scoops smooth basins out of that bed with
--    overlapping water balls: shallow by the islands' sandy shelves, sloping to
--    about 135 studs deep in open water. Anywhere a cave runs below, the floor
--    stays well above the cave's roof so no tunnel is ever opened to the sea.
-- 3. Then it dresses the floor: rock outcrops and reefs, patches of gravel, mud
--    and pale sandstone, and props (coral, kelp, sea grass, shells, starfish).
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Meshes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Meshes"))

local SeaFloor = {}

local M = Enum.Material
local rgb = Color3.fromRGB

local SURFACE_FLOOR = -54 -- the top of the sand bed WorldBuilder lays
local DEEPEST = -135
local CELL = 32 -- grid for "is there a cave below here"

type Island = { x: number, z: number, r: number }

local function caveGrid(tunnels: { any }, chambers: { any }): { [number]: number }
	-- For each CELL column, the highest roof of any cave space within reach.
	local grid: { [number]: number } = {}
	local function mark(p: Vector3, r: number)
		local reach = r + 28
		local x0, x1 = math.floor((p.X - reach) / CELL), math.floor((p.X + reach) / CELL)
		local z0, z1 = math.floor((p.Z - reach) / CELL), math.floor((p.Z + reach) / CELL)
		local roof = p.Y + r
		for cx = x0, x1 do
			for cz = z0, z1 do
				local k = cx * 100003 + cz
				if not grid[k] or grid[k] < roof then
					grid[k] = roof
				end
			end
		end
	end
	for _, t in tunnels do
		local pts = t.points or t.pts
		if pts then
			for i = 1, #pts - 1 do
				local a, b = pts[i], pts[i + 1]
				local n = math.max(1, math.ceil((b - a).Magnitude / 12))
				for s = 0, n do
					mark(a:Lerp(b, s / n), t.r or 10)
				end
			end
			if #pts == 1 then
				mark(pts[1], t.r or 10)
			end
		end
	end
	for _, c in chambers do
		if c.pos then
			mark(c.pos, c.r or 20)
		end
	end
	return grid
end

local function roofAt(grid, x: number, z: number): number?
	return grid[math.floor(x / CELL) * 100003 + math.floor(z / CELL)]
end

-- Distance from (x, z) to the nearest island's outer sandy shelf.
local function shoreDistance(islands: { Island }, x: number, z: number): number
	local best = math.huge
	for _, isl in islands do
		local d = math.sqrt((x - isl.x) ^ 2 + (z - isl.z) ^ 2) - (isl.r + 70)
		if d < best then
			best = d
		end
	end
	return best
end

-- Ravines: long winding trenches across the open sea floor with rocky walls, where
-- the special resources are. They follow the zero lines of a broad noise field, so
-- they wind naturally, and a second noise breaks them into separate trenches.
local function ravineAt(x: number, z: number): number
	local gate = math.noise(x / 1300, z / 1300, 5.5)
	if gate < -0.05 then
		return 0
	end
	local n = math.noise(x / 760, z / 760, 11.3)
	local v = 1 - math.abs(n) * 15
	return math.clamp(v, 0, 1) * math.clamp((gate + 0.05) * 6, 0, 1)
end
SeaFloor.ravineAt = ravineAt

local function targetDepth(islands, grid, x: number, z: number): number?
	local shore = shoreDistance(islands, x, z)
	if shore < 0 then
		return nil
	end
	-- Slope away from the shelf into long, gentle dunes (no small bumps: the old
	-- floor's lumps and leftover pillars read as glitches).
	local depth = SURFACE_FLOOR - math.min(shore / 3.4, 64)
	depth += math.noise(x / 420, z / 420, 3.1) * 12 + math.noise(x / 160, z / 160, 7.7) * 3
	-- Ravines cut down another 30-45 studs, fading in from the shelf.
	local rv = ravineAt(x, z)
	if rv > 0 then
		depth -= (rv ^ 0.7) * 42 * math.clamp(shore / 220, 0, 1)
	end
	depth = math.max(depth, DEEPEST - 10)
	local roof = roofAt(grid, x, z)
	if roof then
		depth = math.max(depth, roof + 16)
	end
	if depth > SURFACE_FLOOR - 2 then
		return nil
	end
	return depth
end

local floorParams = RaycastParams.new()
floorParams.FilterType = Enum.RaycastFilterType.Include
floorParams.IgnoreWater = true
floorParams.FilterDescendantsInstances = { Workspace.Terrain }

-- Carve the floor as one smooth heightfield: every voxel of the sand bed above the
-- target depth turns to water, the top voxel keeps a partial fill so the surface is
-- smooth, and ravine walls turn to rock. Unlike scooping with balls, nothing is ever
-- left standing between two bowls.
local function scoop(terrain: Terrain, islands, grid, extent: number)
	local RES = 4
	local y0, y1 = DEEPEST - 16, SURFACE_FLOOR + 4
	local SLAB = 64 -- voxels per side per block
	local span = SLAB * RES
	local start = -math.ceil(extent / span) * span
	for bx = start, extent, span do
		for bz = start, extent, span do
			local region = Region3.new(Vector3.new(bx, y0, bz), Vector3.new(bx + span, y1, bz + span)):ExpandToGrid(RES)
			local mats, occ = terrain:ReadVoxels(region, RES)
			local size = mats.Size
			local lo = region.CFrame.Position - region.Size / 2
			local changed = false
			for i = 1, size.X do
				local wx = lo.X + (i - 0.5) * RES
				for k = 1, size.Z do
					local wz = lo.Z + (k - 0.5) * RES
					local depth = targetDepth(islands, grid, wx, wz)
					if depth then
						local rv = ravineAt(wx, wz)
						local wall = rv > 0.12 and rv < 0.85
						for j = 1, size.Y do
							local m = mats[i][j][k]
							if m == M.Sand or m == M.Water or m == M.Air then
								local vy = lo.Y + (j - 1) * RES
								local fill = math.clamp((depth - vy) / RES, 0, 1)
								if fill >= 1 then
									if wall and depth - vy < 10 then
										mats[i][j][k] = if (j + i + k) % 3 == 0 then M.Slate else M.Basalt
										changed = true
									end
								elseif fill > 0 then
									mats[i][j][k] = if wall then M.Basalt else M.Sand
									occ[i][j][k] = math.max(fill, 0.05)
									changed = true
								elseif m ~= M.Water then
									mats[i][j][k] = M.Water
									occ[i][j][k] = 1
									changed = true
								end
							end
						end
					end
				end
			end
			if changed then
				terrain:WriteVoxels(region, RES, mats, occ)
			end
			task.wait()
		end
	end
end


local function floorAt(x: number, z: number): RaycastResult?
	floorParams.FilterDescendantsInstances = { Workspace.Terrain }
	local hit = Workspace:Raycast(Vector3.new(x, SURFACE_FLOOR + 30, z), Vector3.new(0, -140, 0), floorParams)
	if hit and hit.Position.Y < SURFACE_FLOOR + 4 and (hit.Material == M.Sand or hit.Material == M.Salt or hit.Material == M.Ground or hit.Material == M.Mud or hit.Material == M.Sandstone or hit.Material == M.Rock or hit.Material == M.Slate or hit.Material == M.Limestone or hit.Material == M.Basalt) then
		return hit
	end
	return nil
end

local CORALS = { rgb(236, 98, 92), rgb(250, 160, 70), rgb(220, 110, 190), rgb(250, 214, 96), rgb(120, 190, 220), rgb(170, 110, 220) }

local function prop(parent: Instance, props): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = M.SmoothPlastic
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = parent
	return p
end

-- The Blender reef pieces (assets/models/blender/set4.py), when the place has them.
local REEF = { "coral_tube", "coral_brain", "coral_yellow", "coral_branch", "coral_fan", "sea_plant" }

local function meshProp(folder: Instance, name: string, at: Vector3, scale: number, rng: Random): boolean
	if not Meshes.has(name) then
		return false
	end
	local m = Meshes.build(name, { scale = scale, collide = false }) :: Model
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.CanQuery = false
			p.CastShadow = false
		end
	end
	-- Sunk a little so it never hovers over a slope.
	m:PivotTo(CFrame.new(at - Vector3.new(0, 0.3 * scale, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0))
	m.Parent = folder
	return true
end

-- A reef cluster: several coral pieces and sea plants packed together.
local function reef(folder: Instance, at: Vector3, rng: Random)
	for _ = 1, rng:NextInteger(3, 7) do
		local x, z = at.X + rng:NextNumber(-7, 7), at.Z + rng:NextNumber(-7, 7)
		local hit = floorAt(x, z)
		if hit then
			meshProp(folder, REEF[rng:NextInteger(1, #REEF)], hit.Position, rng:NextNumber(1.3, 2.8), rng)
		end
	end
end

local function coral(folder: Instance, at: Vector3, rng: Random)
	if Meshes.has("coral_tube") then
		reef(folder, at, rng)
		return
	end
	local m = Instance.new("Model")
	m.Name = "Coral"
	local colour = CORALS[rng:NextInteger(1, #CORALS)]
	local kind = rng:NextInteger(1, 3)
	if kind == 1 then -- branching: a few forked arms
		for _ = 1, rng:NextInteger(4, 7) do
			local h = rng:NextNumber(1.5, 4)
			local tilt = CFrame.Angles(rng:NextNumber(-0.6, 0.6), rng:NextNumber(0, 6.28), rng:NextNumber(-0.6, 0.6))
			local cf = CFrame.new(at) * tilt * CFrame.new(0, h / 2, 0)
			prop(m, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, 0.5, 0.5), CFrame = cf * CFrame.Angles(0, 0, math.pi / 2), Color = colour })
			prop(m, { Shape = Enum.PartType.Ball, Size = Vector3.one * 0.8, CFrame = cf * CFrame.new(0, h / 2, 0), Color = colour:Lerp(Color3.new(1, 1, 1), 0.25) })
		end
	elseif kind == 2 then -- brain coral: a squashed ball with a darker band
		local s = rng:NextNumber(2, 4.5)
		prop(m, { Shape = Enum.PartType.Ball, Size = Vector3.new(s, s * 0.6, s), CFrame = CFrame.new(at + Vector3.new(0, s * 0.2, 0)), Color = colour, Material = M.Fabric })
		prop(m, { Shape = Enum.PartType.Ball, Size = Vector3.new(s * 0.7, s * 0.45, s * 0.7), CFrame = CFrame.new(at + Vector3.new(s * 0.45, s * 0.1, 0)), Color = colour:Lerp(Color3.new(0, 0, 0), 0.2), Material = M.Fabric })
	else -- fan coral: a thin flat disc on a stalk
		local s = rng:NextNumber(2.5, 4.5)
		local yaw = CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
		prop(m, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15, s, s), CFrame = CFrame.new(at + Vector3.new(0, s * 0.5, 0)) * yaw, Color = colour, Transparency = 0.1 })
		prop(m, { Size = Vector3.new(0.3, s * 0.4, 0.3), CFrame = CFrame.new(at + Vector3.new(0, s * 0.15, 0)), Color = colour:Lerp(Color3.new(0, 0, 0), 0.3) })
	end
	m.Parent = folder
end

local function kelp(folder: Instance, at: Vector3, rng: Random)
	if Meshes.has("seaweed") then
		for _ = 1, rng:NextInteger(2, 5) do
			local x, z = at.X + rng:NextNumber(-3, 3), at.Z + rng:NextNumber(-3, 3)
			local hit = floorAt(x, z)
			if hit then
				meshProp(folder, "seaweed", hit.Position, rng:NextNumber(1.6, 3.6), rng)
			end
		end
		return
	end
	local m = Instance.new("Model")
	m.Name = "Kelp"
	local green = rgb(70, 120, 50):Lerp(rgb(120, 140, 50), rng:NextNumber())
	for _ = 1, rng:NextInteger(2, 4) do
		local base = at + Vector3.new(rng:NextNumber(-1.5, 1.5), 0, rng:NextNumber(-1.5, 1.5))
		local h = rng:NextNumber(10, 26)
		local segs = math.ceil(h / 4)
		local p = base
		local lean = Vector3.new(rng:NextNumber(-0.25, 0.25), 1, rng:NextNumber(-0.25, 0.25)).Unit
		for i = 1, segs do
			local wobble = Vector3.new(math.sin(i * 1.3) * 0.2, 0, math.cos(i * 1.1) * 0.2)
			local dir = (lean + wobble).Unit
			local q = p + dir * 4
			prop(m, { Size = Vector3.new(0.9, 4.2, 0.15), CFrame = CFrame.lookAt((p + q) / 2, q) * CFrame.Angles(math.pi / 2, 0, 0), Color = green, Material = M.Grass })
			p = q
		end
	end
	m.Parent = folder
end

local function seaGrass(folder: Instance, at: Vector3, rng: Random)
	local m = Instance.new("Model")
	m.Name = "SeaGrass"
	local green = rgb(90, 150, 70)
	for _ = 1, rng:NextInteger(6, 10) do
		local h = rng:NextNumber(1.2, 2.8)
		local o = Vector3.new(rng:NextNumber(-2, 2), h / 2, rng:NextNumber(-2, 2))
		prop(m, { Size = Vector3.new(0.3, h, 0.1), CFrame = CFrame.new(at + o) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6.28), rng:NextNumber(-0.3, 0.3)), Color = green })
	end
	m.Parent = folder
end

local function shell(folder: Instance, at: Vector3, rng: Random)
	if rng:NextNumber() < 0.5 then
		-- Starfish: five short arms.
		local m = Instance.new("Model")
		m.Name = "Starfish"
		local c = if rng:NextNumber() < 0.5 then rgb(236, 120, 70) else rgb(214, 80, 110)
		local yaw = rng:NextNumber(0, 6.28)
		for k = 0, 4 do
			local a = yaw + k * math.pi * 2 / 5
			prop(m, { Size = Vector3.new(0.45, 0.2, 1.1), CFrame = CFrame.new(at + Vector3.new(math.cos(a) * 0.5, 0.1, math.sin(a) * 0.5)) * CFrame.Angles(0, -a + math.pi / 2, 0), Color = c })
		end
		m.Parent = folder
	else
		prop(folder, { Name = "Shell", Shape = Enum.PartType.Ball, Size = Vector3.new(1.1, 0.5, 0.9), CFrame = CFrame.new(at + Vector3.new(0, 0.15, 0)), Color = rgb(246, 226, 200) })
	end
end

-- Schools of fish: the server places them; the client swims them round (Effects).
local FISH = { rgb(250, 170, 60), rgb(90, 180, 240), rgb(250, 230, 90), rgb(240, 110, 120), rgb(150, 230, 200) }
local function school(folder: Instance, at: Vector3, rng: Random)
	if not Meshes.has("fish") then
		return
	end
	local m = Instance.new("Model")
	m.Name = "FishSchool"
	local colour = FISH[rng:NextInteger(1, #FISH)]
	local centre = at + Vector3.new(0, rng:NextNumber(5, 14), 0)
	m:SetAttribute("Centre", centre)
	m:SetAttribute("Radius", rng:NextNumber(6, 14))
	m:SetAttribute("Speed", rng:NextNumber(0.25, 0.6))
	local scale = rng:NextNumber(0.9, 1.8)
	for i = 1, rng:NextInteger(5, 11) do
		local f = Meshes.build("fish", { scale = scale, collide = false }) :: Model
		f.Name = "Fish"
		for _, p in f:GetDescendants() do
			if p:IsA("BasePart") then
				p.CanQuery = false
				p.CastShadow = false
				if p.Name == "Body" then
					p.Color = colour
				end
			end
		end
		f:SetAttribute("Offset", Vector3.new(rng:NextNumber(-3, 3), rng:NextNumber(-2, 2), rng:NextNumber(-3, 3)))
		f:SetAttribute("Phase", i * 0.35)
		f:PivotTo(CFrame.new(centre + f:GetAttribute("Offset")))
		f.Parent = m
	end
	m.Parent = folder
end

local function dress(terrain: Terrain, extent: number)
	local folder = Instance.new("Folder")
	folder.Name = "Seabed"
	folder.Parent = Workspace
	local rng = Random.new(777)
	local tries = math.floor((extent * 2 / 72) ^ 2)
	for i = 1, tries do
		local x, z = rng:NextNumber(-extent, extent), rng:NextNumber(-extent, extent)
		local hit = floorAt(x, z)
		if hit then
			local at = hit.Position
			local roll = rng:NextNumber()
			local deep = at.Y < -80
			if roll < 0.06 then
				-- Rock outcrop or reef: a few lumpy balls, half buried.
				local mat = ({ M.Rock, M.Slate, M.Limestone, M.Basalt })[rng:NextInteger(1, 4)]
				for _ = 1, rng:NextInteger(2, 5) do
					local r = rng:NextNumber(3, if deep then 11 else 7)
					terrain:FillBall(at + Vector3.new(rng:NextNumber(-6, 6), r * rng:NextNumber(-0.2, 0.3), rng:NextNumber(-6, 6)), r, mat)
				end
			elseif roll < 0.12 then
				-- A patch of different ground: gravel, mud or pale sandstone.
				local mat = ({ M.Ground, M.Mud, M.Sandstone, M.Slate })[rng:NextInteger(1, 4)]
				local r = rng:NextNumber(8, 18)
				terrain:FillBall(at - Vector3.new(0, r * 0.85, 0), r, mat)
			elseif roll < 0.3 then
				coral(folder, at, rng)
			elseif roll < 0.55 then
				kelp(folder, at, rng)
				if rng:NextNumber() < 0.5 then
					kelp(folder, at + Vector3.new(rng:NextNumber(-6, 6), 0, rng:NextNumber(-6, 6)), rng)
				end
			elseif roll < 0.82 then
				seaGrass(folder, at, rng)
				seaGrass(folder, at + Vector3.new(rng:NextNumber(-5, 5), 0, rng:NextNumber(-5, 5)), rng)
			elseif roll < 0.92 then
				shell(folder, at, rng)
			else
				school(folder, at, rng)
			end
		end
		if i % 150 == 0 then
			task.wait()
		end
	end
end

-- Spots along the ravine floors for the special resources (run after the floor is
-- there, baked or freshly carved). Returns floor positions.
function SeaFloor.ravineSpots(islands: { Island }, count: number): { Vector3 }
	local extent = 0
	for _, isl in islands do
		extent = math.max(extent, math.abs(isl.x) + isl.r, math.abs(isl.z) + isl.r)
	end
	local rng = Random.new(9090)
	local out = {}
	for _ = 1, count * 40 do
		if #out >= count then
			break
		end
		local x, z = rng:NextNumber(-extent, extent), rng:NextNumber(-extent, extent)
		if ravineAt(x, z) > 0.85 and shoreDistance(islands, x, z) > 160 then
			local hit = floorAt(x, z)
			if hit and hit.Position.Y < SURFACE_FLOOR - 30 then
				local ok = true
				for _, p in out do
					if (p - hit.Position).Magnitude < 60 then
						ok = false
						break
					end
				end
				if ok then
					table.insert(out, hit.Position)
				end
			end
		end
	end
	return out
end

function SeaFloor.build(islands: { Island }, tunnels: { any }, chambers: { any })
	local terrain = require(script.Parent.WorldBake).terrain
	local extent = 0
	for _, isl in islands do
		extent = math.max(extent, math.abs(isl.x) + isl.r, math.abs(isl.z) + isl.r)
	end
	extent += 500
	local grid = caveGrid(tunnels, chambers)
	if not require(script.Parent.WorldBake).baked then
		scoop(terrain, islands, grid, extent) -- (terrain only: already in a baked map)
	end
	dress(terrain, extent)
end

return SeaFloor
