-- Breaks up the smooth island shapes the way the Island Tribes footage looks: rock
-- outcrops (tors) poking out of the grass, and stretches of rocky coast where the
-- island ends in a low cliff instead of a sand beach. It wraps an island field's
-- height, material and canGrow, so CloverIsland and IslandFields use it the same way.
-- docs/previews/map/rugged.py is a line-for-line copy.
local Rugged = {}

local sqrt, sin, cos, atan2 = math.sqrt, math.sin, math.cos, math.atan2

local function smooth(a: number): number
	a = math.clamp(a, 0, 1)
	return a * a * (3 - 2 * a)
end
local function grain(x: number, z: number): number
	return sin(x * 0.41 + z * 0.17) * 0.5 + sin(z * 0.37 - x * 0.23 + 1.7) * 0.5
end

export type Options = {
	seed: number,
	count: number, -- how many outcrops to try to place
	size: number?, -- scales outcrop radius and height (default 1)
	rock: Enum.Material, -- what outcrops and rocky coast are made of
	coast: boolean, -- add rocky stretches of coast
	avoid: { { number } }?, -- {x, z, r}: keep outcrops away from these (spawn, paths' hub...)
	coastMask: ((x: number, z: number) -> number)?, -- 0 = never rocky coast here, 1 = allowed
}

function Rugged.apply(field: any, o: Options)
	local baseHeight, baseMaterial, baseCanGrow, land = field.height, field.material, field.canGrow, field.land
	local b = field.bounds
	local cx, cz = (b[1] + b[2]) / 2, (b[3] + b[4]) / 2
	local size = o.size or 1

	-- Park-Miller random numbers, so the Python preview places the same outcrops.
	local s = o.seed
	local function rand(): number
		s = (s * 16807) % 2147483647
		return s / 2147483647
	end

	local tors = {}
	local tries = 0
	while #tors < o.count and tries < 600 do
		tries += 1
		local x = b[1] + (b[2] - b[1]) * rand()
		local z = b[3] + (b[4] - b[3]) * rand()
		local r = (5 + rand() * 7) * size
		local h = (3 + rand() * 6) * size
		local k = rand() * 6.283
		local ok = land(x, z) > 0.22 and baseCanGrow(x, z)
		for _, t in tors do
			if ok and sqrt((x - t[1]) ^ 2 + (z - t[2]) ^ 2) < 30 then
				ok = false
			end
		end
		for _, a in o.avoid or {} do
			if ok and sqrt((x - a[1]) ^ 2 + (z - a[2]) ^ 2) < a[3] + r then
				ok = false
			end
		end
		if ok then
			table.insert(tors, { x, z, r, h, k })
		end
	end
	field.tors = tors

	-- Height an outcrop adds here: steep sided, lumpy, faceted top.
	local function tor(x: number, z: number): number
		local best = 0
		for _, t in tors do
			local dx, dz = x - t[1], z - t[2]
			local d = sqrt(dx * dx + dz * dz)
			if d < t[3] * 1.5 then
				local a = atan2(dz, dx)
				local rr = t[3] * (1 + 0.22 * sin(a * 3 + t[5]) + 0.12 * sin(a * 5 + 2 * t[5]))
				local u = 1 - d / rr
				if u > 0 then
					local c = t[4] * smooth(u * 2.4) + t[4] * 0.18 * sin(dx * 0.9 + t[5]) * cos(dz * 0.8 - t[5]) * u
					best = math.max(best, c)
				end
			end
		end
		return best
	end

	-- 0..1: how rocky the coast is at this bearing from the island centre.
	local function rockyCoast(x: number, z: number): number
		if not o.coast then
			return 0
		end
		local a = atan2(z - cz, x - cx)
		local k = sin(a * 3 + o.seed * 0.7) * 0.7 + sin(a * 7 + o.seed) * 0.3
		local r = smooth((k - 0.35) / 0.25)
		if o.coastMask then
			r *= o.coastMask(x, z)
		end
		return r
	end

	field.height = function(x: number, z: number): number
		local h = baseHeight(x, z)
		local l = land(x, z)
		local rc = rockyCoast(x, z)
		if rc > 0 then
			-- lift the shore into a low rocky cliff that drops into the sea
			h += rc * 5 * smooth((l + 0.02) / 0.04) * (1 - smooth((l - 0.14) / 0.08))
		end
		return h + tor(x, z)
	end
	field.material = function(x: number, z: number, h: number, slope: number): Enum.Material
		local g = grain(x, z)
		if tor(x, z) > 0.7 + g * 0.4 then
			return o.rock
		end
		local l = land(x, z)
		if rockyCoast(x, z) > 0.5 + g * 0.1 and l < 0.17 + g * 0.03 then
			return o.rock
		end
		return baseMaterial(x, z, h, slope)
	end
	field.canGrow = function(x: number, z: number): boolean
		return baseCanGrow(x, z) and tor(x, z) < 0.2
	end
	field.tor = tor
	return field
end

return Rugged
