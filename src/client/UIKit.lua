-- Shared look for all UI, taken from how Island Tribes-style survival games read in
-- play: flat tan panels that let the world show through a little, a thin cream rim,
-- small rounded corners, and bold white text with a dark outline. No textures,
-- gradients or bevels. Buttons are mostly just words ("Equip  Drop"); only Trade
-- (green) and close (red) get a coloured pill.
local UIKit = {}

UIKit.Colors = {
	panel = Color3.fromRGB(196, 176, 130), -- main tan
	panelDark = Color3.fromRGB(170, 150, 108), -- tab / bar backs
	card = Color3.fromRGB(178, 158, 114), -- a card inside a panel
	cardDark = Color3.fromRGB(150, 131, 92), -- icon squares, ingredient boxes, "Craft" strip
	cardLocked = Color3.fromRGB(104, 92, 70),
	rim = Color3.fromRGB(236, 224, 190), -- the thin cream edge on panels
	edge = Color3.fromRGB(46, 34, 20), -- text outline
	text = Color3.fromRGB(255, 255, 255),
	textLight = Color3.fromRGB(255, 255, 255),
	button = Color3.fromRGB(150, 131, 92),
	good = Color3.fromRGB(88, 186, 74), -- "Trade", have-enough counts
	bad = Color3.fromRGB(232, 86, 80), -- close X, missing counts
	warn = Color3.fromRGB(236, 140, 60),
	health = Color3.fromRGB(158, 62, 66), -- deep red, not neon
	hunger = Color3.fromRGB(176, 112, 64), -- muted amber
	bag = Color3.fromRGB(78, 116, 146), -- slate blue
	barBack = Color3.fromRGB(52, 44, 34), -- dark brown behind stat bars
	xp = Color3.fromRGB(96, 168, 72), -- green, like the XP orbs
	gold = Color3.fromRGB(246, 200, 72),
	star = Color3.fromRGB(250, 214, 90),
}

-- Merriweather everywhere: a sturdy serif that reads like an old adventure game
-- and suits the wooden-sign logo style, without the bubbly cartoon fonts most
-- simulator games use. Still white with a dark outline, like the footage.
-- Enum.Font only has the regular weight, so text uses FontFace for bold.
UIKit.FontFace = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Bold)
UIKit.Font = Enum.Font.Merriweather
UIKit.FontHeavy = Enum.Font.Merriweather

UIKit.PANEL_ALPHA = 0.12 -- how see-through panels are

