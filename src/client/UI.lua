-- The HUD: XP bar and compass (top), target bar (what you're hitting and its HP),
-- menu buttons, hotbar, Health/Bag/Hunger, pickup prompt, notices, pickup feed,
-- "+XP" popups, build bar, and the Quest Board / Trader panels.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local QuestList = require(Shared.Quests)
local Recipes = require(Shared.Recipes)
local ShopList = require(Shared.Shop)
local UIKit = require(script.Parent.UIKit)
local Icons = require(script.Parent.Icons)
local Favourites = require(script.Parent.Favourites)
local Hover = require(script.Parent.Hover)

local C = UIKit.Colors
local new, label, button, corner, stroke = UIKit.new, UIKit.label, UIKit.button, UIKit.corner, UIKit.stroke

local player = Players.LocalPlayer
local UI = {}
local rgbAir = Color3.fromRGB(104, 176, 206)

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
local promptFrame: BillboardGui
local promptName: TextLabel
local promptKeys: Frame
local promptKeyFor = ""
local selectedDrop: Model? = nil -- the drop you clicked; its prompt stays up
local promptTarget: Model? = nil
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

-- How many hotbar slots you have: more as you level up (Config.HotbarSlots).
function UI.hotbarSize(): number
	return Config.hotbarSlotsFor(Players.LocalPlayer:GetAttribute("Level") or 1)
end

-- Starred items first (any kind, armour included, in the order you starred
-- them), then tools, food, placeables and crates fill the remaining slots.
function UI.hotbarIds(): { string }
	local size = UI.hotbarSize()
	local out, used = {}, {}
	for _, id in Favourites.list() do
		if #out < size and (state.items[id] or 0) > 0 and Items[id] then
			table.insert(out, id)
			used[id] = true
		end
	end
	local ids = {}
	for id, count in state.items do
		local kind = Items[id] and Items[id].kind
		if count > 0 and not used[id] and (kind == "tool" or kind == "food" or kind == "placeable" or kind == "crate") then
			table.insert(ids, id)
		end
	end
	table.sort(ids, function(a, b)
		return Items[a].order < Items[b].order
	end)
	for _, id in ids do
		if #out >= size then
			break
		end
		table.insert(out, id)
	end
	return out
end

local lastSelected: { [string]: boolean } = {}

local function rebuildHotbar()
	for _, c in hotbar:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local ids = UI.hotbarIds()
	for i = 1, math.max(UI.hotbarSize(), #ids) do
		local id = ids[i]
		local item = id and Items[id]
		local worn = item ~= nil and item.kind == "armour" and state.armour[item.slot] == id
		local selected = id ~= nil and (id == state.equipped or worn)
		-- Round flat tan slot; the item's name sits above it, the stack count inside
		-- at the bottom. All your slots always show, like Island Tribes; the held
		-- item's slot gets a gold rim.
		local holder = new("Frame", { Parent = hotbar, LayoutOrder = i, Size = UDim2.fromOffset(58, 72), BackgroundTransparency = 1 })
		local size = 52
		local slot = new("TextButton", {
			Parent = holder,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, 0),
			Size = UDim2.fromOffset(size, size),
			BackgroundColor3 = C.panel,
			BackgroundTransparency = if id then UIKit.PANEL_ALPHA else 0.35,
			Text = "",
			AutoButtonColor = id ~= nil,
		}, { UIKit.round(), stroke(if selected then C.star else C.rim, if selected then 3 else 2) })
		if id then
			Icons.make(id, slot, UDim2.fromScale(0.78, 0.78), UDim2.fromScale(0.11, 0.06))
			-- Long names shrink to fit the slot so neighbours never overlap.
			local name = label({ Parent = holder, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.new(1, 10, 0, 16), ZIndex = if selected then 3 else 1, Text = Items[id].name, TextScaled = true, TextStrokeTransparency = 0.4, TextColor3 = if selected then C.star else C.text })
			new("UITextSizeConstraint", { Parent = name, MaxTextSize = 13 })
			if (state.items[id] or 0) > 1 then
				label({ Parent = slot, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -1), Size = UDim2.fromOffset(40, 14), Text = tostring(state.items[id]), TextScaled = false, TextSize = 13, ZIndex = 3 })
			end
			if Favourites.has(id) then
				label({ Parent = slot, Position = UDim2.fromOffset(2, 0), Size = UDim2.fromOffset(14, 14), Text = "★", TextColor3 = C.star, TextScaled = false, TextSize = 13, ZIndex = 3 })
			end
			slot.MouseButton1Click:Connect(function()
				callbacks.onSlot(i)
			end)
			-- Pop: the slot you just picked jumps up and settles.
			if selected and not lastSelected[id] then
				local scale = new("UIScale", { Parent = slot, Scale = 1.28 })
				TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
				slot.Position = UDim2.new(0.5, 0, 1, -8)
				TweenService:Create(slot, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 1, 0) }):Play()
			end
		end
	end
	lastSelected = {}
	for _, id in ids do
		local item = Items[id]
		if id == state.equipped or (item.kind == "armour" and state.armour[item.slot] == id) then
			lastSelected[id] = true
		end
	end
