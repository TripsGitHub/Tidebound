-- Code-driven character animation: no uploaded animation assets needed.
--
-- Every client animates every R15 character by setting each joint's Transform every
-- frame, just before physics runs. That works for both kinds of R15 joint: classic
-- Motor6Ds and the AnimationConstraints that Roblox's Avatar Joint Upgrade swaps in
-- (their C0/C1 are read-only, so writing C0 silently did nothing on new avatars).
-- Idle, jump, swim and climb use Roblox's default animations; running on the ground is
-- our own (runPose). On top
-- of them this module only drives:
--   1. Holding a tool keeps the right arm out in front.
--   2. One-off actions (Anim.play): chop, slash, eat, place, pick up, drawing and
--      stowing a tool, and putting on each piece of armour.
--
-- Angles are in degrees, as (x, y, z) rotations of each joint:
--   Shoulder/Hip x+ swings the limb forward, Elbow x+ bends the forearm forward,
--   Knee x- bends the shin back, Ankle x- points the toes down,
--   Root/Waist x- leans forward and y twists, Neck x- looks down,
--   RightShoulder z+ / LeftShoulder z- lifts the arm out to the side.
-- RootPos moves the whole body (studs), for bobbing and crouching.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Anim = {}

type Pose = { [string]: Vector3 }
type Key = { t: number, pose: Pose? } -- pose nil = back to whatever the body is doing

local JOINTS: { [string]: { string } } = {
	Root = { "LowerTorso", "Root" },
	Waist = { "UpperTorso", "Waist" },
	Neck = { "Head", "Neck" },
	RightShoulder = { "RightUpperArm", "RightShoulder" },
	RightElbow = { "RightLowerArm", "RightElbow" },
	RightWrist = { "RightHand", "RightWrist" },
	LeftShoulder = { "LeftUpperArm", "LeftShoulder" },
	LeftElbow = { "LeftLowerArm", "LeftElbow" },
	LeftWrist = { "LeftHand", "LeftWrist" },
	RightHip = { "RightUpperLeg", "RightHip" },
	RightKnee = { "RightLowerLeg", "RightKnee" },
	RightAnkle = { "RightFoot", "RightAnkle" },
	LeftHip = { "LeftUpperLeg", "LeftHip" },
	LeftKnee = { "LeftLowerLeg", "LeftKnee" },
	LeftAnkle = { "LeftFoot", "LeftAnkle" },
}

-- In one-off actions, arm joints take the action's angle outright; everything else
-- (torso, legs, RootPos) is added on top of the walk so you can chop while walking.
local ABSOLUTE = {
	RightShoulder = true, RightElbow = true, RightWrist = true,
	LeftShoulder = true, LeftElbow = true, LeftWrist = true,
}

local V = Vector3.new

-- Holding a tool: arm out in front so the tool is clearly visible.
local HOLD: Pose = {
	RightShoulder = V(32, 0, 0),
	RightElbow = V(28, 0, 0),
}

