-- The inventory screen (press C). Laid out the way survival-tribe games do it, so the
-- world stays visible while you craft:
--   * Craft panel docked on the left, Bag panel docked on the right, both tall.
--   * Resource strip at the top centre (name / icon / count), with an inspect box
--     under it that describes whatever card you point at.
--   * A red X in the gap above the hotbar.
-- Tabs are the word "All" followed by category icons. Cards are flat darker-tan
-- blocks; actions are plain outlined words, not boxed buttons.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Items)
local Recipes = require(Shared.Recipes)
local UIKit = require(script.Parent.UIKit)
local Icons = require(script.Parent.Icons)

local C = UIKit.Colors
local new, label, block, textButton = UIKit.new, UIKit.label, UIKit.block, UIKit.textButton

local player = Players.LocalPlayer
local Screen = {}

local root: Frame
local craftGrid: ScrollingFrame
local bagGrid: ScrollingFrame
local strip: Frame
local inspectBox: Frame
local inspectName: TextLabel
local inspectLine: TextLabel
local craftTabs: { [string]: Frame } = {}
local bagTabs: { [string]: Frame } = {}
local craftTab = "All"
local bagTab = "All"
local Favourites = require(script.Parent.Favourites)
local state = { items = {}, equipped = nil, armour = {} }
local callbacks: any = {}

local PANEL_W = 488 -- three cards across, like a proper survival-game bag
local CARD = UDim2.fromOffset(150, 114)
local BAG_CARD = UDim2.fromOffset(150, 150)
local TOP = 100 -- below the XP bar, compass and target bar
local BOTTOM = 112 -- above the hotbar

local STRIP_ITEMS = { "log", "stick", "leaves", "stone", "sticky_slime", "leather" }

-- Tabs: "All" as a word, then one icon per category (the item shown is just a
-- picture of the category).
local CRAFT_TABS = {
	{ name = "All" },
	{ name = "Tools", icon = "wood_harvester" },
	{ name = "Armour", icon = "wood_helmet" },
	{ name = "Buildables", icon = "wood_wall" },
}
local BAG_TABS = {
	{ name = "All" },
	{ name = "Tools", icon = "wood_harvester", kinds = { tool = true, placeable = true } },
	{ name = "Armour", icon = "wood_helmet", kinds = { armour = true } },
	{ name = "Resources", icon = "log", kinds = { resource = true } },
	{ name = "Food", icon = "berries", kinds = { food = true, seed = true } },
}

local function clear(f: Instance)
	for _, c in f:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

-- One line that says what an item is for, for the inspect box.
local function describe(id: string): string
	local item = Items[id]
	if item.ranged then
		return "Shoots for " .. (item.damage or 0) .. ", range " .. (item.range or 0) .. " (uses Arrows)"
	elseif item.kind == "tool" then
		return "Hits for " .. (item.damage or 0)
	elseif item.kind == "armour" then
		if item.bagSize then
			return "Carry +" .. item.bagSize
		end
		local d = item.defense or 0
		return "Blocks " .. math.floor(d * (item.vsMob or 1) * 100 + 0.5) .. "% from mobs, " .. math.floor(d * (item.vsPlayer or 1) * 100 + 0.5) .. "% from players"
	elseif item.kind == "food" then
		return "Fills " .. (item.hunger or 0) .. " hunger"
	elseif item.kind == "placeable" then
		return "Build it on your land"
	elseif item.kind == "crate" then
		return "Open it for random loot"
	elseif item.kind == "raft" then
		local spec = Items.RAFTS[id]
		return "Sail at speed " .. (spec and spec.speed or 0) .. " (use at the shore)"
	end
	return "Used for crafting"
end

local function inspect(id: string?)
	inspectBox.Visible = id ~= nil
	if id then
		inspectName.Text = Items[id].name
		inspectLine.Text = describe(id)
	end
end

local function hoverable(card: GuiObject, id: string)
	card.MouseEnter:Connect(function()
		inspect(id)
	end)
	card.MouseLeave:Connect(function()
		inspect(nil)
	end)
end

