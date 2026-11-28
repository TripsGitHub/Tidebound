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
local promptFrame: Frame
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

-- Slot -> item for the bar. Your slots stay where you put them (see Favourites.lua):
-- drag from the bag or between slots to arrange them; new tools, food, buildables and
-- crates drop into the first empty slot and stay there.
function UI.hotbarIds(): { [number]: string }
	local size = UI.hotbarSize()
	local ids = {}
	for id, count in state.items do
		local kind = Items[id] and Items[id].kind
		if count > 0 and (kind == "tool" or kind == "food" or kind == "placeable" or kind == "crate") then
			table.insert(ids, id)
		end
	end
	table.sort(ids, function(a, b)
		return Items[a].order < Items[b].order
	end)
	return Favourites.layout(size, function(id)
		return (state.items[id] or 0) > 0 and Items[id] ~= nil
	end, ids)
end

-- Dragging an item onto the bar ---------------------------------------------------
local slotButtons: { [number]: GuiObject } = {}
local drag: { id: string, start: Vector2, ghost: GuiObject?, from: number? }? = nil
local dragEndedAt = 0

function UI.hotbarSlotAt(pos: Vector2): number?
	for i, b in slotButtons do
		if b.Parent then
			local p, sz = b.AbsolutePosition, b.AbsoluteSize
			if pos.X >= p.X - 4 and pos.X <= p.X + sz.X + 4 and pos.Y >= p.Y - 10 and pos.Y <= p.Y + sz.Y + 4 then
				return i
			end
		end
	end
	return nil
end

-- Start dragging an item (from a bag card or a slot); it follows the mouse once it
-- has moved a little, and lands in whichever slot you let go over.
local function mouseAt(): Vector2
	return UserInputService:GetMouseLocation() - game:GetService("GuiService"):GetGuiInset()
end
function UI.beginDrag(id: string, _start: Vector2?, from: number?)
	drag = { id = id, start = mouseAt(), from = from }
end

function UI.justDragged(): boolean
	return os.clock() - dragEndedAt < 0.15
end

-- The dragged item lives on its own unscaled layer, so it sits exactly under the
-- pointer whatever the HUD's scale is.
local dragLayer: ScreenGui? = nil
UserInputService.InputChanged:Connect(function(input)
	local d = drag
	if not d or input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	local pos = mouseAt()
	if not d.ghost and (pos - d.start).Magnitude > 8 then
		if not dragLayer then
			dragLayer = new("ScreenGui", { Name = "HotbarDrag", ResetOnSpawn = false, DisplayOrder = 60, IgnoreGuiInset = false, Parent = player:WaitForChild("PlayerGui") })
		end
		local px = 62
		local slot1 = slotButtons[1]
		if slot1 and slot1.Parent then
			px = slot1.AbsoluteSize.X
		end
		local g = new("Frame", { Parent = dragLayer, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(px, px), BackgroundColor3 = C.panel, BackgroundTransparency = 0.2, ZIndex = 50 }, { UIKit.round(), stroke(C.star, 3) })
		local vf = Icons.make(d.id, g, UDim2.fromScale(0.82, 0.82), UDim2.fromScale(0.5, 0.5))
		vf.AnchorPoint = Vector2.new(0.5, 0.5)
		vf.ZIndex = 51
		Icons.wobble(vf)
		d.ghost = g
	end
	if d.ghost then
		d.ghost.Position = UDim2.fromOffset(pos.X, pos.Y)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	local d = drag
	if not d or input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	drag = nil
	if d.ghost then
		d.ghost:Destroy()
		dragEndedAt = os.clock()
		local at = UI.hotbarSlotAt(mouseAt())
		if at then
			Favourites.place(d.id, at)
		elseif d.from then
			-- Dragged off the bar: take it out of its slot.
			Favourites.remove(d.id)
		end
	end
end)

-- The selected slot's background shows what the item is made of, always inside the
-- round slot: wood smoulders with a slow ember swirl, stone turns a cool grey swirl,
-- metal has a turning sheen with a bright glint sweeping across, crystal a turning
-- prism of its colours with stars twinkling over it, and the glowing tiers pulse in
-- their own light on top.
local Tiers = require(Shared.Tiers)
local function spinGradient(g: UIGradient, period: number)
	g.Rotation = 0
	TweenService:Create(g, TweenInfo.new(period, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), { Rotation = 360 }):Play()
