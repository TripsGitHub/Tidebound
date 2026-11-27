-- Clover Island: the spawn island. Four leaves around a central hill with a pond,
-- plus a sandy stem to the south where players spawn.
--   NW leaf "pines"  - dense pine forest on higher ground (wood)
--   NE leaf "rocks"  - terraced rock cliffs and boulders (stone)
--   SW leaf "palms"  - palms and beach
--   SE leaf "meadow" - open meadow, berry bushes, boars
-- Everything here is in studs relative to the island centre (x east, z south),
-- and matches the preview renderer (docs/previews/clover/field.py) exactly.
local CloverIsland = {}

local LOBE_R, CORE_R, LOBE_C = 46, 52, 58
local LOBES = {
	{ -1, -1, "pines" },
	{ 1, -1, "rocks" },
	{ -1, 1, "palms" },
	{ 1, 1, "meadow" },
}
CloverIsland.Zones = { "pines", "rocks", "palms", "meadow", "centre", "stem" }
local POND_X, POND_Z, POND_R, POND_LEVEL = -6, 4, 11, 10.5
CloverIsland.Spawn = Vector2.new(0, 108)
CloverIsland.Board = Vector2.new(-12, 92)
CloverIsland.Trader = Vector2.new(12, 92)
CloverIsland.Herd = Vector2.new(40, 45)
-- Bounds of the area the island touches (relative), for voxel writing.
local X0, X1, Z0, Z1 = -152, 152, -152, 176

local sqrt, sin, cos, abs, floor = math.sqrt, math.sin, math.cos, math.abs, math.floor
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

local function stem(x: number, z: number): number
	if z < 30 or z > 132 then
		return -9
	end
	local t = (z - 30) / 102
	local w = 22 - 9 * t
	local tip = smooth((132 - z) / 14)
	local v = 1 - abs(x) / w
	if v > 0 then
		return v * tip - (1 - tip)
	end
	return v
end

-- > 0 on land (about shore distance / 20), < 0 at sea.
local function land(x: number, z: number): number
	local best = 1 - hypot(x, z) / CORE_R
	local c = LOBE_C / sqrt(2)
	for _, l in LOBES do
		best = math.max(best, 1 - hypot(x - l[1] * c, z - l[2] * c) / LOBE_R)
	end
	best = math.max(best, stem(x, z) * 0.35)
	return best + noise(x * 1.7, z * 1.7) * 0.025
end

local function zoneAt(x: number, z: number): string
	if z > 44 and abs(x) < 24 then
		return "stem"
	end
	if hypot(x, z) < 30 then
		return "centre"
	end
	return LOBES[(if x < 0 then 1 else 2) + (if z < 0 then 0 else 2)][3]
end
CloverIsland.zoneAt = zoneAt

-- Winding dirt trails: spawn stem -> pond, and pond -> out into each leaf.
local function pathDist(x: number, z: number): number
	local d = if z > 14 and z < 122 then abs(x - 4 * sin(z * 0.07)) else 1e9
	for _, l in LOBES do
		local sx, sz = l[1], l[2]
		local ex, ez = sx * 38, sz * 38
		local L = hypot(ex, ez)
		local t = (x * ex + z * ez) / (L * L)
		if t > 0.38 and t < 1 then
			local px, pz = ex * t, ez * t
			local wob = 4 * sin(t * 7 + sx * 1.7 + sz * 0.6)
			local nx, nz = -ez / L, ex / L
			d = math.min(d, hypot(x - (px + nx * wob), z - (pz + nz * wob)))
		end
	end
	return d
end
CloverIsland.pathDist = pathDist

local function lobeWeight(x: number, z: number, i: number): number
	local l = LOBES[i]
	local c = LOBE_C / sqrt(2)
	local d = hypot(x - l[1] * c, z - l[2] * c)
	return smooth((1 - d / LOBE_R) / 0.45) * smooth((hypot(x, z) - 20) / 16)
end

local function stemWeight(x: number, z: number): number
	return smooth((z - 38) / 16) * smooth((24 - abs(x)) / 8)
end

