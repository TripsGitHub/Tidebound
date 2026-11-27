-- Overhead nameplates: a lashed wooden plank, like a sign hammered together on the
-- beach. The player's level sits on a carved bone token at the left end, the name is
-- burnt into the plank in big cream letters, and a smaller line above it holds a title
-- or tribe name. Replaces Roblox's default name display.
--
-- Built for cosmetics later: a plate style is chosen by the player's "Nameplate"
-- attribute (one of STYLES), and the line above by "Title" / "Tribe".
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIKit = require(script.Parent.UIKit)

local new = UIKit.new
local rgb = Color3.fromRGB

local Nameplates = {}

-- Plates keep a fixed pixel size on screen by default, so when you zoom out they
-- dwarf the character. Shrink them with camera distance instead: full size up
-- close, down to about 40% far away.
local W, H = 230, 66
local plates: { [BillboardGui]: { head: BasePart, scale: UIScale } } = {}
local function plateScale(dist: number): number
	return math.clamp(24 / math.max(dist, 1), 0.4, 1)
end

-- plank, darker edge, rope lashings, token, token rim, name colour
local STYLES = {
	plank = { plank = rgb(150, 104, 64), edge = rgb(84, 56, 34), rope = rgb(214, 190, 136), token = rgb(236, 226, 200), tokenRim = rgb(120, 96, 70), name = rgb(255, 242, 214) },
	driftwood = { plank = rgb(170, 160, 146), edge = rgb(96, 90, 82), rope = rgb(120, 180, 170), token = rgb(250, 226, 200), tokenRim = rgb(110, 150, 150), name = rgb(255, 255, 250) },
	ember = { plank = rgb(46, 40, 44), edge = rgb(20, 18, 20), rope = rgb(255, 120, 50), token = rgb(255, 170, 80), tokenRim = rgb(120, 40, 20), name = rgb(255, 210, 160) },
	frost = { plank = rgb(120, 160, 190), edge = rgb(60, 90, 120), rope = rgb(230, 244, 255), token = rgb(236, 248, 255), tokenRim = rgb(90, 140, 180), name = rgb(255, 255, 255) },
}

local function text(props)
	local l = new("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = UIKit.FontFace,
		TextScaled = false,
		TextStrokeTransparency = 1,
	})
	for k, v in props do
		if k ~= "Parent" then
			(l :: any)[k] = v
		end
	end
	new("UIStroke", { Parent = l, Color = rgb(30, 20, 12), Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual })
	l.Parent = props.Parent
	return l
end

