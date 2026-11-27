-- Overhead nameplates: a dark strip with the player's level in a small circle and
-- their name in white. Replaces Roblox's default name display.
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
	-- A dark brown strip: level in a circle on the left, then the name in white.
	local strip = new("Frame", { Parent = gui, LayoutOrder = 1, Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = Color3.fromRGB(62, 44, 28), BackgroundTransparency = 0.15 }, {
		UIKit.round(),
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
		new("UIPadding", { PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 10) }),
	})
	local badge = new("Frame", { Parent = strip, LayoutOrder = 1, Size = UDim2.fromOffset(24, 24), BackgroundColor3 = C.panel }, {
		UIKit.round(),
		UIKit.stroke(C.rim, 1.5),
	})
	local level = UIKit.label({ Parent = badge, Size = UDim2.fromScale(1, 1), Text = "1", TextScaled = false, TextSize = 14 })
	UIKit.label({ Parent = strip, LayoutOrder = 2, Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X, Text = plr.DisplayName, TextScaled = false, TextSize = 18 })

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
