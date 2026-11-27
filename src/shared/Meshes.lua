-- Builds models from the Blender meshes imported into the place.
--
-- The meshes live in ReplicatedStorage.Models (imported from
-- assets/models/tidebound_models.obj; Rojo doesn't manage that folder). Every MeshPart
-- is named "<model>__<Part>", e.g. "pine__Trunk". A model is all parts with its prefix.
--
-- Built models have their pivot at the bottom-centre of their bounding box, so
-- PivotTo(groundCFrame) stands them on the ground. Models with a "<model>__Bounds" part
-- (armour, newer tools and bags) measure from that box and leave it out of the model. If the meshes are missing,
-- Meshes.has() returns false and callers fall back to their block models.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MeshColors = require(script.Parent.MeshColors)

local Meshes = {}

-- Materials that shouldn't look like plastic.
local LOOKS: { [string]: { material: Enum.Material?, transparency: number? } } = {
	Ember = { material = Enum.Material.Neon },
	SlimeGoo = { material = Enum.Material.Glass, transparency = 0.15 },
	SlimeLight = { material = Enum.Material.Glass, transparency = 0.1 },
	Lava = { material = Enum.Material.Neon },
	CrawlerGlow = { material = Enum.Material.Neon },
	QueenGlow = { material = Enum.Material.Neon },
	CrystalGlow = { material = Enum.Material.Neon },
	Crystal = { material = Enum.Material.Glass, transparency = 0.15 },
	SlimeCore = { material = Enum.Material.Glass, transparency = 0.2 },
	SkullBone = { material = Enum.Material.Limestone },
	SkullShade = { material = Enum.Material.Limestone },
	TentHide = { material = Enum.Material.Fabric },
	TentHideDark = { material = Enum.Material.Fabric },
	TentStripe = { material = Enum.Material.Fabric },
	SignBoard = { material = Enum.Material.Wood },
	SignPost = { material = Enum.Material.Wood },
	WardenStone = { material = Enum.Material.Slate },
	GolemRock = { material = Enum.Material.Basalt },
}

-- Thin or soft parts you can walk through.
local SOFT = { "Leaf", "Leaves", "Frond", "Needle", "Berr", "Coconut", "Ember", "Moss" }

local sets: { [string]: { MeshPart } }? = nil

local function load(): { [string]: { MeshPart } }
	if sets then
		return sets
	end
	local found: { [string]: { MeshPart } } = {}
	local root = ReplicatedStorage:FindFirstChild("Models")
	if root then
		for _, d in root:GetDescendants() do
			if d:IsA("MeshPart") then
				local prefix = d.Name:match("^(.-)__")
				if prefix then
					found[prefix] = found[prefix] or {}
					table.insert(found[prefix], d)
				end
			end
		end
	end
	sets = found
	return found
end

function Meshes.has(name: string): boolean
	return load()[name] ~= nil
end

local function isSoft(partName: string): boolean
	for _, word in SOFT do
		if partName:find(word) then
			return true
		end
	end
	return false
end

export type Options = {
	-- Uniform scale (default 1).
	scale: number?,
	-- Stretch each axis so the bounding box is exactly this size (overrides scale).
	fit: Vector3?,
	-- Scale evenly so the wider of X and Z is this many studs (overrides scale).
	width: number?,
	-- Pivot at the centre of the bounding box instead of the bottom.
	centre: boolean?,
	-- Whether solid parts collide (default true).
	collide: boolean?,
}

-- Size of a model's Bounds box (or of all its parts), or nil if the mesh isn't in the place.
function Meshes.size(name: string): Vector3?
	local source = load()[name]
	if not source then
		return nil
	end
	local lo = Vector3.one * math.huge
	local hi = -lo
	for _, p in source do
		if p.Name == name .. "__Bounds" then
			return p.Size
		end
		lo = lo:Min(p.Position - p.Size / 2)
		hi = hi:Max(p.Position + p.Size / 2)
	end
	return hi - lo
end

-- Returns a new Model (PrimaryPart = biggest part), or nil if the mesh isn't in the place.
function Meshes.build(name: string, options: Options?): Model?
	local source = load()[name]
	if not source then
		return nil
	end
	local opts: Options = options or {}

	-- Bounding box of the source parts, in their imported positions. A model with an
	-- invisible "Bounds" part uses that box instead (it marks the origin and the fit size).
	local lo = Vector3.one * math.huge
	local hi = -lo
	local bounds: MeshPart? = nil
	for _, p in source do
		if p.Name == name .. "__Bounds" then
			bounds = p
		end
	end
	for _, p in if bounds then { bounds } else source do
		local half = p.Size / 2
		lo = lo:Min(p.Position - half)
		hi = hi:Max(p.Position + half)
	end
	local size = hi - lo
	local origin = Vector3.new((lo.X + hi.X) / 2, if opts.centre then (lo.Y + hi.Y) / 2 else lo.Y, (lo.Z + hi.Z) / 2)
	local k = if opts.fit
		then Vector3.new(opts.fit.X / size.X, opts.fit.Y / size.Y, opts.fit.Z / size.Z)
		elseif opts.width then Vector3.one * (opts.width / math.max(size.X, size.Z))
		else Vector3.one * (opts.scale or 1)

	local model = Instance.new("Model")
	model.Name = name
	local primary: MeshPart? = nil
	for _, src in source do
		if src == bounds then
			continue
		end
		local p = src:Clone()
		local short = src.Name:sub(#name + 3)
		p.Name = short
		local rot = src.CFrame - src.Position
		p.Size = src.Size * k
		p.CFrame = CFrame.new((src.Position - origin) * k) * rot
		local colour = MeshColors[src.Name]
		if colour then
			p.Color = colour[1]
			local look = LOOKS[colour[2]]
			if look then
				p.Material = look.material or Enum.Material.SmoothPlastic
				p.Transparency = look.transparency or 0
			else
				p.Material = Enum.Material.SmoothPlastic
			end
		end
		p.Anchored = true
		p.CanCollide = opts.collide ~= false and not isSoft(short)
		p.CanTouch = false
		p:SetAttribute("BaseTransparency", p.Transparency)
		p:SetAttribute("BaseCollide", p.CanCollide)
		p.Parent = model
		if not primary or p.Size.Magnitude > primary.Size.Magnitude then
			primary = p
		end
	end
	model.PrimaryPart = primary
	if primary then
		primary.PivotOffset = primary.CFrame:Inverse() -- the model's pivot is the origin it was built around
	end
	return model
end

return Meshes