local ANIMS: { [string]: { Key } } = {
	-- Overhead chop, Island Tribes style: short and snappy (about 0.4s). The arm goes
	-- up, comes straight down hard, and settles; the body only leans a little.
	swing = {
		{ t = 0 },
		{ t = 0.1, pose = { RightShoulder = V(165, 0, -8), RightElbow = V(40, 0, 0), Waist = V(4, -8, 0), Neck = V(4, 0, 0) } },
		{ t = 0.17, pose = { RightShoulder = V(14, 0, 6), RightElbow = V(4, 0, 0), Waist = V(-10, 8, 0), Neck = V(-6, 0, 0) } },
		{ t = 0.24, pose = { RightShoulder = V(22, 0, 6), RightElbow = V(12, 0, 0), Waist = V(-6, 5, 0), Neck = V(-3, 0, 0) } },
		{ t = 0.4 },
	},
	-- Weapon strike (clubs and swords): raise the blade up over the shoulder, then
	-- bring it down forward in front of you with a small lunge, and recover. The
	-- swing trail is drawn during the strike (see Effects.swing). About 0.45s.
	slash = {
		{ t = 0 },
		{ t = 0.12, pose = { RightShoulder = V(172, 0, -10), RightElbow = V(34, 0, 0), Waist = V(8, -10, 0), Neck = V(5, 0, 0), RootPos = V(0, 0.05, 0) } },
		{ t = 0.2, pose = { RightShoulder = V(62, 0, 2), RightElbow = V(0, 0, 0), Waist = V(-16, 6, 0), Neck = V(-8, 0, 0), Root = V(-4, 0, 0), RootPos = V(0, -0.12, -0.25) } },
		{ t = 0.28, pose = { RightShoulder = V(44, 0, 4), RightElbow = V(8, 0, 0), Waist = V(-11, 4, 0), Neck = V(-5, 0, 0), RootPos = V(0, -0.08, -0.15) } },
		{ t = 0.45 },
	},
	-- Bring food to the mouth and chew twice.
	eat = {
		{ t = 0 },
		{ t = 0.15, pose = { RightShoulder = V(75, 0, -28), RightElbow = V(115, 0, 0), Neck = V(-8, 0, 0) } },
		{ t = 0.3, pose = { RightShoulder = V(68, 0, -28), RightElbow = V(105, 0, 0), Neck = V(-14, 0, 0) } },
		{ t = 0.45, pose = { RightShoulder = V(75, 0, -28), RightElbow = V(115, 0, 0), Neck = V(-6, 0, 0) } },
		{ t = 0.6, pose = { RightShoulder = V(68, 0, -28), RightElbow = V(105, 0, 0), Neck = V(-14, 0, 0) } },
		{ t = 0.85 },
	},
	-- Set a wall or campfire down: reach forward and press it into place.
	place = {
		{ t = 0 },
		{ t = 0.12, pose = { RightShoulder = V(70, 0, 4), RightElbow = V(20, 0, 0), Waist = V(-12, 0, 0), Neck = V(-8, 0, 0) } },
		{ t = 0.22, pose = { RightShoulder = V(40, 0, 4), RightElbow = V(6, 0, 0), Waist = V(-20, 0, 0), Neck = V(-12, 0, 0) } },
		{ t = 0.42 },
	},
	-- Bend down and grab something off the ground (knees bend too, so it reads as a crouch).
	pickup = {
		{ t = 0 },
		{ t = 0.16, pose = { Waist = V(-32, 0, 0), Root = V(-6, 0, 0), RootPos = V(0, -0.35, 0), RightHip = V(28, 0, 0), LeftHip = V(28, 0, 0),
			RightKnee = V(-40, 0, 0), LeftKnee = V(-40, 0, 0), RightShoulder = V(55, 0, 6), RightElbow = V(8, 0, 0), Neck = V(-10, 0, 0) } },
		{ t = 0.26, pose = { Waist = V(-32, 0, 0), Root = V(-6, 0, 0), RootPos = V(0, -0.35, 0), RightHip = V(28, 0, 0), LeftHip = V(28, 0, 0),
			RightKnee = V(-40, 0, 0), LeftKnee = V(-40, 0, 0), RightShoulder = V(48, 0, 6), RightElbow = V(30, 0, 0), Neck = V(-10, 0, 0) } },
		{ t = 0.45 },
	},

	-- Equipping -----------------------------------------------------------------------
	-- Draw a tool: the hand drops to the hip, then swings the tool up into the hold.
	draw = {
		{ t = 0 },
		{ t = 0.1, pose = { RightShoulder = V(-28, 0, 22), RightElbow = V(8, 0, 0), Waist = V(0, -10, 0), Neck = V(-4, -6, 0) } },
		{ t = 0.22, pose = { RightShoulder = V(70, 0, 6), RightElbow = V(50, 0, 0), Waist = V(2, 6, 0) } },
		{ t = 0.3, pose = { RightShoulder = V(38, 0, 0), RightElbow = V(30, 0, 0), Waist = V(0, 2, 0) } },
		{ t = 0.42 },
	},
	-- Put a tool away: tuck it back to the hip.
	stow = {
		{ t = 0 },
		{ t = 0.12, pose = { RightShoulder = V(-30, 0, 20), RightElbow = V(12, 0, 0), Waist = V(0, -8, 0) } },
		{ t = 0.32 },
	},
	-- Helmet: both hands lift it onto the head and press it down.
	dress_head = {
		{ t = 0 },
		{ t = 0.16, pose = { RightShoulder = V(160, 0, -22), RightElbow = V(85, 0, 0), LeftShoulder = V(160, 0, 22), LeftElbow = V(85, 0, 0), Neck = V(6, 0, 0) } },
		{ t = 0.3, pose = { RightShoulder = V(150, 0, -26), RightElbow = V(100, 0, 0), LeftShoulder = V(150, 0, 26), LeftElbow = V(100, 0, 0), Neck = V(-8, 0, 0), RootPos = V(0, -0.08, 0) } },
		{ t = 0.4, pose = { RightShoulder = V(152, 0, -24), RightElbow = V(95, 0, 0), LeftShoulder = V(152, 0, 24), LeftElbow = V(95, 0, 0), Neck = V(-3, 0, 0) } },
		{ t = 0.62 },
	},
	-- Chestplate: grab the edges and tug it down into place, chest out.
	dress_body = {
		{ t = 0 },
		{ t = 0.14, pose = { RightShoulder = V(50, 0, -16), RightElbow = V(95, 0, 0), LeftShoulder = V(50, 0, 16), LeftElbow = V(95, 0, 0), Waist = V(-6, 0, 0), Neck = V(-10, 0, 0) } },
		{ t = 0.3, pose = { RightShoulder = V(18, 0, -10), RightElbow = V(60, 0, 0), LeftShoulder = V(18, 0, 10), LeftElbow = V(60, 0, 0), Waist = V(6, 0, 0), Neck = V(4, 0, 0), RootPos = V(0, 0.06, 0) } },
		{ t = 0.4, pose = { RightShoulder = V(14, 0, 6), RightElbow = V(20, 0, 0), LeftShoulder = V(14, 0, -6), LeftElbow = V(20, 0, 0), Waist = V(4, 0, 0) } },
		{ t = 0.62 },
	},
	-- Leggings: crouch, slap both thighs, stand up.
	dress_legs = {
		{ t = 0 },
		{ t = 0.16, pose = { Waist = V(-26, 0, 0), RootPos = V(0, -0.3, 0), RightHip = V(22, 0, 0), LeftHip = V(22, 0, 0), RightKnee = V(-34, 0, 0), LeftKnee = V(-34, 0, 0),
			RightShoulder = V(40, 0, 4), RightElbow = V(10, 0, 0), LeftShoulder = V(40, 0, -4), LeftElbow = V(10, 0, 0), Neck = V(-10, 0, 0) } },
		{ t = 0.28, pose = { Waist = V(-22, 0, 0), RootPos = V(0, -0.26, 0), RightHip = V(20, 0, 0), LeftHip = V(20, 0, 0), RightKnee = V(-30, 0, 0), LeftKnee = V(-30, 0, 0),
			RightShoulder = V(20, 0, 10), RightElbow = V(6, 0, 0), LeftShoulder = V(20, 0, -10), LeftElbow = V(6, 0, 0), Neck = V(-8, 0, 0) } },
		{ t = 0.66 },
	},
	-- Boots: lift each foot and stamp it down.
	dress_feet = {
		{ t = 0 },
		{ t = 0.14, pose = { RightHip = V(40, 0, 0), RightKnee = V(-60, 0, 0), RightAnkle = V(10, 0, 0), RootPos = V(0, -0.05, 0), Waist = V(-4, 6, 0),
			RightShoulder = V(-6, 0, 14), LeftShoulder = V(10, 0, -14) } },
		{ t = 0.24, pose = { RootPos = V(0, -0.14, 0), RightKnee = V(-10, 0, 0), LeftKnee = V(-10, 0, 0), RightShoulder = V(0, 0, 10), LeftShoulder = V(0, 0, -10) } },
		{ t = 0.38, pose = { LeftHip = V(40, 0, 0), LeftKnee = V(-60, 0, 0), LeftAnkle = V(10, 0, 0), RootPos = V(0, -0.05, 0), Waist = V(-4, -6, 0),
			RightShoulder = V(10, 0, 14), LeftShoulder = V(-6, 0, -14) } },
		{ t = 0.48, pose = { RootPos = V(0, -0.14, 0), RightKnee = V(-10, 0, 0), LeftKnee = V(-10, 0, 0), RightShoulder = V(0, 0, 10), LeftShoulder = V(0, 0, -10) } },
		{ t = 0.66 },
	},
	-- Bag: hitch it up onto the back with a shrug.
	dress_bag = {
		{ t = 0 },
		{ t = 0.14, pose = { RightShoulder = V(-20, 0, 18), RightElbow = V(70, 0, 0), LeftShoulder = V(-20, 0, -18), LeftElbow = V(70, 0, 0), Waist = V(-8, 0, 0) } },
		{ t = 0.26, pose = { RightShoulder = V(-10, 0, 12), RightElbow = V(80, 0, 0), LeftShoulder = V(-10, 0, -12), LeftElbow = V(80, 0, 0), Waist = V(6, 0, 0), RootPos = V(0, 0.12, 0) } },
		{ t = 0.5 },
	},
}

