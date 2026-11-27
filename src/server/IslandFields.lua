-- Hand-designed shapes for the five islands around Clover Island. Each island is a
-- height field plus a material rule, written into Smooth Terrain with WriteVoxels,
-- the same way as CloverIsland.lua. Coordinates are studs relative to the island
-- centre (x east, z south; north is -z). The preview renderer in
-- docs/previews/map/fields.py is a line-for-line copy of this file.
--
--   Pine Hills  (west)       crescent of wooded hills round a lagoon that opens east; two hill lakes. Wood.
--   Stone Shelf (east)       long ridge: stepped cliffs to the east sea, grass slope facing the middle,
--                            a cave into the ridge from a fang-rock mouth at the north end. Stone.
--   Frost Isle  (north-west) one snowy mountain, snow pines round its foot, a frozen pond on a shelf.
--   Slime Marsh (north-east) five low boggy islets on shallow flats you can wade across. Slime.
--   Ember Isle  (middle)     black volcano, lava crater, two lava streams, sea cliffs, one landing
--                            on the south side (facing Clover Island) with an ash terrace.
local IslandFields = {}

local sqrt, sin, cos, abs, floor, exp, atan2, pi = math.sqrt, math.sin, math.cos, math.abs, math.floor, math.exp, math.atan2, math.pi
local M = Enum.Material

local function hypot(a: number, b: number): number
	return sqrt(a * a + b * b)
end
local function smooth(a: number): number
	a = math.clamp(a, 0, 1)
	return a * a * (3 - 2 * a)
end
local function noise(x: number, z: number): number
	return sin(x * 0.071 + 1.3) * cos(z * 0.063 - 0.4) * 1.4
		+ sin(x * 0.153 - z * 0.121 + 2.1) * 0.7
		+ cos(x * 0.031 + z * 0.047) * 1.2
end
-- Sea shelf below 0, then sand rising to the grass line.
local function beach(l: number): number
	if l <= 0 then
		return math.max(-26, 1 + l * 60)
	end
	return 1.5 + smooth(l / 0.18) * 2.5
end
local function bump(x: number, z: number, cx: number, cz: number, r: number, h: number): number
	return h * exp(-((x - cx) ^ 2 + (z - cz) ^ 2) / (r * r))
end

-- Fine noise that breaks up straight material edges (-1..1).
local function grain(x: number, z: number): number
	return sin(x * 0.41 + z * 0.17) * 0.5 + sin(z * 0.37 - x * 0.23 + 1.7) * 0.5
end
-- Small bumps on the ground so slopes are not perfectly smooth (about -0.75..0.75).
local function detail(x: number, z: number): number
	return (sin(x * 0.29 + z * 0.11) * cos(z * 0.31 - x * 0.07) + sin(x * 0.53 - z * 0.47) * 0.5) * 0.5
end
-- Patches of the darker grass inside light grass, and the other way round.
local function grassy(x: number, z: number, base: Enum.Material): Enum.Material
	local n = noise(x * 0.6 + 90, z * 0.6)
	if base == Enum.Material.Grass then
		return if n > 1.3 then Enum.Material.Grass else Enum.Material.Grass
	end
	return if n < -1.3 then Enum.Material.Grass else Enum.Material.Grass
end


export type Field = {
	name: string,
	bounds: { number }, -- x0, x1, z0, z1
	ytop: number,
	land: (x: number, z: number) -> number,
	height: (x: number, z: number) -> number,
	zoneAt: (x: number, z: number) -> string,
	material: (x: number, z: number, h: number, slope: number) -> Enum.Material,
	canGrow: (x: number, z: number) -> boolean,
	water: ((x: number, y: number, z: number) -> Enum.Material?)?, -- lakes and ponds above sea level
	carve: ((x: number, y: number, z: number) -> boolean)?, -- caves
}

-- Pine Hills ---------------------------------------------------------------------------

