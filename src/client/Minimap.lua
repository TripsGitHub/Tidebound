-- The minimap (bottom left).
--
-- Above ground it shows the islands drawn from ReplicatedStorage.MapData.Land, north
-- up, with island and landmark names, and an arrow for you.
--
-- Go underground and it dives: the map plunges in (zooms, a ripple, the surface
-- fades to black) and switches to the cave map. Underground nothing is shown that you
-- haven't been near: tunnels and chambers appear as your light reaches them and stay
-- drawn after, and a soft dark ring round the edge works like a flashlight, so the map
-- helps you find your way back without giving the caves away. Coming back up plays the
-- dive in reverse.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UIKit = require(script.Parent.UIKit)

local new = UIKit.new
local C = UIKit.Colors
local rgb = Color3.fromRGB

local Minimap = {}

local player = Players.LocalPlayer
local SIZE = 210 -- on screen, pixels
local SURFACE_PX = 1.6 -- pixels per land cell above ground
local CAVE_ZOOM = 0.55 -- pixels per stud underground
local REVEAL = 55 -- studs: how far your light reaches on the cave map
local SHOW_DEPTH = 40 -- studs: tunnels this far above or below you aren't drawn

local LAND_COLOURS = {
	s = rgb(236, 220, 160),
	g = rgb(150, 184, 70),
	f = rgb(116, 150, 60),
	r = rgb(130, 126, 120),
	n = rgb(240, 246, 250),
	i = rgb(170, 216, 236),
	m = rgb(96, 110, 66),
	d = rgb(140, 110, 76),
	b = rgb(64, 60, 66),
	l = rgb(240, 110, 40),
}
local SEA = rgb(36, 92, 140)

local root: Frame
local surfaceLayer: Frame
local surfaceWorld: Frame
local caveLayer: Frame
local caveWorld: Frame
local darkness: Frame
local ripple: Frame
local arrow: TextLabel
local depthLabel: TextLabel
local cell, x0, z0 = 32, 0, 0

local segments = {} -- { a: Vector2, b: Vector2, y: number, r: number, frame: Frame? }
local rooms = {} -- { p: Vector2, r: number, y: number, frame: Frame? }
local underground = false
local diving = false
-- Zoom: scroll over the map (or tap + / -). The view eases toward the target so
-- it glides instead of jumping.
local ZOOMS = { 0.5, 0.75, 1, 1.5, 2.25, 3.25 }
local zoomIndex = 3
local zoom = 1
local pinned: { UIScale } = {} -- labels and dots that keep their size when you zoom

local function surfacePixel(x: number, z: number): Vector2
	return Vector2.new((x - x0) / cell * SURFACE_PX, (z - z0) / cell * SURFACE_PX)
end

-- Land, drawn as a picture: one pixel a cell, coloured by material, lighter the
-- higher it is, with hill shading (lit from the north-west) so hills and cliffs read,
-- pale shallows round every coast and darker deep sea. Falls back to flat blocks of
-- colour if this device can't make images.
local function readLand(data: Folder): ({ string }, number, number)
	local land = data:WaitForChild("Land") :: StringValue
	cell = land:GetAttribute("Cell") or 20
	x0, z0 = land:GetAttribute("X0") or 0, land:GetAttribute("Z0") or 0
	local rows = {}
	for i = 1, land:GetAttribute("Chunks") or 0 do
		local v = data:WaitForChild("Land" .. i) :: StringValue
		for _, line in string.split(v.Value, "\n") do
			table.insert(rows, line)
		end
	end
	return rows, land:GetAttribute("Cols") or 0, #rows
end

