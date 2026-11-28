-- The Tribe Path panel in the top-left: the one quest a player should do next (see
-- Quests.PATH), its progress and what it pays. Steps are tracked and paid on the
-- server; this only shows them. When a step is done the panel pops, shows the next
-- one, and once the whole path is walked it slides away.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local QuestList = require(Shared.Quests)
local Items = require(Shared.Items)
local UIKit = require(script.Parent.UIKit)

local player = Players.LocalPlayer
local Tutorial = {}

local C = UIKit.Colors
local PATH = QuestList.PATH

local frame: Frame? = nil
local title: TextLabel? = nil
local count: TextLabel? = nil
local body: TextLabel? = nil
local reward: TextLabel? = nil
local fill: Frame? = nil
local fillText: TextLabel? = nil
local state = { index = 0, progress = 0 }
local lastIndex = 0
local finished = false

local function pop()
	if not frame then
		return
	end
	local s = Instance.new("UIScale")
	s.Scale = 1.1
	s.Parent = frame
	TweenService:Create(s, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(0.45, function()
		s:Destroy()
	end)
end

local function show()
	if not frame or not title or not count or not body or not reward or not fill or not fillText then
		return
	end
	local step = PATH[state.index]
	if not step then
		if finished then
			return
		end
		finished = true
		title.Text = "Tribe Path complete!"
		count.Text = ""
		body.Text = "You know the way now. Level up for new recipes, open crates, and take on the bosses."
		reward.Text = ""
		fill.Parent.Visible = false
		task.delay(8, function()
			if frame then
				TweenService:Create(frame, TweenInfo.new(0.6), { Position = frame.Position - UDim2.fromOffset(380, 0) }):Play()
				task.wait(0.7)
				frame:Destroy()
				frame = nil
			end
		end)
		return
	end
	title.Text = step.title
	count.Text = "Step " .. state.index .. " / " .. #PATH
	body.Text = step.text
	local parts = { "+" .. (step.xp or 0) .. " XP" }
	if step.reward then
		table.insert(parts, "+" .. step.reward .. " Shells")
	end
	for id, n in step.items or {} do
		if Items[id] then
			table.insert(parts, n .. " " .. Items[id].name)
		end
	end
	reward.Text = table.concat(parts, "   ")
	local ratio = math.clamp(state.progress / step.amount, 0, 1)
	TweenService:Create(fill, TweenInfo.new(0.25), { Size = UDim2.fromScale(math.max(ratio, 0.02), 1) }):Play()
	fillText.Text = state.progress .. " / " .. step.amount
	if state.index ~= lastIndex then
		lastIndex = state.index
		pop()
	end
end

function Tutorial.setPath(path)
	if type(path) ~= "table" then
		return
	end
	state.index = path.index or 1
	state.progress = path.progress or 0
	show()
end

-- Kept for older callers: the path is tracked on the server now.
function Tutorial.update(_items, _equipped) end
function Tutorial.flag(_name: string) end

function Tutorial.start(parent: ScreenGui)
	if not player:GetAttribute("DataLoaded") then
		player:GetAttributeChangedSignal("DataLoaded"):Wait()
	end
	local f = UIKit.panel({ Parent = parent, Name = "Tutorial", Position = UDim2.fromOffset(12, 150), Size = UDim2.fromOffset(320, 112) })
	UIKit.label({ Parent = f, Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 14), Text = "TRIBE PATH", TextXAlignment = Enum.TextXAlignment.Left, TextScaled = false, TextSize = 12, TextColor3 = C.star })
	count = UIKit.label({ Parent = f, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 6), Size = UDim2.fromOffset(100, 14), Text = "", TextXAlignment = Enum.TextXAlignment.Right, TextScaled = false, TextSize = 12 })
	title = UIKit.label({ Parent = f, Position = UDim2.fromOffset(10, 20), Size = UDim2.new(1, -20, 0, 20), Text = "", TextXAlignment = Enum.TextXAlignment.Left, TextScaled = false, TextSize = 18 })
	body = UIKit.label({ Parent = f, Position = UDim2.fromOffset(10, 42), Size = UDim2.new(1, -20, 0, 32), Text = "", TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextScaled = false, TextSize = 14 })
	local back = UIKit.new("Frame", { Parent = f, Position = UDim2.fromOffset(10, 76), Size = UDim2.new(0.42, 0, 0, 16), BackgroundColor3 = C.barBack }, { UIKit.corner(6) })
	fill = UIKit.new("Frame", { Parent = back, Size = UDim2.fromScale(0.02, 1), BackgroundColor3 = C.xp, BorderSizePixel = 0 }, { UIKit.corner(6) })
	fillText = UIKit.label({ Parent = back, Size = UDim2.fromScale(1, 1), Text = "", TextScaled = false, TextSize = 12, ZIndex = 3 })
	reward = UIKit.label({ Parent = f, Position = UDim2.new(0.42, 18, 0, 74), Size = UDim2.new(0.58, -28, 0, 34), Text = "", TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextScaled = false, TextSize = 12, TextColor3 = C.gold })
	frame = f
	show()
end

return Tutorial
