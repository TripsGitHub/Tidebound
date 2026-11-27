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
local SURFACE_PX = 3 -- pixels per land cell above ground
local CAVE_ZOOM = 0.55 -- pixels per stud underground
local REVEAL = 55 -- studs: how far your light reaches on the cave map
local SHOW_DEPTH = 40 -- studs: tunnels this far above or below you aren't drawn

local LAND_COLOURS = {
	s = rgb(222, 204, 150),
	g = rgb(120, 168, 82),
	f = rgb(96, 136, 66),
	r = rgb(130, 126, 120),
	n = rgb(240, 246, 250),
	i = rgb(170, 216, 236),
	m = rgb(96, 110, 66),
	d = rgb(140, 110, 76),
	b = rgb(64, 60, 66),
	l = rgb(240, 110, 40),
}
local SEA = rgb(58, 112, 150)

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

local function surfacePixel(x: number, z: number): Vector2
	return Vector2.new((x - x0) / cell * SURFACE_PX, (z - z0) / cell * SURFACE_PX)
end

-- Land: each row's runs of one letter, merged down into rectangles where the next
-- rows have the same run (a few hundred frames for the whole map).
local function drawLand(land: StringValue)
	cell = land:GetAttribute("Cell") or 32
	x0, z0 = land:GetAttribute("X0") or 0, land:GetAttribute("Z0") or 0
	local cols = land:GetAttribute("Cols") or 0
	local rows = string.split(land.Value, "\n")
	surfaceWorld.Size = UDim2.fromOffset(cols * SURFACE_PX, #rows * SURFACE_PX)
	local open = {} -- key "start,end,letter" -> { frame, row0 }
	for r, line in rows do
		local runs = {}
		local start, letter = 1, string.sub(line, 1, 1)
		for c = 2, #line + 1 do
			local ch = string.sub(line, c, c)
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
				local frame = new("Frame", {
					Parent = surfaceWorld,
					Position = UDim2.fromOffset((c0 - 1) * SURFACE_PX, (r - 1) * SURFACE_PX),
					Size = UDim2.fromOffset((c1 - c0 + 1) * SURFACE_PX, SURFACE_PX),
					BackgroundColor3 = LAND_COLOURS[parts[3]] or LAND_COLOURS.g,
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
			if not isIsland then
				label.Position = UDim2.fromOffset(p.X, p.Y + 8)
				new("Frame", { Parent = surfaceWorld, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(p.X, p.Y), Size = UDim2.fromOffset(5, 5), BackgroundColor3 = rgb(250, 214, 90), BorderSizePixel = 0, ZIndex = 3 }, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
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

-- Cave colours by depth: warm torch-lit brown up high, cold crystal blue deep down.
local function caveColour(y: number): Color3
	local t = math.clamp((-y - 30) / 70, 0, 1)
	return rgb(170, 120, 74):Lerp(rgb(90, 120, 210), t)
end

local function segmentFrame(s)
	local mid = (s.a + s.b) / 2
	local d = s.b - s.a
	s.frame = new("Frame", {
		Parent = caveWorld,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(mid.X * CAVE_ZOOM, mid.Y * CAVE_ZOOM),
		Size = UDim2.fromOffset(d.Magnitude * CAVE_ZOOM + s.r * CAVE_ZOOM * 2, s.r * 2 * CAVE_ZOOM),
		Rotation = math.deg(math.atan2(d.Y, d.X)),
		BackgroundColor3 = caveColour(s.y),
		BorderSizePixel = 0,
	}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
end

local function roomFrame(rm)
	rm.frame = new("Frame", {
		Parent = caveWorld,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(rm.p.X * CAVE_ZOOM, rm.p.Y * CAVE_ZOOM),
		Size = UDim2.fromOffset(rm.r * 2 * CAVE_ZOOM, rm.r * 2 * CAVE_ZOOM),
		BackgroundColor3 = caveColour(rm.y),
		BorderSizePixel = 0,
	}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
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
			s.frame.BackgroundTransparency = if math.abs(s.y - pos.Y) > SHOW_DEPTH then 0.75 else 0
		end
	end
	for _, rm in rooms do
		if not rm.frame and (rm.p - here).Magnitude < REVEAL + rm.r and math.abs(rm.y - pos.Y) < REVEAL then
			roomFrame(rm)
		end
		if rm.frame then
			rm.frame.BackgroundTransparency = if math.abs(rm.y - pos.Y) > SHOW_DEPTH then 0.75 else 0
		end
	end
end

local function depthName(y: number): string
	if y > -45 then
		return "Upper Caves"
	elseif y > -80 then
		return "Lower Caves"
	end
	return "Deep Network"
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
	local world = new("Frame", { Parent = l, Name = "World", BackgroundTransparency = 1, Size = UDim2.fromOffset(1, 1) })
	return l, world
end

function Minimap.init(parent: ScreenGui)
	local frame = UIKit.panel({ Parent = parent, Name = "Minimap", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 12, 1, -12), Size = UDim2.fromOffset(SIZE + 10, SIZE + 10) })
	root = new("Frame", { Parent = frame, Position = UDim2.fromOffset(5, 5), Size = UDim2.fromOffset(SIZE, SIZE), BackgroundColor3 = SEA, BorderSizePixel = 0, ClipsDescendants = true }, {
		new("UICorner", { CornerRadius = UDim.new(0, 8) }),
	})
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
		drawLand(data:WaitForChild("Land") :: StringValue)
		drawPlaces(data:WaitForChild("Places") :: StringValue)
		loadCaves(data)
	end)

	local check = 0
	RunService.RenderStepped:Connect(function(dt)
		-- The inventory's craft panel sits where the map is: step aside while it's open.
		local inventory = parent:FindFirstChild("Inventory") :: Frame?
		frame.Visible = not (inventory and inventory.Visible)
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not hrp then
			return
		end
		local pos = hrp.Position
		local p = surfacePixel(pos.X, pos.Z)
		surfaceWorld.Position = UDim2.fromOffset(SIZE / 2 - p.X, SIZE / 2 - p.Y)
		caveWorld.Position = UDim2.fromOffset(SIZE / 2 - pos.X * CAVE_ZOOM, SIZE / 2 - pos.Z * CAVE_ZOOM)
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
