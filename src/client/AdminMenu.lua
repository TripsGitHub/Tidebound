-- The admin menu: everything the chat commands do, as buttons, in the game's own tan
-- and driftwood style. Only admins see it (the server sets the "Admin" attribute; see
-- server/Admin.lua, which checks every command again). Open it with the Admin button
-- at the top left or F4.
--   Islands   jump to any island, named or not
--   Places    boss gates and lairs, the Maw, landmarks, camps, grottos, cave mouths
--   Players   everyone online: level, health, where they are and what they hold;
--             go to, bring, spectate, kill or kick them
--   Commands  heal, god mode, invisible, time of day, events, speed, mobs, caves...
--   Items     search any item and give yourself some
--   Camera    free cam (WASD, Q/E down/up, right mouse to look, Shift faster) and
--             see-everyone outlines with names through walls
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Items = require(Shared.Items)
local UIKit = require(script.Parent.UIKit)

local C = UIKit.Colors
local new, label, button, corner = UIKit.new, UIKit.label, UIKit.button, UIKit.corner

local player = Players.LocalPlayer
local AdminMenu = {}

local state: any = nil
local panel: Frame
local pages: { [string]: Frame } = {}
local tabButtons: { [string]: TextButton } = {}
local current = "Islands"
local refreshers: { [string]: () -> () } = {}

local function run(text: string)
	Remotes.AdminRun:FireServer(text)
end

local function requestState()
	run("__state")
end

local function scroller(parent: Instance, cell: Vector2?): ScrollingFrame
	local s = new("ScrollingFrame", {
		Parent = parent,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = C.wood,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	})
	if cell then
		new("UIGridLayout", { Parent = s, CellSize = UDim2.fromOffset(cell.X, cell.Y), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder })
	else
		new("UIListLayout", { Parent = s, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })
	end
	new("UIPadding", { Parent = s, PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 4) })
	return s
end

local function heading(parent: Instance, text: string, order: number)
	return label({ Parent = parent, LayoutOrder = order, Text = text, Size = UDim2.new(1, 0, 0, 24), TextXAlignment = Enum.TextXAlignment.Left })
end

local function flowRow(parent: Instance, order: number): Frame
	local row = new("Frame", { Parent = parent, LayoutOrder = order, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 })
	new("UIGridLayout", { Parent = row, CellSize = UDim2.fromOffset(118, 32), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder })
	return row
end

local function smallButton(parent: Instance, text: string, onClick: () -> (), colour: Color3?, order: number?)
	return button({ Parent = parent, Text = text, LayoutOrder = order or 0, Size = UDim2.fromOffset(118, 32), BackgroundColor3 = colour or C.button, TextSize = 15, TextScaled = false }, onClick)
end

-- Islands --------------------------------------------------------------------------

local function buildIslands(page: Frame)
	local list = scroller(page)
	refreshers.Islands = function()
		for _, c in list:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		if not state then
			return
		end
		heading(list, "Named islands", 1)
		local named = flowRow(list, 2)
		heading(list, "Nameless islands, islets and clusters", 3)
		local nameless = flowRow(list, 4)
		for i, isl in state.islands do
			smallButton(if isl.nameless then nameless else named, isl.name, function()
				run("tp " .. isl.name)
			end, if isl.nameless then C.cardDark else C.button, i)
		end
		heading(list, "Caves", 5)
		local caves = flowRow(list, 6)
		smallButton(caves, "Cave mouth", function()
			run("tp cave")
		end)
		smallButton(caves, "Deep cavern", function()
			run("tp deep")
		end)
		smallButton(caves, "Route end", function()
			run("tp ember")
		end)
	end
end

-- Places: boss gates and lairs, the Maw, cave mouths and seals, landmarks, camps,
-- grottos and secret rooms.
local GROUP_ORDER = { "Boss gates", "Boss lairs", "Caves", "Landmarks", "Camps", "Grottos", "Cave mouths", "Secret rooms" }
local function buildPlaces(page: Frame)
	local list = scroller(page)
	refreshers.Places = function()
		for _, c in list:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		if not state or not state.places then
			return
		end
		local rows = {}
		for i, g in GROUP_ORDER do
			local any = false
			for _, p in state.places do
				if p.group == g then
					any = true
				end
			end
			if any then
				heading(list, g, i * 2)
				rows[g] = flowRow(list, i * 2 + 1)
			end
		end
		for i, p in state.places do
			local row = rows[p.group]
			if row then
				smallButton(row, p.name, function()
					run(("tpxyz %d %d %d"):format(p.x, p.y, p.z))
				end, if string.find(p.group, "Boss") then C.warn else C.button, i).TextTruncate = Enum.TextTruncate.AtEnd
			end
		end
	end