local function cellColour(rows: { string }, cols: number, nrows: number, c: number, r: number): Color3
	local line = rows[r]
	local ch = string.sub(line, c * 2 - 1, c * 2 - 1)
	local v = (string.byte(line, c * 2) or 33) - 33
	if ch == "." then
		-- Shallows near land are pale turquoise, open sea a deep blue.
		local t = math.clamp(v / 30, 0, 1)
		return rgb(120, 206, 214):Lerp(rgb(36, 92, 140), t ^ 0.7)
	elseif ch == "w" then
		return rgb(86, 170, 210)
	end
	local base = LAND_COLOURS[ch] or LAND_COLOURS.g
	local function h(cc: number, rr: number): number
		if cc < 1 or rr < 1 or cc > cols or rr > nrows then
			return 0
		end
		local l = rows[rr]
		if string.sub(l, cc * 2 - 1, cc * 2 - 1) == "." then
			return 0
		end
		return (string.byte(l, cc * 2) or 33) - 33
	end
	local slope = (h(c - 1, r - 1) - h(c + 1, r + 1)) * 0.06
	local lift = math.clamp(v / 50, 0, 0.35)
	local col = base:Lerp(rgb(255, 250, 230), lift * 0.5)
	if slope > 0 then
		col = col:Lerp(rgb(255, 255, 240), math.clamp(slope, 0, 0.35))
	else
		col = col:Lerp(rgb(20, 24, 30), math.clamp(-slope, 0, 0.4))
	end
	return col
end

local function drawLand(data: Folder)
	local rows, cols, nrows = readLand(data)
	surfaceWorld.Size = UDim2.fromOffset(cols * SURFACE_PX, nrows * SURFACE_PX)
	local ok = pcall(function()
		local AssetService = game:GetService("AssetService")
		local image = AssetService:CreateEditableImage({ Size = Vector2.new(cols, nrows) })
		local buf = buffer.create(cols * nrows * 4)
		for r = 1, nrows do
			for c = 1, cols do
				local col = cellColour(rows, cols, nrows, c, r)
				local o = ((r - 1) * cols + (c - 1)) * 4
				buffer.writeu8(buf, o, math.floor(col.R * 255))
				buffer.writeu8(buf, o + 1, math.floor(col.G * 255))
				buffer.writeu8(buf, o + 2, math.floor(col.B * 255))
				buffer.writeu8(buf, o + 3, 255)
			end
			if r % 60 == 0 then
				task.wait()
			end
		end
		image:WritePixelsBuffer(Vector2.zero, Vector2.new(cols, nrows), buf)
		new("ImageLabel", {
			Parent = surfaceWorld,
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ImageContent = Content.fromObject(image),
			ZIndex = 1,
		})
	end)
	if ok then
		return
	end
	-- Fallback: each row's runs of one letter, merged down into rectangles.
	local open = {}
	for r = 1, nrows do
		local line = rows[r]
		local runs = {}
		local start, letter = 1, string.sub(line, 1, 1)
		for c = 2, cols + 1 do
			local ch = string.sub(line, c * 2 - 1, c * 2 - 1)
			if ch ~= letter then
				if letter ~= "." and letter ~= "" then
					table.insert(runs, start .. "," .. (c - 1) .. "," .. letter)
				end
				start, letter = c, ch
			end
		end
		local nextOpen = {}
		for _, key in runs do
			local entry = open[key]
			if entry then
				entry.frame.Size = UDim2.fromOffset(entry.frame.Size.X.Offset, (r - entry.row0 + 1) * SURFACE_PX)
				nextOpen[key] = entry
			else
				local parts = string.split(key, ",")
				local c0, c1 = tonumber(parts[1]) :: number, tonumber(parts[2]) :: number
				local colour = if parts[3] == "w" then rgb(86, 170, 210) else LAND_COLOURS[parts[3]] or LAND_COLOURS.g
				local frame = new("Frame", {
					Parent = surfaceWorld,
					Position = UDim2.fromOffset((c0 - 1) * SURFACE_PX, (r - 1) * SURFACE_PX),
					Size = UDim2.fromOffset((c1 - c0 + 1) * SURFACE_PX, SURFACE_PX),
					BackgroundColor3 = colour,
					BorderSizePixel = 0,
				})
				nextOpen[key] = { frame = frame, row0 = r }
			end
		end
		open = nextOpen
		if r % 40 == 0 then
			task.wait()
		end
	end
end

