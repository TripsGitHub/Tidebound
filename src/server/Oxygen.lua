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

-- Is the head in water? Read the 3x3x3 terrain voxels around it. A voxel your head
-- shares with rock or sand (touching a wall, the sea floor or a cave roof) reports
-- the solid material, not water, so for those look at the neighbours: water next to
-- you and no open air means you're still under.
local W, AIR = Enum.Material.Water, Enum.Material.Air
local function headUnderwater(head: BasePart): boolean
	local p = head.Position + Vector3.new(0, 0.4, 0)
	local c = Vector3.new(math.floor(p.X / 4) * 4, math.floor(p.Y / 4) * 4, math.floor(p.Z / 4) * 4)
	local region = Region3.new(c - Vector3.new(4, 4, 4), c + Vector3.new(8, 8, 8))
	local ok, mats, occ = pcall(function()
		return workspace.Terrain:ReadVoxels(region, 4)
	end)
	if not ok or not mats[2] or not mats[2][2] then
		return false
	end
	local m = mats[2][2][2]
	if m == W then
		return occ[2][2][2] > 0.4
	end
	if m == AIR then
		return false
	end
	-- Head inside a voxel with something solid: decide from the six around it.
	local water, air = false, false
	for _, d in { { 1, 2, 2 }, { 3, 2, 2 }, { 2, 1, 2 }, { 2, 3, 2 }, { 2, 2, 1 }, { 2, 2, 3 } } do
		local n = mats[d[1]][d[2]][d[3]]
		if n == W then
			water = true
		elseif n == AIR or occ[d[1]][d[2]][d[3]] < 0.5 and n ~= W then
			air = air or n == AIR
		end
	end
	return water and not air
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
					-- Only your head counts: standing or walking on the sea floor doesn't
					-- give you air back.
					local under = headUnderwater(head)
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