end
local function disc(parent: Instance, colour: Color3, alpha: number, z: number?): Frame
	return new("Frame", { Parent = parent, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), BackgroundColor3 = colour, BackgroundTransparency = alpha, BorderSizePixel = 0, ZIndex = z or 0 }, { UIKit.round() })
end
local function tierFx(slot: GuiObject, id: string)
	local tier = Tiers.split(id)
	local fx = new("Frame", { Parent = slot, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.92, 0.92), BackgroundTransparency = 1, ZIndex = 0 })
	if not tier then
		local glow = disc(fx, C.star, 0.75)
		TweenService:Create(glow, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { BackgroundTransparency = 0.92 }):Play()
		return
	end
	local white = Color3.new(1, 1, 1)
	local light = tier.plate:Lerp(white, 0.45)
	local dark = tier.plate:Lerp(Color3.new(0, 0, 0), 0.35)
	-- A turning two-colour swirl filling the slot.
	local swirl = disc(fx, white, 0.15)
	local sg = new("UIGradient", { Parent = swirl })
	if tier.style == "wood" then
		sg.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, dark), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 150, 60)), ColorSequenceKeypoint.new(1, dark) })
		spinGradient(sg, 4)
		local ember = disc(fx, Color3.fromRGB(255, 120, 40), 0.6)
		TweenService:Create(ember, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { BackgroundTransparency = 0.95 }):Play()
	elseif tier.style == "stone" then
		sg.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, dark), ColorSequenceKeypoint.new(0.5, light), ColorSequenceKeypoint.new(1, dark) })
		spinGradient(sg, 6)
	elseif tier.style == "metal" then
		sg.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, dark), ColorSequenceKeypoint.new(0.3, tier.plate), ColorSequenceKeypoint.new(0.5, white), ColorSequenceKeypoint.new(0.7, tier.plate), ColorSequenceKeypoint.new(1, dark) })
		spinGradient(sg, 3)
		-- A sharp glint sweeping across every second or so.
		local glint = disc(fx, white, 0, 0)
		local gg = new("UIGradient", {
			Parent = glint,
			Rotation = 30,
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.4, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(0.6, 1), NumberSequenceKeypoint.new(1, 1) }),
			Offset = Vector2.new(-1, 0),
		})
		TweenService:Create(gg, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, -1, false, 0.6), { Offset = Vector2.new(1, 0) }):Play()
	else
		sg.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, tier.plate), ColorSequenceKeypoint.new(0.33, tier.accent), ColorSequenceKeypoint.new(0.66, light), ColorSequenceKeypoint.new(1, tier.plate) })
		spinGradient(sg, 2.5)
		for k = 1, 6 do
			local star = label({ Parent = fx, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.2 + ((k * 0.37) % 0.6), 0.2 + ((k * 0.61) % 0.6)), Size = UDim2.fromOffset(18, 18), Text = "✦", TextColor3 = white, TextScaled = true, TextTransparency = 1, TextStrokeColor3 = tier.accent, TextStrokeTransparency = 1, ZIndex = 0 })
			local s0 = new("UIScale", { Parent = star, Scale = 0.4 })
			local info = TweenInfo.new(0.45 + (k % 3) * 0.15, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true, k * 0.13)
			TweenService:Create(star, info, { TextTransparency = 0, TextStrokeTransparency = 0.3, Rotation = 90 }):Play()
			TweenService:Create(s0, info, { Scale = 1.2 }):Play()
		end
	end
	if tier.glow then
		local halo = disc(fx, tier.accent, 0.55)
		TweenService:Create(halo, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { BackgroundTransparency = 0.95 }):Play()
	end
	-- A dark ring inside the rim so the colour reads as a gem set in the slot.
	new("UIStroke", { Parent = swirl, Color = dark, Thickness = 2, Transparency = 0.2 })
end

local lastSelected: { [string]: boolean } = {}
local SLOT = 66 -- hotbar slot size in pixels