end

-- Players --------------------------------------------------------------------------

local spectating: Player? = nil
local function spectate(target: Player?)
	local cam = workspace.CurrentCamera
	spectating = target
	local character = (target or player).Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	if hum then
		cam.CameraType = Enum.CameraType.Custom
		cam.CameraSubject = hum
	end
end

local function buildPlayers(page: Frame)
	local list = scroller(page)
	refreshers.Players = function()
		for _, c in list:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		if not state then
			return
		end
		if spectating then
			local stop = button({ Parent = list, LayoutOrder = 0, Text = "Stop spectating " .. spectating.DisplayName, Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = C.warn, TextSize = 16, TextScaled = false }, function()
				spectate(nil)
				refreshers.Players()
			end)
			stop.Name = "Stop"
		end
		for i, p in state.players do
			local row = UIKit.block({ Parent = list, LayoutOrder = i, Size = UDim2.new(1, 0, 0, 74), BackgroundColor3 = C.card })
			label({ Parent = row, Text = ("%s  (@%s)  Lv %d"):format(p.display, p.name, p.level), Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 22), TextXAlignment = Enum.TextXAlignment.Left })
			local hpText = ("HP %d/%d%s   %s   holding %s"):format(p.hp, p.maxHp, if p.god then " (god)" else "", p.where, tostring(p.held or "nothing"))
			label({ Parent = row, Text = hpText, Position = UDim2.fromOffset(10, 26), Size = UDim2.new(1, -20, 0, 16), TextXAlignment = Enum.TextXAlignment.Left })
			local bar = new("Frame", { Parent = row, Position = UDim2.fromOffset(10, 44), Size = UDim2.new(0.3, 0, 0, 6), BackgroundColor3 = C.barBack }, { corner(3) })
			new("Frame", { Parent = bar, Size = UDim2.fromScale(math.clamp(p.hp / math.max(p.maxHp, 1), 0, 1), 1), BackgroundColor3 = C.health }, { corner(3) })
			local actions = new("Frame", { Parent = row, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -6, 1, -6), Size = UDim2.fromOffset(0, 24), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1 })
			new("UIListLayout", { Parent = actions, FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), HorizontalAlignment = Enum.HorizontalAlignment.Right })
			local function act(text: string, fn: () -> (), colour: Color3?)
				button({ Parent = actions, Text = text, Size = UDim2.fromOffset(70, 24), BackgroundColor3 = colour or C.button, TextSize = 14, TextScaled = false }, fn)
			end
			if p.userId ~= player.UserId then
				act("Go to", function()
					run("tp " .. p.name)
				end)
				act("Bring", function()
					run("bring " .. p.name)
				end)
				act("Watch", function()
					spectate(Players:GetPlayerByUserId(p.userId))
					refreshers.Players()
				end)
				act("Kill", function()
					run("kill " .. p.name)
				end, C.bad)
				act("Kick", function()
					run("kick " .. p.name)
				end, C.bad)
			else
				act("Respawn", function()
					run("respawn")
				end)
			end
		end
	end
end

-- Commands -------------------------------------------------------------------------

local function buildCommands(page: Frame)
	local list = scroller(page)
	local order = 0
	local function section(title: string): Frame
		order += 1
		heading(list, title, order)
		order += 1
		return flowRow(list, order)
	end
	local me = section("You")
	for _, c in { { "Heal", "heal" }, { "God mode", "god" }, { "Invisible", "invis" }, { "Respawn", "respawn" }, { "Where am I", "where" }, { "Level 250", "level 250" }, { "Shells +100k", "shells 100000" } } do
		smallButton(me, c[1], function()
			run(c[2])
		end)
	end
	local move = section("Movement")
	for _, c in { { "Walk 16", "speed 16" }, { "Walk 50", "speed 50" }, { "Walk 120", "speed 120" }, { "Jump 50", "jump 50" }, { "Jump 150", "jump 150" } } do
		smallButton(move, c[1], function()
			run(c[2])
		end)
	end
	local world = section("World")
	for _, c in { { "Day", "day" }, { "Night", "night" }, { "Sunset", "time 18" }, { "Eruption", "erupt" }, { "Meteor shower", "meteor" }, { "Clear drops", "cleardrops" } } do
		smallButton(world, c[1], function()
			run(c[2])
		end)
	end
	local mobs = section("Spawn a mob next to you")
	refreshers.Commands = function()
		for _, c in mobs:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		for i, m in if state then state.mobs else {} do
			smallButton(mobs, m, function()
				run("mob " .. m .. " 1")
			end, C.cardDark, i)
		end
	end