local PH = {} :: any
PH.name = "Pine Hills"
PH.bounds = { -128, 128, -128, 128 }
PH.ytop = 40
function PH.land(x, z)
	local base = 1 - hypot(x, z) / 100 + noise(x * 1.5, z * 1.5) * 0.03
	local lag = 1 - hypot(x - 64, z + 4) / 54
	local l = base - math.max(0, lag) * 1.25
	return math.max(l, 1 - hypot(x - 60, z - 6) / 11) -- little islet in the lagoon
end
local PH_HILLS = { { -48, -30, 34, 13 }, { -20, 40, 30, 10 }, { -60, 30, 26, 9 }, { 5, -62, 26, 8 } }
local function phGround(x, z)
	local l = PH.land(x, z)
	local h = beach(l)
	if l <= 0 then
		return h
	end
	local inland = smooth((l - 0.12) / 0.45)
	h += inland * (2.5 + noise(x, z) * 1.6)
	for _, b in PH_HILLS do
		h += inland * bump(x, z, b[1], b[2], b[3], b[4])
	end
	return h + smooth(l / 0.2) * detail(x, z) * 0.7
end
local PH_POOLS = {}
for _, p in { { -36, -4, 12 }, { -30, 62, 9 } } do
	table.insert(PH_POOLS, { p[1], p[2], p[3], phGround(p[1], p[2]) - 0.6 })
end
function PH.height(x, z)
	local h = phGround(x, z)
	for _, p in PH_POOLS do
		local d = hypot(x - p[1], z - p[2])
		if d < p[3] then
			h = math.min(h, p[4] - (p[3] - d) * 0.5)
		end
	end
	return h
end
function PH.zoneAt(x, z)
	if x > 15 and PH.land(x, z) < 0.35 then
		return "shore"
	end
	if z + noise(x * 0.9, z * 0.9) * 6 > 18 then
		return "meadow"
	end
	return "forest"
end
function PH.material(x, z, h, slope)
	local l, g = PH.land(x, z), grain(x, z)
	if l <= 0.07 + g * 0.03 or h < 2.6 + g * 0.5 then
		return M.Sand
	end
	if slope > 0.9 + g * 0.15 then
		return M.Rock
	end
	if PH.zoneAt(x, z) == "meadow" then
		return grassy(x, z, M.Grass)
	end
	return grassy(x, z, M.Grass)
end
function PH.canGrow(x, z)
	if PH.land(x, z) <= 0.1 then
		return false
	end
	for _, p in PH_POOLS do
		if hypot(x - p[1], z - p[2]) <= p[3] + 3 then
			return false
		end
	end
	return true
end
function PH.water(x, y, z)
	for _, p in PH_POOLS do
		if y < p[4] and hypot(x - p[1], z - p[2]) < p[3] then
			return M.Water
		end
	end
	return nil
end

-- Stone Shelf --------------------------------------------------------------------------

local SS = {} :: any
SS.name = "Stone Shelf"
SS.bounds = { -110, 110, -132, 132 }
SS.ytop = 44
SS.caveMouth = Vector2.new(12, -86)
-- The cave: a tunnel from the mouth into a chamber under the ridge, then two ramps
-- winding down below sea level to the Deep Vault and, deepest of all, the Hollow.
-- Better ores are deeper (see WorldBuilder CAVE_NODES).
--   { x, z, floor } points joined by tunnels; floor = cave floor height (studs).
local TUNNELS = {
	{ { 12, -86, 3 }, { 10, -40, 3 } }, -- mouth to the first chamber
	{ { 10, -38, 3 }, { 18, -14, -6 }, { 4, 10, -14 } }, -- down to the Deep Vault
	{ { 4, 10, -14 }, { -14, 30, -24 }, { -6, 60, -32 } }, -- down to the Hollow
}
local TUNNEL_W, TUNNEL_H = 6, 10
--   Chambers: { x, z, radius, floor, height }
local CHAMBERS = {
	{ 10, -38, 15, 3, 14, name = "chamber" },
	{ 4, 10, 18, -14, 16, name = "vault" },
	{ -6, 60, 20, -32, 17, name = "hollow" },
}
SS.chambers = CHAMBERS
SS.tunnels = TUNNELS
local ROT = math.rad(12)
local function ssUV(x, z)
	return x * cos(ROT) - z * sin(ROT), x * sin(ROT) + z * cos(ROT)
