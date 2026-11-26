-- Sizes and health of buildable structures (used by the build preview and the server).
local Config = require(script.Parent.Config)

local Structures = {
	Campfire = { size = Vector3.new(9, 2.4, 9), hp = 120 },
	WoodBase = { size = Vector3.new(16, 1.4, 16), hp = 600 },
	StoneBase = { size = Vector3.new(16, 1.6, 16), hp = 1800 },
	WoodWall = { size = Vector3.new(8, 9, 1.2), hp = 300 },
	StoneWall = { size = Vector3.new(8, 9, 2), hp = 900 },
	WoodGate = { size = Vector3.new(8, 9, 1.2), hp = 250 },
}

function Structures.snap(position: Vector3): Vector3
	local g = Config.GridSize
	return Vector3.new(math.round(position.X / g) * g, position.Y, math.round(position.Z / g) * g)
end

function Structures.snapRotation(degrees: number): number
	return (math.round(degrees / 90) % 4) * 90
end

return Structures
