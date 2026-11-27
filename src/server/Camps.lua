-- Camps: the man-made places on the islands. A palisade with a gate, tents, a totem,
-- a fire, crates, barrels, logs, torches, banners and a big carved sign. Every piece
-- stands on the ground under it (nothing floats on slopes). Camps are scenery and
-- meeting points for now; tribes will be able to claim them later.
local Props = require(script.Parent.Props)

local Camps = {}

local rng = Random.new(2024)

-- island name -> camp name and banner colour
local CAMPS = {
	["Clover Island"] = { "Tidecall Camp", Props.CLOTH[3] },
	["Pine Hills"] = { "Woodcutters' Camp", Props.CLOTH[1] },
	["Stone Shelf"] = { "Quarry Camp", Props.CLOTH[4] },
	["Frost Isle"] = { "Frostwatch", Props.CLOTH[3] },
	["Slime Marsh"] = { "Stilt Camp", Color3.fromRGB(120, 200, 90) },
	["Coral Atoll"] = { "Reef Camp", Props.CLOTH[2] },
	["Gold Mesa"] = { "Prospectors' Camp", Props.CLOTH[2] },
	["Silver Crags"] = { "Miners' Camp", Props.CLOTH[4] },
	["Old Ruins"] = { "Explorers' Camp", Props.CLOTH[1] },
	["Sunfruit Isle"] = { "Harvest Camp", Color3.fromRGB(255, 160, 60) },
}

local function onGround(groundAt, x: number, z: number, default: number): Vector3
	local hit = groundAt(x, z)
	return Vector3.new(x, if hit then hit.Position.Y else default, z)
end

-- Builds one camp at `centre` (on the ground), its gate facing `facing`.
function Camps.place(parent: Instance, name: string, banner: Color3, centre: Vector3, facing: Vector3, groundAt): Model
	local m = Instance.new("Model")
	m.Name = name
	local look = CFrame.lookAt(centre, centre + Vector3.new(facing.X, 0, facing.Z))
	local function at(x: number, z: number): Vector3
		local p = look * Vector3.new(x, 0, z)
		return onGround(groundAt, p.X, p.Z, centre.Y)
	end
	local function flatLook(p: Vector3, toward: Vector3): CFrame
		return CFrame.lookAt(p, Vector3.new(toward.X, p.Y, toward.Z))
	end

	-- The palisade: a ring of wall sections, open at the front for the gate.
	local R = 24
	local sections = 14
	for i = 1, sections - 1 do
		local a0 = (i - 0.5) / sections * math.pi * 2
		local a1 = (i + 0.5) / sections * math.pi * 2
		local p0 = at(math.sin(a0) * R, -math.cos(a0) * R)
		local p1 = at(math.sin(a1) * R, -math.cos(a1) * R)
		Props.palisade(m, p0 - Vector3.new(0, 0.5, 0), p1 - Vector3.new(0, 0.5, 0), 15)
	end
	-- Gate posts with torches at the way in.
	local gl, gr = at(-5.5, -R - 1), at(5.5, -R - 1)
	Props.torchPost(m, gl, 12)
	Props.torchPost(m, gr, 12)

	-- Inside: two tents at the back, the totem between them, a fire in the middle.
	local back = at(0, 14)
	Props.totem(m, back, 16, look.LookVector) -- faces the gate
	for side = -1, 1, 2 do
		local tp = at(side * 11, 9)
		Props.tent(m, tp, (centre - tp) * Vector3.new(1, 0, 1), 5)
	end
	Props.campfire(m, at(0, -2))

	-- Stores by the walls.
	Props.crateStack(m, flatLook(at(-15, -6), centre))
	Props.crateStack(m, flatLook(at(15, 2), centre))
	for k = 0, 2 do
		Props.barrel(m, CFrame.new(at(-14 + k * 2.8, 4 + (k % 2))))
	end
	Props.logPile(m, flatLook(at(14, -10), at(14, 0)))
	Props.banner(m, at(-8, -16), banner, 13)
	Props.banner(m, at(8, -16), banner, 13)
	Props.flowers(m, at(0, -R - 3), 5, 10)

	m.WorldPivot = CFrame.new(centre)
	m:SetAttribute("Camp", name)
	m.Parent = parent
	return m
end

-- islands: the island list; spotFor(isl) finds a flat open spot for a camp.
function Camps.build(islands: { any }, groundAt, spotFor: (any) -> Vector3?)
	local f = workspace:FindFirstChild("Camps") or Instance.new("Folder")
	f.Name = "Camps"
	f.Parent = workspace
	for _, isl in islands do
		local spec = CAMPS[isl.name]
		if spec then
			local spot = spotFor(isl)
			if spot then
				-- Gate facing the nearest coast, so you see it as you land.
				local out = Vector3.new(spot.X - isl.x, 0, spot.Z - isl.z)
				local facing = if out.Magnitude > 1 then out.Unit else Vector3.new(rng:NextNumber(-1, 1), 0, 1).Unit
				Camps.place(f, spec[1], spec[2], spot, facing, groundAt)
				task.wait()
			end
		end
	end
end

return Camps