local function tabRow(parent: Instance, tabs, store: { [string]: Frame }, onPick: (string) -> ())
	local row = new("Frame", { Parent = parent, Position = UDim2.fromOffset(8, 6), Size = UDim2.new(1, -16, 0, 48), BackgroundTransparency = 1 }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for i, tab in tabs do
		local holder = block({ Parent = row, LayoutOrder = i, Size = UDim2.fromOffset(if tab.icon then 48 else 64, 48), BackgroundTransparency = 1 })
		if tab.icon then
			Icons.make(tab.icon, holder, UDim2.fromOffset(42, 42), UDim2.fromOffset(3, 3))
		end
		textButton({ Parent = holder, Size = UDim2.fromScale(1, 1), Text = if tab.icon then "" else tab.name, TextScaled = false, TextSize = 32, ZIndex = 2 }, function()
			onPick(tab.name)
		end)
		store[tab.name] = holder
	end
end

local function styleTabs(store: { [string]: Frame }, active: string)
	for name, holder in store do
		holder.BackgroundColor3 = C.cardDark
		holder.BackgroundTransparency = if name == active then 0 else 1
	end
end

local function grid(parent: Instance, cell: UDim2?): ScrollingFrame
	return new("ScrollingFrame", {
		Parent = parent,
		Position = UDim2.fromOffset(8, 60),
		Size = UDim2.new(1, -12, 1, -66),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = C.rim,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	}, { new("UIGridLayout", { CellSize = cell or CARD, CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
end

local rebuildBag: () -> ()

-- Craft cards ---------------------------------------------------------------------
-- [ item name                ]
-- [ icon ] [ ingredients box ]   ingredient: name above, icon, count below (red/green)
-- [         Craft            ]   or "Level N" when locked

-- Cards are built once and then only updated (counts, colours, labels), because
-- building them, with their 3D icons, every time the bag changed made the game hitch.
local craftCards: { [string]: { card: Frame, costs: { [string]: TextLabel }, foot: Frame, locked: boolean? } } = {}

local function craftCard(i: number, recipe)
	local card = block({ Parent = craftGrid, LayoutOrder = i, BackgroundColor3 = C.card })
	hoverable(card, recipe.id)
	local title = label({ Parent = card, Position = UDim2.fromOffset(4, 2), Size = UDim2.new(1, -26, 0, 16), Text = Items[recipe.id].name, TextScaled = true })
	new("UITextSizeConstraint", { Parent = title, MaxTextSize = 15 })

	local iconBox = block({ Parent = card, Position = UDim2.fromOffset(5, 20), Size = UDim2.fromOffset(50, 50), BackgroundColor3 = C.cardDark })
	local iconVf = Icons.make(recipe.id, iconBox, UDim2.fromScale(0.9, 0.9), UDim2.fromScale(0.05, 0.05))

	-- Ingredients share the box evenly however many there are (no names here, so they
	-- never overlap: the (i) panel shows them big with names).
	local costs = block({ Parent = card, Position = UDim2.fromOffset(59, 20), Size = UDim2.new(1, -64, 0, 50), BackgroundColor3 = C.cardDark }, nil)
	new("UIListLayout", { Parent = costs, FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder })
	local counts = {}
	local n = 0
	for _ in recipe.cost do
		n += 1
	end
	local cellW = math.min(30, math.floor((CARD.X.Offset - 64 - 4 - (n - 1) * 2) / math.max(n, 1)))
	for id, amount in recipe.cost do
		local cell = new("Frame", { Parent = costs, Size = UDim2.fromOffset(cellW, 48), BackgroundTransparency = 1 })
		Icons.make(id, cell, UDim2.fromOffset(cellW - 2, cellW - 2), UDim2.fromOffset(1, 4))
		counts[id] = label({ Parent = cell, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 14), Text = tostring(amount), TextScaled = false, TextSize = if cellW < 24 then 12 else 15 })
	end
	-- (i): opens the big detail panel for this recipe.
	local info = textButton({ Parent = card, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -3, 0, 2), Size = UDim2.fromOffset(18, 18), Text = "i", TextScaled = false, TextSize = 15, ZIndex = 4 }, function()
		Screen.details(recipe)
	end)
	info.BackgroundColor3 = C.cardDark
	info.BackgroundTransparency = 0
	new("UICorner", { Parent = info, CornerRadius = UDim.new(1, 0) })

	local foot = block({ Parent = card, Position = UDim2.fromOffset(5, 76), Size = UDim2.new(1, -10, 0, 29), BackgroundColor3 = C.cardDark })
	-- Locked recipes: the name stays, but the look and the cost are blacked out.
	local hidden = new("Frame", { Parent = card, Position = costs.Position, Size = costs.Size, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.05, BorderSizePixel = 0, ZIndex = 5, Visible = false }, {
		new("UICorner", { CornerRadius = UDim.new(0, 8) }),
	})
	label({ Parent = hidden, Size = UDim2.fromScale(1, 1), Text = "???", TextScaled = false, TextSize = 22, ZIndex = 6, TextColor3 = Color3.fromRGB(120, 120, 120) })
	local entry = { card = card, costs = counts, foot = foot, locked = nil, icon = iconVf, hidden = hidden }
	craftCards[recipe.id] = entry
	return entry
end

local function rebuildCrafting()
	styleTabs(craftTabs, craftTab)
	local level = player:GetAttribute("Level") or 1
	for i, recipe in Recipes do
		-- Every recipe shows, locked ones greyed with the level they unlock at, so you
		-- can see what you're working towards.
		-- Merchant-only gear (Tidecaller, boss gear) is made at the wandering merchant.
		local show = (craftTab == "All" or recipe.tab == craftTab) and not recipe.trader
		local entry = craftCards[recipe.id]
		if show and not entry then
			entry = craftCard(i, recipe)
		end
		if entry then
			entry.card.Visible = show
			if show then
				local locked = level < recipe.level
				entry.card.LayoutOrder = (if locked then 1000 else 0) + i
				entry.card.BackgroundColor3 = if locked then C.cardLocked else C.card
				for id, amount in recipe.cost do
					entry.costs[id].TextColor3 = if (state.items[id] or 0) >= amount then C.good else C.bad
				end
				if entry.locked ~= locked then
					entry.locked = locked
					entry.hidden.Visible = locked
					if entry.icon and entry.icon:IsA("ViewportFrame") then
						entry.icon.ImageColor3 = if locked then Color3.new(0, 0, 0) else Color3.new(1, 1, 1)
					end
					clear(entry.foot)
					if locked then
						label({ Parent = entry.foot, Size = UDim2.fromScale(1, 1), Text = "Level " .. recipe.level, TextScaled = false, TextSize = 22 })
					else
						textButton({ Parent = entry.foot, Size = UDim2.fromScale(1, 1), Text = "Craft", TextScaled = false, TextSize = 24 }, function()
							callbacks.onCraft(recipe.id)
						end)
					end
				end
			end
		end
	end
end

-- Bag cards -----------------------------------------------------------------------
-- [ star            ]
-- [      icon       ]
-- [ Name (xN)       ]
-- [ Equip     Drop  ]

local bagCards: { [string]: { card: Frame, star: TextButton, name: TextLabel, primary: TextButton?, stroke: UIStroke } } = {}

local function bagCard(id: string)
	local item = Items[id]
	local card = block({ Parent = bagGrid })
	local ring = UIKit.stroke(C.star, 2)
	ring.Parent = card
	hoverable(card, id)
	local star = textButton({ Parent = card, Position = UDim2.fromOffset(4, 2), Size = UDim2.fromOffset(26, 26), Text = "☆", TextColor3 = C.star, TextScaled = false, TextSize = 26, ZIndex = 3 }, function()
		Favourites.toggle(id)
		rebuildBag()
	end)
	Icons.make(id, card, UDim2.fromOffset(74, 74), UDim2.new(0.5, -37, 0, 8))
	-- Drag the card onto a hotbar slot to put it there.
	card.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			require(script.Parent.UI).beginDrag(id)
		end
	end)
	local name = label({ Parent = card, Position = UDim2.fromOffset(2, 84), Size = UDim2.new(1, -4, 0, 22), Text = item.name, TextScaled = false, TextSize = 18 })
	-- A darker strip along the bottom holds the actions.
	block({ Parent = card, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = C.cardDark })

	local actions = new("Frame", { Parent = card, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 4, 1, -5), Size = UDim2.new(1, -8, 0, 28), BackgroundTransparency = 1, ZIndex = 3 }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local function act(order: number, text: string, fn: () -> ()): TextButton
		return textButton({ Parent = actions, LayoutOrder = order, Size = UDim2.fromOffset(0, 28), AutomaticSize = Enum.AutomaticSize.X, Text = text, TextScaled = false, TextSize = 21, ZIndex = 3 }, fn)
	end
	local primary
	if item.kind == "armour" then
		primary = act(1, "Equip", function()
			callbacks.onWear(id)
		end)
	elseif item.kind == "tool" or item.kind == "placeable" or item.kind == "seed" then
		primary = act(1, if item.kind == "seed" then "Hold" else "Equip", function()
			callbacks.onHold(if state.equipped == id then nil else id)
		end)
	elseif item.kind == "food" then
		act(1, "Eat", function()
			callbacks.onEat(id)
		end)
	elseif item.kind == "crate" then
		act(1, "Open", function()
			callbacks.onEat(id)
		end)
	elseif item.kind == "raft" then
		act(1, "Launch", function()
			callbacks.onEat(id)
		end)
	end
	act(2, "Drop", function()
		callbacks.onDrop(id)
	end)
	local entry = { card = card, star = star, name = name, primary = primary, stroke = ring }
	bagCards[id] = entry
	return entry
end

function rebuildBag()
	styleTabs(bagTabs, bagTab)
	local kinds
	for _, tab in BAG_TABS do
		if tab.name == bagTab then
			kinds = tab.kinds
		end
	end
	local ids = {}
	for id, count in state.items do
		if count > 0 and Items[id] and (kinds == nil or kinds[Items[id].kind]) then
			table.insert(ids, id)
		end
	end
	table.sort(ids, function(a, b)
		local fa, fb = Favourites.has(a), Favourites.has(b)
		if fa ~= fb then
			return fa
		end
		return Items[a].order < Items[b].order
	end)
	local shown = {}
	for i, id in ids do
		shown[id] = true
		local item = Items[id]
		local entry = bagCards[id] or bagCard(id)
		local worn = item.kind == "armour" and state.armour[item.slot] == id
		local held = state.equipped == id
		entry.card.Visible = true
		entry.card.LayoutOrder = i
		entry.stroke.Enabled = worn or held
		entry.star.Text = if Favourites.has(id) then "★" else "☆"
		local count = state.items[id]
		entry.name.Text = if count > 1 then item.name .. " (x" .. count .. ")" else item.name
		if entry.primary then
			entry.primary.Text = if worn or held then "Unequip" else "Equip"
		end
	end
	for id, entry in bagCards do
		if not shown[id] then
			entry.card.Visible = false
		end
	end
end

local stripCounts: { [string]: TextLabel } = {}

local function rebuildStrip()
	for i, id in STRIP_ITEMS do
		local count = stripCounts[id]
		if not count then
			local cell = new("Frame", { Parent = strip, LayoutOrder = i, Size = UDim2.fromOffset(64, 56), BackgroundTransparency = 1 })
			local short = string.match(Items[id].name, "(%S+)$") or Items[id].name
			label({ Parent = cell, Size = UDim2.new(1, 0, 0, 14), Text = short, TextScaled = false, TextSize = 14 })
			Icons.make(id, cell, UDim2.fromOffset(26, 26), UDim2.new(0.5, -13, 0, 14))
			count = label({ Parent = cell, Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 0, 15), Text = "", TextScaled = false, TextSize = 16 })
			stripCounts[id] = count
		end
		count.Text = "x" .. (state.items[id] or 0)
	end
end

-- Several inventory updates can land in one frame (craft = take + add); redraw once.
local pending = false
function Screen.refresh()
	if pending or not (root and root.Visible) then
		return
	end
	pending = true
	task.defer(function()
		pending = false
		if root.Visible then
			rebuildCrafting()
			rebuildBag()
			rebuildStrip()
		end
	end)
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
	inspect(nil)
	Screen.refresh()
end

function Screen.close()
	root.Visible = false
	if Screen.closeDetails then
		Screen.closeDetails()
	end
end

-- The (i) panel: zooms in over the screen with the item turning slowly on a pedestal,
-- what it does, each ingredient big with its name and have/need, and Craft.
local detail: Frame? = nil
function Screen.closeDetails()
	if detail then
		local d = detail
		detail = nil
		local sc = d:FindFirstChildOfClass("UIScale")
		if sc then
			TweenService:Create(sc, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.9 }):Play()
		end
		TweenService:Create(d, TweenInfo.new(0.14), { GroupTransparency = 1 }):Play()
		task.delay(0.15, function()
			d:Destroy()
		end)
	end
