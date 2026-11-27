-- Sizes and health of buildable structures (used by the build preview and the server).
local Config = require(script.Parent.Config)

local Structures = {
	Campfire = { size = Vector3.new(9, 2.4, 9), hp = 120 },
	-- Bases: the plot your home stands on. One per player; what's built on it saves.
	WoodBase = { size = Vector3.new(32, 1.4, 32), hp = 1500 },
	StoneBase = { size = Vector3.new(32, 1.6, 32), hp = 4000 },
	LargeStoneBase = { size = Vector3.new(48, 1.8, 48), hp = 7000 },
	WoodWall = { size = Vector3.new(8, 18, 1.2), hp = 300 },
	StoneWall = { size = Vector3.new(8, 18, 2), hp = 900 },
	WoodGate = { size = Vector3.new(8, 18, 1.2), hp = 250 },
	Chest = { size = Vector3.new(5, 3.4, 3.4), hp = 260 },
}

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