end

-- Items ----------------------------------------------------------------------------

local function buildItems(page: Frame)
	local search = new("TextBox", { Parent = page, PlaceholderText = "Search items...", Text = "", Size = UDim2.new(1, -120, 0, 30), BackgroundColor3 = C.cardDark, TextColor3 = C.text, PlaceholderColor3 = C.rim, FontFace = UIKit.FontFace, TextSize = 16, ClearTextOnFocus = false }, { corner(6) })
	local amount = new("TextBox", { Parent = page, Text = "10", Position = UDim2.new(1, -112, 0, 0), Size = UDim2.fromOffset(112, 30), BackgroundColor3 = C.cardDark, TextColor3 = C.text, FontFace = UIKit.FontFace, TextSize = 16, ClearTextOnFocus = false }, { corner(6) })
	local holder = new("Frame", { Parent = page, Position = UDim2.fromOffset(0, 38), Size = UDim2.new(1, 0, 1, -38), BackgroundTransparency = 1 })
	local list = scroller(holder, Vector2.new(150, 30))
	local function fill()
		for _, c in list:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local q = search.Text:lower()
		local shown = 0
		for i, id in if state then state.items else {} do
			local item = Items[id]
			local name = if item then item.name else id
			if q == "" or string.find(name:lower(), q, 1, true) or string.find(id, q, 1, true) then
				shown += 1
				if shown > 160 then
					break
				end
				button({ Parent = list, LayoutOrder = i, Text = name, Size = UDim2.fromOffset(150, 30), TextSize = 13, TextScaled = false, TextTruncate = Enum.TextTruncate.AtEnd }, function()
					run("give " .. id .. " " .. (tonumber(amount.Text) or 1))
				end)
			end
		end
	end
	search:GetPropertyChangedSignal("Text"):Connect(fill)
	refreshers.Items = fill
end

-- Camera ---------------------------------------------------------------------------

local freecam = false
local camConn: RBXScriptConnection? = nil
local yaw, pitch = 0, 0
local function setFreecam(on: boolean)
	local cam = workspace.CurrentCamera
	freecam = on
	if camConn then
		camConn:Disconnect()
		camConn = nil
	end
	if on then
		local look = cam.CFrame.LookVector
		yaw, pitch = math.atan2(-look.X, -look.Z), math.asin(look.Y)
		cam.CameraType = Enum.CameraType.Scriptable
		-- Keep WASD and Space from moving the character while flying the camera.
		ContextActionService:BindActionAtPriority("AdminFreecam", function()
			return Enum.ContextActionResult.Sink
		end, false, 3000, Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.Q, Enum.KeyCode.E, Enum.KeyCode.Space)
		local pos = cam.CFrame.Position
		camConn = RunService.RenderStepped:Connect(function(dt)
			if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
				UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
				local d = UserInputService:GetMouseDelta()
				yaw -= d.X * 0.004
				pitch = math.clamp(pitch - d.Y * 0.004, -1.5, 1.5)
			else
				UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			end
			local rot = CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
			local move = Vector3.zero
			local typing = UserInputService:GetFocusedTextBox() ~= nil
			if not typing then
				local function key(k)
					return UserInputService:IsKeyDown(k)
				end
				if key(Enum.KeyCode.W) then
					move += Vector3.new(0, 0, -1)
				end
				if key(Enum.KeyCode.S) then
					move += Vector3.new(0, 0, 1)
				end
				if key(Enum.KeyCode.A) then
					move += Vector3.new(-1, 0, 0)
				end
				if key(Enum.KeyCode.D) then
					move += Vector3.new(1, 0, 0)
				end
				if key(Enum.KeyCode.E) or key(Enum.KeyCode.Space) then
					move += Vector3.new(0, 1, 0)
				end
				if key(Enum.KeyCode.Q) then
					move += Vector3.new(0, -1, 0)
				end
			end
			local speed = if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then 220 else 60
			pos += rot:VectorToWorldSpace(move) * speed * dt
			cam.CFrame = CFrame.new(pos) * rot
		end)
	else
		ContextActionService:UnbindAction("AdminFreecam")
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		spectate(spectating)
	end
end

