-- When you die you drop what you had out: the tool in your hand and the armour you
-- were wearing (not your bag). They fall loose on the ground for anyone to pick up.
-- Everything in your bag stays with you, and so does your Rock. Whoever did the most
-- damage to you gets 5-10 seconds of first pick.
local Drops = require(script.Parent.Drops)
local Inventory = require(script.Parent.Inventory)
local Harvest = require(script.Parent.Harvest)
local Combat = require(script.Parent.Combat)

local Death = {}

-- Drop the held tool (not the Rock) and worn armour (not the bag) on the ground
-- under the character. Used on death, and when someone leaves while in combat.
function Death.dropGear(player: Player, character: Model?): Vector3?
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not character or not root then
		return nil
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
	-- Whoever did the most damage gets first pick (see Drops.reserve).
	local top = Drops.topDamager(Harvest.damageBy[character])
	for _, itemId in lost do
		if Inventory.take(player, itemId, 1) then
			Drops.reserve(Drops.spawn(itemId, 1, at), top)
		end
	end
	return at
end

function Death.onDied(player: Player, character: Model)
	local at = Death.dropGear(player, character)
	-- Kill feed, and a Soul for a PvP kill (the killer gets first pick of it).
	Combat.onDied(player, at, function(itemId: string, amount: number, where: Vector3, killer: Player)
		Drops.reserve(Drops.spawn(itemId, amount, where), killer)
	end)
end

return Death
