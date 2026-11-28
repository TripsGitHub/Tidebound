-- The boss bar: the same look as the target bar (what you're hitting), only
-- wider and taller, with a colour gradient picked per boss. It shows while a
-- living boss is within range, under the target bar.
local Players = game:GetService("Players")

local UIKit = require(script.Parent.UIKit)

local C = UIKit.Colors

local BossBar = {}

-- Left-to-right fill colours for each boss (matched on its AnimalType).
local GRADIENTS = {
	CrawlerQueen = { Color3.fromRGB(70, 140, 52), Color3.fromRGB(170, 214, 70) },
	CrystalWarden = { Color3.fromRGB(96, 70, 200), Color3.fromRGB(110, 214, 240) },
	MagmaGolem = { Color3.fromRGB(150, 24, 16), Color3.fromRGB(255, 160, 40) },
}
local DEFAULT = { Color3.fromRGB(140, 30, 30), Color3.fromRGB(220, 80, 60) }

function BossBar.init(root: ScreenGui)
	local frame = Instance.new("Frame")
	frame.Name = "BossBar"
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, 108)
	frame.Size = UDim2.fromOffset(520, 64)
	frame.BackgroundTransparency = 1
	frame.Visible = false
	frame.Parent = root

	local back = Instance.new("Frame")
	back.Size = UDim2.new(1, 0, 0, 34)
	back.BackgroundColor3 = C.cardDark
	back.BackgroundTransparency = UIKit.PANEL_ALPHA
	back.BorderSizePixel = 0
	back.Parent = frame
	Instance.new("UICorner", back).CornerRadius = UDim.new(0, 8)
	local stroke = Instance.new("UIStroke", back)
	stroke.Color = C.rim
	stroke.Thickness = 3

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	fill.BorderSizePixel = 0
	fill.Parent = back
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 8)
	local gradient = Instance.new("UIGradient")
	gradient.Parent = fill

	-- A soft white sheen over the top half, like the target bar's fill.
	local sheen = Instance.new("Frame")
	sheen.Size = UDim2.fromScale(1, 0.45)
	sheen.BackgroundColor3 = Color3.new(1, 1, 1)
	sheen.BackgroundTransparency = 0.82
	sheen.BorderSizePixel = 0
	sheen.Parent = fill
	Instance.new("UICorner", sheen).CornerRadius = UDim.new(0, 8)

	local hpText = UIKit.hudText({ Parent = back, Size = UDim2.fromScale(1, 1), Text = "", ZIndex = 3, TextScaled = false, TextSize = 24 })
	local title = UIKit.hudText({ Parent = frame, Position = UDim2.fromOffset(0, 38), Size = UDim2.new(1, 0, 0, 24), Text = "", TextScaled = false, TextSize = 22 })

	local shownKind = nil
	task.spawn(function()
		while true do
			task.wait(0.15)
			local char = Players.LocalPlayer.Character
			local me = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			local best, bestD = nil, 130
			local animals = workspace:FindFirstChild("Animals")
			if me and animals then
				for _, m in animals:GetChildren() do
					if m:FindFirstChild("BossTag") and (m:GetAttribute("HP") or 0) > 0 then
						local d = (m:GetPivot().Position - me.Position).Magnitude
						if d < bestD then
							best, bestD = m, d
						end
					end
				end
			end
			frame.Visible = best ~= nil
			if best then
				local kind = best:GetAttribute("AnimalType") or best.Name
				if kind ~= shownKind then
					shownKind = kind
					local g = GRADIENTS[kind] or DEFAULT
					gradient.Color = ColorSequence.new(g[1], g[2])
				end
				local hp, max = best:GetAttribute("HP") or 0, best:GetAttribute("MaxHP") or 1
				local name = best:GetAttribute("DisplayName")
				if not name then
					local tag = best:FindFirstChild("BossTag")
					local label = tag and tag:FindFirstChildOfClass("TextLabel")
					name = if label then label.Text else best.Name
				end
				title.Text = name .. (if best:GetAttribute("Enraged") then "  -  ENRAGED" else "")
				title.TextColor3 = if best:GetAttribute("Enraged") then Color3.fromRGB(255, 120, 90) else C.text
				hpText.Text = string.format("%d / %d", math.max(0, math.ceil(hp)), max)
				UIKit.slideBar(fill, hp / max)
			else
				shownKind = nil
			end
		end
	end)
end

return BossBar
