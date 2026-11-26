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

function Survival.eat(player: Player, itemId: unknown)
	if type(itemId) ~= "string" then
		return
	end
	local item = Items[itemId]
	if not item or item.kind ~= "food" then
		return
	end
	local now = os.clock()
	if (lastEat[player] or 0) + 0.4 > now then
		return
	end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	if not Inventory.take(player, itemId, 1) then
		return
	end
	lastEat[player] = now
	local hunger = player:GetAttribute("Hunger") or 0
	player:SetAttribute("Hunger", math.min(Config.MaxHunger, hunger + item.hunger))
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
