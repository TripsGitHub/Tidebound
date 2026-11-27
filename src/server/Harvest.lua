-- A player swings at something. The client only says "I hit this";
-- the server checks reach, swing speed and tool, then gathers, damages or hurts.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Nodes = require(Shared.Nodes)
local Remotes = require(Shared.Remotes)
local Inventory = require(script.Parent.Inventory)
local Progression = require(script.Parent.Progression)
local Drops = require(script.Parent.Drops)
local Animals = require(script.Parent.Animals)

local Harvest = {}
local nextSwing: { [Player]: number } = {}

local function setVisible(model: Model, visible: boolean)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			if visible then
				p.Transparency = p:GetAttribute("BaseTransparency") or 0
				p.CanCollide = p:GetAttribute("BaseCollide") ~= false
				p.CanQuery = true
			else
				p.Transparency = 1
				p.CanCollide = false
				p.CanQuery = false
			end
		end
	end
end

local function respawnLater(model: Model, def, home: CFrame)
	task.delay(def.respawn, function()
		if model.Parent then
			model:PivotTo(home)
			model:SetAttribute("HP", def.hp)
			model:SetAttribute("Depleted", false)
			setVisible(model, true)
		end
	end)
end

-- Rolls what a broken node gives: { { item, amount } }.
local function rollLoot(def): { { item: string, amount: number } }
	local loot = {}
	for _, drop in def.drops do
		local amount = math.random(drop.min, drop.max)
		if amount > 0 then
			table.insert(loot, { item = drop.item, amount = amount })
		end
	end
	return loot
end

local function deplete(player: Player, model: Model, def, _awayFrom: Vector3)
	model:SetAttribute("Depleted", true)
	Progression.addXp(player, def.xp)
	local loot = rollLoot(def)
	-- Trees no longer topple: everything just breaks off and drops, like rocks.
	local home = model:GetPivot()
	setVisible(model, false)
	local center = home.Position + Vector3.new(0, 2, 0)
	local mult = model:GetAttribute("LootMult") or 1 -- giant event ores give more
	for _, drop in loot do
		for _ = 1, drop.amount * mult do
			local a = math.random() * math.pi * 2
			Drops.spawn(drop.item, 1, center, Vector3.new(math.cos(a), 0.6, math.sin(a)))
		end
	end
	if model:GetAttribute("Temporary") then
		model:Destroy() -- world-event nodes (Events.lua) don't grow back
	else
		respawnLater(model, def, home)
	end
end

local function hitNode(player: Player, model: Model, item, rootPos: Vector3)
	local def = Nodes[model:GetAttribute("NodeType")]
	if not def or model:GetAttribute("Depleted") then
		return
	end
	-- Cave seals are broken with swords (any sword), not harvesters or rocks. Each hit
	-- takes the sword's damage off the seal, so a better sword is just quicker.
	if def.seal then
		local held = Inventory.getEquipped(player) or ""
		if item.swing ~= "slash" or not (string.find(held, "sword") or string.find(held, "blade")) then
			Remotes.Notify:FireClient(player, "Cave seals can only be broken with a sword", "warn")
			return
		end
		local dmg = item.damage or 1
		local left = math.max((model:GetAttribute("HP") or def.hp) - dmg, 0)
		Remotes.Marker:FireClient(player, model:GetBoundingBox().Position, dmg, "hit", Inventory.getEquipped(player))
		model:SetAttribute("HP", left)
		Remotes.HitFeedback:FireAllClients(model)
		if left <= 0 then
			deplete(player, model, def, rootPos)
		end
		return
	end
	local power = item.gather and item.gather[def.material] or 0
	if power <= 0 then
		Remotes.Notify:FireClient(player, "Your tool can't harvest that", "warn")
		return
	end
	if def.minPower and power < def.minPower then
		Remotes.Notify:FireClient(player, "You need a stronger harvester to mine " .. def.name, "warn")
		return
	end
	-- Hits only wear it down; the loot and XP come out when it breaks.
	local hp = math.max((model:GetAttribute("HP") or def.hp) - power, 0)
	Remotes.Marker:FireClient(player, model:GetBoundingBox().Position, power, "harvest", Inventory.getEquipped(player))
	model:SetAttribute("HP", hp)
	Remotes.HitFeedback:FireAllClients(model)
	if hp <= 0 then
		deplete(player, model, def, rootPos)
	end