local spinSince: { [string]: number } = {} -- when each held item started turning
local function rebuildHotbar()
	for _, c in hotbar:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local ids = UI.hotbarIds()
	table.clear(slotButtons)
	for i = 1, UI.hotbarSize() do
		local id = ids[i]
		local item = id and Items[id]
		local worn = item ~= nil and item.kind == "armour" and state.armour[item.slot] == id
		local selected = id ~= nil and (id == state.equipped or worn)
		-- Round flat tan slot; the item's name sits above it, the stack count inside
		-- at the bottom. All your slots always show, like Island Tribes; the held
		-- item's slot gets a gold rim.
		local holder = new("Frame", { Parent = hotbar, LayoutOrder = i, Size = UDim2.fromOffset(SLOT + 8, SLOT + 22), BackgroundTransparency = 1 })
		local size = SLOT
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
		slotButtons[i] = slot
		if id then
			local icon = Icons.make(id, slot, UDim2.fromScale(0.82, 0.82), UDim2.fromScale(0.09, 0.05))
			if selected then
				-- The held item turns slowly in its slot, rocking as it goes, over a soft
				-- warm glow that breathes in and out.
				spinSince[id] = spinSince[id] or os.clock()
				Icons.wobble(icon, spinSince[id])
				tierFx(slot, id)
			end
			-- Long names shrink to fit the slot so neighbours never overlap.
			local name = label({ Parent = holder, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.new(1, -2, 0, 16), ZIndex = if selected then 3 else 1, Text = Items[id].name, TextScaled = true, TextStrokeTransparency = 0.4, TextColor3 = if selected then C.star else C.text })
			new("UITextSizeConstraint", { Parent = name, MaxTextSize = 15 })
			if (state.items[id] or 0) > 1 then
				label({ Parent = slot, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -1), Size = UDim2.fromOffset(44, 16), Text = tostring(state.items[id]), TextScaled = false, TextSize = 15, ZIndex = 3 })
			end
			if Favourites.has(id) then
				label({ Parent = slot, Position = UDim2.fromOffset(2, 0), Size = UDim2.fromOffset(14, 14), Text = "★", TextColor3 = C.star, TextScaled = false, TextSize = 13, ZIndex = 3 })
			end
			slot.MouseButton1Click:Connect(function()
				if not UI.justDragged() then
					callbacks.onSlot(i)
				end
			end)
			slot.MouseButton1Down:Connect(function(x, y)
				UI.beginDrag(id, Vector2.new(x, y), i)
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
	-- Forget the turn of anything no longer held, so picking it again starts fresh.
	for id in spinSince do
		local item = Items[id]
		if not (id == state.equipped or (item and item.kind == "armour" and state.armour[item.slot] == id)) then
			spinSince[id] = nil
		end
	end
	lastSelected = {}
	for _, id in pairs(ids) do
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
	-- Same look as the XP and target bars: square-ish corners, the rim outline, the
	-- panel colour behind, value centred.
	label({ Parent = row, Size = UDim2.new(0, 70, 1, 0), Text = name, TextXAlignment = Enum.TextXAlignment.Left, TextScaled = false, TextSize = 17 })
	local back = new("Frame", { Parent = row, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 72, 0.5, 0), Size = UDim2.new(1, -72, 0, 20), BackgroundColor3 = C.cardDark, BackgroundTransparency = UIKit.PANEL_ALPHA, BorderSizePixel = 0 }, { corner(6), stroke(C.rim, 2) })
	local fill = new("Frame", { Parent = back, Size = UDim2.fromScale(1, 1), BackgroundColor3 = color, BorderSizePixel = 0 }, { corner(6) })
	local text = label({ Parent = back, Size = UDim2.fromScale(1, 1), Text = "", TextScaled = false, TextSize = 15, ZIndex = 2 })
	bars[name] = { fill = fill, text = text }
end

local function setBar(name: string, value: number, max: number, textOverride: string?)
	local b = bars[name]
	if not b then
		return
	end
	local ratio = if max > 0 then math.clamp(value / max, 0, 1) else 0
	UIKit.slideBar(b.fill, ratio)
	b.text.Text = textOverride or tostring(math.ceil(value))
end