local function drawPlaces(places: StringValue)
	for _, entry in string.split(places.Value, ";") do
		local bits = string.split(entry, "|")
		if #bits == 3 then
			local p = surfacePixel(tonumber(bits[2]) :: number, tonumber(bits[3]) :: number)
			local isIsland = string.find(bits[1], "Isle") or string.find(bits[1], "Island") or string.find(bits[1], "Hills") or string.find(bits[1], "Shelf")
				or string.find(bits[1], "Marsh") or string.find(bits[1], "Cay") or string.find(bits[1], "Atoll") or string.find(bits[1], "Crags")
				or string.find(bits[1], "Mesa") or string.find(bits[1], "Ruins") or string.find(bits[1], "Key") or string.find(bits[1], "Rock")
			local label = new("TextLabel", {
				Parent = surfaceWorld,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(p.X, p.Y),
				Size = UDim2.fromOffset(120, 14),
				BackgroundTransparency = 1,
				FontFace = UIKit.FontFace,
				Text = bits[1],
				TextSize = if isIsland then 12 else 10,
				TextColor3 = if isIsland then rgb(255, 255, 255) else rgb(250, 214, 90),
				TextStrokeTransparency = 0.3,
				ZIndex = 3,
			})
			table.insert(pinned, new("UIScale", { Parent = label, Scale = 1 }))
			if not isIsland then
				label.Visible = false -- landmarks are just a dot; their names show when you get there
				local dot = new("Frame", { Parent = surfaceWorld, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(p.X, p.Y), Size = UDim2.fromOffset(5, 5), BackgroundColor3 = rgb(250, 214, 90), BorderSizePixel = 0, ZIndex = 3 }, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
				table.insert(pinned, new("UIScale", { Parent = dot, Scale = 1 }))
			end
		end
	end
end

local function loadCaves(data: Folder)
	for _, v in data:GetChildren() do
		if string.sub(v.Name, 1, 5) == "Caves" and v:IsA("StringValue") then
			for _, s in string.split(v.Value, ";") do
				local n = string.split(s, ",")
				if #n == 6 then
					table.insert(segments, {
						a = Vector2.new(tonumber(n[1]) :: number, tonumber(n[2]) :: number),
						b = Vector2.new(tonumber(n[3]) :: number, tonumber(n[4]) :: number),
						y = tonumber(n[5]) :: number,
						r = tonumber(n[6]) :: number,
					})
				end
			end
		end
	end
	local roomValue = data:FindFirstChild("Rooms") :: StringValue?
	if roomValue then
		for _, s in string.split(roomValue.Value, ";") do
			local n = string.split(s, ",")
			if #n == 4 then
				table.insert(rooms, { p = Vector2.new(tonumber(n[1]) :: number, tonumber(n[2]) :: number), r = tonumber(n[3]) :: number, y = tonumber(n[4]) :: number })
			end
		end
	end
end

-- Cave colours by depth, one clear band per layer, so a deep cave isn't one flat
-- blue splat: torch-lit brown up top, amber, teal, deep blue, and dark red down in
-- the lairs.
local DEPTH_BANDS = {
	{ -40, rgb(176, 128, 80) },
	{ -80, rgb(190, 150, 70) },
	{ -120, rgb(70, 150, 140) },
	{ -165, rgb(80, 110, 190) },
	{ -205, rgb(120, 90, 190) },
	{ -1000, rgb(170, 70, 80) },
}
local function caveColour(y: number): Color3
	for i, band in DEPTH_BANDS do
		if y > band[1] then
			if i == 1 then
				return band[2]
			end
			-- blend a little towards the band above near the boundary
			local above = DEPTH_BANDS[i - 1]
			local t = math.clamp((y - band[1]) / (above[1] - band[1]), 0, 1)
			return band[2]:Lerp(above[2], t * 0.35)
		end
	end
	return DEPTH_BANDS[#DEPTH_BANDS][2]
end

-- Each tunnel and room is drawn twice: a dark rim underneath (ZIndex 1) and the
-- lit floor on top (ZIndex 2), so overlapping passages merge into one clean cave
-- shape with an outline, instead of a pile of separate blobs.
local RIM = 3 -- studs of outline
local function capsule(pos: Vector2, length: number, width: number, rot: number, colour: Color3, z: number): Frame
	return new("Frame", {
		Parent = caveWorld,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(pos.X * CAVE_ZOOM, pos.Y * CAVE_ZOOM),
		Size = UDim2.fromOffset((length + width) * CAVE_ZOOM, width * CAVE_ZOOM),
		Rotation = rot,
		BackgroundColor3 = colour,
		BorderSizePixel = 0,
		ZIndex = z,
	}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
end

local function segmentFrame(s)
	local mid = (s.a + s.b) / 2
	local d = s.b - s.a
	local rot = math.deg(math.atan2(d.Y, d.X))
	local col = caveColour(s.y)
	s.rim = capsule(mid, d.Magnitude, s.r * 2 + RIM * 2, rot, col:Lerp(rgb(8, 6, 10), 0.7), 1)
	s.frame = capsule(mid, d.Magnitude, s.r * 2, rot, col, 2)
end

local function roomFrame(rm)
	local col = caveColour(rm.y)
	rm.rim = capsule(rm.p, 0, rm.r * 2 + RIM * 2, 0, col:Lerp(rgb(8, 6, 10), 0.7), 1)
	rm.frame = capsule(rm.p, 0, rm.r * 2, 0, col, 2)
end

-- Light up whatever is close to you, and fade out what's far above or below.
local function reveal(pos: Vector3)
	local here = Vector2.new(pos.X, pos.Z)
	for _, s in segments do
		if not s.frame then
			local ab = s.b - s.a
			local t = if ab.Magnitude > 0 then math.clamp((here - s.a):Dot(ab) / ab:Dot(ab), 0, 1) else 0
			local nearest = s.a + ab * t
			if (nearest - here).Magnitude < REVEAL and math.abs(s.y - pos.Y) < REVEAL then
				segmentFrame(s)
			end
		end
		if s.frame then
			local t = if math.abs(s.y - pos.Y) > SHOW_DEPTH then 0.75 else 0
			s.frame.BackgroundTransparency = t
			s.rim.BackgroundTransparency = t
		end
	end
	for _, rm in rooms do
		if not rm.frame and (rm.p - here).Magnitude < REVEAL + rm.r and math.abs(rm.y - pos.Y) < REVEAL then
			roomFrame(rm)
		end
		if rm.frame then
			local t = if math.abs(rm.y - pos.Y) > SHOW_DEPTH then 0.75 else 0
			rm.frame.BackgroundTransparency = t
			rm.rim.BackgroundTransparency = t
		end
	end
end

local function depthName(y: number): string
	if y > -45 then
		return "Upper Caves"
	elseif y > -80 then
		return "Lower Caves"
	elseif y > -150 then
		return "Deep Network"
	elseif y > -180 then
		return "The Maw"
	end
	return "Boss Lairs"
end

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { workspace.Terrain }
params.IgnoreWater = true

local function isUnderground(pos: Vector3): boolean
	if pos.Y > 0 then
		local up = workspace:Raycast(pos + Vector3.new(0, 3, 0), Vector3.new(0, 160, 0), params)
		return up ~= nil and pos.Y < (up.Position.Y - 12)
	end
	local up = workspace:Raycast(pos + Vector3.new(0, 3, 0), Vector3.new(0, 200, 0), params)
	return up ~= nil
end

-- The dive: zoom in hard, a ripple, black, then the other layer zooms out into place.
local function dive(down: boolean)
	diving = true
	local from = if down then surfaceLayer else caveLayer
	local to = if down then caveLayer else surfaceLayer
	local fromScale = from:FindFirstChild("Zoom") :: UIScale
	local toScale = to:FindFirstChild("Zoom") :: UIScale
	ripple.Size = UDim2.fromOffset(10, 10)
	ripple.Visible = true
	local stroke = ripple:FindFirstChildOfClass("UIStroke") :: UIStroke
	stroke.Transparency = 0
	TweenService:Create(ripple, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(SIZE * 1.4, SIZE * 1.4) }):Play()
	TweenService:Create(stroke, TweenInfo.new(0.6), { Transparency = 1 }):Play()
	TweenService:Create(fromScale, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = if down then 3 else 0.4 }):Play()
	TweenService:Create(darkness, TweenInfo.new(0.45), { BackgroundTransparency = 0 }):Play()
	task.wait(0.45)
	from.Visible = false
	to.Visible = true
	toScale.Scale = if down then 0.4 else 3
	TweenService:Create(toScale, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(darkness, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
	depthLabel.Visible = down
	task.wait(0.5)
	fromScale.Scale = 1
	ripple.Visible = false
	diving = false
end

local function layer(name: string): (Frame, Frame)
	local l = new("Frame", { Parent = root, Name = name, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ClipsDescendants = true }, {
		new("UIScale", { Name = "Zoom", Scale = 1 }),
	})
	local world = new("Frame", { Parent = l, Name = "World", BackgroundTransparency = 1, Size = UDim2.fromOffset(1, 1) }, {
		new("UIScale", { Name = "MapZoom", Scale = 1 }),
	})
	return l, world
end

function Minimap.init(parent: ScreenGui)
	-- A plain square: no rim, no rounded corners, just the map.
	local frame = new("Frame", { Parent = parent, Name = "Minimap", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 12, 1, -12), Size = UDim2.fromOffset(SIZE, SIZE), BackgroundTransparency = 1 })
	root = new("Frame", { Parent = frame, Size = UDim2.fromOffset(SIZE, SIZE), BackgroundColor3 = SEA, BorderSizePixel = 0, ClipsDescendants = true, Active = true })
	-- A thin dark frame round the map so it sits on the screen like a chart.
	new("UIStroke", { Parent = frame, Color = rgb(40, 30, 20), Thickness = 3, Transparency = 0.15 })
	new("Frame", { Parent = frame, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, {
		new("UIStroke", { Color = rgb(236, 224, 190), Thickness = 1, Transparency = 0.5 }),
	})
	local function setZoom(step: number)
		zoomIndex = math.clamp(zoomIndex + step, 1, #ZOOMS)
	end
	root.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			setZoom(if input.Position.Z > 0 then 1 else -1)
		end
	end)
	for i, sign in { "+", "-" } do
		local b = new("TextButton", { Parent = frame, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 4 + (i - 1) * 24), Size = UDim2.fromOffset(20, 20), BackgroundColor3 = rgb(40, 30, 20), BackgroundTransparency = 0.35, Text = sign, TextColor3 = rgb(255, 250, 235), TextSize = 18, FontFace = UIKit.FontFace, ZIndex = 12 }, {
			new("UICorner", { CornerRadius = UDim.new(0, 5) }),
		})
		b.MouseButton1Click:Connect(function()
			setZoom(if sign == "+" then 1 else -1)
		end)
	end
	-- Hide the map (button or M) and bring it back from the small tab left in its place.
	local hidden = false
	local tab = new("TextButton", { Parent = parent, Name = "MapTab", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 12, 1, -12), Size = UDim2.fromOffset(74, 26), BackgroundColor3 = rgb(40, 30, 20), BackgroundTransparency = 0.25, Text = "Map  [M]", TextColor3 = rgb(255, 250, 235), TextSize = 15, FontFace = UIKit.FontFace, Visible = false }, {
		new("UICorner", { CornerRadius = UDim.new(0, 6) }),
		new("UIStroke", { Color = rgb(236, 224, 190), Thickness = 1, Transparency = 0.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})
	local function setHidden(h: boolean)
		hidden = h
		tab.Visible = h
	end
	Minimap.setHidden = setHidden
	Minimap.isHidden = function()
		return hidden
	end
	local hide = new("TextButton", { Parent = frame, Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(20, 20), BackgroundColor3 = rgb(40, 30, 20), BackgroundTransparency = 0.35, Text = "×", TextColor3 = rgb(255, 250, 235), TextSize = 18, FontFace = UIKit.FontFace, ZIndex = 12 }, {
		new("UICorner", { CornerRadius = UDim.new(0, 5) }),
	})
	hide.MouseButton1Click:Connect(function()
		setHidden(true)
	end)
	tab.MouseButton1Click:Connect(function()
		setHidden(false)
	end)
	game:GetService("UserInputService").InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.M then
			setHidden(not hidden)
		end
	end)
	-- North marker on the top edge.
	new("TextLabel", { Parent = frame, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 2), Size = UDim2.fromOffset(16, 16), BackgroundTransparency = 1, Text = "N", TextColor3 = rgb(255, 250, 235), TextSize = 14, FontFace = UIKit.FontFace, TextStrokeTransparency = 0.2, ZIndex = 12 })
	surfaceLayer, surfaceWorld = layer("Surface")
	caveLayer, caveWorld = layer("Caves")
	caveLayer.BackgroundColor3 = rgb(14, 12, 18)
	caveLayer.BackgroundTransparency = 0
	caveLayer.Visible = false

	-- The flashlight: soft dark rings round the edge of the cave map.
	local light = new("Frame", { Parent = caveLayer, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(SIZE * 0.62, SIZE * 0.62), BackgroundTransparency = 1, ZIndex = 5 }, {
		new("UICorner", { CornerRadius = UDim.new(1, 0) }),
	})
	for k = 1, 6 do
		local ring = new("Frame", { Parent = light, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, k * 12, 1, k * 12), BackgroundTransparency = 1, ZIndex = 5 }, {
			new("UICorner", { CornerRadius = UDim.new(1, 0) }),
		})
		new("UIStroke", { Parent = ring, Color = rgb(6, 5, 8), Thickness = 7, Transparency = 0.9 - k * 0.14 })
	end
	local outer = new("Frame", { Parent = light, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 84, 1, 84), BackgroundTransparency = 1, ZIndex = 5 }, {
		new("UICorner", { CornerRadius = UDim.new(1, 0) }),
	})
	new("UIStroke", { Parent = outer, Color = rgb(6, 5, 8), Thickness = 160, Transparency = 0 })

	darkness = new("Frame", { Parent = root, Size = UDim2.fromScale(1, 1), BackgroundColor3 = rgb(6, 8, 14), BackgroundTransparency = 1, ZIndex = 8 })
	ripple = new("Frame", { Parent = root, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1, Visible = false, ZIndex = 9 }, {
		new("UICorner", { CornerRadius = UDim.new(1, 0) }),
		new("UIStroke", { Color = rgb(170, 220, 255), Thickness = 3 }),
	})
	arrow = new("TextLabel", { Parent = root, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(16, 16), BackgroundTransparency = 1, Text = "▲", TextColor3 = C.star, TextSize = 16, FontFace = UIKit.FontFace, TextStrokeTransparency = 0, ZIndex = 10 })
	depthLabel = UIKit.label({ Parent = frame, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -2), Size = UDim2.fromOffset(SIZE, 18), Text = "", TextScaled = false, TextSize = 15, Visible = false })

	task.spawn(function()
		local data = ReplicatedStorage:WaitForChild("MapData", 600)
		if not data then
			return
		end
		drawLand(data)
		drawPlaces(data:WaitForChild("Places") :: StringValue)
		loadCaves(data)
	end)

	local check = 0
	RunService.RenderStepped:Connect(function(dt)
		-- The inventory's craft panel sits where the map is: step aside while it's open.
		local inventory = parent:FindFirstChild("Inventory") :: Frame?
		frame.Visible = not hidden and not (inventory and inventory.Visible)
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not hrp then
			return
		end
		local pos = hrp.Position
		local target = ZOOMS[zoomIndex]
		if math.abs(target - zoom) > 0.001 then
			zoom += (target - zoom) * math.min(1, dt * 10)
			for _, sc in pinned do
				sc.Scale = 1 / zoom
			end
		end
		;(surfaceWorld:FindFirstChild("MapZoom") :: UIScale).Scale = zoom
		;(caveWorld:FindFirstChild("MapZoom") :: UIScale).Scale = zoom
		local p = surfacePixel(pos.X, pos.Z)
		surfaceWorld.Position = UDim2.fromOffset(SIZE / 2 - p.X * zoom, SIZE / 2 - p.Y * zoom)
		caveWorld.Position = UDim2.fromOffset(SIZE / 2 - pos.X * CAVE_ZOOM * zoom, SIZE / 2 - pos.Z * CAVE_ZOOM * zoom)
		local look = workspace.CurrentCamera.CFrame.LookVector
		arrow.Rotation = math.deg(math.atan2(look.X, -look.Z))

		check += dt
		if check > 0.25 then
			check = 0
			local below = isUnderground(pos)
			if below ~= underground and not diving then
				underground = below
				task.spawn(dive, below)
			end
			if underground then
				reveal(pos)
				depthLabel.Text = depthName(pos.Y) .. "  ·  " .. math.floor(-pos.Y) .. " down"
			end
		end
	end)
end

return Minimap
