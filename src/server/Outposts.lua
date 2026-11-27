-- Outposts: the man-made places in the world, each built once, by hand, in its own
-- style (Island Tribes' palisades, log cabins, teepees and gravel yards). Nothing here
-- is copy-pasted: four big camps on four of the named islands, and one small outpost
-- on each of the nameless islands (two of them trading posts).
--
-- Every piece is placed on the ground under it. Buildings on a slope stand on a
-- floor at the height of the highest corner, with posts down to the ground, so
-- nothing floats and nothing is buried.
local Props = require(script.Parent.Props)

local Outposts = {}

local rng = Random.new(4242)
local rgb = Color3.fromRGB
local part = Props.part

local LOG = rgb(122, 84, 52)
local LOG_DARK = rgb(92, 62, 40)
local LOG_LIGHT = rgb(160, 118, 76)
local THATCH = rgb(186, 156, 92)
local STONE = rgb(132, 128, 122)
local STONE_DARK = rgb(96, 94, 92)
local HIDE = rgb(226, 204, 158)

export type Ground = (x: number, z: number) -> RaycastResult?

-- Context for one place: `at(x, z)` is the ground point at local (x, z) (negative z
-- is towards the way in), `cf(x, z, yaw?)` a flat frame there whose front faces it.
type Ctx = {
	m: Model,
	look: CFrame,
	at: (x: number, z: number) -> Vector3,
	cf: (x: number, z: number, yaw: number?) -> CFrame,
	ground: Ground,
}

local function ctxFor(m: Model, centre: Vector3, facing: Vector3, ground: Ground): Ctx
	local flat = Vector3.new(facing.X, 0, facing.Z)
	if flat.Magnitude < 0.01 then
		flat = Vector3.zAxis
	end
	-- Local -Z (and negative z in at/cf) points towards `facing`: the way in, or the sea.
	local look = CFrame.lookAt(centre, centre + flat.Unit)
	local function at(x: number, z: number): Vector3
		local p = look * Vector3.new(x, 0, z)
		local hit = ground(p.X, p.Z)
		return Vector3.new(p.X, if hit then hit.Position.Y else centre.Y, p.Z)
	end
	local function cf(x: number, z: number, yaw: number?): CFrame
		local p = at(x, z)
		return CFrame.new(p) * (look - look.Position) * CFrame.Angles(0, yaw or 0, 0)
	end
	return { m = m, look = look, at = at, cf = cf, ground = ground }
end

-- The highest and lowest ground under a w x d footprint centred on local (x, z).
local function footprint(c: Ctx, x: number, z: number, w: number, d: number): (number, number)
	local hi, lo = -math.huge, math.huge
	for _, o in { { 0, 0 }, { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 }, { 0, 1 }, { 0, -1 }, { 1, 0 }, { -1, 0 } } do
		local y = c.at(x + o[1] * w / 2, z + o[2] * d / 2).Y
		hi, lo = math.max(hi, y), math.min(lo, y)
	end
	return hi, lo
end

-- A plank floor at the footprint's highest ground, on posts down to the lowest.
-- Returns the frame on top of the floor (its centre).
local function floor(c: Ctx, x: number, z: number, w: number, d: number, yaw: number?, colour: Color3?): CFrame
	local hi, lo = footprint(c, x, z, w, d)
	local base = c.cf(x, z, yaw)
	local top = CFrame.new(base.X, hi + 0.8, base.Z) * (base - base.Position)
	part(c.m, { Name = "Floor", Size = Vector3.new(w, 0.8, d), CFrame = top * CFrame.new(0, -0.4, 0), Color = colour or LOG_LIGHT, Material = Enum.Material.WoodPlanks })
	local drop = hi - lo + 1.5
	for sx = -1, 1, 2 do
		for sz = -1, 1, 2 do
			local p = top * CFrame.new(sx * (w / 2 - 0.6), -drop / 2 - 0.4, sz * (d / 2 - 0.6))
			part(c.m, { Name = "Stilt", Size = Vector3.new(1, drop, 1), CFrame = p, Color = LOG_DARK, Material = Enum.Material.Wood })
		end
	end
	return top
end

-- Walls of stacked horizontal logs (a log cabin), on `top` (floor centre), with a
-- door gap in the front (-Z) wall and a window in each side.
local function logWalls(c: Ctx, top: CFrame, w: number, d: number, h: number)
	local r = 0.75
	local rows = math.floor(h / (r * 2))
	for row = 0, rows - 1 do
		local y = r + row * r * 2
		local col = if row % 2 == 0 then LOG else LOG_LIGHT
		-- Back and sides: whole logs, sticking out past the corners like a real cabin.
		part(c.m, { Name = "Log", Shape = Enum.PartType.Cylinder, Size = Vector3.new(w + 2, r * 2, r * 2), CFrame = top * CFrame.new(0, y, d / 2), Color = col, Material = Enum.Material.Wood })
		for side = -1, 1, 2 do
			local window = row >= 2 and row <= 3
			if window then
				for _, half in { -1, 1 } do
					local len = d / 2 - 1.5
					part(c.m, { Name = "Log", Shape = Enum.PartType.Cylinder, Size = Vector3.new(len, r * 2, r * 2), CFrame = top * CFrame.new(side * w / 2, y + 0.01, half * (len / 2 + 1.5)) * CFrame.Angles(0, math.pi / 2, 0), Color = col, Material = Enum.Material.Wood })
				end
			else
				part(c.m, { Name = "Log", Shape = Enum.PartType.Cylinder, Size = Vector3.new(d + 2, r * 2, r * 2), CFrame = top * CFrame.new(side * w / 2, y + 0.01, 0) * CFrame.Angles(0, math.pi / 2, 0), Color = col, Material = Enum.Material.Wood })
			end
		end
		-- Front: a door in the middle (the lower rows).
		if row < rows - 2 then
			for side = -1, 1, 2 do
				local len = w / 2 - 2
				part(c.m, { Name = "Log", Shape = Enum.PartType.Cylinder, Size = Vector3.new(len, r * 2, r * 2), CFrame = top * CFrame.new(side * (len / 2 + 2), y, -d / 2), Color = col, Material = Enum.Material.Wood })
			end
		else
			part(c.m, { Name = "Log", Shape = Enum.PartType.Cylinder, Size = Vector3.new(w + 2, r * 2, r * 2), CFrame = top * CFrame.new(0, y, -d / 2), Color = col, Material = Enum.Material.Wood })
		end
	end
	-- Window shutters, hung open.
	for side = -1, 1, 2 do
		part(c.m, { Name = "Shutter", Size = Vector3.new(0.3, 2.4, 1.4), CFrame = top * CFrame.new(side * (w / 2 + 0.9), r * 5, 2.3), Color = rgb(120, 70, 50), Material = Enum.Material.WoodPlanks, CanCollide = false })
	end
	return rows * r * 2
end

-- A gable roof over a w x d building whose walls are `wallH` tall.
local function gableRoof(c: Ctx, top: CFrame, w: number, d: number, wallH: number, colour: Color3, material: Enum.Material?)
	local rise = w * 0.45
	for side = -1, 1, 2 do
		part(c.m, {
			Class = "WedgePart",
			Name = "Roof",
			Size = Vector3.new(d + 3, rise, w / 2 + 1.5),
			CFrame = top * CFrame.new(side * (w / 4 + 0.75), wallH + rise / 2, 0) * CFrame.Angles(0, side * -math.pi / 2, 0),
			Color = colour,
			Material = material or Enum.Material.WoodPlanks,
		})
	end
	-- Gable ends: triangles of planks under the roof.
	for _, z in { -d / 2, d / 2 } do
		for side = -1, 1, 2 do
			part(c.m, { Class = "WedgePart", Name = "Gable", Size = Vector3.new(0.6, rise, w / 2), CFrame = top * CFrame.new(side * w / 4, wallH + rise / 2, z) * CFrame.Angles(0, side * -math.pi / 2, 0), Color = LOG_DARK, Material = Enum.Material.WoodPlanks })
		end
	end
	part(c.m, { Name = "RidgeBeam", Size = Vector3.new(0.9, 0.9, d + 3.6), CFrame = top * CFrame.new(0, wallH + rise + 0.1, 0), Color = LOG_DARK, Material = Enum.Material.Wood })
end

local function chimney(c: Ctx, top: CFrame, x: number, z: number, h: number)
	for i = 0, math.floor(h / 1.6) do
		part(c.m, { Name = "Chimney", Size = Vector3.new(2.6, 1.6, 2.6), CFrame = top * CFrame.new(x + (i % 2) * 0.1, 0.8 + i * 1.6, z), Color = if i % 2 == 0 then STONE else STONE_DARK, Material = Enum.Material.Cobblestone })
	end
	local cap = part(c.m, { Name = "ChimneyTop", Size = Vector3.new(1.6, 0.4, 1.6), CFrame = top * CFrame.new(x, h + 1.8, z), Color = rgb(40, 36, 34), Material = Enum.Material.Slate, CanCollide = false })
	Props.particles(cap, "smoke")
end

local function logCabin(c: Ctx, x: number, z: number, w: number, d: number, yaw: number?, roof: Color3?)
	local top = floor(c, x, z, w, d, yaw)
	local wallH = logWalls(c, top, w, d, 9)
	gableRoof(c, top, w, d, wallH, roof or rgb(110, 74, 50))
	chimney(c, top, w / 2 - 2, d / 2 - 2, wallH + w * 0.45 + 1)
	-- Porch step and a lantern by the door.
	part(c.m, { Name = "Step", Size = Vector3.new(4, 0.6, 2), CFrame = top * CFrame.new(0, -0.5, -d / 2 - 1.2), Color = LOG_DARK, Material = Enum.Material.WoodPlanks })
	Props.torchPost(c.m, (top * CFrame.new(2.8, -0.4, -d / 2 - 1.2)).Position, 4)
	return top
end

-- A teepee: hide panels round a ring of poles that cross and stick out at the top.
local function teepee(c: Ctx, x: number, z: number, r: number, h: number, paint: Color3)
	local base = c.at(x, z)
	-- The Blender teepee, built big: about four times a player's height.
	if Props.teepee(c.m, base, (c.at(0, 0) - base), h * 1.8, paint) then
		return
	end
	local n = 10
	for i = 0, n - 1 do
		local a = i / n * math.pi * 2
		local foot = base + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		local tip = base + Vector3.new(0, h, 0)
		local len = (tip - foot).Magnitude
		local mid = (foot + tip) / 2
		local w = 2 * r * math.sin(math.pi / n) + 0.4
		-- Door gap on panel 0, facing outwards.
		if i ~= 0 then
			part(c.m, { Name = "Hide", Size = Vector3.new(w, len, 0.25), CFrame = CFrame.lookAt(mid, mid + (mid - base) * Vector3.new(1, 0, 1)) * CFrame.Angles(-math.atan2(r, h), 0, 0), Color = if i % 3 == 0 then paint else HIDE, Material = Enum.Material.Fabric })
		end
		local pole = CFrame.lookAt(foot, tip)
		part(c.m, { Name = "Pole", Size = Vector3.new(0.3, 0.3, len + 3), CFrame = pole * CFrame.new(0, 0, -(len + 3) / 2), Color = LOG_DARK, Material = Enum.Material.Wood, CanCollide = false })
	end
	-- A painted band round the middle.
	for i = 0, n - 1 do
		local a = (i + 0.5) / n * math.pi * 2
		local rr = r * 0.55
		part(c.m, { Name = "Band", Size = Vector3.new(2 * rr * math.sin(math.pi / n) + 0.3, 0.6, 0.3), CFrame = CFrame.lookAt(base + Vector3.new(math.cos(a) * rr, h * 0.45, math.sin(a) * rr), base + Vector3.new(0, h * 0.45, 0)), Color = paint, Material = Enum.Material.Fabric, CanCollide = false })
	end
end

-- A drying rack with hides stretched on it.
local function dryingRack(c: Ctx, x: number, z: number, yaw: number)
	local cf = c.cf(x, z, yaw)
	for side = -1, 1, 2 do
		part(c.m, { Name = "RackPost", Size = Vector3.new(0.5, 6, 0.5), CFrame = cf * CFrame.new(side * 3, 3, 0), Color = LOG_DARK, Material = Enum.Material.Wood })
	end
	part(c.m, { Name = "RackBar", Size = Vector3.new(7, 0.4, 0.4), CFrame = cf * CFrame.new(0, 5.6, 0), Color = LOG_DARK, Material = Enum.Material.Wood })
	for k = -1, 1 do
		part(c.m, { Name = "DryingHide", Size = Vector3.new(1.6, 3.2, 0.12), CFrame = cf * CFrame.new(k * 2, 3.8, 0) * CFrame.Angles(0, 0, k * 0.05), Color = HIDE:Lerp(rgb(150, 110, 70), (k + 1) / 3), Material = Enum.Material.Fabric, CanCollide = false })
	end
end

-- A watchtower: four legs braced with crossbeams, a railed platform, a ladder and a roof.
local function watchtower(c: Ctx, x: number, z: number, h: number, ruined: boolean?)
	local hi = footprint(c, x, z, 8, 8)
	local base = c.cf(x, z)
	local top = CFrame.new(base.X, hi + h, base.Z) * (base - base.Position)
	for sx = -1, 1, 2 do
		for sz = -1, 1, 2 do
			local foot = c.at(x + sx * 3.4, z + sz * 3.4)
			local head = (top * CFrame.new(sx * 3, 0, sz * 3)).Position
			local len = (head - foot).Magnitude
			part(c.m, { Name = "Leg", Size = Vector3.new(1.1, 1.1, len + 1), CFrame = CFrame.lookAt((foot + head) / 2, head), Color = LOG, Material = Enum.Material.Wood })
		end
	end
	for _, y in { h * 0.35, h * 0.7 } do
		for side = -1, 1, 2 do
			part(c.m, { Name = "Brace", Size = Vector3.new(7.2, 0.6, 0.6), CFrame = top * CFrame.new(0, y - h, side * 3.15), Color = LOG_DARK, Material = Enum.Material.Wood })
			part(c.m, { Name = "Brace", Size = Vector3.new(0.6, 0.6, 7.2), CFrame = top * CFrame.new(side * 3.15, y - h + 0.3, 0), Color = LOG_DARK, Material = Enum.Material.Wood })
		end
	end
	part(c.m, { Name = "Platform", Size = Vector3.new(9, 0.8, 9), CFrame = top, Color = LOG_LIGHT, Material = Enum.Material.WoodPlanks })
	for side = -1, 1, 2 do
		if not (ruined and side > 0) then
			part(c.m, { Name = "Rail", Size = Vector3.new(9, 0.5, 0.5), CFrame = top * CFrame.new(0, 2.6, side * 4.3), Color = LOG_DARK, Material = Enum.Material.Wood })
		end
		part(c.m, { Name = "Rail", Size = Vector3.new(0.5, 0.5, 9), CFrame = top * CFrame.new(side * 4.3, 2.6, 0), Color = LOG_DARK, Material = Enum.Material.Wood })
	end
	-- Ladder up the front: wooden rungs and an invisible truss to climb.
	local foot = c.at(x, z - 4.6)
	local ladderH = top.Y - foot.Y
	local ladder = CFrame.new(foot.X, foot.Y + ladderH / 2, foot.Z) * (base - base.Position)
	part(c.m, { Class = "TrussPart", Name = "Climb", Size = Vector3.new(2, math.max(2, math.floor(ladderH / 2) * 2), 2), CFrame = ladder, Transparency = 1 })
	for side = -1, 1, 2 do
		part(c.m, { Name = "LadderSide", Size = Vector3.new(0.4, ladderH, 0.4), CFrame = ladder * CFrame.new(side * 1.1, 0, -1.1), Color = LOG_DARK, Material = Enum.Material.Wood, CanCollide = false })
	end
	for k = 0, math.floor(ladderH / 1.5) do
		part(c.m, { Name = "Rung", Size = Vector3.new(2.2, 0.3, 0.3), CFrame = ladder * CFrame.new(0, -ladderH / 2 + 0.6 + k * 1.5, -1.1), Color = LOG_LIGHT, Material = Enum.Material.Wood, CanCollide = false })
	end
	if not ruined then
		for sx = -1, 1, 2 do
			for sz = -1, 1, 2 do
				part(c.m, { Name = "RoofPost", Size = Vector3.new(0.6, 6, 0.6), CFrame = top * CFrame.new(sx * 4, 3, sz * 4), Color = LOG_DARK, Material = Enum.Material.Wood })
			end
		end
		for side = -1, 1, 2 do
			part(c.m, { Class = "WedgePart", Name = "Roof", Size = Vector3.new(11, 3, 5.5), CFrame = top * CFrame.new(side * 2.75, 7.5, 0) * CFrame.Angles(0, side * -math.pi / 2, 0), Color = THATCH, Material = Enum.Material.Grass })
		end
		Props.torchPost(c.m, (top * CFrame.new(3.6, 0.4, -3.6)).Position, 2)
	else
		-- Collapsed roof timbers lying at the foot.
		for k = 1, 3 do
			local p = c.at(x + rng:NextNumber(-7, 7), z + rng:NextNumber(5, 9))
			part(c.m, { Name = "FallenBeam", Size = Vector3.new(0.9, 0.9, rng:NextNumber(5, 8)), CFrame = CFrame.new(p + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0.1 * k), Color = LOG_DARK, Material = Enum.Material.Wood })
		end
	end
	return top
end

-- A fence of posts and two rails from a to b.
local function fence(c: Ctx, a: Vector3, b: Vector3)
	local d = b - a
	local n = math.max(1, math.floor(d.Magnitude / 4))
	for i = 0, n do
		local p = a:Lerp(b, i / n)
		local hit = c.ground(p.X, p.Z)
		local y = if hit then hit.Position.Y else p.Y
		part(c.m, { Name = "FencePost", Size = Vector3.new(0.6, 3.4, 0.6), CFrame = CFrame.new(p.X, y + 1.4, p.Z), Color = LOG_DARK, Material = Enum.Material.Wood })
	end
	for _, y in { 1.2, 2.5 } do
		local ha, hb = c.ground(a.X, a.Z), c.ground(b.X, b.Z)
		local pa = Vector3.new(a.X, (if ha then ha.Position.Y else a.Y) + y, a.Z)
		local pb = Vector3.new(b.X, (if hb then hb.Position.Y else b.Y) + y, b.Z)
		part(c.m, { Name = "FenceRail", Size = Vector3.new(0.3, 0.3, (pb - pa).Magnitude), CFrame = CFrame.lookAt((pa + pb) / 2, pb), Color = LOG, Material = Enum.Material.Wood, CanCollide = false })
	end
end

-- Market stall: counter, four posts and a striped awning.
local function stall(c: Ctx, x: number, z: number, yaw: number, cloth: Color3)
	local top = floor(c, x, z, 10, 6, yaw, LOG_DARK)
	part(c.m, { Name = "Counter", Size = Vector3.new(9, 3, 1.6), CFrame = top * CFrame.new(0, 1.5, -2.2), Color = LOG_LIGHT, Material = Enum.Material.WoodPlanks })
	for sx = -1, 1, 2 do
		for sz = -1, 1, 2 do
			part(c.m, { Name = "StallPost", Size = Vector3.new(0.6, 8, 0.6), CFrame = top * CFrame.new(sx * 4.6, 4, sz * 2.6), Color = LOG_DARK, Material = Enum.Material.Wood })
		end
	end
	for k = 0, 4 do
		part(c.m, { Name = "Awning", Size = Vector3.new(2.05, 0.2, 7.4), CFrame = top * CFrame.new(-4 + k * 2, 8.2, -0.4) * CFrame.Angles(-0.18, 0, 0), Color = if k % 2 == 0 then cloth else rgb(240, 232, 214), Material = Enum.Material.Fabric })
	end
	Props.crate(c.m, top * CFrame.new(-3, 3, -2.2), 1.6)
	Props.barrel(c.m, top * CFrame.new(3.4, 0, 1.6))
	return top
end

-- A jetty out over the water from local (x, z), `len` long.
local function dock(c: Ctx, x: number, z: number, len: number)
	local start = c.at(x, z)
	local deck = math.max(start.Y, 1.2) + 1.2
	for k = 0, math.floor(len / 2) do
		local p = c.look * Vector3.new(x, 0, z - k * 2)
		part(c.m, { Name = "DockPlank", Size = Vector3.new(6, 0.5, 1.8), CFrame = CFrame.new(p.X, deck + (if k % 3 == 0 then 0.03 else 0), p.Z) * (c.look - c.look.Position) * CFrame.Angles(0, rng:NextNumber(-0.02, 0.02), 0), Color = if k % 2 == 0 then LOG_LIGHT else LOG, Material = Enum.Material.WoodPlanks })
		if k % 3 == 0 then
			for side = -1, 1, 2 do
				local hit = c.ground(p.X + side * 2.6, p.Z)
				local bottom = if hit then hit.Position.Y - 2 else -6
				local h = deck + 1.6 - bottom
				local q = c.look * Vector3.new(x + side * 2.8, 0, z - k * 2)
				part(c.m, { Name = "DockPost", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, 1, 1), CFrame = CFrame.new(q.X, bottom + h / 2, q.Z) * CFrame.Angles(0, 0, math.pi / 2), Color = LOG_DARK, Material = Enum.Material.Wood })
			end
		end
	end
	return deck
