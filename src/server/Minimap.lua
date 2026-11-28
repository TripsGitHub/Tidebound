-- Publishes what the client minimap draws, once the world is built:
--   ReplicatedStorage.MapData.Land#    the surface: per cell a material letter and a
--                                      height (or water depth), one row per line, split
--                                      over several values; MapData.Land holds the grid's
--                                      attributes (Cell, X0, Z0, Cols, Rows, Chunks)
--   ReplicatedStorage.MapData.Caves#   cave tunnels as segments "x1,z1,x2,z2,y,r;" (split
--                                      over several values so none gets too long)
--   ReplicatedStorage.MapData.Rooms    chambers as "x,z,r,y;"
--   ReplicatedStorage.MapData.Places   island and landmark names as "name|x|z;"
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Caves = require(script.Parent.Caves)

local Minimap = {}

local CELL = 20 -- studs per map pixel
local ROWS_PER_VALUE = 40
local M = Enum.Material
local LETTER = {
	[M.Water] = ".",
	[M.Sand] = "s",
	[M.Salt] = "s", -- wet sand
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

	-- Land: two characters a cell, its material letter and its height (or, for water,
	-- its depth) as string.char(33 + v), v in steps of 1.5 studs. Rows go into values
	-- of ROWS_PER_VALUE rows each so no value gets too long.
	local extent = 0
	for _, isl in islands do
		extent = math.max(extent, math.abs(isl.x) + isl.r, math.abs(isl.z) + isl.r)
	end
	extent += 200
	local cols = math.ceil(extent * 2 / CELL)
	local x0, z0 = -extent, -extent
	local dry = RaycastParams.new()
	dry.FilterType = Enum.RaycastFilterType.Include
	dry.FilterDescendantsInstances = { workspace.Terrain }
	dry.IgnoreWater = true
	local wet = RaycastParams.new()
	wet.FilterType = Enum.RaycastFilterType.Include
	wet.FilterDescendantsInstances = { workspace.Terrain }
	wet.IgnoreWater = false
	local function code(v: number): string
		return string.char(33 + math.clamp(math.floor(v / 1.5 + 0.5), 0, 90))
	end
	local rows = {}
	for r = 1, cols do
		local line = table.create(cols * 2)
		local z = z0 + (r - 0.5) * CELL
		for c = 1, cols do
			local x = x0 + (c - 0.5) * CELL
			local hit = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -500, 0), dry)
			local y = if hit then hit.Position.Y else -60
			local ch, v
			if y < 0.5 then
				ch, v = ".", -y -- sea: how deep
			else
				local top = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -500, 0), wet)
				if top and top.Material == M.Water and top.Position.Y > y + 0.5 then
					ch, v = "w", top.Position.Y - y -- a pond or lake
				else
					ch, v = LETTER[hit.Material] or "g", y
				end
			end
			line[c * 2 - 1] = ch
			line[c * 2] = code(v)
		end
		rows[r] = table.concat(line)
		if r % 6 == 0 then
			task.wait()
		end
	end
	local chunk = 0
	for r0 = 1, cols, ROWS_PER_VALUE do
		chunk += 1
		local part = table.move(rows, r0, math.min(r0 + ROWS_PER_VALUE - 1, cols), 1, {})
		value(data, "Land" .. chunk, table.concat(part, "\n"))
	end
	local land = value(data, "Land", "")
	land:SetAttribute("Cell", CELL)
	land:SetAttribute("X0", x0)
	land:SetAttribute("Z0", z0)
	land:SetAttribute("Cols", cols)
	land:SetAttribute("Rows", cols)
	land:SetAttribute("Chunks", chunk)

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
	-- Marks on the cave map: boss lairs (always shown, so players can find them), boss
	-- gates, the Maw, and the ways in and out. "kind|x|z|y|label;"
	local marks = {}
	local function mark(kind: string, pos: Vector3, label: string)
		local text = string.gsub(string.gsub(label, "[|;]", " "), "(%l)(%u)", "%1 %2")
		table.insert(marks, string.format("%s|%d|%d|%d|%s;", kind, pos.X, pos.Z, pos.Y, text))
	end
	for _, room in network.bossRooms or {} do
		mark("boss", room.pos, tostring(room.boss))
	end
	for _, b in network.barriers or {} do
		local boss = string.match(b.kind, "^gate_(.+)$")
		if boss then
			mark("gate", b.pos, boss .. " gate")
		end
	end
	if network.hub then
		mark("maw", network.hub.pos, "The Maw")
	end
	for _, e in network.entrances or {} do
		mark("exit", e.pos, "Way out")
	end
	for _, e in network.exits or {} do
		mark("exit", e.pos, "Way out")
	end
	value(data, "CaveMarks", table.concat(marks))

	-- Names
	local places = {}
	for _, isl in islands do
		if not isl.nameless then
			table.insert(places, string.format("%s|%d|%d;", isl.name, isl.x, isl.z))
		end
	end
	-- The trading posts are worth finding, so they get a name on the map.
	local camps = workspace:FindFirstChild("Camps")
	if camps then
		for _, m in camps:GetChildren() do
			local kind = m:GetAttribute("Outpost")
			if kind == "dockMarket" or kind == "hillTrader" then
				local p = m:GetPivot().Position
				table.insert(places, string.format("%s|%d|%d;", "Trading Post", p.X, p.Z))
			end
		end
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
