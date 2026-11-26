-- Swings, hit shakes, a few chips, bobbing slime and optional sounds.
-- If Config.Animations.Swing has an id, a real keyframed animation plays instead
-- of the built-in code swing.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)

local Effects = {}

function Effects.sound(name: string, at: Instance?)
	local id = Config.Sounds[name]
	if not id or id == "" then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = 0.6
	s.PlaybackSpeed = 0.92 + math.random() * 0.16
	if at and at:IsA("BasePart") then
		s.Parent = at
	else
		s.Parent = SoundService
	end
	s:Play()
	Debris:AddItem(s, 3)
end

-- Swing --------------------------------------------------------------------------

local baseC0: { [Motor6D]: CFrame } = {}
local busy: { [Motor6D]: boolean } = {}
local loadedTracks: { [Humanoid]: AnimationTrack } = {}

local function shoulderOf(character: Model): Motor6D?
	local upper = character:FindFirstChild("RightUpperArm")
	local motor = upper and upper:FindFirstChild("RightShoulder")
	if not motor then
		local torso = character:FindFirstChild("Torso")
		motor = torso and torso:FindFirstChild("Right Shoulder")
	end
	return if motor and motor:IsA("Motor6D") then motor else nil
end

local function waistOf(character: Model): Motor6D?
	local upper = character:FindFirstChild("UpperTorso")
	local motor = upper and upper:FindFirstChild("Waist")
	return if motor and motor:IsA("Motor6D") then motor else nil
end

local function tweenC0(motor: Motor6D, to: CFrame, t: number, style: Enum.EasingStyle, dir: Enum.EasingDirection)
	local tw = TweenService:Create(motor, TweenInfo.new(t, style, dir), { C0 = to })
	tw:Play()
	return tw
end

function Effects.swing(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if Config.Animations.Swing ~= "" and humanoid then
		local track = loadedTracks[humanoid]
		if not track then
			local animator = humanoid:FindFirstChildOfClass("Animator")
			if animator then
				local anim = Instance.new("Animation")
				anim.AnimationId = Config.Animations.Swing
				track = animator:LoadAnimation(anim)
				track.Priority = Enum.AnimationPriority.Action
				loadedTracks[humanoid] = track
			end
		end
		if track then
			track:Play(0.05)
			return
		end
	end

	-- Built-in swing: an overhead chop with a little body twist.
	local shoulder = shoulderOf(character)
	if not shoulder or busy[shoulder] then
		return
	end
	busy[shoulder] = true
	local base = baseC0[shoulder] or shoulder.C0
	baseC0[shoulder] = base
	local waist = waistOf(character)
	local waistBase = waist and (baseC0[waist] or waist.C0)
	if waist then
		baseC0[waist] = waistBase
	end
	local isR6 = shoulder.Name == "Right Shoulder"
	local windUp = if isR6 then base * CFrame.Angles(0, 0, math.rad(160)) else base * CFrame.Angles(math.rad(165), 0, math.rad(-15))
	local strike = if isR6 then base * CFrame.Angles(0, 0, math.rad(25)) else base * CFrame.Angles(math.rad(25), 0, math.rad(8))

	tweenC0(shoulder, windUp, 0.13, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	if waist and waistBase then
		tweenC0(waist, waistBase * CFrame.Angles(math.rad(8), math.rad(-14), 0), 0.13, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	end
	task.wait(0.13)
	tweenC0(shoulder, strike, 0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	if waist and waistBase then
		tweenC0(waist, waistBase * CFrame.Angles(math.rad(-10), math.rad(10), 0), 0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end
	task.wait(0.1)
	tweenC0(shoulder, base, 0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	if waist and waistBase then
		tweenC0(waist, waistBase, 0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	end
	task.wait(0.2)
	busy[shoulder] = nil
end

-- Hits ---------------------------------------------------------------------------

local shaking: { [Model]: boolean } = {}

local function shake(model: Model)
	if shaking[model] or not model:GetAttribute("NodeType") and not model:GetAttribute("StructureType") then
		return
	end
	shaking[model] = true
	local pivot = model:GetPivot()
	task.spawn(function()
		for i = 1, 4 do
			local s = 0.12 * (1 - i / 5)
			model:PivotTo(pivot * CFrame.new(math.random() * s * 2 - s, 0, math.random() * s * 2 - s) * CFrame.Angles(math.rad((i % 2 * 2 - 1) * 1.5), 0, 0))
			task.wait(0.03)
		end
		if not model:GetAttribute("Depleted") then
			model:PivotTo(pivot)
		end
		shaking[model] = nil
	end)
end

local function chips(model: Model)
	local primary = model.PrimaryPart
	if not primary then
		return
	end
	local cf, size = model:GetBoundingBox()
	local origin = Vector3.new(cf.X, cf.Y - size.Y / 2 + 2.5, cf.Z)
	for _ = 1, 3 do
		local chip = Instance.new("Part")
		chip.Size = Vector3.new(0.25, 0.25, 0.25) * (0.7 + math.random() * 0.8)
		chip.Color = primary.Color
		chip.Material = primary.Material
		chip.CanCollide = false
		chip.CanQuery = false
		chip.CanTouch = false
		chip.CFrame = CFrame.new(origin) * CFrame.Angles(math.random() * 6, math.random() * 6, 0)
		chip.AssemblyLinearVelocity = Vector3.new(math.random(-9, 9), math.random(10, 16), math.random(-9, 9))
		chip.Parent = workspace
		Debris:AddItem(chip, 0.5)
	end
end

local function flashRed(model: Model)
	local h = Instance.new("Highlight")
	h.FillColor = Color3.fromRGB(255, 60, 60)
	h.FillTransparency = 0.55
	h.OutlineTransparency = 1
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Adornee = model
	h.Parent = model
	Debris:AddItem(h, 0.12)
end

function Effects.hit(target: Instance)
	if not target or not target.Parent or not target:IsA("Model") then
		return
	end
	local model = target :: Model
	if model:GetAttribute("NodeType") then
		shake(model)
		chips(model)
		local mat = model.PrimaryPart and model.PrimaryPart.Material
		Effects.sound(if mat == Enum.Material.Slate then "HitStone" else "ChopWood", model.PrimaryPart)
	elseif model:GetAttribute("StructureType") then
		shake(model)
		chips(model)
		Effects.sound("ChopWood", model.PrimaryPart)
	else
		flashRed(model)
		Effects.sound("HitFlesh", model.PrimaryPart)
	end
end

-- Ambient ------------------------------------------------------------------------

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
