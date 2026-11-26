-- When you die, everything you carry drops in a loot sack anyone can pick up.
-- You keep your Rock so you can always start again.
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
	sack.Shape = Enum.PartType.Ball
	sack.Size = Vector3.new(2.4, 2.4, 2.4)
	sack.Color = Color3.fromRGB(150, 115, 75)
	sack.Material = Enum.Material.Fabric
	sack.Anchored = true
	sack.CanCollide = false

	-- Drop it on the ground under where you died.
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain, workspace:FindFirstChild("TestGround") or workspace.Terrain, workspace.Structures }
	local hit = workspace:Raycast(position + Vector3.new(0, 2, 0), Vector3.new(0, -60, 0), params)
	sack.Position = if hit then hit.Position + Vector3.new(0, 1.2, 0) else position

	local knot = Instance.new("Part")
	knot.Name = "Knot"
	knot.Size = Vector3.new(0.7, 0.6, 0.7)
	knot.Color = Color3.fromRGB(110, 80, 50)
	knot.Material = Enum.Material.Fabric
	knot.Anchored = true
	knot.CanCollide = false
	knot.Position = sack.Position + Vector3.new(0, 1.3, 0)
	knot.Parent = sack

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Loot"
	prompt.ObjectText = ownerName .. "'s sack"
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = sack

	local taken = false
	prompt.Triggered:Connect(function(looter)
		if taken then
			return
		end
		taken = true
		for itemId, amount in items do
			Inventory.add(looter, itemId, amount)
		end
		Remotes.Notify:FireClient(looter, "Looted " .. ownerName .. "'s sack")
		sack:Destroy()
	end)

	sack.Parent = workspace.LootSacks
	Debris:AddItem(sack, Config.LootSackLifetime)
end

function Death.onDied(player: Player, character: Model)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local items = Inventory.getAll(player)
	items.rock = nil
	Inventory.clear(player)
	if root and next(items) then
		spawnSack(player.Name, root.Position, items)
	end
end

return Death