end

function Screen.details(recipe)
	Screen.closeDetails()
	local item = Items[recipe.id]
	local level = player:GetAttribute("Level") or 1
	local d = new("CanvasGroup", { Parent = root, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.46), Size = UDim2.fromOffset(440, 360), BackgroundColor3 = C.panel, BackgroundTransparency = 0.04, GroupTransparency = 1, ZIndex = 50 }, {
		new("UICorner", { CornerRadius = UDim.new(0, 14) }),
		new("UIStroke", { Color = C.rim, Thickness = 3 }),
	})
	detail = d
	local sc = new("UIScale", { Parent = d, Scale = 0.85 })
	TweenService:Create(sc, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(d, TweenInfo.new(0.18), { GroupTransparency = 0 }):Play()

	label({ Parent = d, Position = UDim2.fromOffset(0, 10), Size = UDim2.new(1, 0, 0, 30), Text = item.name, TextScaled = false, TextSize = 28 })
	UIKit.closeButton({ Parent = d, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 8), TextScaled = false, TextSize = 18 }, function()
		Screen.closeDetails()
	end)
	-- Pedestal: a soft round glow with the item turning on it.
	local stage = new("Frame", { Parent = d, Position = UDim2.fromOffset(18, 50), Size = UDim2.fromOffset(170, 170), BackgroundColor3 = C.cardDark, BorderSizePixel = 0 }, {
		new("UICorner", { CornerRadius = UDim.new(1, 0) }),
	})
	local glow = new("Frame", { Parent = stage, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.8, 0.8), BackgroundColor3 = C.star, BackgroundTransparency = 0.82, BorderSizePixel = 0 }, {
		new("UICorner", { CornerRadius = UDim.new(1, 0) }),
	})
	TweenService:Create(glow, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Size = UDim2.fromScale(0.95, 0.95), BackgroundTransparency = 0.92 }):Play()
	local big = Icons.make(recipe.id, stage, UDim2.fromScale(0.86, 0.86), UDim2.fromScale(0.07, 0.07))
	Icons.spin(big, 0.8)
	local isLocked = level < recipe.level
	if isLocked and big and big:IsA("ViewportFrame") then
		big.ImageColor3 = Color3.new(0, 0, 0)
	end

	-- What it does, in a sentence or two.
	local about = label({ Parent = d, Position = UDim2.fromOffset(200, 54), Size = UDim2.fromOffset(222, 100), Text = if isLocked then "Reach level " .. recipe.level .. " to see what this is and what it takes." else (item.description or describe(recipe.id)), TextScaled = false, TextSize = 18, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top })
	label({ Parent = d, Position = UDim2.fromOffset(200, 160), Size = UDim2.fromOffset(222, 22), Text = (if level >= recipe.level then "Unlocked" else "Unlocks at level " .. recipe.level), TextScaled = false, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = if level >= recipe.level then C.good else C.bad })
	_ = about

	-- Ingredients, big, with names and what you have.
	local row = new("Frame", { Parent = d, Position = UDim2.fromOffset(14, 230), Size = UDim2.new(1, -28, 0, 76), BackgroundTransparency = 1 }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for id, amount in (if isLocked then {} else recipe.cost) do
		local have = state.items[id] or 0
		local cell = block({ Parent = row, Size = UDim2.fromOffset(86, 76), BackgroundColor3 = C.cardDark })
		label({ Parent = cell, Position = UDim2.fromOffset(2, 2), Size = UDim2.new(1, -4, 0, 16), Text = Items[id].name, TextScaled = true })
		Icons.make(id, cell, UDim2.fromOffset(36, 36), UDim2.new(0.5, -18, 0, 18))
		label({ Parent = cell, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -2), Size = UDim2.new(1, 0, 0, 18), Text = have .. " / " .. amount, TextScaled = false, TextSize = 16, TextColor3 = if have >= amount then C.good else C.bad })
	end
	if isLocked then
		label({ Parent = row, Size = UDim2.fromOffset(300, 60), Text = "??? Requirements hidden", TextScaled = false, TextSize = 22, TextColor3 = Color3.fromRGB(120, 120, 120) })
	end
	if level >= recipe.level then
		textButton({ Parent = d, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.fromOffset(180, 34), Text = "Craft", TextScaled = false, TextSize = 24 }, function()
			callbacks.onCraft(recipe.id)
			task.defer(function()
				if detail == d then
					Screen.details(recipe)
				end
			end)
		end)
	end
