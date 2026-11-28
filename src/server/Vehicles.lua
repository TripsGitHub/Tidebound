-- Driveable rafts and carts. The server rigs a vehicle (welds it to one root part,
-- adds a seat and the movers) and hands physics to whoever sits in the seat; that
-- player's client (client/Vehicles.lua) steers it every frame, so driving feels
-- instant instead of lagging a round trip behind your keys.
--
-- A vehicle model carries: Vehicle = "raft" | "cart", Speed (studs/s), Turn (rad/s).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local Vehicles = {}

export type Rig = { root: BasePart, seat: VehicleSeat, vel: LinearVelocity, align: AlignOrientation }

local function weldAll(model: Model, root: BasePart)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p ~= root then
			p.Anchored = false
			p.Massless = true
			if not p:FindFirstChildOfClass("WeldConstraint") then
				local w = Instance.new("WeldConstraint")
				w.Part0, w.Part1 = root, p
				w.Parent = p
			end
		end
	end
	root.Anchored = false
end

-- kind: "raft" (floats at waterY) or "cart" (rolls on the ground under gravity).
-- seatCf: where the seat goes. Returns the movers so callers can stop it.
function Vehicles.rig(model: Model, root: BasePart, kind: string, speed: number, seatCf: CFrame, opts: { waterY: number?, turn: number?, hint: string? }?): Rig
	local o = opts or {}
	model:SetAttribute("Vehicle", kind)
	model:SetAttribute("Speed", speed)
	model:SetAttribute("Turn", o.turn or (if kind == "raft" then 1.5 else 2.2))

	local seat = model:FindFirstChildWhichIsA("VehicleSeat") :: VehicleSeat?
	if not seat then
		local s = Instance.new("VehicleSeat")
		s.Name = "Seat"
		s.Size = Vector3.new(2.2, 0.4, 2.2)
		s.CFrame = seatCf
		s.Color = Color3.fromRGB(104, 72, 45)
		s.Material = Enum.Material.WoodPlanks
		s.TopSurface = Enum.SurfaceType.Smooth
		s.Parent = model
		seat = s
	end
	local vs = seat :: VehicleSeat
	vs.MaxSpeed = 0
	vs.Torque = 0
	vs.HeadsUpDisplay = false
	weldAll(model, root)

	local att = root:FindFirstChild("DriveAttachment") :: Attachment?
	if not att then
		att = Instance.new("Attachment")
		att.Name = "DriveAttachment"
		att.Parent = root
	end
	local a = att :: Attachment
	local mass = 0
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			mass += p:GetMass()
		end
	end
	local push = math.max(mass, 40) * 600

	if kind == "raft" then
		local hold = Instance.new("AlignPosition")
		hold.Name = "Float"
		hold.Mode = Enum.PositionAlignmentMode.OneAttachment
		hold.Attachment0 = a
		hold.ForceLimitMode = Enum.ForceLimitMode.PerAxis
		hold.MaxAxesForce = Vector3.new(0, push * 4, 0)
		hold.Position = Vector3.new(0, o.waterY or 0.55, 0)
		hold.Responsiveness = 30
		hold.Parent = root
	end
	local align = Instance.new("AlignOrientation")
	align.Name = "Steer"
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = a
	align.MaxTorque = push * 200
	align.Responsiveness = 25
	local _, yaw = root.CFrame:ToOrientation()
	align.CFrame = CFrame.Angles(0, yaw, 0)
	align.Parent = root
	local vel = Instance.new("LinearVelocity")
	vel.Name = "Drive"
	vel.Attachment0 = a
	vel.RelativeTo = Enum.ActuatorRelativeTo.World
	vel.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	vel.PrimaryTangentAxis = Vector3.xAxis
	vel.SecondaryTangentAxis = Vector3.zAxis
	vel.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	vel.MaxAxesForce = Vector3.new(push, 0, push)
	-- Plane mode uses the planar limit (default 1000, far too weak: carts stood still
	-- and rafts crawled). Found in Studio.
	vel.MaxPlanarAxesForce = Vector2.new(push, push)
	vel.PlaneVelocity = Vector2.zero
	vel.Parent = root

	local hint = o.hint or (if kind == "raft" then "W/S to row, A/D to turn, Space to hop off" else "W/S to drive, A/D to steer, Space to hop off")
	-- G to get in (as well as walking onto the seat).
	local ride = Instance.new("ProximityPrompt")
	ride.Name = "RidePrompt"
	ride.ActionText = if kind == "raft" then "Board" else "Ride"
	ride.ObjectText = model:GetAttribute("DisplayName") or (if kind == "raft" then "Raft" else "Cart")
	ride.KeyboardKeyCode = Enum.KeyCode.G
	ride.GamepadKeyCode = Enum.KeyCode.ButtonY
	ride.HoldDuration = 0
	ride.MaxActivationDistance = 12
	ride.RequiresLineOfSight = false
	ride.UIOffset = Vector2.new(0, -40)
	ride.Parent = vs
	ride.Triggered:Connect(function(player)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 and not vs.Occupant and not humanoid.SeatPart then
			vs:Sit(humanoid)
		end
	end)
	-- A parked cart just rests on the ground under gravity; it only holds its
	-- heading while someone drives it. Rafts always stay level on the water.
	local function settle(driving: boolean)
		if kind == "cart" then
			align.Enabled = driving
			vel.Enabled = driving
		end
		ride.Enabled = not driving
	end
	settle(false)
	vs:GetPropertyChangedSignal("Occupant"):Connect(function()
		local occupant = vs.Occupant
		local driver = occupant and Players:GetPlayerFromCharacter(occupant.Parent)
		if not driver then
			vel.PlaneVelocity = Vector2.zero
		end
		settle(occupant ~= nil)
		pcall(function()
			root:SetNetworkOwner(driver)
		end)
		if driver then
			Remotes.Notify:FireClient(driver, hint)
		end
	end)
	return { root = root, seat = vs, vel = vel, align = align }
end

return Vehicles