end

-- Stat bars ----------------------------------------------------------------------

local function statBar(parent: Instance, order: number, name: string, color: Color3)
	-- Roomy rows with a softer outline: the label, then a wide rounded bar with the
	-- value centred in it.
	local row = new("Frame", { Parent = parent, LayoutOrder = order, Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1 })
	label({ Parent = row, Size = UDim2.new(0, 74, 1, 0), Text = name, TextXAlignment = Enum.TextXAlignment.Left, TextScaled = false, TextSize = 18, TextStrokeTransparency = 0.55 })
	local back = new("Frame", { Parent = row, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 78, 0.5, 0), Size = UDim2.new(1, -78, 0, 20), BackgroundColor3 = C.barBack, BorderSizePixel = 0 }, { UIKit.round() })
	local fill = new("Frame", { Parent = back, Size = UDim2.fromScale(1, 1), BackgroundColor3 = color, BorderSizePixel = 0 }, { UIKit.round() })
	local text = label({ Parent = back, Size = UDim2.fromScale(1, 1), Text = "", TextScaled = false, TextSize = 15, TextStrokeTransparency = 0.5, ZIndex = 2 })
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
		-- Your save loading in isn't levelling up: just take the numbers.
		if not player:GetAttribute("DataLoaded") then
			lastLevel, lastXp = nil, nil
			return
		end
		if lastLevel and lastXp then
			local gained = if level > lastLevel then Config.XpForLevel(lastLevel) - lastXp + xp else xp - lastXp
			if gained > 0 then
				popup("+" .. gained .. "xp", C.xp, true)
			end
			if level > lastLevel then
				UI.levelUp(lastLevel, level)
			end
		end
		lastLevel, lastXp = level, xp
	end)
end

local function updateStats()
	local hunger = player:GetAttribute("Hunger") or Config.MaxHunger
	if lastHunger and hunger > lastHunger + 0.5 then
		UI.heart(math.floor(hunger - lastHunger + 0.5))
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
	-- Plain outlined words over the world, coloured by kind (red warning, green
	-- good news), no box.
	local color = if style == "warn" then C.bad elseif style == "good" then C.xp else C.text
	-- Don't stack the same warning five times.
	for _, child in noticeList:GetChildren() do
		if child:IsA("TextLabel") and child.Text == text then
			child:SetAttribute("Born", os.clock())
			return
		end
	end
	local n = label({ Parent = noticeList, Size = UDim2.fromOffset(0, 28), AutomaticSize = Enum.AutomaticSize.X, TextColor3 = color, Text = text, TextScaled = false, TextSize = 24 })
	n:SetAttribute("Born", os.clock())
	task.spawn(function()
		while n.Parent and os.clock() - (n:GetAttribute("Born") :: number) < 2.5 do
			task.wait(0.25)
		end
		local fade = TweenService:Create(n, TweenInfo.new(0.3), { TextTransparency = 1, TextStrokeTransparency = 1 })
		fade:Play()
		fade.Completed:Wait()
		n:Destroy()
	end)
end