local seeAll = false
local function setSeeAll(on: boolean)
	seeAll = on
	for _, p in Players:GetPlayers() do
		local character = p.Character
		if character and p ~= player then
			local h = character:FindFirstChild("AdminSee")
			if h then
				h:Destroy()
			end
			local tag = character:FindFirstChild("AdminTag")
			if tag then
				tag:Destroy()
			end
			if on then
				local hl = Instance.new("Highlight")
				hl.Name = "AdminSee"
				hl.FillTransparency = 0.7
				hl.FillColor = C.warn
				hl.OutlineColor = Color3.new(1, 1, 1)
				hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				hl.Parent = character
				local head = character:FindFirstChild("Head")
				if head then
					local bb = new("BillboardGui", { Name = "AdminTag", Parent = character, Adornee = head, AlwaysOnTop = true, Size = UDim2.fromOffset(200, 24), StudsOffset = Vector3.new(0, 3, 0), MaxDistance = 100000 })
					label({ Parent = bb, Text = p.DisplayName, Size = UDim2.fromScale(1, 1) })
				end
			end
		end
	end
end

local function buildCamera(page: Frame)
	local list = scroller(page)
	heading(list, "Free cam: WASD to fly, Q/E down and up, hold right mouse to look, Shift for speed", 1)
	local row = flowRow(list, 2)
	local fc
	fc = smallButton(row, "Free cam: off", function()
		setFreecam(not freecam)
		fc.Text = if freecam then "Free cam: on" else "Free cam: off"
	end)
	local sa
	sa = smallButton(row, "See all: off", function()
		setSeeAll(not seeAll)
		sa.Text = if seeAll then "See all: on" else "See all: off"
	end)
	smallButton(row, "Back to me", function()
		if freecam then
			setFreecam(false)
			fc.Text = "Free cam: off"
		end
		spectate(nil)
	end)
	heading(list, "See all outlines every other player through walls, with their name over them at any distance.", 3)
end

-- The window ------------------------------------------------------------------------

local function show(name: string)
	current = name
	for n, page in pages do
		page.Visible = n == name
		tabButtons[n].BackgroundColor3 = if n == name then C.plank else C.button
	end
	requestState()
	if refreshers[name] then
		refreshers[name]()
	end
end

local function build(root: ScreenGui)
	panel = UIKit.panel({ Parent = root, Name = "AdminMenu", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(720, 470), Visible = false, ZIndex = 20 })
	UIKit.title(panel, "Admin")
	UIKit.closeButton({ Parent = panel, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 8) }, function()
		panel.Visible = false
	end)
	local tabs = new("Frame", { Parent = panel, Position = UDim2.fromOffset(12, 30), Size = UDim2.new(0, 120, 1, -42), BackgroundTransparency = 1 })
	new("UIListLayout", { Parent = tabs, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })
	local body = UIKit.block({ Parent = panel, Position = UDim2.fromOffset(140, 30), Size = UDim2.new(1, -152, 1, -42), BackgroundColor3 = C.panelDark })
	new("UIPadding", { Parent = body, PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) })
	local builders = { { "Islands", buildIslands }, { "Places", buildPlaces }, { "Players", buildPlayers }, { "Commands", buildCommands }, { "Items", buildItems }, { "Camera", buildCamera } }
	for i, b in builders do
		local page = new("Frame", { Parent = body, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false })
		pages[b[1]] = page
		b[2](page)
		tabButtons[b[1]] = button({ Parent = tabs, LayoutOrder = i, Text = b[1], Size = UDim2.new(1, 0, 0, 38), TextSize = 18, TextScaled = false }, function()
			show(b[1])
		end)
	end
	-- The Admin button, top left under the menu buttons.
	button({ Parent = root, Name = "AdminButton", Text = "Admin", AnchorPoint = Vector2.new(0, 0), Position = UDim2.fromOffset(12, 110), Size = UDim2.fromOffset(84, 30), BackgroundColor3 = C.plank, TextSize = 16, TextScaled = false }, function()
		AdminMenu.toggle()
	end)
end

function AdminMenu.toggle()
	if not panel then
		return
	end
	panel.Visible = not panel.Visible
	if panel.Visible then
		show(current)
	end
end

function AdminMenu.init(root: ScreenGui)
	local function ready()
		if player:GetAttribute("Admin") and not panel then
			build(root)
		end
	end
	ready()
	player:GetAttributeChangedSignal("Admin"):Connect(ready)
	Remotes.AdminState.OnClientEvent:Connect(function(s)
		state = s
		if panel and panel.Visible and refreshers[current] and current ~= "Items" then
			refreshers[current]()
		elseif refreshers.Items and current == "Items" and panel and panel.Visible then
			refreshers.Items()
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.F4 then
			AdminMenu.toggle()
		end
	end)
	-- Keep the players list live while it's open, and the see-all outlines on new spawns.
	task.spawn(function()
		while true do
			task.wait(2)
			if panel and panel.Visible and current == "Players" then
				requestState()
			end
			if seeAll then
				setSeeAll(true)
			end
		end
	end)
end

return AdminMenu