-- Reactions: added on top of everything, never interrupt an action.
local REACTS: { [string]: { Key } } = {
	land = {
		{ t = 0 },
		{ t = 0.06, pose = { RootPos = V(0, -0.38, 0), RightHip = V(26, 0, 0), LeftHip = V(26, 0, 0), RightKnee = V(-44, 0, 0), LeftKnee = V(-44, 0, 0),
			RightAnkle = V(14, 0, 0), LeftAnkle = V(14, 0, 0), Waist = V(-10, 0, 0), RightShoulder = V(0, 0, 8), LeftShoulder = V(0, 0, -8) } },
		{ t = 0.28 },
	},
	hurt = {
		{ t = 0 },
		{ t = 0.06, pose = { Waist = V(12, 0, 0), Neck = V(14, 0, 0), Root = V(5, 0, 0), RightShoulder = V(-8, 0, 12), LeftShoulder = V(-8, 0, -12) } },
		{ t = 0.3 },
	},
}

local DRESS_ORDER = { "head", "body", "legs", "feet", "bag" }

-- Per character -------------------------------------------------------------------------

type State = {
	phase: number,
	speed: number, -- smoothed horizontal speed
	air: number, -- 0 grounded .. 1 in the air (smoothed)
	airborne: boolean,
	airSince: number,
	fallSpeed: number,
	action: { name: string, start: number }?,
	react: { name: string, start: number, scale: number }?,
	health: number?,
	held: string?,
	armour: { [string]: string }?,
	armourFolder: Instance?,
	born: number,
	run: number?, -- 0..1 how much of our own run is showing
}