-- "Level up!" notice: a green header with a tan row for each item that just
-- unlocked. Sits left of centre so it doesn't cover what you're hitting.
local levelUpBox: Frame? = nil
function UI.levelUp(fromLevel: number, toLevel: number)
	if levelUpBox then
		levelUpBox:Destroy()
	end
	local box = new("Frame", { Parent = gui, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(0.5, -120, 0.45, 0), Size = UDim2.fromOffset(240, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, {
		new("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	levelUpBox = box
	local head = UIKit.block({ Parent = box, LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = C.good })
	label({ Parent = head, Size = UDim2.fromScale(1, 1), Text = "Level up!  (" .. toLevel .. ")", TextScaled = false, TextSize = 24 })
	local n = 0
	for _, recipe in Recipes do
		if recipe.level > fromLevel and recipe.level <= toLevel then
			n += 1
			local row = UIKit.panel({ Parent = box, LayoutOrder = n, Size = UDim2.new(1, 0, 0, 34) })
			Icons.make(recipe.id, row, UDim2.fromOffset(28, 28), UDim2.fromOffset(4, 3))
			label({ Parent = row, Position = UDim2.fromOffset(38, 0), Size = UDim2.new(1, -42, 1, 0), Text = "Unlocked " .. Items[recipe.id].name, TextXAlignment = Enum.TextXAlignment.Left, TextScaled = false, TextSize = 18 })
		end
	end
	task.delay(5, function()
		if levelUpBox == box then
			box:Destroy()
			levelUpBox = nil
		end
	end)
end

-- Eating: a big flat green heart with "+N" in a white pill, centre screen.
function UI.heart(amount: number)
	if amount <= 0 then
		return
	end
	local heart = label({ Parent = popupLayer, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(150, 130), Text = "♥", TextColor3 = C.xp, TextStrokeTransparency = 1, TextScaled = true })
	local pill = new("Frame", { Parent = heart, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(64, 26), BackgroundColor3 = C.text }, { UIKit.round() })
	local num = UIKit.new("TextLabel", { Parent = pill, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, FontFace = UIKit.FontFace, TextSize = 20, TextColor3 = Color3.fromRGB(70, 140, 60), Text = "+" .. amount })
	task.delay(0.6, function()
		local info = TweenInfo.new(0.35)
		TweenService:Create(heart, info, { TextTransparency = 1 }):Play()
		TweenService:Create(pill, info, { BackgroundTransparency = 1 }):Play()
		local t = TweenService:Create(num, info, { TextTransparency = 1 })
		t:Play()
		t.Completed:Wait()
		heart:Destroy()
	end)
end

local feedRows: { [string]: TextLabel } = {}
function UI.pickup(itemId: string, amount: number)
	local row = feedRows[itemId]
	if row and row.Parent then
		row:SetAttribute("Amount", (row:GetAttribute("Amount") :: number) + amount)
		row:SetAttribute("Born", os.clock())
	else
		row = label({ Parent = feedList, Size = UDim2.new(1, 0, 0, 22), Text = "", TextXAlignment = Enum.TextXAlignment.Right, TextScaled = false, TextSize = 20 })
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

-- A tan pill in the pickup prompt. On keyboards it carries the key in a small box;
-- on touch screens it is just the word.
local touchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local function promptButton(order: number, key: string, text: string, enabled: boolean, onClick: () -> ())
	local b = new("TextButton", { Parent = promptKeys, LayoutOrder = order, Size = UDim2.fromOffset(if touchOnly then 108 else 124, 36), BackgroundColor3 = C.panel, BackgroundTransparency = if enabled then 0.05 else 0.4, Text = "", AutoButtonColor = enabled }, {
		corner(8),
		stroke(C.rim, 2),
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	if not touchOnly then
		local cap = new("Frame", { Parent = b, LayoutOrder = 1, Size = UDim2.fromOffset(20, 20), BackgroundColor3 = C.cardDark, BorderSizePixel = 0 }, { corner(4) })
		label({ Parent = cap, Size = UDim2.fromScale(1, 1), Text = key, TextScaled = false, TextSize = 14, TextStrokeTransparency = 0.5 })
	end
	label({ Parent = b, LayoutOrder = 2, Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X, Text = text, TextScaled = false, TextSize = 22 })
	if enabled then
		b.MouseButton1Click:Connect(onClick)
	end
	return b
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

	-- Pickup prompt over the item: its name, then tan "Pickup" (and "Eat") buttons.
	-- Clicking or tapping a drop selects it, so the prompt stays until you pick it
	-- up, walk away or click something else; hovering shows it too.
	local target, name, inRange = nil, nil, false
	if selectedDrop then
		if selectedDrop.Parent then
			local n, ok, d = Hover.dropInfo(selectedDrop)
			if d <= Config.PickupRange + 4 then
				target, name, inRange = selectedDrop, n, ok
			else
				selectedDrop = nil
			end
		else
			selectedDrop = nil
		end
	end
	if not target and info.target and info.kind == "drop" and info.inRange then
		target, name, inRange = info.target, info.name, true
	end
	if target then
		local anchor = target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart", true)
		promptFrame.Adornee = anchor
		promptFrame.Enabled = anchor ~= nil
		promptName.Text = name or ""
		promptTarget = target
		local itemId = target:GetAttribute("ItemId")
		local food = Items[itemId] and Items[itemId].kind == "food"
		local want = (if food then "FE" else "F") .. (if inRange then "" else "-")
		if promptKeyFor ~= want then
			promptKeyFor = want
			for _, c in promptKeys:GetChildren() do
				if c:IsA("GuiObject") then
					c:Destroy()
				end
			end
			promptButton(1, "F", "Pickup", inRange, function()
				if promptTarget then
					callbacks.onPickupDrop(promptTarget)
				end
			end)
			if food then
				promptButton(2, "E", "Eat", inRange, function()
					if promptTarget then
						callbacks.onEatDrop(promptTarget)
					end
				end)
			end
		end
	else
		promptFrame.Enabled = false
		promptTarget = nil
	end
end

function UI.selectDrop(model: Model?)
	selectedDrop = model
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
	local half = compass.Size.X.Offset / 2
	for _, m in compassMarks do
		local diff = (m.deg - heading + 540) % 360 - 180
		local x = half + diff * COMPASS_PX_PER_DEG
		m.label.Visible = math.abs(diff) * COMPASS_PX_PER_DEG < half - 8
		m.label.Position = UDim2.fromOffset(x, 0)
	end
end

-- "+XP" popups -----------------------------------------------------------------------

popup = function(text: string, color: Color3, orb: boolean?)
	local badge = UIKit.hudText({ Parent = popupLayer, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5 + (math.random() - 0.5) * 0.3, 0.72), Size = UDim2.fromOffset(140, 30), Text = text, TextColor3 = color, TextScaled = false, TextSize = 26 })
	if orb then
		-- A small green "XP" orb to the left of the number.
		local o = new("Frame", { Parent = badge, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(0.5, -34, 0.5, 0), Size = UDim2.fromOffset(26, 26), BackgroundColor3 = C.xp, Rotation = 22.5 }, { corner(7), stroke(Color3.fromRGB(60, 130, 50), 2) })
		label({ Parent = o, Size = UDim2.fromScale(1, 1), Rotation = -22.5, Text = "XP", TextScaled = false, TextSize = 13 })
		TweenService:Create(o, TweenInfo.new(1.1), { BackgroundTransparency = 1 }):Play()
	end
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
	-- A narrow centred panel with a big outlined title and the red X pill under it.
	local frame = UIKit.panel({ Parent = gui, Name = name, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(380, 400), Visible = false })
	UIKit.title(frame, title)
	UIKit.closeButton({ Parent = frame, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 8), TextScaled = false, TextSize = 22 }, function()
		UI.closePanels()
	end)
	local list = new("ScrollingFrame", {
		Parent = frame,
		Size = UDim2.new(1, -16, 1, -48),
		Position = UDim2.fromOffset(8, 42),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = C.rim,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	}, { new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
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
		local row = UIKit.block({ Parent = list, LayoutOrder = i, Size = UDim2.new(1, -8, 0, 62) })
		local progress = questProgress[q.id] or 0
		local done, claimed = progress >= q.amount, questClaimed[q.id]
		label({ Parent = row, Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -100, 0, 24), Text = q.title, TextXAlignment = Enum.TextXAlignment.Left, TextScaled = false, TextSize = 21 })
		label({ Parent = row, Position = UDim2.fromOffset(10, 32), Size = UDim2.new(1, -100, 0, 20), TextScaled = false, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, Text = q.text .. "  (" .. progress .. "/" .. q.amount .. ")  ·  " .. q.reward .. " Shells" })
		button({ Parent = row, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(78, 28), BackgroundColor3 = if claimed then C.cardLocked elseif done then C.good else C.cardDark, Text = if claimed then "Done" elseif done then "Claim" else (progress .. "/" .. q.amount), TextScaled = false, TextSize = 18 }, function()
			if done and not claimed then
				callbacks.onClaim(q.id)
			end
		end)
	end
end

local function rebuildShop()
	local list = panelLists.shop
	clear(list)
	-- Each row: what you give (Shells, red if you can't afford it) | Trade | what you get.
	local shells = player:GetAttribute("Shells") or 0
	local head = new("Frame", { Parent = list, LayoutOrder = 0, Size = UDim2.new(1, -8, 0, 22), BackgroundTransparency = 1 })
	label({ Parent = head, Size = UDim2.new(0.38, 0, 1, 0), Text = "Give", TextScaled = false, TextSize = 20 })
	label({ Parent = head, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0.38, 0, 1, 0), Text = "Get", TextScaled = false, TextSize = 20 })
	for i, entry in ShopList do
		local row = UIKit.block({ Parent = list, LayoutOrder = i, Size = UDim2.new(1, -8, 0, 70) })
		local give = new("Frame", { Parent = row, Size = UDim2.new(0.38, 0, 1, 0), BackgroundTransparency = 1 })
		label({ Parent = give, Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 14), Text = "Shells", TextScaled = false, TextSize = 13 })
		local coin = new("Frame", { Parent = give, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 22), Size = UDim2.fromOffset(24, 24), BackgroundColor3 = C.gold }, { UIKit.round(), stroke(C.edge, 1.5) })
		label({ Parent = coin, Size = UDim2.fromScale(1, 1), Text = "S", TextScaled = false, TextSize = 16 })
		label({ Parent = give, Position = UDim2.fromOffset(0, 48), Size = UDim2.new(1, 0, 0, 18), Text = tostring(entry.price), TextColor3 = if shells >= entry.price then C.good else C.bad, TextScaled = false, TextSize = 18 })
		button({ Parent = row, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(70, 26), BackgroundColor3 = C.good, Text = "Trade", TextScaled = false, TextSize = 18 }, function()
			callbacks.onBuy(entry.id)
		end)
		local get = new("Frame", { Parent = row, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0.38, 0, 1, 0), BackgroundTransparency = 1 })
		label({ Parent = get, Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 0, 14), Text = Items[entry.item].name, TextScaled = false, TextSize = 13 })
		local box = UIKit.block({ Parent = get, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 20), Size = UDim2.fromOffset(46, 46), BackgroundColor3 = C.cardDark })
		Icons.make(entry.item, box, UDim2.fromScale(0.9, 0.9), UDim2.fromScale(0.05, 0.05))
		label({ Parent = box, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -2, 1, 0), Size = UDim2.fromOffset(30, 16), Text = "x" .. entry.amount, TextXAlignment = Enum.TextXAlignment.Right, TextScaled = false, TextSize = 15, ZIndex = 3 })
	end