end

local function hitStructure(player: Player, model: Model, item)
	-- Bases are broken with weapons: harvesters and the rock can't damage them.
	if item.swing ~= "slash" then
		Remotes.Notify:FireClient(player, "Use a weapon to break structures", "warn")
		return false
	end
	local hp = (model:GetAttribute("HP") or 0) - (item.damage or Config.UnarmedDamage)
	model:SetAttribute("HP", hp)
	Remotes.HitFeedback:FireAllClients(model)
	if hp <= 0 then
		model:Destroy()
	end
	return true
end

-- character -> { [Player]: damage } from other players, cleared when it's removed.
Harvest.damageBy = setmetatable({}, { __mode = "k" }) :: { [Model]: { [Player]: number } }

local function hitPlayer(attacker: Player, victimCharacter: Model, item)
	local victim = Players:GetPlayerFromCharacter(victimCharacter)
	local humanoid = victimCharacter:FindFirstChildOfClass("Humanoid")
	if not victim or not humanoid or humanoid.Health <= 0 or victim == attacker then
		return
	end
	if victimCharacter:FindFirstChildOfClass("ForceField") then
		return
	end
	local defense = Inventory.defense(victim)
	local dealt = (item.damage or Config.UnarmedDamage) * (1 - defense)
	humanoid:TakeDamage(dealt)
	-- Tally who hurt whom, for loot priority when they die (see Death.lua).
	local tally = Harvest.damageBy[victimCharacter] or {}
	tally[attacker] = (tally[attacker] or 0) + dealt
	Harvest.damageBy[victimCharacter] = tally
	Remotes.Marker:FireClient(attacker, victimCharacter:GetPivot().Position, dealt, "hit", Inventory.getEquipped(attacker))
	Remotes.HitFeedback:FireAllClients(victimCharacter)
end

function Harvest.onHit(player: Player, target: unknown)
	if typeof(target) ~= "Instance" or not (target :: Instance):IsA("Model") then
		return
	end
	local model = target :: Model
	local kind
	if model.Parent == workspace:FindFirstChild("Nodes") then
		kind = "node"
	elseif model.Parent == workspace:FindFirstChild("Structures") then
		kind = "structure"
	elseif model.Parent == workspace:FindFirstChild("Animals") then
		kind = "animal"
	elseif Players:GetPlayerFromCharacter(model) then
		kind = "player"
	else
		return
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end

	local itemId = Inventory.getEquipped(player)
	local item = itemId and Items[itemId]
	if not item or item.kind ~= "tool" then
		return
	end

	local now = os.clock()
	if (nextSwing[player] or 0) > now then
		return
	end
	nextSwing[player] = now + item.cooldown * 0.9 -- a little slack for lag

	-- Reach: distance to the closest point of the target's box.
	local cf, size = model:GetBoundingBox()
	local offset = cf:PointToObjectSpace(root.Position)
	local half = size / 2
	local closest = Vector3.new(math.clamp(offset.X, -half.X, half.X), math.clamp(offset.Y, -half.Y, half.Y), math.clamp(offset.Z, -half.Z, half.Z))
	if (offset - closest).Magnitude > Config.HitRange then
		return
	end

	Remotes.Swing:FireAllClients(character)
	if kind == "node" then
		hitNode(player, model, item, root.Position)
	elseif kind == "structure" then
		local at = model:GetBoundingBox().Position
		if hitStructure(player, model, item) then
			Remotes.Marker:FireClient(player, at, item.damage or Config.UnarmedDamage, "hit", Inventory.getEquipped(player))
		end
	elseif kind == "animal" then
		local at = model:GetBoundingBox().Position
		Animals.damage(model, item.damage or Config.UnarmedDamage, player)
		Remotes.Marker:FireClient(player, at, item.damage or Config.UnarmedDamage, "hit", Inventory.getEquipped(player))
		Remotes.HitFeedback:FireAllClients(model)
	else
		hitPlayer(player, model, item)
	end
end

function Harvest.removePlayer(player: Player)
	nextSwing[player] = nil
end

return Harvest