end
function SS.land(x, z)
	local u, v = ssUV(x, z)
	return 1 - sqrt((u / 64) ^ 2 + (v / 108) ^ 2) + noise(x * 1.4, z * 1.4) * 0.03
end
local function ssRidge(x, z)
	local u, v = ssUV(x, z)
	return smooth((u + 18) / 34) * smooth((1 - abs(v) / 100) / 0.25)
end
function SS.height(x, z)
	local l = SS.land(x, z)
	local h = beach(l)
	if l <= 0 then
		return h
	end
	local inland = smooth((l - 0.1) / 0.4)
	h += inland * (2 + noise(x, z) * 1.3)
	local w = ssRidge(x, z) * smooth((l - 0.06) / 0.3)
	if w > 0 then
		local hr = h + w * 30 + noise(x * 1.2, z * 1.2) * 2.5
		hr = 1.5 + floor((hr - 1.5 + grain(x, z) * 1.5) / 6) * 6 + ((hr - 1.5) % 6) * 0.45 -- rough ledges
		h += (hr - h) * math.min(1, w * 1.6)
	end
	return h + smooth(l / 0.2) * detail(x, z) * 0.7
end
function SS.carve(x, y, z)
	for _, path in TUNNELS do
		for i = 1, #path - 1 do
			local a, b = path[i], path[i + 1]
			local dx, dz = b[1] - a[1], b[2] - a[2]
			local t = math.clamp(((x - a[1]) * dx + (z - a[2]) * dz) / (dx * dx + dz * dz), 0, 1)
			local d = hypot(x - (a[1] + dx * t), z - (a[2] + dz * t))
			local w = TUNNEL_W + sin(t * 9 + i) * 1.2
			if d < w then
				local floor_ = a[3] + (b[3] - a[3]) * t
				if y >= floor_ and y < floor_ + TUNNEL_H * (1 - (d / w) ^ 2) then
					return true
				end
			end
		end
	end
	for _, c in CHAMBERS do
		local dc = hypot(x - c[1], z - c[2])
		if dc < c[3] and y >= c[4] and y < c[4] + c[5] * (1 - (dc / c[3]) ^ 2) then
			return true
		end
	end
	return false
end
function SS.zoneAt(x, z)
	if hypot(x - CHAMBERS[1][1], z - CHAMBERS[1][2]) < CHAMBERS[1][3] then
		return "cave"
	end
	return if ssRidge(x, z) > 0.45 then "cliffs" else "slope"
end
function SS.material(x, z, h, slope)
	local l, g = SS.land(x, z), grain(x, z)
	if l <= 0.06 + g * 0.03 or h < 2.6 + g * 0.5 then
		return M.Sand
	end
	if ssRidge(x, z) > 0.45 + g * 0.08 then
		return if slope > 0.7 + g * 0.15 then M.Slate else M.Rock
	end
	if slope > 0.9 + g * 0.15 then
		return M.Rock
	end
	return grassy(x, z, M.Grass)
end
function SS.canGrow(x, z)
	return SS.land(x, z) > 0.1 and hypot(x - SS.caveMouth.X, z - SS.caveMouth.Y) > 18
end

-- Frost Isle ---------------------------------------------------------------------------

local FI = {} :: any
FI.name = "Frost Isle"
FI.bounds = { -120, 124, -120, 124 }
FI.ytop = 60
local POND = { -30, 42, 13 }
function FI.land(x, z)
	local l = 1 - hypot(x, z) / 82 + noise(x * 1.1, z * 1.1) * 0.06
	return math.max(l, (1 - hypot(x - 62, z - 52) / 30) * 0.6)
end
local function fiGround(x, z)
	local l = FI.land(x, z)
	local h = beach(l)
	if l <= 0 then
		return h
	end
	local inland = smooth((l - 0.12) / 0.4)
	local d = hypot(x + 6, z + 10)
	h += inland * (2 + noise(x, z) * 2)
	h += inland * 40 * smooth(1 - d / 80) ^ 1.4
	h += inland * smooth(1 - d / 72) * abs(noise(x * 0.8, z * 0.8)) * 5
	return h + smooth(l / 0.2) * detail(x, z) * 0.7
