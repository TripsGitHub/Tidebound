-- The HUD: XP bar and compass (top), target bar (what you're hitting and its HP),
-- menu buttons, hotbar, Health/Bag/Hunger, pickup prompt, notices, pickup feed,
-- "+XP" popups, build bar, and the Quest Board / Trader panels.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local QuestList = require(Shared.Quests)
local ShopList = require(Shared.Shop)
local UIKit = require(script.Parent.UIKit)
local Icons = require(script.Parent.Icons)
local Hover = require(script.Parent.Hover)

local C = UIKit.Colors
local new, label, button, corner, stroke = UIKit.new, UIKit.label, UIKit.button, UIKit.corner, UIKit.stroke

local player = Players.LocalPlayer
local UI = {}

local gui: ScreenGui
local state = { items = {}, equipped = nil, armour = {}, bagSize = Config.BaseBagSize }
local questProgress, questClaimed = {}, {}
local callbacks: any = {}

local hotbar: Frame
local compass: Frame
local compassMarks: { { label: TextLabel, deg: number } } = {}
local targetFrame: Frame
local targetName: TextLabel
local targetFill: Frame
local targetHp: TextLabel
local promptFrame: Frame
local promptName: TextLabel
local promptKeys: Frame
local promptKeyFor = ""
local popupLayer: Frame
local popup: (string, Color3) -> ()
local lastHit: Model? = nil
local lastHitAt = 0
local noticeList: Frame
local feedList: Frame
local buildBar: Frame
local buildName: TextLabel
local xpFill: Frame
local xpText: TextLabel
local levelLeft: TextLabel
local levelRight: TextLabel
local bars = {}
local panels: { [string]: Frame } = {}
local panelLists: { [string]: ScrollingFrame } = {}
local openPanel: string? = nil

UI.root = nil :: ScreenGui?

-- Hotbar -------------------------------------------------------------------------

function UI.hotbarIds(): { string }
	local ids = {}
	for id, count in state.items do
		local kind = Items[id] and Items[id].kind
		if count > 0 and (kind == "tool" or kind == "food" or kind == "placeable") then
			table.insert(ids, id)
		end
	end
	table.sort(ids, function(a, b)
		return Items[a].order < Items[b].order
	end)
	local out = {}
	for i = 1, math.min(8, #ids) do
		out[i] = ids[i]
	end
	return out
end

local function rebuildHotbar()
	for _, c in hotbar:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local ids = UI.hotbarIds()
	for i = 1, math.max(5, #ids) do
		local id = ids[i]
		local selected = id ~= nil and id == state.equipped
		local holder = new("Frame", { Parent = hotbar, LayoutOrder = i, Size = UDim2.fromOffset(76, 84), BackgroundTransparency = 1 })
		local slot = new("TextButton", {
			Parent = holder,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, 0),
			Size = UDim2.fromOffset(if selected then 62 else 56, if selected then 62 else 56),
			BackgroundColor3 = if selected then Color3.fromRGB(252, 240, 214) else C.panel,
			BackgroundTransparency = if id then 0 else 0.25,
			Text = "",
			AutoButtonColor = id ~= nil,
		}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }), stroke(if selected then C.xp else C.edge, if selected then 3 else 2) })
		label({ Parent = slot, Size = UDim2.fromOffset(16, 16), Position = UDim2.fromOffset(2, 0), Text = tostring(i), TextColor3 = C.edge, ZIndex = 3 })
		if id then
			Icons.make(id, slot, UDim2.fromScale(0.8, 0.8), UDim2.fromScale(0.1, 0.1))
			UIKit.hudText({ Parent = holder, Size = UDim2.new(1, -2, 0, 15), Position = UDim2.fromOffset(1, 0), Text = Items[id].name, TextColor3 = if selected then C.xp else C.textLight })
			if (state.items[id] or 0) > 1 then
				label({ Parent = slot, AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromScale(1, 1), Size = UDim2.fromOffset(28, 16), Text = "x" .. state.items[id], TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 3 })
			end
			slot.MouseButton1Click:Connect(function()
				callbacks.onSlot(i)
			end)
		end
	end
end

-- Stat bars ----------------------------------------------------------------------

