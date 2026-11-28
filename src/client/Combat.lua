-- The combat HUD, the Island Tribes way:
--  * "You are in combat! If you log out you will lose your equipped items!" in red
--    over the hotbar while you're tagged (the InCombat attribute, set by the server).
--  * The kill feed, middle left: "Killer(lvl) [weapon] Victim(lvl)".
--  * Passive Mode: a toggle under the menu, a line over the hotbar while it's on, and
--    you only see players whose Passive Mode matches yours (they can't fight you,
--    and you can't fight them).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local UIKit = require(script.Parent.UIKit)
local Icons = require(script.Parent.Icons)

local Combat = {}

local C = UIKit.Colors
local new = UIKit.new
local player = Players.LocalPlayer
local RED = Color3.fromRGB(255, 60, 50)
local FEED_LIFE = 8
local FEED_MAX = 5

local feed: Frame

local function nameText(name: string, level: number?): string
	return if level then name .. "(" .. level .. ")" else name
end

local function addFeedLine(killer: string?, killerLevel: number?, weapon: string?, victim: string, victimLevel: number?)
	local row = new("Frame", { Parent = feed, Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = Color3.fromRGB(20, 14, 10), BackgroundTransparency = 0.45, LayoutOrder = -os.clock() * 100 }, {
		UIKit.corner(6),
		new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local function word(text: string, order: number, colour: Color3?)
		UIKit.label({ Parent = row, LayoutOrder = order, Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X, Text = text, TextScaled = false, TextSize = 16, TextColor3 = colour or C.text })
	end
	local mine = player.DisplayName
	if killer then
		word(nameText(killer, killerLevel), 1, if killer == mine then C.star else nil)
		local icon = new("Frame", { Parent = row, LayoutOrder = 2, Size = UDim2.fromOffset(24, 24), BackgroundTransparency = 1 })
		if weapon then
			Icons.make(weapon, icon, UDim2.fromScale(1, 1))
		else
			-- Killed by a creature or with bare hands: the crossed swords.
			local id = Config.Icons.hitSwords
			if id ~= 0 then
				new("ImageLabel", { Parent = icon, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = "rbxassetid://" .. id })
			else
				UIKit.label({ Parent = icon, Size = UDim2.fromScale(1, 1), Text = "X", TextColor3 = RED })
			end
		end
		word(nameText(victim, victimLevel), 3, if victim == mine then C.star else nil)
	else
		word(nameText(victim, victimLevel) .. " died", 1, if victim == mine then C.star else nil)
	end
	-- Keep only the newest few.
	local rows = {}
	for _, r in feed:GetChildren() do
		if r:IsA("Frame") then
			table.insert(rows, r)
		end
	end
	table.sort(rows, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for i = FEED_MAX + 1, #rows do
		rows[i]:Destroy()
	end
	task.delay(FEED_LIFE, function()
		if row.Parent then
			local info = TweenInfo.new(0.5)
			TweenService:Create(row, info, { BackgroundTransparency = 1 }):Play()
			for _, d in row:GetDescendants() do
				if d:IsA("TextLabel") then
					TweenService:Create(d, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
				elseif d:IsA("ImageLabel") then
					TweenService:Create(d, info, { ImageTransparency = 1 }):Play()
				elseif d:IsA("ViewportFrame") then
					TweenService:Create(d, info, { ImageTransparency = 1 }):Play()
				end
			end
			task.wait(0.55)
			row:Destroy()
		end
	end)
end

-- Hide or show another player's character (and its nameplate) on this screen only.
local hidden: { [Model]: boolean } = {}
local function setShown(character: Model, shown: boolean)
	if (hidden[character] == true) == not shown then
		return
	end
	hidden[character] = if shown then nil else true
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("Decal") then
			d.LocalTransparencyModifier = if shown then 0 else 1
		elseif d:IsA("BillboardGui") or d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam") then
			d.Enabled = shown
		end
	end
end

-- Can I see this player? Only if we're both passive or both not.
function Combat.canSee(other: Player): boolean
	return (other:GetAttribute("Passive") == true) == (player:GetAttribute("Passive") == true)
end

function Combat.init(root: ScreenGui)
	-- Warning over the hotbar while you're in combat, and the Passive line.
	local warning = UIKit.label({ Parent = root, Name = "CombatWarning", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -104), Size = UDim2.fromOffset(640, 24), Text = "You are in combat! If you log out you will lose your equipped items!", TextScaled = false, TextSize = 20, TextColor3 = RED, TextStrokeColor3 = Color3.fromRGB(40, 6, 4), Visible = false })
	local passiveLine = UIKit.label({ Parent = root, Name = "PassiveLine", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -104), Size = UDim2.fromOffset(640, 22), Text = "Passive Mode is enabled - you can only see other Passive players", TextScaled = false, TextSize = 17, TextColor3 = Color3.fromRGB(150, 230, 255), Visible = false })

	-- Passive Mode toggle, under the menu buttons (top left).
	local toggle = UIKit.button({ Parent = root, Name = "PassiveToggle", Position = UDim2.fromOffset(14, 92), Size = UDim2.fromOffset(150, 28), Text = "Passive Mode: Off", TextScaled = false, TextSize = 15 }, function()
		Remotes.SetPassive:FireServer(not player:GetAttribute("Passive"))
	end)

	local function refresh()
		local inCombat = player:GetAttribute("InCombat") == true
		local passive = player:GetAttribute("Passive") == true
		warning.Visible = inCombat
		passiveLine.Visible = passive and not inCombat
		toggle.Text = "Passive Mode: " .. (if passive then "On" else "Off")
		toggle.BackgroundColor3 = if passive then Color3.fromRGB(70, 150, 190) else C.button
		toggle.AutoButtonColor = not inCombat
		toggle.TextTransparency = if inCombat then 0.45 else 0
	end
	refresh()
	player:GetAttributeChangedSignal("InCombat"):Connect(refresh)
	player:GetAttributeChangedSignal("Passive"):Connect(refresh)
	-- The warning pulses so it catches the eye.
	RunService.Heartbeat:Connect(function()
		if warning.Visible then
			warning.TextTransparency = 0.15 + 0.15 * math.sin(os.clock() * 6)
		end
	end)

	-- Kill feed, middle left.
	feed = new("Frame", { Parent = root, Name = "KillFeed", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.45, 0), Size = UDim2.fromOffset(360, 160), BackgroundTransparency = 1 }, {
		new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	Remotes.KillFeed.OnClientEvent:Connect(addFeedLine)

	-- Passive players only see each other: check every half second (and whenever
	-- anyone's Passive Mode changes).
	local function sweep()
		for _, other in Players:GetPlayers() do
			if other ~= player and other.Character then
				setShown(other.Character, Combat.canSee(other))
			end
		end
		for character in hidden do
			if not character.Parent then
				hidden[character] = nil
			end
		end
	end
	local function watch(other: Player)
		other:GetAttributeChangedSignal("Passive"):Connect(sweep)
		local function hook(character: Model)
			hidden[character] = nil
			task.defer(sweep)
			-- Parts added later (tools, armour) follow the character's state.
			character.DescendantAdded:Connect(function(d)
				if hidden[character] then
					if d:IsA("BasePart") or d:IsA("Decal") then
						d.LocalTransparencyModifier = 1
					elseif d:IsA("BillboardGui") or d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam") then
						d.Enabled = false
					end
				end
			end)
		end
		other.CharacterAdded:Connect(hook)
		if other.Character then
			hook(other.Character)
		end
	end
	for _, other in Players:GetPlayers() do
		if other ~= player then
			watch(other)
		end
	end
	Players.PlayerAdded:Connect(watch)
	player:GetAttributeChangedSignal("Passive"):Connect(sweep)
	task.spawn(function()
		while true do
			sweep()
			task.wait(0.5)
		end
	end)
end

return Combat