end

-- A small rowing boat.
local function rowboat(c: Ctx, at: Vector3, yaw: number)
	local cf = CFrame.new(at) * CFrame.Angles(0, yaw, 0)
	part(c.m, { Name = "Hull", Size = Vector3.new(4, 1, 9), CFrame = cf * CFrame.new(0, 0.2, 0), Color = rgb(150, 98, 62), Material = Enum.Material.WoodPlanks })
	for side = -1, 1, 2 do
		part(c.m, { Name = "Side", Size = Vector3.new(0.4, 1.4, 9), CFrame = cf * CFrame.new(side * 2, 1, 0) * CFrame.Angles(0, 0, side * -0.25), Color = rgb(170, 60, 50), Material = Enum.Material.WoodPlanks })
	end
	part(c.m, { Class = "WedgePart", Name = "Bow", Size = Vector3.new(4, 1.8, 2.4), CFrame = cf * CFrame.new(0, 0.9, -5.6) * CFrame.Angles(0, math.pi, 0), Color = rgb(150, 98, 62), Material = Enum.Material.WoodPlanks })
	part(c.m, { Name = "Seat", Size = Vector3.new(3.6, 0.3, 1), CFrame = cf * CFrame.new(0, 1, 0), Color = LOG_LIGHT, Material = Enum.Material.WoodPlanks })
	part(c.m, { Name = "Oar", Size = Vector3.new(0.3, 0.3, 7), CFrame = cf * CFrame.new(1.5, 1.4, 0.5) * CFrame.Angles(0, 0.3, 0), Color = LOG_LIGHT, Material = Enum.Material.Wood, CanCollide = false })
