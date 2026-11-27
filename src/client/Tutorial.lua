-- The first few minutes: a short list of steps in the top-left that teaches the loop
-- (gather, craft, build, eat, quests). Each step ticks itself off when you do it. It
-- only shows for new players (level 5 or under when they join) and goes away when
-- it's done.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local UIKit = require(script.Parent.UIKit)

local player = Players.LocalPlayer
local Tutorial = {}

local C = UIKit.Colors

type Step = { text: string, done: (items: { [string]: number }, equipped: string?) -> boolean }

local flags: { [string]: boolean } = {}

local STEPS: { Step } = {
	{ text = "Hit a tree with your Rock (click) to get logs", done = function(items)
		return (items.log or 0) >= 1
	end },
	{ text = "Hit a boulder to get Small Rocks", done = function(items)
		return (items.stone or 0) >= 1
	end },
	{ text = "Press C, then craft a Wooden Harvester", done = function(items)
		return (items.wood_harvester or 0) >= 1
	end },
	{ text = "Hold the harvester (hotbar) and gather 10 logs", done = function(items)
		return (items.log or 0) >= 10
	end },
	{ text = "Craft a Campfire: it goes straight to placing. Click to put it down", done = function()
		return flags.placed == true
	end },
	{ text = "Eat something: click food in your hotbar", done = function()
		return flags.ate == true
	end },
	{ text = "Visit the Quest Board by the spawn for quests", done = function()
		return flags.quests == true
	end },
}

local frame: Frame? = nil
local label: TextLabel? = nil
local count: TextLabel? = nil
local index = 1
local active = false
local lastItems: { [string]: number } = {}
local lastEquipped: string? = nil

local function show()
	if not frame or not label or not count then
		return
	end
	if index > #STEPS then
		label.Text = "You're ready! Level up for rewards and new recipes."
		count.Text = "Done"
		task.delay(6, function()
			if frame then
				TweenService:Create(frame, TweenInfo.new(0.6), { Position = frame.Position - UDim2.fromOffset(360, 0) }):Play()
				task.wait(0.7)
				frame:Destroy()
				frame = nil
			end
		end)
		active = false
		return
	end
	label.Text = STEPS[index].text
	count.Text = "Step " .. index .. " / " .. #STEPS
	local s = Instance.new("UIScale")
	s.Scale = 1.08
	s.Parent = frame
	TweenService:Create(s, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(0.4, function()
		s:Destroy()
	end)
end

local function check()
	if not active then
		return
	end
	local moved = false
	while index <= #STEPS and STEPS[index].done(lastItems, lastEquipped) do
		index += 1
		moved = true
	end
	if moved then
		show()
	end
end

function Tutorial.update(items: { [string]: number }, equipped: string?)
	lastItems, lastEquipped = items, equipped
	check()
end

-- Things that aren't in the bag: "placed", "ate", "quests".
function Tutorial.flag(name: string)
	flags[name] = true
	check()
end

function Tutorial.start(parent: ScreenGui)
	-- Wait for the save to load, then only teach new players.
	if not player:GetAttribute("DataLoaded") then
		player:GetAttributeChangedSignal("DataLoaded"):Wait()
	end
	if (player:GetAttribute("Level") or 1) > 5 then
		return
	end
	active = true
	local f = UIKit.panel({ Parent = parent, Name = "Tutorial", Position = UDim2.fromOffset(12, 150), Size = UDim2.fromOffset(300, 74) })
	UIKit.label({ Parent = f, Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 16), Text = "Getting started", TextXAlignment = Enum.TextXAlignment.Left, TextScaled = false, TextSize = 15, TextColor3 = C.star })
	count = UIKit.label({ Parent = f, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 6), Size = UDim2.fromOffset(90, 16), Text = "", TextXAlignment = Enum.TextXAlignment.Right, TextScaled = false, TextSize = 13 })
	label = UIKit.label({ Parent = f, Position = UDim2.fromOffset(10, 26), Size = UDim2.new(1, -20, 0, 42), Text = "", TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextScaled = false, TextSize = 16 })
	frame = f
	show()
	check()
end

return Tutorial