function UIKit.new(className: string, props, children: { Instance }?): any
	local inst = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			(inst :: any)[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	if props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

function UIKit.corner(r: number?)
	return UIKit.new("UICorner", { CornerRadius = UDim.new(0, r or 8) })
end

function UIKit.round()
	return UIKit.new("UICorner", { CornerRadius = UDim.new(1, 0) })
end

function UIKit.stroke(color: Color3?, thickness: number?)
	return UIKit.new("UIStroke", { Color = color or UIKit.Colors.rim, Thickness = thickness or 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

-- Soft drop shadow instead of an outline. Roblox has no text shadow, so the label
-- you get back keeps its text invisible (it still sizes and lays out as normal),
-- and two children draw the text: a faint dark copy 2px down-right, and the real
-- text on top. Changes to Text, colour, size, font and transparency on the label
-- are copied to both.
local SHADOW = Color3.fromRGB(30, 22, 12)
local SYNC = { "Text", "TextSize", "TextScaled", "FontFace", "TextXAlignment", "TextYAlignment", "TextWrapped", "TextTruncate", "RichText", "LineHeight", "ZIndex", "Visible" }
function UIKit.shadowText(outer: TextLabel | TextButton)
	local function copy(offset: Vector2, color: Color3): TextLabel
		local t = Instance.new("TextLabel")
		t.Name = if offset.Magnitude > 0 then "Shadow" else "Face"
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Position = UDim2.fromOffset(offset.X, offset.Y)
		t.TextColor3 = color
		t.TextStrokeTransparency = 1
		t.Active = false
		for _, k in SYNC do
			if k ~= "Visible" then
				(t :: any)[k] = (outer :: any)[k]
			end
		end
		t.Parent = outer
		return t
	end
	local shadow = copy(Vector2.new(1, 2), SHADOW)
	local face = copy(Vector2.zero, outer.TextColor3)
	local guard = false
	local function setAlpha()
		if guard then
			return
		end
		local a = outer.TextTransparency
		face.TextTransparency = a
		shadow.TextTransparency = 1 - (1 - a) * 0.6
		guard = true
		outer.TextTransparency = 1
		guard = false
	end
	setAlpha()
	outer.TextStrokeTransparency = 1
	outer:GetPropertyChangedSignal("TextTransparency"):Connect(setAlpha)
	outer:GetPropertyChangedSignal("TextColor3"):Connect(function()
		face.TextColor3 = outer.TextColor3
	end)
	for _, k in SYNC do
		if k ~= "Visible" then
			outer:GetPropertyChangedSignal(k):Connect(function()
				(shadow :: any)[k] = (outer :: any)[k];
				(face :: any)[k] = (outer :: any)[k]
			end)
		end
	end
	-- Size limits added to the label apply to the visible copies too.
	local function constrain(c: Instance)
		if c:IsA("UITextSizeConstraint") then
			c:Clone().Parent = shadow
			c:Clone().Parent = face
		end
	end
	for _, c in outer:GetChildren() do
		constrain(c)
	end
	outer.ChildAdded:Connect(constrain)
	return outer
end

-- White text with a soft shadow (see shadowText). The only text style in the game.
function UIKit.label(props)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	if props.Font == nil and props.FontFace == nil then
		props.FontFace = UIKit.FontFace
	end
	props.TextColor3 = props.TextColor3 or UIKit.Colors.text
	props.TextStrokeColor3 = props.TextStrokeColor3 or UIKit.Colors.edge
	props.TextStrokeTransparency = props.TextStrokeTransparency or 0
	if props.TextScaled == nil and props.TextSize == nil then
		props.TextScaled = true
	end
	return UIKit.shadowText(UIKit.new("TextLabel", props))
end

UIKit.hudText = UIKit.label

-- A word you can click, with no box around it ("Equip", "Drop", "Craft").
function UIKit.textButton(props, onClick: () -> ())
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	if props.Font == nil and props.FontFace == nil then
		props.FontFace = UIKit.FontFace
	end
	props.TextColor3 = props.TextColor3 or UIKit.Colors.text
	props.TextStrokeColor3 = props.TextStrokeColor3 or UIKit.Colors.edge
	props.TextStrokeTransparency = 0
	props.AutoButtonColor = false
	if props.TextScaled == nil and props.TextSize == nil then
		props.TextScaled = true
	end
	local b = UIKit.shadowText(UIKit.new("TextButton", props))
	b.MouseEnter:Connect(function()
		b.TextColor3 = UIKit.Colors.star
	end)
	b.MouseLeave:Connect(function()
		b.TextColor3 = props.TextColor3
	end)
	b.MouseButton1Click:Connect(onClick)
	return b
end

-- A small rounded coloured pill with white text: green "Trade", red "X".
function UIKit.button(props, onClick: () -> ())
	if props.Font == nil and props.FontFace == nil then
		props.FontFace = UIKit.FontFace
	end
	props.TextColor3 = props.TextColor3 or UIKit.Colors.text
	props.TextStrokeColor3 = UIKit.Colors.edge
	props.TextStrokeTransparency = 0
	props.BackgroundColor3 = props.BackgroundColor3 or UIKit.Colors.button
	if props.TextScaled == nil and props.TextSize == nil then
		props.TextScaled = true
	end
	props.AutoButtonColor = true
	local b = UIKit.shadowText(UIKit.new("TextButton", props, { UIKit.corner(6) }))
	b.MouseButton1Click:Connect(onClick)
	return b
end

-- The red close pill used under every window.
function UIKit.closeButton(props, onClick: () -> ())
	props.BackgroundColor3 = UIKit.Colors.bad
	props.Text = "X"
	props.Size = props.Size or UDim2.fromOffset(64, 26)
	return UIKit.button(props, onClick)
end

-- A small key box like [F] followed by what it does, for prompts.
function UIKit.keyCap(parent: Instance, key: string, action: string, order: number)
	local row = UIKit.new("Frame", { Parent = parent, LayoutOrder = order, Size = UDim2.fromOffset(0, 24), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1 }, {
		UIKit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 5) }),
	})
	local cap = UIKit.new("Frame", { Parent = row, LayoutOrder = 1, Size = UDim2.fromOffset(22, 22), BackgroundColor3 = UIKit.Colors.panel, BackgroundTransparency = UIKit.PANEL_ALPHA }, { UIKit.corner(4), UIKit.stroke(UIKit.Colors.rim, 1.5) })
	UIKit.label({ Parent = cap, Size = UDim2.fromScale(1, 1), Text = key, TextScaled = false, TextSize = 16 })
	UIKit.label({ Parent = row, LayoutOrder = 2, Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X, Text = action, TextScaled = false, TextSize = 18 })
	return row
