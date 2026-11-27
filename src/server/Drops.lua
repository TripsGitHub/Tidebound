-- Items lying on the ground. Gathering, hunting and dropping all create these;
-- players walk up and press F to pick them up (or E to eat food).
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local ItemModels = require(Shared.ItemModels)
local Remotes = require(Shared.Remotes)
local Inventory = require(script.Parent.Inventory)

local Drops = {}
local onPickedUp: ((Player, string, number) -> ())? = nil

local function dropFolder(): Folder
	return workspace:WaitForChild("Drops") :: Folder
end

-- Spawns `amount` of an item as one pile at `position`, tossed in `direction`.
function Drops.spawn(itemId: string, amount: number, position: Vector3, direction: Vector3?): Model?
	if amount <= 0 or not Items[itemId] then
		return nil
	end
	local model = ItemModels.build(itemId)
	model:ScaleTo(Config.DropScale)
	model.Name = "Drop"
	model:SetAttribute("ItemId", itemId)
	model:SetAttribute("Amount", amount)
	local spin = CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
	model:PivotTo(CFrame.new(position) * spin)

	-- Physics: the main part collides so it lands on the ground; the rest is welded on.
	local primary = model.PrimaryPart :: BasePart
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.CanQuery = true
			if p ~= primary then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = primary
				weld.Part1 = p
				weld.Parent = p
			end
		end
	end
	primary.CanCollide = true
	primary.Massless = false
	primary.CustomPhysicalProperties = PhysicalProperties.new(1, 0.6, 0.1)

	model.Parent = dropFolder()
	primary:SetNetworkOwner(nil)
	local dir = (direction or Vector3.new(math.random() - 0.5, 0, math.random() - 0.5))
	dir = Vector3.new(dir.X, 0, dir.Z)
	if dir.Magnitude > 0 then
		dir = dir.Unit
	end
	local scatter = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5) * 6
	primary.AssemblyLinearVelocity = dir * math.random(6, 12) + scatter + Vector3.new(0, math.random(14, 20), 0)
	primary.AssemblyAngularVelocity = Vector3.new(math.random(-8, 8), math.random(-8, 8), math.random(-8, 8))

	-- Settle: once it lands, anchor it so hundreds of drops don't cost physics.
	task.delay(2.5, function()
		if model.Parent then
			for _, p in model:GetDescendants() do
				if p:IsA("BasePart") then
					p.Anchored = true
				end
			end
			primary.CanCollide = false
		end
	end)
	Debris:AddItem(model, Config.DropLifetime)
	return model
end

local function validDrop(player: Player, drop: unknown): Model?
	if typeof(drop) ~= "Instance" or not (drop :: Instance):IsA("Model") then
		return nil
	end
	local model = drop :: Model
	if model.Parent ~= dropFolder() or not model:GetAttribute("ItemId") then
		return nil
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
	if (model:GetPivot().Position - root.Position).Magnitude > Config.PickupRange then
		return nil
	end
	return model
end

function Drops.pickUp(player: Player, drop: unknown)
	local model = validDrop(player, drop)
	if not model then
		return
	end
	local itemId = model:GetAttribute("ItemId") :: string
	local amount = model:GetAttribute("Amount") :: number
	local added = Inventory.add(player, itemId, amount)
	if added <= 0 then
		Remotes.Notify:FireClient(player, "Bag too full!", "warn")
		return
	end
	Remotes.PickedUp:FireClient(player, itemId, added)
	if onPickedUp then
		onPickedUp(player, itemId, added)
	end
	if added < amount then
		model:SetAttribute("Amount", amount - added)
		Remotes.Notify:FireClient(player, "Bag too full!", "warn")
	else
		model:Destroy()
	end
end

-- Eat food straight off the ground.
function Drops.eat(player: Player, drop: unknown, eatFn: (Player, string) -> boolean)
	local model = validDrop(player, drop)
	if not model then
		return
	end
	local itemId = model:GetAttribute("ItemId") :: string
	if Items[itemId].kind ~= "food" then
		return
	end
	if eatFn(player, itemId) then
		local amount = (model:GetAttribute("Amount") :: number) - 1
		if amount <= 0 then
			model:Destroy()
		else
			model:SetAttribute("Amount", amount)
		end
	end
end

-- Drop one of an item from your bag onto the ground in front of you.
function Drops.dropFromBag(player: Player, itemId: unknown)
	if type(itemId) ~= "string" or not Items[itemId] then
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local count = Inventory.count(player, itemId)
	if count <= 0 then
		return
	end
	-- Tools/armour drop one at a time; resources drop the whole stack.
	local kind = Items[itemId].kind
	local amount = if kind == "resource" or kind == "food" then count else 1
	if Inventory.take(player, itemId, amount) then
		Drops.spawn(itemId, amount, root.Position + root.CFrame.LookVector * 3, root.CFrame.LookVector)
	end
end

function Drops.setPickupCallback(fn: (Player, string, number) -> ())
	onPickedUp = fn
end

return Drops
