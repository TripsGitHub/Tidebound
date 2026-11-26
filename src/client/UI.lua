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
local hotbarRope: Frame
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
	local count = math.max(6, #ids)
	hotbarRope.Size = UDim2.fromOffset(count * 80, 5)
	for i = 1, count do
		local id = ids[i]
		local selected = id ~= nil and id == state.equipped
		local holder = new("Frame", { Parent = hotbar, LayoutOrder = i, Size = UDim2.fromOffset(76, 90), BackgroundTransparency = 1 })
		-- Each slot is a log slice hanging on the rope; the held one lifts and gets a sea-glass rim.
		local slot = UIKit.slice({
			Parent = holder,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, if selected then -12 else -4),
			Size = UDim2.fromOffset(if selected then 60 else 56, if selected then 60 else 56),
			BackgroundTransparency = if id then 0 else 0.45,
		})
		if selected then
			slot:FindFirstChildOfClass("UIStroke").Color = C.xp
		end
		local hit = new("TextButton", { Parent = slot, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 5 })
		local num = new("Frame", { Parent = slot, Position = UDim2.fromOffset(-9, -9), Size = UDim2.fromOffset(20, 20), BackgroundColor3 = C.bark, ZIndex = 4 }, { UIKit.round() })
		label({ Parent = num, Size = UDim2.fromScale(1, 1), Text = tostring(i), TextColor3 = C.woodLight, TextScaled = false, TextSize = 12, ZIndex = 4 })
		if id then
			Icons.make(id, slot, UDim2.fromScale(0.9, 0.9), UDim2.fromScale(0.05, 0.05))
			UIKit.hudText({ Parent = holder, Position = UDim2.fromOffset(0, if selected then -6 else 2), Size = UDim2.new(1, 0, 0, 15), Text = Items[id].name, TextColor3 = if selected then C.glassLight else C.textLight, TextScaled = false, TextSize = 13, TextWrapped = false })
			if (state.items[id] or 0) > 1 then
				UIKit.hudText({ Parent = slot, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 8, 1, 6), Size = UDim2.fromOffset(30, 18), Text = tostring(state.items[id]), TextXAlignment = Enum.TextXAlignment.Right, TextScaled = false, TextSize = 16, ZIndex = 4 })
			end
			hit.MouseButton1Click:Connect(function()
				callbacks.onSlot(i)
			end)
		end
	end
end

-- Stat bars ----------------------------------------------------------------------

