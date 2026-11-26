-- The inventory screen (press C): crafting on the left, your bag on the right,
-- resource counts across the top, and what you're wearing.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Items)
local Recipes = require(Shared.Recipes)
local UIKit = require(script.Parent.UIKit)
local Icons = require(script.Parent.Icons)

local C = UIKit.Colors
local new, label, button, corner, stroke = UIKit.new, UIKit.label, UIKit.button, UIKit.corner, UIKit.stroke

local player = Players.LocalPlayer
local Screen = {}

local root: Frame
local craftGrid: ScrollingFrame
local bagGrid: ScrollingFrame
local strip: Frame
local wornRow: Frame
local craftTabButtons: { [string]: TextButton } = {}
local bagTabButtons: { [string]: TextButton } = {}
local craftTab = "All"
local bagTab = "All" -- always open on everything
local state = { items = {}, equipped = nil, armour = {} }
local callbacks: any = {}

local STRIP_ITEMS = { "log", "stick", "leaves", "stone", "sticky_slime", "leather" }
local BAG_TABS = { All = nil, Tools = "tool", Armour = "armour", Resources = "resource", Food = "food" }
local BAG_TAB_ORDER = { "All", "Tools", "Armour", "Resources", "Food" }
local CRAFT_TAB_ORDER = { "All", "Tools", "Armour", "Buildables" }

local function clear(f: Instance)
	for _, c in f:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

local TAB_TILT = { -3, 2, -1.5, 2.5, -2 }
local TAB_LABEL = { Buildables = "Build", Resources = "Stuff" }

