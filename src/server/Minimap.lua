-- Publishes what the client minimap draws, once the world is built:
--   ReplicatedStorage.MapData.Land     the surface as a grid of material letters, one
--                                      row per line (attributes: Cell, X0, Z0, Cols, Rows)
--   ReplicatedStorage.MapData.Caves#   cave tunnels as segments "x1,z1,x2,z2,y,r;" (split
--                                      over several values so none gets too long)
--   ReplicatedStorage.MapData.Rooms    chambers as "x,z,r,y;"
--   ReplicatedStorage.MapData.Places   island and landmark names as "name|x|z;"
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Caves = require(script.Parent.Caves)

local Minimap = {}

local CELL = 32
local M = Enum.Material
local LETTER = {
	[M.Water] = ".",
	[M.Sand] = "s",
	[M.Grass] = "g",
	[M.LeafyGrass] = "f",
	[M.Rock] = "r",
	[M.Slate] = "r",
	[M.Limestone] = "r",
	[M.Snow] = "n",
	[M.Glacier] = "i",
	[M.Mud] = "m",
	[M.Ground] = "d",
	[M.Basalt] = "b",
	[M.CrackedLava] = "l",
}

local function value(parent: Instance, name: string, text: string): StringValue
	local v = Instance.new("StringValue")
	v.Name = name
	v.Value = text
	v.Parent = parent
	return v
end

function Minimap.publish(islands: { any }, network, groundAt)
	local old = ReplicatedStorage:FindFirstChild("MapData")
	if old then
		old:Destroy()
	end
	local data = Instance.new("Folder")
	data.Name = "MapData"

	-- Land
	local extent = 0
	for _, isl in islands do
		extent = math.max(extent, math.abs(isl.x) + isl.r, math.abs(isl.z) + isl.r)
	end
	extent += 200
	local cols = math.ceil(extent * 2 / CELL)
	local x0, z0 = -extent, -extent
	local rows = {}
	for r = 1, cols do
		local line = table.create(cols)
		local z = z0 + (r - 0.5) * CELL
		for c = 1, cols do
			local x = x0 + (c - 0.5) * CELL
			local hit = groundAt(x, z)
			local ch = "."
			if hit and hit.Material ~= M.Water and hit.Position.Y > -2 then
				ch = LETTER[hit.Material] or "g"
			elseif hit and hit.Material ~= M.Water then
				ch = "." -- sea floor under shallow water
			end
			line[c] = ch
		end
		rows[r] = table.concat(line)
		if r % 8 == 0 then
			task.wait()
		end
	end
	local land = value(data, "Land", table.concat(rows, "\n"))
	land:SetAttribute("Cell", CELL)
	land:SetAttribute("X0", x0)
	land:SetAttribute("Z0", z0)
	land:SetAttribute("Cols", cols)
	land:SetAttribute("Rows", cols)

	-- Caves
	local chunks, current, size = {}, {}, 0
	for _, t in network.tunnels do
		local pts = Caves.samples(t.points)
		for i = 1, #pts - 1, 4 do
			local a, b = pts[i], pts[math.min(i + 4, #pts)]
			local s = string.format("%d,%d,%d,%d,%d,%d;", a.X, a.Z, b.X, b.Z, (a.Y + b.Y) / 2, t.r)
			table.insert(current, s)
			size += #s
			if size > 40000 then
				table.insert(chunks, table.concat(current))
				current, size = {}, 0
			end
		end
	end
	table.insert(chunks, table.concat(current))
	for i, text in chunks do
		value(data, "Caves" .. i, text)
	end
	local rooms = {}
	for _, c in network.chambers do
		table.insert(rooms, string.format("%d,%d,%d,%d;", c.pos.X, c.pos.Z, c.r, c.pos.Y))
	end
	for _, room in network.secretRooms do
		table.insert(rooms, string.format("%d,%d,%d,%d;", room.pos.X, room.pos.Z, math.max(room.size.X, room.size.Z) / 2, room.pos.Y))
	end
	value(data, "Rooms", table.concat(rooms))

	-- Names
	local places = {}
	for _, isl in islands do
		table.insert(places, string.format("%s|%d|%d;", isl.name, isl.x, isl.z))
	end
	local lm = workspace:FindFirstChild("Landmarks")
	if lm then
		for _, m in lm:GetChildren() do
			if m:IsA("Model") then
				local p = m:GetPivot().Position
				table.insert(places, string.format("%s|%d|%d;", m.Name, p.X, p.Z))
			end
		end
	end
	value(data, "Places", table.concat(places))
	data.Parent = ReplicatedStorage
end

return Minimap
