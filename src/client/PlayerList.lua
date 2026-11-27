-- Our own player list in place of Roblox's (which has an invite button we don't
-- want). A driftwood-framed board in the top right: each islander's level badge,
-- name and tribe, highest level first. Tab folds it down to just the header.
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local UIKit = require(script.Parent.UIKit)

local PlayerList = {}

local C = UIKit.Colors
local new = UIKit.new
local ROW = 26

local board: Frame
local list: Frame
local header: TextButton
local rows: { [Player]: Frame } = {}
local open = true
local watching: { [Player]: { RBXScriptConnection } } = {}

local function hideCore()
	-- SetCoreGuiEnabled can fail if the core scripts haven't loaded yet: retry.
	for _ = 1, 20 do
		if pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.PlayerList, false) then
			return
		end
		task.wait(0.5)
	end
end

local function resize()
	local n = 0
	for _ in rows do
		n += 1
	end
	list.Visible = open
	board.Size = UDim2.fromOffset(220, 40 + (if open then n * (ROW + 2) + 6 else 0))
	header.Text = "Islanders  " .. n
end

local function sortRows()
	local order = {}
	for plr in rows do
		table.insert(order, plr)
	end
	table.sort(order, function(a, b)
		local la, lb = a:GetAttribute("Level") or 1, b:GetAttribute("Level") or 1
		if la ~= lb then
			return la > lb
		end
		return a.DisplayName:lower() < b.DisplayName:lower()
	end)
	for i, plr in order do
		rows[plr].LayoutOrder = i
	end
end

local function fill(plr: Player)
	local row = rows[plr]
	if not row then
		return
	end
	local level = plr:GetAttribute("Level") or 1
	local tribe = plr:GetAttribute("Tribe")
	row.Badge.Num.Text = tostring(level)
	row.Name_.Text = plr.DisplayName
	row.Tribe.Text = if type(tribe) == "string" and tribe ~= "" then tribe else ""
	row.Name_.TextColor3 = if plr == Players.LocalPlayer then C.star else C.text
	sortRows()
end

local function add(plr: Player)
	if rows[plr] then
		return
	end
	local row = new("Frame", { Parent = list, Name = plr.Name, Size = UDim2.new(1, 0, 0, ROW), BackgroundColor3 = C.cardDark, BackgroundTransparency = 0.55 }, { UIKit.corner(4) })
	local badge = new("Frame", { Parent = row, Name = "Badge", Position = UDim2.fromOffset(3, 3), Size = UDim2.fromOffset(34, ROW - 6), BackgroundColor3 = C.wood }, {
		UIKit.corner(4),
		new("UIStroke", { Color = C.brass, Thickness = 1 }),
	})
	UIKit.label({ Parent = badge, Name = "Num", Size = UDim2.fromScale(1, 1), Text = "1", TextScaled = false, TextSize = 14, TextColor3 = C.gold })
	UIKit.label({ Parent = row, Name = "Name_", Position = UDim2.fromOffset(44, 0), Size = UDim2.new(1, -50, 1, 0), Text = plr.DisplayName, TextXAlignment = Enum.TextXAlignment.Left, TextScaled = false, TextSize = 16, TextTruncate = Enum.TextTruncate.AtEnd })
	UIKit.label({ Parent = row, Name = "Tribe", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 0), Size = UDim2.new(0.4, 0, 1, 0), Text = "", TextXAlignment = Enum.TextXAlignment.Right, TextScaled = false, TextSize = 12, TextColor3 = C.rim })
	rows[plr] = row
	watching[plr] = {
		plr:GetAttributeChangedSignal("Level"):Connect(function()
			fill(plr)
		end),
		plr:GetAttributeChangedSignal("Tribe"):Connect(function()
			fill(plr)
		end),
	}
	fill(plr)
	resize()
end

local function remove(plr: Player)
	if rows[plr] then
		rows[plr]:Destroy()
		rows[plr] = nil
	end
	for _, c in watching[plr] or {} do
		c:Disconnect()
	end
	watching[plr] = nil
	resize()
end

function PlayerList.init(gui: ScreenGui)
	task.spawn(hideCore)
	board = UIKit.panel({ Parent = gui, Name = "PlayerList", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 52), Size = UDim2.fromOffset(220, 40) })
	board.ClipsDescendants = false
	header = UIKit.textButton({ Parent = board, Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 26), Text = "Islanders", TextScaled = false, TextSize = 18 }, function()
		open = not open
		resize()
	end)
	list = new("Frame", { Parent = board, Position = UDim2.fromOffset(8, 36), Size = UDim2.new(1, -16, 1, -42), BackgroundTransparency = 1 }, {
		new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for _, plr in Players:GetPlayers() do
		add(plr)
	end
	Players.PlayerAdded:Connect(add)
	Players.PlayerRemoving:Connect(remove)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.Tab then
			open = not open
			resize()
		end
	end)
end

return PlayerList