local function statBar(parent: Instance, order: number, name: string, color: Color3)
	local row = new("Frame", { Parent = parent, LayoutOrder = order, Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1 })
	label({ Parent = row, Size = UDim2.new(0, 60, 1, 0), Text = name, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.text })
	local back = new("Frame", { Parent = row, Position = UDim2.fromOffset(62, 2), Size = UDim2.new(1, -62, 1, -4), BackgroundColor3 = C.panelDark }, { corner(6) })
	local fill = new("Frame", { Parent = back, Size = UDim2.fromScale(1, 1), BackgroundColor3 = color }, { corner(6) })
	local text = label({ Parent = back, Size = UDim2.fromScale(1, 1), Text = "", TextColor3 = C.textLight, TextStrokeTransparency = 0.5, ZIndex = 2 })
	bars[name] = { fill = fill, text = text }
end

local function setBar(name: string, value: number, max: number, textOverride: string?)
	local b = bars[name]
	if not b then
		return
	end
	local ratio = if max > 0 then math.clamp(value / max, 0, 1) else 0
	TweenService:Create(b.fill, TweenInfo.new(0.15), { Size = UDim2.fromScale(ratio, 1) }):Play()
	b.text.Text = textOverride or tostring(math.ceil(value))
end

local function hookCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local function update()
		setBar("Health", humanoid.Health, humanoid.MaxHealth)
	end
	humanoid.HealthChanged:Connect(update)
	update()
end

local lastLevel, lastXp, lastHunger = nil, nil, nil
local xpCheckQueued = false

-- Level and XP arrive as two attribute changes; wait a moment so both have landed
-- before working out how much XP was gained.
local function queueXpCheck()
	if xpCheckQueued then
		return
	end
	xpCheckQueued = true
	task.delay(0.05, function()
		xpCheckQueued = false
		local level = player:GetAttribute("Level") or 1
		local xp = player:GetAttribute("XP") or 0
		if lastLevel and lastXp then
			local gained = if level > lastLevel then Config.XpForLevel(lastLevel) - lastXp + xp else xp - lastXp
			if gained > 0 then
				popup("+" .. gained .. " XP", Color3.fromRGB(150, 236, 110))
			end
			if level > lastLevel then
				UI.notify("Level " .. level .. "!", "good")
			end
		end
		lastLevel, lastXp = level, xp
	end)
end

local function updateStats()
	local hunger = player:GetAttribute("Hunger") or Config.MaxHunger
	if lastHunger and hunger > lastHunger + 0.5 then
		popup("+" .. math.floor(hunger - lastHunger + 0.5) .. " Hunger", C.hunger)
	end
	lastHunger = hunger
	setBar("Hunger", hunger, Config.MaxHunger)
	local used, size = player:GetAttribute("BagUsed") or 0, player:GetAttribute("BagSize") or Config.BaseBagSize
	setBar("Bag", used, size, if used >= size then "FULL!" else used .. "/" .. size)
	local level = player:GetAttribute("Level") or 1
	local xp = player:GetAttribute("XP") or 0
	local need = Config.XpForLevel(level)
	queueXpCheck()
	levelLeft.Text = "Lv. " .. level
	levelRight.Text = if level >= Config.MaxLevel then "MAX" else "Lv. " .. (level + 1)
	xpText.Text = if level >= Config.MaxLevel then "" else xp .. " / " .. need .. " XP"
	TweenService:Create(xpFill, TweenInfo.new(0.2), { Size = UDim2.fromScale(if level >= Config.MaxLevel then 1 else math.clamp(xp / need, 0, 1), 1) }):Play()
end

-- Notices and pickup feed --------------------------------------------------------

function UI.notify(text: string, style: string?)
	local color = if style == "warn" then C.warn elseif style == "good" then C.good else C.button
	-- Don't stack the same warning five times.
	for _, child in noticeList:GetChildren() do
		if child:IsA("TextLabel") and child.Text == text then
			child:SetAttribute("Born", os.clock())
			return
		end
	end
	local n = label({ Parent = noticeList, Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 0, BackgroundColor3 = color, TextColor3 = C.textLight, Text = text, TextScaled = false, TextSize = 18, Font = UIKit.FontHeavy }, nil)
	corner(8).Parent = n
	new("UIPadding", { Parent = n, PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) })
	n:SetAttribute("Born", os.clock())
	task.spawn(function()
		while n.Parent and os.clock() - (n:GetAttribute("Born") :: number) < 2.5 do
			task.wait(0.25)
		end
		local fade = TweenService:Create(n, TweenInfo.new(0.3), { BackgroundTransparency = 1, TextTransparency = 1 })
		fade:Play()
		fade.Completed:Wait()
		n:Destroy()
	end)
