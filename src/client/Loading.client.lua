-- While the server builds the world (a minute or two), cover the screen with a
-- loading card instead of an empty orange sky, so it doesn't look stuck. It shows
-- what's being built (workspace "LoadingStep", set by WorldBuilder) and how long
-- it's been, and fades out once your character is in the world.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
if player.Character then
	return
end

local gui = Instance.new("ScreenGui")
gui.Name = "Loading"
gui.IgnoreGuiInset = true
gui.DisplayOrder = 100
gui.ResetOnSpawn = false

local back = Instance.new("Frame")
back.Size = UDim2.fromScale(1, 1)
back.BackgroundColor3 = Color3.fromRGB(22, 44, 56)
back.BorderSizePixel = 0
back.Parent = gui
local grad = Instance.new("UIGradient")
grad.Rotation = 90
grad.Color = ColorSequence.new(Color3.fromRGB(40, 96, 110), Color3.fromRGB(14, 28, 40))
grad.Parent = back

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.AnchorPoint = Vector2.new(0.5, 0.5)
title.Position = UDim2.fromScale(0.5, 0.42)
title.Size = UDim2.fromOffset(600, 90)
title.Font = Enum.Font.FredokaOne
title.Text = "TIDEBOUND"
title.TextSize = 72
title.TextColor3 = Color3.fromRGB(246, 230, 196)
title.Parent = back
local stroke = Instance.new("UIStroke")
stroke.Thickness = 4
stroke.Color = Color3.fromRGB(70, 46, 30)
stroke.Parent = title

local pill = Instance.new("Frame")
pill.AnchorPoint = Vector2.new(0.5, 0)
pill.Position = UDim2.fromScale(0.5, 0.52)
pill.Size = UDim2.fromOffset(360, 44)
pill.BackgroundColor3 = Color3.fromRGB(196, 164, 116)
pill.Parent = back
Instance.new("UICorner", pill).CornerRadius = UDim.new(0, 10)
local inner = Instance.new("Frame")
inner.AnchorPoint = Vector2.new(0.5, 0.5)
inner.Position = UDim2.fromScale(0.5, 0.5)
inner.Size = UDim2.new(1, -10, 1, -10)
inner.BackgroundColor3 = Color3.fromRGB(120, 92, 62)
inner.Parent = pill
Instance.new("UICorner", inner).CornerRadius = UDim.new(0, 7)
local step = Instance.new("TextLabel")
step.BackgroundTransparency = 1
step.Size = UDim2.fromScale(1, 1)
step.Font = Enum.Font.BuilderSansBold
step.TextSize = 20
step.TextColor3 = Color3.new(1, 1, 1)
step.Text = "Building the world"
step.Parent = inner

local hint = Instance.new("TextLabel")
hint.BackgroundTransparency = 1
hint.AnchorPoint = Vector2.new(0.5, 0)
hint.Position = UDim2.fromScale(0.5, 0.6)
hint.Size = UDim2.fromOffset(600, 24)
hint.Font = Enum.Font.BuilderSans
hint.TextSize = 17
hint.TextColor3 = Color3.fromRGB(200, 220, 225)
hint.Text = ""
hint.Parent = back

gui.Parent = player:WaitForChild("PlayerGui")

local start = os.clock()
local conn = RunService.Heartbeat:Connect(function()
	local dots = string.rep(".", math.floor(os.clock() * 2) % 4)
	step.Text = (workspace:GetAttribute("LoadingStep") or "Building the world") .. dots
	hint.Text = string.format("The islands are built fresh each server: about a minute or two (%ds)", os.clock() - start)
end)

player.CharacterAdded:Wait()
task.wait(1)
conn:Disconnect()
local info = TweenInfo.new(0.8)
for _, d in gui:GetDescendants() do
	if d:IsA("Frame") then
		TweenService:Create(d, info, { BackgroundTransparency = 1 }):Play()
	elseif d:IsA("TextLabel") then
		TweenService:Create(d, info, { TextTransparency = 1 }):Play()
	elseif d:IsA("UIStroke") then
		TweenService:Create(d, info, { Transparency = 1 }):Play()
	end
end
task.wait(0.9)
gui:Destroy()
