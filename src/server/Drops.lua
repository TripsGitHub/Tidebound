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

local Ores = require(Shared.Ores)
local Tiers = require(Shared.Tiers)

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

-- Loot priority: when something dies, whoever did the most damage to it gets first
-- pick of what it dropped for 5-10 seconds (longer the rarer the item); after that
-- anyone can take it.
local oreRank = {}
for i, ore in Ores do
	oreRank[ore.item] = i
end
local tierRank = {}
for i, tier in Tiers.list do
	tierRank[tier.id] = i
end
local RARE = { key_fragment = 4, maw_key = 5, queen_fang = 5, warden_core = 5, golem_heart = 5, supply_crate = 2 }

function Drops.prioritySeconds(itemId: string): number
	local item = Items[itemId]
	local bonus = RARE[itemId] or 0
	if oreRank[itemId] then
		bonus = math.max(bonus, math.ceil(oreRank[itemId] * 5 / #Ores))
	end
	if item and (item.kind == "tool" or item.kind == "armour") then
		local tier = string.match(itemId, "^(%a+)_")
		bonus = math.max(bonus, 1 + math.ceil((tierRank[tier or ""] or 1) * 4 / #Tiers.list))
	end
	return 5 + math.clamp(bonus, 0, 5)
end

-- Reserves a drop for `player` (no-op when player is nil).
function Drops.reserve(model: Model?, player: Player?)
	if not model or not player then
		return
	end
	local itemId = model:GetAttribute("ItemId") :: string
	model:SetAttribute("OwnerId", player.UserId)
	model:SetAttribute("OwnerName", player.DisplayName)
	model:SetAttribute("OwnerUntil", workspace:GetServerTimeNow() + Drops.prioritySeconds(itemId))
end

-- Who did the most damage, from a { [Player]: number } tally.
function Drops.topDamager(tally: { [Player]: number }?): Player?
	local best, most = nil, 0
	for p, d in tally or {} do
		if p.Parent and d > most then
			best, most = p, d
		end
	end
	return best
end

local function reservedFor(player: Player, model: Model): boolean
	local owner = model:GetAttribute("OwnerId")
	local untilT = model:GetAttribute("OwnerUntil")
	if not owner or owner == player.UserId or not untilT then
		return false
	end
	local left = untilT - workspace:GetServerTimeNow()
	if left <= 0 then
		return false
	end
	Remotes.Notify:FireClient(player, string.format("%s has first pick for %ds", model:GetAttribute("OwnerName") or "Someone", math.ceil(left)), "warn")
	return true
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
	-- Dead players can't grab anything (not even what they just dropped): only once
	-- they've respawned, like everyone else.
	local hum = player.Character:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 or hum:GetState() == Enum.HumanoidStateType.Dead then
		return nil
	end
	if (model:GetPivot().Position - root.Position).Magnitude > Config.PickupRange then
		return nil
	end
	return model
end

function Drops.pickUp(player: Player, drop: unknown)
	local model = validDrop(player, drop)
	if not model or reservedFor(player, model) then
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
	if not model or reservedFor(player, model) then
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
	-- Everything drops one at a time (click again for the next), each landing a
	-- little apart so they don't pile into one spot.
	if Inventory.take(player, itemId, 1) then
		local side = root.CFrame.RightVector * (math.random() - 0.5) * 2.4
		Drops.spawn(itemId, 1, root.Position + root.CFrame.LookVector * 3 + side, root.CFrame.LookVector)
	end
end

function Drops.setPickupCallback(fn: (Player, string, number) -> ())
	onPickedUp = fn
end

return Drops
