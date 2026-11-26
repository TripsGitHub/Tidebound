-- Puts a simple model of the held tool in the player's right hand.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Items = require(ReplicatedStorage:WaitForChild("Shared").Items)

local HeldItem = {}

local function makePart(name: string, size: Vector3, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	return part
end

function HeldItem.update(player: Player, itemId: string?)
	local character = player.Character
	if not character then
		return
	end
	local old = character:FindFirstChild("HeldItem")
	if old then
		old:Destroy()
	end
	local item = itemId and Items[itemId]
	if not item or item.kind ~= "tool" then
		return
	end
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if not hand or not hand:IsA("BasePart") then
		return
	end

	local model = Instance.new("Model")
	model.Name = "HeldItem"

	local size = item.handleSize or Vector3.new(0.3, 0.3, 2)
	local handle = makePart("Handle", size, item.color, if item.headColor then Enum.Material.Wood else Enum.Material.Slate)
	-- Hold it pointing forward out of the fist.
	handle.CFrame = hand.CFrame * CFrame.new(0, -hand.Size.Y / 2, -size.Z / 2 + 0.4)
	handle.Parent = model
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hand
	weld.Part1 = handle
	weld.Parent = handle

	if item.headColor then
		local head = makePart("Head", Vector3.new(0.35, 1.3, 0.6), item.headColor, Enum.Material.Slate)
		head.CFrame = handle.CFrame * CFrame.new(0, 0.45, -size.Z / 2 + 0.3)
		head.Parent = model
		local headWeld = Instance.new("WeldConstraint")
		headWeld.Part0 = handle
		headWeld.Part1 = head
		headWeld.Parent = head
	end

	model.Parent = character
end

return HeldItem
