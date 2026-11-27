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
		return if n > 1.3 then Enum.Material.LeafyGrass else Enum.Material.Grass
	end
	return if n < -1.3 then Enum.Material.Grass else Enum.Material.LeafyGrass
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
		return grassy(x, z, M.LeafyGrass)
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
	return M.LeafyGrass
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

IslandFields.hills = PH :: Field
IslandFields.rock = SS :: Field
IslandFields.snow = FI :: Field
IslandFields.marsh = SM :: Field
IslandFields.ember = EI :: Field

-- Writes an island into terrain, centred on (cx, cz). Overwrites the ocean there.
function IslandFields.fill(field: Field, terrain: Terrain, cx: number, cz: number)
	local RES = 4
	local b = field.bounds
	local region = Region3.new(Vector3.new(cx + b[1], -44, cz + b[3]), Vector3.new(cx + b[2], field.ytop, cz + b[4])):ExpandToGrid(RES)
	local size = region.Size / RES
	local nx, ny, nz = size.X, size.Y, size.Z
	local minC = region.CFrame.Position - region.Size / 2
	local mats, occ = table.create(nx), table.create(nx)
	local height, material, water, carve = field.height, field.material, field.water, field.carve
	for i = 1, nx do
		local mi, oi = table.create(ny), table.create(ny)
		for j = 1, ny do
			mi[j], oi[j] = table.create(nz), table.create(nz)
		end
		mats[i], occ[i] = mi, oi
		local x = minC.X + (i - 0.5) * RES - cx
		for k = 1, nz do
			local z = minC.Z + (k - 0.5) * RES - cz
			local h = height(x, z)
			local h1, h2, h3, h4 = height(x + 2, z), height(x - 2, z), height(x, z + 2), height(x, z - 2)
			local slope = (math.max(h1, h2, h3, h4) - math.min(h1, h2, h3, h4)) / 4
			local top = if h < 0 then M.Sand else material(x, z, h, slope)
			for j = 1, ny do
				local y0 = minC.Y + (j - 1) * RES
				local o = math.clamp((h - y0) / RES, 0, 1)
				local m
				if o > 0 and carve and carve(x, y0 + RES / 2, z) then
					m, o = M.Air, 0
				elseif o > 0 then
					-- Under the surface: rock deep down, the surface material near the top.
					m = if h - y0 > 10 and top ~= M.Sand then M.Rock else top
					if h - y0 > 8 and top == M.Sand then
						m = M.Sand
					end
				elseif y0 < 0 then
					m, o = M.Water, 1
				else
					local w = water and water(x, y0, z)
					if w then
						m, o = w, 1
					else
						m = M.Air
					end
				end
				mats[i][j][k], occ[i][j][k] = m, o
			end
		end
	end
	terrain:WriteVoxels(region, RES, mats, occ)
end

return IslandFields
