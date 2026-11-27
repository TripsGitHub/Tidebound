-- The cave network under the whole map.
--
-- Every island has a cave entrance (a ring of pale fang rocks). From it a tunnel
-- spirals down under the island through two chambers:
--   Upper Chamber  about 25 studs down   Silver and Gold
--   Lower Chamber  about 60 studs down   Sunstone and Diamond
-- and then drops to the Deep Network, about 100 studs down, far below the sea floor:
-- long tunnels linking every island's roots, with big caverns where they meet and
-- halfway between islands. Only down there do you find Fractite and Amethyst.
-- So you can walk from any island to any other underground, but it's a long way.
--
-- Carved after the islands are written: a tunnel is a chain of air balls, wrapped in a
-- shell of rock wherever it runs below the islands (so the sea never leaks in and the
-- deep tunnels have walls). Shapes come from a fixed seed, so the map is the same
-- every time.
local Caves = {}

local M = Enum.Material
local rng = Random.new(4242)

local TUNNEL_R = 7 -- tunnel radius (studs): 14 tall, room to fight in
local STEP = 3 -- distance between carved balls
local UPPER_Y, LOWER_Y, DEEP_Y = -25, -60, -100

export type Chamber = { pos: Vector3, r: number, tier: string }
export type Result = {
	chambers: { Chamber },
	paths: { { Vector3 } },
	entrances: { { pos: Vector3, facing: Vector3 } },
}

-- Rock around the tunnel wherever it's deep, so it has walls under the sea.
local function shell(terrain: Terrain, p: Vector3, r: number)
	if p.Y > -40 then
		return -- up here it's inside the island already
	end
	local pad = Vector3.one * (r + 6)
	terrain:ReplaceMaterial(Region3.new(p - pad, p + pad):ExpandToGrid(4), 4, M.Air, M.Rock)
end

local function carvePath(terrain: Terrain, points: { Vector3 })
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local n = math.max(1, math.ceil((b - a).Magnitude / STEP))
		for s = 0, n - 1 do
			shell(terrain, a:Lerp(b, s / n), TUNNEL_R)
		end
	end
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local n = math.max(1, math.ceil((b - a).Magnitude / STEP))
		for s = 0, n do
			terrain:FillBall(a:Lerp(b, s / n), TUNNEL_R, M.Air)
		end
	end
end

local function carveChamber(terrain: Terrain, floor: Vector3, r: number)
	local centre = floor + Vector3.new(0, r * 0.45, 0)
	shell(terrain, centre, r)
	terrain:FillBall(centre, r, M.Air)
	-- Flat floor.
	terrain:FillCylinder(CFrame.new(floor - Vector3.new(0, 3, 0)), 6, r * 0.95, M.Rock)
end

-- A tunnel that spirals down around (cx, cz) from `from` to height `toY`, ending at
-- angle `a1`. Gentle enough to walk: about 1 stud down for every 6 along.
local function spiral(cx: number, cz: number, radius: number, a0: number, fromY: number, toY: number): ({ Vector3 }, number)
	local pts = {}
	local drop = fromY - toY
	local length = drop * 6
	local turn = length / radius -- radians to go round
	local steps = math.max(4, math.ceil(turn / math.rad(15)))
	for i = 0, steps do
		local t = i / steps
		local a = a0 + turn * t
		local r = radius * (1 + math.sin(t * 7) * 0.08)
		table.insert(pts, Vector3.new(cx + math.cos(a) * r, fromY - drop * t, cz + math.sin(a) * r))
	end
	return pts, a0 + turn
end

-- A long deep tunnel between two points, wandering a little so it isn't a straight pipe.
local function wander(a: Vector3, b: Vector3): { Vector3 }
	local pts = { a }
	local d = b - a
	local side = Vector3.new(-d.Z, 0, d.X).Unit
	local n = math.max(2, math.floor(d.Magnitude / 60))
	local phase = rng:NextNumber(0, 6)
	for i = 1, n - 1 do
		local t = i / n
		local off = math.sin(t * math.pi * 2 + phase) * 30 + rng:NextNumber(-8, 8)
		local y = a.Y + (b.Y - a.Y) * t + rng:NextNumber(-4, 4)
		table.insert(pts, a:Lerp(b, t) + side * off + Vector3.new(0, y - (a.Y + (b.Y - a.Y) * t), 0))
	end
	table.insert(pts, b)
	return pts
end

