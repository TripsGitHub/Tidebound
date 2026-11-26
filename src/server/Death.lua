-- When you die, everything you carry drops in a loot sack anyone can take.
-- You keep your Rock and the bag you're wearing.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Inventory = require(script.Parent.Inventory)

local Death = {}

local function spawnSack(ownerName: string, position: Vector3, items: { [string]: number })
	local sack = Instance.new("Part")
	sack.Name = "LootSack"
	sack.Size = Vector3.new(2.2, 2, 2.2)
	sack.Color = Color3.fromRGB(150, 115, 75)
	sack.Material = Enum.Material.Fabric
	sack.Anchored = true
	sack.CanCollide = false

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain, workspace.Structures }
	local hit = workspace:Raycast(position + Vector3.new(0, 2, 0), Vector3.new(0, -80, 0), params)
	sack.CFrame = CFrame.new(if hit then hit.Position + Vector3.new(0, 1, 0) else position) * CFrame.Angles(0, math.random() * 6, 0)

	local tie = Instance.new("Part")
	tie.Size = Vector3.new(0.9, 0.6, 0.9)
	tie.Color = Color3.fromRGB(110, 80, 50)
	tie.Material = Enum.Material.Fabric
	tie.Anchored = true
	tie.CanCollide = false
	tie.CFrame = sack.CFrame * CFrame.new(0, 1.2, 0) * CFrame.Angles(0, 0.7, 0)
	tie.Parent = sack

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Loot"
	prompt.ObjectText = ownerName .. "'s sack"
	prompt.HoldDuration = 0.6
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = sack

	local busy = false
	prompt.Triggered:Connect(function(looter)
		if busy then
			return
		end
		busy = true
		local left = 0
		for itemId, amount in items do
			local added = Inventory.add(looter, itemId, amount)
			items[itemId] = if amount - added > 0 then amount - added else nil
			left += amount - added
		end
		if left > 0 then
			Remotes.Notify:FireClient(looter, "Bag too full!", "warn")
			busy = false
		else
			sack:Destroy()
		end
	end)

	sack.Parent = workspace.LootSacks
	Debris:AddItem(sack, Config.LootSackLifetime)
end

function Death.onDied(player: Player, character: Model)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local items = Inventory.getAll(player)
	local keep: { [string]: boolean } = { rock = true }
	local bag = Inventory.getArmour(player).bag
	if bag then
		keep[bag] = true
	end
	for itemId in keep do
		if items[itemId] then
			items[itemId] -= 1
			if items[itemId] <= 0 then
				items[itemId] = nil
			end
		end
	end
	Inventory.clearExcept(player, keep)
	if root and next(items) then
		spawnSack(player.Name, root.Position, items)
	end
end

return Death
