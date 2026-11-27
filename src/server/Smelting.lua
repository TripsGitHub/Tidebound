-- Smelting at campfires, the survival-tribe way: drop raw ore (or raw meat) into a
-- lit fire and it comes back out as bars (or cooked meat) one at a time. Drop logs,
-- sticks or leaves in to keep it burning. Every fire shows two bars over it: how much
-- fuel it has left, and how far along the current piece is.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Items)
local Drops = require(script.Parent.Drops)

local Smelting = {}

-- What a fire turns things into, and how many seconds each piece takes.
Smelting.RECIPES = {
	silver_ore = { out = "silver_bar", time = 4 },
	gold_ore = { out = "gold_bar", time = 5 },
	sunstone = { out = "sunsteel_bar", time = 6 },
	raw_meat = { out = "cooked_meat", time = 3 },
}
-- Seconds of burning each fuel adds.
Smelting.FUEL = { log = 40, stick = 12, leaves = 5, coconut = 8 }
local START_FUEL = 60 -- a freshly built fire
local MAX_FUEL = 600
local REACH = 6 -- how close to the fire a dropped item must land

type Fire = { model: Model, core: BasePart, queue: { string }, progress: number, gui: BillboardGui, fuelFill: Frame, workFill: Frame, workText: TextLabel, fuelText: TextLabel }
local fires: { [Model]: Fire } = {}

local function bar(parent: Instance, y: number, colour: Color3): (Frame, TextLabel)
	local back = Instance.new("Frame")
	back.Position = UDim2.new(0, 0, 0, y)
	back.Size = UDim2.new(1, 0, 0, 16)
	back.BackgroundColor3 = Color3.fromRGB(40, 28, 20)
	back.BackgroundTransparency = 0.15
	back.BorderSizePixel = 0
	back.Parent = parent
	Instance.new("UICorner", back).CornerRadius = UDim.new(1, 0)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(236, 214, 170)
	stroke.Thickness = 1.5
	stroke.Parent = back
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = colour
	fill.BorderSizePixel = 0
	fill.Parent = back
	Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.TextColor3 = Color3.fromRGB(255, 248, 232)
	text.TextStrokeTransparency = 0.3
	text.Font = Enum.Font.GothamBold
	text.TextSize = 12
	text.ZIndex = 2
	text.Parent = back
	return fill, text
end

local function watch(model: Model)
	if fires[model] or model.Name ~= "Campfire" then
		return
	end
	local core = model:FindFirstChild("Core") :: BasePart?
	if not core then
		return
	end
	if model:GetAttribute("Fuel") == nil then
		model:SetAttribute("Fuel", START_FUEL)
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "FireBars"
	gui.Size = UDim2.fromOffset(150, 40)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 6, 0)
	gui.MaxDistance = 40
	gui.LightInfluence = 0
	gui.Parent = core
	local fuelFill, fuelText = bar(gui, 0, Color3.fromRGB(255, 150, 60))
	local workFill, workText = bar(gui, 22, Color3.fromRGB(236, 236, 240))
	workFill.Parent.Visible = false
	fires[model] = { model = model, core = core, queue = {}, progress = 0, gui = gui, fuelFill = fuelFill, workFill = workFill, workText = workText, fuelText = fuelText }
	model.Destroying:Connect(function()
		local f = fires[model]
		fires[model] = nil
		-- Anything still waiting in the fire comes back out raw.
		if f then
			for _, id in f.queue do
				Drops.spawn(id, 1, core.Position + Vector3.new(0, 2, 0))
			end
		end
	end)
end

local function setLit(f: Fire, lit: boolean)
	for _, d in f.core:GetChildren() do
		if d:IsA("Fire") or d:IsA("PointLight") then
			d.Enabled = lit
		end
	end
end

local function step(f: Fire, dt: number)
	local fuel = f.model:GetAttribute("Fuel") or 0
	local pos = f.core.Position
	-- Pull in anything dropped into the fire.
	local folder = workspace:FindFirstChild("Drops")
	if folder then
		for _, drop in folder:GetChildren() do
			local id = drop:GetAttribute("ItemId")
			if id and drop:IsA("Model") and (drop:GetPivot().Position - pos).Magnitude < REACH then
				local amount = drop:GetAttribute("Amount") or 1
				if Smelting.FUEL[id] then
					fuel = math.min(MAX_FUEL, fuel + Smelting.FUEL[id] * amount)
					drop:Destroy()
				elseif Smelting.RECIPES[id] then
					for _ = 1, amount do
						table.insert(f.queue, id)
					end
					drop:Destroy()
				end
			end
		end
	end
	-- Burn: the fire goes down whether or not it's working, like a real fire.
	fuel = math.max(0, fuel - dt)
	if fuel > 0 and #f.queue > 0 then
		local r = Smelting.RECIPES[f.queue[1]]
		f.progress += dt / r.time
		if f.progress >= 1 then
			f.progress = 0
			table.remove(f.queue, 1)
			local a = math.random() * math.pi * 2
			Drops.spawn(r.out, 1, pos + Vector3.new(math.cos(a) * 3.5, 2, math.sin(a) * 3.5), Vector3.new(math.cos(a), 0.5, math.sin(a)))
		end
	end
	f.model:SetAttribute("Fuel", fuel)
	setLit(f, fuel > 0)

	-- The bars.
	f.fuelFill.Size = UDim2.fromScale(math.clamp(fuel / 120, 0, 1), 1)
	f.fuelText.Text = if fuel > 0 then string.format("Fire  %ds", math.ceil(fuel)) else "Out: drop wood in"
	local working = #f.queue > 0
	;(f.workFill.Parent :: Frame).Visible = working
	if working then
		local id = f.queue[1]
		f.workFill.Size = UDim2.fromScale(math.clamp(f.progress, 0, 1), 1)
		f.workText.Text = string.format("%s  %d left", Items[Smelting.RECIPES[id].out].name, #f.queue)
	end
end

function Smelting.start()
	local function hookFolder(folder: Instance)
		for _, m in folder:GetChildren() do
			if m:IsA("Model") then
				watch(m)
			end
		end
		folder.ChildAdded:Connect(function(m)
			if m:IsA("Model") then
				task.defer(watch, m)
			end
		end)
	end
	task.spawn(function()
		hookFolder(workspace:WaitForChild("Structures"))
	end)
	task.spawn(function()
		while true do
			local dt = task.wait(0.25)
			for _, f in fires do
				step(f, dt)
			end
		end
	end)
end

return Smelting
