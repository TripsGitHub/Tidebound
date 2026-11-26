-- Hunger. It drains over time, food refills it, and an empty bar hurts.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Inventory = require(script.Parent.Inventory)

local Survival = {}
local lastEat: { [Player]: number } = {}

function Survival.reset(player: Player)
	player:SetAttribute("Hunger", Config.MaxHunger)
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
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + item.heal)
	end
	if item.hurt then
		humanoid:TakeDamage(item.hurt)
	end
	return true
end

-- Eat from the bag.
function Survival.eat(player: Player, itemId: unknown)
	if type(itemId) ~= "string" or Inventory.count(player, itemId) <= 0 then
		return
	end
	if Survival.consume(player, itemId) then
		Inventory.take(player, itemId, 1)
	end
end

function Survival.removePlayer(player: Player)
	lastEat[player] = nil
end

function Survival.start()
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
