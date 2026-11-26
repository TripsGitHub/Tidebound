-- Gates have no opening animation: the owner just walks through their own gates.
-- Collision is turned off on this client only, so everyone else still bumps into them.
local Players = game:GetService("Players")

local Gates = {}

local function update(model: Instance)
	if not model:IsA("Model") or model:GetAttribute("StructureType") ~= "WoodGate" then
		return
	end
	if model:GetAttribute("OwnerId") ~= Players.LocalPlayer.UserId then
		return
	end
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.CanCollide = false
		end
	end
end

function Gates.start()
	local structures = workspace:WaitForChild("Structures")
	for _, m in structures:GetChildren() do
		task.defer(update, m)
	end
	structures.ChildAdded:Connect(function(m)
		-- Attributes and parts can arrive a moment after the model itself.
		task.wait(0.2)
		update(m)
	end)
end

return Gates
