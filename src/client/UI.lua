-- All the on-screen UI, built in code: health/hunger bars, level and Shells,
-- the hotbar, and the Crafting / Quests / Trader panels.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Recipes = require(Shared.Recipes)
local QuestList = require(Shared.Quests)
local ShopList = require(Shared.Shop)

local player = Players.LocalPlayer
local UI = {}

-- Style ---------------------------------------------------------------------
local FONT = Enum.Font.FredokaOne
local PANEL = Color3.fromRGB(58, 44, 32)
local PANEL_LIGHT = Color3.fromRGB(86, 66, 48)
local CREAM = Color3.fromRGB(250, 238, 210)
local GOOD = Color3.fromRGB(120, 200, 90)
local BAD = Color3.fromRGB(220, 90, 80)
local GOLD = Color3.fromRGB(245, 200, 90)

local function new(className: string, props, children: { Instance }?): any
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

local function corner(r: number?)
	return new("UICorner", { CornerRadius = UDim.new(0, r or 10) })
end

local function stroke(color: Color3?, thickness: number?)
	return new("UIStroke", { Color = color or Color3.fromRGB(30, 22, 16), Thickness = thickness or 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

local function label(props)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Font = props.Font or FONT
	props.TextColor3 = props.TextColor3 or CREAM
	props.TextScaled = if props.TextScaled == nil then true else props.TextScaled
	return new("TextLabel", props)
end

local function button(props, onClick: () -> ())
	props.Font = props.Font or FONT
	props.TextColor3 = props.TextColor3 or CREAM
	props.TextScaled = if props.TextScaled == nil then true else props.TextScaled
	props.AutoButtonColor = true
	local b = new("TextButton", props, { corner(8), stroke() })
	b.MouseButton1Click:Connect(onClick)
	return b
end

-- State ---------------------------------------------------------------------
local items: { [string]: number } = {}
local equipped: string? = nil
local questProgress: { [string]: number } = {}
local questClaimed: { [string]: boolean } = {}
local callbacks: any = {}

local gui: ScreenGui
local hotbarFrame: Frame
local toastFrame: Frame
local panels: { [string]: Frame } = {}
local panelLists: { [string]: ScrollingFrame } = {}
local openPanel: string? = nil
local healthFill: Frame
local hungerFill: Frame
local healthText: TextLabel
local hungerText: TextLabel
local levelText: TextLabel
local xpFill: Frame
local shellsText: TextLabel

-- Bars ----------------------------------------------------------------------
local function bar(parent: Instance, y: number, color: Color3, icon: string): (Frame, TextLabel)
	local holder = new("Frame", {
		Parent = parent,
		Size = UDim2.new(1, 0, 0, 26),
		Position = UDim2.fromOffset(0, y),
		BackgroundColor3 = PANEL,
	}, { corner(13), stroke() })
	local fill = new("Frame", { Parent = holder, Size = UDim2.fromScale(1, 1), BackgroundColor3 = color }, { corner(13) })
	local text = label({ Parent = holder, Size = UDim2.new(1, -16, 1, -6), Position = UDim2.fromOffset(8, 3), Text = icon, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 2 })
	return fill, text
end

local function setBar(fill: Frame, text: TextLabel, name: string, value: number, max: number)
	local ratio = math.clamp(value / max, 0, 1)
	TweenService:Create(fill, TweenInfo.new(0.2), { Size = UDim2.fromScale(ratio, 1) }):Play()
	text.Text = name .. "  " .. math.ceil(value)
end

local function hookCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local function update()
		setBar(healthFill, healthText, "Health", humanoid.Health, humanoid.MaxHealth)
	end
	humanoid.HealthChanged:Connect(update)
	update()
end

local function updateHunger()
	setBar(hungerFill, hungerText, "Hunger", player:GetAttribute("Hunger") or Config.MaxHunger, Config.MaxHunger)
end

local function updateLevel()
	local level = player:GetAttribute("Level") or 1
	local xp = player:GetAttribute("XP") or 0
	levelText.Text = "Lv " .. level
	local need = Config.XpForLevel(level)
	local ratio = if level >= Config.MaxLevel then 1 else math.clamp(xp / need, 0, 1)
	TweenService:Create(xpFill, TweenInfo.new(0.2), { Size = UDim2.fromScale(ratio, 1) }):Play()
	shellsText.Text = "Shells: " .. (player:GetAttribute("Shells") or 0)
end

-- Hotbar --------------------------------------------------------------------
function UI.hotbarIds(): { string }
	local ids = {}
	for id, count in items do
		if count > 0 and Items[id] and Items[id].kind ~= "resource" then
			table.insert(ids, id)
		end
	end
	table.sort(ids, function(a, b)
		return Items[a].order < Items[b].order
	end)
	local limited = {}
	for i = 1, math.min(9, #ids) do
		limited[i] = ids[i]
	end
	return limited
end

local function rebuildHotbar()
	for _, child in hotbarFrame:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for i, id in UI.hotbarIds() do
		local isEquipped = id == equipped
		local slot = button({
			Parent = hotbarFrame,
			LayoutOrder = i,
			Size = UDim2.fromOffset(72, 72),
			BackgroundColor3 = if isEquipped then PANEL_LIGHT else PANEL,
			Text = "",
		}, function()
			callbacks.onSlot(i)
		end)
		if isEquipped then
			slot:FindFirstChildOfClass("UIStroke").Color = GOLD
			slot:FindFirstChildOfClass("UIStroke").Thickness = 3
		end
		label({ Parent = slot, Size = UDim2.fromOffset(18, 18), Position = UDim2.fromOffset(5, 3), Text = tostring(i), TextColor3 = GOLD })
		label({ Parent = slot, Size = UDim2.new(1, -8, 0, 34), Position = UDim2.fromOffset(4, 20), Text = Items[id].name, TextWrapped = true })
		if (items[id] or 0) > 1 then
			label({ Parent = slot, Size = UDim2.new(1, -8, 0, 16), Position = UDim2.new(0, 4, 1, -18), Text = "x" .. items[id], TextXAlignment = Enum.TextXAlignment.Right })
		end
	end
end

-- Panels --------------------------------------------------------------------
local function makePanel(name: string, title: string)
	local frame = new("Frame", {
		Parent = gui,
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(440, 420),
		BackgroundColor3 = PANEL,
		Visible = false,
	}, { corner(14), stroke(nil, 3) })
	label({ Parent = frame, Size = UDim2.new(1, -60, 0, 36), Position = UDim2.fromOffset(16, 10), Text = title, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = GOLD })
	button({ Parent = frame, Size = UDim2.fromOffset(34, 34), Position = UDim2.new(1, -44, 0, 10), BackgroundColor3 = BAD, Text = "X" }, function()
		UI.close()
	end)
	local list = new("ScrollingFrame", {
		Parent = frame,
		Size = UDim2.new(1, -24, 1, -64),
		Position = UDim2.fromOffset(12, 54),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	}, { new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
	panels[name] = frame
	panelLists[name] = list
end

local function clearList(list: ScrollingFrame)
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function row(list: ScrollingFrame, order: number, height: number): Frame
	return new("Frame", { Parent = list, LayoutOrder = order, Size = UDim2.new(1, -8, 0, height), BackgroundColor3 = PANEL_LIGHT }, { corner(10) })
end

local function costText(cost: { [string]: number }): (string, boolean)
	local parts = {}
	local enough = true
	for id, amount in cost do
		local have = items[id] or 0
		if have < amount then
			enough = false
		end
		table.insert(parts, have .. "/" .. amount .. " " .. Items[id].name)
	end
	table.sort(parts)
	return table.concat(parts, ",  "), enough
end

local function rebuildCrafting()
	local list = panelLists.crafting
	clearList(list)
	-- What you're carrying
	local resources = {}
	for id, count in items do
		if Items[id].kind == "resource" then
			table.insert(resources, Items[id].name .. " " .. count)
		end
	end
	table.sort(resources)
	local pack = row(list, 0, 44)
	label({ Parent = pack, Size = UDim2.new(1, -16, 1, -8), Position = UDim2.fromOffset(8, 4), TextScaled = false, TextSize = 16, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Text = "Pack: " .. (if #resources > 0 then table.concat(resources, ",  ") else "empty, go hit some trees!") })

	local level = player:GetAttribute("Level") or 1
	for i, recipe in Recipes do
		local r = row(list, i, 64)
		local locked = level < recipe.level
		local text, enough = costText(recipe.cost)
		label({ Parent = r, Size = UDim2.new(1, -130, 0, 26), Position = UDim2.fromOffset(10, 6), Text = Items[recipe.id].name, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = if locked then Color3.fromRGB(170, 160, 150) else CREAM })
		label({ Parent = r, Size = UDim2.new(1, -130, 0, 22), Position = UDim2.fromOffset(10, 34), TextScaled = false, TextSize = 15, Text = if locked then "Unlocks at level " .. recipe.level else text, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = if locked or not enough then Color3.fromRGB(220, 170, 150) else GOOD })
		button({ Parent = r, Size = UDim2.fromOffset(100, 40), Position = UDim2.new(1, -110, 0.5, -20), BackgroundColor3 = if not locked and enough then GOOD else Color3.fromRGB(110, 100, 90), Text = if locked then "Locked" else "Craft" }, function()
			callbacks.onCraft(recipe.id)
		end)
	end
end

local function rebuildQuests()
	local list = panelLists.quests
	clearList(list)
	for i, quest in QuestList do
		local r = row(list, i, 70)
		local progress = questProgress[quest.id] or 0
		local claimed = questClaimed[quest.id]
		local done = progress >= quest.amount
		label({ Parent = r, Size = UDim2.new(1, -130, 0, 26), Position = UDim2.fromOffset(10, 6), Text = quest.title, TextXAlignment = Enum.TextXAlignment.Left })
		label({ Parent = r, Size = UDim2.new(1, -130, 0, 22), Position = UDim2.fromOffset(10, 36), TextScaled = false, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, Text = quest.text .. "  (" .. progress .. "/" .. quest.amount .. ")  Reward: " .. quest.reward .. " Shells" })
		button({ Parent = r, Size = UDim2.fromOffset(100, 40), Position = UDim2.new(1, -110, 0.5, -20), BackgroundColor3 = if claimed then Color3.fromRGB(90, 80, 70) elseif done then GOLD else Color3.fromRGB(110, 100, 90), TextColor3 = if done and not claimed then PANEL else CREAM, Text = if claimed then "Done" elseif done then "Claim" else "In progress" }, function()
			if done and not claimed then
				callbacks.onClaim(quest.id)
			end
		end)
	end
end

local function rebuildShop()
	local list = panelLists.shop
	clearList(list)
	local shells = player:GetAttribute("Shells") or 0
	local header = row(list, 0, 36)
	label({ Parent = header, Size = UDim2.new(1, -16, 1, -8), Position = UDim2.fromOffset(8, 4), Text = "You have " .. shells .. " Shells", TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Left })
	for i, entry in ShopList do
		local r = row(list, i, 56)
		label({ Parent = r, Size = UDim2.new(1, -130, 0, 26), Position = UDim2.fromOffset(10, 14), Text = entry.amount .. " " .. Items[entry.item].name, TextXAlignment = Enum.TextXAlignment.Left })
		button({ Parent = r, Size = UDim2.fromOffset(110, 40), Position = UDim2.new(1, -120, 0.5, -20), BackgroundColor3 = if shells >= entry.price then GOLD else Color3.fromRGB(110, 100, 90), TextColor3 = PANEL, Text = entry.price .. " Shells" }, function()
			callbacks.onBuy(entry.id)
		end)
	end
end

local rebuilders = { crafting = rebuildCrafting, quests = rebuildQuests, shop = rebuildShop }

local function refreshOpen()
	if openPanel then
		rebuilders[openPanel]()
	end
end

function UI.open(name: string)
	UI.close()
	if panels[name] then
		openPanel = name
		rebuilders[name]()
		panels[name].Visible = true
	end
end

function UI.close()
	for _, p in panels do
		p.Visible = false
	end
	openPanel = nil
end

function UI.toggle(name: string)
	if openPanel == name then
		UI.close()
	else
		UI.open(name)
	end
end

-- Toasts --------------------------------------------------------------------
function UI.toast(text: string)
	local t = label({
		Parent = toastFrame,
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 0.15,
		BackgroundColor3 = PANEL,
		Text = "  " .. text .. "  ",
		TextScaled = false,
		TextSize = 20,
	})
	corner(10).Parent = t
	task.delay(3, function()
		local fade = TweenService:Create(t, TweenInfo.new(0.4), { TextTransparency = 1, BackgroundTransparency = 1 })
		fade:Play()
		fade.Completed:Wait()
		t:Destroy()
	end)
end

-- Public updates ------------------------------------------------------------
function UI.setInventory(newItems: { [string]: number }, newEquipped: string?)
	items = newItems
	equipped = newEquipped
	rebuildHotbar()
	refreshOpen()
end

function UI.setQuests(progress: { [string]: number }, claimed: { [string]: boolean })
	questProgress = progress
	questClaimed = claimed
	refreshOpen()
end

function UI.init(cb)
	callbacks = cb
	gui = new("ScreenGui", { Name = "TideboundUI", ResetOnSpawn = false, IgnoreGuiInset = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui") })

	-- Status (bottom left)
	local status = new("Frame", { Parent = gui, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 16, 1, -16), Size = UDim2.fromOffset(240, 128), BackgroundTransparency = 1 })
	local levelBadge = new("Frame", { Parent = status, Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = PANEL }, { corner(10), stroke() })
	levelText = label({ Parent = levelBadge, Size = UDim2.fromOffset(60, 26), Position = UDim2.fromOffset(8, 4), Text = "Lv 1", TextColor3 = GOLD })
	local xpHolder = new("Frame", { Parent = levelBadge, Size = UDim2.new(1, -84, 0, 10), Position = UDim2.fromOffset(74, 12), BackgroundColor3 = PANEL_LIGHT }, { corner(5) })
	xpFill = new("Frame", { Parent = xpHolder, Size = UDim2.fromScale(0, 1), BackgroundColor3 = GOLD }, { corner(5) })
	healthFill, healthText = bar(status, 42, Color3.fromRGB(205, 70, 70), "Health")
	hungerFill, hungerText = bar(status, 72, Color3.fromRGB(225, 150, 60), "Hunger")
	shellsText = label({ Parent = status, Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(4, 104), Text = "Shells: 0", TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Left })

	-- Hotbar (bottom middle)
	hotbarFrame = new("Frame", { Parent = gui, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16), Size = UDim2.fromOffset(9 * 78, 72), BackgroundTransparency = 1 }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	-- Craft button + controls hint (bottom right)
	button({ Parent = gui, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -60), Size = UDim2.fromOffset(130, 46), BackgroundColor3 = PANEL_LIGHT, Text = "Craft (C)" }, function()
		UI.toggle("crafting")
	end)
	label({ Parent = gui, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -16), Size = UDim2.fromOffset(330, 36), TextScaled = false, TextSize = 14, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Right, TextTransparency = 0.15, Text = "Click: use held item  |  1-9: pick item  |  C: craft  |  R: rotate build" })

	-- Toasts (top middle)
	toastFrame = new("Frame", { Parent = gui, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12), Size = UDim2.fromOffset(520, 200), BackgroundTransparency = 1 }, {
		new("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center }),
	})

	makePanel("crafting", "Crafting")
	makePanel("quests", "Quest Board")
	makePanel("shop", "Trader")

	player:GetAttributeChangedSignal("Hunger"):Connect(updateHunger)
	player:GetAttributeChangedSignal("Level"):Connect(function()
		updateLevel()
		refreshOpen()
	end)
	player:GetAttributeChangedSignal("XP"):Connect(updateLevel)
	player:GetAttributeChangedSignal("Shells"):Connect(function()
		updateLevel()
		refreshOpen()
	end)
	updateHunger()
	updateLevel()
	if player.Character then
		task.spawn(hookCharacter, player.Character)
	end
	player.CharacterAdded:Connect(hookCharacter)
end

return UI
