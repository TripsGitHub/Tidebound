-- Drives the raft or cart you're sitting in. The server gives the driver's client
-- physics ownership (server/Vehicles.lua), so we steer the movers right here every
-- frame: W/S for speed, A/D to turn. Rafts stop at the shore, carts at the sea.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local Vehicles = {}

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.IgnoreWater = false

local function surfaceAt(at: Vector3): RaycastResult?
	params.FilterDescendantsInstances = { workspace.Terrain }
	return workspace:Raycast(Vector3.new(at.X, at.Y + 30, at.Z), Vector3.new(0, -80, 0), params)
end

local current: { model: Model, seat: VehicleSeat, root: BasePart, vel: LinearVelocity, align: AlignOrientation, yaw: number, speed: number }? = nil
local probeT = 0
local blocked = false

local function release()
	if current then
		current.vel.PlaneVelocity = Vector2.zero
	end
	current = nil
end

local function onSeated(active: boolean, seat: Instance?)
	release()
	if not active or not seat or not seat:IsA("VehicleSeat") then
		return
	end
	local model = seat:FindFirstAncestorWhichIsA("Model")
	while model and not model:GetAttribute("Vehicle") do
		model = model:FindFirstAncestorWhichIsA("Model")
	end
	if not model then
		return
	end
	local vel = model:FindFirstChild("Drive", true) :: LinearVelocity?
	local align = model:FindFirstChild("Steer", true) :: AlignOrientation?
	if not vel or not align or not vel.Parent or not vel.Parent:IsA("BasePart") then
		return
	end
	local root = vel.Parent :: BasePart
	local _, yaw = align.CFrame:ToOrientation()
	current = { model = model, seat = seat, root = root, vel = vel, align = align, yaw = yaw, speed = 0 }
	blocked = false
end

local function hook(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if humanoid then
		humanoid.Seated:Connect(onSeated)
	end
end

function Vehicles.start()
	if player.Character then
		task.spawn(hook, player.Character)
	end
	player.CharacterAdded:Connect(hook)
	RunService.Heartbeat:Connect(function(dt)
		local c = current
		if not c then
			return
		end
		if not c.model.Parent or c.seat.Occupant == nil then
			release()
			return
		end
		local kind = c.model:GetAttribute("Vehicle")
		local top = c.model:GetAttribute("Speed") or 24
		local turn = c.model:GetAttribute("Turn") or 1.8
		local throttle, steer = c.seat.ThrottleFloat, c.seat.SteerFloat
		-- Turn more slowly at a standstill, and the right way round when backing up.
		local moving = math.clamp(math.abs(c.speed) / math.max(top * 0.35, 1), 0.35, 1)
		c.yaw -= steer * turn * moving * dt * (if c.speed < -0.5 then -1 else 1)
		c.align.CFrame = CFrame.Angles(0, c.yaw, 0)
		local target = throttle * top * (if throttle < 0 then 0.45 else 1)
		local ease = if math.abs(target) > math.abs(c.speed) then 1.4 else 2.6
		c.speed += (target - c.speed) * math.min(1, dt * ease)

		local fwdLocal = c.model:GetAttribute("Forward")
		local base = CFrame.Angles(0, c.yaw, 0)
		local forward = if typeof(fwdLocal) == "Vector3" then base:VectorToWorldSpace(fwdLocal) else base.LookVector
		-- Look ahead now and then: rafts stay on open water, carts stay off it.
		probeT += dt
		if probeT > 0.12 then
			probeT = 0
			blocked = false
			if math.abs(c.speed) > 0.5 then
				local ahead = c.root.Position + forward * (6 + math.abs(c.speed) * 0.2) * math.sign(c.speed)
				local hit = surfaceAt(ahead)
				if kind == "raft" then
					blocked = not hit or hit.Material ~= Enum.Material.Water or hit.Position.Y < -2
				elseif kind == "cart" then
					blocked = hit ~= nil and hit.Material == Enum.Material.Water
				end
			end
		end
		if blocked and math.sign(target) == math.sign(c.speed) then
			c.speed *= 0.5
		end
		local v = forward * c.speed
		c.vel.PlaneVelocity = Vector2.new(v.X, v.Z)
	end)
end

return Vehicles
