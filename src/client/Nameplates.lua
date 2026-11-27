-- Overhead nameplates: a lashed wooden plank, like a sign hammered together on the
-- beach. The player's level sits on a carved bone token at the left end, the name is
-- burnt into the plank in big cream letters, and a smaller line above it holds a title
-- or tribe name. Replaces Roblox's default name display.
--
-- Built for cosmetics later: a plate style is chosen by the player's "Nameplate"
-- attribute (one of STYLES), and the line above by "Title" / "Tribe".
local Players = game:GetService("Players")
local UIKit = require(script.Parent.UIKit)

local new = UIKit.new
local rgb = Color3.fromRGB

local Nameplates = {}

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
		Size = UDim2.fromOffset(300, 74),
		StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0),
		AlwaysOnTop = false,
		MaxDistance = 160,
		LightInfluence = 0,
		Parent = head,
	})

	-- The line above the plank: title or tribe (empty until there is one).
	local over = text({ Parent = gui, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.new(1, 0, 0, 20), Text = "", TextSize = 16, TextColor3 = rgb(250, 214, 90) })

	-- The plank: sized to the name, tilted a hair so it looks nailed up by hand.
	local plank = new("Frame", {
		Parent = gui,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -4),
		Size = UDim2.fromOffset(0, 40),
		AutomaticSize = Enum.AutomaticSize.X,
		Rotation = -1.5,
		BorderSizePixel = 0,
	}, {
		new("UICorner", { CornerRadius = UDim.new(0, 6) }),
		new("UIPadding", { PaddingLeft = UDim.new(0, 40), PaddingRight = UDim.new(0, 18) }),
	})
	local rim = new("UIStroke", { Parent = plank, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	-- Wood grain: two faint lines along the plank.
	local grain = {}
	for i, y in { 0.32, 0.7 } do
		grain[i] = new("Frame", { Parent = plank, Position = UDim2.new(0, -36, y, 0), Size = UDim2.new(1, 50, 0, 2), BackgroundTransparency = 0.7, BorderSizePixel = 0, ZIndex = 1 })
	end
	local name = text({ Parent = plank, Size = UDim2.fromOffset(0, 40), AutomaticSize = Enum.AutomaticSize.X, Text = plr.DisplayName, TextSize = 24, ZIndex = 3 })

	-- Rope lashings at both ends.
	local ropes = {}
	for i, side in { 0, 1 } do
		ropes[i] = new("Frame", { Parent = plank, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(side, if side == 0 then -26 else 10, 0.5, 0), Size = UDim2.fromOffset(5, 48), BorderSizePixel = 0, ZIndex = 2 }, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	end

	-- The level token: a carved bone disc hanging over the left end.
	local token = new("Frame", { Parent = gui, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.fromOffset(44, 44), BorderSizePixel = 0, ZIndex = 4 }, {
		new("UICorner", { CornerRadius = UDim.new(1, 0) }),
	})
	local tokenRim = new("UIStroke", { Parent = token, Thickness = 3 })
	local level = text({ Parent = token, Size = UDim2.fromScale(1, 1), Text = "1", TextSize = 20, ZIndex = 5 })

	local function place()
		-- Keep the token on the plank's left end whatever the name's length.
		local w = plank.AbsoluteSize.X
		token.Position = UDim2.new(0.5, -w / 2 + 6, 1, 2)
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
		token.BackgroundColor3 = s.token
		tokenRim.Color = s.tokenRim
		level.TextColor3 = s.edge
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
	for _, plr in Players:GetPlayers() do
		watch(plr)
	end
	Players.PlayerAdded:Connect(watch)
end

return Nameplates
