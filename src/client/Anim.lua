-- Code-driven character animations: no uploaded animation assets needed.
-- Each animation is a few keyframed poses for the right arm, waist and neck,
-- blended every frame on top of the normal walk/idle animations.
--
-- Angles are in degrees, as (x, y, z) rotations of each joint:
--   RightShoulder x+ raises the arm forward and up, RightElbow x+ bends the forearm forward,
--   Waist x- leans forward and y twists, Neck x- looks down.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Anim = {}

type Pose = { [string]: Vector3 }
type Key = { t: number, pose: Pose? } -- pose nil = back to the resting pose

-- Holding a tool: arm out in front so the tool is clearly visible.
local HOLD: Pose = {
	RightShoulder = Vector3.new(32, 0, 0),
	RightElbow = Vector3.new(28, 0, 0),
}

local ANIMS: { [string]: { Key } } = {
	-- Overhead chop, Island Tribes style: short and snappy (about 0.4s). The arm goes
	-- up, comes straight down hard, and settles; the body only leans a little.
	swing = {
		{ t = 0 },
		{ t = 0.1, pose = { RightShoulder = Vector3.new(165, 0, -8), RightElbow = Vector3.new(40, 0, 0), Waist = Vector3.new(4, -8, 0), Neck = Vector3.new(4, 0, 0) } },
		{ t = 0.17, pose = { RightShoulder = Vector3.new(14, 0, 6), RightElbow = Vector3.new(4, 0, 0), Waist = Vector3.new(-10, 8, 0), Neck = Vector3.new(-6, 0, 0) } },
		{ t = 0.24, pose = { RightShoulder = Vector3.new(22, 0, 6), RightElbow = Vector3.new(12, 0, 0), Waist = Vector3.new(-6, 5, 0), Neck = Vector3.new(-3, 0, 0) } },
		{ t = 0.4 },
	},
	-- Bring food to the mouth and chew twice.
	eat = {
		{ t = 0 },
		{ t = 0.15, pose = { RightShoulder = Vector3.new(75, 0, -28), RightElbow = Vector3.new(115, 0, 0), Neck = Vector3.new(-8, 0, 0) } },
		{ t = 0.3, pose = { RightShoulder = Vector3.new(68, 0, -28), RightElbow = Vector3.new(105, 0, 0), Neck = Vector3.new(-14, 0, 0) } },
		{ t = 0.45, pose = { RightShoulder = Vector3.new(75, 0, -28), RightElbow = Vector3.new(115, 0, 0), Neck = Vector3.new(-6, 0, 0) } },
		{ t = 0.6, pose = { RightShoulder = Vector3.new(68, 0, -28), RightElbow = Vector3.new(105, 0, 0), Neck = Vector3.new(-14, 0, 0) } },
		{ t = 0.85 },
	},
	-- Set a wall or campfire down: reach forward and press it into place.
	place = {
		{ t = 0 },
		{ t = 0.12, pose = { RightShoulder = Vector3.new(70, 0, 4), RightElbow = Vector3.new(20, 0, 0), Waist = Vector3.new(-12, 0, 0), Neck = Vector3.new(-8, 0, 0) } },
		{ t = 0.22, pose = { RightShoulder = Vector3.new(40, 0, 4), RightElbow = Vector3.new(6, 0, 0), Waist = Vector3.new(-20, 0, 0), Neck = Vector3.new(-12, 0, 0) } },
		{ t = 0.42 },
	},
	-- Bend down and grab something off the ground.
	pickup = {
		{ t = 0 },
		{ t = 0.16, pose = { Waist = Vector3.new(-38, 0, 0), RightShoulder = Vector3.new(55, 0, 6), RightElbow = Vector3.new(8, 0, 0), Neck = Vector3.new(-10, 0, 0) } },
		{ t = 0.26, pose = { Waist = Vector3.new(-38, 0, 0), RightShoulder = Vector3.new(48, 0, 6), RightElbow = Vector3.new(30, 0, 0), Neck = Vector3.new(-10, 0, 0) } },
		{ t = 0.45 },
	},
}

local JOINTS = {
	RightShoulder = { "RightUpperArm", "RightShoulder" },
	RightElbow = { "RightLowerArm", "RightElbow" },
	Waist = { "UpperTorso", "Waist" },
	Neck = { "Head", "Neck" },
}

local baseC0: { [Motor6D]: CFrame } = setmetatable({}, { __mode = "k" }) :: any
local playing: { [Model]: { name: string, start: number } } = setmetatable({}, { __mode = "k" }) :: any

local function motorsOf(character: Model): { [string]: Motor6D }
	local out = {}
	for joint, path in JOINTS do
		local part = character:FindFirstChild(path[1])
		local m = part and part:FindFirstChild(path[2])
		if m and m:IsA("Motor6D") then
			out[joint] = m
		end
	end
	return out
end

local function smooth(a: number): number
	return a * a * (3 - 2 * a)
end

-- The pose a character is in right now, before any one-off animation.
local function restPose(character: Model): Pose
	local held = character:FindFirstChild("HeldItem")
	return if held then HOLD else {}
end

local function sample(keys: { Key }, rest: Pose, t: number): (Pose, boolean)
	local function poseAt(k: Key): Pose
		return k.pose or rest
	end
	if t >= keys[#keys].t then
		return rest, true
	end
	for i = 1, #keys - 1 do
		local a, b = keys[i], keys[i + 1]
		if t >= a.t and t < b.t then
			local f = smooth((t - a.t) / (b.t - a.t))
			local pa, pb = poseAt(a), poseAt(b)
			local out = {}
			for joint in JOINTS do
				local va, vb = pa[joint] or Vector3.zero, pb[joint] or Vector3.zero
				out[joint] = va:Lerp(vb, f)
			end
			return out, false
		end
	end
	return rest, true
end

local function apply(character: Model, pose: Pose)
	for joint, motor in motorsOf(character) do
		local base = baseC0[motor]
		if not base then
			base = motor.C0
			baseC0[motor] = base
		end
		local v = pose[joint] or Vector3.zero
		motor.C0 = base * CFrame.Angles(math.rad(v.X), math.rad(v.Y), math.rad(v.Z))
	end
end

function Anim.play(character: Model?, name: string)
	if character and ANIMS[name] then
		playing[character] = { name = name, start = os.clock() }
	end
end

function Anim.isPlaying(character: Model?): boolean
	return character ~= nil and playing[character] ~= nil
end

function Anim.start()
	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		for _, player in Players:GetPlayers() do
			local character = player.Character
			if character and character.Parent then
				local rest = restPose(character)
				local p = playing[character]
				if p then
					local pose, done = sample(ANIMS[p.name], rest, now - p.start)
					apply(character, pose)
					if done then
						playing[character] = nil
					end
				else
					apply(character, rest)
				end
			end
		end
	end)
end

return Anim
