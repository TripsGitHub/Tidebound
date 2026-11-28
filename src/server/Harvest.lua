-- A player swings at something. The client only says "I hit this";
-- the server checks reach, swing speed and tool, then gathers, damages or hurts.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Nodes = require(Shared.Nodes)
local Remotes = require(Shared.Remotes)
local Tiers = require(Shared.Tiers)
local TIER_RANK = {}
for i, t in Tiers.list do
	TIER_RANK[t.id] = i
end
local function tierRank(id: string): number
	return TIER_RANK[id] or 0
end
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
local ORE_ITEMS: { [string]: boolean } = {}
for _, ore in require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Ores")) do
	ORE_ITEMS[ore.item] = true
end

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
	-- Ore counts towards "Mine N ore" quests when you break it out of the rock, not
	-- when you pick it up: a full bag used to stop the quest (and Main.server.lua
	-- skips ore on pickup so it isn't counted twice).
	for _, drop in loot do
		if ORE_ITEMS[drop.item] then
			require(script.Parent.Quests).record(player, "gather", drop.item, drop.amount * mult)
		end
	end
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

-- A warning at most once every 20 seconds per kind, so hitting doesn't spam it.
local warned: { [Player]: { [string]: number } } = setmetatable({}, { __mode = "k" }) :: any
local function warnOnce(player: Player, kind: string, text: string)
	local t = warned[player] or {}
	warned[player] = t
	if (t[kind] or 0) + 20 < os.clock() then
		t[kind] = os.clock()
		Remotes.Notify:FireClient(player, text, "warn")
	end
end

-- The weakest harvester whose stone power reaches `power`, by name.
local function needHarvester(power: number): string
	local best, bestOrder = nil, math.huge
	for _, it in Items do
		if type(it) == "table" and it.kind == "tool" and it.gather and not it.swing and (it.gather.stone or 0) >= power and string.find(it.name or "", "Harvester") and (it.order or 99) < bestOrder then
			best, bestOrder = it.name, it.order or 99
		end
	end
	return best or "stronger harvester"
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
		if def.swordTier then
			-- Tide and Abyss Seals: any sword chips them, but each tier short of the one
			-- they're meant for makes every hit count for much less.
			local need = Tiers.get(def.swordTier)
			local have = Tiers.split(held)
			local short = if need then tierRank(need.id) - (if have then tierRank(have.id) else 0) else 0
			if short > 0 then
				dmg = math.max(1, math.floor(dmg * 0.45 ^ short + 0.5))
				warnOnce(player, "seal", "Your sword is weak against the " .. def.name .. ": a " .. need.name .. " sword breaks it much faster")
			end
		end
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
		-- Ores need the right harvester: Stone for Silver, Silver for Gold, and so on.
		warnOnce(player, "ore", def.name .. " needs a " .. needHarvester(def.minPower) .. " or better")
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
	local defense = Inventory.defense(victim, "player")
	local dealt = (item.damage or Config.UnarmedDamage) * (1 - defense)
	humanoid:TakeDamage(dealt)
	-- Tally who hurt whom, for loot priority when they die (see Death.lua).
	local tally = Harvest.damageBy[victimCharacter] or {}
	tally[attacker] = (tally[attacker] or 0) + dealt
	Harvest.damageBy[victimCharacter] = tally
	Remotes.Marker:FireClient(attacker, victimCharacter:GetPivot().Position, dealt, "hit", Inventory.getEquipped(attacker))
	Remotes.HitFeedback:FireAllClients(victimCharacter)
end

-- Bows: each shot uses an Arrow and reaches item.range studs, if nothing's in the way.
-- Arrows hurt beasts, bosses and players, not nodes or buildings.
local function shoot(player: Player, itemId: string, item, target: unknown, aim: unknown)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	local now = os.clock()
	if (nextSwing[player] or 0) > now then
		return
	end
	if Inventory.count(player, "arrow") < 1 then
		warnOnce(player, "arrows", "You need Arrows to shoot (craft them in Tools)")
		return
	end
	nextSwing[player] = now + item.cooldown * 0.9
	Inventory.takeAll(player, { arrow = 1 })
	local from = root.Position + Vector3.new(0, 1.2, 0)
	-- Aim at the hovered target if there is one, otherwise where the mouse points.
	-- The arrow then flies dead straight for item.range studs and hits the first
	-- thing in its way.
	local aimAt: Vector3? = nil
	if typeof(target) == "Instance" and (target :: Instance):IsA("Model") then
		aimAt = (target :: Model):GetBoundingBox().Position
	elseif typeof(aim) == "Vector3" then
		aimAt = aim :: Vector3
	end
	local dir = if aimAt and (aimAt - from).Magnitude > 0.5 then (aimAt - from).Unit else root.CFrame.LookVector
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, workspace:FindFirstChild("Drops") :: Instance, workspace:FindFirstChild("Decor") :: Instance }
	params.IgnoreWater = true
	local hit = workspace:Raycast(from, dir * item.range, params)
	local to = if hit then hit.Position else from + dir * item.range
	local model: Model? = nil
	local kind = nil
	if hit then
		local animals = workspace:FindFirstChild("Animals")
		local inst: Instance? = hit.Instance
		while inst and inst ~= workspace do
			if inst:IsA("Model") and inst.Parent == animals then
				model, kind = inst, "animal"
				break
			elseif inst:IsA("Model") and Players:GetPlayerFromCharacter(inst) then
				model, kind = inst, "player"
				break
			end
			inst = inst.Parent
		end
	end
	local speed = item.arrowSpeed or 140
	Remotes.Arrow:FireAllClients(character, from, to, kind ~= nil, speed, hit == nil)
	if not kind or not model then
		return
	end
	local delay = (to - from).Magnitude / speed
	task.delay(delay, function()
		if not model.Parent then
			return
		end
		if kind == "animal" then
			Animals.damage(model, item.damage, player)
			Remotes.Marker:FireClient(player, model:GetBoundingBox().Position, item.damage, "hit", itemId)
			Remotes.HitFeedback:FireAllClients(model)
		else
			hitPlayer(player, model, item)
		end
	end)
end

function Harvest.onHit(player: Player, target: unknown, aim: unknown)
	local equippedId = Inventory.getEquipped(player)
	local equippedItem = equippedId and Items[equippedId]
	if equippedItem and equippedItem.ranged then
		shoot(player, equippedId :: string, equippedItem, target, aim)
		return
	end
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