end
local POND_LEVEL = fiGround(POND[1], POND[2])
function FI.height(x, z)
	local h = fiGround(x, z)
	local d = hypot(x - POND[1], z - POND[2])
	if d < POND[3] + 6 then
		h += (POND_LEVEL - h) * smooth((POND[3] + 6 - d) / 6) -- a flat shelf round the pond
	end
	return h
end
function FI.zoneAt(x, z)
	local h = fiGround(x, z)
	if h > 24 then
		return "peak"
	end
	if FI.land(x, z) < 0.18 then
		return "shore"
	end
	return "slopes"
end
function FI.material(x, z, h, slope)
	local l = FI.land(x, z)
	if hypot(x - POND[1], z - POND[2]) < POND[3] then
		return M.Glacier -- the frozen pond
	end
	local g = grain(x, z)
	if l <= 0.05 + g * 0.03 or h < 2.2 + g * 0.5 then
		return M.Sand
	end
	if slope > 1.5 + g * 0.2 and h > 8 then
		return M.Rock
	end
	return M.Snow
end
function FI.canGrow(x, z)
	return FI.land(x, z) > 0.1 and hypot(x - POND[1], z - POND[2]) > POND[3] + 4
end

-- Slime Marsh --------------------------------------------------------------------------

local SM = {} :: any
SM.name = "Slime Marsh"
SM.bounds = { -112, 112, -112, 112 }
SM.ytop = 24
local ISLETS = {
	{ 4, 6, 38, "heart" },
	{ -60, 24, 26, "west" },
	{ 52, 50, 24, "east" },
	{ 42, -56, 23, "north" },
	{ -44, -56, 19, "northwest" },
}
function SM.land(x, z)
	local best = -math.huge
	for _, i in ISLETS do
		best = math.max(best, 1 - hypot(x - i[1], z - i[2]) / i[3])
	end
	return best + noise(x * 1.9, z * 1.9) * 0.04
end
function SM.height(x, z)
	local l = SM.land(x, z)
	if l <= 0 then
		local flats = smooth((92 + noise(x * 0.8, z * 0.8) * 6 - hypot(x, z)) / 22) -- shallow flats inside the marsh
		return math.max(-26, 1 + l * 60) * (1 - flats) + math.max(-2.5, 1 + l * 14) * flats
	end
	return 1.2 + smooth(l / 0.25) * 1.8 + smooth((l - 0.2) / 0.5) * (1.2 + noise(x * 1.6, z * 1.6) * 0.9) + smooth(l / 0.2) * detail(x, z) * 0.35
end
function SM.zoneAt(x, z)
	local best, name = -9, "heart"
	for _, i in ISLETS do
		local v = 1 - hypot(x - i[1], z - i[2]) / i[3]
		if v > best then
			best, name = v, i[4]
		end
	end
	return name
end
function SM.material(x, z, h, slope)
	local l = SM.land(x, z)
	if l <= 0.05 + grain(x, z) * 0.03 then
		return M.Mud
	end
	if noise(x * 2.7 + 40, z * 2.7) > 1.1 then
		return M.Mud
	end
	if l < 0.14 then
		return M.Ground
	end
	return M.Grass
end
function SM.canGrow(x, z)
	return SM.land(x, z) > 0.12
end

-- Ember Isle ---------------------------------------------------------------------------

local EI = {} :: any
EI.name = "Ember Isle"
EI.bounds = { -150, 150, -150, 150 }
EI.ytop = 64
function EI.land(x, z)
	return 1 - hypot(x, z) / 112 + noise(x * 1.2, z * 1.2) * 0.04
end
local function eiLanding(x, z)
	local a = atan2(x, z) + noise(x * 0.5, z * 0.5) * 0.07 -- 0 = due south
	return smooth((0.55 - abs(a)) / 0.3)
