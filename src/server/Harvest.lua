-- A player swings at something. The client only says "I hit this";
-- the server checks reach, swing speed and tool, then gathers, damages or hurts.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

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

-- Trees tip over away from the player, then break into logs.
local function fellTree(model: Model, def, awayFrom: Vector3, loot: { { item: string, amount: number } })
	local home = model:GetPivot()
	local base = home.Position
	local away = (base - awayFrom) * Vector3.new(1, 0, 1)
	away = if away.Magnitude > 0 then away.Unit else Vector3.xAxis
	local axis = Vector3.yAxis:Cross(away).Unit
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.CanCollide = false
			p.CanQuery = false
		end
	end
	local angle = Instance.new("NumberValue")
	angle.Changed:Connect(function(a)
		model:PivotTo(CFrame.fromAxisAngle(axis, math.rad(a)) * (home - base) + base)
	end)
	local tween = TweenService:Create(angle, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Value = 88 })
	tween:Play()
	tween.Completed:Wait()
	angle:Destroy()
	task.wait(0.4)
	setVisible(model, false)
	local _, size = model:GetBoundingBox()
	local length = math.max(size.X, size.Y, size.Z)
	-- Spread the loot along where the trunk landed.
	local total = 0
	for _, drop in loot do
		total += drop.amount
	end
	local n = 0
	for _, drop in loot do
		for _ = 1, drop.amount do
			n += 1
			local along = base + away * (length * n / (total + 1)) + Vector3.new(0, 2, 0)
			Drops.spawn(drop.item, 1, along, axis * (if n % 2 == 0 then 1 else -1))
		end
	end
	if model:GetAttribute("Temporary") then
		model:Destroy() -- world-event nodes (Events.lua) don't grow back
	else
		respawnLater(model, def, home)
	end
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

local function deplete(player: Player, model: Model, def, awayFrom: Vector3)
	model:SetAttribute("Depleted", true)
	Progression.addXp(player, def.xp)
	local loot = rollLoot(def)
	if def.falls then
		task.spawn(fellTree, model, def, awayFrom, loot)
		return
	end
	local home = model:GetPivot()
	setVisible(model, false)
	local center = home.Position + Vector3.new(0, 2, 0)
	for _, drop in loot do
		for _ = 1, drop.amount do
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
	model:SetAttribute("HP", hp)
	Remotes.HitFeedback:FireAllClients(model)
	if hp <= 0 then
		deplete(player, model, def, rootPos)
	end
end

local function hitStructure(model: Model, item)
	local hp = (model:GetAttribute("HP") or 0) - (item.damage or Config.UnarmedDamage)
	model:SetAttribute("HP", hp)
	Remotes.HitFeedback:FireAllClients(model)
	if hp <= 0 then
		model:Destroy()
	end
end

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
	humanoid:TakeDamage((item.damage or Config.UnarmedDamage) * (1 - defense))
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
		hitStructure(model, item)
	elseif kind == "animal" then
		Animals.damage(model, item.damage or Config.UnarmedDamage, player)
		Remotes.HitFeedback:FireAllClients(model)
	else
		hitPlayer(player, model, item)
	end
end

function Harvest.removePlayer(player: Player)
	nextSwing[player] = nil
end

return Harvest
