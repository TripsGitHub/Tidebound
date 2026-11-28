-- Rafts: use a raft item at the shore to put it in the water, sit on it and sail.
-- W/S row forward and back, A/D turn. The raft can't sail up onto land.
-- One raft per player: launching another packs the old one back into your bag.
-- Driving is done by the driver's own client (see Vehicles).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Items)
local Remotes = require(Shared.Remotes)
local Inventory = require(script.Parent.Inventory)
local Vehicles = require(script.Parent.Vehicles)

local Rafts = {}

local SEA_Y = 0 -- the top of the sea (WorldBuilder fills the water up to y = 0)
local FLOAT = 0.55 -- how high the deck's centre sits above the water

type Raft = { model: Model, root: BasePart, seat: VehicleSeat, owner: Player, itemId: string, yaw: number, speed: number, vel: LinearVelocity, align: AlignOrientation }

local active: { [Player]: Raft } = {}

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.IgnoreWater = false

-- Is the sea open (no land poking above the water) at this x/z?
local function openWater(at: Vector3): boolean
	params.FilterDescendantsInstances = { workspace.Terrain }
	local hit = workspace:Raycast(Vector3.new(at.X, SEA_Y + 30, at.Z), Vector3.new(0, -60, 0), params)
	return hit ~= nil and hit.Material == Enum.Material.Water and hit.Position.Y > SEA_Y - 2
end

local WOOD = Color3.fromRGB(141, 101, 64)
local WOOD_DARK = Color3.fromRGB(104, 72, 45)

