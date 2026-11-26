-- Our own procedural animations and juice: arm swings, hit shakes, chips flying,
-- floating "+2 Wood" text and bobbing slime. No uploaded animation assets needed.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Effects = {}

-- Arm swing ------------------------------------------------------------------

local baseC0: { [Motor6D]: CFrame } = {}
local swinging: { [Motor6D]: boolean } = {}

local function shoulderOf(character: Model): Motor6D?
	local upper = character:FindFirstChild("RightUpperArm")
	local motor = upper and upper:FindFirstChild("RightShoulder")
	if not motor then
		local torso = character:FindFirstChild("Torso")
		motor = torso and torso:FindFirstChild("Right Shoulder")
	end
	return if motor and motor:IsA("Motor6D") then motor else nil
end

-- A chop: wind up over the head, snap down, settle back.
function Effects.swing(character: Model)
	local motor = shoulderOf(character)
	if not motor or swinging[motor] then
		return
	end
	swinging[motor] = true
	local base = baseC0[motor] or motor.C0
	baseC0[motor] = base
	local isR6 = motor.Name == "Right Shoulder"
	local windUp = if isR6 then base * CFrame.Angles(0, 0, math.rad(150)) else base * CFrame.Angles(math.rad(150), 0, math.rad(-10))
	local strike = if isR6 then base * CFrame.Angles(0, 0, math.rad(40)) else base * CFrame.Angles(math.rad(35), 0, math.rad(5))

	local up = TweenService:Create(motor, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { C0 = windUp })
	local down = TweenService:Create(motor, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { C0 = strike })
	local back = TweenService:Create(motor, TweenInfo.new(0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { C0 = base })
	up:Play()
	up.Completed:Wait()
	down:Play()
	down.Completed:Wait()
	back:Play()
	back.Completed:Wait()
	swinging[motor] = nil
end

-- Hit feedback ---------------------------------------------------------------

local shaking: { [Model]: boolean } = {}

local function shake(model: Model)
	if shaking[model] then
		return
	end
	shaking[model] = true
	local pivot = model:GetPivot()
	task.spawn(function()
		for i = 1, 4 do
			local s = 0.18 * (1 - i / 5)
			model:PivotTo(pivot * CFrame.new(math.random() * s * 2 - s, 0, math.random() * s * 2 - s) * CFrame.Angles(0, 0, math.rad((i % 2 * 2 - 1) * 2)))
			task.wait(0.03)
		end
		model:PivotTo(pivot)
		shaking[model] = nil
	end)
end

local function chips(model: Model)
	local primary = model.PrimaryPart
	if not primary then
		return
	end
	local _, size = model:GetBoundingBox()
	local origin = primary.Position + Vector3.new(0, math.min(size.Y / 2, 3), 0)
	for _ = 1, 5 do
		local chip = Instance.new("Part")
		chip.Size = Vector3.new(0.3, 0.3, 0.3) * (0.6 + math.random() * 0.8)
		chip.Color = primary.Color
		chip.Material = primary.Material
		chip.CanCollide = false
		chip.CanQuery = false
		chip.CanTouch = false
		chip.CFrame = CFrame.new(origin) * CFrame.Angles(math.random() * 6, math.random() * 6, 0)
		chip.AssemblyLinearVelocity = Vector3.new(math.random(-12, 12), math.random(12, 22), math.random(-12, 12))
		chip.Parent = workspace
		Debris:AddItem(chip, 0.7)
	end
end

local function floatText(model: Model, text: string)
	local primary = model.PrimaryPart
	if not primary or text == "" then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Adornee = primary
	gui.AlwaysOnTop = true
	gui.Size = UDim2.fromOffset(260, 36)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 244, 200)
	label.TextStrokeTransparency = 0.2
	label.Text = text
	label.Parent = gui
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local info = TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(gui, info, { StudsOffset = Vector3.new(0, 7, 0) }):Play()
	TweenService:Create(label, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(gui, 1)
end

function Effects.hit(model: Model, text: string)
	if not model or not model.Parent then
		return
	end
	shake(model)
	chips(model)
	floatText(model, text)
end

-- Bobbing slime ---------------------------------------------------------------

function Effects.startAmbient()
	local bobbers: { [BasePart]: CFrame } = {}
	local function track(inst: Instance)
		if inst:IsA("BasePart") and inst:GetAttribute("Bob") then
			bobbers[inst] = inst.CFrame
		end
	end
	local nodes = workspace:WaitForChild("Nodes")
	for _, d in nodes:GetDescendants() do
		track(d)
	end
	nodes.DescendantAdded:Connect(track)
	nodes.DescendantRemoving:Connect(function(d)
		bobbers[d :: BasePart] = nil
	end)
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		for p, base in bobbers do
			local phase = (base.Position.X + base.Position.Z) * 0.7
			p.CFrame = base * CFrame.new(0, math.sin(t * 2 + phase) * 0.15, 0)
		end
	end)
end

return Effects
