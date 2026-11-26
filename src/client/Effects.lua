-- Swings, hit shakes, a few chips, bobbing slime and optional sounds.
-- If Config.Animations.Swing has an id, a real keyframed animation plays instead
-- of the built-in code swing.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)
local Anim = require(script.Parent.Anim)

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

local loadedTracks: { [Humanoid]: AnimationTrack } = {}

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
	-- Built-in overhead chop (see Anim.lua).
	Anim.play(character, "swing")
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
		local stony = model:GetAttribute("NodeType") == "Boulder"
		Effects.sound(if stony then "HitStone" else "ChopWood", model.PrimaryPart)
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