-- Food heals slowly (Survival.lua): the health still to come shows as a glowing green
-- stretch past the end of the health bar, with "+N" and a little heart that beats.
local pending: Frame? = nil
local pendingText: TextLabel? = nil
local function healthPending()
	local b = bars.Health
	if not b then
		return
	end
	if not pending then
		local back = b.fill.Parent :: Frame
		pending = new("Frame", { Parent = back, Name = "Healing", Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(150, 236, 120), BackgroundTransparency = 0.35, BorderSizePixel = 0, ZIndex = b.fill.ZIndex }, { corner(6) })
		TweenService:Create(pending :: Frame, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { BackgroundTransparency = 0.7 }):Play()
		pendingText = label({ Parent = back, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(56, 18), Text = "", TextXAlignment = Enum.TextXAlignment.Right, TextScaled = false, TextSize = 14, TextColor3 = Color3.fromRGB(200, 255, 170), TextStrokeTransparency = 0.4, ZIndex = 10 })
	end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local pool = player:GetAttribute("HealPool") or 0
	local p = pending :: Frame
	if not humanoid or pool <= 0.05 then
		p.Visible = false
		;(pendingText :: TextLabel).Text = ""
		return
	end
	local max = math.max(1, humanoid.MaxHealth)
	local from = math.clamp(humanoid.Health / max, 0, 1)
	local to = math.clamp((humanoid.Health + pool) / max, 0, 1)
	p.Visible = true
	p.Position = UDim2.fromScale(from, 0)
	p.Size = UDim2.fromScale(to - from, 1)
	;(pendingText :: TextLabel).Text = "♥ +" .. math.ceil(pool)
end

local function hookCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local function update()
		setBar("Health", humanoid.Health, humanoid.MaxHealth)
		healthPending()
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
			-- XP gains show as the green orb over you (Markers.lua), and what a level
			-- unlocks comes as notifications from the server: no popups here.
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

-- Notices stack upward beside your character: the newest slides in at the bottom
-- and shoves the older ones up out of its way (with a little overshoot), and each
-- one leaves by drifting up and fading out, then the stack settles down into the gap.
local NOTICE_H, NOTICE_GAP, NOTICE_MAX = 40, 6, 5
local notices: { Frame } = {}

local function restack()
	for i, holder in notices do
		local y = -(i - 1) * (NOTICE_H + NOTICE_GAP)
		TweenService:Create(holder, TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, 0), { Position = UDim2.new(0, 0, 1, y) }):Play()
	end
end