end

-- The big camps ------------------------------------------------------------------

local CAMPS = {}

-- Pine Hills: Hilltop Fort. A wide palisade with two watchtowers at the gate, a
-- longhouse and tents inside, the totem and a cookfire.
function CAMPS.fort(c: Ctx, name: string, banner: Color3)
	local R = 46
	local sections = 22
	for i = 1, sections - 1 do
		local a0 = (i - 0.5) / sections * math.pi * 2
		local a1 = (i + 0.5) / sections * math.pi * 2
		Props.palisade(c.m, c.at(math.sin(a0) * R, -math.cos(a0) * R) - Vector3.new(0, 0.8, 0), c.at(math.sin(a1) * R, -math.cos(a1) * R) - Vector3.new(0, 0.8, 0), 18)
	end
	watchtower(c, -9, -R + 2, 24)
	watchtower(c, 9, -R + 2, 24)
	-- Longhouse along the back.
	local top = floor(c, 0, 24, 26, 12, 0)
	local wallH = logWalls(c, top, 26, 12, 8)
	gableRoof(c, top, 26, 12, wallH, THATCH, Enum.Material.Grass)
	Props.totem(c.m, c.at(0, 6), 18, c.look.LookVector)
	Props.campfire(c.m, c.at(0, -8))
	Props.tent(c.m, c.at(-26, 4), (c.at(0, 0) - c.at(-26, 4)) * Vector3.new(1, 0, 1), 6)
	Props.tent(c.m, c.at(26, -6), (c.at(0, 0) - c.at(26, -6)) * Vector3.new(1, 0, 1), 5.5)
	dryingRack(c, -22, -20, 0.4)
	Props.crateStack(c.m, c.cf(28, 16, 0.3))
	Props.logPile(c.m, c.cf(-28, 18, 1.2))
	for k = 0, 3 do
		Props.barrel(c.m, c.cf(18 + k * 2.8, 22 + (k % 2)))
	end
	Props.banner(c.m, c.at(-14, -R + 4), banner, 15)
	Props.banner(c.m, c.at(14, -R + 4), banner, 15)
	return R
