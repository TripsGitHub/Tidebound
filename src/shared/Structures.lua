-- Sizes and health of buildable structures (used by the build preview and the server).
local Config = require(script.Parent.Config)

local Structures = {
	Campfire = { size = Vector3.new(10, 2.6, 10), hp = 120 },
	-- Bases: the plot your home stands on. One per player; what's built on it saves.
	WoodBase = { size = Vector3.new(56, 1.6, 56), hp = 1500 },
	StoneBase = { size = Vector3.new(68, 1.8, 68), hp = 4000 },
	LargeStoneBase = { size = Vector3.new(92, 2, 92), hp = 7000 },
	WoodWall = { size = Vector3.new(12, 24, 1.6), hp = 300 },
	StoneWall = { size = Vector3.new(12, 24, 2.6), hp = 900 },
	WoodGate = { size = Vector3.new(12, 24, 1.6), hp = 250 },
	Chest = { size = Vector3.new(6, 4.2, 4.2), hp = 260 },
}

-- Round 7: lights, bed, trap, ladder, ore walls and chests, carts.
Structures.PlantBox = { size = Vector3.new(7, 1.8, 7), hp = 220, planter = true }
Structures.Torch = { size = Vector3.new(1.6, 7, 1.6), hp = 40, small = true }
Structures.Lamp = { size = Vector3.new(2.4, 9, 2.4), hp = 90, small = true }
Structures.Bed = { size = Vector3.new(5.2, 2.4, 9.4), hp = 150 }
Structures.SpikeTrap = { size = Vector3.new(8, 1, 8), hp = 160, trap = true }
Structures.Ladder = { size = Vector3.new(3.6, 22, 1.1), hp = 120 }
Structures.Chest.chest = Config.ChestCapacity
do
	local Tiers = require(script.Parent.Tiers)
	for _, tier in Tiers.list do
		if tier.rank >= 3 then
			local name = tier.name:gsub("%s", "")
			Structures[name .. "Wall"] = { size = Vector3.new(12, 24, 2.4), hp = math.floor(900 * (1 + (tier.rank - 2) * 0.55)), tier = tier.id, wall = true }
			Structures[name .. "Chest"] = { size = Vector3.new(6, 4.2, 4.2), hp = 260 + tier.rank * 220, tier = tier.id, chest = Config.ChestCapacity + (tier.rank - 2) * 150 }
		end
	end
	for i, t in { "wood", "stone", "silver", "gold" } do
		local tier = Tiers.get(t) :: any
		Structures[tier.name .. "Cart"] = { size = Vector3.new(8, 5, 5), hp = 200 + i * 150, tier = t, chest = 250 + i * 150, cart = true, speed = 20 + i * 4 }
	end
end

function Structures.snap(position: Vector3): Vector3
	local g = Config.GridSize
	return Vector3.new(math.round(position.X / g) * g, position.Y, math.round(position.Z / g) * g)
end

-- Bases come in fixed sizes now (wooden, stone, large stone); no tiling.
Structures.MAX_TILES = 1
function Structures.isFloor(structure: string): boolean
	return structure == "WoodBase" or structure == "StoneBase" or structure == "LargeStoneBase"
end
Structures.isBase = Structures.isFloor
function Structures.sizeFor(structure: string, tiles: number?): Vector3
	local size = Structures[structure].size
	local n = if Structures.isFloor(structure) then math.clamp(math.floor(tiles or 1), 1, Structures.MAX_TILES) else 1
	return Vector3.new(size.X * n, size.Y, size.Z * n)
end

function Structures.snapRotation(degrees: number): number
	return (math.round(degrees / 90) % 4) * 90
end

return Structures
