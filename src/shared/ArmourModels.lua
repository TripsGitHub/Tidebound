-- Builds worn armour from the Blender meshes (assets/models/blender/set3.py).
--
-- Each slot is made of pieces, and each piece is worn on one body part. A piece's mesh
-- is centred on that part and modelled around the R15 reference size below, so scaling
-- it by part.Size / reference fits it to any R15 avatar (wide, tall or slim).
-- The same pieces, put on a reference rig, make the item's icon and dropped model.
local Meshes = require(script.Parent.Meshes)
local Tiers = require(script.Parent.Tiers)

local ArmourModels = {}

-- R15 reference part sizes (the size each mesh was modelled for).
local REF: { [string]: Vector3 } = {
	Head = Vector3.new(1.2, 1.2, 1.2),
	UpperTorso = Vector3.new(2, 1.6, 1),
	LowerTorso = Vector3.new(2, 0.4, 1),
	UpperArm = Vector3.new(1, 1.169, 1),
	UpperLeg = Vector3.new(1, 1.217, 1),
	LowerLeg = Vector3.new(1, 1.193, 1),
}

type Piece = { piece: string, part: string, ref: string, turn: boolean? }

-- turn: the piece is modelled for the right side, so the left one is turned around.
local SLOTS: { [string]: { Piece } } = {
	head = { { piece = "helmet", part = "Head", ref = "Head" } },
	body = {
		{ piece = "chest", part = "UpperTorso", ref = "UpperTorso" },
		{ piece = "pauldron", part = "RightUpperArm", ref = "UpperArm" },
		{ piece = "pauldron", part = "LeftUpperArm", ref = "UpperArm", turn = true },
	},
	legs = {
		{ piece = "hip", part = "LowerTorso", ref = "LowerTorso" },
		{ piece = "thigh", part = "RightUpperLeg", ref = "UpperLeg" },
		{ piece = "thigh", part = "LeftUpperLeg", ref = "UpperLeg" },
	},
	feet = {
		{ piece = "boot", part = "RightLowerLeg", ref = "LowerLeg" },
		{ piece = "boot", part = "LeftLowerLeg", ref = "LowerLeg" },
	},
}

-- Where each part sits on a standing R15 rig, relative to the UpperTorso (for icons).
local RIG: { [string]: Vector3 } = {
	Head = Vector3.new(0, 1.4, 0),
	UpperTorso = Vector3.zero,
	LowerTorso = Vector3.new(0, -1, 0),
	RightUpperArm = Vector3.new(1.5, 0.2, 0),
	LeftUpperArm = Vector3.new(-1.5, 0.2, 0),
	RightUpperLeg = Vector3.new(0.5, -1.55, 0),
	LeftUpperLeg = Vector3.new(-0.5, -1.55, 0),
	RightLowerLeg = Vector3.new(0.5, -2.35, 0),
	LeftLowerLeg = Vector3.new(-0.5, -2.35, 0),
}

local SLOT_KEY = { helmet = "head", body = "body", legs = "legs", boots = "feet" }

-- "gold_body" -> gold tier, "body" slot. Nil if it isn't tiered armour.
local function parse(itemId: string): (Tiers.Tier?, string?)
	local tier, rest = Tiers.split(itemId)
	local slot = rest and SLOT_KEY[rest]
	if tier and slot then
		return tier, slot
	end
	return nil, nil
end

-- Whether this item has armour meshes in the place.
function ArmourModels.has(itemId: string): boolean
	local tier, slot = parse(itemId)
	if not tier or not slot then
		return false
	end
	return Meshes.has("armour_" .. tier.style .. "_" .. SLOTS[slot][1].piece)
end

local function buildPiece(tier: Tiers.Tier, spec: Piece, partSize: Vector3): Model?
	local name = "armour_" .. tier.style .. "_" .. spec.piece
	local bounds = Meshes.size(name)
	if not bounds then
		return nil
	end
	local model = Meshes.build(name, { centre = true, fit = bounds * (partSize / REF[spec.ref]), collide = false })
	if model then
		Tiers.paint(model, tier)
		for _, p in model:GetChildren() do
			local part = p :: BasePart
			part.CanQuery = false
			part.CanTouch = false
			part.Massless = true
		end
	end
	return model
end

-- Builds the pieces of a worn item on a character. Returns one model per piece, each
-- already placed on its body part (not welded). Empty if the character isn't R15.
function ArmourModels.wear(itemId: string, character: Model): { { model: Model, part: BasePart } }
	local out = {}
	local tier, slot = parse(itemId)
	if not tier or not slot then
		return out
	end
	for _, spec in SLOTS[slot] do
		local part = character:FindFirstChild(spec.part)
		if part and part:IsA("BasePart") then
			local model = buildPiece(tier, spec, part.Size)
			if model then
				model:PivotTo(part.CFrame * (if spec.turn then CFrame.Angles(0, math.pi, 0) else CFrame.identity))
				table.insert(out, { model = model, part = part })
			end
		end
	end
	return out
end

-- The whole item on an invisible reference rig, as one model (for icons and drops).
-- Pivot is the centre of the pieces. Nil if the meshes aren't in the place.
function ArmourModels.build(itemId: string): Model?
	local tier, slot = parse(itemId)
	if not tier or not slot or not ArmourModels.has(itemId) then
		return nil
	end
	local result = Instance.new("Model")
	result.Name = itemId
	local primary: BasePart? = nil
	for _, spec in SLOTS[slot] do
		local model = buildPiece(tier, spec, REF[spec.ref])
		if model then
			model:PivotTo(CFrame.new(RIG[spec.part]) * (if spec.turn then CFrame.Angles(0, math.pi, 0) else CFrame.identity))
			for _, p in model:GetChildren() do
				p.Parent = result
				local part = p :: BasePart
				if not primary or part.Size.Magnitude > primary.Size.Magnitude then
					primary = part
				end
			end
			model:Destroy()
		end
	end
	if not primary then
		result:Destroy()
		return nil
	end
	result.PrimaryPart = primary
	local centre = result:GetBoundingBox()
	primary.PivotOffset = primary.CFrame:ToObjectSpace(centre)
	result:PivotTo(CFrame.new())
	return result
end

return ArmourModels
