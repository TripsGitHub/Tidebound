-- Hunger. It drains over time, food refills it, and an empty bar hurts.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Inventory = require(script.Parent.Inventory)
local Drops = require(script.Parent.Drops)

local Survival = {}
local lastEat: { [Player]: number } = {}

function Survival.reset(player: Player)
	player:SetAttribute("Hunger", Config.MaxHunger)
	player:SetAttribute("HealPool", 0)
end

-- Applies a food's effect. Returns true if the player could eat.
function Survival.consume(player: Player, itemId: string): boolean
	local item = Items[itemId]
	if not item or item.kind ~= "food" then
		return false
	end
	local now = os.clock()
	if (lastEat[player] or 0) + 0.5 > now then
		return false
	end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false
	end
	lastEat[player] = now
	local hunger = player:GetAttribute("Hunger") or 0
	player:SetAttribute("Hunger", math.min(Config.MaxHunger, hunger + (item.hunger or 0)))
	if item.heal then
		-- Food heals in fast chunks rather than all at once: it goes into a pool that
		-- pays out HEAL_CHUNK every HEAL_TICK seconds (see Survival.start).
		player:SetAttribute("HealPool", math.min(humanoid.MaxHealth, (player:GetAttribute("HealPool") or 0) + item.heal * Config.FoodHealScale))
	end
	if item.hurt then
		humanoid:TakeDamage(item.hurt)
	end
	return true
end

-- Opens a crate of any rarity: a few random stacks from its own loot table (see
-- Items.CRATES), weighted towards the common lines. The client plays the opening
-- screen with what came out. Anything that doesn't fit in the bag lands on the ground.
local Remotes = require(Shared.Remotes)
local function openCrate(player: Player, crateId: string)
	local crate = Items.CRATES[crateId]
	local now = os.clock()
	if not crate or (lastEat[player] or 0) + 1.2 > now or not Inventory.take(player, crateId, 1) then
		return
	end
	lastEat[player] = now
	local total = 0
	for _, e in crate.loot do
		total += e[4]
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local got: { [string]: number } = {}
	local order = {}
	for _ = 1, math.random(crate.rolls[1], crate.rolls[2]) do
		local roll = math.random() * total
		for _, e in crate.loot do
			roll -= e[4]
			if roll <= 0 then
				if not got[e[1]] then
					table.insert(order, e[1])
				end
				got[e[1]] = (got[e[1]] or 0) + math.random(e[2], e[3])
				break
			end
		end
	end
	local shown = {}
	for _, id in order do
		local amount = got[id]
		local added = Inventory.add(player, id, amount)
		if added < amount and root then
			Drops.spawn(id, amount - added, root.Position + Vector3.new(0, 2, 0))
		end
		table.insert(shown, { id, amount })
	end
	Remotes.CrateOpened:FireClient(player, crateId, shown)
end

-- Eat from the bag (or open a crate).
function Survival.eat(player: Player, itemId: unknown)
	if type(itemId) ~= "string" or Inventory.count(player, itemId) <= 0 then
		return
	end
	if Items[itemId] and Items[itemId].kind == "crate" then
		openCrate(player, itemId)
		return
	end
	if Survival.consume(player, itemId) then
		Inventory.take(player, itemId, 1)
	end
end

function Survival.removePlayer(player: Player)
	lastEat[player] = nil
end

-- Food heals in quick chunks: HEAL_CHUNK health every HEAL_TICK seconds until the
-- eaten amount is used up. There is no passive regeneration at all (Roblox's default
-- "Health" script is replaced by an empty one below), so running away doesn't heal
-- you: eating does.
local HEAL_CHUNK = 6
local HEAL_TICK = 0.5

function Survival.start()
	local StarterPlayer = game:GetService("StarterPlayer")
	local scripts = StarterPlayer:FindFirstChild("StarterCharacterScripts")
	if scripts and not scripts:FindFirstChild("Health") then
		local stub = Instance.new("Script")
		stub.Name = "Health" -- an empty script with this name stops Roblox adding its regen
		stub.Parent = scripts
	end
	local function noRegen(character: Model)
		task.defer(function()
			local regen = character:FindFirstChild("Health")
			if regen and regen:IsA("Script") then
				regen:Destroy()
			end
		end)
	end
	local function watchPlayer(player: Player)
		player.CharacterAdded:Connect(noRegen)
		if player.Character then
			noRegen(player.Character)
		end
	end
	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	task.spawn(function()
		while true do
			task.wait(HEAL_TICK)
			for _, player in Players:GetPlayers() do
				local pool = player:GetAttribute("HealPool") or 0
				if pool > 0 then
					local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
					if not humanoid or humanoid.Health <= 0 then
						player:SetAttribute("HealPool", 0)
					else
						local room = humanoid.MaxHealth - humanoid.Health
						local step = math.min(pool, HEAL_CHUNK, room)
						humanoid.Health += step
						-- A full bar stops the trickle: the rest of the food is wasted.
						local left = if room - step <= 0.01 then 0 else pool - step
						player:SetAttribute("HealPool", if left < 0.01 then 0 else left)
					end
				end
			end
		end
	end)
	task.spawn(function()
		while true do
			local dt = task.wait(1)
			for _, player in Players:GetPlayers() do
				local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if humanoid and humanoid.Health > 0 then
					local hunger = math.max(0, (player:GetAttribute("Hunger") or 0) - Config.HungerDrainPerSecond * dt)
					player:SetAttribute("Hunger", hunger)
					if hunger <= 0 then
						humanoid:TakeDamage(Config.StarveDamagePerSecond * dt)
					end
				end
			end
		end
	end)
end

return Survival
