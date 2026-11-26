-- "Customise Castaway": pick skin, hair, outfit, dye and face paint. A live 3D
-- preview of your own character turns slowly on the left; each < > click changes
-- your character in the world straight away. Opens once on first join.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Looks = require(Shared.Looks)
local Remotes = require(Shared.Remotes)

local UIKit = require(script.Parent.UIKit)
local new, label = UIKit.new, UIKit.label
local C = UIKit.Colors

local Screen = {}

local player = Players.LocalPlayer
local root: Frame
local viewport: ViewportFrame
local world: WorldModel
local camera: Camera
local valueLabels: { [string]: TextLabel } = {}
local look: Looks.Look? = nil
local spin = 0
local refreshToken = 0

local function readLook(): Looks.Look?
	local raw = player:GetAttribute("Look")
	if type(raw) ~= "string" then
		return nil
	end
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
	return if ok then Looks.sanitize(decoded) else nil
end

-- Copies the character into the viewport (after the server has re-dressed it).
local function refreshPreview()
	refreshToken += 1
	local token = refreshToken
	task.delay(0.3, function()
		if token ~= refreshToken or not root.Visible then
			return
		end
		world:ClearAllChildren()
		local character = player.Character
		if not character then
			return
		end
		character.Archivable = true
		local copy = character:Clone()
		character.Archivable = false
		for _, d in copy:GetDescendants() do
			if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Sound") or d:IsA("BillboardGui") then
				d:Destroy()
			elseif d:IsA("BasePart") then
				d.Anchored = true
			end
		end
		local hrp = copy:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp then
			copy.PrimaryPart = hrp
			copy:PivotTo(CFrame.new(0, 0, 0))
		end
		copy.Parent = world
	end)
end

local function refreshValues()
	if not look then
		return
	end
	for _, row in Looks.ROWS do
		valueLabels[row.key].Text = Looks.OPTIONS[row.key][(look :: any)[row.key]].name
	end
end

local function step(key: string, dir: number)
	if not look then
		return
	end
	local n = #Looks.OPTIONS[key]
	local l = look :: any
	l[key] = (l[key] - 1 + dir) % n + 1
	refreshValues()
	Remotes.SetLook:FireServer(look)
	refreshPreview()
end

function Screen.open()
	look = readLook()
	refreshValues()
	root.Visible = true
	refreshPreview()
end

function Screen.close()
	if root.Visible and look then
		Remotes.SetLook:FireServer(look, true)
	end
	root.Visible = false
end

function Screen.toggle()
	if root.Visible then
		Screen.close()
	else
		Screen.open()
	end
end

function Screen.isOpen(): boolean
	return root.Visible
end

function Screen.init(parent: ScreenGui)
	root = UIKit.panel({ Parent = parent, Name = "Look", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(560, 400), Visible = false, ZIndex = 5 })
	UIKit.title(root, "Your Castaway", 8)

	local previewBox = UIKit.block({ Parent = root, Position = UDim2.fromOffset(16, 50), Size = UDim2.fromOffset(210, 280), BackgroundColor3 = C.cardDark })
	viewport = new("ViewportFrame", { Parent = previewBox, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Ambient = Color3.fromRGB(170, 160, 150), LightColor = Color3.fromRGB(255, 246, 230), LightDirection = Vector3.new(-0.4, -1, -0.6) })
	world = new("WorldModel", { Parent = viewport })
	camera = new("Camera", { Parent = viewport, FieldOfView = 30 })
	viewport.CurrentCamera = camera

	local rows = new("Frame", { Parent = root, Position = UDim2.fromOffset(240, 54), Size = UDim2.fromOffset(304, 276), BackgroundTransparency = 1 }, {
		new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for i, row in Looks.ROWS do
		local r = UIKit.block({ Parent = rows, LayoutOrder = i, Size = UDim2.new(1, 0, 0, 40) })
		label({ Parent = r, Position = UDim2.fromOffset(10, 0), Size = UDim2.new(0, 110, 1, 0), Text = row.label, TextScaled = false, TextSize = 19, TextXAlignment = Enum.TextXAlignment.Left })
		UIKit.textButton({ Parent = r, Position = UDim2.fromOffset(122, 4), Size = UDim2.fromOffset(28, 32), Text = "<", TextScaled = false, TextSize = 26 }, function()
			step(row.key, -1)
		end)
		valueLabels[row.key] = label({ Parent = r, Position = UDim2.fromOffset(150, 0), Size = UDim2.new(1, -184, 1, 0), Text = "", TextScaled = false, TextSize = 19 })
		UIKit.textButton({ Parent = r, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 4), Size = UDim2.fromOffset(28, 32), Text = ">", TextScaled = false, TextSize = 26 }, function()
			step(row.key, 1)
		end)
	end

	UIKit.button({ Parent = root, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.fromOffset(150, 38), Text = "Done", BackgroundColor3 = C.good, TextScaled = false, TextSize = 24 }, function()
		Screen.close()
	end)

	RunService.RenderStepped:Connect(function(dt)
		if not root.Visible then
			return
		end
		spin += dt * 0.6
		-- Front of the character faces -Z; orbit slowly around the upper body.
		local target = Vector3.new(0, -0.4, 0)
		camera.CFrame = CFrame.lookAt(target + Vector3.new(math.sin(spin) * 13, 1.5, -math.cos(spin) * 13), target)
	end)

	-- First visit: let the player pick a look before they start.
	task.delay(2, function()
		if player:GetAttribute("LookChosen") == false then
			Screen.open()
		end
	end)
	player.CharacterAdded:Connect(function()
		if root.Visible then
			refreshPreview()
		end
	end)
end

return Screen