end

-- Sunfruit Isle: the Homestead. Two log cabins, a fenced garden of crops, a well,
-- a woodpile and a cart. No walls: friendly farm country.
function CAMPS.homestead(c: Ctx, name: string, banner: Color3)
	logCabin(c, -14, 12, 16, 12, 0.08, rgb(150, 70, 52))
	logCabin(c, 18, 18, 12, 10, -0.35, rgb(110, 74, 50))
	-- Garden: rows of crops inside a fence.
	local corners = { c.at(-30, -26), c.at(6, -26), c.at(6, -4), c.at(-30, -4) }
	for i = 1, 3 do
		fence(c, corners[i], corners[i + 1])
	end
	fence(c, corners[4], c.at(-16, -4))
	for row = 0, 4 do
		for k = 0, 7 do
			local p = c.at(-27 + k * 4, -23 + row * 4)
			part(c.m, { Name = "Crop", Size = Vector3.new(1, 1.4 + (k % 3) * 0.3, 1), CFrame = CFrame.new(p + Vector3.new(0, 0.7, 0)), Color = rgb(90, 150, 56):Lerp(rgb(200, 170, 60), (row % 2) * 0.5), Material = Enum.Material.Grass, CanCollide = false })
			part(c.m, { Name = "Furrow", Size = Vector3.new(3.4, 0.3, 1.6), CFrame = CFrame.new(p + Vector3.new(0, 0.05, 0)), Color = rgb(96, 70, 46), Material = Enum.Material.Ground, CanCollide = false })
		end
	end
	-- A stone well with a little roof.
	local w = c.at(16, -14)
	for i = 0, 9 do
		local a = i / 10 * math.pi * 2
		part(c.m, { Name = "WellStone", Size = Vector3.new(2, 3, 1.4), CFrame = CFrame.lookAt(w + Vector3.new(math.cos(a) * 3, 1.3, math.sin(a) * 3), w + Vector3.new(0, 1.3, 0)), Color = if i % 2 == 0 then STONE else STONE_DARK, Material = Enum.Material.Cobblestone })
	end
	for side = -1, 1, 2 do
		part(c.m, { Name = "WellPost", Size = Vector3.new(0.6, 7, 0.6), CFrame = CFrame.new(w + Vector3.new(side * 3, 3.5, 0)), Color = LOG_DARK, Material = Enum.Material.Wood })
		part(c.m, { Class = "WedgePart", Name = "WellRoof", Size = Vector3.new(8, 2, 3.4), CFrame = CFrame.new(w + Vector3.new(0, 8, side * 1.7)) * CFrame.Angles(0, if side > 0 then 0 else math.pi, 0), Color = rgb(150, 70, 52), Material = Enum.Material.WoodPlanks })
	end
	part(c.m, { Name = "Bucket", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 1.2, 1.2), CFrame = CFrame.new(w + Vector3.new(0, 4, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = LOG, Material = Enum.Material.Wood })
	Props.logPile(c.m, c.cf(-28, 18, 1.57))
	Props.crateStack(c.m, c.cf(4, 8, 0.2))
	Props.flowers(c.m, c.at(-6, 2), 6, 14)
	Props.banner(c.m, c.at(-2, -30), banner, 10)
	return 36
end

-- Coral Atoll: Reef Village. A ring of painted teepees round a big fire, drying
-- racks, a totem pair and canoes pulled up on the sand.
function CAMPS.teepees(c: Ctx, name: string, banner: Color3)
	local paints = { rgb(170, 70, 52), rgb(70, 120, 160), rgb(200, 150, 60), rgb(90, 140, 80), rgb(140, 80, 130), rgb(170, 70, 52) }
	for i = 0, 5 do
		local a = (i + 0.5) / 6 * math.pi * 2
		teepee(c, math.sin(a) * 30, math.cos(a) * 30, 5.5 + (i % 2), 13 + (i % 3), paints[i + 1])
	end
	-- A big fire pit with a ring of log seats.
	local mid = c.at(0, 0)
	Props.campfire(c.m, mid)
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		local p = c.at(math.cos(a) * 8, math.sin(a) * 8)
		part(c.m, { Name = "LogSeat", Shape = Enum.PartType.Cylinder, Size = Vector3.new(4, 1.4, 1.4), CFrame = CFrame.lookAt(p + Vector3.new(0, 0.7, 0), mid + Vector3.new(0, 0.7, 0)) * CFrame.Angles(0, math.pi / 2, 0), Color = LOG, Material = Enum.Material.Wood })
	end
	Props.totem(c.m, c.at(-7, -32), 13, c.look.LookVector)
	Props.totem(c.m, c.at(7, -32), 13, c.look.LookVector)
	dryingRack(c, 32, 4, 1.2)
	dryingRack(c, -32, -6, -1.1)
	Props.banner(c.m, c.at(0, 34), banner, 14)
	return 38
end

-- Stone Shelf: the Quarry Yard. A gravel yard with cut stone stacked in blocks, a
-- timber crane with a block on its rope, ore carts, a tool shed and a forge.
function CAMPS.quarry(c: Ctx, name: string, banner: Color3, terrain: Terrain)
	-- Gravel underfoot.
	for k = 0, 7 do
		local p = c.at(rng:NextNumber(-22, 22), rng:NextNumber(-22, 22))
		pcall(function()
			terrain:FillCylinder(CFrame.new(p + Vector3.new(0, -0.6, 0)), 2.4, rng:NextNumber(10, 16), Enum.Material.Pebble)
		end)
	end
	-- Cut stone, stacked.
	for s = 0, 3 do
		local base = c.cf(-24 + s * 6, 14 + (s % 2) * 4, rng:NextNumber(-0.2, 0.2))
		for row = 0, 2 - (s % 2) do
			for k = 0, 1 do
				part(c.m, { Name = "CutStone", Size = Vector3.new(2.6, 1.8, 2.6), CFrame = base * CFrame.new(k * 2.7 - 1.35, 0.9 + row * 1.85, 0) * CFrame.Angles(0, rng:NextNumber(-0.06, 0.06), 0), Color = STONE:Lerp(STONE_DARK, rng:NextNumber()), Material = Enum.Material.Slate })
			end
		end
	end
	-- The crane: an A-frame, a long arm, a rope and a block hanging off it.
	local foot = c.cf(14, 6, 0.6)
	for side = -1, 1, 2 do
		part(c.m, { Name = "CraneLeg", Size = Vector3.new(1.2, 18, 1.2), CFrame = foot * CFrame.new(side * 3, 8.5, 0) * CFrame.Angles(0, 0, side * -0.18), Color = LOG, Material = Enum.Material.Wood })
	end
	part(c.m, { Name = "CraneArm", Size = Vector3.new(1, 1, 22), CFrame = foot * CFrame.new(0, 17, -6) * CFrame.Angles(0.25, 0, 0), Color = LOG_DARK, Material = Enum.Material.Wood })
	local tip = (foot * CFrame.new(0, 19.6, -16.5)).Position
	local blockAt = c.ground(tip.X, tip.Z)
	local blockY = (if blockAt then blockAt.Position.Y else tip.Y - 12) + 4
	part(c.m, { Name = "Rope", Size = Vector3.new(0.25, tip.Y - blockY, 0.25), CFrame = CFrame.new(tip.X, (tip.Y + blockY) / 2, tip.Z), Color = Props.ROPE, Material = Enum.Material.Fabric, CanCollide = false })
	part(c.m, { Name = "HangingBlock", Size = Vector3.new(3.2, 2.4, 3.2), CFrame = CFrame.new(tip.X, blockY - 1.2, tip.Z), Color = STONE, Material = Enum.Material.Slate })
	part(c.m, { Name = "Winch", Shape = Enum.PartType.Cylinder, Size = Vector3.new(4, 1.6, 1.6), CFrame = foot * CFrame.new(0, 2.2, 1.6), Color = LOG_DARK, Material = Enum.Material.Wood })
	-- Ore carts on a short run of track.
	for k = 0, 5 do
		local p = c.cf(-6, -6 - k * 3, 0)
		part(c.m, { Name = "Sleeper", Size = Vector3.new(4, 0.3, 0.8), CFrame = p * CFrame.new(0, 0.15, 0), Color = LOG_DARK, Material = Enum.Material.Wood })
	end
	for side = -1, 1, 2 do
		local a, b = c.at(-6 + side * 1.5, -6), c.at(-6 + side * 1.5, -21)
		part(c.m, { Name = "Rail", Size = Vector3.new(0.3, 0.3, (b - a).Magnitude), CFrame = CFrame.lookAt((a + b) / 2 + Vector3.new(0, 0.45, 0), b + Vector3.new(0, 0.45, 0)), Color = rgb(70, 66, 64), Material = Enum.Material.Metal })
	end
	for k = 0, 1 do
		local cart = c.cf(-6, -9 - k * 8, 0)
		part(c.m, { Name = "Cart", Size = Vector3.new(3.4, 2, 4), CFrame = cart * CFrame.new(0, 1.8, 0), Color = rgb(96, 88, 80), Material = Enum.Material.Metal })
		part(c.m, { Name = "CartLoad", Size = Vector3.new(3, 1, 3.6), CFrame = cart * CFrame.new(0, 2.9, 0), Color = if k == 0 then rgb(170, 170, 178) else STONE_DARK, Material = Enum.Material.Slate })
		for sx = -1, 1, 2 do
			for sz = -1, 1, 2 do
				part(c.m, { Name = "Wheel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 1.2, 1.2), CFrame = cart * CFrame.new(sx * 1.6, 0.6, sz * 1.3), Color = rgb(50, 46, 44), Material = Enum.Material.Metal })
			end
		end
	end
	-- Tool shed with a lean-to roof, and a forge.
	local shed = floor(c, 24, 22, 10, 8, -0.3)
	for side = -1, 1, 2 do
		part(c.m, { Name = "ShedWall", Size = Vector3.new(0.6, 7, 8), CFrame = shed * CFrame.new(side * 4.7, 3.5, 0), Color = LOG_LIGHT, Material = Enum.Material.WoodPlanks })
	end
	part(c.m, { Name = "ShedWall", Size = Vector3.new(10, 7, 0.6), CFrame = shed * CFrame.new(0, 3.5, 3.7), Color = LOG_LIGHT, Material = Enum.Material.WoodPlanks })
	part(c.m, { Name = "ShedRoof", Size = Vector3.new(11.5, 0.6, 10), CFrame = shed * CFrame.new(0, 7.6, 0) * CFrame.Angles(0.18, 0, 0), Color = rgb(90, 84, 80), Material = Enum.Material.CorrodedMetal })
	for k = 0, 2 do
		part(c.m, { Name = "Pick", Size = Vector3.new(0.3, 4, 0.3), CFrame = shed * CFrame.new(-2 + k * 2, 2.2, 3) * CFrame.Angles(0, 0, 0.2), Color = LOG_LIGHT, Material = Enum.Material.Wood, CanCollide = false })
	end
	local forge = c.at(-22, -14)
	part(c.m, { Name = "Forge", Size = Vector3.new(5, 3, 5), CFrame = CFrame.new(forge + Vector3.new(0, 1.5, 0)), Color = STONE_DARK, Material = Enum.Material.Cobblestone })
	local coals = part(c.m, { Name = "Coals", Size = Vector3.new(3.4, 0.4, 3.4), CFrame = CFrame.new(forge + Vector3.new(0, 3.1, 0)), Color = rgb(255, 110, 40), Material = Enum.Material.Neon, CanCollide = false })
	local fire = Instance.new("Fire")
	fire.Size, fire.Heat = 3, 5
	fire.Parent = coals
	part(c.m, { Name = "Anvil", Size = Vector3.new(1.4, 1.6, 2.6), CFrame = CFrame.new(forge + Vector3.new(4.5, 0.8, 0)), Color = rgb(60, 58, 62), Material = Enum.Material.Metal })
	Props.banner(c.m, c.at(-30, -28), banner, 12)
	return 34
end

-- Small outposts on the nameless islands -----------------------------------------

local OUTPOSTS = {}

-- A trading post on a jetty: a market stall at the shore, a hut and a boat tied up.
function OUTPOSTS.dockMarket(c: Ctx, hooks)
	local top = stall(c, 0, 0, 0, rgb(70, 120, 160))
	hooks.trader(top * CFrame.new(0, 0, 0.4) * CFrame.Angles(0, math.pi, 0), "Dock Trader", { shirt = rgb(60, 100, 140), pants = rgb(80, 66, 50), skin = rgb(160, 112, 80) })
	dock(c, 0, -6, 26)
	rowboat(c, (c.look * CFrame.new(5.5, 0, -26)).Position * Vector3.new(1, 0, 1) + Vector3.new(0, 0.6, 0), math.rad(8))
	logCabin(c, -16, 10, 10, 9, 0.2, rgb(70, 110, 130))
	Props.crateStack(c.m, c.cf(8, 6, 0.4))
	Props.barrel(c.m, c.cf(9, 3))
	Props.barrel(c.m, c.cf(11, 4.4))
	Props.torchPost(c.m, c.at(-5, -5), 5)
	Props.torchPost(c.m, c.at(5, -5), 5)
end

-- A trading hut up the hill: a thatched round hut, a sign and a pack mule's hitching rail.
function OUTPOSTS.hillTrader(c: Ctx, hooks)
	local top = floor(c, 0, 0, 14, 14, 0)
	-- Round wattle wall from posts and woven panels, door at the front.
	for i = 0, 13 do
		local a = i / 14 * math.pi * 2
		if not (i == 0 or i == 13) then
			local p = top * CFrame.new(math.sin(a) * 6.2, 3.2, -math.cos(a) * 6.2)
			part(c.m, { Name = "Wattle", Size = Vector3.new(2.9, 6.4, 0.5), CFrame = CFrame.lookAt(p.Position, top.Position + Vector3.new(0, 3.2, 0)), Color = rgb(150, 116, 74), Material = Enum.Material.Fabric })
		end
	end
	-- Conical thatch roof from wedges.
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		part(c.m, { Class = "WedgePart", Name = "Thatch", Size = Vector3.new(4.2, 6, 8.4), CFrame = top * CFrame.Angles(0, a, 0) * CFrame.new(0, 9.4, -3.4) * CFrame.Angles(0, math.pi, 0), Color = THATCH:Lerp(rgb(150, 120, 70), (i % 3) / 3), Material = Enum.Material.Grass })
	end
	part(c.m, { Name = "Counter", Size = Vector3.new(6, 3, 1.4), CFrame = top * CFrame.new(0, 1.5, -2), Color = LOG_LIGHT, Material = Enum.Material.WoodPlanks })
	hooks.trader(top * CFrame.new(0, 0, 0.4) * CFrame.Angles(0, math.pi, 0), "Hill Trader", { shirt = rgb(150, 70, 52), pants = rgb(70, 60, 50), skin = rgb(222, 180, 140) })
	-- Hitching rail with packs and a lantern.
	local railA, railB = c.at(-8, -12), c.at(4, -12)
	fence(c, railA, railB)
	for k = 0, 1 do
		Props.crate(c.m, c.cf(-6 + k * 5, -14.5, 0.3 * k), 2)
	end
	Props.torchPost(c.m, c.at(8, -9), 5)
	Props.flowers(c.m, c.at(-9, 2), 4, 8)
end

-- A broken old watchtower with a lookout's camp at its foot.
function OUTPOSTS.ruinedTower(c: Ctx)
	watchtower(c, 0, 0, 20, true)
	Props.campfire(c.m, c.at(9, -6))
	Props.tent(c.m, c.at(12, 6), (c.at(9, -6) - c.at(12, 6)) * Vector3.new(1, 0, 1), 4.5)
	for k = 1, 5 do
		local p = c.at(rng:NextNumber(-14, -6), rng:NextNumber(-10, 10))
		part(c.m, { Name = "Rubble", Size = Vector3.new(rng:NextNumber(1.5, 3), rng:NextNumber(1, 2), rng:NextNumber(1.5, 3)), CFrame = CFrame.new(p + Vector3.new(0, 0.5, 0)) * CFrame.Angles(rng:NextNumber(0, 0.4), rng:NextNumber(0, 6), 0), Color = STONE:Lerp(STONE_DARK, k / 5), Material = Enum.Material.Slate })
	end
end

-- A shipwreck run aground on the beach, tilted, with its cargo spilled.
function OUTPOSTS.shipwreck(c: Ctx)
	local base = c.at(0, 4)
	local cf = CFrame.new(base + Vector3.new(0, 2.2, 0)) * (c.look - c.look.Position) * CFrame.Angles(0, 0.4, 0.32)
	part(c.m, { Name = "Keel", Size = Vector3.new(2, 2, 34), CFrame = cf * CFrame.new(0, -2, 0), Color = LOG_DARK, Material = Enum.Material.Wood })
	for k = 0, 7 do
		local z = -15 + k * 4.3
		local w = 12 - math.abs(k - 3.5) * 1.6
		for side = -1, 1, 2 do
			if not (side > 0 and (k == 3 or k == 4)) then -- a hole stove in on one side
				part(c.m, { Name = "HullPlank", Size = Vector3.new(0.8, 7, 4.4), CFrame = cf * CFrame.new(side * w / 2, 1.5, z) * CFrame.Angles(0, 0, side * 0.22), Color = rgb(110, 76, 50):Lerp(rgb(80, 60, 44), k / 8), Material = Enum.Material.WoodPlanks })
			end
		end
		part(c.m, { Name = "Rib", Size = Vector3.new(w, 0.8, 0.8), CFrame = cf * CFrame.new(0, 4.8, z), Color = LOG_DARK, Material = Enum.Material.Wood })
	end
	part(c.m, { Name = "Deck", Size = Vector3.new(8, 0.6, 16), CFrame = cf * CFrame.new(0, 3.6, 8), Color = LOG_LIGHT, Material = Enum.Material.WoodPlanks })
	part(c.m, { Name = "BrokenMast", Shape = Enum.PartType.Cylinder, Size = Vector3.new(14, 1.4, 1.4), CFrame = cf * CFrame.new(0, 10, -2) * CFrame.Angles(0, 0, math.pi / 2 + 0.1), Color = LOG, Material = Enum.Material.Wood })
	local mastTop = c.at(10, -10)
	part(c.m, { Name = "FallenMast", Shape = Enum.PartType.Cylinder, Size = Vector3.new(18, 1.2, 1.2), CFrame = CFrame.new(mastTop + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, 0.8, 0), Color = LOG, Material = Enum.Material.Wood })
	part(c.m, { Name = "Sail", Size = Vector3.new(9, 0.2, 7), CFrame = CFrame.new(mastTop + Vector3.new(2, 0.2, 3)) * CFrame.Angles(0, 0.5, 0.05), Color = rgb(232, 222, 196), Material = Enum.Material.Fabric, CanCollide = false })
	for k = 1, 4 do
		Props.crate(c.m, c.cf(rng:NextNumber(-14, 14), rng:NextNumber(-16, -6), rng:NextNumber(0, 1)), rng:NextNumber(1.8, 2.8))
	end
	Props.barrel(c.m, c.cf(-9, -12) * CFrame.Angles(math.pi / 2, 0, 0) * CFrame.new(0, -1.3, -1.3))
end

-- A fisher's hut on stilts at the water's edge, nets drying, a jetty and a boat.
function OUTPOSTS.fishingHut(c: Ctx)
	local top = floor(c, 0, 6, 12, 10, 0)
	for side = -1, 1, 2 do
		part(c.m, { Name = "HutWall", Size = Vector3.new(0.6, 6.5, 10), CFrame = top * CFrame.new(side * 5.7, 3.25, 0), Color = rgb(150, 120, 86), Material = Enum.Material.WoodPlanks })
	end
	part(c.m, { Name = "HutWall", Size = Vector3.new(12, 6.5, 0.6), CFrame = top * CFrame.new(0, 3.25, -4.7), Color = rgb(150, 120, 86), Material = Enum.Material.WoodPlanks })
	for side = -1, 1, 2 do
		part(c.m, { Name = "HutWall", Size = Vector3.new(3.5, 6.5, 0.6), CFrame = top * CFrame.new(side * 4.25, 3.25, 4.7), Color = rgb(150, 120, 86), Material = Enum.Material.WoodPlanks })
	end
	gableRoof(c, top, 12, 10, 6.5, THATCH, Enum.Material.Grass)
	dock(c, 0, 0, 20)
	rowboat(c, (c.look * CFrame.new(-6, 0, -18)).Position * Vector3.new(1, 0, 1) + Vector3.new(0, 0.6, 0), math.rad(-12))
	-- Nets on poles.
	for k = 0, 1 do
		local cf = c.cf(-12, -6 + k * 8, 0.3)
		for side = -1, 1, 2 do
			part(c.m, { Name = "NetPole", Size = Vector3.new(0.4, 6, 0.4), CFrame = cf * CFrame.new(side * 3, 3, 0), Color = LOG_DARK, Material = Enum.Material.Wood })
		end
		part(c.m, { Name = "Net", Size = Vector3.new(6, 4, 0.1), CFrame = cf * CFrame.new(0, 3.6, 0), Color = rgb(190, 180, 150), Material = Enum.Material.Fabric, Transparency = 0.35, CanCollide = false })
	end
	for k = 0, 2 do
		Props.barrel(c.m, c.cf(7 + k * 2.6, -4))
	end
end

-- A ring of tall standing stones round a flat altar stone, moss on the tops.
function OUTPOSTS.stoneCircle(c: Ctx)
	local mid = c.at(0, 0)
	for i = 0, 8 do
		local a = i / 9 * math.pi * 2
		local p = c.at(math.cos(a) * 16, math.sin(a) * 16)
		local h = 9 + (i % 3) * 2.5
		local stone = part(c.m, { Name = "StandingStone", Size = Vector3.new(3.2, h, 2.2), CFrame = CFrame.lookAt(p + Vector3.new(0, h / 2 - 1, 0), mid + Vector3.new(0, h / 2 - 1, 0)) * CFrame.Angles(rng:NextNumber(-0.06, 0.06), 0, rng:NextNumber(-0.06, 0.06)), Color = rgb(150, 146, 140):Lerp(rgb(110, 108, 104), (i % 3) / 3), Material = Enum.Material.Slate })
		part(c.m, { Name = "Moss", Size = Vector3.new(3.3, 0.6, 2.3), CFrame = stone.CFrame * CFrame.new(0, h / 2 - 0.2, 0), Color = rgb(90, 130, 60), Material = Enum.Material.Grass, CanCollide = false })
		if i % 3 == 0 then
			-- A lintel across to the next stone.
			local a2 = (i + 1) / 9 * math.pi * 2
			local q = c.at(math.cos(a2) * 16, math.sin(a2) * 16)
			local y = math.min(p.Y, q.Y) + h - 1
			part(c.m, { Name = "Lintel", Size = Vector3.new(2, 1.6, (q - p).Magnitude + 2), CFrame = CFrame.lookAt(Vector3.new((p.X + q.X) / 2, y, (p.Z + q.Z) / 2), Vector3.new(q.X, y, q.Z)), Color = rgb(140, 136, 130), Material = Enum.Material.Slate })
		end
	end
	part(c.m, { Name = "Altar", Size = Vector3.new(7, 2, 4), CFrame = CFrame.new(mid + Vector3.new(0, 0.8, 0)), Color = rgb(120, 118, 114), Material = Enum.Material.Slate })
	local glow = part(c.m, { Name = "AltarGlow", Size = Vector3.new(1.4, 1.4, 1.4), CFrame = CFrame.new(mid + Vector3.new(0, 2.6, 0)) * CFrame.Angles(0.6, 0.6, 0), Color = rgb(150, 220, 255), Material = Enum.Material.Neon, CanCollide = false })
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = rgb(150, 220, 255), 18, 1.2
	light.Parent = glow
	Props.particles(glow, "fireflies")
end

-- A striped lighthouse on the point, with a keeper's shed.
function OUTPOSTS.lighthouse(c: Ctx)
	local hi = footprint(c, 0, 0, 10, 10)
	local base = c.at(0, 0)
	local y = hi - 1
	for k = 0, 7 do
		local d = 10 - k * 0.55
		part(c.m, { Name = "Tower", Shape = Enum.PartType.Cylinder, Size = Vector3.new(4, d, d), CFrame = CFrame.new(base.X, y + 2 + k * 4, base.Z) * CFrame.Angles(0, 0, math.pi / 2), Color = if k % 2 == 0 then rgb(236, 232, 224) else rgb(186, 60, 50), Material = Enum.Material.Concrete })
	end
	local topY = y + 32
	part(c.m, { Name = "Gallery", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, 9, 9), CFrame = CFrame.new(base.X, topY + 0.4, base.Z) * CFrame.Angles(0, 0, math.pi / 2), Color = rgb(60, 58, 60), Material = Enum.Material.Metal })
	local lamp = part(c.m, { Name = "Lamp", Shape = Enum.PartType.Cylinder, Size = Vector3.new(4, 4.4, 4.4), CFrame = CFrame.new(base.X, topY + 2.8, base.Z) * CFrame.Angles(0, 0, math.pi / 2), Color = rgb(255, 236, 170), Material = Enum.Material.Neon, CanCollide = false })
	part(c.m, { Class = "WedgePart", Name = "Cap", Size = Vector3.new(5.6, 2.4, 2.8), CFrame = CFrame.new(base.X, topY + 6, base.Z + 1.4), Color = rgb(60, 58, 60), Material = Enum.Material.Metal })
	part(c.m, { Class = "WedgePart", Name = "Cap", Size = Vector3.new(5.6, 2.4, 2.8), CFrame = CFrame.new(base.X, topY + 6, base.Z - 1.4) * CFrame.Angles(0, math.pi, 0), Color = rgb(60, 58, 60), Material = Enum.Material.Metal })
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness, light.Shadows = rgb(255, 230, 160), 60, 2, false
	light.Parent = lamp
	local beam = Instance.new("SpotLight")
	beam.Color, beam.Range, beam.Brightness, beam.Angle, beam.Face = rgb(255, 236, 190), 60, 4, 30, Enum.NormalId.Front
	beam.Parent = lamp
	-- Keeper's shed and a path of stepping stones.
	local shed = floor(c, 12, -4, 8, 7, 0.3)
	part(c.m, { Name = "ShedBox", Size = Vector3.new(7.4, 5.5, 6.4), CFrame = shed * CFrame.new(0, 2.75, 0), Color = rgb(236, 232, 224), Material = Enum.Material.WoodPlanks })
	gableRoof(c, shed, 8, 7, 5.5, rgb(186, 60, 50))
	for k = 1, 6 do
		local p = c.at(4 + k * 1.2, -9 - k * 2.4)
		part(c.m, { Name = "SteppingStone", Size = Vector3.new(2.4, 0.5, 2), CFrame = CFrame.new(p + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, k, 0), Color = STONE, Material = Enum.Material.Slate })
	end
end

-- A hermit's camp: one big painted teepee, a cookfire with a spit, a drying rack,
-- a woodpile and a totem.
function OUTPOSTS.hermit(c: Ctx)
	teepee(c, 0, 4, 7, 17, rgb(110, 90, 160))
	local fire = c.at(0, -8)
	Props.campfire(c.m, fire)
	for side = -1, 1, 2 do
		part(c.m, { Name = "SpitPost", Size = Vector3.new(0.4, 3.6, 0.4), CFrame = CFrame.new(fire + Vector3.new(side * 2.4, 1.8, 0)), Color = LOG_DARK, Material = Enum.Material.Wood })
	end
	part(c.m, { Name = "Spit", Size = Vector3.new(5.4, 0.25, 0.25), CFrame = CFrame.new(fire + Vector3.new(0, 3.4, 0)), Color = LOG_DARK, Material = Enum.Material.Wood })
	part(c.m, { Name = "Roast", Shape = Enum.PartType.Ball, Size = Vector3.new(1.8, 1.4, 1.4), CFrame = CFrame.new(fire + Vector3.new(0, 3.2, 0)), Color = rgb(150, 76, 44), Material = Enum.Material.SmoothPlastic, CanCollide = false })
	dryingRack(c, 9, -2, 1.3)
	Props.logPile(c.m, c.cf(-10, 0, 1.5))
	Props.totem(c.m, c.at(-6, -14), 10, c.look.LookVector)
end

Outposts.CAMPS = CAMPS
Outposts.OUTPOSTS = OUTPOSTS

-- Builds one place. `kind` is a key of CAMPS or OUTPOSTS. Returns the model.
function Outposts.place(parent: Instance, kind: string, label: string, centre: Vector3, facing: Vector3, ground: Ground, hooks): Model
	local m = Instance.new("Model")
	m.Name = label
	local c = ctxFor(m, centre, facing, ground)
	local builder = CAMPS[kind] or OUTPOSTS[kind]
	if CAMPS[kind] then
		builder(c, label, hooks.banner or Props.CLOTH[1], workspace.Terrain)
		m:SetAttribute("Camp", label)
	else
		builder(c, hooks)
		m:SetAttribute("Outpost", kind)
	end
	m.WorldPivot = CFrame.new(centre)
	m.Parent = parent
	return m
end

return Outposts
