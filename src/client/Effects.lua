-- Swings, hit shakes, a few chips, bobbing slime and optional sounds.
-- If Config.Animations.Swing has an id, a real keyframed animation plays instead
-- of the built-in code swing.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)
local Items = require(ReplicatedStorage:WaitForChild("Shared").Items)
local Anim = require(script.Parent.Anim)

local Effects = {}
local trail: (Model, Model, string) -> ()

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

-- A crescent trail behind the tip of the held item, only while the arm is moving
-- fast. Weapons get a bright cyan arc; tools a faint white one.
local TRAIL = {
	slash = { color = Color3.fromRGB(110, 236, 255), from = 0.08, to = 0.26, alpha = 0.15 },
	swing = { color = Color3.fromRGB(255, 255, 255), from = 0.08, to = 0.2, alpha = 0.55 },
}
local trails: { [Model]: Trail } = setmetatable({}, { __mode = "k" }) :: any

trail = function(character: Model, held: Model, style: string)
	local spec = TRAIL[style]
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if not spec or not hand or not hand:IsA("BasePart") then
		return
	end
	local t = trails[held]
	if not t or not t.Parent then
		-- Grip is at the bottom of the fist; the tip is the far end of the item.
		local grip = Vector3.new(0, -hand.Size.Y / 2 + 0.1, 0)
		local cf, size = held:GetBoundingBox()
		local centre = hand.CFrame:PointToObjectSpace(cf.Position)
		local dir = centre - grip
		if dir.Magnitude < 0.1 then
			dir = Vector3.new(0, 0, -1) * size.Magnitude / 2
		end
		local a0 = Instance.new("Attachment")
		a0.Name = "TrailBase"
		a0.Position = grip + dir * 0.9
		a0.Parent = hand
		local a1 = Instance.new("Attachment")
		a1.Name = "TrailTip"
		a1.Position = grip + dir * 2
		a1.Parent = hand
		t = Instance.new("Trail")
		t.Attachment0 = a0
		t.Attachment1 = a1
		t.FaceCamera = false
		t.LightEmission = 0.8
		t.Lifetime = 0.16
		t.MinLength = 0.05
		t.Enabled = false
		t.Parent = hand
		trails[held] = t
		held.Destroying:Connect(function()
			a0:Destroy()
			a1:Destroy()
			t:Destroy()
		end)
	end
	t.Color = ColorSequence.new(spec.color)
	t.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, spec.alpha), NumberSequenceKeypoint.new(1, 1) })
	t.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.2) })
	task.delay(spec.from, function()
		t.Enabled = true
		task.wait(spec.to - spec.from)
		t.Enabled = false
	end)
end

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
	-- Built-in animation (see Anim.lua): weapons slash sideways, everything else
	-- chops overhead. Both leave a short trail behind the tip of what you hold.
	local held = character:FindFirstChild("HeldItem")
	local itemId = held and held:GetAttribute("ItemId")
	local style = if itemId and Items[itemId] and Items[itemId].swing == "slash" then "slash" else "swing"
	Anim.play(character, style)
	if held and held:IsA("Model") then
		trail(character, held, style)
	end
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

-- A short flash over whatever you hit: white on trees, rocks and walls, red on
-- anything alive.
local function flash(model: Model, color: Color3)
	local h = Instance.new("Highlight")
	h.FillColor = color
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
		flash(model, Color3.new(1, 1, 1))
		local stony = model:GetAttribute("NodeType") == "Boulder"
		Effects.sound(if stony then "HitStone" else "ChopWood", model.PrimaryPart)
	elseif model:GetAttribute("StructureType") then
		shake(model)
		chips(model)
		flash(model, Color3.new(1, 1, 1))
		Effects.sound("ChopWood", model.PrimaryPart)
	else
		flash(model, Color3.fromRGB(255, 60, 60))
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