end

local feedRows: { [string]: TextLabel } = {}
function UI.pickup(itemId: string, amount: number)
	local row = feedRows[itemId]
	if row and row.Parent then
		row:SetAttribute("Amount", (row:GetAttribute("Amount") :: number) + amount)
		row:SetAttribute("Born", os.clock())
	else
		row = label({ Parent = feedList, Size = UDim2.new(1, 0, 0, 22), Text = "", TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = C.textLight, TextStrokeTransparency = 0.4, Font = UIKit.FontHeavy })
		row:SetAttribute("Amount", amount)
		row:SetAttribute("Born", os.clock())
		feedRows[itemId] = row
		task.spawn(function()
			while row.Parent and os.clock() - (row:GetAttribute("Born") :: number) < 2.5 do
				row.Text = "+" .. row:GetAttribute("Amount") .. " " .. Items[itemId].name
				task.wait(0.1)
			end
			row:Destroy()
			if feedRows[itemId] == row then
				feedRows[itemId] = nil
			end
		end)
	end
	row.Text = "+" .. row:GetAttribute("Amount") .. " " .. Items[itemId].name
end

-- Target bar and pickup prompt ----------------------------------------------------

-- Call when you hit something, so its bar stays up for a moment after you look away.
function UI.targetHit(model: Instance)
	if model and model:IsA("Model") then
		lastHit = model
		lastHitAt = os.clock()
	end
end

local function showTarget(name: string?, hp: number?, maxHp: number?)
	if not name or not hp or not maxHp or maxHp <= 0 then
		targetFrame.Visible = false
		return
	end
	targetFrame.Visible = true
	targetName.Text = name
	targetHp.Text = tostring(math.max(0, math.ceil(hp)))
	targetFill.Size = UDim2.fromScale(math.clamp(hp / maxHp, 0, 1), 1)
end

local function updateHover()
	local info = Hover.get()
	-- Target bar: whatever you're pointing at that has health, else what you last hit.
	if info.target and info.kind ~= "drop" and info.hp then
		showTarget(info.name, info.hp, info.maxHp)
	elseif lastHit and lastHit.Parent and os.clock() - lastHitAt < 3 and not lastHit:GetAttribute("Depleted") then
		local hum = lastHit:FindFirstChildOfClass("Humanoid")
		local hp = if hum then hum.Health else lastHit:GetAttribute("HP")
		local maxHp = if hum then hum.MaxHealth else lastHit:GetAttribute("MaxHP")
		showTarget(lastHit:GetAttribute("DisplayName") or lastHit.Name, hp, maxHp)
	else
		showTarget(nil)
	end

	-- Pickup prompt: the item's name in big letters, with its keys under it.
	if info.target and info.kind == "drop" and info.inRange then
		promptFrame.Visible = true
		promptName.Text = info.name or ""
		local itemId = info.target:GetAttribute("ItemId")
		local food = Items[itemId] and Items[itemId].kind == "food"
		local want = if food then "FE" else "F"
		if promptKeyFor ~= want then
			promptKeyFor = want
			for _, c in promptKeys:GetChildren() do
				if c:IsA("GuiObject") then
					c:Destroy()
				end
			end
			UIKit.keyCap(promptKeys, "F", "Pick up", 1)
			if food then
				UIKit.keyCap(promptKeys, "E", "Eat", 2)
			end
		end
	else
		promptFrame.Visible = false
	end
end

-- Compass ------------------------------------------------------------------------

local COMPASS_PX_PER_DEG = 3.2
local function updateCompass()
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local look = cam.CFrame.LookVector
	local heading = math.deg(math.atan2(look.X, -look.Z)) % 360 -- 0 = north (-Z)
	local half = compass.AbsoluteSize.X / 2
	for _, m in compassMarks do
		local diff = (m.deg - heading + 540) % 360 - 180
		local x = half + diff * COMPASS_PX_PER_DEG
		m.label.Visible = math.abs(diff) * COMPASS_PX_PER_DEG < half - 8
		m.label.Position = UDim2.fromOffset(x, 0)
	end
end

-- "+XP" popups -----------------------------------------------------------------------

