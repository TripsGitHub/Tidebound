-- Shows the held tool in the player's hand and worn armour on their body.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Items)
local ItemModels = require(Shared.ItemModels)
local Config = require(Shared.Config)
local ArmourModels = require(Shared.ArmourModels)

local Appearance = {}

local function weldModel(model: Model, to: BasePart)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.CanCollide = false
			p.CanQuery = false
			p.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = to
			weld.Part1 = p
			weld.Parent = p
		end
	end
end

local function findPart(character: Model, names: { string }): BasePart?
	for _, name in names do
		local p = character:FindFirstChild(name)
		if p and p:IsA("BasePart") then
			return p
		end
	end
	return nil
end

function Appearance.setTool(player: Player, itemId: string?)
	local character = player.Character
	if not character then
		return
	end
	local old = character:FindFirstChild("HeldItem")
	if old then
		old:Destroy()
	end
	if not itemId or Items[itemId].kind ~= "tool" then
		return
	end
	local hand = findPart(character, { "RightHand", "Right Arm" })
	if not hand then
		return
	end
	local model = ItemModels.build(itemId)
	model:ScaleTo(Config.HeldScale) -- scales around the grip
	model.Name = "HeldItem"
	model:SetAttribute("ItemId", itemId)
	-- Grip at the bottom of the fist. Axes and harvesters stand up out of the fist;
	-- swords and clubs lean forward, blade out in front at about 40 degrees.
	local slash = Items[itemId].swing == "slash"
	local tilt = if slash then -55 elseif Items[itemId].swing == "shoot" then 0 else -90
	-- Blades are modelled with their edges left and right; the strike comes down from
	-- overhead, so turn the blade a quarter round its length to lead with the edge.
	local edge = if slash then CFrame.Angles(0, math.rad(90), 0) else CFrame.identity
	model:PivotTo(hand.CFrame * CFrame.new(0, -hand.Size.Y / 2 + 0.1, 0) * CFrame.Angles(math.rad(tilt), 0, 0) * edge)
	weldModel(model, hand)
	model.Parent = character
end

-- Where each armour slot sits, for R15 and R6 characters.
local SLOT_PARTS = {
	head = { { names = { "Head" }, offset = CFrame.new(0, 0.45, 0), scale = 1 } },
	body = { { names = { "UpperTorso", "Torso" }, offset = CFrame.new(0, 0, 0), scale = 1 } },
	legs = {
		{ names = { "LeftUpperLeg", "Left Leg" }, offset = CFrame.new(0, 0, 0), scale = 0.55, half = "left" },
		{ names = { "RightUpperLeg", "Right Leg" }, offset = CFrame.new(0, 0, 0), scale = 0.55, half = "right" },
	},
	feet = {
		{ names = { "LeftFoot", "Left Leg" }, offset = CFrame.new(0, 0, -0.1), scale = 1, half = "left", foot = true },
		{ names = { "RightFoot", "Right Leg" }, offset = CFrame.new(0, 0, -0.1), scale = 1, half = "right", foot = true },
	},
	bag = { { names = { "UpperTorso", "Torso" }, offset = CFrame.new(0, 0.1, 0.95), scale = 1 } },
	shield = { { names = { "LeftLowerArm", "Left Arm" }, offset = CFrame.new(-0.35, 0, 0), scale = 1 } },
}

local function simplePiece(itemId: string, attach: BasePart, spec): Model
	-- Builds a fitted shell around the body part instead of scaling the icon model.
	local item = Items[itemId]
	local model = ItemModels.build(itemId)
	local color = model.PrimaryPart.Color
	local material = model.PrimaryPart.Material
	if item.slot == "shield" then
		-- Strapped to the outside of the forearm, facing out to the side.
		model:ScaleTo(0.9)
		model:PivotTo(attach.CFrame * spec.offset * CFrame.Angles(0, math.rad(90), 0))
	elseif item.slot ~= "bag" then
		model:ClearAllChildren()
		local shell = Instance.new("Part")
		shell.Color = color
		shell.Material = material
		local size = attach.Size
		if item.slot == "head" then
			shell.Size = Vector3.new(size.X + 0.25, size.Y * 0.55, size.Z + 0.25)
		elseif item.slot == "body" then
			shell.Size = size + Vector3.new(0.2, 0.05, 0.2)
		elseif spec.foot then
			shell.Size = Vector3.new(size.X + 0.15, math.min(size.Y, 0.6) + 0.1, size.Z + 0.2)
		else
			shell.Size = size + Vector3.new(0.15, -size.Y * 0.2, 0.15)
		end
		shell.CFrame = attach.CFrame * (if spec.foot then CFrame.new(0, -size.Y / 2 + shell.Size.Y / 2 - 0.05, 0) else spec.offset)
		shell.Parent = model
		model.PrimaryPart = shell
	else
		-- Sit the bag against the wearer's back, however deep it is.
		local depth = model:GetExtentsSize().Z
		model:PivotTo(attach.CFrame * CFrame.new(0, spec.offset.Y, attach.Size.Z / 2 + depth / 2 - 0.08))
	end
	return model
end

function Appearance.setArmour(player: Player, armour: { [string]: string })
	local character = player.Character
	if not character then
		return
	end
	local folder = character:FindFirstChild("Armour")
	if folder then
		folder:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "Armour"
	for slot, itemId in armour do
		-- Real armour meshes, fitted to each body part (R15 only).
		local pieces = ArmourModels.wear(itemId, character)
		if #pieces > 0 then
			for _, piece in pieces do
				-- Clients read these to play the putting-on animation (Anim.lua).
				piece.model:SetAttribute("Slot", slot)
				piece.model:SetAttribute("ItemId", itemId)
				weldModel(piece.model, piece.part)
				piece.model.Parent = folder
			end
			continue
		end
		-- Otherwise: block shells (R6, or the meshes aren't imported), and bags.
		for _, spec in SLOT_PARTS[slot] or {} do
			local attach = findPart(character, spec.names)
			if attach then
				local piece = simplePiece(itemId, attach, spec)
				piece:SetAttribute("Slot", slot)
				piece:SetAttribute("ItemId", itemId)
				weldModel(piece, attach)
				piece.Parent = folder
			end
		end
	end
	folder.Parent = character
end

return Appearance
