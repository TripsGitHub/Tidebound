-- When you die you drop what you had out: the tool in your hand and the armour you
-- were wearing (not your bag). They fall loose on the ground for anyone to pick up.
-- Everything in your bag stays with you, and so does your Rock.
local Drops = require(script.Parent.Drops)
local Inventory = require(script.Parent.Inventory)

local Death = {}

function Death.onDied(player: Player, character: Model)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local lost: { string } = {}
	local held = Inventory.getEquipped(player)
	if held and held ~= "rock" then
		table.insert(lost, held)
	end
	for slot, itemId in Inventory.getArmour(player) do
		if slot ~= "bag" and not table.find(lost, itemId) then
			table.insert(lost, itemId)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	local hit = workspace:Raycast(root.Position + Vector3.new(0, 2, 0), Vector3.new(0, -80, 0), params)
	local at = (if hit then hit.Position else root.Position) + Vector3.new(0, 2, 0)
	for _, itemId in lost do
		if Inventory.take(player, itemId, 1) then
			Drops.spawn(itemId, 1, at)
		end
	end
end

return Death
