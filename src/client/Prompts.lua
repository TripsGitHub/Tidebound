-- Interaction prompts in the game's own style, replacing Roblox's default
-- ProximityPrompt look everywhere (chests, traders, quest boards, gates, ...).
-- Every prompt is switched to Style Custom on this client, and when one is in
-- range we draw a tan panel over the object: a cream key cap with the key, the
-- action in bold white, the object's name above it, and a fill that sweeps
-- across the panel while a hold prompt is held.
local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local UIKit = require(script.Parent.UIKit)

local C = UIKit.Colors
local new = UIKit.new

local Prompts = {}

local function keyText(prompt: ProximityPrompt): string
	if UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then
		return "X"
	end
	local key = prompt.KeyboardKeyCode
	local s = UserInputService:GetStringForKeyCode(key)
	if s == nil or s == "" then
		s = key.Name
	end
	return string.upper(s)
end

local function build(prompt: ProximityPrompt, gui: ScreenGui)
	local board = new("BillboardGui", {
		Name = "TideboundPrompt",
		AlwaysOnTop = true,
		Size = UDim2.fromOffset(300, 72),
		SizeOffset = Vector2.new(0, 0.5),
		StudsOffset = Vector2.new(0, 0),
		LightInfluence = 0,
		ResetOnSpawn = false,
		Adornee = prompt.Parent,
		Parent = gui,
	})
	local panel = new("TextButton", {
		Parent = board,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, -4),
		Size = UDim2.fromOffset(60, 52),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = C.panel,
		BackgroundTransparency = UIKit.PANEL_ALPHA,
		Text = "",
		AutoButtonColor = false,
		BorderSizePixel = 0,
	}, { UIKit.corner(8), UIKit.stroke(C.rim, 2) })
	new("UIPadding", { Parent = panel, PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 14) })
	new("UIListLayout", { Parent = panel, FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder })

	-- Hold progress: a green strip under the panel that fills while held.
	local holdBack = new("Frame", { Parent = board, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.fromOffset(120, 6), BackgroundColor3 = C.barBack, BorderSizePixel = 0, Visible = prompt.HoldDuration > 0 }, { UIKit.corner(3) })
	local holdFill = new("Frame", { Parent = holdBack, Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.good, BorderSizePixel = 0 }, { UIKit.corner(3) })

	local cap = new("Frame", { Parent = panel, LayoutOrder = 1, Size = UDim2.fromOffset(36, 36), BackgroundColor3 = C.rim, BorderSizePixel = 0, ZIndex = 2 }, {
		UIKit.corner(6),
		UIKit.stroke(C.edge, 2),
	})
	local keyLabel = new("TextLabel", {
		Parent = cap,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		FontFace = UIKit.FontFace,
		TextSize = 20,
		TextColor3 = C.edge,
		Text = keyText(prompt),
		ZIndex = 3,
	})
	local words = new("Frame", { Parent = panel, LayoutOrder = 2, Size = UDim2.fromOffset(0, 44), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, ZIndex = 2 }, {
		new("UIListLayout", { VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local objectLabel = UIKit.hudText({ Parent = words, LayoutOrder = 1, Size = UDim2.fromOffset(0, 16), AutomaticSize = Enum.AutomaticSize.X, Text = prompt.ObjectText, TextScaled = false, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 2 })
	objectLabel.TextColor3 = C.rim
	local actionLabel = UIKit.hudText({ Parent = words, LayoutOrder = 2, Size = UDim2.fromOffset(0, 24), AutomaticSize = Enum.AutomaticSize.X, Text = prompt.ActionText, TextScaled = false, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 2 })

	local function refresh()
		objectLabel.Text = prompt.ObjectText
		objectLabel.Visible = prompt.ObjectText ~= ""
		actionLabel.Text = if prompt.HoldDuration > 0 then "Hold  " .. prompt.ActionText else prompt.ActionText
		keyLabel.Text = keyText(prompt)
		holdBack.Visible = prompt.HoldDuration > 0
		holdBack.Size = UDim2.fromOffset(math.max(60, panel.AbsoluteSize.X - 16), 6)
	end
	refresh()
	local conns = {
		prompt:GetPropertyChangedSignal("ActionText"):Connect(refresh),
		prompt:GetPropertyChangedSignal("ObjectText"):Connect(refresh),
		panel:GetPropertyChangedSignal("AbsoluteSize"):Connect(refresh),
	}

	-- Clicking or tapping the panel triggers it too.
	conns[#conns + 1] = panel.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			prompt:InputHoldBegin()
		end
	end)
	conns[#conns + 1] = panel.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			prompt:InputHoldEnd()
		end
	end)

	local tween: Tween? = nil
	conns[#conns + 1] = prompt.PromptButtonHoldBegan:Connect(function()
		if tween then
			tween:Cancel()
		end
		holdFill.Size = UDim2.fromScale(0, 1)
		tween = TweenService:Create(holdFill, TweenInfo.new(prompt.HoldDuration, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(1, 1) })
		tween:Play()
	end)
	conns[#conns + 1] = prompt.PromptButtonHoldEnded:Connect(function()
		if tween then
			tween:Cancel()
			tween = nil
		end
		holdFill.Size = UDim2.fromScale(0, 1)
	end)
	conns[#conns + 1] = prompt.Triggered:Connect(function()
		-- A quick pop so the press reads.
		cap.Size = UDim2.fromOffset(30, 30)
		TweenService:Create(cap, TweenInfo.new(0.15, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(36, 36) }):Play()
	end)

	-- Grow in.
	panel.Size = UDim2.fromOffset(40, 40)
	TweenService:Create(panel, TweenInfo.new(0.12, Enum.EasingStyle.Quad), { Size = UDim2.fromOffset(60, 52) }):Play()

	return function()
		for _, c in conns do
			c:Disconnect()
		end
		board:Destroy()
	end
end

local function customise(inst: Instance)
	if inst:IsA("ProximityPrompt") then
		inst.Style = Enum.ProximityPromptStyle.Custom
	end
end

function Prompts.start()
	local gui = new("ScreenGui", { Name = "Prompts", ResetOnSpawn = false, Parent = Players.LocalPlayer:WaitForChild("PlayerGui") })
	for _, d in workspace:GetDescendants() do
		customise(d)
	end
	workspace.DescendantAdded:Connect(customise)

	local open: { [ProximityPrompt]: () -> () } = {}
	ProximityPromptService.PromptShown:Connect(function(prompt, _inputType)
		if prompt.Style ~= Enum.ProximityPromptStyle.Custom then
			return
		end
		if open[prompt] then
			open[prompt]()
		end
		open[prompt] = build(prompt, gui)
	end)
	ProximityPromptService.PromptHidden:Connect(function(prompt)
		local close = open[prompt]
		if close then
			open[prompt] = nil
			close()
		end
	end)
end

return Prompts