local function statBar(parent: Instance, order: number, name: string, color: Color3)
	local row = new("Frame", { Parent = parent, LayoutOrder = order, Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1 })
	label({ Parent = row, Size = UDim2.new(0, 60, 1, 0), Text = name, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = color:Lerp(C.text, 0.15), TextScaled = false, TextSize = 14 })
	local back = new("Frame", { Parent = row, Position = UDim2.new(0, 62, 0.5, -6), Size = UDim2.new(1, -94, 0, 12), BackgroundColor3 = C.panelDark }, { UIKit.round(), stroke(Color3.fromRGB(140, 116, 80), 1.5) })
	local fill = new("Frame", { Parent = back, Size = UDim2.fromScale(1, 1), BackgroundColor3 = color }, { UIKit.round(), UIKit.shade(0.2) })
	local text = label({ Parent = row, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0, 30, 1, 0), Text = "", TextXAlignment = Enum.TextXAlignment.Right, TextScaled = false, TextSize = 13 })
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
				popup("+" .. gained .. " XP", C.glassLight)
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
	setBar("Bag", used, size, if used >= size then "FULL" else tostring(used))
	local level = player:GetAttribute("Level") or 1
	local xp = player:GetAttribute("XP") or 0
	local need = Config.XpForLevel(level)
	queueXpCheck()
	levelLeft.Text = tostring(level)
	levelRight.Text = if level >= Config.MaxLevel then "MAX" else tostring(level + 1)
	xpText.Text = if level >= Config.MaxLevel then "" else xp .. " / " .. need
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
	local n = UIKit.hudText({ Parent = noticeList, Size = UDim2.fromOffset(0, 32), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 0, BackgroundColor3 = color, Text = text, TextScaled = false, TextSize = 18 })
	corner(5).Parent = n
	new("UIStroke", { Parent = n, Color = C.bark, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	UIKit.grain(false, 0.5).Parent = n
	new("UIPadding", { Parent = n, PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) })
	n:SetAttribute("Born", os.clock())
	task.spawn(function()
		while n.Parent and os.clock() - (n:GetAttribute("Born") :: number) < 2.5 do
			task.wait(0.25)
		end
		for _, st in n:GetChildren() do
			if st:IsA("UIStroke") then
				TweenService:Create(st, TweenInfo.new(0.3), { Transparency = 1 }):Play()
			end
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
		row = UIKit.hudText({ Parent = feedList, Size = UDim2.new(1, 0, 0, 22), Text = "", TextXAlignment = Enum.TextXAlignment.Right, TextScaled = false, TextSize = 17 })
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
	targetHp.Text = math.max(0, math.ceil(hp)) .. " / " .. math.ceil(maxHp)
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
	local badge = UIKit.hudText({ Parent = popupLayer, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5 + (math.random() - 0.5) * 0.3, 0.8), Size = UDim2.fromOffset(160, 32), Text = text, TextColor3 = color, TextScaled = false, TextSize = 28 })
	local info = TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local rise = TweenService:Create(badge, info, { Position = badge.Position - UDim2.fromOffset(0, 60), TextTransparency = 1 })
	TweenService:Create(badge:FindFirstChildOfClass("UIStroke") :: UIStroke, info, { Transparency = 1 }):Play()
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
	local frame = UIKit.panel({ Parent = gui, Name = name, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.47), Size = UDim2.fromOffset(470, 410), Visible = false })
	UIKit.sign(frame, title, 220)
	local close = button({ Parent = frame, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -6, 0, 6), Size = UDim2.fromOffset(42, 38), BackgroundColor3 = C.bad, Text = "X", TextScaled = false, TextSize = 22, ZIndex = 6 }, function()
		UI.closePanels()
	end)
	close:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0.45, 0)
	local list = new("ScrollingFrame", {
		Parent = frame,
		Size = UDim2.new(1, -40, 1, -70),
		Position = UDim2.fromOffset(20, 40),
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
		local row = new("Frame", { Parent = list, LayoutOrder = i, Size = UDim2.new(1, -8, 0, 64), BackgroundColor3 = C.card }, { corner(6), stroke(Color3.fromRGB(160, 134, 96), 2), UIKit.stitch() })
		local progress = questProgress[q.id] or 0
		local done, claimed = progress >= q.amount, questClaimed[q.id]
		label({ Parent = row, Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -130, 0, 24), Text = q.title, TextXAlignment = Enum.TextXAlignment.Left, Font = UIKit.FontHeavy })
		label({ Parent = row, Position = UDim2.fromOffset(10, 34), Size = UDim2.new(1, -130, 0, 20), TextScaled = false, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, Text = q.text .. "  (" .. progress .. "/" .. q.amount .. ")  ·  " .. q.reward .. " Shells" })
		button({ Parent = row, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(100, 36), BackgroundColor3 = if claimed then C.button elseif done then C.good else C.button, Text = if claimed then "Done" elseif done then "Claim" else "..." }, function()
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
		local row = new("Frame", { Parent = list, LayoutOrder = i, Size = UDim2.new(1, -8, 0, 58), BackgroundColor3 = C.card }, { corner(6), stroke(Color3.fromRGB(160, 134, 96), 2), UIKit.stitch() })
		Icons.make(entry.item, row, UDim2.fromOffset(48, 48), UDim2.fromOffset(6, 5))
		label({ Parent = row, Position = UDim2.fromOffset(62, 16), Size = UDim2.new(1, -190, 0, 26), Text = entry.amount .. "  " .. Items[entry.item].name, TextXAlignment = Enum.TextXAlignment.Left })
		button({ Parent = row, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(110, 36), BackgroundColor3 = if shells >= entry.price then C.good else C.button, Text = entry.price .. " Shells" }, function()
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
	local holder = new("Frame", { Parent = parent, LayoutOrder = order, Size = UDim2.fromOffset(72, 76), BackgroundTransparency = 1 })
	local crate = UIKit.wood({ Parent = holder, Position = UDim2.fromOffset(2, 4), Size = UDim2.fromOffset(64, 60), Rotation = -2 })
	for _, y in { 19, 38 } do
		new("Frame", { Parent = crate, Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = C.edge, BorderSizePixel = 0 })
	end
	for _, p in { UDim2.fromOffset(7, 7), UDim2.new(1, -7, 0, 7), UDim2.new(0, 7, 1, -7), UDim2.new(1, -7, 1, -7) } do
		UIKit.nail(crate, p)
	end
	UIKit.hudText({ Parent = crate, Position = UDim2.fromOffset(4, 20), Size = UDim2.new(1, -8, 0, 18), Text = text, ZIndex = 3 })
	local peb = UIKit.pebble(crate, key, 22)
	peb.AnchorPoint = Vector2.new(0.5, 0.5)
	peb.Position = UDim2.new(1, -2, 1, -2)
	peb.ZIndex = 4
	local hit = new("TextButton", { Parent = holder, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 6 })
	hit.MouseButton1Click:Connect(onClick)
end

function UI.init(cb)
	callbacks = cb
	gui = new("ScreenGui", { Name = "TideboundHUD", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui") })
	UI.root = gui

	-- XP (top centre): a bamboo tube filling with sea-glass, between two hanging
	-- wooden level tags.
	local xpRow = new("Frame", { Parent = gui, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(390, 44), BackgroundTransparency = 1 })
	local function levelTag(x: number, rot: number, dim: boolean): TextLabel
		local tag = UIKit.wood({ Parent = xpRow, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(x, 0, 0, 2), Size = UDim2.fromOffset(46, 38), Rotation = rot, BackgroundColor3 = if dim then Color3.fromRGB(150, 116, 80) else nil, ZIndex = 3 })
		new("Frame", { Parent = tag, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 3), Size = UDim2.fromOffset(7, 7), BackgroundColor3 = C.bark, ZIndex = 4 }, { UIKit.round() })
		return UIKit.hudText({ Parent = tag, Position = UDim2.fromOffset(0, 9), Size = UDim2.new(1, 0, 1, -10), Text = "1", ZIndex = 4, TextScaled = false, TextSize = 22 })
	end
	levelLeft = levelTag(0.06, -7, false)
	levelRight = levelTag(0.94, 6, true)
	local tube = new("Frame", { Parent = xpRow, Position = UDim2.fromOffset(44, 10), Size = UDim2.new(1, -88, 0, 22), BackgroundColor3 = Color3.fromRGB(214, 196, 124), ClipsDescendants = true }, {
		UIKit.round(),
		stroke(C.bark, 2.5),
		UIKit.shade(0.2),
	})
	xpFill = new("Frame", { Parent = tube, Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.xp, BorderSizePixel = 0 }, {
		UIKit.round(),
		new("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(0.45, Color3.new(0.9, 0.9, 0.9)), ColorSequenceKeypoint.new(1, Color3.new(0.68, 0.68, 0.68)) }), Rotation = 90 }),
	})
	for k = 1, 5 do -- bamboo nodes
		new("Frame", { Parent = tube, Position = UDim2.new(k / 6, 0, 0, 0), Size = UDim2.new(0, 2, 1, 0), BackgroundColor3 = Color3.fromRGB(107, 90, 44), BorderSizePixel = 0, BackgroundTransparency = 0.25, ZIndex = 2 })
	end
	xpText = UIKit.hudText({ Parent = tube, Size = UDim2.fromScale(1, 1), Text = "", ZIndex = 3, TextScaled = false, TextSize = 14 })

	-- Compass: a carved driftwood strip under the XP bar, with a sea-glass pointer.
	local compassWood = UIKit.wood({ Parent = gui, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 44), Size = UDim2.fromOffset(270, 20) })
	compassWood:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(1, 0)
	compass = new("Frame", { Parent = compassWood, Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -16, 1, 0), BackgroundTransparency = 1, ClipsDescendants = true })
	for deg = 0, 345, 15 do
		local names = { [0] = "N", [90] = "E", [180] = "S", [270] = "W" }
		local cardinal = names[deg]
		local l = if cardinal
			then UIKit.hudText({ Parent = compass, AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(30, 18), Position = UDim2.fromOffset(0, 1), Text = cardinal, TextScaled = false, TextSize = 15 })
			else label({ Parent = compass, AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(30, 18), Text = if deg % 45 == 0 then "·" else tostring(deg), TextColor3 = C.bark, TextTransparency = 0.15, TextScaled = false, TextSize = 11 })
		table.insert(compassMarks, { label = l, deg = deg })
	end
	new("Frame", { Parent = gui, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 66), Size = UDim2.fromOffset(9, 9), Rotation = 45, BackgroundColor3 = C.xp }, { stroke(C.bark, 1.5) })

	-- Target: the name of what you're hitting, over a groove that empties as it loses
	-- HP, tied on with rope at both ends.
	targetFrame = new("Frame", { Parent = gui, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 74), Size = UDim2.fromOffset(240, 46), BackgroundTransparency = 1, Visible = false })
	targetName = UIKit.hudText({ Parent = targetFrame, Size = UDim2.new(1, 0, 0, 22), Text = "", TextScaled = false, TextSize = 20 })
	local targetBack = new("Frame", { Parent = targetFrame, Position = UDim2.fromOffset(0, 25), Size = UDim2.new(1, 0, 0, 18), BackgroundColor3 = C.edge, ClipsDescendants = true }, { corner(3), stroke(C.bark, 2) })
	targetFill = new("Frame", { Parent = targetBack, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(120, 186, 80), BorderSizePixel = 0 }, { UIKit.shade(0.3) })
	targetHp = UIKit.hudText({ Parent = targetBack, Size = UDim2.fromScale(1, 1), Text = "", ZIndex = 2, TextScaled = false, TextSize = 13 })
	UIKit.rope(targetFrame, UDim2.new(0, -6, 0, 34), UDim2.fromOffset(14, 10), 0)
	UIKit.rope(targetFrame, UDim2.new(1, 6, 0, 34), UDim2.fromOffset(14, 10), 0)

	-- Left: the crate that opens crafting + bag, and your Shells under it.
	local menu = new("Frame", { Parent = gui, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.42, 0), Size = UDim2.fromOffset(80, 140), BackgroundTransparency = 1 }, {
		new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	menuButton(menu, 1, "Pack", "C", function()
		callbacks.onInventory()
	end)
	local shellRow = new("Frame", { Parent = menu, LayoutOrder = 2, Size = UDim2.fromOffset(80, 30), BackgroundTransparency = 1 })
	-- A sand dollar: Tidebound's Shells.
	local dollar = new("Frame", { Parent = shellRow, Position = UDim2.fromOffset(2, 1), Size = UDim2.fromOffset(28, 28), BackgroundColor3 = Color3.fromRGB(240, 226, 196) }, { UIKit.round(), stroke(Color3.fromRGB(140, 116, 80), 2.5), UIKit.shade(0.12) })
	for k = 0, 4 do
		local a = math.rad(k * 72 - 90)
		new("Frame", { Parent = dollar, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, math.cos(a) * 6, 0.5, math.sin(a) * 6), Size = UDim2.fromOffset(3, 7), Rotation = k * 72, BackgroundColor3 = Color3.fromRGB(184, 156, 112), BorderSizePixel = 0 }, { UIKit.round() })
	end
	local shellsLabel = UIKit.hudText({ Parent = shellRow, Position = UDim2.fromOffset(36, 0), Size = UDim2.new(1, -36, 1, 0), Text = "0", TextXAlignment = Enum.TextXAlignment.Left, TextScaled = false, TextSize = 22 })

	-- Hotbar (bottom centre): log slices hanging on a rope.
	hotbarRope = new("Frame", { Parent = gui, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -42), Size = UDim2.fromOffset(480, 5), BackgroundColor3 = C.rope }, { UIKit.round(), stroke(Color3.fromRGB(110, 82, 48), 1) })
	hotbar = new("Frame", { Parent = gui, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.fromOffset(8 * 82, 90), BackgroundTransparency = 1 }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Bottom, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	-- Stats (bottom right): a strip of sailcloth nailed to a stick.
	local stats = new("Frame", { Parent = gui, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -14), Size = UDim2.fromOffset(222, 94), Rotation = -1.5, BackgroundTransparency = 1 })
	local cloth = new("Frame", { Parent = stats, Position = UDim2.fromOffset(4, 8), Size = UDim2.new(1, -8, 1, -8), BackgroundColor3 = C.panel }, {
		UIKit.corner(8),
		stroke(Color3.fromRGB(156, 131, 88), 2),
		UIKit.shade(0.1),
		UIKit.stitch(Color3.fromRGB(205, 182, 138)),
		new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 12) }),
		new("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	UIKit.wood({ Parent = stats, Position = UDim2.fromOffset(-6, -4), Size = UDim2.new(1, 12, 0, 14), ZIndex = 2 }, true)
	UIKit.nail(stats, UDim2.fromOffset(22, 3))
	UIKit.nail(stats, UDim2.new(1, -22, 0, 3))
	statBar(cloth, 1, "Health", C.health)
	statBar(cloth, 2, "Hunger", C.hunger)
	statBar(cloth, 3, "Bag", C.bag)

	-- Pickup prompt: the item's name on a little sign hanging on two strings, keys under it.
	promptFrame = new("Frame", { Parent = gui, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -112), Size = UDim2.fromOffset(220, 76), BackgroundTransparency = 1, Visible = false })
	for _, x in { 40, -40 } do
		new("Frame", { Parent = promptFrame, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(if x > 0 then 0 else 1, x, 0, 2), Size = UDim2.fromOffset(2, 16), BackgroundColor3 = Color3.fromRGB(140, 106, 62), BorderSizePixel = 0 })
	end
	local promptSign = UIKit.wood({ Parent = promptFrame, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.new(1, -20, 0, 40), Rotation = -1.5 })
	UIKit.nail(promptSign, UDim2.fromOffset(30, 8))
	UIKit.nail(promptSign, UDim2.new(1, -30, 0, 8))
	promptName = UIKit.hudText({ Parent = promptSign, Position = UDim2.fromOffset(0, 3), Size = UDim2.new(1, 0, 1, -2), Text = "", TextScaled = false, TextSize = 24, ZIndex = 3 })
	promptKeys = new("Frame", { Parent = promptFrame, Position = UDim2.fromOffset(0, 46), Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1 }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	-- Floating "+XP" / "+Hunger" popups
	popupLayer = new("Frame", { Parent = gui, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })

	-- Notices (top centre, below the target bar)
	noticeList = new("Frame", { Parent = gui, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 126), Size = UDim2.fromOffset(600, 150), BackgroundTransparency = 1 }, {
		new("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center }),
	})

	-- Pickup feed (right middle)
	feedList = new("Frame", { Parent = gui, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.55, 0), Size = UDim2.fromOffset(220, 160), BackgroundTransparency = 1 }, {
		new("UIListLayout", { Padding = UDim.new(0, 2), VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Right }),
	})

	-- Build bar (top centre while holding a buildable): a sign with what you're placing.
	buildBar = new("Frame", { Parent = gui, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 126), Size = UDim2.fromOffset(300, 84), BackgroundTransparency = 1, Visible = false })
	local nameBox = UIKit.wood({ Parent = buildBar, Size = UDim2.new(1, 0, 0, 36), Rotation = -1 })
	UIKit.nail(nameBox, UDim2.fromOffset(10, 18))
	UIKit.nail(nameBox, UDim2.new(1, -10, 0, 18))
	buildName = UIKit.hudText({ Parent = nameBox, Size = UDim2.new(1, -40, 1, -4), Position = UDim2.fromOffset(20, 3), Text = "", TextScaled = false, TextSize = 20 })
	local cancel = button({ Parent = buildBar, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 40), Size = UDim2.fromOffset(40, 34), BackgroundColor3 = C.bad, Text = "X", TextScaled = false, TextSize = 20 }, function()
		callbacks.onCancelBuild()
	end)
	cancel:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0.45, 0)
	UIKit.hudText({ Parent = buildBar, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 78), Size = UDim2.fromOffset(300, 16), Text = "Click to place  ·  R to rotate", TextScaled = false, TextSize = 14 })

	makePanel("quests", "Quest Board")
	makePanel("shop", "Trader")

	for _, attr in { "Hunger", "BagUsed", "BagSize", "Level", "XP" } do
		player:GetAttributeChangedSignal(attr):Connect(updateStats)
	end
	player:GetAttributeChangedSignal("Shells"):Connect(function()
		shellsLabel.Text = tostring(player:GetAttribute("Shells") or 0)
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