local states: { [Model]: State } = setmetatable({}, { __mode = "k" }) :: any
local baseC0: { [Instance]: CFrame } = setmetatable({}, { __mode = "k" }) :: any

local function stateOf(character: Model): State
	local s = states[character]
	if not s then
		s = { phase = 0, speed = 0, air = 0, airborne = false, airSince = 0, fallSpeed = 0, born = os.clock() }
		states[character] = s
	end
	return s
end

-- A joint is a Motor6D or (with the Avatar Joint Upgrade) an AnimationConstraint.
-- Both have a writable Transform.
local function motorsOf(character: Model): { [string]: any }
	local out = {}
	for joint, path in JOINTS do
		local part = character:FindFirstChild(path[1])
		local m = part and part:FindFirstChild(path[2])
		if m and (m:IsA("Motor6D") or m:IsA("AnimationConstraint")) then
			out[joint] = m
		end
	end
	return out
end

local function smooth(a: number): number
	return a * a * (3 - 2 * a)
end

local function get(p: Pose, k: string): Vector3
	return p[k] or Vector3.zero
end

local function mix(a: Pose, b: Pose, f: number): Pose
	local out = {}
	for k, v in a do
		out[k] = v:Lerp(get(b, k), f)
	end
	for k, v in b do
		if not a[k] then
			out[k] = Vector3.zero:Lerp(v, f)
		end
	end
	return out
end

-- Locomotion poses ------------------------------------------------------------------------

local function idlePose(t: number): Pose
	local b = math.sin(t * 1.7)
	return {
		Waist = V(1.5 * b, 0, 0),
		Neck = V(-1.2 * b, 0, 0),
		RightShoulder = V(0, 0, 3 + b),
		LeftShoulder = V(0, 0, -3 - b),
		RightElbow = V(6 + b, 0, 0),
		LeftElbow = V(6 + b, 0, 0),
		RootPos = V(0, -0.02 * (b + 1), 0),
	}
end