end
EI.landing = eiLanding
function EI.height(x, z)
	local l = EI.land(x, z)
	local h = beach(l)
	if l <= 0 then
		return h
	end
	local d = hypot(x, z)
	local inland = smooth((l - 0.06) / 0.25)
	local cone = smooth(1 - d / 96) ^ 1.5 * 52
	h += inland * (cone + 3 + noise(x * 1.5, z * 1.5) * 1.5)
	h += (1 - eiLanding(x, z)) * smooth((l - 0.02) / 0.08) * 8 -- sea cliffs except at the landing
	h += smooth(l / 0.2) * detail(x, z) * 0.9
	if d < 22 then
		h = math.min(h, 40 + (d / 22) ^ 2 * 12) -- crater
	end
	local t = eiLanding(x, z) * smooth((d - 58) / 8) * smooth((92 - d) / 8) -- ash terrace
	if l > 0.1 then
		h += (6.5 - h) * t
	end
	return h
end
local STREAMS = { { pi, 0.25 }, { -pi / 2, 0.2 } } -- north, west
local function eiStream(x, z)
	local best = 0
	local a, d = atan2(x, z), hypot(x, z)
	if d <= 18 or d >= 88 then
		return 0
	end
	for _, s in STREAMS do
		local da = abs((a - s[1] - sin(d * 0.06) * s[2] + pi) % (2 * pi) - pi) * d
		best = math.max(best, 1 - da / (5 + d * 0.04))
	end
	return best
end
function EI.zoneAt(x, z)
	local d = hypot(x, z)
	if d < 24 then
		return "crater"
	end
	if eiLanding(x, z) > 0.5 and d > 60 and d < 90 then
		return "camp"
	end
	return "slopes"
end
function EI.material(x, z, h, slope)
	local d, l = hypot(x, z), EI.land(x, z)
	if d < 16 or eiStream(x, z) > 0 then
		return M.CrackedLava
	end
	local g = grain(x, z)
	if l <= 0.05 + g * 0.03 or h < 2.4 + g * 0.5 then
		return if eiLanding(x, z) < 0.5 then M.Basalt else M.Sand
	end
	if EI.zoneAt(x, z) == "camp" and noise(x * 1.8, z * 1.8) > 0.2 then
		return M.Ground
	end
	if slope > 0.8 + g * 0.15 then
		return M.Slate
	end
	return M.Basalt
end
function EI.canGrow(x, z)
	return EI.land(x, z) > 0.1 and eiStream(x, z) <= 0 and hypot(x, z) > 26
end

-- Rock outcrops in the grass and rocky stretches of coast (see Rugged.lua).
local Rugged = require(script.Parent.Rugged)
Rugged.apply(PH, { seed = 23, count = 7, rock = M.Rock, coast = true })
Rugged.apply(SS, { seed = 37, count = 8, rock = M.Rock, coast = true, avoid = { { 12, -86, 20 } }, coastMask = function(x, z)
	return smooth((hypot(x - 12, z + 86) - 28) / 16) -- keep the cave mouth clear
end })
Rugged.apply(FI, { seed = 41, count = 5, rock = M.Rock, coast = true, avoid = { { POND[1], POND[2], POND[3] + 8 } } })
Rugged.apply(SM, { seed = 53, count = 3, size = 0.6, rock = M.Slate, coast = false })
Rugged.apply(EI, { seed = 67, count = 6, rock = M.Slate, coast = true, coastMask = function(x, z)
	return 1 - eiLanding(x, z)
end })