end

-- Storage chest: what's inside on top, your bag underneath. Click a stack to move it.
local chest: { model: Model?, contents: { [string]: number }, cap: number } = { model = nil, contents = {}, cap = 0 }

local function sortedIds(map: { [string]: number }): { string }
	local ids = {}
	for id, n in map do
		if Items[id] and n > 0 then
			table.insert(ids, id)
		end
	end
	table.sort(ids, function(a, b)
		local oa, ob = Items[a].order or 999, Items[b].order or 999
		if oa ~= ob then
			return oa < ob
		end
		return a < b
	end)
	return ids
end

local function stackGrid(list: Instance, order: number, title: string, map: { [string]: number }, empty: string, onClick: (string) -> ())
	label({ Parent = list, LayoutOrder = order, Size = UDim2.new(1, -8, 0, 22), Text = title, TextXAlignment = Enum.TextXAlignment.Left, TextScaled = false, TextSize = 19 })
	local grid = new("Frame", { Parent = list, LayoutOrder = order + 1, Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, {
		new("UIGridLayout", { CellSize = UDim2.fromOffset(52, 52), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local ids = sortedIds(map)
	if #ids == 0 then
		label({ Parent = list, LayoutOrder = order + 1, Size = UDim2.new(1, -8, 0, 20), Text = empty, TextColor3 = C.textLight, TextScaled = false, TextSize = 15 })
		grid:Destroy()
		return
	end
	for i, id in ids do
		local cell = new("TextButton", { Parent = grid, LayoutOrder = i, Text = "", AutoButtonColor = true, BackgroundColor3 = C.cardDark }, { corner(6), stroke(C.rim, 1.5) })
		Icons.make(id, cell, UDim2.fromScale(0.84, 0.84), UDim2.fromScale(0.08, 0.08))
		label({ Parent = cell, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -3, 1, 0), Size = UDim2.fromOffset(40, 16), Text = tostring(map[id]), TextXAlignment = Enum.TextXAlignment.Right, TextScaled = false, TextSize = 15, ZIndex = 3 })
		cell.MouseButton1Click:Connect(function()
			onClick(id)
		end)
	end
end

local function rebuildChest()
	local list = panelLists.chest
	clear(list)
	local model = chest.model
	if not model then
		return
	end
	local used = 0
	for _, n in chest.contents do
		used += n
	end
	stackGrid(list, 1, "In the chest  (" .. used .. " / " .. chest.cap .. ")", chest.contents, "Empty. Click items in your bag to store them.", function(id)
		callbacks.onChestMove(model, id, "take")
	end)
	stackGrid(list, 10, "Your bag", state.items, "Your bag is empty.", function(id)
		callbacks.onChestMove(model, id, "put")
	end)
end

local rebuilders = { quests = rebuildQuests, shop = rebuildShop, chest = rebuildChest }

-- Opens or refreshes the chest panel; contents == nil closes it (the chest broke).
function UI.showChest(model: Model?, contents: { [string]: number }?, cap: number?)
	if not model or not contents then
		chest.model = nil
		if openPanel == "chest" then
			UI.closePanels()
		end
		return
	end
	chest.model, chest.contents, chest.cap = model, contents, cap or 0
	if openPanel == "chest" then
		rebuildChest()
	else
		UI.openPanel("chest")
	end
end

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

-- Top-left menu: label above, an icon on a small tan square, and the key in a tiny
-- box on its corner.
local function menuButton(parent: Instance, order: number, text: string, key: string, icon: string, onClick: () -> ())
	local holder = new("Frame", { Parent = parent, LayoutOrder = order, Size = UDim2.fromOffset(66, 74), BackgroundTransparency = 1 })
	label({ Parent = holder, Size = UDim2.new(1, 0, 0, 16), Text = text, TextScaled = false, TextSize = 16 })
	local b = new("TextButton", { Parent = holder, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 18), Size = UDim2.fromOffset(52, 52), BackgroundColor3 = C.panel, BackgroundTransparency = UIKit.PANEL_ALPHA, Text = "", AutoButtonColor = true }, {
		corner(8),
		stroke(C.rim, 2),
	})
	Icons.make(icon, b, UDim2.fromScale(0.84, 0.84), UDim2.fromScale(0.08, 0.08))
	local cap = new("Frame", { Parent = b, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 4, 1, 4), Size = UDim2.fromOffset(18, 18), BackgroundColor3 = C.cardDark, ZIndex = 3 }, { corner(4), stroke(C.rim, 1) })
	label({ Parent = cap, Size = UDim2.fromScale(1, 1), Text = key, TextScaled = false, TextSize = 14, ZIndex = 3 })
	b.MouseButton1Click:Connect(onClick)
end

function UI.init(cb)
	callbacks = cb
	Favourites.Changed:Connect(function()
		if hotbar then
			rebuildHotbar()
		end
	end)
	gui = new("ScreenGui", { Name = "TideboundHUD", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui") })
	UI.root = gui
	UIKit.fitScreen(gui)

	-- XP bar (top centre): "Lv. 2 [ 21 / 44 XP ] Lv. 3"
	local xpRow = new("Frame", { Parent = gui, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(420, 26), BackgroundTransparency = 1 })
	levelLeft = label({ Parent = xpRow, Size = UDim2.fromOffset(60, 22), Position = UDim2.fromOffset(0, 2), Text = "Lv. 1", TextScaled = false, TextSize = 22 })
	levelRight = label({ Parent = xpRow, AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromOffset(60, 22), Position = UDim2.new(1, 0, 0, 2), Text = "Lv. 2", TextScaled = false, TextSize = 22 })
	local xpBack = new("Frame", { Parent = xpRow, Position = UDim2.fromOffset(66, 3), Size = UDim2.new(1, -132, 0, 20), BackgroundColor3 = C.panel, BackgroundTransparency = UIKit.PANEL_ALPHA }, { corner(6), stroke(C.rim, 2) })
	xpFill = new("Frame", { Parent = xpBack, Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.xp, BorderSizePixel = 0 }, { corner(6) })
	xpText = label({ Parent = xpBack, Size = UDim2.fromScale(1, 1), Text = "", ZIndex = 2, TextScaled = false, TextSize = 15 })

	-- Compass strip under the XP bar
	compass = new("Frame", { Parent = gui, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 36), Size = UDim2.fromOffset(300, 18), BackgroundTransparency = 1, ClipsDescendants = true })
	for deg = 0, 345, 15 do
		local names = { [0] = "N", [90] = "E", [180] = "S", [270] = "W" }
		local cardinal = names[deg]
		local l = UIKit.hudText({ Parent = compass, AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(30, if cardinal then 18 else 13), Text = cardinal or tostring(deg), TextColor3 = if cardinal then C.star else C.textLight })
		table.insert(compassMarks, { label = l, deg = deg })
	end
	new("Frame", { Parent = compass, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.fromOffset(2, 4), BackgroundColor3 = C.textLight, BorderSizePixel = 0 })

	-- Target bar: the name and HP of whatever you're hitting
	targetFrame = new("Frame", { Parent = gui, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 58), Size = UDim2.fromOffset(300, 44), BackgroundTransparency = 1, Visible = false })
	local targetBack = new("Frame", { Parent = targetFrame, Size = UDim2.new(1, 0, 0, 22), BackgroundColor3 = C.cardDark, BackgroundTransparency = UIKit.PANEL_ALPHA }, { corner(6), stroke(C.rim, 2) })
	targetFill = new("Frame", { Parent = targetBack, Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.xp, BorderSizePixel = 0 }, { corner(6) })
	targetHp = UIKit.hudText({ Parent = targetBack, Size = UDim2.fromScale(1, 1), Text = "", ZIndex = 2, TextScaled = false, TextSize = 18 })
	targetName = UIKit.hudText({ Parent = targetFrame, Position = UDim2.fromOffset(0, 25), Size = UDim2.new(1, 0, 0, 18), Text = "", TextScaled = false, TextSize = 16 })

	-- Menu (top left): icon buttons in a row, then the Shells counter
	local menu = new("Frame", { Parent = gui, Position = UDim2.fromOffset(10, 8), Size = UDim2.fromOffset(240, 80), BackgroundTransparency = 1 }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	menuButton(menu, 1, "Inventory", "C", "leather_bag", function()
		callbacks.onInventory()
	end)
	local shellsHolder = new("Frame", { Parent = menu, LayoutOrder = 2, Size = UDim2.fromOffset(66, 74), BackgroundTransparency = 1 })
	label({ Parent = shellsHolder, Size = UDim2.new(1, 0, 0, 16), Text = "Shells", TextScaled = false, TextSize = 16 })
	local coin = new("Frame", { Parent = shellsHolder, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 20), Size = UDim2.fromOffset(32, 32), BackgroundColor3 = C.gold }, { UIKit.round(), stroke(C.edge, 2) })
	label({ Parent = coin, Size = UDim2.fromScale(1, 1), Text = "S", TextScaled = false, TextSize = 22 })
	local shellsLabel = label({ Parent = shellsHolder, Position = UDim2.fromOffset(0, 54), Size = UDim2.new(1, 0, 0, 18), Text = "0", TextScaled = false, TextSize = 20 })

	-- Hotbar (bottom centre)
	hotbar = new("Frame", { Parent = gui, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.fromOffset(8 * 62, 72), BackgroundTransparency = 1 }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Bottom, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	-- Stats (bottom right)
	local stats = UIKit.panel({ Parent = gui, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -10, 1, -10), Size = UDim2.fromOffset(268, 112) })
	new("UIPadding", { Parent = stats, PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10) })
	new("UIListLayout", { Parent = stats, Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center })
	statBar(stats, 1, "Health", C.health)
	statBar(stats, 2, "Bag", C.bag)
	statBar(stats, 3, "Hunger", C.hunger)

	-- Air: a row of bubbles above the stats that only shows under water (or while
	-- it refills). Each bubble pops as your air runs down.
	local airRow = new("Frame", { Parent = gui, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -10, 1, -128), Size = UDim2.fromOffset(268, 26), BackgroundTransparency = 1, Visible = false }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local bubbles: { Frame } = {}
	for i = 1, 10 do
		bubbles[i] = new("Frame", { Parent = airRow, LayoutOrder = i, Size = UDim2.fromOffset(20, 20), BackgroundColor3 = rgbAir, BackgroundTransparency = 0.15, BorderSizePixel = 0 }, {
			UIKit.round(),
			new("UIStroke", { Color = Color3.fromRGB(230, 248, 255), Thickness = 1.5, Transparency = 0.2 }),
			new("Frame", { Position = UDim2.fromScale(0.2, 0.18), Size = UDim2.fromScale(0.28, 0.28), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.25, BorderSizePixel = 0 }, { UIKit.round() }),
		})
	end
	local function updateAir()
		local air, max = player:GetAttribute("Air"), player:GetAttribute("MaxAir")
		if not air or not max or max <= 0 then
			airRow.Visible = false
			return
		end
		airRow.Visible = air < max - 0.05
		local filled = air / max * #bubbles
		for i, b in bubbles do
			local amount = math.clamp(filled - (#bubbles - i), 0, 1)
			b.BackgroundTransparency = 0.15 + (1 - amount) * 0.85
			b.Size = UDim2.fromOffset(10 + 10 * amount, 10 + 10 * amount)
			b.BackgroundColor3 = if air <= 0 then C.bad else rgbAir
		end
	end
	player:GetAttributeChangedSignal("Air"):Connect(updateAir)
	player:GetAttributeChangedSignal("MaxAir"):Connect(updateAir)

	-- Pickup prompt, floating over the item in the world: its name, then "[F] Pickup"
	promptFrame = new("BillboardGui", { Parent = player:WaitForChild("PlayerGui"), Name = "TideboundPickup", Size = UDim2.fromOffset(280, 76), StudsOffsetWorldSpace = Vector3.new(0, 2.5, 0), AlwaysOnTop = true, Active = true, LightInfluence = 0, ResetOnSpawn = false, Enabled = false })
	promptName = UIKit.hudText({ Parent = promptFrame, Size = UDim2.new(1, 0, 0, 30), Text = "", TextScaled = false, TextSize = 26 })
	promptKeys = new("Frame", { Parent = promptFrame, Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 0, 38), BackgroundTransparency = 1 }, {
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
	buildName = label({ Parent = nameBox, Size = UDim2.new(1, -16, 1, -6), Position = UDim2.fromOffset(8, 3), Text = "", TextScaled = false, TextSize = 24 })
	UIKit.closeButton({ Parent = buildBar, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 40), Size = UDim2.fromOffset(56, 24), TextScaled = false, TextSize = 20 }, function()
		callbacks.onCancelBuild()
	end)
	label({ Parent = buildBar, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 68), Size = UDim2.fromOffset(440, 18), Text = "Click to place  ·  R rotate  ·  [ ] floor size  ·  X cancel", TextScaled = false, TextSize = 16 })

	makePanel("quests", "Quest Board")
	makePanel("shop", "Trader")
	makePanel("chest", "Storage Chest")
	-- Walk away from an open chest and it closes.
	RunService.Heartbeat:Connect(function()
		if openPanel == "chest" then
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local m = chest.model
			if not m or not m.Parent or not root or (m:GetPivot().Position - root.Position).Magnitude > 16 then
				chest.model = nil
				UI.closePanels()
			end
		end
	end)

	player:GetAttributeChangedSignal("DataLoaded"):Connect(function()
		lastLevel, lastXp = player:GetAttribute("Level") or 1, player:GetAttribute("XP") or 0
	end)
	for _, attr in { "Hunger", "BagUsed", "BagSize", "Level", "XP" } do
		player:GetAttributeChangedSignal(attr):Connect(updateStats)
	end
	player:GetAttributeChangedSignal("Level"):Connect(rebuildHotbar)
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
