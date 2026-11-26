-- Handles a player hitting something: gathering from trees, rocks, bushes and slime,
-- or damaging a structure. The client only says "I hit this"; the server checks everything.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Nodes = require(Shared.Nodes)
local Remotes = require(Shared.Remotes)
local Inventory = require(script.Parent.Inventory)
local Progression = require(script.Parent.Progression)
local Quests = require(script.Parent.Quests)

local Harvest = {}
local nextSwing: { [Player]: number } = {}

local function setNodeVisible(model: Model, visible: boolean)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			if visible then
				part.Transparency = part:GetAttribute("BaseTransparency") or 0
				part.CanCollide = part:GetAttribute("BaseCollide") ~= false
				part.CanQuery = true
			else
				part.Transparency = 1
				part.CanCollide = false
				part.CanQuery = false
			end
		end
	end
end

local function deplete(model: Model, def)
	model:SetAttribute("Depleted", true)
	setNodeVisible(model, false)
	task.delay(def.respawn, function()
		if model.Parent then
			model:SetAttribute("HP", def.hp)
			model:SetAttribute("Depleted", false)
			setNodeVisible(model, true)
		end
	end)
end

local function hitNode(player: Player, model: Model, item)
	local def = Nodes[model:GetAttribute("NodeType")]
	if not def or model:GetAttribute("Depleted") then
		return
	end
	local power = item.gather and item.gather[def.material] or 0
	if power <= 0 then
		Remotes.Notify:FireClient(player, "You need a different tool for that.")
		return
	end

	local gained = {}
	for _, drop in def.drops do
		if math.random() <= drop.chance then
			local amount = if drop.scales then drop.amount * power else drop.amount
			Inventory.add(player, drop.item, amount)
			Quests.record(player, "gather", drop.item, amount)
			table.insert(gained, "+" .. amount .. " " .. Items[drop.item].name)
		end
	end
	Progression.addXp(player, def.xp)

	local hp = (model:GetAttribute("HP") or def.hp) - power
	model:SetAttribute("HP", hp)
	Remotes.HitFeedback:FireClient(player, model, table.concat(gained, "   "))
	if hp <= 0 then
		deplete(model, def)
	end
end

local function hitStructure(player: Player, model: Model, item)
	local hp = (model:GetAttribute("HP") or 0) - (item.damage or 1)
	model:SetAttribute("HP", hp)
	Remotes.HitFeedback:FireClient(player, model, "-" .. (item.damage or 1))
	if hp <= 0 then
		model:Destroy()
	end
end

function Harvest.onHit(player: Player, target: unknown)
	if typeof(target) ~= "Instance" or not (target :: Instance):IsA("Model") then
		return
	end
	local model = target :: Model
	local isNode = model:IsDescendantOf(workspace:WaitForChild("Nodes"))
	local isStructure = model.Parent == workspace:WaitForChild("Structures")
	if not isNode and not isStructure then
		return
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end

	local itemId = Inventory.getEquipped(player)
	local item = itemId and Items[itemId]
	if not item or item.kind ~= "tool" then
		return
	end

	-- Swing speed limit
	local now = os.clock()
	if (nextSwing[player] or 0) > now then
		return
	end
	nextSwing[player] = now + item.cooldown * 0.9 -- a little slack for network lag

	-- Reach check (measured to the closest point of the thing's bounding box)
	local cf, size = model:GetBoundingBox()
	local offset = cf:PointToObjectSpace((root :: BasePart).Position)
	local half = size / 2
	local closest = Vector3.new(
		math.clamp(offset.X, -half.X, half.X),
		math.clamp(offset.Y, -half.Y, half.Y),
		math.clamp(offset.Z, -half.Z, half.Z)
	)
	if (offset - closest).Magnitude > Config.HitRange then
		return
	end

	Remotes.Swing:FireAllClients(character)
	if isNode then
		hitNode(player, model, item)
	else
		hitStructure(player, model, item)
	end
end

function Harvest.removePlayer(player: Player)
	nextSwing[player] = nil
end

return Harvest
