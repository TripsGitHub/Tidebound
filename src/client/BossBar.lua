-- A wide health bar at the top of the screen while you're near a boss.
local Players = game:GetService("Players")

local BossBar = {}

function BossBar.init(root: ScreenGui)
	local frame = Instance.new("Frame")
	frame.Name = "BossBar"
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, 92)
	frame.Size = UDim2.fromOffset(420, 46)
	frame.BackgroundTransparency = 1
	frame.Visible = false
	frame.Parent = root
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 20)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 18
	title.TextColor3 = Color3.fromRGB(240, 226, 200)
	title.TextStrokeTransparency = 0.4
	title.Parent = frame
	local back = Instance.new("Frame")
	back.Position = UDim2.fromOffset(0, 24)
	back.Size = UDim2.new(1, 0, 0, 16)
	back.BackgroundColor3 = Color3.fromRGB(40, 30, 28)
	back.BorderSizePixel = 0
	back.Parent = frame
	Instance.new("UICorner", back).CornerRadius = UDim.new(0, 6)
	local stroke = Instance.new("UIStroke", back)
	stroke.Color = Color3.fromRGB(20, 14, 12)
	stroke.Thickness = 2
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(150, 40, 34)
	fill.BorderSizePixel = 0
	fill.Parent = back
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 6)

	task.spawn(function()
		while true do
			task.wait(0.2)
			local char = Players.LocalPlayer.Character
			local me = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			local best, bestD = nil, 130
			local animals = workspace:FindFirstChild("Animals")
			if me and animals then
				for _, m in animals:GetChildren() do
					if m:FindFirstChild("BossTag") then
						local d = (m:GetPivot().Position - me.Position).Magnitude
						if d < bestD then
							best, bestD = m, d
						end
					end
				end
			end
			frame.Visible = best ~= nil
			if best then
				local hp, max = best:GetAttribute("HP") or 0, best:GetAttribute("MaxHP") or 1
				local tag = best:FindFirstChild("BossTag")
				local label = tag and tag:FindFirstChildOfClass("TextLabel")
				title.Text = (if label then label.Text else best.Name) .. (if best:GetAttribute("Enraged") then "  ·  ENRAGED" else "")
				fill.Size = UDim2.fromScale(math.clamp(hp / max, 0, 1), 1)
			end
		end
	end)
end

return BossBar