local function height(x: number, z: number): number
	local l = land(x, z)
	if l <= 0 then
		return math.max(-26, 1 + l * 60) -- shelf down into the sea
	end
	local h = 1.5 + smooth(l / 0.18) * 2.5 -- beach rising to the grass
	local inland = smooth((l - 0.12) / 0.5)
	h += inland * (2.5 + noise(x, z) * 1.6) -- rolling ground
	h += 9 * math.exp(-(hypot(x, z) / 34) ^ 2) -- central hill
	local wr = lobeWeight(x, z, 2) -- NE: terraced rock cliffs
	if wr > 0 then
		local k = smooth((l - 0.1 + noise(x * 2.3, z * 2.3) * 0.06) / 0.35)
		local hr = h + k * 14 + noise(x * 1.3, z * 1.3) * 3
		hr = 1.5 + floor((hr - 1.5 + grain(x, z) * 1.2) / 4.5) * 4.5 + ((hr - 1.5) % 4.5) * 0.45
		h += (hr - h) * wr
	end
	h += inland * 5 * lobeWeight(x, z, 1) -- NW: higher wooded ground
	h += smooth(l / 0.2) * detail(x, z) * 0.7 -- small bumps
	local ws = stemWeight(x, z) -- the stem stays low
	h += (math.min(h, 2.6 + l * 4) - h) * ws
	local pd = hypot(x - POND_X, z - POND_Z)
	if pd < POND_R then
		h = math.min(h, POND_LEVEL - (POND_R - pd) * 0.5)
	end
	return h
end
CloverIsland.height = height

local M = Enum.Material
local function material(x: number, z: number, h: number, slope: number): Enum.Material
	local l = land(x, z)
	local zone = zoneAt(x, z)
	local g = grain(x, z)
	if l <= 0.07 + g * 0.03 or (h < 2.6 + g * 0.5 and zone ~= "stem") then
		return M.Sand
	end
	if lobeWeight(x, z, 2) > 0.5 and slope > 0.35 + g * 0.1 then
		return M.Rock
	end
	if slope > 0.9 + g * 0.15 then
		return M.Rock
	end
	if pathDist(x, z) < 3.2 + g * 0.8 and zone ~= "rocks" then
		return M.Ground
	end
	if zone == "palms" and l < 0.3 + g * 0.05 then
		return M.Sand
	end
	if zone == "meadow" then
		return grassy(x, z, M.LeafyGrass)
	end
	return grassy(x, z, M.Grass)
end

-- True where a resource node may grow: on land, off the trails, away from the pond.
local function canGrow(x: number, z: number): boolean
	return land(x, z) > 0.1 and pathDist(x, z) > 5 and hypot(x - POND_X, z - POND_Z) > POND_R + 3
end

-- Rock outcrops in the grass and rocky stretches of coast (see Rugged.lua). Kept
-- off the spawn spit, the central hub and the palm beach.
do
	local Rugged = require(script.Parent.Rugged)
	local f = Rugged.apply({ bounds = { X0, X1, Z0, Z1 }, land = land, height = height, material = material, canGrow = canGrow }, {
		seed = 11,
		count = 6,
		rock = M.Rock,
		coast = true,
		avoid = { { 0, 0, 36 }, { 0, 100, 30 } },
		coastMask = function(x, z)
			local zone = zoneAt(x, z)
			return if zone == "palms" or zone == "stem" then 0 else 1
		end,
	})
	height, material, canGrow = f.height, f.material, f.canGrow
end
CloverIsland.height = height
CloverIsland.canGrow = canGrow

-- Writes the island into terrain, centred on (cx, cz). Overwrites the ocean there.
function CloverIsland.fill(terrain: Terrain, cx: number, cz: number)
	local RES = 4
	local Y0, Y1 = -44, 40
	local region = Region3.new(Vector3.new(cx + X0, Y0, cz + Z0), Vector3.new(cx + X1, Y1, cz + Z1)):ExpandToGrid(RES)
	local size = region.Size / RES
	local nx, ny, nz = size.X, size.Y, size.Z
	local minC = region.CFrame.Position - region.Size / 2
	local mats, occ = table.create(nx), table.create(nx)
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
			local slope = (math.max(height(x + 2, z), height(x - 2, z), height(x, z + 2), height(x, z - 2))
				- math.min(height(x + 2, z), height(x - 2, z), height(x, z + 2), height(x, z - 2))) / 4
			local top = if h < 0 then M.Sand else material(x, z, h, slope)
			local pond = hypot(x - POND_X, z - POND_Z) < POND_R
			for j = 1, ny do
				local y0 = minC.Y + (j - 1) * RES
				local o = math.clamp((h - y0) / RES, 0, 1)
				local m
				if o > 0 then
					-- Under the surface: rock deep down, the surface material near the top.
					m = if h - y0 > 10 and top ~= M.Sand then (if top == M.Rock then M.Rock else M.Ground) else top
					if h - y0 > 8 and top == M.Sand then
						m = M.Sand
					end
				elseif y0 < 0 or (pond and y0 < POND_LEVEL) then
					m, o = M.Water, 1
				else
					m = M.Air
				end
				mats[i][j][k], occ[i][j][k] = m, o
			end
		end
	end
	terrain:WriteVoxels(region, RES, mats, occ)
end

return CloverIsland
