-- The cave network under the whole map.
--
-- Every island has a cave mouth (a ring of pale fang rocks). From it a wide hall
-- spirals down under the island through two chambers:
--   Upper Chamber  about 32 studs down   torch-lit, Silver and Gold
--   Lower Chamber  about 64 studs down   Gold and Sunstone, the first crystals
-- and then drops to the island's Root Cavern in the Deep Network, about 100 studs
-- down, far below the sea floor. Long halls link every island's roots, with big
-- caverns where they meet and halfway between islands.
--
-- The halls are wide (built for a tribe, not one player) and the best ore is never on
-- the main way. Side branches wander off the halls: most are dead ends, some squeeze
-- down to a crawlway that opens into a small pocket with rare ore (Diamond in the
-- lower caves; Fractite and Amethyst only deep down), and a few hide a sealed-looking
-- secret room, kept empty for traders and events later.
--
-- Ways out besides the fang mouths:
--   * a second exit on every island, coming up inside its landmark (WorldBuilder
--     builds the landmark round the hole);
--   * ravines in the sea floor halfway between islands: a hall climbs from the deep
--     cavern into a flooded trench, and you swim up to the open sea.
--
-- Carved after the islands are written. A tunnel is a chain of air balls wrapped in a
-- shell of rock wherever it runs below the islands (so the sea never leaks in and the
-- deep tunnels have walls). Shapes come from a fixed seed, so the map is the same every
-- time.
local Caves = {}

local M = Enum.Material
local rng = Random.new(4242)

local HALL_R = 11 -- main halls: 22 studs tall, room for a tribe to fight in
local BRANCH_R = 7 -- side branches
local CRAWL_R = 4.5 -- the squeeze into a rare-ore pocket
local STEP = 3 -- distance between carved balls
local UPPER_Y, LOWER_Y, DEEP_Y = -32, -64, -100
local SEA_FLOOR = -60 -- the sand layer's middle (WorldBuilder: -40 * V)
Caves.HALL_R = HALL_R
Caves.SHALLOW_Y = -45 -- above this caves are torch-lit; below it the crystals start

export type Tunnel = { points: { Vector3 }, r: number, kind: string, flooded: number? }
export type Chamber = { pos: Vector3, r: number, tier: string }
export type Result = {
	chambers: { Chamber },
	paths: { { Vector3 } },
	tunnels: { Tunnel },
	entrances: { { pos: Vector3, facing: Vector3 } },
	exits: { { pos: Vector3, island: number, biome: string } },
	pockets: { { pos: Vector3, tier: string } },
	secretRooms: { { pos: Vector3, size: Vector3, facing: Vector3 } },
	ravines: { { a: Vector3, b: Vector3 } },
	spoke: { Vector3 }?,
}

local function tierAt(y: number): string
	if y > Caves.SHALLOW_Y then
		return "upper"
	elseif y > -80 then
		return "lower"
	end
	return "deep"
end
Caves.tierAt = tierAt

-- Rock round a tunnel wherever it's underground, so it has walls under the sea and
-- never opens into the water beside an island.
local function shell(terrain: Terrain, p: Vector3, r: number)
	if p.Y + r + 6 > -2 then
		return -- up here it's inside the island already
	end
	local pad = Vector3.one * (r + 6)
	local region = Region3.new(p - pad, p + pad):ExpandToGrid(4)
	terrain:ReplaceMaterial(region, 4, M.Air, M.Rock)
	terrain:ReplaceMaterial(region, 4, M.Water, M.Rock)
end

