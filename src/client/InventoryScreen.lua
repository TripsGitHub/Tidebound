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
local bagTab = "All"
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

local function tabRow(parent: Instance, names: { string }, store: { [string]: TextButton }, onPick: (string) -> ())
	local row = new("Frame", { Parent = parent, Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 0, 30), BackgroundTransparency = 1 }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4) }),
	})
	for _, name in names do
		store[name] = button({ Parent = row, Size = UDim2.fromOffset(if #name > 6 then 92 else 62, 28), Text = name, TextScaled = false, TextSize = 15 }, function()
			onPick(name)
		end)
	end
end

local function styleTabs(store: { [string]: TextButton }, active: string)
	for name, b in store do
		b.BackgroundColor3 = if name == active then C.edge else C.panelDark
		b.TextColor3 = if name == active then C.textLight else C.text
	end
end

local function grid(parent: Instance, cell: UDim2): ScrollingFrame
	return new("ScrollingFrame", {
		Parent = parent,
		Position = UDim2.fromOffset(8, 44),
		Size = UDim2.new(1, -16, 1, -52),
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
			local card = new("Frame", { Parent = craftGrid, LayoutOrder = i, BackgroundColor3 = if locked then C.cardLocked else C.card }, { corner(8) })
			Icons.make(recipe.id, card, UDim2.fromOffset(52, 52), UDim2.fromOffset(4, 4))
			-- Cost: small icons with have/need counts.
			local costs = new("Frame", { Parent = card, Position = UDim2.fromOffset(58, 4), Size = UDim2.new(1, -62, 0, 52), BackgroundTransparency = 1 }, {
				new("UIGridLayout", { CellSize = UDim2.fromOffset(28, 25), CellPadding = UDim2.fromOffset(2, 2) }),
			})
			for id, amount in recipe.cost do
				local c = new("Frame", { Parent = costs, BackgroundTransparency = 1 })
				Icons.make(id, c, UDim2.fromOffset(18, 18), UDim2.fromOffset(5, 0))
				local have = state.items[id] or 0
				label({ Parent = c, Position = UDim2.fromOffset(0, 15), Size = UDim2.new(1, 0, 0, 11), Text = tostring(amount), TextColor3 = if have >= amount then C.good else C.bad, Font = UIKit.FontHeavy })
			end
			label({ Parent = card, Position = UDim2.fromOffset(4, 58), Size = UDim2.new(1, -8, 0, 16), Text = Items[recipe.id].name, TextColor3 = if locked then C.textLight else C.text })
			if locked then
				label({ Parent = card, Position = UDim2.fromOffset(4, 78), Size = UDim2.new(1, -8, 0, 28), Text = "Level " .. recipe.level, TextColor3 = C.textLight, Font = UIKit.FontHeavy })
			else
				button({ Parent = card, Position = UDim2.fromOffset(6, 78), Size = UDim2.new(1, -12, 0, 28), BackgroundColor3 = if enough then C.good else C.button, Text = "Craft", Font = UIKit.FontHeavy }, function()
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
		local card = new("Frame", { Parent = bagGrid, LayoutOrder = i, BackgroundColor3 = C.card }, { corner(8), stroke(if worn or held then C.xp else C.edge, if worn or held then 2.5 else 1) })
		Icons.make(id, card, UDim2.fromOffset(52, 52), UDim2.new(0.5, -26, 0, 2))
		label({ Parent = card, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 2), Size = UDim2.fromOffset(34, 14), Text = "x" .. state.items[id], TextXAlignment = Enum.TextXAlignment.Right })
		label({ Parent = card, Position = UDim2.fromOffset(2, 54), Size = UDim2.new(1, -4, 0, 15), Text = item.name })
		local actions = new("Frame", { Parent = card, Position = UDim2.fromOffset(4, 72), Size = UDim2.new(1, -8, 0, 24), BackgroundTransparency = 1 }, {
			new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 3), HorizontalAlignment = Enum.HorizontalAlignment.Center }),
		})
		local function act(text: string, fn: () -> ())
			button({ Parent = actions, Size = UDim2.fromOffset(42, 24), Text = text, TextScaled = false, TextSize = 12 }, fn)
		end
		if item.kind == "armour" then
			act(if worn then "Remove" else "Wear", function()
				callbacks.onWear(id)
			end)
		elseif item.kind == "tool" or item.kind == "placeable" then
			act(if held then "Put away" else "Hold", function()
				callbacks.onHold(if held then nil else id)
			end)
		elseif item.kind == "food" then
			act("Eat", function()
				callbacks.onEat(id)
			end)
		end
		act("Drop", function()
			callbacks.onDrop(id)
		end)
	end
end

local function rebuildStrip()
	clear(strip)
	for i, id in STRIP_ITEMS do
		local cell = new("Frame", { Parent = strip, LayoutOrder = i, Size = UDim2.fromOffset(62, 50), BackgroundTransparency = 1 })
		label({ Parent = cell, Size = UDim2.new(1, 0, 0, 12), Text = Items[id].name, TextColor3 = C.text })
		Icons.make(id, cell, UDim2.fromOffset(26, 26), UDim2.new(0.5, -13, 0, 12))
		label({ Parent = cell, Position = UDim2.fromOffset(0, 38), Size = UDim2.new(1, 0, 0, 12), Text = "x" .. (state.items[id] or 0), Font = UIKit.FontHeavy })
	end
end

local SLOT_ORDER = { "head", "body", "legs", "feet", "bag" }
local SLOT_NAMES = { head = "Head", body = "Body", legs = "Legs", feet = "Feet", bag = "Bag" }

local function rebuildWorn()
	clear(wornRow)
	for i, slot in SLOT_ORDER do
		local cell = new("Frame", { Parent = wornRow, LayoutOrder = i, Size = UDim2.fromOffset(50, 50), BackgroundColor3 = C.panelDark }, { corner(8), stroke(C.edge, 1.5) })
		local id = state.armour[slot]
		if id then
			Icons.make(id, cell, UDim2.fromScale(0.9, 0.9), UDim2.fromScale(0.05, 0.05))
		else
			label({ Parent = cell, Size = UDim2.fromScale(1, 1), Text = SLOT_NAMES[slot], TextColor3 = C.cardLocked, TextScaled = false, TextSize = 12 })
		end
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
	root = new("Frame", { Parent = parent, Name = "Inventory", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.48), Size = UDim2.fromOffset(860, 470), BackgroundTransparency = 1, Visible = false })

	-- Resource strip (top)
	local stripPanel = UIKit.panel({ Parent = root, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(6 * 66 + 16, 58) })
	strip = new("Frame", { Parent = stripPanel, Position = UDim2.fromOffset(8, 4), Size = UDim2.new(1, -16, 1, -8), BackgroundTransparency = 1 }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	-- Crafting (left)
	local craftPanel = UIKit.panel({ Parent = root, Position = UDim2.fromOffset(0, 68), Size = UDim2.new(0.5, -8, 1, -110) })
	tabRow(craftPanel, CRAFT_TAB_ORDER, craftTabButtons, function(name)
		craftTab = name
		rebuildCrafting()
	end)
	craftGrid = grid(craftPanel, UDim2.fromOffset(128, 112))

	-- Bag (right)
	local bagPanel = UIKit.panel({ Parent = root, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 68), Size = UDim2.new(0.5, -8, 1, -110) })
	tabRow(bagPanel, BAG_TAB_ORDER, bagTabButtons, function(name)
		bagTab = name
		rebuildBag()
	end)
	bagGrid = grid(bagPanel, UDim2.fromOffset(98, 100))

	-- Worn armour + close (bottom)
	wornRow = new("Frame", { Parent = root, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 0, 1, 0), Size = UDim2.fromOffset(5 * 54, 50), BackgroundTransparency = 1 }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Right }),
	})
	button({ Parent = root, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.fromOffset(70, 30), BackgroundColor3 = C.bad, Text = "X", Font = UIKit.FontHeavy }, function()
		Screen.close()
	end)

	player:GetAttributeChangedSignal("Level"):Connect(Screen.refresh)
end

return Screen