end

function Screen.init(parent: ScreenGui, cb)
	callbacks = cb
	root = new("Frame", { Parent = parent, Name = "Inventory", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false })

	-- Resource strip (top centre)
	local stripPanel = UIKit.panel({ Parent = root, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, TOP), Size = UDim2.fromOffset(#STRIP_ITEMS * 64 + 16, 62) })
	strip = new("Frame", { Parent = stripPanel, Position = UDim2.fromOffset(8, 3), Size = UDim2.new(1, -16, 1, -6), BackgroundTransparency = 1 }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	-- Inspect box under it: small name, then one big line about the item
	inspectBox = UIKit.panel({ Parent = root, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, TOP + 68), Size = UDim2.fromOffset(#STRIP_ITEMS * 64 + 16, 62), Visible = false })
	inspectName = label({ Parent = inspectBox, Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 0, 16), Text = "", TextScaled = false, TextSize = 16 })
	inspectLine = label({ Parent = inspectBox, Position = UDim2.fromOffset(8, 22), Size = UDim2.new(1, -16, 0, 34), Text = "", TextScaled = false, TextSize = 30 })

	-- Craft (left)
	local craftPanel = UIKit.panel({ Parent = root, Position = UDim2.fromOffset(12, TOP), Size = UDim2.new(0, PANEL_W, 1, -TOP - BOTTOM) })
	tabRow(craftPanel, CRAFT_TABS, craftTabs, function(name)
		craftTab = name
		rebuildCrafting()
	end)
	craftGrid = grid(craftPanel)

	-- Bag (right)
	local bagPanel = UIKit.panel({ Parent = root, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, TOP), Size = UDim2.new(0, PANEL_W, 1, -TOP - BOTTOM) })
	tabRow(bagPanel, BAG_TABS, bagTabs, function(name)
		bagTab = name
		rebuildBag()
	end)
	bagGrid = grid(bagPanel, BAG_CARD)

	-- On smaller screens shrink the whole screen to fit rather than overlap.
	local fit = new("UIScale", { Parent = root })
	local function refit()
		local sc = math.clamp(parent.AbsoluteSize.X / (PANEL_W * 2 + 440), 0.6, 1)
		fit.Scale = sc
		root.Size = UDim2.fromScale(1 / sc, 1 / sc)
	end
	parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)
	task.defer(refit)

	-- Red X in the gap above the hotbar
	UIKit.closeButton({ Parent = root, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -BOTTOM + 6), TextScaled = false, TextSize = 22 }, function()
		Screen.close()
	end)

	player:GetAttributeChangedSignal("Level"):Connect(Screen.refresh)
end

return Screen
