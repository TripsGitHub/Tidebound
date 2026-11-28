-- Who may use a build (open a chest or gate, ride a cart, tend a plant box).
-- Always its owner. Their tribe mates too, unless the owner has locked it: a locked
-- build is the owner's alone, even to their own tribe.
local Access = {}

function Access.canUse(player: Player, model: Instance): boolean
	local owner = model:GetAttribute("OwnerId")
	if owner == nil or owner == player.UserId then
		return true
	end
	if model:GetAttribute("Locked") then
		return false
	end
	local tribe = player:GetAttribute("Tribe")
	return tribe ~= nil and tribe == model:GetAttribute("OwnerTribe")
end

-- Builds that can be locked.
function Access.lockable(def: any): boolean
	return def ~= nil and (def.chest ~= nil or def.gate == true or def.planter == true or def.cart == true)
end

return Access
