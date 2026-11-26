-- Tidebound's castaway look: everything is something you could find or make on a
-- beach. Driftwood planks with nails, rope lashings, sailcloth panels, log-slice
-- slots, pebble key caps and sea-glass highlights. Built only from Frames, strokes,
-- corners and gradients, so there are no image uploads to manage.
local UIKit = {}

UIKit.Colors = {
	-- sailcloth
	panel = Color3.fromRGB(239, 226, 196),
	panelDark = Color3.fromRGB(205, 182, 138),
	card = Color3.fromRGB(226, 208, 168),
	cardLocked = Color3.fromRGB(58, 42, 30),
	-- wood and rope
	edge = Color3.fromRGB(90, 63, 40),
	bark = Color3.fromRGB(74, 50, 32),
	wood = Color3.fromRGB(162, 124, 85),
	woodLight = Color3.fromRGB(215, 181, 133),
	rope = Color3.fromRGB(216, 181, 122),
	ropeDark = Color3.fromRGB(169, 134, 78),
	-- text
	text = Color3.fromRGB(62, 42, 24),
	textLight = Color3.fromRGB(255, 248, 234),
	-- paint
	button = Color3.fromRGB(122, 86, 52),
	good = Color3.fromRGB(46, 154, 144), -- sea glass
	glassLight = Color3.fromRGB(143, 224, 210),
	bad = Color3.fromRGB(217, 86, 63), -- coral
	warn = Color3.fromRGB(239, 161, 58),
	health = Color3.fromRGB(226, 96, 74),
	hunger = Color3.fromRGB(239, 161, 58),
	bag = Color3.fromRGB(91, 167, 201),
	xp = Color3.fromRGB(63, 179, 168),
	stone = Color3.fromRGB(150, 144, 136),
}
local C = UIKit.Colors

-- One chunky hand-painted font for everything.
UIKit.Font = Enum.Font.LuckiestGuy
UIKit.FontHeavy = Enum.Font.LuckiestGuy

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
local new = UIKit.new

function UIKit.corner(r: number?)
	return new("UICorner", { CornerRadius = UDim.new(0, r or 8) })
end

function UIKit.round()
	return new("UICorner", { CornerRadius = UDim.new(1, 0) })
end