-- Smaller islands, built from a recipe instead of drawn by hand ---------------------------
-- Each one is a blob of land with a wobbly coast, a few hills, and a palette:
--   r        radius at 1x            peak     height of its tallest hill
--   low/high the ground below and above half the peak height, cliff for steep slopes
--   atoll    a ring of land round a lagoon     mesa  flat-topped terraces
--   spires   tall rock needles poking up       seed  so each looks different
local function make(spec): Field
	local F = {} :: any
	F.name = spec.name
	local R = spec.r
	F.bounds = { -R * 1.4, R * 1.4, -R * 1.4, R * 1.4 }
	F.ytop = spec.peak + 14
	local seed = spec.seed
	local rand = Random.new(seed)
	local hills = {}
	for _ = 1, spec.hills or 3 do
		local a, d = rand:NextNumber(0, pi * 2), rand:NextNumber(0, R * 0.5)
		table.insert(hills, { cos(a) * d, sin(a) * d, R * rand:NextNumber(0.25, 0.45), spec.peak * rand:NextNumber(0.5, 1) })
	end
	local spires = {}
	for _ = 1, spec.spires or 0 do
		local a, d = rand:NextNumber(0, pi * 2), rand:NextNumber(R * 0.1, R * 0.7)
		table.insert(spires, { cos(a) * d, sin(a) * d, rand:NextNumber(3, 6), spec.peak * rand:NextNumber(0.9, 1.6) })
	end
	-- Ponds: round dips with water in them, somewhere inland.
	local ponds = {}
	for _ = 1, spec.ponds or 0 do
		local a, d = rand:NextNumber(0, pi * 2), rand:NextNumber(R * 0.15, R * 0.5)
		table.insert(ponds, { cos(a) * d, sin(a) * d, R * rand:NextNumber(0.08, 0.13) })
	end
	function F.land(x, z)
		local a = atan2(z, x)
		local wob = sin(a * 3 + seed) * 0.12 + sin(a * 5 + seed * 2.3) * 0.07 + noise(x * 1.3 + seed * 7, z * 1.3) * 0.04
		local l = 1 - hypot(x, z) / (R * (1 + wob))
		if spec.atoll then
			l = math.min(l, (hypot(x, z) - R * 0.55) / (R * 0.5))
		end
		return l
	end
	local function ground(x, z)
		local l = F.land(x, z)
		local h = beach(l)
		if l <= 0 then
			return h
		end
		local inland = smooth((l - 0.1) / 0.35)
		h += inland * (1.5 + noise(x, z) * 1.5)
		for _, b in hills do
			h += inland * bump(x, z, b[1], b[2], b[3], b[4])
		end
		if spec.mesa and h > 6 then
			local step = spec.peak / 3
			local t = h / step
			h = (floor(t) + smooth((t - floor(t) - 0.75) / 0.25)) * step -- flat terraces, steep risers
		end
		for _, sp in spires do
			local d = hypot(x - sp[1], z - sp[2])
			if d < sp[3] then
				h = math.max(h, sp[4] * smooth(1 - d / sp[3]) ^ 0.4)
			end
		end
		return h + smooth(l / 0.2) * detail(x, z) * 0.6
	end
	for _, pd in ponds do
		pd[4] = ground(pd[1], pd[2]) - 0.6 -- water level, just under the ground there
	end
	local function height(x, z)
		local h = ground(x, z)
		for _, pd in ponds do
			local d = hypot(x - pd[1], z - pd[2])
			if d < pd[3] + 5 then
				local bed = pd[4] - 3.5 * smooth(1 - d / pd[3])
				h = math.min(h, bed + smooth((d - pd[3]) / 5) * (h - bed))
			end
		end
		return h
	end
	F.height = height
	if #ponds > 0 then
		function F.water(x, y, z)
			for _, pd in ponds do
				if hypot(x - pd[1], z - pd[2]) < pd[3] + 1 and y < pd[4] then
					return M.Water
				end
			end
			return nil
		end
	end
	function F.zoneAt(x, z)
		if F.land(x, z) < 0.18 then
			return "shore"
		end
		if height(x, z) > spec.peak * 0.55 then
			return "peak"
		end
		return "inland"
	end
	function F.material(x, z, h, slope)
		local l = F.land(x, z)
		local g = grain(x, z)
		if l <= 0.06 + g * 0.03 or h < 2.2 + g * 0.5 then
			return spec.shore or M.Sand
		end
		if slope > 1.4 + g * 0.2 and h > 5 then
			return spec.cliff or M.Rock
		end
		local m = if h > spec.peak * 0.55 then spec.high or spec.low else spec.low
		if m == M.Grass or m == M.Grass then
			return grassy(x, z, m)
		end
		return m
	end
	function F.canGrow(x, z)
		if F.land(x, z) <= 0.1 then
			return false
		end
		for _, pd in ponds do
			if hypot(x - pd[1], z - pd[2]) < pd[3] + 3 then
				return false
			end
		end
		return true
	end
	F.ponds = ponds
	return F :: Field