local function dismiss(holder: Frame)
	if holder:GetAttribute("Leaving") then
		return
	end
	holder:SetAttribute("Leaving", true)
	local i = table.find(notices, holder)
	if i then
		table.remove(notices, i)
	end
	local fade = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(holder, fade, { Position = holder.Position + UDim2.fromOffset(0, -34) }):Play()
	for _, d in holder:GetDescendants() do
		if d:IsA("Frame") and d.BackgroundTransparency < 1 then
			TweenService:Create(d, fade, { BackgroundTransparency = 1 }):Play()
		elseif d:IsA("TextLabel") then
			TweenService:Create(d, fade, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		elseif d:IsA("UIStroke") then
			TweenService:Create(d, fade, { Transparency = 1 }):Play()
		elseif d:IsA("ViewportFrame") then
			TweenService:Create(d, fade, { ImageTransparency = 1, BackgroundTransparency = 1 }):Play()
		end
	end
	restack()
	task.delay(0.5, function()
		holder:Destroy()
	end)
end

function UI.notify(text: string, style: string?, iconItem: string?)
	-- A small tan pill: a darker inner box with bold white words, and the item it's
	-- about (or what you're holding) as an icon on the right. The same message again
	-- just keeps the one already showing up for longer, with a little bump.
	for _, holder in notices do
		if holder:GetAttribute("Text") == text then
			holder:SetAttribute("Born", os.clock())
			local bump = holder:FindFirstChildWhichIsA("UIScale", true)
			if bump then
				bump.Scale = 1.12
				TweenService:Create(bump, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			end
			return
		end
	end
	local holder = new("Frame", { Parent = noticeList, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, -24, 1, 18), Size = UDim2.fromOffset(0, NOTICE_H), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1 })
	holder:SetAttribute("Text", text)
	holder:SetAttribute("Born", os.clock())
	local pill = new("Frame", { Parent = holder, Size = UDim2.fromOffset(0, NOTICE_H), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = C.panel, BackgroundTransparency = 0.05 }, {
		new("UICorner", { CornerRadius = UDim.new(0, 8) }),
		new("UIStroke", { Color = C.wood, Thickness = 2, Transparency = 0.1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		new("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }),
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6) }),
	})
	local inner = new("Frame", { Parent = pill, LayoutOrder = 1, Size = UDim2.fromOffset(0, 32), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = if style == "good" then Color3.fromRGB(92, 120, 70) elseif style == "warn" then Color3.fromRGB(140, 78, 56) else C.cardDark }, {
		new("UICorner", { CornerRadius = UDim.new(0, 6) }),
		new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
	})
	label({ Parent = inner, Size = UDim2.fromOffset(0, 32), AutomaticSize = Enum.AutomaticSize.X, Text = text, TextScaled = false, TextSize = 21, Font = Enum.Font.BuilderSansBold, TextColor3 = if style == "good" then Color3.fromRGB(230, 255, 210) else C.text })
	local icon = iconItem or state.equipped
	if icon and Items[icon] then
		local iconHolder = new("Frame", { Parent = pill, LayoutOrder = 2, Size = UDim2.fromOffset(32, 32), BackgroundTransparency = 1 })
		Icons.make(icon, iconHolder, UDim2.fromScale(1, 1))
	end
	local scale = new("UIScale", { Parent = pill, Scale = 0.7 })
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	table.insert(notices, 1, holder)
	while #notices > NOTICE_MAX do
		dismiss(notices[#notices])
	end
	restack()
	task.spawn(function()
		while holder.Parent and not holder:GetAttribute("Leaving") and os.clock() - (holder:GetAttribute("Born") :: number) < 3 do
			task.wait(0.2)
		end
		if holder.Parent then
			dismiss(holder)
		end
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

-- Eating: the healing itself shows as the green heart badge over you (Markers.lua),
-- the same style as the badges over nameplates, so nothing big in the middle here.
function UI.heart(_amount: number) end

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
	UIKit.slideBar(targetFill, hp / maxHp)
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
	if not target then
		-- Nothing pointed at: offer the closest drop in reach.
		local near = Hover.nearestDrop()
		if near then
			local n, ok = Hover.dropInfo(near)
			target, name, inRange = near, n, ok
		end
	end
	if target then
		promptFrame.Visible = true
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
		promptFrame.Visible = false
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
	for i, q in ipairs(QuestList) do
		local row = UIKit.block({ Parent = list, LayoutOrder = i, Size = UDim2.new(1, -8, 0, 62) })
		local progress = questProgress[q.id] or 0
		local done, claimed = progress >= q.amount, questClaimed[q.id]
		label({ Parent = row, Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -100, 0, 24), Text = q.title, TextXAlignment = Enum.TextXAlignment.Left, TextScaled = false, TextSize = 21 })
		label({ Parent = row, Position = UDim2.fromOffset(10, 32), Size = UDim2.new(1, -100, 0, 20), TextScaled = false, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, Text = q.text .. "  (" .. progress .. "/" .. q.amount .. ")  ·  " .. q.reward .. " Shells, " .. (q.xp or 0) .. " XP" })
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

-- The wandering merchant: what they'll make this stop. You bring the materials.
local function rebuildMerchant()
	local list = panelLists.merchant
	clear(list)
	local place = workspace:GetAttribute("MerchantPlace") or "?"
	local untilPhase = workspace:GetAttribute("MerchantUntil") or "later"
	label({ Parent = list, LayoutOrder = 0, Size = UDim2.new(1, -8, 0, 36), Text = "On " .. place .. " until " .. untilPhase .. ". Bring the materials and I'll make it.", TextWrapped = true, TextScaled = false, TextSize = 15 })
	local level = player:GetAttribute("Level") or 1
	local i = 0
	for id in string.gmatch(workspace:GetAttribute("MerchantStock") or "", "[^,]+") do
		local recipe
		for _, rc in Recipes do
			if rc.id == id then
				recipe = rc
				break
			end
		end
		if recipe and Items[id] then
			i += 1
			local row = UIKit.block({ Parent = list, LayoutOrder = i, Size = UDim2.new(1, -8, 0, 92) })
			local box = UIKit.block({ Parent = row, Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(52, 52), BackgroundColor3 = C.cardDark })
			Icons.make(id, box, UDim2.fromScale(0.9, 0.9), UDim2.fromScale(0.05, 0.05))
			label({ Parent = row, Position = UDim2.fromOffset(64, 4), Size = UDim2.new(1, -150, 0, 22), Text = Items[id].name, TextXAlignment = Enum.TextXAlignment.Left, TextScaled = false, TextSize = 19 })
			local costs = new("Frame", { Parent = row, Position = UDim2.fromOffset(64, 28), Size = UDim2.new(1, -150, 0, 60), BackgroundTransparency = 1 }, {
				new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
			})
			local can = level >= recipe.level
			for cid, amount in recipe.cost do
				local have = state.items[cid] or 0
				if have < amount then
					can = false
				end
				local cell = new("Frame", { Parent = costs, Size = UDim2.fromOffset(40, 58), BackgroundTransparency = 1 })
				Icons.make(cid, cell, UDim2.fromOffset(34, 34), UDim2.fromOffset(3, 2))
				label({ Parent = cell, Position = UDim2.fromOffset(0, 38), Size = UDim2.new(1, 0, 0, 16), Text = have .. "/" .. amount, TextScaled = false, TextSize = 13, TextColor3 = if have >= amount then C.good else C.bad })
			end
			button({ Parent = row, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(74, 30), BackgroundColor3 = if can then C.good else C.cardDark, Text = if level < recipe.level then "Lv " .. recipe.level else "Make", TextScaled = false, TextSize = 18 }, function()
				callbacks.onCraft(id)
			end)
		end
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

local rebuilders = { quests = rebuildQuests, shop = rebuildShop, chest = rebuildChest, merchant = rebuildMerchant }

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

-- Armour readout above the stats: how much of a hit your worn armour blocks from
-- beasts and from other players (the same sums the server uses), with a toast when
-- it changes, like "+8% vs mobs".
local armourBadges: { mob: TextLabel?, player: TextLabel? } = {}
local armourRowRef: Frame? = nil
local lastDefense: { mob: number, player: number }? = nil
local function defenseFor(vs: string): number
	local total = 0
	for _, id in state.armour or {} do
		local item = Items[id]
		if item then
			local mult = if vs == "mob" then item.vsMob elseif vs == "player" then item.vsPlayer else 1
			total += (item.defense or 0) * (mult or 1)
		end
	end
	return math.min(total, 0.9)
end
local function updateArmour()
	local mob, plr = defenseFor("mob"), defenseFor("player")
	if armourBadges.mob then
		armourBadges.mob.Text = math.floor(mob * 100 + 0.5) .. "%"
		armourBadges.player.Text = math.floor(plr * 100 + 0.5) .. "%"
	end
	-- Only worth showing once you're wearing something.
	if armourRowRef then
		armourRowRef.Visible = mob > 0 or plr > 0
	end
	if lastDefense then
		local dm = math.floor((mob - lastDefense.mob) * 100 + 0.5)
		local dp = math.floor((plr - lastDefense.player) * 100 + 0.5)
		if dm ~= 0 or dp ~= 0 then
			local function sign(n)
				return (if n > 0 then "+" else "") .. n .. "%"
			end
			UI.notify(sign(dm) .. " vs mobs  ·  " .. sign(dp) .. " vs players", if dm + dp >= 0 then "good" else "warn")
		end
	end
	lastDefense = { mob = mob, player = plr }
end

function UI.setInventory(items, equipped, armour, bagSize)
	state.items, state.equipped, state.armour, state.bagSize = items, equipped, armour, bagSize
	rebuildHotbar()
	updateArmour()
	refreshOpen()
end

function UI.setQuests(progress, claimed, path)
	questProgress, questClaimed = progress, claimed
	refreshOpen()
	if path then
		require(script.Parent.Tutorial).setPath(path)
	end
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
	hotbar = new("Frame", { Parent = gui, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.fromOffset(8 * (SLOT + 12), SLOT + 22), BackgroundTransparency = 1 }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Bottom, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	-- Stats (bottom right)
	local statsPanel = UIKit.panel({ Parent = gui, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -10, 1, -10), Size = UDim2.fromOffset(268, 112) })
	local stats = new("Frame", { Parent = statsPanel, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
	new("UIPadding", { Parent = stats, PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10) })
	new("UIListLayout", { Parent = stats, Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center })
	statBar(stats, 1, "Health", C.health)
	statBar(stats, 2, "Bag", C.bag)
	statBar(stats, 3, "Hunger", C.hunger)

	-- Air: a row of bubbles above the stats that only shows under water (or while
	-- it refills). Each bubble pops as your air runs down.
	-- Armour badges just above the stats: a shield with a paw (vs mobs) and a shield
	-- with a sword (vs players), each with the % of a hit it blocks.
	local armourRow = new("Frame", { Parent = gui, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -10, 1, -128), Size = UDim2.fromOffset(268, 28), BackgroundTransparency = 1 }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	armourRowRef = armourRow
	armourRow.Visible = false
	for i, spec in { { "mob", "Mobs", Color3.fromRGB(120, 170, 90) }, { "player", "Players", Color3.fromRGB(200, 110, 90) } } do
		local pill = UIKit.panel({ Parent = armourRow, LayoutOrder = i, Size = UDim2.fromOffset(128, 28) })
		local shield = new("Frame", { Parent = pill, Position = UDim2.fromOffset(5, 4), Size = UDim2.fromOffset(18, 20), BackgroundColor3 = spec[3] }, {
			new("UICorner", { CornerRadius = UDim.new(0.45, 0) }),
			new("UIStroke", { Color = C.wood, Thickness = 1.5 }),
		})
		new("Frame", { Parent = shield, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(3, 12), BackgroundColor3 = C.rim, BorderSizePixel = 0 })
		label({ Parent = pill, Position = UDim2.fromOffset(28, 0), Size = UDim2.new(0, 58, 1, 0), Text = "vs " .. spec[2], TextXAlignment = Enum.TextXAlignment.Left, TextScaled = false, TextSize = 13 })
		armourBadges[spec[1]] = label({ Parent = pill, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -7, 0, 0), Size = UDim2.new(0, 40, 1, 0), Text = "0%", TextXAlignment = Enum.TextXAlignment.Right, TextScaled = false, TextSize = 16, TextColor3 = C.gold })
	end

	local airRow = new("Frame", { Parent = gui, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -10, 1, -160), Size = UDim2.fromOffset(268, 26), BackgroundTransparency = 1, Visible = false }, {
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

	-- Pickup prompt on screen, just above the hotbar: the item's name, then "[F] Pickup"
	-- (and "[E] Eat" for food). Shows for whatever you point at, or the closest drop.
	promptFrame = new("Frame", { Parent = gui, Name = "PickupPrompt", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -128), Size = UDim2.fromOffset(300, 76), BackgroundTransparency = 1, Visible = false })
	promptName = UIKit.hudText({ Parent = promptFrame, Size = UDim2.new(1, 0, 0, 30), Text = "", TextScaled = false, TextSize = 26 })
	promptKeys = new("Frame", { Parent = promptFrame, Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 0, 38), BackgroundTransparency = 1 }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	-- Floating "+XP" / "+Hunger" popups
	popupLayer = new("Frame", { Parent = gui, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })

	-- Notices (top centre, below the XP bar)
	-- Notices float just right of your character (screen centre).
	noticeList = new("Frame", { Parent = gui, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0.5, 70, 0.5, 60), Size = UDim2.fromOffset(460, 280), BackgroundTransparency = 1 })

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
	label({ Parent = buildBar, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 68), Size = UDim2.fromOffset(440, 18), Text = "Click to place  ·  R rotate  ·  X cancel", TextScaled = false, TextSize = 16 })

	makePanel("quests", "Quest Board")
	makePanel("shop", "Trader")
	makePanel("merchant", "Wandering Merchant")
	panels.merchant.Size = UDim2.fromOffset(440, 440)
	-- Walk away from the merchant and the panel closes.
	RunService.Heartbeat:Connect(function()
		if openPanel == "merchant" then
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local at = workspace:GetAttribute("MerchantAt")
			if not root or typeof(at) ~= "Vector3" or (at - root.Position).Magnitude > 22 then
				UI.closePanels()
			end
		end
	end)
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
	player:GetAttributeChangedSignal("HealPool"):Connect(healthPending)
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