function UIKit.stroke(color: Color3?, thickness: number?)
	return new("UIStroke", { Color = color or C.edge, Thickness = thickness or 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

-- Light/dark bands across a frame, like wood grain. Multiplies the frame's colour.
local GRAIN = { 1, 0.9, 0.98, 0.82, 0.92, 0.78, 0.86 }
function UIKit.grain(vertical: boolean?, strength: number?)
	local s = strength or 1
	local keys = {}
	for i, v in GRAIN do
		local k = 1 - (1 - v) * s
		table.insert(keys, ColorSequenceKeypoint.new((i - 1) / (#GRAIN - 1), Color3.new(k, k, k)))
	end
	return new("UIGradient", { Color = ColorSequence.new(keys), Rotation = if vertical then 0 else 90 })
end

-- Soft top-to-bottom shading (lighter on top), for cloth, paint and stone.
function UIKit.shade(amount: number?)
	local a = 1 - (amount or 0.12)
	return new("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(a, a, a)), Rotation = 90 })
end

-- A driftwood plank.
function UIKit.wood(props, vertical: boolean?)
	props.BackgroundColor3 = props.BackgroundColor3 or Color3.fromRGB(190, 148, 102)
	props.BorderSizePixel = 0
	return new("Frame", props, { UIKit.corner(4), UIKit.stroke(C.edge, 2), UIKit.grain(vertical) })
end

-- A nail head.
function UIKit.nail(parent: Instance, position: UDim2)
	return new("Frame", { Parent = parent, AnchorPoint = Vector2.new(0.5, 0.5), Position = position, Size = UDim2.fromOffset(8, 8), BackgroundColor3 = Color3.fromRGB(120, 112, 106), ZIndex = 4 }, {
		UIKit.round(),
		UIKit.stroke(Color3.fromRGB(46, 38, 32), 1.5),
		new("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(0.55, 0.55, 0.55)), Rotation = 45 }),
	})
end

-- A rope lashing: diagonal twisted stripes.
function UIKit.rope(parent: Instance, position: UDim2, size: UDim2, rotation: number?)
	local keys = {}
	local n = 8
	for i = 0, n - 1 do
		local c = if i % 2 == 0 then C.rope else C.ropeDark
		table.insert(keys, ColorSequenceKeypoint.new(i / n, c))
		table.insert(keys, ColorSequenceKeypoint.new(math.min(1, (i + 1) / n - 0.001), c))
	end
	return new("Frame", { Parent = parent, AnchorPoint = Vector2.new(0.5, 0.5), Position = position, Size = size, Rotation = rotation or 45, BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 3 }, {
		UIKit.corner(3),
		UIKit.stroke(Color3.fromRGB(110, 82, 48), 1.5),
		new("UIGradient", { Color = ColorSequence.new(keys), Rotation = 45 }),
	})
end

-- A log slice: dark bark ring, pale wood, two growth rings. Returns the slice.
function UIKit.slice(props)
	props.BackgroundColor3 = props.BackgroundColor3 or Color3.fromRGB(222, 192, 146)
	local s = new("Frame", props, { UIKit.round(), UIKit.stroke(C.bark, 5), UIKit.shade(0.1) })
	for _, inset in { 0.12, 0.26 } do
		new("Frame", { Parent = s, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1 - inset * 2, 1 - inset * 2), BackgroundTransparency = 1 }, {
			UIKit.round(),
			UIKit.stroke(Color3.fromRGB(184, 143, 92), 1.5),
		})
	end
	return s
end

function UIKit.label(props)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Font = props.Font or UIKit.Font
	props.TextColor3 = props.TextColor3 or C.text
	if props.TextScaled == nil and props.TextSize == nil then
		props.TextScaled = true
	end
	return new("TextLabel", props)
end

-- Cream text with a thick bark outline, for anything drawn straight over the world.
function UIKit.hudText(props)
	props.TextColor3 = props.TextColor3 or C.textLight
	props.Font = props.Font or UIKit.FontHeavy
	local l = UIKit.label(props)
	new("UIStroke", { Parent = l, Color = C.bark, Thickness = props.TextSize and props.TextSize >= 22 and 2.5 or 1.8, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual })
	return l
end

-- A pebble key cap, like [F].
function UIKit.pebble(parent: Instance, key: string, size: number?)
	local s = size or 26
	local p = new("Frame", { Parent = parent, Size = UDim2.fromOffset(s + 2, s), BackgroundColor3 = Color3.fromRGB(176, 170, 162) }, {
		new("UICorner", { CornerRadius = UDim.new(0.45, 0) }),
		UIKit.stroke(Color3.fromRGB(58, 53, 48), 2),
		UIKit.shade(0.3),
	})
	UIKit.hudText({ Parent = p, Size = UDim2.fromScale(1, 1), Text = key, TextScaled = false, TextSize = math.floor(s * 0.6) })
	return p
end

-- A pebble with its action next to it: (F) Pick up
function UIKit.keyCap(parent: Instance, key: string, action: string, order: number)
	local row = new("Frame", { Parent = parent, LayoutOrder = order, Size = UDim2.fromOffset(0, 28), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1 }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	UIKit.pebble(row, key).LayoutOrder = 1
	UIKit.hudText({ Parent = row, LayoutOrder = 2, Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X, Text = action, TextScaled = false, TextSize = 18 })
	return row
end

-- A painted plank button. Colour = the paint.
function UIKit.button(props, onClick: () -> ())
	props.Font = props.Font or UIKit.Font
	props.TextColor3 = props.TextColor3 or C.textLight
	props.BackgroundColor3 = props.BackgroundColor3 or C.button
	if props.TextScaled == nil and props.TextSize == nil then
		props.TextScaled = true
	end
	props.AutoButtonColor = true
	local b = new("TextButton", props, { UIKit.corner(5), UIKit.stroke(C.bark, 2), UIKit.shade(0.22) })
	new("UIPadding", { Parent = b, PaddingTop = UDim.new(0, 3), PaddingBottom = UDim.new(0, 2), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) })
	b.MouseButton1Click:Connect(onClick)
	return b
end

-- A stitched seam just inside a cloth card's edge.
function UIKit.stitch(color: Color3?)
	return new("Frame", { Position = UDim2.fromOffset(3, 3), Size = UDim2.new(1, -6, 1, -6), BackgroundTransparency = 1 }, {
		UIKit.corner(4),
		UIKit.stroke(color or Color3.fromRGB(246, 236, 212), 1.5),
	})
end

-- A sailcloth panel in a lashed driftwood frame. Put content inside, at least 16px
-- in from each edge (the frame bars are 14px).
function UIKit.panel(props)
	props.BackgroundTransparency = 1
	local f = new("Frame", props)
	new("Frame", { Parent = f, Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -12, 1, -12), BackgroundColor3 = C.panel, BorderSizePixel = 0, ZIndex = 0 }, { UIKit.shade(0.08) })
	local bars = {
		{ UDim2.new(0.5, 0, 0, 7), UDim2.new(1, 8, 0, 14), -0.5, false },
		{ UDim2.new(0.5, 2, 1, -7), UDim2.new(1, 8, 0, 14), 0.4, false },
		{ UDim2.new(0, 7, 0.5, 0), UDim2.new(0, 14, 1, 8), 0.4, true },
		{ UDim2.new(1, -7, 0.5, 2), UDim2.new(0, 14, 1, 8), -0.3, true },
	}
	for _, b in bars do
		UIKit.wood({ Parent = f, AnchorPoint = Vector2.new(0.5, 0.5), Position = b[1], Size = b[2], Rotation = b[3], ZIndex = 2 }, b[4])
	end
	for _, p in { UDim2.fromOffset(7, 7), UDim2.new(1, -7, 0, 7), UDim2.new(0, 7, 1, -7), UDim2.new(1, -7, 1, -7) } do
		UIKit.rope(f, p, UDim2.fromOffset(20, 20))
	end
	return f
end

-- A wooden sign with a title, sitting on the top bar of a panel.
function UIKit.sign(parent: Instance, text: string, width: number)
	local s = UIKit.wood({ Parent = parent, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 4), Size = UDim2.fromOffset(width, 36), Rotation = -1.5, ZIndex = 5 })
	UIKit.nail(s, UDim2.fromOffset(10, 18))
	UIKit.nail(s, UDim2.new(1, -10, 0, 18))
	UIKit.hudText({ Parent = s, Size = UDim2.new(1, -30, 1, -4), Position = UDim2.fromOffset(15, 3), Text = text, ZIndex = 6, TextScaled = false, TextSize = 22 })
	return s
end

return UIKit