local function samples(points: { Vector3 }): { Vector3 }
	local out = {}
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local n = math.max(1, math.ceil((b - a).Magnitude / STEP))
		for s = 0, n - 1 do
			table.insert(out, a:Lerp(b, s / n))
		end
	end
	if #points > 0 then
		table.insert(out, points[#points])
	end
	return out
end
Caves.samples = samples

-- A tunnel that spirals down around (cx, cz) from `fromY` to height `toY`, ending at
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

-- A long tunnel between two points, wandering a little so it isn't a straight pipe.
local function wander(a: Vector3, b: Vector3, sway: number?): { Vector3 }
	local pts = { a }
	local d = b - a
	local flat = Vector3.new(-d.Z, 0, d.X)
	local side = if flat.Magnitude > 0 then flat.Unit else Vector3.xAxis
	local n = math.max(2, math.floor(d.Magnitude / 60))
	local phase = rng:NextNumber(0, 6)
	local amp = sway or 30
	for i = 1, n - 1 do
		local t = i / n
		local off = math.sin(t * math.pi * 2 + phase) * amp + rng:NextNumber(-8, 8)
		table.insert(pts, a:Lerp(b, t) + side * off + Vector3.new(0, rng:NextNumber(-3, 3), 0))
	end
	table.insert(pts, b)
	return pts
end

local function yaw(v: Vector3, a: number): Vector3
	local c, s = math.cos(a), math.sin(a)
	return Vector3.new(v.X * c - v.Z * s, 0, v.X * s + v.Z * c)
end

-- A side branch: wanders off from `origin`, turning as it goes. Returns its points.
local function crooked(origin: Vector3, heading: Vector3, length: number, minY: number, maxY: number): { Vector3 }
	local pts = { origin }
	local p, h = origin, heading
	for _ = 1, math.max(2, math.ceil(length / 28)) do
		h = yaw(h, rng:NextNumber(-0.7, 0.7))
		p = p + h * 28 + Vector3.new(0, rng:NextNumber(-5, 4), 0)
		p = Vector3.new(p.X, math.clamp(p.Y, minY, maxY), p.Z)
		table.insert(pts, p)
	end
	return pts
end

-- islands: the scaled island list. groundAt(x, z) -> RaycastResult?
-- canEnter(isl, x, z) -> true if that spot is dry, open land for an entrance.
function Caves.build(terrain: Terrain, islands: { any }, groundAt: (number, number) -> RaycastResult?, canEnter: (any, number, number) -> boolean): Result
	local result: Result = { chambers = {}, paths = {}, tunnels = {}, entrances = {}, exits = {}, pockets = {}, secretRooms = {}, ravines = {}, spoke = nil }
	local roots = {}
	local halls = {} -- main halls branches can grow from: { points, depth range }

	local function add(points: { Vector3 }, r: number, kind: string, flooded: number?)
		table.insert(result.tunnels, { points = points, r = r, kind = kind, flooded = flooded })
		table.insert(result.paths, points)
	end
	local function chamber(pos: Vector3, r: number, tier: string)
		table.insert(result.chambers, { pos = pos, r = r, tier = tier })
	end

	-- A dry, flat, enterable spot on an island between `d0` and `d1` of its radius.
	local function spotOn(isl, d0: number, d1: number, avoid: Vector3?, gap: number?): (Vector3?, number?)
		for _ = 1, 80 do
			local a = rng:NextNumber(0, math.pi * 2)
			local d = isl.r * rng:NextNumber(d0, d1)
			local x, z = isl.x + math.cos(a) * d, isl.z + math.sin(a) * d
			local hit = groundAt(x, z)
			if
				hit
				and hit.Position.Y > 5
				and hit.Normal.Y > 0.85
				and hit.Material ~= M.Water
				and canEnter(isl, x, z)
				and (avoid == nil or (Vector3.new(x, 0, z) - Vector3.new(avoid.X, 0, avoid.Z)).Magnitude > (gap or 0))
			then
				return hit.Position, a
			end
		end
		return nil, nil
	end

	for index, isl in islands do
		local cx, cz = isl.x, isl.z
		local root = Vector3.new(cx, DEEP_Y, cz)
		local entrance, angle = spotOn(isl, 0.3, 0.55)
		if entrance and angle then
			local radius = math.max(60, (Vector3.new(entrance.X, 0, entrance.Z) - Vector3.new(cx, 0, cz)).Magnitude)
			-- Down into the hill from the mouth, then spiral.
			local path = { entrance + Vector3.new(0, 4, 0) }
			local s1, a1 = spiral(cx, cz, radius, angle, entrance.Y - 2, UPPER_Y)
			table.move(s1, 1, #s1, #path + 1, path)
			local upper = path[#path]
			add(path, HALL_R, "hall")
			table.insert(halls, path)
			chamber(upper - Vector3.new(0, HALL_R * 0.6, 0), 24, "upper")

			local s2, a2 = spiral(cx, cz, radius * 0.75, a1 + 0.6, UPPER_Y, LOWER_Y)
			table.insert(s2, 1, upper)
			add(s2, HALL_R, "hall")
			table.insert(halls, s2)
			local lower = s2[#s2]
			chamber(lower - Vector3.new(0, HALL_R * 0.6, 0), 30, "lower")

			local s3 = spiral(cx, cz, radius * 0.45, a2 + 0.6, LOWER_Y, DEEP_Y + 8)
			table.insert(s3, 1, lower)
			table.insert(s3, root + Vector3.new(0, 8, 0))
			add(s3, HALL_R, "hall")
			table.insert(halls, s3)

			-- The mouth's fang ring has its gap on its left, so face it inwards: the gap
			-- then opens the way the spiral runs (anticlockwise round the island).
			local inward = Vector3.new(cx - entrance.X, 0, cz - entrance.Z)
			table.insert(result.entrances, { pos = entrance, facing = if inward.Magnitude > 0 then inward.Unit else Vector3.zAxis })

			-- The second way out, up into the island's landmark: a ramp from the upper
			-- chamber, no steeper than 1 up for 3 along.
			local upperFloor = upper - Vector3.new(0, HALL_R * 0.6, 0)
			for _ = 1, 3 do
				local spot = spotOn(isl, 0.12, 0.5, entrance, isl.r * 0.45)
				if spot then
					local run = (Vector3.new(spot.X, 0, spot.Z) - Vector3.new(upperFloor.X, 0, upperFloor.Z)).Magnitude
					if run > (spot.Y - upperFloor.Y) * 3 then
						local ramp = wander(upperFloor + Vector3.new(0, HALL_R * 0.6, 0), spot + Vector3.new(0, 3, 0), 12)
						add(ramp, BRANCH_R + 1, "exit")
						table.insert(result.exits, { pos = spot, island = index, biome = isl.biome })
						break
					end
				end
			end
		end
		-- The island's root cavern in the Deep Network.
		chamber(root, 44, "deep")
		roots[index] = root
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
		if i ~= middle and isl.ring ~= false then
			table.insert(ring, { i = i, a = math.atan2(isl.z, isl.x) })
		end
	end
	table.sort(ring, function(p, q)
		return p.a < q.a
	end)
	local links = {}
	for k, entry in ring do
		local nextEntry = ring[k % #ring + 1]
		table.insert(links, { a = roots[entry.i], b = roots[nextEntry.i], ring = true })
		if middle then
			table.insert(links, { a = roots[entry.i], b = roots[middle], ring = false })
		end
	end
	-- Islands left out of the ring (small outer isles) hang off their nearest root.
	for i, isl in islands do
		if i ~= middle and isl.ring == false then
			local best, bestD
			for j, other in islands do
				if j ~= i and other.ring ~= false then
					local d = (roots[j] - roots[i]).Magnitude
					if not bestD or d < bestD then
						best, bestD = j, d
					end
				end
			end
			if best then
				table.insert(links, { a = roots[i], b = roots[best], ring = false })
			end
		end
	end
	for _, link in links do
		local a, b = link.a + Vector3.new(0, 8, 0), link.b + Vector3.new(0, 8, 0)
		local path = wander(a, b)
		add(path, HALL_R, "hall")
		table.insert(halls, path)
		if middle and link.a == roots[1] and link.b == roots[middle] then
			result.spoke = path -- the first island's way to the middle one, for the self-test
		end
		-- A long cavern halfway along each hall: three overlapping domes, kept low so
		-- they stay under the sea floor.
		local mid = path[math.max(1, math.floor(#path / 2))]
		local floor = Vector3.new(mid.X, DEEP_Y - rng:NextNumber(4, 8), mid.Z)
		local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
		local along = if flat.Magnitude > 0 then flat.Unit else Vector3.xAxis
		for k = -1, 1 do
			chamber(floor + along * (k * 34), 26, "deep")
		end

		-- Ring halls run under open sea: a ravine in the sea floor above the cavern,
		-- with a flooded hall climbing up into it.
		if link.ring and (b - a).Magnitude > 900 then
			local side = Vector3.new(-along.Z, 0, along.X)
			local centre = Vector3.new(floor.X, SEA_FLOOR, floor.Z) + side * 70
			local ra, rb = centre - along * 120, centre + along * 120
			table.insert(result.ravines, { a = ra, b = rb })
			local bottom = centre + Vector3.new(0, -16, 0)
			local climb = wander(floor + Vector3.new(0, 8, 0), bottom, 10)
			add(climb, BRANCH_R + 2, "ravine", SEA_FLOOR - 22)
		end
	end

	-- Side branches off the halls: dead ends, crawlways into rare-ore pockets, and a
	-- few secret rooms.
	local secrets = 0
	for hi, hall in halls do
		local pts = samples(hall)
		local count = math.clamp(math.floor(#pts * STEP / 140), 1, 6)
		for _ = 1, count do
			local i = rng:NextInteger(math.max(2, math.floor(#pts * 0.1)), math.max(2, math.floor(#pts * 0.9)))
			local at = pts[i]
			local nxt = pts[math.min(i + 1, #pts)]
			local dir = Vector3.new(nxt.X - at.X, 0, nxt.Z - at.Z)
			if at.Y < -30 and dir.Magnitude > 0 then
				local side = Vector3.new(-dir.Z, 0, dir.X).Unit * (if rng:NextNumber() < 0.5 then 1 else -1)
				local heading = yaw(side, rng:NextNumber(-0.5, 0.5))
				local minY, maxY = math.max(DEEP_Y - 20, at.Y - 25), math.min(-34, at.Y + 12)
				local branch = crooked(at, heading, rng:NextNumber(70, 200), minY, maxY)
				add(branch, BRANCH_R, "branch")
				local tip = branch[#branch]
				local roll = rng:NextNumber()
				local tier = tierAt(tip.Y)
				if roll < 0.12 and secrets < 10 and tier ~= "upper" then
					-- A secret room behind a squeeze: flat floor, square walls.
					local last = branch[#branch - 1] or at
					local face = Vector3.new(tip.X - last.X, 0, tip.Z - last.Z)
					face = if face.Magnitude > 0 then face.Unit else Vector3.xAxis
					local door = tip + face * 18
					add({ tip, door }, CRAWL_R, "crawl")
					local size = Vector3.new(rng:NextInteger(28, 40), 16, rng:NextInteger(28, 40))
					local roomPos = door + face * (size.X / 2 + 2) + Vector3.new(0, size.Y / 2 - CRAWL_R, 0)
					table.insert(result.secretRooms, { pos = roomPos, size = size, facing = face })
					secrets += 1
				elseif roll < 0.5 and tier ~= "upper" then
					-- A crawlway into a small pocket of rare ore.
					local crawl = crooked(tip, yaw(heading, rng:NextNumber(-0.9, 0.9)), rng:NextNumber(30, 60), minY - 8, maxY)
					add(crawl, CRAWL_R, "crawl")
					local pocket = crawl[#crawl] - Vector3.new(0, CRAWL_R * 0.4, 0)
					chamber(pocket, 11, "pocket")
					table.insert(result.pockets, { pos = pocket, tier = tierAt(pocket.Y) })
				elseif roll < 0.62 then
					-- Splits once, both ends dead.
					local fork = crooked(branch[math.max(2, #branch - 2)], yaw(heading, rng:NextNumber(0.8, 1.4)), rng:NextNumber(40, 90), minY, maxY)
					add(fork, BRANCH_R - 1, "branch")
				end
				-- else: just a dead end
			end
		end
		if hi % 3 == 0 then
			task.wait()
		end
	end

	Caves.carveAll(terrain, result)
	return result
end

-- Carves everything at once, in an order where nothing undoes anything else:
-- 1. rock shells round every deep tunnel, chamber, room and ravine, 2. hollow the
-- chambers, 3. lay their flat floors, 4. bore every tunnel (through those floors
-- where a tunnel leads on), 5. the secret rooms, 6. flood the ravines and the halls
-- climbing into them.
function Caves.carveAll(terrain: Terrain, result: Result)
	local all = {}
	for _, t in result.tunnels do
		table.insert(all, { pts = samples(t.points), r = t.r, flooded = t.flooded })
	end
	for n, t in all do
		for _, p in t.pts do
			shell(terrain, p, t.r)
		end
		if n % 4 == 0 then
			task.wait()
		end
	end
	for _, c in result.chambers do
		shell(terrain, c.pos + Vector3.new(0, c.r * 0.45, 0), c.r)
	end
	for _, room in result.secretRooms do
		local pad = room.size / 2 + Vector3.one * 6
		local region = Region3.new(room.pos - pad, room.pos + pad):ExpandToGrid(4)
		terrain:ReplaceMaterial(region, 4, M.Air, M.Rock)
		terrain:ReplaceMaterial(region, 4, M.Water, M.Rock)
	end
	local ravineBalls = {}
	for _, rv in result.ravines do
		for _, p in samples({ rv.a, rv.b }) do
			local wobble = math.sin(p.X * 0.05 + p.Z * 0.03) * 6
			local q = p + Vector3.new(0, -8 + wobble * 0.3, 0)
			table.insert(ravineBalls, q)
			local pad = Vector3.new(20, 26, 20)
			terrain:ReplaceMaterial(Region3.new(q - pad, q + Vector3.new(20, 0, 20)):ExpandToGrid(4), 4, M.Air, M.Rock)
		end
	end
	task.wait()

	for _, c in result.chambers do
		terrain:FillBall(c.pos + Vector3.new(0, c.r * 0.45, 0), c.r, M.Air)
	end
	for _, c in result.chambers do
		terrain:FillCylinder(CFrame.new(c.pos - Vector3.new(0, 3, 0)), 6, c.r * 0.95, M.Rock)
	end
	for n, t in all do
		for _, p in t.pts do
			terrain:FillBall(p, t.r, M.Air)
		end
		if n % 4 == 0 then
			task.wait()
		end
	end
	for _, room in result.secretRooms do
		local cf = CFrame.lookAt(room.pos, room.pos + room.facing)
		terrain:FillBlock(cf, Vector3.new(room.size.Z, room.size.Y, room.size.X), M.Air)
		terrain:FillBlock(cf - Vector3.new(0, room.size.Y / 2 + 1, 0), Vector3.new(room.size.Z, 2, room.size.X), M.Slate)
	end

	-- The ravines are open to the sea: a jagged trench, water from the trench floor up.
	for _, q in ravineBalls do
		terrain:FillBall(q, 16, M.Water)
	end
	for _, t in all do
		if t.flooded then
			for _, p in t.pts do
				if p.Y + t.r > t.flooded then
					terrain:FillBall(p, t.r, M.Water)
				end
			end
		end
	end
end

-- Studio self-test: checks every tunnel's centre line is open (air, or water in the
-- flooded ravine climbs). PathfindingService isn't used: it reports false blocks in
-- deep terrain caves that walk fine.
function Caves.verify(terrain: Terrain, result: Result)
	local solid, total = 0, 0
	-- The walk from the first island's entrance down to its root and on to the
	-- middle island, as "x,y,z;..." so a test client (and /tp route) can walk it.
	local route = {}
	for i = 1, math.min(3, #result.paths) do
		for _, p in samples(result.paths[i]) do
			table.insert(route, p)
		end
	end
	for _, p in samples(result.spoke or {}) do
		table.insert(route, p)
	end
	local parts = {}
	for i = 1, #route, 4 do
		local p = route[i]
		table.insert(parts, string.format("%d,%d,%d", p.X, p.Y, p.Z))
	end
	workspace:SetAttribute("CaveRoute", table.concat(parts, ";"))
	for n, path in result.paths do
		for _, p in samples(path) do
			total += 1
			local region = Region3.new(p - Vector3.one * 2, p + Vector3.one * 2):ExpandToGrid(4)
			local mats, occ = terrain:ReadVoxels(region, 4)
			if mats[1][1][1] ~= M.Air and mats[1][1][1] ~= M.Water and occ[1][1][1] > 0.5 then
				solid += 1
			end
		end
		if n % 4 == 0 then
			task.wait()
		end
	end
	local summary = string.format(
		"solid samples %d of %d | %d tunnels, %d pockets, %d secret rooms, %d ravines, %d landmark exits",
		solid,
		total,
		#result.tunnels,
		#result.pockets,
		#result.secretRooms,
		#result.ravines,
		#result.exits
	)
	workspace:SetAttribute("CaveCheck", summary)
	print("[Caves] " .. summary)
end

return Caves