-- One stride cycle. run: 0 = walking, 1 = running (bigger, faster, leaning in).
local function walkPose(phase: number, run: number): Pose
	local s, c = math.sin(phase), math.cos(phase)
	local amp = 32 + 18 * run
	local arm = amp * (0.55 + 0.15 * run)
	local bob = 0.12 + 0.12 * run
	local swingR = math.max(0, c) -- right leg swinging forward
	local swingL = math.max(0, -c)
	return {
		RightHip = V(amp * s, 0, 0),
		LeftHip = V(-amp * s, 0, 0),
		RightKnee = V(-6 - amp * (1.1 + 0.5 * run) * swingR, 0, 0),
		LeftKnee = V(-6 - amp * (1.1 + 0.5 * run) * swingL, 0, 0),
		RightAnkle = V(0.4 * amp * s, 0, 0),
		LeftAnkle = V(-0.4 * amp * s, 0, 0),
		RightShoulder = V(-arm * s, 0, 4),
		LeftShoulder = V(arm * s, 0, -4),
		RightElbow = V(12 + 50 * run + 0.4 * arm * math.max(0, -s), 0, 0),
		LeftElbow = V(12 + 50 * run + 0.4 * arm * math.max(0, s), 0, 0),
		Root = V(-3 - 8 * run, 6 * s, 0),
		Waist = V(-1 - 3 * run, -9 * s, 0),
		Neck = V(1 + 3 * run, 3 * s, 0),
		RootPos = V(0, bob * (math.abs(c) - 0.6), 0),
	}
end

-- Tidebound's own run (replaces Roblox's default run on the ground): a springy,
-- cartoon jog with the chest leaning into it, bent arms pumping hard against the
-- legs, high knees on the forward leg, a little hop at each footfall and the head
-- held up and steady.
local function runPose(phase: number): Pose
	local s, c = math.sin(phase), math.cos(phase)
	local fwdR = math.max(0, c) -- right leg coming through
	local fwdL = math.max(0, -c)
	local hop = math.abs(math.sin(phase)) -- 0 at each footfall, 1 mid-stride
	return {
		Root = V(-12, 7 * s, 0),
		Waist = V(-4 - 2 * hop, -13 * s, 0),
		Neck = V(10 + 2 * hop, 6 * s, 0),
		RightHip = V(52 * s + 6, 0, 0),
		LeftHip = V(-52 * s + 6, 0, 0),
		RightKnee = V(-14 - 78 * fwdR - 22 * fwdL, 0, 0),
		LeftKnee = V(-14 - 78 * fwdL - 22 * fwdR, 0, 0),
		RightAnkle = V(18 * s - 6 * fwdL, 0, 0),
		LeftAnkle = V(-18 * s - 6 * fwdR, 0, 0),
		RightShoulder = V(-58 * s + 8, 0, 8),
		LeftShoulder = V(58 * s + 8, 0, -8),
		RightElbow = V(82 + 14 * math.max(0, s), 0, 0),
		LeftElbow = V(82 + 14 * math.max(0, -s), 0, 0),
		RightWrist = V(-10, 0, 0),
		LeftWrist = V(-10, 0, 0),
		RootPos = V(0, 0.32 * hop - 0.22, 0),
	}
end

local function airPose(rising: boolean): Pose
	if rising then
		return {
			RightHip = V(34, 0, 0), RightKnee = V(-56, 0, 0), LeftHip = V(-8, 0, 0), LeftKnee = V(-24, 0, 0),
			RightAnkle = V(-10, 0, 0), LeftAnkle = V(-14, 0, 0),
			RightShoulder = V(30, 0, 26), LeftShoulder = V(-10, 0, -30), RightElbow = V(30, 0, 0), LeftElbow = V(24, 0, 0),
			Waist = V(-4, 0, 0), Neck = V(4, 0, 0),
		}
	end
	return {
		RightHip = V(14, 0, 0), RightKnee = V(-22, 0, 0), LeftHip = V(6, 0, 0), LeftKnee = V(-12, 0, 0),
		RightAnkle = V(8, 0, 0), LeftAnkle = V(8, 0, 0),
		RightShoulder = V(14, 0, 58), LeftShoulder = V(14, 0, -58), RightElbow = V(18, 0, 0), LeftElbow = V(18, 0, 0),
		Waist = V(4, 0, 0), Neck = V(6, 0, 0),
	}
