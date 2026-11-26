-- Shared look for all UI: sun-bleached parchment panels with dark driftwood edges.
local UIKit = {}

UIKit.Colors = {
	panel = Color3.fromRGB(232, 214, 174),
	panelDark = Color3.fromRGB(205, 182, 136),
	card = Color3.fromRGB(214, 192, 148),
	cardLocked = Color3.fromRGB(120, 104, 84),
	edge = Color3.fromRGB(88, 62, 38),
	text = Color3.fromRGB(70, 48, 30),
	textLight = Color3.fromRGB(252, 244, 226),
	button = Color3.fromRGB(122, 86, 52),
	good = Color3.fromRGB(92, 150, 62),
	bad = Color3.fromRGB(206, 84, 62),
	warn = Color3.fromRGB(232, 128, 52),
	health = Color3.fromRGB(214, 86, 86),
	hunger = Color3.fromRGB(222, 150, 70),
	bag = Color3.fromRGB(110, 168, 196),
	xp = Color3.fromRGB(236, 196, 84),
}

-- One chunky, rounded font everywhere (like hand-painted signs), instead of a
-- generic UI font.
UIKit.Font = Enum.Font.FredokaOne
UIKit.FontHeavy = Enum.Font.FredokaOne

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

function UIKit.stroke(color: Color3?, thickness: number?)
	return UIKit.new("UIStroke", { Color = color or UIKit.Colors.edge, Thickness = thickness or 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

function UIKit.label(props)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Font = props.Font or UIKit.Font
	props.TextColor3 = props.TextColor3 or UIKit.Colors.text
	if props.TextScaled == nil and props.TextSize == nil then
		props.TextScaled = true
	end
	return UIKit.new("TextLabel", props)
end

-- White text with a dark outline, for text drawn straight over the world.
function UIKit.hudText(props)
	props.TextColor3 = props.TextColor3 or UIKit.Colors.textLight
	props.TextStrokeColor3 = props.TextStrokeColor3 or Color3.fromRGB(40, 26, 14)
	props.TextStrokeTransparency = props.TextStrokeTransparency or 0
	props.Font = props.Font or UIKit.FontHeavy
	return UIKit.label(props)
end

-- A small key cap like [F], for prompts.
function UIKit.keyCap(parent: Instance, key: string, action: string, order: number)
	local row = UIKit.new("Frame", { Parent = parent, LayoutOrder = order, Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = UIKit.Colors.panel }, {
		UIKit.corner(8),
		UIKit.stroke(UIKit.Colors.edge, 2),
		UIKit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6) }),
		UIKit.new("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 10) }),
	})
	local cap = UIKit.new("Frame", { Parent = row, LayoutOrder = 1, Size = UDim2.fromOffset(22, 22), BackgroundColor3 = UIKit.Colors.edge }, { UIKit.corner(5) })
	UIKit.label({ Parent = cap, Size = UDim2.fromScale(1, 1), Text = key, TextColor3 = UIKit.Colors.textLight, Font = UIKit.FontHeavy })
	UIKit.label({ Parent = row, LayoutOrder = 2, Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X, Text = action, TextScaled = false, TextSize = 18, Font = UIKit.FontHeavy })
	return row
end

function UIKit.button(props, onClick: () -> ())
	props.Font = props.Font or UIKit.Font
	props.TextColor3 = props.TextColor3 or UIKit.Colors.textLight
	props.BackgroundColor3 = props.BackgroundColor3 or UIKit.Colors.button
	if props.TextScaled == nil and props.TextSize == nil then
		props.TextScaled = true
	end
	props.AutoButtonColor = true
	local b = UIKit.new("TextButton", props, { UIKit.corner(6), UIKit.stroke(UIKit.Colors.edge, 1.5) })
	b.MouseButton1Click:Connect(onClick)
	return b
end

function UIKit.panel(props)
	props.BackgroundColor3 = props.BackgroundColor3 or UIKit.Colors.panel
	return UIKit.new("Frame", props, { UIKit.corner(10), UIKit.stroke(UIKit.Colors.edge, 3) })
end

return UIKit
