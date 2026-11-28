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
local W, H = 230, 100
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

-- owner: the Player (or, for an NPC, its own model) whose attributes drive the plate.
local function attach(plr: any, character: Model, displayName: string?, npc: boolean?)
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
		StudsOffsetWorldSpace = Vector3.new(0, 3.6, 0),
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
	local name = text({ Parent = plank, Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X, Text = displayName or plr.DisplayName, TextSize = 18, ZIndex = 3 })

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

	-- NPCs get the same plank, plus a speech-bubble badge on the right end, so you can
	-- tell at a glance it's someone to talk to.
	if npc then
		local badge = new("Frame", { Parent = plank, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(1, 2, 0.5, 0), Size = UDim2.fromOffset(26, 26), BackgroundColor3 = rgb(250, 214, 90), BorderSizePixel = 0, ZIndex = 4 }, {
			new("UICorner", { CornerRadius = UDim.new(1, 0) }),
			new("UIStroke", { Color = rgb(84, 56, 34), Thickness = 2 }),
		})
		-- A drawn speech bubble: a round body and a small tail.
		new("Frame", { Parent = badge, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(15, 11), BackgroundColor3 = rgb(84, 56, 34), BorderSizePixel = 0, ZIndex = 5 }, {
			new("UICorner", { CornerRadius = UDim.new(1, 0) }),
		})
		new("Frame", { Parent = badge, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.36, 0.7), Size = UDim2.fromOffset(5, 5), Rotation = 45, BackgroundColor3 = rgb(84, 56, 34), BorderSizePixel = 0, ZIndex = 5 })
		for k = -1, 1 do
			new("Frame", { Parent = badge, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, k * 4, 0.45, 0), Size = UDim2.fromOffset(2.5, 2.5), BackgroundColor3 = rgb(250, 214, 90), BorderSizePixel = 0, ZIndex = 6 }, {
				new("UICorner", { CornerRadius = UDim.new(1, 0) }),
			})
		end
		local pad = plank:FindFirstChildOfClass("UIPadding")
		if pad then
			pad.PaddingRight = UDim.new(0, 30)
		end
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
	-- Armour badges over the plate, seen by everyone: a blue shield for how much of a
	-- player's hit it blocks and a green slime for a mob's. Hidden with no armour on.
	local badgeRow = new("Frame", { Parent = gui, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(220, 34), BackgroundTransparency = 1, Visible = false }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local function pctLabel(parent: Instance)
		local pill = new("Frame", { Parent = parent, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromOffset(34, 14), BackgroundColor3 = rgb(236, 236, 236), BorderSizePixel = 0, ZIndex = 9 }, {
			new("UICorner", { CornerRadius = UDim.new(1, 0) }),
			new("UIStroke", { Color = rgb(30, 30, 30), Thickness = 1.5 }),
		})
		local l = new("TextLabel", { Parent = pill, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "0%", TextScaled = true, TextColor3 = rgb(20, 20, 20), FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold), ZIndex = 10 })
		return l
	end
	-- Island Tribes-style shield badges: a flat-topped heater shield with raised top
	-- corners, a thick dark outline, crisp corners (nothing rounded), and a two-tone
	-- fill, lighter on the left like light coming from one side.
	local function shieldShape(parent: Instance, fill: Color3, edge: Color3)
		local light = fill:Lerp(Color3.new(1, 1, 1), 0.28)
		local function twoTone(f: Frame, rot: number)
			new("UIGradient", {
				Parent = f,
				Rotation = rot,
				Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, light), ColorSequenceKeypoint.new(0.5, light), ColorSequenceKeypoint.new(0.501, fill), ColorSequenceKeypoint.new(1, fill) }),
			})
		end
		-- Outline first (one size up, dark), then the fill on top.
		for layer = 1, 2 do
			local pad = if layer == 1 then 3 else 0
			local col = if layer == 1 then edge else Color3.new(1, 1, 1)
			local z = 5 + layer
			local top = new("Frame", { Parent = parent, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 4 - pad / 2), Size = UDim2.fromOffset(26 + pad, 16 + pad), BackgroundColor3 = col, BorderSizePixel = 0, ZIndex = z })
			local point = new("Frame", { Parent = parent, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 19), Size = UDim2.fromOffset(18.5 + pad, 18.5 + pad), Rotation = 45, BackgroundColor3 = col, BorderSizePixel = 0, ZIndex = z })
			-- The raised corners at the top.
			for side = -1, 1, 2 do
				local horn = new("Frame", { Parent = parent, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, side * 10, 0, 4), Size = UDim2.fromOffset(7 + pad, 7 + pad), Rotation = 45, BackgroundColor3 = col, BorderSizePixel = 0, ZIndex = z })
				if layer == 2 then
					horn.BackgroundColor3 = if side < 0 then light else fill
				end
			end
			if layer == 2 then
				twoTone(top, 0)
				twoTone(point, -45)
			end
		end
	end
	local shield = new("Frame", { Parent = badgeRow, LayoutOrder = 1, Size = UDim2.fromOffset(34, 34), BackgroundTransparency = 1 })
	shieldShape(shield, rgb(38, 112, 226), rgb(12, 30, 72))
	local vsPlayer = pctLabel(shield)
	-- Against mobs: the same shield in green.
	local slime = new("Frame", { Parent = badgeRow, LayoutOrder = 2, Size = UDim2.fromOffset(34, 34), BackgroundTransparency = 1 })
	shieldShape(slime, rgb(58, 160, 52), rgb(14, 50, 14))
	local vsMob = pctLabel(slime)
	-- Stat add-ons: one round badge per active booster, next to the armour badges.
	-- Each reads a player attribute holding a percentage; nil or 0 hides it. New
	-- boosters only need a line here (and the server setting the attribute).
	local BOOSTS = {
		{ attr = "BoostSpeed", glyph = ">>", fill = rgb(250, 196, 40), edge = rgb(110, 70, 10), sign = "+" },
		{ attr = "BoostDamage", glyph = "X", fill = rgb(230, 60, 50), edge = rgb(90, 16, 12), sign = "+" },
		{ attr = "BoostRegen", glyph = "+", fill = rgb(90, 200, 90), edge = rgb(20, 70, 20), sign = "+" },
		{ attr = "Heavy", glyph = "kg", fill = rgb(130, 130, 140), edge = rgb(40, 40, 46), sign = "-" },
	}
	local boostBadges = {}
	for i, b in BOOSTS do
		local holder = new("Frame", { Parent = badgeRow, LayoutOrder = 2 + i, Size = UDim2.fromOffset(32, 34), BackgroundTransparency = 1, Visible = false })
		-- A crisp diamond (a turned square) with a dark rim and a lit left half.
		new("Frame", { Parent = holder, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 13), Size = UDim2.fromOffset(23, 23), Rotation = 45, BackgroundColor3 = b.edge, BorderSizePixel = 0, ZIndex = 6 })
		local gem = new("Frame", { Parent = holder, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 13), Size = UDim2.fromOffset(18, 18), Rotation = 45, BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 7 }, {
			new("UIGradient", { Rotation = -45, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, b.fill:Lerp(Color3.new(1, 1, 1), 0.3)), ColorSequenceKeypoint.new(0.5, b.fill:Lerp(Color3.new(1, 1, 1), 0.3)), ColorSequenceKeypoint.new(0.501, b.fill), ColorSequenceKeypoint.new(1, b.fill) }) }),
		})
		local disc = new("Frame", { Parent = holder, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 13), Size = UDim2.fromOffset(20, 20), BackgroundTransparency = 1, ZIndex = 8 })
		local _ = gem
		new("TextLabel", { Parent = disc, Size = UDim2.fromScale(1, 0.9), BackgroundTransparency = 1, Text = b.glyph, TextScaled = true, TextColor3 = rgb(255, 255, 255), TextStrokeTransparency = 0.3, FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Heavy), ZIndex = 8 })
		local pill = pctLabel(holder)
		pill.Parent.Position = UDim2.fromScale(0.5, 0.82)
		boostBadges[i] = { holder = holder, label = pill, spec = b }
	end
	local function armour()
		local m, p = plr:GetAttribute("DefMob") or 0, plr:GetAttribute("DefPlayer") or 0
		local anyBoost = false
		for _, bb in boostBadges do
			local v = plr:GetAttribute(bb.spec.attr)
			local on = type(v) == "number" and v ~= 0
			bb.holder.Visible = on
			if on then
				anyBoost = true
				bb.label.Text = bb.spec.sign .. tostring(math.abs(v)) .. "%"
			end
		end
		shield.Visible, slime.Visible = m > 0 or p > 0, m > 0 or p > 0
		badgeRow.Visible = not npc and (m > 0 or p > 0 or anyBoost)
		local function fmt(n: number)
			return (if n == math.floor(n) then tostring(n) else string.format("%.1f", n)) .. "%"
		end
		vsPlayer.Text, vsMob.Text = fmt(p), fmt(m)
	end
	armour()
	over.Position = UDim2.new(0.5, 0, 0, 36)

	local conns = {
		plr:GetAttributeChangedSignal("DefMob"):Connect(armour),
		plr:GetAttributeChangedSignal("DefPlayer"):Connect(armour),
		plr:GetAttributeChangedSignal("BoostSpeed"):Connect(armour),
		plr:GetAttributeChangedSignal("BoostDamage"):Connect(armour),
		plr:GetAttributeChangedSignal("BoostRegen"):Connect(armour),
		plr:GetAttributeChangedSignal("Heavy"):Connect(armour),
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

local function watchNpc(model: Instance)
	if model:IsA("Model") then
		task.spawn(attach, model, model, model:GetAttribute("NpcName") or model.Name, true)
	end
end

function Nameplates.start()
	local CollectionService = game:GetService("CollectionService")
	for _, m in CollectionService:GetTagged("NPC") do
		watchNpc(m)
	end
	CollectionService:GetInstanceAddedSignal("NPC"):Connect(watchNpc)
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