-- Tabs are wooden tags hanging off the panel's top bar on short strings.
local function tabRow(parent: Instance, names: { string }, store: { [string]: TextButton }, onPick: (string) -> ())
	local row = new("Frame", { Parent = parent, Position = UDim2.fromOffset(22, -10), Size = UDim2.new(1, -44, 0, 34), BackgroundTransparency = 1, ZIndex = 5 }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for i, name in names do
		local text = TAB_LABEL[name] or name
		local holder = new("Frame", { Parent = row, LayoutOrder = i, Size = UDim2.fromOffset(#text * 11 + 24, 34), BackgroundTransparency = 1, ZIndex = 5 })
		new("Frame", { Parent = holder, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, 6), Size = UDim2.fromOffset(2, 12), BackgroundColor3 = Color3.fromRGB(140, 106, 62), BorderSizePixel = 0, ZIndex = 5 })
		local b = button({ Parent = holder, Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 4), Rotation = TAB_TILT[(i - 1) % #TAB_TILT + 1], Text = text, TextScaled = false, TextSize = 14, ZIndex = 6 }, function()
			onPick(name)
		end)
		b:FindFirstChildOfClass("UIGradient"):Destroy() -- wood grain instead of paint shading
		UIKit.grain(false, 0.6).Parent = b
		store[name] = b
	end
end

local function styleTabs(store: { [string]: TextButton }, active: string)
	for name, b in store do
		local on = name == active
		b.BackgroundColor3 = if on then C.panel else Color3.fromRGB(176, 136, 94)
		b.TextColor3 = if on then C.text else C.textLight
		b.Position = UDim2.fromOffset(0, if on then 9 else 4)
	end
end

local function grid(parent: Instance, cell: UDim2): ScrollingFrame
	return new("ScrollingFrame", {
		Parent = parent,
		Position = UDim2.fromOffset(18, 30),
		Size = UDim2.new(1, -34, 1, -46),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = C.edge,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	}, { new("UIGridLayout", { CellSize = cell, CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
end

-- Crafting cards ---------------------------------------------------------------------

local function rebuildCrafting()
	clear(craftGrid)
	styleTabs(craftTabButtons, craftTab)
	local level = player:GetAttribute("Level") or 1
	for i, recipe in Recipes do
		if craftTab == "All" or recipe.tab == craftTab then
			local locked = level < recipe.level
			local enough = true
			for id, amount in recipe.cost do
				if (state.items[id] or 0) < amount then
					enough = false
				end
			end
			if locked then
				-- A charred plank with the level it unlocks at burned in.
				local card = new("Frame", { Parent = craftGrid, LayoutOrder = i, BackgroundColor3 = C.cardLocked }, { corner(4), stroke(Color3.fromRGB(30, 20, 12), 2), UIKit.grain(false, 0.5) })
				local icon = Icons.make(recipe.id, card, UDim2.fromOffset(52, 52), UDim2.new(0.5, -26, 0, 4))
				icon.ImageColor3 = Color3.fromRGB(70, 60, 54)
				label({ Parent = card, Position = UDim2.fromOffset(4, 58), Size = UDim2.new(1, -8, 0, 15), Text = Items[recipe.id].name, TextColor3 = Color3.fromRGB(168, 149, 126) })
				label({ Parent = card, Position = UDim2.fromOffset(4, 78), Size = UDim2.new(1, -8, 0, 24), Text = "LV " .. recipe.level, TextColor3 = Color3.fromRGB(231, 137, 74), TextScaled = false, TextSize = 21 })
			else
				-- A light plank: picture, cost (green = you have enough), name, and a painted Craft button.
				local card = UIKit.wood({ Parent = craftGrid, LayoutOrder = i, BackgroundColor3 = Color3.fromRGB(222, 190, 140) })
				Icons.make(recipe.id, card, UDim2.fromOffset(54, 54), UDim2.fromOffset(2, 2))
				local costs = new("Frame", { Parent = card, Position = UDim2.fromOffset(58, 6), Size = UDim2.new(1, -62, 0, 50), BackgroundTransparency = 1 }, {
					new("UIGridLayout", { CellSize = UDim2.fromOffset(32, 22), CellPadding = UDim2.fromOffset(2, 2) }),
				})
				for id, amount in recipe.cost do
					local c = new("Frame", { Parent = costs, BackgroundTransparency = 1 })
					Icons.make(id, c, UDim2.fromOffset(18, 18), UDim2.fromOffset(0, 2))
					local have = state.items[id] or 0
					label({ Parent = c, Position = UDim2.fromOffset(18, 2), Size = UDim2.new(1, -18, 0, 18), Text = tostring(amount), TextColor3 = if have >= amount then Color3.fromRGB(46, 107, 42) else Color3.fromRGB(178, 58, 38), TextScaled = false, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left })
				end
				label({ Parent = card, Position = UDim2.fromOffset(4, 56), Size = UDim2.new(1, -8, 0, 16), Text = Items[recipe.id].name, TextScaled = false, TextSize = 14 })
				button({ Parent = card, Position = UDim2.fromOffset(12, 76), Size = UDim2.new(1, -24, 0, 28), Rotation = -2, BackgroundColor3 = if enough then C.good else C.button, Text = "CRAFT", TextScaled = false, TextSize = 16 }, function()
					callbacks.onCraft(recipe.id)
				end)
			end
		end
	end
end

-- Bag cards ----------------------------------------------------------------------------

local function rebuildBag()
	clear(bagGrid)
	styleTabs(bagTabButtons, bagTab)
	local want = BAG_TABS[bagTab]
	local ids = {}
	for id, count in state.items do
		if count > 0 and (want == nil or Items[id].kind == want or (want == "tool" and Items[id].kind == "placeable")) then
			table.insert(ids, id)
		end
	end
	table.sort(ids, function(a, b)
		return Items[a].order < Items[b].order
	end)
	for i, id in ids do
		local item = Items[id]
		local worn = item.kind == "armour" and state.armour[item.slot] == id
		local held = state.equipped == id
		-- A stitched sailcloth pocket; what you're holding or wearing gets a sea-glass seam.
		local card = new("Frame", { Parent = bagGrid, LayoutOrder = i, BackgroundColor3 = C.card }, {
			corner(6),
			stroke(if worn or held then C.good else Color3.fromRGB(160, 134, 96), 2),
			UIKit.shade(0.08),
			UIKit.stitch(if worn or held then C.glassLight else nil),
		})
		Icons.make(id, card, UDim2.fromOffset(52, 52), UDim2.new(0.5, -26, 0, 2))
		label({ Parent = card, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -7, 0, 5), Size = UDim2.fromOffset(34, 14), Text = tostring(state.items[id]), TextXAlignment = Enum.TextXAlignment.Right, TextScaled = false, TextSize = 13 })
		label({ Parent = card, Position = UDim2.fromOffset(4, 54), Size = UDim2.new(1, -8, 0, 15), Text = item.name })
		local actions = new("Frame", { Parent = card, Position = UDim2.fromOffset(4, 72), Size = UDim2.new(1, -8, 0, 24), BackgroundTransparency = 1 }, {
			new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 3), HorizontalAlignment = Enum.HorizontalAlignment.Center }),
		})
		local function act(text: string, fn: () -> (), paint: Color3?)
			button({ Parent = actions, Size = UDim2.fromOffset(42, 22), BackgroundColor3 = paint, Text = text, TextScaled = false, TextSize = 12 }, fn)
		end
		if item.kind == "armour" then
			act(if worn then "Remove" else "Wear", function()
				callbacks.onWear(id)
			end, C.good)
		elseif item.kind == "tool" or item.kind == "placeable" then
			act(if held then "Stow" else "Hold", function()
				callbacks.onHold(if held then nil else id)
			end, C.good)
		elseif item.kind == "food" then
			act("Eat", function()
				callbacks.onEat(id)
			end, C.good)
		end
		act("Drop", function()
			callbacks.onDrop(id)
		end)
	end
end

local function rebuildStrip()
	clear(strip)
	for i, id in STRIP_ITEMS do
		local cell = new("Frame", { Parent = strip, LayoutOrder = i, Size = UDim2.fromOffset(62, 54), BackgroundTransparency = 1 })
		Icons.make(id, cell, UDim2.fromOffset(40, 40), UDim2.new(0.5, -20, 0, 0))
		UIKit.hudText({ Parent = cell, Position = UDim2.fromOffset(0, 36), Size = UDim2.new(1, 0, 0, 16), Text = tostring(state.items[id] or 0), TextScaled = false, TextSize = 15, ZIndex = 2 })
	end
end

local SLOT_ORDER = { "head", "body", "legs", "feet", "bag" }
local SLOT_NAMES = { head = "Head", body = "Body", legs = "Legs", feet = "Feet", bag = "Bag" }

local function rebuildWorn()
	clear(wornRow)
	for i, slot in SLOT_ORDER do
		local cell = new("Frame", { Parent = wornRow, LayoutOrder = i, Size = UDim2.fromOffset(50, 66), BackgroundTransparency = 1 })
		local disc = UIKit.slice({ Parent = cell, Position = UDim2.fromOffset(2, 0), Size = UDim2.fromOffset(46, 46) })
		disc:FindFirstChildOfClass("UIStroke").Thickness = 4
		local id = state.armour[slot]
		if id then
			Icons.make(id, disc, UDim2.fromScale(0.9, 0.9), UDim2.fromScale(0.05, 0.05))
		end
		UIKit.hudText({ Parent = cell, Position = UDim2.fromOffset(0, 50), Size = UDim2.new(1, 0, 0, 14), Text = SLOT_NAMES[slot], TextScaled = false, TextSize = 11 })
	end
end

function Screen.refresh()
	if root and root.Visible then
		rebuildCrafting()
		rebuildBag()
		rebuildStrip()
		rebuildWorn()
	end
end

function Screen.set(items, equipped, armour)
	state.items, state.equipped, state.armour = items, equipped, armour
	Screen.refresh()
end

function Screen.isOpen(): boolean
	return root.Visible
end

function Screen.toggle()
	root.Visible = not root.Visible
	Screen.refresh()
end

function Screen.close()
	root.Visible = false
end

function Screen.init(parent: ScreenGui, cb)
	callbacks = cb
	root = new("Frame", { Parent = parent, Name = "Inventory", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(860, 520), BackgroundTransparency = 1, Visible = false })

	-- Resource strip (top): your materials standing on a nailed driftwood shelf.
	local shelf = new("Frame", { Parent = root, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(6 * 66 + 16, 62), BackgroundTransparency = 1 })
	UIKit.wood({ Parent = shelf, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 12) })
	UIKit.nail(shelf, UDim2.new(0, 12, 1, -6))
	UIKit.nail(shelf, UDim2.new(1, -12, 1, -6))
	strip = new("Frame", { Parent = shelf, Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -16, 1, -4), BackgroundTransparency = 1, ZIndex = 2 }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	-- Crafting (left)
	local craftPanel = UIKit.panel({ Parent = root, Position = UDim2.fromOffset(0, 84), Size = UDim2.new(0.5, -8, 0, 356) })
	tabRow(craftPanel, CRAFT_TAB_ORDER, craftTabButtons, function(name)
		craftTab = name
		rebuildCrafting()
	end)
	craftGrid = grid(craftPanel, UDim2.fromOffset(122, 112))

	-- Bag (right)
	local bagPanel = UIKit.panel({ Parent = root, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 84), Size = UDim2.new(0.5, -8, 0, 356) })
	tabRow(bagPanel, BAG_TAB_ORDER, bagTabButtons, function(name)
		bagTab = name
		rebuildBag()
	end)
	bagGrid = grid(bagPanel, UDim2.fromOffset(90, 100))

	-- Worn armour (bottom right, as log slices) and a coral pebble to close.
	wornRow = new("Frame", { Parent = root, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 0, 1, 0), Size = UDim2.fromOffset(5 * 56, 66), BackgroundTransparency = 1 }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Right }),
	})
	local close = button({ Parent = root, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16), Size = UDim2.fromOffset(52, 44), BackgroundColor3 = C.bad, Text = "X", TextScaled = false, TextSize = 24 }, function()
		Screen.close()
	end)
	close:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0.45, 0)

	player:GetAttributeChangedSignal("Level"):Connect(Screen.refresh)
end

return Screen