end

-- Sampling one-off animations -----------------------------------------------------------

-- Samples keys on top of `under`. Absolute joints blend from/to `under`; the rest
-- (and every joint when `additive` is set) are offsets that blend from/to zero.
local function sample(keys: { Key }, under: Pose, t: number, scale: number?, additive: boolean?): (Pose, boolean)
	if t >= keys[#keys].t then
		return under, true
	end
	local k = scale or 1
	local a, b = keys[1], keys[#keys]
	for i = 1, #keys - 1 do
		if t >= keys[i].t and t < keys[i + 1].t then
			a, b = keys[i], keys[i + 1]
			break
		end
	end
	local f = smooth((t - a.t) / (b.t - a.t))
	local out = table.clone(under)
	local joints = {}
	for _, key in { a, b } do
		for j in key.pose or {} do
			joints[j] = true
		end
	end
	for j in joints do
		if ABSOLUTE[j] and not additive then
			local va = if a.pose and a.pose[j] then a.pose[j] else get(under, j)
			local vb = if b.pose and b.pose[j] then b.pose[j] else get(under, j)
			out[j] = va:Lerp(vb, f)
		else
			local va = if a.pose and a.pose[j] then a.pose[j] else Vector3.zero
			local vb = if b.pose and b.pose[j] then b.pose[j] else Vector3.zero
			out[j] = get(under, j) + va:Lerp(vb, f) * k
		end
	end
	return out, false
end

local function jointFrame(motor: any): CFrame
	-- The frame the Transform is applied in (C0 for a Motor6D, Attachment0 for a constraint).
	if motor:IsA("Motor6D") then
		return motor.C0
	end
	local a = motor.Attachment0
	return if a then a.CFrame else CFrame.identity
end

local function apply(character: Model, pose: Pose, weight: number?)
	local rootPos = get(pose, "RootPos")
	for joint, motor in motorsOf(character) do
		-- Only the joints this pose moves: the rest keep Roblox's own animation.
		if pose[joint] == nil and not (joint == "Root" and pose.RootPos) then
			continue
		end
		local base = baseC0[motor]
		if not base then
			base = jointFrame(motor)
			baseC0[motor] = base
		end
		local v = get(pose, joint)
		local cf = CFrame.Angles(math.rad(v.X), math.rad(v.Y), math.rad(v.Z))
		if joint == "Root" then
			-- RootPos is in the parent part's space; Transform works in the joint's frame.
			cf = CFrame.new(base:VectorToObjectSpace(rootPos)) * cf
		end
		if weight and weight < 1 then
			-- Blend from whatever Roblox's animation wrote this frame.
			cf = motor.Transform:Lerp(cf, weight)
		end
		motor.Transform = cf
	end
end

-- Watching for equipment changes -------------------------------------------------------

local function flash(model: Instance)
	local h = Instance.new("Highlight")
	h.Adornee = model
	h.FillColor = Color3.fromRGB(255, 244, 214)
	h.OutlineColor = Color3.fromRGB(255, 236, 180)
	h.FillTransparency = 0.35
	h.OutlineTransparency = 0.2
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = model
	local tween = TweenService:Create(h, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FillTransparency = 1, OutlineTransparency = 1 })
	tween:Play()
	tween.Completed:Once(function()
		h:Destroy()
	end)
end

local function readArmour(folder: Instance): { [string]: string }
	local out = {}
	for _, piece in folder:GetChildren() do
		local slot, item = piece:GetAttribute("Slot"), piece:GetAttribute("ItemId")
		if typeof(slot) == "string" and typeof(item) == "string" then
			out[slot] = item
		end
	end
	return out
end

local function startAction(s: State, name: string)
	s.action = { name = name, start = os.clock() }
end

local function watchEquipment(character: Model, s: State, now: number)
	local settled = now - s.born > 1.5 -- don't animate the gear you spawn with

	local held = character:FindFirstChild("HeldItem")
	local heldId = held and held:GetAttribute("ItemId")
	heldId = if typeof(heldId) == "string" then heldId else nil
	if heldId ~= s.held then
		if settled and not s.action then
			startAction(s, if heldId then "draw" else "stow")
		end
		s.held = heldId
	end

	local folder = character:FindFirstChild("Armour")
	if folder ~= s.armourFolder then
		s.armourFolder = folder
		local now_ = if folder then readArmour(folder) else {}
		local before = s.armour or {}
		s.armour = now_
		if settled then
			for _, slot in DRESS_ORDER do
				if now_[slot] and now_[slot] ~= before[slot] then
					startAction(s, "dress_" .. slot)
					break
				end
			end
			if folder then
				for _, piece in folder:GetChildren() do
					local slot = piece:GetAttribute("Slot")
					if typeof(slot) == "string" and now_[slot] ~= before[slot] then
						flash(piece)
					end
				end
			end
		end
	end
end

-- Per-frame update --------------------------------------------------------------------------

local function step(player: Player, character: Model, s: State, now: number, dt: number)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		return
	end

	-- Movement.
	local vel = root.AssemblyLinearVelocity
	local flat = Vector3.new(vel.X, 0, vel.Z).Magnitude
	s.speed += (flat - s.speed) * math.min(1, dt * 10)
	local inAir
	if player == Players.LocalPlayer then
		inAir = humanoid.FloorMaterial == Enum.Material.Air
	else
		inAir = math.abs(vel.Y) > 7
	end
	if inAir and not s.airborne then
		s.airborne = true
		s.airSince = now
	elseif not inAir and s.airborne then
		s.airborne = false
		if now - s.airSince > 0.25 and not s.react then
			s.react = { name = "land", start = now, scale = math.clamp(s.fallSpeed / 50, 0.35, 1) }
		end
	end
	if inAir then
		s.fallSpeed = math.max(0, -vel.Y)
	end
	local airTarget = if s.airborne and now - s.airSince > 0.08 then 1 else 0
	s.air += (airTarget - s.air) * math.min(1, dt * 12)

	-- Hurt flinch.
	local hp = humanoid.Health
	if s.health and hp < s.health - 0.5 and hp > 0 then
		s.react = { name = "hurt", start = now, scale = 1 }
	end
	s.health = hp

	watchEquipment(character, s, now)

	-- Running on the ground is our own (runPose); idle, jumping, swimming and climbing
	-- stay Roblox's default animations. The run fades in and out over Roblox's pose.
	local state = humanoid:GetState()
	local grounded = not s.airborne and state ~= Enum.HumanoidStateType.Swimming and state ~= Enum.HumanoidStateType.Climbing and state ~= Enum.HumanoidStateType.Seated
	local runTarget = if grounded and s.speed > 1.5 then math.clamp((s.speed - 1.5) / 5, 0, 1) else 0
	s.run = (s.run or 0) + (runTarget - (s.run or 0)) * math.min(1, dt * 10)
	if s.run > 0.01 then
		-- About one full stride (two steps) per 7.5 studs.
		s.phase += dt * math.max(s.speed, 6) / 7.5 * math.pi * 2
		apply(character, runPose(s.phase), s.run)
	end

	-- The tool-holding arm and one-off actions go on top, on just the joints they use.
	local pose: Pose = {}
	if character:FindFirstChild("HeldItem") then
		for joint, v in HOLD do
			pose[joint] = v
		end
	end

	-- 3. One-off action.
	local a = s.action
	if a then
		local keys = ANIMS[a.name]
		local out, done = sample(keys, pose, now - a.start)
		if done then
			s.action = nil
		else
			pose = out
		end
	end

	apply(character, pose)
end

-- Public -------------------------------------------------------------------------------------

function Anim.play(character: Model?, name: string)
	if character and ANIMS[name] then
		startAction(stateOf(character), name)
	end
end

-- How long an animation lasts, in seconds.
function Anim.length(name: string): number
	local keys = ANIMS[name]
	return if keys then keys[#keys].t else 0
end

function Anim.isPlaying(character: Model?): boolean
	local s = character and states[character]
	return s ~= nil and s.action ~= nil
end

function Anim.start()
	local last = os.clock()
	-- PreSimulation runs after the Animator has written its own Transforms, so ours win.
	RunService.PreSimulation:Connect(function()
		local now = os.clock()
		local dt = math.min(now - last, 0.1)
		last = now
		for _, player in Players:GetPlayers() do
			local character = player.Character
			if character and character.Parent then
				step(player, character, stateOf(character), now, dt)
			end
		end
	end)
end

return Anim