local function attach(plr: Player, character: Model)
	local head = character:WaitForChild("Head", 10) :: BasePart?
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not head or not humanoid then
		return
	end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	local old = head:FindFirstChild("TideboundNameplate")
	if old then
		old:Destroy()
	end

	local gui = new("BillboardGui", {
		Name = "TideboundNameplate",
		Adornee = head,
		Size = UDim2.fromOffset(W, H),
		StudsOffsetWorldSpace = Vector3.new(0, 3, 0),
		AlwaysOnTop = false,
		MaxDistance = 160,
		LightInfluence = 0,
		Parent = head,
	})
	plates[gui] = { head = head, scale = new("UIScale", { Parent = gui, Scale = 1 }) }
	gui.Destroying:Connect(function()
		plates[gui] = nil
	end)

	-- The line above the plank: title or tribe (empty until there is one).
	local over = text({ Parent = gui, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.new(1, 0, 0, 16), Text = "", TextSize = 13, TextColor3 = rgb(250, 214, 90) })

	-- The plank: sized to the name, tilted a hair so it looks nailed up by hand.
	local plank = new("Frame", {
		Parent = gui,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.fromOffset(0, 30),
		AutomaticSize = Enum.AutomaticSize.X,
		Rotation = -1.5,
		BorderSizePixel = 0,
	}, {
		new("UICorner", { CornerRadius = UDim.new(0, 6) }),
		new("UIPadding", { PaddingLeft = UDim.new(0, 30), PaddingRight = UDim.new(0, 13) }),
	})
	local rim = new("UIStroke", { Parent = plank, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	-- Wood grain: two faint lines along the plank.
	local grain = {}
	for i, y in { 0.32, 0.7 } do
		grain[i] = new("Frame", { Parent = plank, Position = UDim2.new(0, -27, y, 0), Size = UDim2.new(1, 38, 0, 2), BackgroundTransparency = 0.7, BorderSizePixel = 0, ZIndex = 1 })
	end
	local name = text({ Parent = plank, Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X, Text = plr.DisplayName, TextSize = 18, ZIndex = 3 })

	-- Rope lashings at both ends.
	local ropes = {}
	for i, side in { 0, 1 } do
		ropes[i] = new("Frame", { Parent = plank, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(side, if side == 0 then -20 else 8, 0.5, 0), Size = UDim2.fromOffset(4, 36), BorderSizePixel = 0, ZIndex = 2 }, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	end

	-- The level token: a carved bone disc hanging over the left end.
	local token = new("Frame", { Parent = gui, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.fromOffset(36, 36), BorderSizePixel = 0, ZIndex = 4 }, {
		new("UICorner", { CornerRadius = UDim.new(1, 0) }),
	})
	local tokenRim = new("UIStroke", { Parent = token, Thickness = 2 })
	local level = text({ Parent = token, Size = UDim2.fromScale(1, 1), Text = "1", TextSize = 19, ZIndex = 5 })
	-- Digits read far better in a heavy sans than in the serif, so the level uses one,
	-- white on the dark token with a thick outline.
	level.FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.ExtraBold)
	level.TextColor3 = rgb(255, 255, 255)
	local levelStroke = level:FindFirstChildOfClass("UIStroke")
	if levelStroke then
		levelStroke.Thickness = 2.5
		levelStroke.Color = rgb(20, 12, 6)
	end

	-- Health: a thin bar under the plank that shows for a few seconds whenever your
	-- health changes (hit, healed), then fades away.
	local hpBack = new("Frame", { Parent = gui, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -2), Size = UDim2.fromOffset(120, 7), BackgroundColor3 = rgb(40, 28, 20), BorderSizePixel = 0, Visible = false, ZIndex = 6 }, {
		new("UICorner", { CornerRadius = UDim.new(1, 0) }),
		new("UIStroke", { Color = rgb(30, 20, 12), Thickness = 1.5 }),
	})
	local hpFill = new("Frame", { Parent = hpBack, Size = UDim2.fromScale(1, 1), BackgroundColor3 = rgb(110, 210, 90), BorderSizePixel = 0, ZIndex = 7 }, {
		new("UICorner", { CornerRadius = UDim.new(1, 0) }),
	})
	local lastHealth = humanoid.Health
	local shownAt = 0
	local function showHealth()
		local h = humanoid :: Humanoid
		if math.abs(h.Health - lastHealth) < 0.5 then
			return
		end
		lastHealth = h.Health
		local frac = math.clamp(h.Health / math.max(h.MaxHealth, 1), 0, 1)
		UIKit.slideBar(hpFill, frac)
		hpFill.BackgroundColor3 = if frac > 0.5 then rgb(110, 210, 90) elseif frac > 0.25 then rgb(236, 180, 60) else rgb(232, 80, 70)
		hpBack.Visible = true
		shownAt = os.clock()
		local mine = shownAt
		task.delay(4, function()
			if shownAt == mine then
				hpBack.Visible = false
			end
		end)
	end

	local function place()
		-- Keep the token on the plank's left end whatever the name's length.
		local fit = gui:FindFirstChildOfClass("UIScale")
		local w = plank.AbsoluteSize.X / (if fit and fit.Scale > 0 then fit.Scale else 1)
		token.Position = UDim2.new(0.5, -w / 2 + 5, 1, -11)
	end

	local function restyle()
		local s = STYLES[plr:GetAttribute("Nameplate") or "plank"] or STYLES.plank
		plank.BackgroundColor3 = s.plank
		rim.Color = s.edge
		for _, g in grain do
			g.BackgroundColor3 = s.edge
		end
		for _, r in ropes do
			r.BackgroundColor3 = s.rope
		end
		token.BackgroundColor3 = s.edge
		tokenRim.Color = s.token
		tokenRim.Thickness = 2.5
		name.TextColor3 = s.name
		local tribe, title = plr:GetAttribute("Tribe"), plr:GetAttribute("Title")
		over.Text = if tribe and title then "[" .. tribe .. "] " .. title elseif tribe then "[" .. tribe .. "]" else (title or "")
	end
	local function refresh()
		level.Text = tostring(plr:GetAttribute("Level") or 1)
	end
	refresh()
	restyle()
	local conns = {
		plr:GetAttributeChangedSignal("Level"):Connect(refresh),
		plr:GetAttributeChangedSignal("Nameplate"):Connect(restyle),
		plr:GetAttributeChangedSignal("Title"):Connect(restyle),
		plr:GetAttributeChangedSignal("Tribe"):Connect(restyle),
		plank:GetPropertyChangedSignal("AbsoluteSize"):Connect(place),
		humanoid.HealthChanged:Connect(showHealth),
	}
	place()
	gui.Destroying:Connect(function()
		for _, c in conns do
			c:Disconnect()
		end
	end)
end

local function watch(plr: Player)
	if plr.Character then
		task.spawn(attach, plr, plr.Character)
	end
	plr.CharacterAdded:Connect(function(character)
		attach(plr, character)
	end)
end

function Nameplates.start()
	RunService.RenderStepped:Connect(function()
		local cam = workspace.CurrentCamera
		if not cam then
			return
		end
		local eye = cam.CFrame.Position
		for gui, p in plates do
			if not gui.Parent then
				plates[gui] = nil
				continue
			end
			local s = plateScale((p.head.Position - eye).Magnitude)
			if math.abs(p.scale.Scale - s) > 0.01 then
				p.scale.Scale = s
				gui.Size = UDim2.fromOffset(W * s, H * s)
			end
		end
	end)
	for _, plr in Players:GetPlayers() do
		watch(plr)
	end
	Players.PlayerAdded:Connect(watch)
end

return Nameplates