popup = function(text: string, color: Color3)
	local badge = UIKit.hudText({ Parent = popupLayer, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5 + (math.random() - 0.5) * 0.3, 0.8), Size = UDim2.fromOffset(140, 30), Text = text, TextColor3 = color, TextScaled = false, TextSize = 26 })
	local rise = TweenService:Create(badge, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = badge.Position - UDim2.fromOffset(0, 60), TextTransparency = 1, TextStrokeTransparency = 1 })
	rise:Play()
	rise.Completed:Connect(function()
		badge:Destroy()
	end)
end
UI.popup = popup

-- Build bar ------------------------------------------------------------------------

function UI.setBuild(itemId: string?)
	buildBar.Visible = itemId ~= nil
	if itemId then
		buildName.Text = Items[itemId].name
	end
end

-- Quest Board / Trader panels ------------------------------------------------------

local function makePanel(name: string, title: string)
	local frame = UIKit.panel({ Parent = gui, Name = name, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.47), Size = UDim2.fromOffset(460, 400), Visible = false })
	label({ Parent = frame, Size = UDim2.new(1, -60, 0, 34), Position = UDim2.fromOffset(16, 10), Text = title, TextXAlignment = Enum.TextXAlignment.Left, Font = UIKit.FontHeavy })
	button({ Parent = frame, Size = UDim2.fromOffset(40, 30), Position = UDim2.new(1, -52, 0, 12), BackgroundColor3 = C.bad, Text = "X" }, function()
		UI.closePanels()
	end)
	local list = new("ScrollingFrame", {
		Parent = frame,
		Size = UDim2.new(1, -24, 1, -60),
		Position = UDim2.fromOffset(12, 52),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = C.edge,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	}, { new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
	panels[name] = frame
	panelLists[name] = list
end

local function clear(list: Instance)
	for _, c in list:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

local function rebuildQuests()
	local list = panelLists.quests
	clear(list)
	for i, q in QuestList do
		local row = new("Frame", { Parent = list, LayoutOrder = i, Size = UDim2.new(1, -8, 0, 64), BackgroundColor3 = C.card }, { corner(8) })
		local progress = questProgress[q.id] or 0
		local done, claimed = progress >= q.amount, questClaimed[q.id]
		label({ Parent = row, Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -130, 0, 24), Text = q.title, TextXAlignment = Enum.TextXAlignment.Left, Font = UIKit.FontHeavy })
		label({ Parent = row, Position = UDim2.fromOffset(10, 34), Size = UDim2.new(1, -130, 0, 20), TextScaled = false, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, Text = q.text .. "  (" .. progress .. "/" .. q.amount .. ")  ·  " .. q.reward .. " Shells" })
		button({ Parent = row, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(100, 36), BackgroundColor3 = if claimed then C.cardLocked elseif done then C.good else C.cardLocked, Text = if claimed then "Done" elseif done then "Claim" else "..." }, function()
			if done and not claimed then
				callbacks.onClaim(q.id)
			end
		end)
	end
end

local function rebuildShop()
	local list = panelLists.shop
	clear(list)
	local shells = player:GetAttribute("Shells") or 0
	label({ Parent = list, LayoutOrder = 0, Size = UDim2.new(1, -8, 0, 26), Text = "You have " .. shells .. " Shells", TextXAlignment = Enum.TextXAlignment.Left, Font = UIKit.FontHeavy })
	for i, entry in ShopList do
		local row = new("Frame", { Parent = list, LayoutOrder = i, Size = UDim2.new(1, -8, 0, 58), BackgroundColor3 = C.card }, { corner(8) })
		Icons.make(entry.item, row, UDim2.fromOffset(48, 48), UDim2.fromOffset(6, 5))
		label({ Parent = row, Position = UDim2.fromOffset(62, 16), Size = UDim2.new(1, -190, 0, 26), Text = entry.amount .. "  " .. Items[entry.item].name, TextXAlignment = Enum.TextXAlignment.Left })
		button({ Parent = row, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(110, 36), BackgroundColor3 = if shells >= entry.price then C.good else C.cardLocked, Text = entry.price .. " Shells" }, function()
			callbacks.onBuy(entry.id)
		end)
	end
end

local rebuilders = { quests = rebuildQuests, shop = rebuildShop }

function UI.openPanel(name: string)
	UI.closePanels()
	if panels[name] then
		openPanel = name
		rebuilders[name]()
		panels[name].Visible = true
	end
end

function UI.closePanels()
	for _, p in panels do
		p.Visible = false
	end
	openPanel = nil
end

local function refreshOpen()
	if openPanel then
		rebuilders[openPanel]()
	end
end

-- Public -----------------------------------------------------------------------

function UI.setInventory(items, equipped, armour, bagSize)
	state.items, state.equipped, state.armour, state.bagSize = items, equipped, armour, bagSize
	rebuildHotbar()
	refreshOpen()
end

function UI.setQuests(progress, claimed)
	questProgress, questClaimed = progress, claimed
	refreshOpen()
end

local function menuButton(parent: Instance, order: number, text: string, key: string, onClick: () -> ())
	local holder = new("Frame", { Parent = parent, LayoutOrder = order, Size = UDim2.fromOffset(64, 70), BackgroundTransparency = 1 })
	local b = new("TextButton", { Parent = holder, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(50, 50), BackgroundColor3 = C.panel, Text = key, TextColor3 = C.edge, Font = UIKit.FontHeavy, TextSize = 22 }, {
		new("UICorner", { CornerRadius = UDim.new(1, 0) }),
		stroke(C.edge, 2.5),
	})
	b.MouseButton1Click:Connect(onClick)
	label({ Parent = holder, Position = UDim2.fromOffset(0, 52), Size = UDim2.new(1, 0, 0, 16), Text = text, TextColor3 = C.textLight, TextStrokeTransparency = 0.4 })
end

function UI.init(cb)
	callbacks = cb
	gui = new("ScreenGui", { Name = "TideboundHUD", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui") })
	UI.root = gui

	-- XP bar (top centre): "Lv. 2 [ 21 / 44 XP ] Lv. 3"
	local xpRow = new("Frame", { Parent = gui, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(420, 26), BackgroundTransparency = 1 })
	levelLeft = label({ Parent = xpRow, Size = UDim2.fromOffset(60, 22), Position = UDim2.fromOffset(0, 2), Text = "Lv. 1", TextColor3 = C.textLight, TextStrokeTransparency = 0.3, Font = UIKit.FontHeavy })
	levelRight = label({ Parent = xpRow, AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromOffset(60, 22), Position = UDim2.new(1, 0, 0, 2), Text = "Lv. 2", TextColor3 = C.textLight, TextStrokeTransparency = 0.3, Font = UIKit.FontHeavy })
	local xpBack = new("Frame", { Parent = xpRow, Position = UDim2.fromOffset(66, 2), Size = UDim2.new(1, -132, 0, 22), BackgroundColor3 = C.panel }, { corner(6), stroke(C.edge, 2) })
	xpFill = new("Frame", { Parent = xpBack, Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.xp }, { corner(6) })
	xpText = label({ Parent = xpBack, Size = UDim2.fromScale(1, 1), Text = "", ZIndex = 2, TextScaled = false, TextSize = 14 })

	-- Compass strip under the XP bar
	compass = new("Frame", { Parent = gui, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 36), Size = UDim2.fromOffset(300, 18), BackgroundTransparency = 1, ClipsDescendants = true })
	for deg = 0, 345, 15 do
		local names = { [0] = "N", [90] = "E", [180] = "S", [270] = "W" }
		local cardinal = names[deg]
		local l = UIKit.hudText({ Parent = compass, AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(30, if cardinal then 18 else 13), Text = cardinal or tostring(deg), TextColor3 = if cardinal then C.xp else C.textLight })
		table.insert(compassMarks, { label = l, deg = deg })
	end
	new("Frame", { Parent = compass, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.fromOffset(2, 4), BackgroundColor3 = C.textLight, BorderSizePixel = 0 })

	-- Target bar: the name and HP of whatever you're hitting
	targetFrame = new("Frame", { Parent = gui, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 58), Size = UDim2.fromOffset(300, 44), BackgroundTransparency = 1, Visible = false })
	local targetBack = new("Frame", { Parent = targetFrame, Size = UDim2.new(1, 0, 0, 24), BackgroundColor3 = C.panel }, { corner(6), stroke(C.edge, 2) })
	targetFill = new("Frame", { Parent = targetBack, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(122, 196, 104) }, { corner(6) })
	targetHp = UIKit.hudText({ Parent = targetBack, Size = UDim2.fromScale(1, 1), Text = "", ZIndex = 2, TextScaled = false, TextSize = 18 })
	targetName = UIKit.hudText({ Parent = targetFrame, Position = UDim2.fromOffset(0, 25), Size = UDim2.new(1, 0, 0, 18), Text = "", TextScaled = false, TextSize = 16 })

	-- Menu buttons (left)
	local menu = new("Frame", { Parent = gui, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.42, 0), Size = UDim2.fromOffset(64, 230), BackgroundTransparency = 1 }, {
		new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	menuButton(menu, 1, "Inventory", "C", function()
		callbacks.onInventory()
	end)
	label({ Parent = menu, LayoutOrder = 2, Size = UDim2.fromOffset(64, 20), Text = "", TextColor3 = C.xp })
	local shellsLabel = label({ Parent = menu, LayoutOrder = 3, Size = UDim2.fromOffset(64, 40), Text = "0\nShells", TextColor3 = C.xp, TextStrokeTransparency = 0.3, Font = UIKit.FontHeavy })

	-- Hotbar (bottom centre)
	hotbar = new("Frame", { Parent = gui, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.fromOffset(8 * 82, 84), BackgroundTransparency = 1 }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Bottom, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	-- Stats (bottom right)
	local stats = UIKit.panel({ Parent = gui, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -10, 1, -10), Size = UDim2.fromOffset(230, 78) }, nil)
	new("UIPadding", { Parent = stats, PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 8) })
	new("UIListLayout", { Parent = stats, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder })
	statBar(stats, 1, "Health", C.health)
	statBar(stats, 2, "Bag", C.bag)
	statBar(stats, 3, "Hunger", C.hunger)

	-- Pickup prompt (just above the hotbar): big item name, then its keys
	promptFrame = new("Frame", { Parent = gui, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -104), Size = UDim2.fromOffset(360, 70), BackgroundTransparency = 1, Visible = false })
	promptName = UIKit.hudText({ Parent = promptFrame, Size = UDim2.new(1, 0, 0, 34), Text = "", TextScaled = false, TextSize = 30 })
	promptKeys = new("Frame", { Parent = promptFrame, Position = UDim2.fromOffset(0, 38), Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1 }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	-- Floating "+XP" / "+Hunger" popups
	popupLayer = new("Frame", { Parent = gui, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })

	-- Notices (top centre, below the XP bar)
	noticeList = new("Frame", { Parent = gui, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 108), Size = UDim2.fromOffset(600, 150), BackgroundTransparency = 1 }, {
		new("UIListLayout", { Padding = UDim.new(0, 4), HorizontalAlignment = Enum.HorizontalAlignment.Center }),
	})

	-- Pickup feed (right middle)
	feedList = new("Frame", { Parent = gui, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.55, 0), Size = UDim2.fromOffset(220, 160), BackgroundTransparency = 1 }, {
		new("UIListLayout", { Padding = UDim.new(0, 2), VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Right }),
	})

	-- Build bar (top centre while holding a buildable)
	buildBar = new("Frame", { Parent = gui, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 108), Size = UDim2.fromOffset(300, 70), BackgroundTransparency = 1, Visible = false })
	local nameBox = UIKit.panel({ Parent = buildBar, Size = UDim2.new(1, 0, 0, 34) })
	buildName = label({ Parent = nameBox, Size = UDim2.new(1, -16, 1, -6), Position = UDim2.fromOffset(8, 3), Text = "", Font = UIKit.FontHeavy })
	button({ Parent = buildBar, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 38), Size = UDim2.fromOffset(56, 26), BackgroundColor3 = C.bad, Text = "X" }, function()
		callbacks.onCancelBuild()
	end)
	label({ Parent = buildBar, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 68), Size = UDim2.fromOffset(300, 16), Text = "Click to place  ·  R to rotate", TextColor3 = C.textLight, TextStrokeTransparency = 0.4, TextScaled = false, TextSize = 14 })

	makePanel("quests", "Quest Board")
	makePanel("shop", "Trader")

	for _, attr in { "Hunger", "BagUsed", "BagSize", "Level", "XP" } do
		player:GetAttributeChangedSignal(attr):Connect(updateStats)
	end
	player:GetAttributeChangedSignal("Shells"):Connect(function()
		shellsLabel.Text = (player:GetAttribute("Shells") or 0) .. "\nShells"
		refreshOpen()
	end)
	updateStats()
	if player.Character then
		task.spawn(hookCharacter, player.Character)
	end
	player.CharacterAdded:Connect(hookCharacter)
	RunService.RenderStepped:Connect(function()
		updateHover()
		updateCompass()
	end)
	rebuildHotbar()
end

return UI