local function part(model: Model, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.Wood
	p.Color = WOOD
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = model
	return p
end

local function build(itemId: string, cf: CFrame): (Model, BasePart, VehicleSeat)
	local model = Instance.new("Model")
	model.Name = Items[itemId].name
	local logs = if itemId == "gold_raft" then 7 else 6
	local width = logs * 1.5
	local root = part(model, { Name = "Root", Size = Vector3.new(width, 0.6, 9), CFrame = cf, Transparency = 1, CanCollide = true })
	root.CustomPhysicalProperties = PhysicalProperties.new(0.3, 0.3, 0)
	local colour = if itemId == "log_raft" then WOOD else WOOD_DARK
	for i = 1, logs do
		local x = (i - (logs + 1) / 2) * 1.5
		local log = part(model, {
			Name = "Log",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(9 + (i % 2) * 0.6, 1.5, 1.5),
			CFrame = cf * CFrame.new(x, 0, 0) * CFrame.Angles(0, math.rad(90), 0),
			Color = colour:Lerp(Color3.new(0, 0, 0), (i % 3) * 0.05),
			CanCollide = false,
			Massless = true,
		})
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1 = root, log
		w.Parent = log
	end
	for _, z in { -3, 3 } do
		local band = part(model, { Name = "Rope", Size = Vector3.new(width + 0.2, 0.35, 0.5), CFrame = cf * CFrame.new(0, 0.65, z), Color = Color3.fromRGB(122, 74, 42), Material = Enum.Material.Fabric, CanCollide = false, Massless = true })
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1 = root, band
		w.Parent = band
	end
	if itemId ~= "log_raft" then
		local mast = part(model, { Name = "Mast", Size = Vector3.new(0.5, 10, 0.5), CFrame = cf * CFrame.new(0, 5.6, -1), Color = WOOD_DARK, CanCollide = false, Massless = true })
		local sail = part(model, {
			Name = "Sail",
			Size = Vector3.new(width - 1.5, 6.5, 0.15),
			CFrame = cf * CFrame.new(0, 6.6, -1.4),
			Color = if itemId == "gold_raft" then Color3.fromRGB(176, 52, 48) else Color3.fromRGB(238, 228, 200),
			Material = Enum.Material.Fabric,
			CanCollide = false,
			Massless = true,
		})
		for _, p in { mast, sail } do
			local w = Instance.new("WeldConstraint")
			w.Part0, w.Part1 = root, p
			w.Parent = p
		end
		if itemId == "gold_raft" then
			for _, x in { -width / 2, width / 2 } do
				local trim = part(model, { Name = "Trim", Size = Vector3.new(0.3, 0.4, 9.4), CFrame = cf * CFrame.new(x, 0.75, 0), Color = Color3.fromRGB(236, 192, 72), Material = Enum.Material.Metal, CanCollide = false, Massless = true })
				local w = Instance.new("WeldConstraint")
				w.Part0, w.Part1 = root, trim
				w.Parent = trim
			end
		end
	end
	local seat = Instance.new("VehicleSeat")
	seat.Name = "Seat"
	seat.Size = Vector3.new(2, 0.4, 2)
	seat.CFrame = cf * CFrame.new(0, 1, 2.2)
	seat.Color = WOOD_DARK
	seat.Material = Enum.Material.WoodPlanks
	seat.TopSurface = Enum.SurfaceType.Smooth
	seat.MaxSpeed = 0
	seat.Torque = 0
	seat.HeadsUpDisplay = false
	seat.Massless = true
	seat.Parent = model
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = root, seat
	w.Parent = seat
	model.PrimaryPart = root
	return model, root, seat
end

local function pack(r: Raft, refund: boolean)
	if active[r.owner] == r then
		active[r.owner] = nil
	end
	if refund and r.owner.Parent then
		Inventory.add(r.owner, r.itemId, 1, true)
	end
	r.model:Destroy()
end

function Rafts.launch(player: Player, itemId: unknown)
	if type(itemId) ~= "string" or not Items.RAFTS[itemId] or Inventory.count(player, itemId) < 1 then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	-- Look for open water a few studs ahead of you.
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	look = if look.Magnitude > 0.01 then look.Unit else Vector3.new(0, 0, -1)
	local spot: Vector3? = nil
	for _, d in { 7, 10, 13, 4, 16 } do
		local at = root.Position + look * d
		if openWater(at) and openWater(at + look * 4) and (math.abs(root.Position.Y - SEA_Y) < 14) then
			spot = Vector3.new(at.X, SEA_Y + FLOAT, at.Z)
			break
		end
	end
	if not spot then
		Remotes.Notify:FireClient(player, "Face open water at the shore to put the raft in", "warn")
		return
	end
	if not Inventory.takeAll(player, { [itemId] = 1 }) then
		return
	end
	local old = active[player]
	if old then
		pack(old, true)
	end
	local spec = Items.RAFTS[itemId]
	local yaw = math.atan2(-look.X, -look.Z)
	local model, raftRoot, seat = build(itemId, CFrame.new(spot) * CFrame.Angles(0, yaw, 0))
	model:SetAttribute("Owner", player.UserId)
	model:SetAttribute("HP", spec.hp)
	model:SetAttribute("MaxHP", spec.hp)

	local rig = Vehicles.rig(model, raftRoot, "raft", spec.speed, seat.CFrame, { waterY = SEA_Y + FLOAT })
	local vel, align = rig.vel, rig.align

	-- Pack it up again (owner only, when nobody's aboard).
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Pack up"
	prompt.ObjectText = model.Name
	prompt.KeyboardKeyCode = Enum.KeyCode.R
	prompt.HoldDuration = 0.6
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = raftRoot

	local folder = workspace:FindFirstChild("Rafts")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Rafts"
		folder.Parent = workspace
	end
	model.Parent = folder
	local r: Raft = { model = model, root = raftRoot, seat = seat, owner = player, itemId = itemId, yaw = yaw, speed = 0, vel = vel, align = align }
	active[player] = r

	prompt.Triggered:Connect(function(who)
		if who ~= player then
			Remotes.Notify:FireClient(who, "That raft isn't yours", "warn")
		elseif seat.Occupant then
			Remotes.Notify:FireClient(who, "Get off the raft first", "warn")
		else
			pack(r, true)
		end
	end)
	Remotes.Notify:FireClient(player, "Raft launched: sit on it to sail", "good")
end

function Rafts.removePlayer(player: Player)
	local r = active[player]
	if r then
		pack(r, false)
	end
end

function Rafts.start()
	Remotes.Launch.OnServerEvent:Connect(Rafts.launch)
end

return Rafts