end

-- A flat tan panel with a thin cream rim.
function UIKit.panel(props)
	props.BackgroundColor3 = props.BackgroundColor3 or UIKit.Colors.panel
	props.BackgroundTransparency = props.BackgroundTransparency or UIKit.PANEL_ALPHA
	return UIKit.new("Frame", props, { UIKit.corner(8), UIKit.stroke(UIKit.Colors.rim, 2) })
end

-- A darker block inside a panel (cards, icon squares). No rim.
function UIKit.block(props)
	props.BackgroundColor3 = props.BackgroundColor3 or UIKit.Colors.card
	props.BorderSizePixel = 0
	return UIKit.new("Frame", props, { UIKit.corner(6) })
end

-- A window title in big outlined text.
function UIKit.title(parent: Instance, text: string, y: number?)
	return UIKit.label({ Parent = parent, Position = UDim2.fromOffset(0, y or 6), Size = UDim2.new(1, 0, 0, 30), Text = text, TextScaled = false, TextSize = 30 })
end

-- Screen scaling: every HUD size is in pixels tuned for a ~1280x720 window, so
-- one UIScale on the ScreenGui shrinks it on small windows and phones and grows
-- it a little on big monitors.
local screenScale = 1
function UIKit.screenScale(): number
	return screenScale
end
function UIKit.fitScreen(gui: ScreenGui)
	local scale = Instance.new("UIScale")
	scale.Name = "ScreenFit"
	scale.Parent = gui
	local function fit()
		local cam = workspace.CurrentCamera
		if not cam then
			return
		end
		local v = cam.ViewportSize
		screenScale = math.clamp(math.min(v.X / 1280, v.Y / 720), 0.75, 1.3)
		scale.Scale = screenScale
	end
	fit()
	local function hook()
		if workspace.CurrentCamera then
			workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
		end
		fit()
	end
	hook()
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(hook)
end

-- Slides a bar's fill to `ratio` (0..1) instead of jumping. A paler "chip" bar behind
-- the fill shows what was just lost: it waits a moment, then drains down to meet the
-- fill. When the bar goes up, the fill grows smoothly into the new amount.
local TweenService = game:GetService("TweenService")
local chips: { [Frame]: Frame } = setmetatable({}, { __mode = "k" }) :: any
local lastRatio: { [Frame]: number } = setmetatable({}, { __mode = "k" }) :: any
function UIKit.slideBar(fill: Frame, ratio: number)
	ratio = math.clamp(ratio, 0, 1)
	local last = lastRatio[fill]
	if last and math.abs(last - ratio) < 0.0005 then
		return
	end
	lastRatio[fill] = ratio
	local chip = chips[fill]
	if not chip and fill.Parent then
		chip = fill:Clone()
		chip:ClearAllChildren()
		local round = fill:FindFirstChildOfClass("UICorner")
		if round then
			round:Clone().Parent = chip
		end
		chip.Name = "Chip"
		chip.BackgroundColor3 = Color3.fromRGB(255, 244, 214)
		chip.BackgroundTransparency = 0.25
		-- Lift the fill (and anything drawn over it) one step so the chip sits behind.
		local z = fill.ZIndex
		for _, sib in (fill.Parent :: Instance):GetChildren() do
			if sib:IsA("GuiObject") and sib ~= fill and sib.ZIndex >= z then
				sib.ZIndex += 1
			end
		end
		fill.ZIndex = z + 1
		chip.ZIndex = z
		chip.Parent = fill.Parent
		chips[fill] = chip
	end
	local target = UDim2.new(ratio, 0, fill.Size.Y.Scale, fill.Size.Y.Offset)
	if not last or ratio < last then
		-- Loss: the fill snaps down quickly, the chip lingers then drains.
		TweenService:Create(fill, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = target }):Play()
		if chip then
			TweenService:Create(chip, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 0, false, 0.35), { Size = target }):Play()
		end
	else
		-- Gain: the chip jumps ahead and the fill grows into it.
		if chip then
			chip.Size = target
		end
		TweenService:Create(fill, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = target }):Play()
	end
end

return UIKit
