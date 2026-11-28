-- Plant boxes: plant a seed, wait for it to grow, harvest the crop (and seeds to
-- plant again). A box shows its crop growing in three stages: sprouts, leafy, ripe.
-- What's planted and when is kept on the box's attributes, and saved with your base.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Items)
local Remotes = require(Shared.Remotes)
local Inventory = require(script.Parent.Inventory)

local Farming = {}

local rng = Random.new()
local boxes: { [Model]: { plant: ProximityPrompt, harvest: ProximityPrompt, stage: number } } = {}

local LEAF = Color3.fromRGB(92, 168, 62)
local LEAF_DARK = Color3.fromRGB(62, 128, 44)

local function deco(parent: Instance, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = parent
	return p
end

-- The plants on top of the soil, for the crop and stage (1 sprouts, 2 leafy, 3 ripe).
local function drawCrop(box: Model, crop: string?, stage: number)
	local old = box:FindFirstChild("Crop")
	if old then
		old:Destroy()
	end
	local core = box.PrimaryPart
	if not crop or stage <= 0 or not core then
		return
	end
	local folder = Instance.new("Model")
	folder.Name = "Crop"
	local top = core.CFrame * CFrame.new(0, core.Size.Y / 2, 0)
	local half = core.Size.X / 2 - 1.4
	local spots = {}
	if crop == "watermelon" or crop == "coconut" then
		spots = { Vector3.new(0, 0, 0) }
	else
		for x = -1, 1 do
			for z = -1, 1, 2 do
				table.insert(spots, Vector3.new(x * half * 0.7, 0, z * half * 0.5))
			end
		end
	end
	local grow = ({ 0.35, 0.7, 1 })[stage]
	for i, o in spots do
		local at = top * CFrame.new(o) * CFrame.Angles(0, i * 1.3, 0)
		if crop == "coconut" then
			-- A young palm: a curved trunk and a crown of fronds, nuts when ripe.
			local h = 5 * grow
			deco(folder, { Size = Vector3.new(0.6, h, 0.6), CFrame = at * CFrame.new(0, h / 2, 0) * CFrame.Angles(0, 0, math.rad(6)), Color = Color3.fromRGB(150, 110, 70), Material = Enum.Material.Wood })
			for k = 0, 5 do
				local a = k / 6 * math.pi * 2
				deco(folder, { Size = Vector3.new(0.2, 0.6 * grow + 0.2, 3.2 * grow + 0.4), CFrame = at * CFrame.new(0, h, 0) * CFrame.Angles(0, a, 0) * CFrame.Angles(math.rad(-25), 0, 0) * CFrame.new(0, 0, -1.4 * grow), Color = if k % 2 == 0 then LEAF else LEAF_DARK, Material = Enum.Material.Grass })
			end
			if stage == 3 then
				for k = 0, 2 do
					local a = k / 3 * math.pi * 2
					deco(folder, { Shape = Enum.PartType.Ball, Size = Vector3.new(0.8, 0.8, 0.8), CFrame = at * CFrame.new(math.cos(a) * 0.5, h - 0.4, math.sin(a) * 0.5), Color = Color3.fromRGB(110, 74, 44), Material = Enum.Material.Wood })
				end
			end
		elseif crop == "watermelon" then
			for k = 0, 4 do
				local a = k / 5 * math.pi * 2
				deco(folder, { Size = Vector3.new(1.2 * grow + 0.4, 0.15, 1.2 * grow + 0.4), CFrame = at * CFrame.new(math.cos(a) * 1.6 * grow, 0.2, math.sin(a) * 1.6 * grow) * CFrame.Angles(0, a, 0), Color = LEAF, Material = Enum.Material.Grass })
			end
			if stage >= 2 then
				local s = if stage == 3 then 2.4 else 1.2
				local melon = deco(folder, { Shape = Enum.PartType.Ball, Size = Vector3.new(s * 1.25, s, s), CFrame = at * CFrame.new(0.6, s / 2, 0.4) * CFrame.Angles(0, 0.4, 0), Color = Color3.fromRGB(56, 128, 52), Material = Enum.Material.SmoothPlastic })
				for k = -1, 1 do
					deco(folder, { Shape = Enum.PartType.Ball, Size = Vector3.new(s * 1.27, s * 1.02, s * 0.16), CFrame = melon.CFrame * CFrame.new(0, 0, k * s * 0.3), Color = Color3.fromRGB(34, 86, 34) })
				end
			end
		elseif crop == "slime" then
			local s = 0.7 + grow * 0.9
			local colour = if stage == 3 then Color3.fromRGB(120, 220, 110) else Color3.fromRGB(150, 200, 120)
			deco(folder, { Size = Vector3.new(0.15, 0.5 + grow, 0.15), CFrame = at * CFrame.new(0, (0.5 + grow) / 2, 0), Color = LEAF_DARK })
			deco(folder, { Shape = Enum.PartType.Ball, Size = Vector3.new(s, s * 0.8, s), CFrame = at * CFrame.new(0, 0.5 + grow + s * 0.3, 0), Color = colour, Material = Enum.Material.Glass, Transparency = 0.15 })
		else
			-- Carrots and potatoes: leafy tops, and when ripe the crop showing at the soil.
			local h = 0.6 + 1.6 * grow
			for k = 0, 2 do
				local a = k / 3 * math.pi * 2
				deco(folder, { Size = Vector3.new(0.18, h, 0.5), CFrame = at * CFrame.Angles(0, a, 0) * CFrame.Angles(math.rad(14), 0, 0) * CFrame.new(0, h / 2, 0), Color = if crop == "carrot" then Color3.fromRGB(96, 176, 64) else LEAF_DARK, Material = Enum.Material.Grass })
			end
			if stage == 3 then
				if crop == "carrot" then
					deco(folder, { Size = Vector3.new(0.6, 0.35, 0.6), CFrame = at * CFrame.new(0, 0.1, 0), Color = Color3.fromRGB(236, 128, 40) })
				else
					deco(folder, { Shape = Enum.PartType.Ball, Size = Vector3.new(0.9, 0.6, 0.7), CFrame = at * CFrame.new(0.3, 0.15, 0), Color = Color3.fromRGB(176, 136, 86) })
				end
			end
		end
	end
	folder.Parent = box
end

local function stageOf(box: Model): number
	local crop = box:GetAttribute("Crop")
	local at = box:GetAttribute("PlantedAt")
	local def = crop and Items.CROPS[crop]
	if not def or not at then
		return 0
	end
	local frac = (os.time() - at) / def.grow
	return if frac >= 1 then 3 elseif frac >= 0.45 then 2 else 1
end

local function refresh(box: Model)
	local b = boxes[box]
	if not b then
		return
	end
	local stage = stageOf(box)
	local crop = box:GetAttribute("Crop")
	if stage ~= b.stage then
		b.stage = stage
		drawCrop(box, crop, stage)
	end
	-- While it grows the plant prompt shows how long is left instead.
	b.plant.Enabled = stage < 3
	b.plant.ActionText = if crop then "Growing" else "Plant seeds"
	b.harvest.Enabled = stage == 3
	if crop and stage < 3 then
		local def = Items.CROPS[crop]
		local left = math.max(0, def.grow - (os.time() - (box:GetAttribute("PlantedAt") or os.time())))
		box:SetAttribute("Status", (Items[def.seed] and Items[def.seed].name or crop) .. ": ready in " .. (if left >= 60 then math.ceil(left / 60) .. " min" else math.ceil(left) .. "s"))
	elseif crop then
		box:SetAttribute("Status", "Ready to harvest")
	else
		box:SetAttribute("Status", "Empty: plant seeds")
	end
	b.plant.ObjectText = box:GetAttribute("Status")
end

-- Which seed a player plants: the one they're holding, else the one they have most of.
local function pickSeed(player: Player): string?
	local held = Inventory.getEquipped(player)
	if held and Items[held] and Items[held].crop and Inventory.count(player, held) > 0 then
		return held
	end
	local best, bestN = nil, 0
	for id, n in Inventory.getAll(player) do
		local item = Items[id]
		if item and item.kind == "seed" and n > bestN then
			best, bestN = id, n
		end
	end
	return best
end

local function canUse(player: Player, box: Model): boolean
	local owner = box:GetAttribute("OwnerId")
	return owner == nil or owner == player.UserId or (player:GetAttribute("Tribe") ~= nil and player:GetAttribute("Tribe") == box:GetAttribute("OwnerTribe"))
end

local function plant(player: Player, box: Model)
	if box:GetAttribute("Crop") then
		return
	end
	if not canUse(player, box) then
		Remotes.Notify:FireClient(player, "That plant box isn't yours", "warn")
		return
	end
	local seed = pickSeed(player)
	if not seed then
		Remotes.Notify:FireClient(player, "You need seeds: dig up wild crops for some", "warn")
		return
	end
	if not Inventory.takeAll(player, { [seed] = 1 }) then
		return
	end
	local crop = Items[seed].crop
	box:SetAttribute("Crop", crop)
	box:SetAttribute("PlantedAt", os.time())
	refresh(box)
	Remotes.Notify:FireClient(player, "Planted " .. Items[seed].name, "good")
end

local function harvest(player: Player, box: Model)
	local crop = box:GetAttribute("Crop")
	local def = crop and Items.CROPS[crop]
	if not def or stageOf(box) < 3 then
		return
	end
	if not canUse(player, box) then
		Remotes.Notify:FireClient(player, "That plant box isn't yours", "warn")
		return
	end
	local got = {}
	for _, y in def.yield do
		local item = y[1]
		if item == "*" and def.variants then
			local total = 0
			for _, v in def.variants do
				total += v[2]
			end
			local roll = rng:NextNumber(0, total)
			for _, v in def.variants do
				roll -= v[2]
				if roll <= 0 then
					item = v[1]
					break
				end
			end
		end
		local n = rng:NextInteger(y[2], y[3])
		if Items[item] and n > 0 then
			Inventory.add(player, item, n, true)
			table.insert(got, n .. " " .. Items[item].name)
		end
	end
	local back = rng:NextInteger(def.seeds[1], def.seeds[2])
	if back > 0 then
		Inventory.add(player, def.seed, back, true)
		table.insert(got, back .. " " .. Items[def.seed].name)
	end
	box:SetAttribute("Crop", nil)
	box:SetAttribute("PlantedAt", nil)
	refresh(box)
	Remotes.Notify:FireClient(player, "Harvested " .. table.concat(got, ", "), "good")
end

-- Called by Building when a plant box is built. `saved` is what export() gave.
function Farming.setup(box: Model, saved: any?)
	local core = box.PrimaryPart
	if not core then
		return
	end
	if type(saved) == "table" and type(saved.crop) == "string" and Items.CROPS[saved.crop] then
		box:SetAttribute("Crop", saved.crop)
		-- Saved as seconds grown, so time offline doesn't count against you or for you.
		box:SetAttribute("PlantedAt", os.time() - math.clamp(tonumber(saved.grown) or 0, 0, 1e6))
	end
	local function prompt(text: string): ProximityPrompt
		local p = Instance.new("ProximityPrompt")
		p.ActionText = text
		p.ObjectText = "Plant Box"
		p.KeyboardKeyCode = Enum.KeyCode.E
		p.HoldDuration = 0.4
		p.MaxActivationDistance = 10
		p.RequiresLineOfSight = false
		p.Parent = core
		return p
	end
	local b = { plant = prompt("Plant seeds"), harvest = prompt("Harvest"), stage = -1 }
	boxes[box] = b
	b.plant.Triggered:Connect(function(player)
		plant(player, box)
	end)
	b.harvest.Triggered:Connect(function(player)
		harvest(player, box)
	end)
	box.Destroying:Connect(function()
		boxes[box] = nil
	end)
	refresh(box)
end

function Farming.export(box: Model): any?
	local crop = box:GetAttribute("Crop")
	if not crop then
		return nil
	end
	return { crop = crop, grown = os.time() - (box:GetAttribute("PlantedAt") or os.time()) }
end

function Farming.start()
	task.spawn(function()
		while true do
			task.wait(2)
			for box in boxes do
				if box.Parent then
					refresh(box)
				else
					boxes[box] = nil
				end
			end
		end
	end)
end

local _ = Players
return Farming