end
IslandFields.make = make

IslandFields.cay = make({ name = "Driftwood Cay", r = 45, peak = 12, hills = 4, spires = 2, seed = 11, low = M.Sand, high = M.Grass, cliff = M.Rock })
IslandFields.atoll = make({ name = "Coral Atoll", r = 58, peak = 10, hills = 5, seed = 19, atoll = true, low = M.Grass, high = M.Grass })
IslandFields.crags = make({ name = "Silver Crags", r = 62, peak = 34, hills = 4, spires = 9, ponds = 1, seed = 29, low = M.Slate, high = M.Rock, cliff = M.Slate })
IslandFields.mesa = make({ name = "Gold Mesa", r = 64, peak = 30, hills = 3, mesa = true, seed = 43, low = M.Sandstone, high = M.Sandstone, cliff = M.Sandstone, shore = M.Sand })
IslandFields.ruins = make({ name = "Old Ruins", r = 72, peak = 20, hills = 6, ponds = 2, seed = 61, low = M.Grass, high = M.Grass })
IslandFields.fruit = make({ name = "Sunfruit Isle", r = 66, peak = 16, hills = 5, ponds = 3, seed = 97, low = M.Grass, high = M.Grass })
IslandFields.skull = make({ name = "Skull Key", r = 34, peak = 22, hills = 1, seed = 71, low = M.Basalt, high = M.Slate, cliff = M.Basalt, shore = M.Sand })
IslandFields.maw = make({ name = "Maw Rock", r = 36, peak = 18, hills = 2, spires = 6, seed = 89, low = M.Basalt, high = M.Slate, cliff = M.Basalt, shore = M.Sand })
IslandFields.rockcay = make({ name = "Gull Rock", r = 28, peak = 14, hills = 2, spires = 3, seed = 83, low = M.Rock, high = M.Rock })
-- The nameless islands: small, each its own shape.
IslandFields.isle1 = make({ name = "", r = 30, peak = 16, hills = 2, spires = 4, seed = 101, low = M.Grass, high = M.Rock, cliff = M.Slate })
IslandFields.isle2 = make({ name = "", r = 32, peak = 24, hills = 3, spires = 2, seed = 107, low = M.Slate, high = M.Rock, cliff = M.Slate })
IslandFields.isle3 = make({ name = "", r = 32, peak = 12, hills = 3, seed = 113, low = M.Grass, high = M.Grass, cliff = M.Rock })
IslandFields.isle4 = make({ name = "", r = 40, peak = 20, hills = 3, seed = 127, low = M.Grass, high = M.Grass, cliff = M.Rock })
IslandFields.isle5 = make({ name = "", r = 42, peak = 15, hills = 4, seed = 131, low = M.Grass, high = M.Grass })
IslandFields.isle6 = make({ name = "", r = 38, peak = 18, hills = 2, spires = 3, seed = 139, low = M.Rock, high = M.Slate, cliff = M.Slate })
IslandFields.isle7 = make({ name = "", r = 36, peak = 10, hills = 4, seed = 149, low = M.Sand, high = M.Grass, cliff = M.Sandstone })
IslandFields.isle8 = make({ name = "", r = 30, peak = 12, hills = 3, seed = 151, low = M.Grass, high = M.Grass, cliff = M.Rock })

