-- The crate-opening screen. The crate slides in, shakes a little, pops open, and the
-- loot pops out one card at a time with its name and amount. Click (or wait) to close it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Items)
local ItemModels = require(Shared.ItemModels)
local Remotes = require(Shared.Remotes)
local UIKit = require(script.Parent.UIKit)
local Icons = require(script.Parent.Icons)

local player = Players.LocalPlayer
local CrateOpen = {}

local RARITY_OF: { [string]: string } = {}
for id, crate in Items.CRATES do
	RARITY_OF[id] = crate.rarity
end
-- How rare each loot item reads on its card: by the crate rarity it first appears in.
local ITEM_RARITY: { [string]: Color3 } = {}
for _, id in { "supply_crate", "rare_crate", "epic_crate", "mythic_crate" } do
	local crate = Items.CRATES[id]
	for _, line in crate.loot do
		if not ITEM_RARITY[line[1]] then
			ITEM_RARITY[line[1]] = crate.colour
		end
	end
end
for _, id in { "star_shard", "abyss_pearl", "ancient_rune" } do
	ITEM_RARITY[id] = Items.CRATES.mythic_crate.colour
end

local gui: ScreenGui
local queue = {}
local busy = false

local function tween(obj: Instance, t: number, props, style: Enum.EasingStyle?, dir: Enum.EasingDirection?)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function play(crateId: string, loot: { { any } })
	busy = true
	local crate = Items.CRATES[crateId]
	local colour = crate and crate.colour or Color3.new(1, 1, 1)
	local closed = false

	local root = UIKit.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	tween(root, 0.25, { BackgroundTransparency = 0.45 })

	-- The crate itself, in 3D.
	local vf = UIKit.new("ViewportFrame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, -0.2),
		Size = UDim2.fromOffset(260, 260),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(170, 170, 170),
		LightColor = Color3.fromRGB(255, 250, 235),
		LightDirection = Vector3.new(-1, -2, -1),
		Parent = root,
	})
	local model = ItemModels.build(crateId)
	local cf, size = model:GetBoundingBox()
	model:PivotTo(CFrame.Angles(math.rad(-18), math.rad(30), 0) * (cf:Inverse() * model:GetPivot()))
	model.Parent = vf
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	local dist = size.Magnitude / 2 / math.tan(math.rad(15)) * 1.3
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 0, dist), Vector3.zero)
	camera.Parent = vf
	vf.CurrentCamera = camera

	local title = UIKit.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.08),
		Size = UDim2.fromOffset(500, 44),
		Text = (crate and crate.rarity or "") .. " Crate",
		TextColor3 = colour,
		TextSize = 34,
		TextTransparency = 1,
		Parent = root,
	})
	tween(title, 0.3, { TextTransparency = 0 })

	-- Slam in: drops from above and lands hard with a jolt of the whole screen.
	local scale = Instance.new("UIScale")
	scale.Scale = 1.5
	scale.Parent = vf
	tween(vf, 0.14, { Position = UDim2.fromScale(0.5, 0.4) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	tween(scale, 0.14, { Scale = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.wait(0.14)
	local function jolt(power: number, time: number)
		task.spawn(function()
			local t0 = os.clock()
			while os.clock() - t0 < time and root.Parent do
				local k = 1 - (os.clock() - t0) / time
				root.Position = UDim2.fromOffset(math.random(-power, power) * k, math.random(-power, power) * k)
				RunService.RenderStepped:Wait()
			end
			root.Position = UDim2.fromOffset(0, 0)
		end)
	end
	jolt(10, 0.15)
	-- A quick, hard rattle that builds.
	local base = model:GetPivot()
	local t0 = os.clock()
	while os.clock() - t0 < 0.32 do
		local k = (os.clock() - t0) / 0.32
		local a = math.sin((os.clock() - t0) * 70) * (0.05 + 0.11 * k)
		model:PivotTo(base * CFrame.Angles(0, 0, a))
		scale.Scale = 1 - 0.06 * k -- squashes down before it bursts
		RunService.RenderStepped:Wait()
	end
	model:PivotTo(base)

	-- Burst: a white flash, a big screen jolt, the crate punches outward and the lid
	-- is blown off.
	local lidParts = {}
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p.Name == "Lid" then
			table.insert(lidParts, { p, p.CFrame })
		end
	end
	local flash = UIKit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.15, ZIndex = 20, Parent = root })
	tween(flash, 0.22, { BackgroundTransparency = 1 })
	jolt(18, 0.25)
	scale.Scale = 1.25
	tween(scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	pcall(function()
		require(script.Parent.Effects).sound("Hit")
	end)
	task.spawn(function()
		local s0 = os.clock()
		while os.clock() - s0 < 0.35 and model.Parent do
			local k = (os.clock() - s0) / 0.35
			for _, entry in lidParts do
				local p, start = entry[1], entry[2]
				p.CFrame = CFrame.new(0, k * 6, -k * 2) * start * CFrame.Angles(-k * 3, 0, k * 0.8)
				p.Transparency = k
			end
			RunService.RenderStepped:Wait()
		end
	end)

	-- The loot cards, one at a time.
	local row = UIKit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.62),
		Size = UDim2.fromOffset(math.max(1, #loot) * 128, 160),
		BackgroundTransparency = 1,
		Parent = root,
	}, {
		UIKit.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 10),
		}),
	})
	task.wait(0.05)
	for i, entry in loot do
		local id, amount = entry[1], entry[2]
		local item = Items[id]
		local rc = ITEM_RARITY[id] or Items.CRATES.supply_crate.colour
		local holder = UIKit.new("Frame", { Size = UDim2.fromOffset(118, 150), BackgroundTransparency = 1, LayoutOrder = i, Parent = row })
		local card = UIKit.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(10, 10),
			BackgroundColor3 = UIKit.Colors.panel,
			BackgroundTransparency = 0.05,
			Parent = holder,
		}, { UIKit.corner(10), UIKit.stroke(rc, 3) })
		local shine = UIKit.new("Frame", {
			Size = UDim2.new(1, 0, 0, 8),
			BackgroundColor3 = rc,
			BorderSizePixel = 0,
			Parent = card,
		}, { UIKit.corner(6) })
		shine.Position = UDim2.new(0, 0, 1, -8)
		Icons.make(id, card, UDim2.new(1, -20, 0, 86), UDim2.fromOffset(10, 8))
		UIKit.label({
			Position = UDim2.new(0, 4, 0, 94),
			Size = UDim2.new(1, -8, 0, 22),
			Text = "x" .. amount,
			TextSize = 20,
			Parent = card,
		})
		UIKit.label({
			Position = UDim2.new(0, 4, 0, 116),
			Size = UDim2.new(1, -8, 0, 24),
			Text = if item then item.name else id,
			TextSize = 13,
			TextWrapped = true,
			TextColor3 = rc,
			Parent = card,
		})
		-- Each card slams in big and snaps to size.
		card.Size = UDim2.fromOffset(170, 216)
		card.Rotation = (i % 2 == 0 and 1 or -1) * 8
		tween(card, 0.16, { Size = UDim2.fromOffset(118, 150), Rotation = 0 }, Enum.EasingStyle.Back)
		pcall(function()
			require(script.Parent.Effects).sound("Pickup")
		end)
		task.wait(0.1)
	end

	local hint = UIKit.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.9),
		Size = UDim2.fromOffset(400, 24),
		Text = "Click to close",
		TextSize = 16,
		Parent = root,
	})
	local button = UIKit.new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 50, Parent = root })
	local function close()
		if closed then
			return
		end
		closed = true
		tween(root, 0.25, { BackgroundTransparency = 1 })
		for _, d in root:GetDescendants() do
			if d:IsA("GuiObject") then
				tween(d, 0.25, { BackgroundTransparency = 1 })
			end
			if d:IsA("TextLabel") then
				tween(d, 0.25, { TextTransparency = 1, TextStrokeTransparency = 1 })
			end
			if d:IsA("ViewportFrame") then
				tween(d, 0.25, { ImageTransparency = 1 })
			end
		end
		task.delay(0.3, function()
			root:Destroy()
			busy = false
			local nextOne = table.remove(queue, 1)
			if nextOne then
				task.spawn(play, nextOne[1], nextOne[2])
			end
		end)
	end
	button.MouseButton1Click:Connect(close)
	hint.Visible = true
	task.delay(4, close)
end

function CrateOpen.init()
	gui = UIKit.new("ScreenGui", {
		Name = "CrateOpen",
		ResetOnSpawn = false,
		DisplayOrder = 40,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	Remotes.CrateOpened.OnClientEvent:Connect(function(crateId: string, loot)
		if type(loot) ~= "table" then
			return
		end
		if busy then
			table.insert(queue, { crateId, loot })
		else
			task.spawn(play, crateId, loot)
		end
	end)
end

return CrateOpen
