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
	health = Color3.fromRGB(200, 98, 112), -- muted red-pink
	hunger = Color3.fromRGB(212, 146, 154), -- dusty pink
	bag = Color3.fromRGB(122, 170, 204), -- muted light blue
	barBack = Color3.fromRGB(80, 70, 56), -- dark brown behind stat bars
	xp = Color3.fromRGB(122, 214, 92), -- green, like the XP orbs
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

-- White text with a dark outline. This is the only text style in the game.
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
	return UIKit.new("TextLabel", props)
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
	local b = UIKit.new("TextButton", props)
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
	local b = UIKit.new("TextButton", props, { UIKit.corner(6) })
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

return UIKit