-- Islets (WorldBuilder ISLANDS "Islet n"): palm, rock, grass and sandbar in turn.
IslandFields.islet1 = make({ name = "", r = 20, peak = 7, hills = 2, low = M.Sand, high = M.Grass, seed = 207 })
IslandFields.islet2 = make({ name = "", r = 16, peak = 16, hills = 2, spires = 3, low = M.Rock, high = M.Slate, cliff = M.Slate, seed = 214 })
IslandFields.islet3 = make({ name = "", r = 22, peak = 10, hills = 3, low = M.Grass, high = M.Grass, cliff = M.Rock, seed = 221 })
IslandFields.islet4 = make({ name = "", r = 16, peak = 4, hills = 2, low = M.Sand, high = M.Sand, seed = 228 })
IslandFields.islet5 = make({ name = "", r = 22, peak = 7, hills = 2, low = M.Sand, high = M.Grass, seed = 235 })
IslandFields.islet6 = make({ name = "", r = 22, peak = 16, hills = 2, spires = 3, low = M.Rock, high = M.Slate, cliff = M.Slate, seed = 242 })
IslandFields.islet7 = make({ name = "", r = 22, peak = 10, hills = 3, low = M.Grass, high = M.Grass, cliff = M.Rock, seed = 249 })
IslandFields.islet8 = make({ name = "", r = 20, peak = 4, hills = 2, low = M.Sand, high = M.Sand, seed = 256 })
IslandFields.islet9 = make({ name = "", r = 12, peak = 7, hills = 2, low = M.Sand, high = M.Grass, seed = 263 })
IslandFields.islet10 = make({ name = "", r = 18, peak = 16, hills = 2, spires = 3, low = M.Rock, high = M.Slate, cliff = M.Slate, seed = 270 })
IslandFields.islet11 = make({ name = "", r = 14, peak = 10, hills = 3, low = M.Grass, high = M.Grass, cliff = M.Rock, seed = 277 })
IslandFields.islet12 = make({ name = "", r = 22, peak = 4, hills = 2, low = M.Sand, high = M.Sand, seed = 284 })
IslandFields.islet13 = make({ name = "", r = 12, peak = 7, hills = 2, low = M.Sand, high = M.Grass, seed = 291 })
IslandFields.islet14 = make({ name = "", r = 14, peak = 16, hills = 2, spires = 3, low = M.Rock, high = M.Slate, cliff = M.Slate, seed = 298 })
IslandFields.islet15 = make({ name = "", r = 12, peak = 10, hills = 3, low = M.Grass, high = M.Grass, cliff = M.Rock, seed = 305 })
IslandFields.islet16 = make({ name = "", r = 16, peak = 4, hills = 2, low = M.Sand, high = M.Sand, seed = 312 })

IslandFields.hills = PH :: Field
IslandFields.rock = SS :: Field
IslandFields.snow = FI :: Field
IslandFields.marsh = SM :: Field
IslandFields.ember = EI :: Field

-- Writes an island into terrain, centred on (cx, cz). Overwrites the ocean there.
-- The shape is sampled at 1x and stretched by MapScale (H wide, V tall).
local MapScale = require(script.Parent.MapScale)
function IslandFields.fill(field: Field, terrain: Terrain, cx: number, cz: number)
	local RES = 4
	local H, V = MapScale.H, MapScale.V
	local b = field.bounds
	local height, material, water, carve = field.height, field.material, field.water, field.carve
	MapScale.writeSlabs(terrain, cx + b[1] * H, cx + b[2] * H, -44 * V, field.ytop * V, cz + b[3] * H, cz + b[4] * H, function(wx, wz, ys, mats, occ)
		local x, z = (wx - cx) / H, (wz - cz) / H
		local h = height(x, z)
		local h1, h2, h3, h4 = height(x + 2, z), height(x - 2, z), height(x, z + 2), height(x, z - 2)
		local slope = (math.max(h1, h2, h3, h4) - math.min(h1, h2, h3, h4)) / 4
		local top = if h < 0 then M.Sand else material(x, z, h, slope)
		local hw = h * V
		for j, y0 in ys do
			local o = math.clamp((hw - y0) / RES, 0, 1)
			local m
			if o > 0 and carve and carve(x, (y0 + RES / 2) / V, z) then
				m, o = M.Air, 0
			elseif o > 0 then
				-- Under the surface: rock deep down, the surface material near the top.
				m = if hw - y0 > 10 * V and top ~= M.Sand then M.Rock else top
				if hw - y0 > 8 * V and top == M.Sand then
					m = M.Sand
				end
			elseif y0 < 0 then
				m, o = M.Water, 1
			else
				local w = water and water(x, y0 / V, z)
				if w then
					m, o = w, 1
				else
					m = M.Air
				end
			end
			mats[j], occ[j] = m, o
		end
	end)
end

return IslandFields
