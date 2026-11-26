-- Overhead nameplates: a round level badge next to each player's name, in the same
-- parchment style as the HUD. Replaces Roblox's default name display.
local Players = game:GetService("Players")
local UIKit = require(script.Parent.UIKit)

local C = UIKit.Colors
local new = UIKit.new

local Nameplates = {}

local function attach(plr: Player, character: Model)
	local head = character:WaitForChild("Head", 10) :: BasePart?
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not head or not humanoid then
		return
	end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

	local gui = new("BillboardGui", {
		Name = "TideboundNameplate",
		Adornee = head,
		Size = UDim2.fromOffset(200, 34),
		StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0),
		AlwaysOnTop = false,
		MaxDistance = 120,
		LightInfluence = 0,
		Parent = head,
	}, {
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local badge = new("Frame", { Parent = gui, LayoutOrder = 1, Size = UDim2.fromOffset(28, 28), BackgroundColor3 = C.xp }, {
		new("UICorner", { CornerRadius = UDim.new(1, 0) }),
		UIKit.stroke(C.edge, 2),
	})
	local level = UIKit.label({ Parent = badge, Size = UDim2.new(1, -6, 1, -6), Position = UDim2.fromOffset(3, 3), Text = "1", Font = UIKit.FontHeavy })
	UIKit.hudText({ Parent = gui, LayoutOrder = 2, Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X, Text = plr.DisplayName, TextScaled = false, TextSize = 20 })

	local function refresh()
		level.Text = tostring(plr:GetAttribute("Level") or 1)
	end
	refresh()
	local conn = plr:GetAttributeChangedSignal("Level"):Connect(refresh)
	gui.Destroying:Connect(function()
		conn:Disconnect()
	end)
end

local function watch(plr: Player)
	if plr.Character then
		task.spawn(attach, plr, plr.Character)
	end
	plr.CharacterAdded:Connect(function(character)
		attach(plr, character)
	end)
end

function Nameplates.start()
	for _, plr in Players:GetPlayers() do
		watch(plr)
	end
	Players.PlayerAdded:Connect(watch)
end

return Nameplates