-- islands: the scaled island list. groundAt(x, z) -> RaycastResult?
-- canEnter(isl, x, z) -> true if that spot is dry, open land for an entrance.
function Caves.build(terrain: Terrain, islands: { any }, groundAt: (number, number) -> RaycastResult?, canEnter: (any, number, number) -> boolean): Result
	local result: Result = { chambers = {}, paths = {}, entrances = {} }
	local roots = {}

	for index, isl in islands do
		-- Entrance: dry land partway in from the coast, on fairly flat ground.
		local entrance, angle
		for _ = 1, 60 do
			local a = rng:NextNumber(0, math.pi * 2)
			local d = isl.r * rng:NextNumber(0.3, 0.55)
			local x, z = isl.x + math.cos(a) * d, isl.z + math.sin(a) * d
			local hit = groundAt(x, z)
			if hit and hit.Position.Y > 5 and hit.Normal.Y > 0.85 and hit.Material ~= M.Water and canEnter(isl, x, z) then
				entrance, angle = hit.Position, a
				break
			end
		end
		local cx, cz = isl.x, isl.z
		local root = Vector3.new(cx, DEEP_Y, cz)
		if entrance then
			local radius = math.max(40, (Vector3.new(entrance.X, 0, entrance.Z) - Vector3.new(cx, 0, cz)).Magnitude)
			-- Straight down a short ramp into the hill, then spiral.
			local path = { entrance + Vector3.new(0, 2, 0) }
			local s1, a1 = spiral(cx, cz, radius, angle, entrance.Y - 1, UPPER_Y)
			table.move(s1, 1, #s1, #path + 1, path)
			local upper = path[#path]
			carvePath(terrain, path)
			table.insert(result.paths, path)
			carveChamber(terrain, upper - Vector3.new(0, TUNNEL_R * 0.6, 0), 18)
			table.insert(result.chambers, { pos = upper - Vector3.new(0, TUNNEL_R * 0.6, 0), r = 18, tier = "upper" })

			local s2, a2 = spiral(cx, cz, radius * 0.75, a1 + 0.6, UPPER_Y, LOWER_Y)
			table.insert(s2, 1, upper)
			carvePath(terrain, s2)
			table.insert(result.paths, s2)
			local lower = s2[#s2]
			carveChamber(terrain, lower - Vector3.new(0, TUNNEL_R * 0.6, 0), 20)
			table.insert(result.chambers, { pos = lower - Vector3.new(0, TUNNEL_R * 0.6, 0), r = 20, tier = "lower" })

			local s3 = spiral(cx, cz, radius * 0.45, a2 + 0.6, LOWER_Y, DEEP_Y + 6)
			table.insert(s3, 1, lower)
			table.insert(s3, root + Vector3.new(0, 6, 0))
			carvePath(terrain, s3)
			table.insert(result.paths, s3)

			local outward = Vector3.new(entrance.X - cx, 0, entrance.Z - cz)
			table.insert(result.entrances, { pos = entrance, facing = if outward.Magnitude > 0 then outward.Unit else Vector3.zAxis })
		end
		-- The island's root cavern in the Deep Network.
		carveChamber(terrain, root, 26)
		table.insert(result.chambers, { pos = root, r = 26, tier = "deep" })
		roots[index] = root
		task.wait()
	end

	-- Deep Network: the outer islands in a ring, and each one to the middle island.
	local middle
	for i, isl in islands do
		if isl.biome == "ember" then
			middle = i
		end
	end
	local ring = {}
	for i, isl in islands do
		if i ~= middle then
			table.insert(ring, { i = i, a = math.atan2(isl.z, isl.x) })
		end
	end
	table.sort(ring, function(p, q)
		return p.a < q.a
	end)
	local links = {}
	for k, entry in ring do
		local nextEntry = ring[k % #ring + 1]
		table.insert(links, { roots[entry.i], roots[nextEntry.i] })
		if middle then
			table.insert(links, { roots[entry.i], roots[middle] })
		end
	end
	for _, link in links do
		local a, b = link[1] + Vector3.new(0, 6, 0), link[2] + Vector3.new(0, 6, 0)
		local path = wander(a, b)
		carvePath(terrain, path)
		table.insert(result.paths, path)
		-- A cavern halfway along each long tunnel.
		local mid = path[math.max(1, math.floor(#path / 2))]
		local floor = Vector3.new(mid.X, DEEP_Y - rng:NextNumber(0, 8), mid.Z)
		carveChamber(terrain, floor, 30)
		table.insert(result.chambers, { pos = floor, r = 30, tier = "deep" })
		task.wait()
	end

	return result
end

return Caves
