-- Air. Swim with your head under water and your air runs down; run out and you
-- start drowning. Surface (or climb out) and it refills fast. A diving mask on
-- your head adds more air, so deep water and flooded caves are a gear check.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Items = require(ReplicatedStorage:WaitForChild("Shared").Items)
local Config = require(ReplicatedStorage.Shared.Config)
local Inventory = require(script.Parent.Inventory)

local Oxygen = {}

local TICK = 0.25

local function maxAir(player: Player): number
	local extra = 0
	local armour = Inventory.getArmour(player)
	if armour then
		for _, id in armour do
			extra += (Items[id] and Items[id].air) or 0
		end
	end
	return Config.BaseAir + extra
end

local function headUnderwater(head: BasePart): boolean
	local p = head.Position + Vector3.new(0, 0.4, 0)
	local region = Region3.new(p - Vector3.new(1, 1, 1), p + Vector3.new(1, 1, 1)):ExpandToGrid(4)
	local ok, mats, occ = pcall(function()
		return workspace.Terrain:ReadVoxels(region, 4)
	end)
	if not ok then
		return false
	end
	local m, o = mats[1][1][1], occ[1][1][1]
	return m == Enum.Material.Water and o > 0.4
end

function Oxygen.start()
	task.spawn(function()
		while true do
			task.wait(TICK)
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				local head = character and character:FindFirstChild("Head") :: BasePart?
				if humanoid and head and humanoid.Health > 0 then
					local max = maxAir(player)
					local air = player:GetAttribute("Air") or max
					local under = humanoid:GetState() == Enum.HumanoidStateType.Swimming and headUnderwater(head)
					if under then
						air = math.max(0, air - TICK)
						if air <= 0 then
							humanoid:TakeDamage(Config.DrownDamagePerSecond * TICK)
						end
					else
						air = math.min(max, air + TICK * Config.AirRefillRate)
					end
					player:SetAttribute("Air", air)
					player:SetAttribute("MaxAir", max)
				end
			end
		end
	end)
end

return Oxygen
