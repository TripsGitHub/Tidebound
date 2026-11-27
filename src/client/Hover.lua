-- Works out what the player is pointing at, every frame.
-- Gives the hover panel its text and tells input what F / E / click would act on.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Pointer = require(script.Parent.Pointer)

local player = Players.LocalPlayer
local Hover = {}

export type Info = {
	target: Model?,
	kind: string?, -- "drop" | "node" | "structure" | "animal" | "player"
	name: string?,
	hp: number?,
	maxHp: number?,
	inRange: boolean,
}

local current: Info = { inRange = false }
local highlight = Instance.new("Highlight")
highlight.FillTransparency = 1
highlight.OutlineColor = Color3.fromRGB(255, 240, 200)
highlight.OutlineTransparency = 0.2
highlight.DepthMode = Enum.HighlightDepthMode.Occluded

local function classify(inst: Instance?): (Model?, string?)
	while inst and inst ~= workspace do
		if inst:IsA("Model") then
			local parent = inst.Parent
			if parent and parent.Name == "Drops" and parent.Parent == workspace then
				return inst, "drop"
			elseif inst:GetAttribute("NodeType") then
				return inst, "node"
			elseif inst:GetAttribute("StructureType") then
				return inst, "structure"
			elseif inst:GetAttribute("AnimalType") then
				return inst, "animal"
			elseif Players:GetPlayerFromCharacter(inst) then
				return inst, "player"
			end
		end
		inst = inst.Parent
	end
	return nil, nil
end

local function distanceTo(model: Model): number
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return math.huge
	end
	local cf, size = model:GetBoundingBox()
	local offset = cf:PointToObjectSpace(root.Position)
	local half = size / 2
	local closest = Vector3.new(math.clamp(offset.X, -half.X, half.X), math.clamp(offset.Y, -half.Y, half.Y), math.clamp(offset.Z, -half.Z, half.Z))
	return (offset - closest).Magnitude
end

-- The nearest drop to the player (for F when not pointing at one).
function Hover.nearestDrop(): Model?
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local drops = workspace:FindFirstChild("Drops")
	if not root or not drops then
		return nil
	end
	local best, bestDist = nil, Config.PickupRange - 1
	for _, d in drops:GetChildren() do
		if d:IsA("Model") then
			local dist = (d:GetPivot().Position - root.Position).Magnitude
			if dist < bestDist then
				best, bestDist = d, dist
			end
		end
	end
	return best
end

function Hover.get(): Info
	return current
end

-- Name and range for a drop, for the pickup prompt on a drop you clicked.
function Hover.dropInfo(model: Model): (string, boolean, number)
	local itemId = model:GetAttribute("ItemId")
	local amount = model:GetAttribute("Amount") or 1
	local item = Items[itemId]
	local name = (if item then item.name else "Item") .. (if amount > 1 then " x" .. amount else "")
	local d = distanceTo(model)
	return name, d <= Config.PickupRange, d
end

local function update()
	local exclude: { Instance } = { workspace.CurrentCamera }
	if player.Character then
		table.insert(exclude, player.Character)
	end
	local hit = Pointer.cast(exclude, 120)
	local model, kind = classify(hit and hit.Instance)
	if model and kind then
		local info: Info = { target = model, kind = kind, inRange = false }
		if kind == "drop" then
			local itemId = model:GetAttribute("ItemId")
			local amount = model:GetAttribute("Amount") or 1
			info.name = Items[itemId].name .. (if amount > 1 then " x" .. amount else "")
			info.inRange = distanceTo(model) <= Config.PickupRange
		elseif kind == "player" then
			local hum = model:FindFirstChildOfClass("Humanoid")
			info.name = model.Name
			info.hp = hum and hum.Health
			info.maxHp = hum and hum.MaxHealth
			info.inRange = distanceTo(model) <= Config.HitRange
		else
			info.name = model:GetAttribute("DisplayName") or model.Name
			info.hp = model:GetAttribute("HP")
			info.maxHp = model:GetAttribute("MaxHP")
			info.inRange = distanceTo(model) <= Config.HitRange
			if model:GetAttribute("Depleted") then
				model, info = nil, { inRange = false }
			end
		end
		current = info
		highlight.Adornee = model
		highlight.Parent = if model then workspace.CurrentCamera else nil
	else
		current = { inRange = false }
		highlight.Adornee = nil
		highlight.Parent = nil
	end
end

-- Re-reads what's under the pointer right now (a tap moves the pointer between frames).
Hover.refresh = update

function Hover.start()
	RunService.RenderStepped:Connect(update)
end

return Hover
