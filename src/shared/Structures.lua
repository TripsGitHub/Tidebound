-- Sizes and health of buildable structures (used by both the build preview and the server).
local Config = require(script.Parent.Config)

local Structures = {
	WoodWall = { size = Vector3.new(8, 8, 1), hp = 250 },
	WoodFloor = { size = Vector3.new(8, 1, 8), hp = 250 },
	WoodDoor = { size = Vector3.new(4, 7, 1), hp = 200 },
	StoneWall = { size = Vector3.new(8, 8, 1.5), hp = 700 },
	Campfire = { size = Vector3.new(4, 1.5, 4), hp = 100 },
}

-- Snap a position to the build grid (X and Z only).
function Structures.snap(position: Vector3): Vector3
	local g = Config.GridSize
	return Vector3.new(math.round(position.X / g) * g, position.Y, math.round(position.Z / g) * g)
end

-- Turn a rotation in degrees into one of 0, 90, 180, 270.
function Structures.snapRotation(degrees: number): number
	return (math.round(degrees / 90) % 4) * 90
end

return Structures
